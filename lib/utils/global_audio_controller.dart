// lib/utils/global_audio_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

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

  VoidCallback? _onPlayPause;
  VoidCallback? _onStop;
  AudioSeekCallback? _onSeek;
  AudioSpeedCallback? _onSetSpeed;

  // ── Playlist ───────────────────────────────────────────────────────────────
  // Map from chatId → list of registered voice messages in insertion order.
  // Entries are never explicitly removed (stale callbacks check mounted).
  // On re-registration of the same filename the old entry is replaced.
  final Map<String, List<_PlaylistItem>> _playlists = {};
  int _sortCounter = 0;

  // ── Settings ───────────────────────────────────────────────────────────────
  bool _autoPlay = false;
  double _playbackSpeed = 1.0;
  // true = Stretch (time-stretch, pitch preserved); false = Resample (pitch tracks speed)
  bool _isStretchMode = true;

  // ── Adopted player ─────────────────────────────────────────────────────────
  AudioPlayer? _adoptedPlayer;
  StreamSubscription<Duration>? _adoptedPosSub;
  StreamSubscription<Duration?>? _adoptedDurSub;
  StreamSubscription<PlayerState>? _adoptedStateSub;

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get trackName => _trackName;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isActive => _isActive;
  bool get isFile => _isFile;
  bool get autoPlay => _autoPlay;
  double get playbackSpeed => _playbackSpeed;
  bool get isStretchMode => _isStretchMode;

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
    _currentChatId = chatId;
    _currentFilename = filename;
    notifyListeners();

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
    _duration = duration;
    _isPlaying = isPlaying;
    notifyListeners();
  }

  void deactivate(int sessionId) {
    if (sessionId != _sessionId) return;
    _cleanAdopted();
    _isActive = false;
    _isPlaying = false;
    notifyListeners();
  }

  void playPause() => _onPlayPause?.call();

  void stopAndClose() {
    _onStop?.call();
    _cleanAdopted();
    _isActive = false;
    _isPlaying = false;
    notifyListeners();
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
    _duration = duration;

    _adoptedStateSub = player.playerStateStream.listen((state) {
      if (sessionId != _sessionId) return;
      _isPlaying = state.playing;
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _isActive = false;
        _position = Duration.zero;
        notifyListeners();
        final shouldAutoPlay = _autoPlay;
        _cleanAdopted();
        if (shouldAutoPlay) playNext();
      }
    });
    _adoptedPosSub = player.positionStream.listen((pos) {
      if (sessionId != _sessionId) return;
      _position = pos;
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
        notifyListeners();
      }
    };
    _onSeek = (d) => player.seek(d);
    _onSetSpeed = (s) async {
      await player.setSpeed(s);
      await player.setPitch(s);
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
  }
}

final GlobalAudioController globalAudioController = GlobalAudioController();
