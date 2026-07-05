// lib/utils/audio_envelope_extractor.dart
import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show md5;
import 'package:flutter/foundation.dart' show compute, debugPrint, kIsWeb;
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'onyx_base_dir.dart' show getOnyxDocumentsDirectory;

/// Envelope time resolution: one bucket per this many milliseconds,
/// regardless of track length. Fine enough that a single drum hit/transient
/// lands in its own bucket instead of being averaged away with the quiet
/// moment around it — GlobalAudioController._tickGlow relies on that to give
/// a punchy attack/release response instead of a smooth wavy one.
const int kEnvelopeBucketMs = 25;

/// Hard cap on bucket count for pathologically long files, so a multi-hour
/// recording can't blow up memory/decode time — resolution degrades
/// gracefully past this rather than the feature just being disabled.
const int kEnvelopeMaxBuckets = 20000;

/// Reads a previously computed envelope for [audioFilePath] from disk, if
/// any. The native just_waveform decode in particular can take a few
/// seconds for a full music track — without this, every replay of the same
/// track (very common: voice notes get replayed, songs get looped) pays
/// that cost again, so the glow visibly "kicks in late" every single time.
Future<List<double>?> _loadCachedEnvelope(String audioFilePath) async {
  try {
    final file = await _envelopeCacheFile(audioFilePath);
    if (!await file.exists()) return null;
    final raw = jsonDecode(await file.readAsString()) as List;
    return raw.map((e) => (e as num).toDouble()).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _saveCachedEnvelope(String audioFilePath, List<double> envelope) async {
  try {
    final file = await _envelopeCacheFile(audioFilePath);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(envelope));
  } catch (e) {
    debugPrint('[AudioEnvelope] failed to cache envelope for $audioFilePath: $e');
  }
}

Future<File> _envelopeCacheFile(String audioFilePath) async {
  final docs = await getOnyxDocumentsDirectory();
  final hash = md5.convert(utf8.encode(audioFilePath)).toString();
  return File(p.join(docs.path, 'envelope_cache', '$hash.json'));
}

/// Decodes a local WAV file's real PCM data into a normalized (0..1)
/// RMS-loudness envelope at ~[kEnvelopeBucketMs] resolution spanning the
/// whole file, so the vinyl/player glow can react to the track's actual
/// loudness instead of a synthetic pulse.
///
/// Only WAV is supported here — it's the one format that decodes to PCM
/// trivially in pure Dart on every platform this app ships (Android/iOS/
/// macOS/Windows/Linux), covering the voice notes this app itself records
/// with AudioEncoder.wav plus any .wav shared in chat. Compressed formats
/// (mp3/m4a/aac/ogg/opus/flac) have no cross-platform pure-Dart decoder
/// without a heavy native/ffmpeg dependency, so callers must fall back to a
/// synthetic heuristic for those (see GlobalAudioController._tickGlow).
///
/// Returns null on any failure or unsupported format — this is a decorative
/// feature, so errors are swallowed rather than surfaced.
Future<List<double>?> computeWavEnvelope(String audioFilePath) async {
  if (kIsWeb) return null;
  if (!audioFilePath.toLowerCase().endsWith('.wav')) return null;

  final cached = await _loadCachedEnvelope(audioFilePath);
  if (cached != null) return cached;

  try {
    final bytes = await File(audioFilePath).readAsBytes();
    // Decoding walks every sample (with striding) — offload it so a long
    // track never causes a UI jank spike on the main isolate.
    final env = await compute(_decodeWavEnvelope, bytes);
    if (env != null) unawaited(_saveCachedEnvelope(audioFilePath, env));
    return env;
  } catch (e) {
    debugPrint('[AudioEnvelope] failed for $audioFilePath: $e');
    return null;
  }
}

List<double>? _decodeWavEnvelope(Uint8List bytes) {
  if (bytes.length < 44) return null;
  if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) {
    return null; // "RIFF"
  }
  if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
    return null; // "WAVE"
  }

  final bd = ByteData.sublistView(bytes);
  int pos = 12;
  int audioFormat = 1;
  int numChannels = 1;
  int sampleRate = 44100;
  int bitsPerSample = 16;
  int dataOffset = -1;
  int dataSize = 0;

  while (pos + 8 <= bytes.length) {
    final chunkId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    final chunkSize = bd.getUint32(pos + 4, Endian.little);
    final bodyStart = pos + 8;
    if (chunkId == 'fmt ' && bodyStart + 16 <= bytes.length) {
      audioFormat = bd.getUint16(bodyStart, Endian.little);
      numChannels = bd.getUint16(bodyStart + 2, Endian.little);
      sampleRate = bd.getUint32(bodyStart + 4, Endian.little);
      bitsPerSample = bd.getUint16(bodyStart + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = bodyStart;
      dataSize = chunkSize;
    }
    pos = bodyStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  if (dataOffset < 0 || dataSize <= 0 || numChannels <= 0 || sampleRate <= 0) return null;
  final bytesPerSample = bitsPerSample ~/ 8;
  if (bytesPerSample <= 0) return null;
  final end = (dataOffset + dataSize).clamp(0, bytes.length);
  final frameBytes = bytesPerSample * numChannels;
  final totalFrames = (end - dataOffset) ~/ frameBytes;
  if (totalFrames <= 0) return null;

  // One bucket per kEnvelopeBucketMs of real time, capped so a
  // pathologically long file can't blow up the array.
  final framesPerBucket = (sampleRate * kEnvelopeBucketMs / 1000).round().clamp(1, totalFrames);
  final bucketCount = (totalFrames / framesPerBucket).ceil().clamp(1, kEnvelopeMaxBuckets);

  double readSample(int frameIndex, int channel) {
    final off = dataOffset + frameIndex * frameBytes + channel * bytesPerSample;
    switch (bitsPerSample) {
      case 8:
        return (bytes[off] - 128) / 128.0;
      case 16:
        return bd.getInt16(off, Endian.little) / 32768.0;
      case 24:
        int s = bytes[off] | (bytes[off + 1] << 8) | (bytes[off + 2] << 16);
        if (s >= 0x800000) s -= 0x1000000;
        return s / 8388608.0;
      case 32:
        // audioFormat 3 = IEEE float, 1 = signed int.
        return audioFormat == 3
            ? bd.getFloat32(off, Endian.little).clamp(-1.0, 1.0)
            : bd.getInt32(off, Endian.little) / 2147483648.0;
      default:
        return 0.0;
    }
  }

  final buckets = List<double>.filled(bucketCount, 0.0);
  for (int b = 0; b < bucketCount; b++) {
    final startFrame = b * totalFrames ~/ bucketCount;
    final endFrame =
        ((b + 1) * totalFrames ~/ bucketCount).clamp(startFrame + 1, totalFrames);
    // Stride through the bucket instead of reading every frame — plenty
    // accurate for a glow effect and much faster on long tracks.
    final stride = ((endFrame - startFrame) / 200).ceil().clamp(1, 1 << 30);
    double sumSq = 0.0;
    int count = 0;
    for (int f = startFrame; f < endFrame; f += stride) {
      double frameSum = 0.0;
      for (int c = 0; c < numChannels; c++) {
        frameSum += readSample(f, c);
      }
      final avg = frameSum / numChannels;
      sumSq += avg * avg;
      count++;
    }
    buckets[b] = count > 0 ? sqrt(sumSq / count) : 0.0;
  }

  final maxV = buckets.fold<double>(0.0, (a, v) => v > a ? v : a);
  if (maxV <= 0.0001) return buckets;
  for (int i = 0; i < buckets.length; i++) {
    buckets[i] = (buckets[i] / maxV).clamp(0.0, 1.0);
  }
  return buckets;
}

/// Decodes a compressed audio file (mp3/m4a/aac/ogg/flac/...) into a
/// normalized (0..1) loudness envelope via `just_waveform`, which decodes
/// through the OS's own native codecs (AVAssetReader on iOS/macOS,
/// MediaExtractor/MediaCodec on Android) — that package only ships native
/// implementations for Android/iOS/macOS, so this is a no-op everywhere else
/// (Windows/Linux/web keep the synthetic fallback in
/// GlobalAudioController._tickGlow).
///
/// Returns null on any failure, unsupported platform, or if the file has no
/// usable audio track — this is a decorative feature, so errors are
/// swallowed rather than surfaced.
Future<List<double>?> computeCompressedEnvelope(String audioFilePath) async {
  if (kIsWeb) return null;
  if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return null;

  final cached = await _loadCachedEnvelope(audioFilePath);
  if (cached != null) return cached;

  File? waveFile;
  try {
    final tempDir = await getTemporaryDirectory();
    final hash = md5.convert(utf8.encode(audioFilePath)).toString();
    waveFile = File(p.join(tempDir.path, 'envelope_$hash.wave'));

    Waveform? waveform;
    // The native extractor can in principle wedge (bad file, exotic codec
    // the OS decoder chokes on) without ever emitting an error — a timeout
    // guarantees this always resolves to the synthetic fallback instead of
    // silently never loading an envelope.
    await for (final progress in JustWaveform.extract(
      audioInFile: File(audioFilePath),
      waveOutFile: waveFile,
      // Match kEnvelopeBucketMs (25ms/40Hz) so a single hit/transient lands
      // in its own pixel instead of being averaged into its quieter
      // surroundings — needed for the punchy attack/release response in
      // GlobalAudioController._tickGlow.
      zoom: const WaveformZoom.pixelsPerSecond(1000 ~/ kEnvelopeBucketMs),
    ).timeout(const Duration(seconds: 20))) {
      if (progress.waveform != null) waveform = progress.waveform;
    }
    if (waveform == null || waveform.length <= 0) {
      debugPrint('[AudioEnvelope] just_waveform produced no data for $audioFilePath');
      return null;
    }

    final buckets = List<double>.generate(waveform.length, (i) {
      return (waveform!.getPixelMax(i) - waveform.getPixelMin(i)).abs().toDouble();
    });
    final maxV = buckets.fold<double>(0.0, (a, v) => v > a ? v : a);
    debugPrint('[AudioEnvelope] just_waveform decoded ${buckets.length} buckets '
        'for $audioFilePath (peak=$maxV)');
    if (maxV > 0.0001) {
      for (int i = 0; i < buckets.length; i++) {
        buckets[i] = (buckets[i] / maxV).clamp(0.0, 1.0);
      }
    }
    unawaited(_saveCachedEnvelope(audioFilePath, buckets));
    return buckets;
  } catch (e, st) {
    debugPrint('[AudioEnvelope] just_waveform failed for $audioFilePath: $e\n$st');
    return null;
  } finally {
    if (waveFile != null) {
      unawaited(waveFile.delete().catchError((_) => waveFile!));
    }
  }
}
