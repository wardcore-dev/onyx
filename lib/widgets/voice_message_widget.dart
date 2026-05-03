// lib/widgets/voice_message_widget.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform, File, Directory;
import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../managers/account_manager.dart';
import '../managers/external_server_manager.dart';
import 'package:audio_session/audio_session.dart';
import '../globals.dart';
import '../utils/media_cache.dart';
import '../utils/global_audio_controller.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String filename;
  final String? owner;
  final String label;
  final String peerUsername;
  final String? mediaKeyB64;
  final bool isFile;
  final String? origName;
  const VoiceMessagePlayer({
    Key? key,
    required this.filename,
    this.owner,
    required this.label,
    required this.peerUsername,
    this.mediaKeyB64,
    this.isFile = false,
    this.origName,
  }) : super(key: key);

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  String? _cachedFilePath;
  AudioPlayer? _player; // created lazily on first play — avoids spawning N ExoPlayers at screen-open
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _playerReady = false; // true = source loaded, player can resume without reload
  String? _lastEnsureError;
  int? _activeSessionId;
  final List<StreamSubscription> _subs = [];

  static bool _bgConfigured = false;

  static Future<void> _configureBackground() async {
    if (_bgConfigured) return;
    _bgConfigured = true;
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      }
    } catch (e) {
      debugPrint('[VoiceWidget] Audio session config error: $e');
      _bgConfigured = false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Pre-populate cache from global registry — rebuilt widgets skip download.
    final cached = mediaFilePathRegistry[widget.filename];
    if (cached != null) {
      if (!kIsWeb && File(cached).existsSync()) {
        _cachedFilePath = cached;
      } else {
        mediaFilePathRegistry.remove(widget.filename);
      }
    }

    // Register in the chat playlist for prev/next navigation.
    globalAudioController.registerTrack(
      widget.peerUsername,
      widget.filename,
      () { _loadAndPlay(); },
    );

    _configureBackground();
    // AudioPlayer is created lazily on first play tap — see _initPlayer().
  }

  // Creates the AudioPlayer and wires its streams. Called once, on first play.
  void _initPlayer() {
    if (_player != null) return;
    final p = AudioPlayer();
    _player = p;

    _subs.add(p.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      final ps = state.processingState;
      final buffering = ps == ProcessingState.loading || ps == ProcessingState.buffering;
      setState(() {
        _isPlaying = playing;
        if (_playerReady) _isLoading = buffering && !playing;
      });
      if (_activeSessionId != null) {
        globalAudioController.updateState(
          sessionId: _activeSessionId!,
          position: _position,
          duration: _duration,
          isPlaying: playing,
        );
      }
      if (ps == ProcessingState.completed) {
        setState(() { _isPlaying = false; _position = Duration.zero; });
        if (_activeSessionId != null) {
          globalAudioController.updateState(
            sessionId: _activeSessionId!,
            position: Duration.zero,
            duration: _duration,
            isPlaying: false,
          );
          if (globalAudioController.autoPlay) globalAudioController.playNext();
        }
      }
    }));
    _subs.add(p.durationStream.listen((duration) {
      if (!mounted) return;
      final d = duration ?? Duration.zero;
      setState(() => _duration = d);
      if (_activeSessionId != null) {
        globalAudioController.updateState(
          sessionId: _activeSessionId!,
          position: _position,
          duration: d,
          isPlaying: _isPlaying,
        );
      }
    }));
    _subs.add(p.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
      if (_activeSessionId != null) {
        globalAudioController.updateState(
          sessionId: _activeSessionId!,
          position: position,
          duration: _duration,
          isPlaying: _isPlaying,
        );
      }
    }));
  }

  @override
  void dispose() {
    // Cancel widget-level subscriptions so callbacks stop calling setState.
    for (final s in _subs) { s.cancel(); }
    _subs.clear();

    if (_activeSessionId != null && _playerReady && _player != null) {
      // Hand ownership of the player to the global controller so audio
      // keeps playing (or can be resumed) after this widget is removed from
      // the tree. Adopt on any loaded state — not just _isPlaying — so a
      // transient buffering/paused moment doesn't accidentally kill the session.
      globalAudioController.adoptPlayer(
          _player!, _activeSessionId!, _position, _duration);
      _activeSessionId = null;
    } else {
      if (_activeSessionId != null) {
        globalAudioController.deactivate(_activeSessionId!);
        _activeSessionId = null;
      }
      _player?.dispose();
    }
    super.dispose();
  }

  static Uint8List? _ensureStandardPcm16(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final bd = ByteData.sublistView(bytes);

    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') return null;

    int audioFormat = 0, numChannels = 0, sampleRate = 0, bitsPerSample = 0;
    int dataStart = 0, dataLength = 0;

    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final chunkSize = bd.getUint32(pos + 4, Endian.little);

      if (id == 'fmt ') {
        audioFormat = bd.getUint16(pos + 8, Endian.little);
        numChannels = bd.getUint16(pos + 10, Endian.little);
        sampleRate = bd.getUint32(pos + 12, Endian.little);
        bitsPerSample = bd.getUint16(pos + 22, Endian.little);
        
        if (audioFormat == 0xFFFE && chunkSize >= 26) {
          audioFormat = bd.getUint16(pos + 8 + 24, Endian.little);
        }
      } else if (id == 'data') {
        dataStart = pos + 8;
        dataLength = chunkSize;
        break;
      }
      pos += 8 + chunkSize + (chunkSize & 1); 
    }

    debugPrint('[VoiceWidget] WAV fmt=$audioFormat ch=$numChannels '
        'rate=${sampleRate}Hz bits=$bitsPerSample dataBytes=$dataLength');

    if (audioFormat == 1 && bitsPerSample == 16) {
      if (dataLength == 0 && dataStart > 0) {
        
        final actualDataSize = bytes.length - dataStart;
        final patched = Uint8List.fromList(bytes);
        final pBd = ByteData.sublistView(patched);
        pBd.setUint32(4, bytes.length - 8, Endian.little);      
        pBd.setUint32(dataStart - 4, actualDataSize, Endian.little); 
        debugPrint('[VoiceWidget] Patched streaming WAV: dataSize=$actualDataSize');
        return patched;
      }
      return null; 
    }
    if (dataStart == 0 || numChannels == 0 || sampleRate == 0) return null;

    final audioData = bytes.sublist(dataStart, min(dataStart + dataLength, bytes.length));
    late Uint8List pcm16;

    if (audioFormat == 3 && bitsPerSample == 32) {
      
      final n = audioData.length ~/ 4;
      pcm16 = Uint8List(n * 2);
      final inBd = ByteData.sublistView(audioData);
      final outBd = ByteData.sublistView(pcm16);
      for (int i = 0; i < n; i++) {
        final f = inBd.getFloat32(i * 4, Endian.little).clamp(-1.0, 1.0);
        outBd.setInt16(i * 2, (f * 32767.0).round(), Endian.little);
      }
    } else if (audioFormat == 1 && bitsPerSample == 32) {
      
      final n = audioData.length ~/ 4;
      pcm16 = Uint8List(n * 2);
      final inBd = ByteData.sublistView(audioData);
      final outBd = ByteData.sublistView(pcm16);
      for (int i = 0; i < n; i++) {
        outBd.setInt16(i * 2, inBd.getInt32(i * 4, Endian.little) >> 16, Endian.little);
      }
    } else if (audioFormat == 1 && bitsPerSample == 24) {
      
      final n = audioData.length ~/ 3;
      pcm16 = Uint8List(n * 2);
      final outBd = ByteData.sublistView(pcm16);
      for (int i = 0; i < n; i++) {
        int s = audioData[i * 3] | (audioData[i * 3 + 1] << 8) | (audioData[i * 3 + 2] << 16);
        if (s >= 0x800000) s -= 0x1000000;
        outBd.setInt16(i * 2, s >> 8, Endian.little);
      }
    } else {
      debugPrint('[VoiceWidget] Unsupported WAV fmt=$audioFormat bits=$bitsPerSample, skipping conversion');
      return null;
    }

    final dataSize = pcm16.length;
    final out = Uint8List(44 + dataSize);
    final outBd = ByteData.sublistView(out);
    out.setAll(0,  [82, 73, 70, 70]); 
    outBd.setUint32(4, 36 + dataSize, Endian.little);
    out.setAll(8,  [87, 65, 86, 69]); 
    out.setAll(12, [102, 109, 116, 32]); 
    outBd.setUint32(16, 16, Endian.little);
    outBd.setUint16(20, 1, Endian.little); 
    outBd.setUint16(22, numChannels, Endian.little);
    outBd.setUint32(24, sampleRate, Endian.little);
    outBd.setUint32(28, sampleRate * numChannels * 2, Endian.little);
    outBd.setUint16(32, numChannels * 2, Endian.little);
    outBd.setUint16(34, 16, Endian.little);
    out.setAll(36, [100, 97, 116, 97]); 
    outBd.setUint32(40, dataSize, Endian.little);
    out.setAll(44, pcm16);

    debugPrint('[VoiceWidget] Converted to PCM16: ${out.length} bytes');
    return out;
  }

  // Sets the source, starts playback, registers with the global controller.
  Future<void> _startPlayback(String filePath) async {
    _initPlayer(); // no-op if already created
    final p = _player!;

    await p.setAudioSource(AudioSource.uri(Uri.file(filePath)));
    _playerReady = true;

    // Activate BEFORE play() so ExoPlayer's initial state events (playing,
    // duration, position) are forwarded to the global controller immediately.
    _activeSessionId = globalAudioController.activate(
      trackName: widget.origName?.isNotEmpty == true
          ? widget.origName!
          : (widget.label.isNotEmpty ? widget.label : widget.filename),
      isFile: widget.isFile,
      onPlayPause: () {
        if (_isPlaying) { p.pause(); } else { p.play(); }
      },
      onStop: () {
        p.stop();
        _playerReady = false;
        _activeSessionId = null;
        if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
      },
      onSeek: (d) => p.seek(d),
      onSetSpeed: (s) async {
        try {
          await p.setSpeed(s);
          await p.setPitch(s);
        } catch (_) {}
      },
      chatId: widget.peerUsername,
      filename: widget.filename,
    );

    await p.play();
    final speed = globalAudioController.playbackSpeed;
    if (speed != 1.0) {
      try {
        await p.setSpeed(speed);
        await p.setPitch(speed);
      } catch (_) {}
    }
  }

  Future<void> _loadAndPlay() async {
    if (_isPlaying) {
      // _isPlaying is only true after _initPlayer() has run.
      await _player!.pause();
      return;
    }

    // Source already loaded and session live — just resume (no reload).
    if (_playerReady) {
      // _playerReady is only true after _initPlayer() has run.
      final p = _player!;
      if (p.processingState == ProcessingState.completed) {
        await p.seek(Duration.zero);
      }
      await p.play();
      return;
    }

    // Fast path: file already cached — skip all download/decrypt logic.
    if (_cachedFilePath != null && File(_cachedFilePath!).existsSync()) {
      setState(() => _isLoading = true);
      try {
        await _startPlayback(_cachedFilePath!);
      } catch (e) {
        debugPrint('[VoiceWidget] Fast-path replay error: $e');
        _cachedFilePath = null; // force re-download on next tap
        rootScreenKey.currentState?.showSnack('Play error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (widget.peerUsername == '<external>' && widget.filename.startsWith('http')) {
      setState(() => _isLoading = true);
      try {
        
        final appSupport = await getApplicationDocumentsDirectory();
        final cacheDir = Directory(p.join(appSupport.path, 'voice_cache'));
        await cacheDir.create(recursive: true);

        final uri = Uri.parse(widget.filename);
        final safeName = uri.pathSegments.last.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
        final cachedFile = File(p.join(cacheDir.path, safeName));

        if (!(await cachedFile.exists())) {
          debugPrint('[VoiceWidget] Downloading external voice: ${widget.filename}');

          var url = widget.filename;
          if (!url.contains('?token=') && !url.contains('&token=')) {
            final servers = ExternalServerManager.servers.value;
            final matching = servers.where(
              (s) => s.host == uri.host && s.port == uri.port,
            ).toList();
            if (matching.isNotEmpty) {
              url = '$url?token=${Uri.encodeComponent(matching.first.token)}';
              debugPrint('[VoiceWidget] Added auth token to URL');
            }
          }

          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await cachedFile.writeAsBytes(res.bodyBytes);
            debugPrint('[VoiceWidget] Downloaded ${res.bodyBytes.length} bytes to ${cachedFile.path}');
          } else {
            throw Exception('HTTP ${res.statusCode}');
          }
        } else {
          debugPrint('[VoiceWidget] Using cached file: ${cachedFile.path}');
        }

        if (!await cachedFile.exists()) {
          throw Exception('Cached file does not exist');
        }
        final fileSize = await cachedFile.length();
        if (fileSize == 0) {
          throw Exception('Cached file is empty');
        }
        debugPrint('[VoiceWidget] Playing file: ${cachedFile.path} (size: $fileSize bytes)');

        File playFile = cachedFile;
        if (!kIsWeb &&
            p.extension(cachedFile.path).toLowerCase() == '.wav') {
          final raw = await cachedFile.readAsBytes();
          final converted = _ensureStandardPcm16(raw);
          if (converted != null) {
            final convertedPath = p.join(
              p.dirname(cachedFile.path),
              '${p.basenameWithoutExtension(cachedFile.path)}_c16.wav',
            );
            playFile = File(convertedPath);
            await playFile.writeAsBytes(converted);
            debugPrint('[VoiceWidget] Using converted PCM16: $convertedPath');
          }
        }

        _cachedFilePath = playFile.path;
        mediaFilePathRegistry[widget.filename] = playFile.path;
        await _startPlayback(playFile.path);
      } catch (e) {
        debugPrint('[VoiceWidget] Error: $e');
        rootScreenKey.currentState?.showSnack('Play error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    Future<File?> _ensureVoiceCached() async {
      try {
        debugPrint('[VoiceWidget] Loading voice: "${widget.filename}"');

        if (widget.isFile) {
          final root = rootScreenKey.currentState;
          if (root == null) {
            _lastEnsureError = 'RootScreen not ready';
            return null;
          }
          final f = await root.downloadFileToCache(
            widget.filename,
            peerUsername: widget.peerUsername,
            owner: widget.owner,
            mediaKeyB64: widget.mediaKeyB64,
          );
          if (f == null) _lastEnsureError = _lastEnsureError ?? 'File not found';
          return f;
        }

        if (widget.filename.startsWith('lan://')) {
          debugPrint('[VoiceWidget] LAN file detected: ${widget.filename}');
          final lanFilename = widget.filename.substring(6);
          final appDocuments = await getApplicationDocumentsDirectory();
          final lanFile = File('${appDocuments.path}/lan_media/$lanFilename');
          if (await lanFile.exists()) {
            return lanFile;
          } else {
            _lastEnsureError = 'LAN file not found: $lanFilename';
            return null;
          }
        }

        if (widget.filename.startsWith('fav://')) {
          debugPrint('[VoiceWidget] Favorites local file: ${widget.filename}');
          final favFilename = widget.filename.substring(6);
          final appDocuments = await getApplicationDocumentsDirectory();
          final favFile = File('${appDocuments.path}/voice_cache/$favFilename');
          if (await favFile.exists()) {
            return favFile;
          } else {
            _lastEnsureError = 'Favorites voice file not found locally';
            return null;
          }
        }

        final appSupport = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${appSupport.path}/voice_cache');
        await cacheDir.create(recursive: true);
        final displayDir = await MediaCache.instance.displayDirFor('voice');

        final possibleExts = ['', '.ogg', '.opus', '.m4a', '.mp3', '.wav'];
        final candidateNames = possibleExts
            .map((ext) => widget.filename.endsWith(ext) || ext.isEmpty
                ? widget.filename
                : '${widget.filename}$ext')
            .toList();
        final existingCached = await MediaCache.instance.findCachedDisplay(
            cacheDir, candidateNames, displayDir);
        if (existingCached != null) return existingCached;

        final token = await AccountManager.getToken(
          await AccountManager.getCurrentAccount() ?? '',
        );
        if (token == null) {
          _lastEnsureError = 'Not logged in';
          return null;
        }

        final voiceUrl = widget.filename.startsWith('http')
            ? widget.filename
            : (widget.owner != null && widget.owner!.isNotEmpty)
                ? '$serverBase/voice/${widget.owner}/${widget.filename}'
                : '$serverBase/voice/${widget.filename}';
        final res = await http.get(
          Uri.parse(voiceUrl),
          headers: {'authorization': 'Bearer $token'},
        );

        if (res.statusCode == 404) {
          _lastEnsureError = 'File not found on server (404)';
          return null;
        }
        if (res.statusCode != 200) {
          _lastEnsureError = 'HTTP ${res.statusCode}';
          return null;
        }

        final cipherBytes = res.bodyBytes;
        if (cipherBytes.isEmpty) {
          _lastEnsureError = 'Empty file';
          return null;
        }
        
        debugPrint('[VoiceWidget] Downloaded: ${cipherBytes.length} bytes, filename: ${widget.filename}, from: ${widget.peerUsername}');

        final bool isExternal = widget.filename.startsWith('http');
        
        Uint8List bytes;
        if (isExternal) {
          bytes = cipherBytes;
          debugPrint('[VoiceWidget] External URL: ${cipherBytes.length} bytes (no decryption)');
        } else {
          final root = rootScreenKey.currentState;
          if (root == null) {
            _lastEnsureError = 'RootScreen not ready';
            return null;
          }
          bytes = await root.decryptMediaFromPeer(
            widget.peerUsername,
            cipherBytes,
            kind: 'voice',
            mediaKeyB64: widget.mediaKeyB64,
          );
          debugPrint('[VoiceWidget] After decrypt: ${bytes.length} bytes, same as download: ${bytes.length == cipherBytes.length}');
        }

        String outName = widget.filename;
        if (!_isOgg(bytes) &&
            !_isM4A(bytes) &&
            !_isWav(bytes) &&
            !_isMp3(bytes) &&
            !_isRawOpus(bytes)) {
          debugPrint('[VoiceWidget] File format not recognized after decrypt (${bytes.take(4).toList()}), forcing .m4a');
          outName = widget.filename.endsWith('.m4a')
              ? widget.filename
              : '${widget.filename}.m4a';
        }
        final safeName = _sanitizeFilename(outName);

        await MediaCache.instance.writeEncrypted(cacheDir, safeName, bytes);
        final displayFile = File('${displayDir.path}/$safeName');
        // Don't overwrite if file already exists — it may be held open by the player
        if (!await displayFile.exists() || await displayFile.length() == 0) {
          await displayFile.writeAsBytes(bytes, flush: true);
        }
        return displayFile;
      } catch (e, st) {
        _lastEnsureError = e.toString();
        debugPrint('Voice cache error: $e\n$st');
        return null;
      }
    }

    final rootState = rootScreenKey.currentState;
    if (rootState == null) return;
    setState(() => _isLoading = true);
    try {
      final cachedFile = await _ensureVoiceCached();
      if (cachedFile == null) {
        rootScreenKey.currentState?.showSnack('Play failed: ${_lastEnsureError ?? 'Unknown'}');
        return;
      }
      
      File playFile = cachedFile;
      if (!kIsWeb &&
          p.extension(cachedFile.path).toLowerCase() == '.wav') {
        final raw = await cachedFile.readAsBytes();
        final converted = _ensureStandardPcm16(raw);
        if (converted != null) {
          final convertedPath = p.join(
            p.dirname(cachedFile.path),
            '${p.basenameWithoutExtension(cachedFile.path)}_c16.wav',
          );
          playFile = File(convertedPath);
          await playFile.writeAsBytes(converted);
          debugPrint('[VoiceWidget] Using converted PCM16: $convertedPath');
        }
      }
      _cachedFilePath = playFile.path;
      mediaFilePathRegistry[widget.filename] = playFile.path;
      await _startPlayback(playFile.path);
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Play error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveVoice() async {
    
    if (_cachedFilePath == null || !await File(_cachedFilePath!).exists()) {
      setState(() => _isLoading = true);
      _lastEnsureError = null;
      try {
        File? found; 

        if (widget.filename.startsWith('lan://')) {
          final lanFilename = widget.filename.substring(6);
          final appDocuments = await getApplicationDocumentsDirectory();
          final lanFile = File('${appDocuments.path}/lan_media/$lanFilename');
          if (await lanFile.exists()) {
            found = lanFile;
          } else {
            _lastEnsureError = 'LAN file not found: $lanFilename';
          }
        } else if (widget.isFile) {
          final root = rootScreenKey.currentState;
          if (root != null) {
            found = await root.downloadFileToCache(
              widget.filename,
              peerUsername: widget.peerUsername,
              owner: widget.owner,
              mediaKeyB64: widget.mediaKeyB64,
            );
            if (found == null) _lastEnsureError = _lastEnsureError ?? 'File not available';
          } else {
            _lastEnsureError = 'RootScreen not ready';
          }
        } else {
          final appSupport = await getApplicationDocumentsDirectory();
          final cacheDir = Directory('${appSupport.path}/voice_cache');
          await cacheDir.create(recursive: true);
          final possibleExts = ['', '.ogg', '.opus', '.m4a', '.mp3', '.wav'];
          for (final ext in possibleExts) {
            final tryName = widget.filename.endsWith(ext) || ext.isEmpty
                ? widget.filename
                : '${widget.filename}$ext';
            final f = File('${cacheDir.path}/$tryName');
            if (await f.exists()) {
              found = f;
              break;
            }
          }
          if (found == null) {
            
          final token = await AccountManager.getToken(
            await AccountManager.getCurrentAccount() ?? '',
          );
          if (token == null) {
            _lastEnsureError = 'Not logged in';
          } else {
            final voiceUrl2 = widget.filename.startsWith('http')
                ? widget.filename
                : (widget.owner != null && widget.owner!.isNotEmpty)
                    ? '$serverBase/voice/${widget.owner}/${widget.filename}'
                    : '$serverBase/voice/${widget.filename}';
            final res = await http.get(
              Uri.parse(voiceUrl2),
              headers: {'authorization': 'Bearer $token'},
            );
            if (res.statusCode == 404) {
              _lastEnsureError = 'File not found on server (404)';
            } else if (res.statusCode != 200) {
              _lastEnsureError = 'HTTP ${res.statusCode}';
            } else {
              final cipherBytes = res.bodyBytes;
              if (cipherBytes.isEmpty) {
                _lastEnsureError = 'Empty file';
              } else {
                final root = rootScreenKey.currentState;
                if (root == null) {
                  _lastEnsureError = 'RootScreen not ready';
                } else {
                  
                  final bool isExternal = widget.filename.startsWith('http');
                  final bytes = isExternal
                      ? cipherBytes
                      : await root.decryptMediaFromPeer(
                          widget.peerUsername,
                          cipherBytes,
                          kind: 'voice',
                          mediaKeyB64: widget.mediaKeyB64,
                        );
                  if (isExternal) {
                    debugPrint('[VoiceWidget] External URL - no decryption, size: ${bytes.length}');
                  }
                  String outName = widget.filename;
                  if (!_isOgg(bytes) &&
                      !_isM4A(bytes) &&
                      !_isWav(bytes) &&
                      !_isMp3(bytes) &&
                      !_isRawOpus(bytes)) {
                    outName = widget.filename.endsWith('.m4a')
                        ? widget.filename
                        : '${widget.filename}.m4a';
                  }
                  final safeName = _sanitizeFilename(outName);
                  final cachedFile = File('${cacheDir.path}/$safeName');
                  await cachedFile.writeAsBytes(bytes, flush: true);
                  found = cachedFile;
                }
              }
            }
          }
          }
        }

        if (found == null) {
          rootScreenKey.currentState?.showSnack('Voice not available to save: ${_lastEnsureError ?? 'Unknown'}');
          return;
        }

        _cachedFilePath = found.path;
        mediaFilePathRegistry[widget.filename] = found.path;
      } catch (e, st) {
        debugPrint(' ensure for save error: $e\n$st');
        rootScreenKey.currentState?.showSnack('Voice not available to save: $e');
        return;
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    try {
      final basename = p.basename(_cachedFilePath!);

      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        String? destPath;
        var dialogSupported = true;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save voice as',
            fileName: basename,
            type: FileType.custom,
            allowedExtensions: [p.extension(basename).replaceFirst('.', '')],
          );
        } catch (e) {
          
          dialogSupported = false;
          destPath = null;
        }

        if (destPath == null) {
          if (dialogSupported) {
            
            rootScreenKey.currentState?.showSnack('Save cancelled');
            return;
          }
          
          final dl = await getDownloadsDirectory();
          if (dl == null) {
            rootScreenKey.currentState?.showSnack('Cannot access save directory');
            return;
          }
          destPath = '${dl.path}/$basename';
        }

        final savedFile = File(destPath);
        await File(_cachedFilePath!).copy(savedFile.path);
        rootScreenKey.currentState?.showSnack('Saved to: ${savedFile.path}');
        return; 
      }

      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack('Save not supported on web — open the voice and save');
        return;
      }

      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getDownloadsDirectory();
      }
      if (targetDir == null) {
        rootScreenKey.currentState?.showSnack('Cannot access save directory');
        return;
      }

      final destPath = '${targetDir.path}/$basename';
      final savedFile = File(destPath);
      await File(_cachedFilePath!).copy(savedFile.path);
      rootScreenKey.currentState?.showSnack('Saved to: ${savedFile.path}');

      if (Platform.isAndroid) await OpenFilex.open(savedFile.path);
    } catch (e, st) {
      debugPrint(' _saveVoice error: $e\n$st');
      rootScreenKey.currentState?.showSnack(' Save failed: $e');
    }
  }

  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  static bool _isOgg(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
  }

  static bool _isM4A(List<int> bytes) {
    if (bytes.length < 8) return false;
    return String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp';
  }

  static bool _isWav(List<int> bytes) {
    if (bytes.length < 12) return false;
    return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE';
  }

  static bool _isMp3(List<int> bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
  }

  static bool _isRawOpus(List<int> bytes) {
    if (bytes.length < 8) return false;
    return String.fromCharCodes(bytes.sublist(0, 8)) == 'OpusHead';
  }

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.origName != null && widget.origName!.isNotEmpty) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note, size: 12, color: fg.withValues(alpha: 0.5)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  widget.origName!,
                  style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.6)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
        ],
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: _isLoading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 18,
                      color: fg,
                    ),
              onPressed: _loadAndPlay,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            
            const SizedBox(width: 6),
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                ),
                child: Slider(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds.toDouble()
                      : 0,
                  max: _duration.inMilliseconds.toDouble(),
                  onChanged: (value) async {
                    final newPosition = Duration(milliseconds: value.toInt());
                    if (_duration == Duration.zero || _player == null) return;
                    await _player!.seek(newPosition);
                    if (!_isPlaying) {
                      await Future.delayed(const Duration(milliseconds: 10));
                      await _player!.pause();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${d.inMinutes}:${twoDigits(d.inSeconds.remainder(60))}';
  }
}