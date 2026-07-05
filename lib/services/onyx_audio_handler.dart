// lib/services/onyx_audio_handler.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../utils/audio_art_extractor.dart';
import '../utils/global_audio_controller.dart';

/// Bridges [GlobalAudioController] — the app's single source of truth for
/// whichever voice message/audio file is playing — into a real Android
/// MediaSession via audio_service. This is what gives the system
/// notification/lock-screen widget album-art-style layout, a scrubbable
/// progress bar, and the system output-device picker, none of which are
/// available to a MediaSession-less notification.
///
/// GlobalAudioController keeps owning the actual just_audio player and
/// playback logic; this handler only mirrors its state outward and forwards
/// transport commands from the OS back into it.
class OnyxAudioHandler extends BaseAudioHandler {
  String? _lastTrackName;
  Duration? _lastDuration;
  String? _lastArtPath;

  // Precomputed eagerly (not lazily per no-art track) so there's no window
  // where the notification goes out with artUri: null and the OS's own OEM
  // default (blue-ish on some skins, e.g. Samsung One UI) shows instead of
  // the app's theme-colored placeholder while getFallbackArt() is still
  // generating the PNG.
  String? _fallbackArtPath;
  Future<String?>? _fallbackArtFuture;

  OnyxAudioHandler() {
    _fallbackArtFuture = getFallbackArt().then((path) {
      _fallbackArtPath = path;
      debugPrint('[OnyxAudioHandler] fallback art ready: $path');
      return path;
    });
    globalAudioController.addListener(_sync);
    _sync();
  }

  void _sync() {
    final ctrl = globalAudioController;

    if (!ctrl.isActive) {
      _lastTrackName = null;
      _lastDuration = null;
      _lastArtPath = null;
      mediaItem.add(null);
      playbackState.add(PlaybackState(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      return;
    }

    final trackName = ctrl.trackName ?? 'Audio';
    if (trackName != _lastTrackName ||
        ctrl.duration != _lastDuration ||
        ctrl.artPath != _lastArtPath) {
      _lastTrackName = trackName;
      _lastDuration = ctrl.duration;
      _lastArtPath = ctrl.artPath;
      // No embedded cover picture for this track. Some OEM Android skins
      // (Samsung's One UI media card among them) derive their own tint for
      // the notification/lock-screen widget from the artwork's dominant
      // color rather than fully honoring NotificationCompat.setColor(), so
      // an art-less track falls back to that skin's own default tint
      // instead of the app's theme unless *some* artUri is supplied. Use the
      // precomputed fallback immediately if it's ready — only the very
      // first no-art track before startup finishes generating it should
      // ever hit the "post with null, replace once ready" path below.
      final artUriPath = ctrl.artPath ?? _fallbackArtPath;
      mediaItem.add(MediaItem(
        id: trackName,
        title: trackName,
        artist: 'ONYX',
        duration: ctrl.duration == Duration.zero ? null : ctrl.duration,
        artUri: artUriPath != null ? Uri.file(artUriPath) : null,
      ));
      debugPrint('[OnyxAudioHandler] mediaItem for "$trackName": '
          'artPath=${ctrl.artPath} fallback=$_fallbackArtPath -> artUri=$artUriPath');
      if (ctrl.artPath == null && _fallbackArtPath == null) {
        _applyFallbackArt(trackName);
      }
    }

    final controls = <MediaControl>[
      if (ctrl.hasPrev) MediaControl.skipToPrevious,
      MediaControl.rewind,
      ctrl.isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.fastForward,
      if (ctrl.hasNext) MediaControl.skipToNext,
    ];
    // Compact view always shows rewind/play-pause/fastForward — their index
    // shifts by one if a leading skipToPrevious control is present.
    final playPauseIdx = ctrl.hasPrev ? 2 : 1;

    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: [
        playPauseIdx - 1,
        playPauseIdx,
        playPauseIdx + 1,
      ],
      processingState: AudioProcessingState.ready,
      playing: ctrl.isPlaying,
      updatePosition: ctrl.position,
    ));
  }

  Future<void> _applyFallbackArt(String trackName) async {
    // Only the very first no-art track (before the constructor's eager
    // precompute finishes) should ever reach here — reuse that in-flight
    // future instead of kicking off a second parallel getFallbackArt() call.
    final fallbackPath = await (_fallbackArtFuture ??= getFallbackArt());
    _fallbackArtPath ??= fallbackPath;
    if (fallbackPath == null) {
      debugPrint('[OnyxAudioHandler] getFallbackArt() returned null for "$trackName"');
      return;
    }
    final ctrl = globalAudioController;
    // Bail if the track changed, or real embedded art already arrived,
    // while the fallback image was being generated/loaded.
    if (ctrl.trackName != trackName || ctrl.artPath != null) return;
    mediaItem.add(MediaItem(
      id: trackName,
      title: trackName,
      artist: 'ONYX',
      duration: ctrl.duration == Duration.zero ? null : ctrl.duration,
      artUri: Uri.file(fallbackPath),
    ));
  }

  @override
  Future<void> play() async => globalAudioController.playPause();

  @override
  Future<void> pause() async => globalAudioController.playPause();

  @override
  Future<void> seek(Duration position) async =>
      globalAudioController.seek(position);

  @override
  Future<void> fastForward() async {
    final ctrl = globalAudioController;
    final fwd = ctrl.position + const Duration(seconds: 10);
    final dur = ctrl.duration;
    await ctrl.seek(dur != Duration.zero && fwd > dur ? dur : fwd);
  }

  @override
  Future<void> rewind() async {
    final ctrl = globalAudioController;
    final back = ctrl.position - const Duration(seconds: 10);
    await ctrl.seek(back.isNegative ? Duration.zero : back);
  }

  @override
  Future<void> skipToNext() async => globalAudioController.playNext();

  @override
  Future<void> skipToPrevious() async => globalAudioController.playPrev();

  @override
  Future<void> stop() async {
    globalAudioController.stopAndClose();
    await super.stop();
  }
}
