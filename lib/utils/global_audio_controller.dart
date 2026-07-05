// lib/utils/global_audio_controller.dart
import 'dart:async';
import 'dart:math' show pow;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_envelope_extractor.dart'
    show computeCompressedEnvelope, computeWavEnvelope;

const String _kVolumePrefsKey = 'global_audio_volume';

typedef AudioSeekCallback = Future<void> Function(Duration);
typedef AudioSpeedCallback = Future<void> Function(double);

class _PlaylistItem {
  final String chatId;
  final String filename;
  final VoidCallback play;
  final int order;
  _PlaylistItem({
    required this.chatId,
    required this.filename,
    required this.play,
    required this.order,
  });
}

/// Global singleton that tracks whichever audio/voice message is currently
/// playing. VoiceMessagePlayer registers itself here on play, the
/// VinylPlayerButton + FullPlayerSheet listen and show controls.
class GlobalAudioController extends ChangeNotifier {
  String? _trackName;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isActive = false;
  bool _isFile = false;
  int _sessionId = 0;
  String? _currentChatId;
  String? _currentFilename;
  String? _artPath;

  VoidCallback? _onPlayPause;
  VoidCallback? _onStop;
  AudioSeekCallback? _onSeek;
  AudioSpeedCallback? _onSetSpeed;
  AudioSpeedCallback? _onSetVolume;

  // ── Playlist ───────────────────────────────────────────────────────────────
  // Map from chatId → list of registered voice messages in insertion order.
  // Entries are never explicitly removed (stale callbacks check mounted).
  // On re-registration of the same filename the old entry is replaced.
  final Map<String, List<_PlaylistItem>> _playlists = {};
  int _sortCounter = 0;

  // ── Settings ───────────────────────────────────────────────────────────────
  bool _autoPlay = false;
  double _playbackSpeed = 1.0;
  // Persists across tracks — a user who turns it down expects it to stay
  // down for the next voice message/file too, not reset to 100%.
  double _volume = 1.0;
  // true = Stretch (time-stretch, pitch preserved); false = Resample (pitch tracks speed)
  bool _isStretchMode = true;
  // false = speed slider snaps to 0.25 steps (default); true = free continuous drag.
  bool _speedUnlocked = false;

  // ── Adopted player ─────────────────────────────────────────────────────────
  AudioPlayer? _adoptedPlayer;
  StreamSubscription<Duration>? _adoptedPosSub;
  StreamSubscription<Duration?>? _adoptedDurSub;
  StreamSubscription<PlayerState>? _adoptedStateSub;

  // ── Reactive glow ──────────────────────────────────────────────────────────
  // Drives the pulsing glow around the vinyl/artwork. Where a real decoded
  // envelope is available (WAV everywhere, mp3/m4a/aac/ogg/flac on
  // Android/iOS/macOS via just_waveform — see audio_envelope_extractor.dart)
  // this runs a fast-attack/slow-release follower over the track's actual
  // loudness at ~kEnvelopeBucketMs resolution, so individual hits/transients
  // snap the glow up and it fades back down like a VU meter needle, instead
  // of a smooth wavy pulse. Elsewhere (Windows/Linux, or any format neither
  // decoder handles) there's no real per-instant loudness to react to, so
  // the glow just holds steady at a brightness proportional to the playback
  // volume instead of pulsing at all.
  final ValueNotifier<double> glowEnergy = ValueNotifier<double>(0.0);
  Timer? _glowTimer;
  List<double>? _envelope;
  // Wall-clock time _position was last updated, so _tickGlow (60ms ticks)
  // can extrapolate a finer-grained position between just_audio's coarser
  // (~200ms) position-stream updates — otherwise most envelope buckets
  // between two updates would never get sampled and hits would be missed.
  DateTime? _positionUpdatedAt;
  // Track-time (ms) position already scanned into the envelope, so each
  // tick can scan forward over every bucket crossed since the last tick and
  // take the loudest one, rather than only sampling wherever this tick
  // happens to land.
  double _envelopeScanMs = 0.0;

  void _startGlowTimer() {
    _glowTimer?.cancel();
    _glowTimer = Timer.periodic(const Duration(milliseconds: 60), (_) => _tickGlow());
  }

  void _stopGlowTimer() {
    _glowTimer?.cancel();
    _glowTimer = null;
    glowEnergy.value = 0.0;
  }

  /// Scans the envelope from the last-sampled track position up to an
  /// extrapolated "now" position, returning the loudest bucket crossed.
  /// Returns null if there's no real envelope for the current track.
  double? _envelopeEnergyForTick() {
    final env = _envelope;
    final durationMs = _duration.inMilliseconds;
    if (env == null || env.isEmpty || durationMs <= 0) return null;

    double estimatedMs = _position.inMilliseconds.toDouble();
    final updatedAt = _positionUpdatedAt;
    if (updatedAt != null) {
      estimatedMs +=
          DateTime.now().difference(updatedAt).inMilliseconds * _playbackSpeed;
    }
    estimatedMs = estimatedMs.clamp(0.0, durationMs.toDouble());

    final bucketMs = durationMs / env.length;
    final currentIdx = (estimatedMs / bucketMs).floor().clamp(0, env.length - 1);
    final lastIdx = (_envelopeScanMs / bucketMs).floor().clamp(0, env.length - 1);
    _envelopeScanMs = estimatedMs;

    // currentIdx <= lastIdx covers both a seek backward and "same bucket as
    // last tick"; a huge forward jump (seek forward) isn't a real
    // hit-by-hit scan, so just sample the destination in both cases.
    if (currentIdx <= lastIdx || currentIdx - lastIdx > 40) {
      return env[currentIdx];
    }
    double maxV = 0.0;
    for (int i = lastIdx + 1; i <= currentIdx; i++) {
      if (env[i] > maxV) maxV = env[i];
    }
    return maxV;
  }

  void _tickGlow() {
    if (_isPlaying) {
      final envelopeEnergy = _envelopeEnergyForTick();
      if (envelopeEnergy != null) {
        // A raw RMS/peak envelope reads as "always kind of glowing" — most
        // of a track sits in the middle of the range, so quiet and loud
        // parts don't look very different. Push it through a gamma curve to
        // widen that gap (quiet passages get pulled down harder than loud
        // ones stay pulled down) and gate near-silence to fully off, so the
        // glow visibly punches on hits instead of just wavering.
        double shaped = envelopeEnergy < 0.05 ? 0.0 : pow(envelopeEnergy, 1.7).toDouble();
        // Near-instant attack, moderately quick release — a hit should snap
        // the glow up in a single tick and fade out over a handful of
        // ticks, like a subwoofer-reactive light, not a slow smooth wave.
        final rate = shaped > glowEnergy.value ? 0.95 : 0.35;
        glowEnergy.value += (shaped - glowEnergy.value) * rate;
        return;
      }
      // No real envelope for this format/platform: steady (non-pulsing)
      // glow keyed to actual playback volume — louder = brighter, quieter =
      // dimmer.
      glowEnergy.value = (0.15 + 0.85 * _volume).clamp(0.0, 1.0);
    } else {
      // Smooth decay toward 0 (~400ms) instead of an instant cutoff.
      glowEnergy.value = glowEnergy.value * 0.65;
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get trackName => _trackName;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isActive => _isActive;
  bool get isFile => _isFile;
  bool get autoPlay => _autoPlay;
  double get playbackSpeed => _playbackSpeed;
  double get volume => _volume;
  bool get isStretchMode => _isStretchMode;
  bool get speedUnlocked => _speedUnlocked;
  /// Local path to the extracted embedded cover art for the current track,
  /// or null if none has been found (yet, or at all). Set asynchronously by
  /// [setArt] after playback starts — see lib/utils/audio_art_extractor.dart.
  String? get artPath => _artPath;

  bool get hasNext {
    if (_currentChatId == null || _currentFilename == null) return false;
    final list = _playlists[_currentChatId] ?? [];
    final idx = list.indexWhere((e) => e.filename == _currentFilename);
    return idx >= 0 && idx < list.length - 1;
  }

  bool get hasPrev {
    if (_currentChatId == null || _currentFilename == null) return false;
    final list = _playlists[_currentChatId] ?? [];
    final idx = list.indexWhere((e) => e.filename == _currentFilename);
    return idx > 0;
  }

  // ── Playlist management ────────────────────────────────────────────────────

  /// Registers (or re-registers) a track in its chat's playlist.
  /// Call from VoiceMessagePlayer.initState.
  void registerTrack(String chatId, String filename, VoidCallback play) {
    final list = _playlists.putIfAbsent(chatId, () => []);
    list.removeWhere((e) => e.filename == filename);
    list.add(_PlaylistItem(
      chatId: chatId,
      filename: filename,
      play: play,
      order: _sortCounter++,
    ));
    list.sort((a, b) => a.order.compareTo(b.order));
  }

  void playNext() {
    if (_currentChatId == null || _currentFilename == null) return;
    final list = _playlists[_currentChatId] ?? [];
    final idx = list.indexWhere((e) => e.filename == _currentFilename);
    if (idx >= 0 && idx < list.length - 1) list[idx + 1].play();
  }

  void playPrev() {
    if (_currentChatId == null || _currentFilename == null) return;
    final list = _playlists[_currentChatId] ?? [];
    final idx = list.indexWhere((e) => e.filename == _currentFilename);
    if (idx > 0) list[idx - 1].play();
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  void setAutoPlay(bool v) {
    _autoPlay = v;
    notifyListeners();
  }

  void setSpeedMode(bool stretch) {
    if (_isStretchMode == stretch) return;
    _isStretchMode = stretch;
    _onSetSpeed?.call(_playbackSpeed);
    notifyListeners();
  }

  void setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    _onSetSpeed?.call(speed);
    notifyListeners();
  }

  void setSpeedUnlocked(bool v) {
    _speedUnlocked = v;
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _onSetVolume?.call(_volume);
    notifyListeners();
    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setDouble(_kVolumePrefsKey, _volume)),
    );
  }

  /// Restores the volume the user last set, so reopening the app resumes
  /// at that level instead of always starting at 100% (which meant a track
  /// could suddenly blast at full volume after a quiet session). Call once
  /// at app startup, before any track can start playing.
  Future<void> loadPersistedVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kVolumePrefsKey);
    if (saved != null) _volume = saved.clamp(0.0, 1.0);
  }

  // ── Session management ─────────────────────────────────────────────────────

  /// Call when a player starts. Returns the session ID that the caller must
  /// pass back to [updateState] and [deactivate]. A new session automatically
  /// stops the previous one.
  int activate({
    required String trackName,
    required bool isFile,
    required VoidCallback onPlayPause,
    required VoidCallback onStop,
    required AudioSeekCallback onSeek,
    AudioSpeedCallback? onSetSpeed,
    AudioSpeedCallback? onSetVolume,
    String? chatId,
    String? filename,
  }) {
    final previousStop = _onStop;
    _sessionId++;
    final id = _sessionId;

    _cleanAdopted();

    _trackName = trackName;
    _isFile = isFile;
    _isActive = true;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _onPlayPause = onPlayPause;
    _onStop = onStop;
    _onSeek = onSeek;
    _onSetSpeed = onSetSpeed;
    _onSetVolume = onSetVolume;
    _currentChatId = chatId;
    _currentFilename = filename;
    _artPath = null;
    _envelope = null;
    _positionUpdatedAt = DateTime.now();
    _envelopeScanMs = 0.0;
    _startGlowTimer();
    notifyListeners();

    // Apply the persisted volume AND speed to the freshly created player — a
    // new AudioPlayer instance always starts at 100%/1.0x, so without this
    // every new track would briefly play at the wrong volume/speed before
    // jumping to the user's chosen setting (the caller must not also apply
    // speed again after play() — that's what caused the audible 1x-then-jump
    // stutter previously).
    onSetVolume?.call(_volume);
    onSetSpeed?.call(_playbackSpeed);

    // Stop the previous session AFTER registering new callbacks.
    previousStop?.call();

    return id;
  }

  void updateState({
    required int sessionId,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) {
    if (sessionId != _sessionId) return;
    _position = position;
    _positionUpdatedAt = DateTime.now();
    _duration = duration;
    _isPlaying = isPlaying;
    notifyListeners();
  }

  void deactivate(int sessionId) {
    if (sessionId != _sessionId) return;
    _cleanAdopted();
    _isActive = false;
    _isPlaying = false;
    _artPath = null;
    _envelope = null;
    _stopGlowTimer();
    notifyListeners();
  }

  void playPause() => _onPlayPause?.call();

  void stopAndClose() {
    _onStop?.call();
    _cleanAdopted();
    _isActive = false;
    _isPlaying = false;
    _artPath = null;
    _envelope = null;
    _stopGlowTimer();
    notifyListeners();
  }

  /// Called by whoever started playback once embedded cover-art extraction
  /// (async, off the playback critical path) resolves — see
  /// lib/utils/audio_art_extractor.dart. Ignored if a newer session has since
  /// taken over.
  void setArt(int sessionId, String? path) {
    if (sessionId != _sessionId) return;
    _artPath = path;
    notifyListeners();
  }

  /// Called by whoever started playback once the real amplitude envelope
  /// (async, off the playback critical path) resolves — see
  /// lib/utils/audio_envelope_extractor.dart. Tries the pure-Dart WAV decoder
  /// first, then falls back to just_waveform's native decode (Android/iOS/
  /// macOS only) for compressed formats. Ignored if a newer session has
  /// since taken over, or if neither could decode the file (glow keeps using
  /// the synthetic fallback in that case).
  void loadEnvelope(int sessionId, String audioFilePath) {
    computeWavEnvelope(audioFilePath).then((env) async {
      if (sessionId != _sessionId) return;
      if (env != null) {
        _envelope = env;
        debugPrint('[AudioEnvelope] using WAV envelope for glow ($audioFilePath)');
        return;
      }
      final compressedEnv = await computeCompressedEnvelope(audioFilePath);
      if (sessionId != _sessionId) return;
      if (compressedEnv == null) {
        debugPrint('[AudioEnvelope] no real envelope for $audioFilePath — '
            'glow falls back to steady volume-based brightness');
        return;
      }
      _envelope = compressedEnv;
      debugPrint('[AudioEnvelope] using native-decoded envelope for glow ($audioFilePath)');
    });
  }

  Future<void> seek(Duration d) async => _onSeek?.call(d);

  /// Takes ownership of [player] from a disposed widget so audio keeps playing.
  void adoptPlayer(
    AudioPlayer player,
    int sessionId,
    Duration position,
    Duration duration,
  ) {
    if (sessionId != _sessionId) {
      player.dispose();
      return;
    }

    _cleanAdopted();
    _adoptedPlayer = player;
    _position = position;
    _positionUpdatedAt = DateTime.now();
    _duration = duration;

    _adoptedStateSub = player.playerStateStream.listen((state) {
      if (sessionId != _sessionId) return;
      _isPlaying = state.playing;
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _isActive = false;
        _position = Duration.zero;
        _stopGlowTimer();
        notifyListeners();
        final shouldAutoPlay = _autoPlay;
        _cleanAdopted();
        if (shouldAutoPlay) playNext();
      }
    });
    _adoptedPosSub = player.positionStream.listen((pos) {
      if (sessionId != _sessionId) return;
      _position = pos;
      _positionUpdatedAt = DateTime.now();
      notifyListeners();
    });
    _adoptedDurSub = player.durationStream.listen((dur) {
      if (sessionId != _sessionId) return;
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // Capture the session ID at adoption time so the _onStop callback can
    // tell whether a new session has already taken over (via activate()). If
    // it has, _isActive must NOT be reset — that new session owns the field.
    final adoptedSessionId = _sessionId;

    _onPlayPause = () {
      if (_isPlaying) { player.pause(); } else { player.play(); }
    };
    _onStop = () {
      // Guard against calling stop() after _cleanAdopted() has already
      // disposed the player (happens when activate() is called while adopted).
      if (_adoptedPlayer != null) player.stop();
      _cleanAdopted();
      // Only reset the active state if no new session has started since
      // adoptPlayer() was called. When activate() calls previousStop(), it
      // has already incremented _sessionId and set _isActive = true; calling
      // notifyListeners() here with isActive = false would kill the vinyl.
      if (_sessionId == adoptedSessionId) {
        _isActive = false;
        _isPlaying = false;
        _position = Duration.zero;
        _stopGlowTimer();
        notifyListeners();
      }
    };
    _onSeek = (d) => player.seek(d);
    _onSetSpeed = (s) async {
      await player.setSpeed(s);
      await player.setPitch(s);
    };
    _onSetVolume = (v) async {
      await player.setVolume(v);
    };
  }

  void _cleanAdopted() {
    _adoptedPosSub?.cancel();
    _adoptedDurSub?.cancel();
    _adoptedStateSub?.cancel();
    _adoptedPosSub = null;
    _adoptedDurSub = null;
    _adoptedStateSub = null;
    _adoptedPlayer?.dispose();
    _adoptedPlayer = null;
    _onSetSpeed = null;
    _onSetVolume = null;
  }
}

final GlobalAudioController globalAudioController = GlobalAudioController();
