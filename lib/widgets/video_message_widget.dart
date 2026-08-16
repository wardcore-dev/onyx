// lib/widgets/video_message_widget.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show SystemChrome, SystemUiMode, SystemUiOverlay;
import 'dart:io' show File, Directory, Platform;
import 'package:http/http.dart' as http;
import '../utils/onyx_base_dir.dart'
    show getOnyxDocumentsDirectory, getOnyxSupportDirectory;
import 'package:path/path.dart' as p;
import '../utils/file_utils.dart' show getOnyxSaveDirectory, showSavedToSnack;
import 'package:file_picker/file_picker.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../managers/account_manager.dart';
import '../managers/external_server_manager.dart';
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import '../globals.dart';
import '../utils/blurhash_cache.dart';
import '../utils/wallpaper_util.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ── File cache ────────────────────────────────────────────────────────────────
final Map<String, File?> _globalVideoCache = {};

// ── Player cache ──────────────────────────────────────────────────────────────
// Keeps Player+VideoController alive across widget dispose/recreate so videos
// don't have to re-buffer every time the user navigates away from the chat.

class _CachedPlayerEntry {
  final Player player;
  final VideoController controller;
  final File file;
  double aspectRatio;
  _CachedPlayerEntry(this.player, this.controller, this.file, this.aspectRatio);
}

const int _kMaxCachedPlayers = 6;
final Map<String, _CachedPlayerEntry> _globalPlayerCache = {};
final List<String> _playerCacheOrder = [];

void _touchPlayerLru(String key) {
  _playerCacheOrder.remove(key);
  _playerCacheOrder.add(key);
}

void _evictOldestPlayer() {
  if (_playerCacheOrder.isNotEmpty) {
    final key = _playerCacheOrder.removeAt(0);
    _globalPlayerCache.remove(key)?.player.dispose();
  }
}

class VideoMessageWidget extends StatefulWidget {
  final String filename;
  final String? owner;
  final String peerUsername;
  final String? mediaKeyB64;

  /// BlurHash poster from the message metadata — shows a blurred preview behind
  /// the play button while the video is unloaded. Null for videos sent without
  /// one; in that case a poster is captured from the first frame after the
  /// video is opened once and reused on later views (BlurHashCache).
  final String? blurHash;

  /// Aspect ratio embedded in the message metadata at send time. Used to size
  /// the bubble correctly before the video is ever played. Falls back to 16/9.
  final double? initialAspectRatio;

  /// Scales the bubble's displayed max dimensions to match the app-wide
  /// "message size" setting, same as the text/timestamp scaling.
  final double fontSizeMultiplier;

  const VideoMessageWidget({
    super.key,
    required this.filename,
    this.owner,
    required this.peerUsername,
    this.mediaKeyB64,
    this.blurHash,
    this.initialAspectRatio,
    this.fontSizeMultiplier = 1.0,
  });

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _errorDetails;
  bool _loading = false;
  bool _error = false;
  bool _needsTap = false; // true = waiting for user tap before downloading
  File? _cachedFile;
  double? _downloadProgress; // 0.0–1.0, null = no progress info

  Player? _player;
  VideoController? _videoController;
  bool _initialized = false;
  bool _saving = false;
  StreamSubscription<VideoParams>? _videoParamsSub;

  // Real aspect ratio from the video stream
  double _aspectRatio = 16 / 9;

  // Suppress hover-detection on the video while the context menu is visible
  bool _suppressHover = false;

  @override
  void initState() {
    super.initState();
    // Seed from metadata so the bubble has the right shape before the video plays.
    if (widget.initialAspectRatio != null && widget.initialAspectRatio! > 0) {
      _aspectRatio = widget.initialAspectRatio!;
    }
    // Auto-load only when the user opted in, or when this video is already
    // prepared in the session cache (cheap to show, no download/player spin-up).
    // Otherwise show a tap-to-load placeholder so scrolling past videos stays
    // smooth — preparing a video is the main source of jank.
    final hasLivePlayer = _globalPlayerCache.containsKey(widget.filename);
    if (SettingsManager.autoLoadVideoEnabled.value || hasLivePlayer) {
      _loading = true;
      _loadOrDownload();
    } else {
      _needsTap = true;
    }
  }

  void _startLoadFromTap() {
    setState(() {
      _needsTap = false;
      _loading = true;
      _error = false;
      _errorDetails = null;
    });
    _loadOrDownload();
  }

  void _attachParamsListener(Player player) {
    _videoParamsSub?.cancel();
    _videoParamsSub = player.stream.videoParams.listen((params) {
      final w = params.dw;
      final h = params.dh;
      if (w != null && h != null && w > 0 && h > 0 && mounted) {
        final ar = w / h;
        final entry = _globalPlayerCache[widget.filename];
        if (entry != null) entry.aspectRatio = ar;
        // videoParams can re-emit the same (or near-identical, due to float
        // rounding) dimensions repeatedly during playback — every such
        // setState resizes the AspectRatio box the player + its controls
        // live in, which was restarting media_kit_video's own animated
        // seek-bar/toolbar positioning mid-flight and showed up as controls
        // visibly drifting. Only relayout when the ratio actually changed.
        if ((ar - _aspectRatio).abs() > 0.001) {
          setState(() => _aspectRatio = ar);
        }
        // First decoded frame is available now — capture a poster so future
        // views (and the unloaded placeholder) show a blurred preview.
        _capturePosterIfNeeded(player);
      }
    });
  }

  bool _posterCaptured = false;

  /// Grabs the current frame once and stores a BlurHash poster for this video,
  /// unless we already have one. Best-effort; never throws.
  Future<void> _capturePosterIfNeeded(Player player) async {
    if (_posterCaptured) return;
    if (widget.blurHash != null && widget.blurHash!.isNotEmpty) return;
    if (BlurHashCache.instance.get(widget.filename) != null) return;
    _posterCaptured = true;
    try {
      final bytes = await player.screenshot();
      if (bytes != null && bytes.isNotEmpty) {
        BlurHashCache.instance.ensureForBytes(widget.filename, bytes);
      }
    } catch (_) {
      // Screenshot unsupported on this platform / not ready — ignore.
    }
  }

  Future<void> _initPlayer(File file) async {
    // ── Fast path: reuse cached player ────────────────────────────────────────
    final cached = _globalPlayerCache[widget.filename];
    if (cached != null) {
      _touchPlayerLru(widget.filename);
      _attachParamsListener(cached.player);
      if (mounted) {
        setState(() {
          _player = cached.player;
          _videoController = cached.controller;
          _aspectRatio = cached.aspectRatio;
          _initialized = true;
        });
      }
      return;
    }

    // ── Cold path: create new player ──────────────────────────────────────────
    try {
      final player = Player();
      final controller = VideoController(player);

      _attachParamsListener(player);

      await player.open(Media(file.path), play: false);

      // Also check state synchronously after open
      final w = player.state.videoParams.dw;
      final h = player.state.videoParams.dh;
      if (w != null && h != null && w > 0 && h > 0) {
        _aspectRatio = w / h;
      }

      if (mounted) {
        // Store in global cache before setting state
        if (_globalPlayerCache.length >= _kMaxCachedPlayers) {
          _evictOldestPlayer();
        }
        _globalPlayerCache[widget.filename] =
            _CachedPlayerEntry(player, controller, file, _aspectRatio);
        _touchPlayerLru(widget.filename);

        setState(() {
          _player = player;
          _videoController = controller;
          _initialized = true;
        });
      } else {
        player.dispose();
      }
    } catch (e) {
      debugPrint('[VideoWidget] Player init failed: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _errorDetails = e.toString();
        });
      }
    }
  }

  Future<void> _loadOrDownload() async {
    debugPrint('[VideoWidget] Loading video: "${widget.filename}"');

    // ── Ultra-fast path: player already fully cached ──────────────────────────
    final cached = _globalPlayerCache[widget.filename];
    if (cached != null) {
      _touchPlayerLru(widget.filename);
      _attachParamsListener(cached.player);
      if (mounted) {
        setState(() {
          _loading = false;
          _cachedFile = cached.file;
          _player = cached.player;
          _videoController = cached.controller;
          _aspectRatio = cached.aspectRatio;
          _initialized = true;
        });
      }
      return;
    }

    try {
      final appSupport = await getOnyxSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/video_cache');
      await cacheDir.create(recursive: true);

      File? cachedFile;

      if (widget.filename.startsWith('file://')) {
        cachedFile = File(widget.filename.substring(7));
        if (!(await cachedFile.exists())) {
          throw Exception('Mesh file not found: ${widget.filename}');
        }
      } else if (widget.filename.startsWith('lan://')) {
        final lanFilename = widget.filename.substring(6);
        final appDocuments = await getOnyxDocumentsDirectory();
        cachedFile = File('${appDocuments.path}/lan_media/$lanFilename');
        if (!(await cachedFile.exists())) {
          throw Exception('LAN file not found: $lanFilename');
        }
      } else if (widget.filename.startsWith('fav://')) {
        final favFilename = widget.filename.substring(6);
        final appDocuments = await getOnyxDocumentsDirectory();
        cachedFile = File('${appDocuments.path}/fav_media/$favFilename');
        if (!(await cachedFile.exists())) {
          throw Exception('Favorites file not found: $favFilename');
        }
      } else if (widget.filename.startsWith('http')) {
        var url = widget.filename;
        final safeName = _sanitizeFilename(Uri.parse(url).pathSegments.last);
        final ext = _guessExtension(url) ?? '.mp4';
        cachedFile = File('${cacheDir.path}/$safeName$ext');

        if (!(await cachedFile.exists())) {
          final uri = Uri.parse(url);
          if (!url.contains('?token=') && !url.contains('&token=')) {
            final servers = ExternalServerManager.servers.value;
            final matching = servers
                .where((s) => s.host == uri.host && s.port == uri.port)
                .toList();
            if (matching.isNotEmpty) {
              url = '$url?token=${Uri.encodeComponent(matching.first.token)}';
            }
          }
          final client = http.Client();
          try {
            final req = http.Request('GET', Uri.parse(url));
            final streamedRes = await client.send(req);
            if (streamedRes.statusCode != 200) {
              throw Exception('HTTP ${streamedRes.statusCode}');
            }
            final total = streamedRes.contentLength ?? 0;
            var received = 0;
            final bytes = <int>[];
            await for (final chunk in streamedRes.stream) {
              bytes.addAll(chunk);
              received += chunk.length;
              if (total > 0 && mounted) {
                setState(() => _downloadProgress = received / total);
              }
            }
            await cachedFile.writeAsBytes(bytes);
          } finally {
            client.close();
          }
        }
      } else {
        if (_globalVideoCache.containsKey(widget.filename)) {
          final file = _globalVideoCache[widget.filename];
          if (file != null && await file.exists()) {
            if (mounted) {
              setState(() {
                _loading = false;
                _cachedFile = file;
              });
              await _initPlayer(file);
            }
            return;
          }
        }

        final cachedPath = '${cacheDir.path}/${widget.filename}';
        cachedFile = File(cachedPath);

        if (!(await cachedFile.exists())) {
          final currentUsername = rootScreenKey.currentState?.currentUsername;
          final token = await AccountManager.getToken(currentUsername ?? '');
          if (token == null) throw Exception('Not logged in');

          final videoUrl = (widget.owner != null && widget.owner!.isNotEmpty)
              ? '$serverBase/video/${widget.owner}/${widget.filename}'
              : '$serverBase/video/${widget.filename}';
          final client = http.Client();
          final Uint8List encryptedBytes;
          try {
            final req = http.Request('GET', Uri.parse(videoUrl));
            req.headers['authorization'] = 'Bearer $token';
            final streamedRes = await client.send(req);
            if (streamedRes.statusCode != 200) {
              throw Exception('HTTP ${streamedRes.statusCode}');
            }
            final total = streamedRes.contentLength ?? 0;
            var received = 0;
            final bytes = <int>[];
            await for (final chunk in streamedRes.stream) {
              bytes.addAll(chunk);
              received += chunk.length;
              if (total > 0 && mounted) {
                setState(() => _downloadProgress = received / total);
              }
            }
            if (bytes.isEmpty) throw Exception('Empty response');
            encryptedBytes = Uint8List.fromList(bytes);
          } finally {
            client.close();
          }

          final root = rootScreenKey.currentState;
          if (root == null) throw Exception('RootScreen not ready');

          final plainBytes = await root.decryptMediaFromPeer(
            widget.peerUsername,
            encryptedBytes,
            kind: 'video',
            mediaKeyB64: widget.mediaKeyB64,
          );
          await cachedFile.writeAsBytes(plainBytes, flush: true);
          _globalVideoCache[widget.filename] = cachedFile;
        }
      }

      mediaFilePathRegistry[widget.filename] = cachedFile.path;
      if (mounted) {
        setState(() {
          _loading = false;
          _cachedFile = cachedFile;
        });
        await _initPlayer(cachedFile);
      }
    } catch (e) {
      debugPrint('[VideoWidget] _loadOrDownload error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
          _errorDetails = e.toString();
        });
      }
    }
  }

  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  static String? _guessExtension(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    if (path.endsWith('.mp4')) return '.mp4';
    if (path.endsWith('.mov')) return '.mov';
    if (path.endsWith('.m4v')) return '.m4v';
    if (path.endsWith('.webm')) return '.webm';
    return null;
  }

  Future<void> _saveVideoWithState() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _saveVideo();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveVideo() async {
    if (_cachedFile == null || !await _cachedFile!.exists()) {
      rootScreenKey.currentState?.showSnack('Video not available to save');
      return;
    }
    try {
      final origName = widget.filename.startsWith('http')
          ? Uri.parse(widget.filename).pathSegments.last
          : widget.filename;
      final ext = p.extension(origName) == '' ? '.mp4' : p.extension(origName);
      final safeName = _sanitizeFilename(origName);

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        String? destPath;
        var dialogSupported = true;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save video as',
            fileName: safeName,
            type: FileType.custom,
            allowedExtensions: [ext.replaceFirst('.', '')],
          );
        } catch (e) {
          dialogSupported = false;
          destPath = null;
        }
        if (destPath == null || destPath.isEmpty) {
          if (dialogSupported) {
            rootScreenKey.currentState?.showSnack('Save cancelled');
            return;
          }
          final onyxDir = await getOnyxSaveDirectory();
          if (onyxDir == null) {
            rootScreenKey.currentState
                ?.showSnack('Cannot access save directory');
            return;
          }
          destPath = '${onyxDir.path}/$safeName';
        }
        final savedFile = File(destPath);
        await _cachedFile!.copy(savedFile.path);
        showSavedToSnack(savedFile.path);
        return;
      }

      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack(
            'Save not supported on web — open the video and save it');
        return;
      }

      // Mobile — save to gallery
      if (Platform.isAndroid || Platform.isIOS) {
        final saved = await GallerySaver.saveVideo(
          _cachedFile!.path,
          albumName: 'ONYX',
        );
        if (saved == true) {
          rootScreenKey.currentState?.showSnack('Saved to gallery');
        } else {
          rootScreenKey.currentState?.showSnack('Failed to save to gallery');
        }
        return;
      }

      final onyxDir = await getOnyxSaveDirectory();
      if (onyxDir == null) {
        rootScreenKey.currentState?.showSnack('Cannot access save directory');
        return;
      }
      final savedFile = File('${onyxDir.path}/$safeName');
      await _cachedFile!.copy(savedFile.path);
      showSavedToSnack(savedFile.path);
    } catch (e, st) {
      debugPrint(' _saveVideo error: $e\n$st');
      rootScreenKey.currentState?.showSnack(' Save failed: $e');
    }
  }

  Future<void> _saveCurrentFrameWithState() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _saveCurrentFrame();
    if (mounted) setState(() => _saving = false);
  }

  /// Captures the currently displayed video frame via the player's
  /// screenshot API and saves it like a regular image.
  Future<void> _saveCurrentFrame() async {
    if (_player == null) {
      rootScreenKey.currentState?.showSnack('Video not playing');
      return;
    }
    try {
      final bytes = await _player!.screenshot();
      if (bytes == null || bytes.isEmpty) {
        rootScreenKey.currentState?.showSnack('Failed to capture frame');
        return;
      }
      final filename = 'frame_${DateTime.now().millisecondsSinceEpoch}.png';

      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        String? destPath;
        var dialogSupported = true;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save frame as',
            fileName: filename,
            type: FileType.custom,
            allowedExtensions: ['png'],
          );
        } catch (e) {
          dialogSupported = false;
          destPath = null;
        }
        if (destPath == null || destPath.isEmpty) {
          if (dialogSupported) {
            rootScreenKey.currentState?.showSnack('Save cancelled');
            return;
          }
          final onyxDir = await getOnyxSaveDirectory();
          if (onyxDir == null) {
            rootScreenKey.currentState
                ?.showSnack('Cannot access save directory');
            return;
          }
          destPath = '${onyxDir.path}/$filename';
        }
        await File(destPath).writeAsBytes(bytes);
        showSavedToSnack(destPath);
        return;
      }

      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack('Save not supported on web');
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getOnyxSupportDirectory();
        final tempFile = File('${tempDir.path}/$filename');
        await tempFile.writeAsBytes(bytes);
        final saved =
            await GallerySaver.saveImage(tempFile.path, albumName: 'ONYX');
        if (saved == true) {
          rootScreenKey.currentState?.showSnack('Frame saved to gallery');
        } else {
          rootScreenKey.currentState?.showSnack('Failed to save frame');
        }
        return;
      }

      final onyxDir = await getOnyxSaveDirectory();
      if (onyxDir == null) {
        rootScreenKey.currentState?.showSnack('Cannot access save directory');
        return;
      }
      final savedFile = File('${onyxDir.path}/$filename');
      await savedFile.writeAsBytes(bytes);
      showSavedToSnack(savedFile.path);
    } catch (e, st) {
      debugPrint(' _saveCurrentFrame error: $e\n$st');
      rootScreenKey.currentState?.showSnack(' Save frame failed: $e');
    }
  }

  Future<void> _setVideoAsWallpaper() async {
    if (_cachedFile == null || !await _cachedFile!.exists()) {
      rootScreenKey.currentState?.showSnack('Video not available');
      return;
    }
    try {
      await setFileAsChatWallpaper(_cachedFile!, isVideo: true);
      rootScreenKey.currentState?.showSnack('Video wallpaper set');
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Failed to set wallpaper: $e');
    }
  }

  /// Three-dot menu (Download / Save current frame / Set as wallpaper) shown
  /// while the video is fullscreen — a persistent top-right button like
  /// every other messenger's fullscreen media viewer, NOT wired through
  /// media_kit's `topButtonBar`.
  ///
  /// `topButtonBar` lives inside the player's auto-hiding controls layer:
  /// the same tap that opened our menu was also seen by the video's own
  /// tap-to-toggle-controls handler underneath, hiding (unmounting) the
  /// whole control bar — and with it our just-opened menu — causing it to
  /// flash open and immediately vanish. Inserting our own [OverlayEntry]
  /// directly via [onEnterFullscreen]/[onExitFullscreen] keeps the button
  /// completely independent of that auto-hide timer.
  OverlayEntry? _fullscreenMenuEntry;

  void _showFullscreenMenuOverlay() {
    if (!mounted) return;
    _fullscreenMenuEntry?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _VideoFullscreenMenuButton(
              onDownload: _saveVideoWithState,
              onSaveFrame: _saveCurrentFrameWithState,
              onSetWallpaper: _setVideoAsWallpaper,
            ),
          ),
        ),
      ),
    );
    _fullscreenMenuEntry = entry;
    overlay.insert(entry);
  }

  void _hideFullscreenMenuOverlay() {
    _fullscreenMenuEntry?.remove();
    _fullscreenMenuEntry = null;
  }

  void _resetAndRetry() {
    // Remove from global cache so _initPlayer does a fresh cold init
    final removed = _globalPlayerCache.remove(widget.filename);
    _playerCacheOrder.remove(widget.filename);
    removed?.player.dispose();

    _videoParamsSub?.cancel();
    _videoParamsSub = null;

    setState(() {
      _loading = true;
      _error = false;
      _errorDetails = null;
      _cachedFile = null;
      _initialized = false;
      _player = null;
      _videoController = null;
      _aspectRatio = 16 / 9;
      _downloadProgress = null;
    });
    _loadOrDownload();
  }

  @override
  void dispose() {
    _hideFullscreenMenuOverlay();
    _videoParamsSub?.cancel();
    _videoParamsSub = null;
    // Pause before releasing — player stays alive in cache but shouldn't play
    // when the user has navigated away from the chat.
    _player?.pause();
    _player = null;
    _videoController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: VisibilityDetector(
        key: Key('video_${widget.filename}_${widget.peerUsername}'),
        onVisibilityChanged: (info) {
          // Pause when scrolled fully out of view
          if (info.visibleFraction == 0 &&
              _player != null &&
              _player!.state.playing) {
            _player!.pause();
          }
        },
        child: _buildVideoWidget(context),
      ),
    );
  }

  Widget _buildVideoWidget(BuildContext context) {
    if (_needsTap) {
      return _tapToLoadBox(context);
    }

    if (_loading) {
      final hash =
          widget.blurHash ?? BlurHashCache.instance.get(widget.filename);
      return _sizedBox(
        context,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hash != null && hash.isNotEmpty)
              Image(
                image: BlurHashImage(hash),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_downloadProgress != null) ...[
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_downloadProgress! * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else
                    const CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ],
        ),
        color: Colors.black,
      );
    }

    if (_error) {
      return _errorBox(context);
    }

    if (_initialized && _videoController != null) {
      return _buildPlayer(context);
    }

    // Fallback while player is initializing after file is ready
    return _sizedBox(
      context,
      child: const Center(child: CircularProgressIndicator()),
      color: Colors.black,
    );
  }

  /// A container sized to match the video's aspect ratio with Telegram-style
  /// proportional constraints: portrait clips to 300×460, landscape to 300×168.
  Widget _sizedBox(BuildContext context,
      {required Widget child, Color color = Colors.transparent}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 300 * widget.fontSizeMultiplier,
          maxHeight: 460 * widget.fontSizeMultiplier,
        ),
        child: AspectRatio(
          aspectRatio: _aspectRatio.clamp(0.4, 2.0),
          child: Container(color: color, child: child),
        ),
      ),
    );
  }

  /// Shown when auto-load is off and the video hasn't been requested yet:
  /// a dark poster-sized box with a play button. Tapping starts the download.
  Widget _tapToLoadBox(BuildContext context) {
    final hash = widget.blurHash ?? BlurHashCache.instance.get(widget.filename);
    return GestureDetector(
      onTap: _startLoadFromTap,
      child: _sizedBox(
        context,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hash != null && hash.isNotEmpty)
              Image(
                image: BlurHashImage(hash),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context).tapToLoadVideo,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 300 * widget.fontSizeMultiplier),
      child: Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(' Failed to load video',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_errorDetails != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorDetails!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _resetAndRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Wrap Video in the appropriate theme provider so the seek bar
    // uses the app's primary color. Controls type selects hover (desktop)
    // vs tap (mobile) behavior.
    Widget videoWithTheme;
    if (isDesktop) {
      videoWithTheme = MaterialDesktopVideoControlsTheme(
        normal: MaterialDesktopVideoControlsThemeData(
          seekBarThumbColor: primary,
          seekBarPositionColor: primary,
          seekBarBufferColor: primary.withValues(alpha: 0.3),
          // Inline bubble preview only: drop the volume button and the
          // timecode readout — neither is useful at bubble width, and
          // their layout was what visibly glitched/drifted in the
          // cramped control bar. Fullscreen keeps the full default set.
          bottomButtonBar: const [
            MaterialDesktopSkipPreviousButton(),
            MaterialDesktopPlayOrPauseButton(),
            MaterialDesktopSkipNextButton(),
            Spacer(),
            MaterialDesktopFullscreenButton(),
          ],
        ),
        fullscreen: MaterialDesktopVideoControlsThemeData(
          seekBarThumbColor: primary,
          seekBarPositionColor: primary,
          seekBarBufferColor: primary.withValues(alpha: 0.3),
        ),
        child: Video(
          controller: _videoController!,
          controls: MaterialDesktopVideoControls,
          // Desktop has no built-in onEnterFullscreen override elsewhere, so
          // we must still call the package default (native OS window
          // fullscreen) ourselves alongside showing our persistent menu.
          onEnterFullscreen: () async {
            await defaultEnterNativeFullscreen();
            _showFullscreenMenuOverlay();
          },
          onExitFullscreen: () async {
            _hideFullscreenMenuOverlay();
            await defaultExitNativeFullscreen();
          },
        ),
      );
    } else {
      videoWithTheme = MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          seekBarThumbColor: primary,
          seekBarPositionColor: primary,
          seekBarBufferColor: primary.withValues(alpha: 0.3),
          // Inline bubble preview only: drop the timecode readout, same
          // reasoning as the desktop branch above. Fullscreen keeps the
          // full default set.
          bottomButtonBar: const [
            Spacer(),
            MaterialFullscreenButton(),
          ],
        ),
        fullscreen: MaterialVideoControlsThemeData(
          seekBarThumbColor: primary,
          seekBarPositionColor: primary,
          seekBarBufferColor: primary.withValues(alpha: 0.3),
        ),
        child: Video(
          controller: _videoController!,
          controls: MaterialVideoControls,
          // Don't force landscape — let the device auto-rotate freely
          onEnterFullscreen: () async {
            await SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
              overlays: [],
            );
            // No setPreferredOrientations call → system auto-rotate stays active
            _showFullscreenMenuOverlay();
          },
          onExitFullscreen: () async {
            _hideFullscreenMenuOverlay();
            _player?.pause();
            await SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.manual,
              overlays: SystemUiOverlay.values,
            );
            await SystemChrome.setPreferredOrientations([]); // unlock all
          },
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        // Right-click: suppress hover so media_kit controls don't
        // appear and dismiss the native context menu.
        if (event.buttons == 0x02) {
          setState(() => _suppressHover = true);
          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) setState(() => _suppressHover = false);
          });
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 300 * widget.fontSizeMultiplier,
            maxHeight: 460 * widget.fontSizeMultiplier,
          ),
          child: AspectRatio(
            aspectRatio: _aspectRatio.clamp(0.4, 2.0),
            child: Stack(
              children: [
                AbsorbPointer(absorbing: _suppressHover, child: videoWithTheme),
                // No always-visible save button here — Download / Save frame /
                // Set as wallpaper now live in the fullscreen controls' menu
                // (see _buildFullscreenMenuButton), so the inline bubble stays
                // clean and the actions only show once the user opens fullscreen.
                // Mobile only: GestureDetector that claims vertical drags
                // so they scroll the chat instead of triggering video
                // controls. Taps are not handled here, so they pass through
                // to MaterialVideoControls as normal.
                if (!isDesktop)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (details) {
                        final pos = Scrollable.maybeOf(context)?.position;
                        if (pos != null) {
                          pos.moveTo(
                            pos.pixels + (details.primaryDelta ?? 0),
                            clamp: true,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Self-contained three-dot menu for the fullscreen video controls. Must own
/// its own State (rather than reading state from the outer
/// [_VideoMessageWidgetState]) because media_kit snapshots `topButtonBar`'s
/// widget instances into the fullscreen route once, at the moment fullscreen
/// is entered — only a widget that manages its own open/closed flag keeps
/// responding to taps after that snapshot is taken.
class _VideoFullscreenMenuButton extends StatefulWidget {
  final VoidCallback onDownload;
  final VoidCallback onSaveFrame;
  final VoidCallback onSetWallpaper;

  const _VideoFullscreenMenuButton({
    required this.onDownload,
    required this.onSaveFrame,
    required this.onSetWallpaper,
  });

  @override
  State<_VideoFullscreenMenuButton> createState() =>
      _VideoFullscreenMenuButtonState();
}

class _VideoFullscreenMenuButtonState
    extends State<_VideoFullscreenMenuButton> {
  // Renders the dropdown into the app's root Overlay (full-screen sized)
  // instead of as a Positioned child of a small Stack: a Stack only
  // hit-tests within its own layout size, so a Positioned child that merely
  // *paints* outside those bounds via Clip.none is visible but untappable.
  // OverlayPortal mounts the panel as real Overlay content, sized to the
  // whole screen, so taps on it hit-test correctly.
  final _controller = OverlayPortalController();
  final _layerLink = LayerLink();

  void _select(VoidCallback action) {
    _controller.hide();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal.targetsRootOverlay(
        controller: _controller,
        overlayChildBuilder: (context) => Stack(
          children: [
            // Invisible full-screen barrier — tap outside the panel to close
            // it. Opaque (not translucent): a translucent barrier let taps
            // fall through to the video underneath, which toggled
            // play/pause and the controls' own show/hide timer — fighting
            // with our menu's visibility and causing it to flicker.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _controller.hide,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              showWhenUnlinked: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildPanel(),
              ),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          tooltip: 'More',
          onPressed: _controller.toggle,
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final cs = Theme.of(context).colorScheme;

    Widget item(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        onTap: () => _select(onTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: cs.onSurface),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: SizedBox(
        // Fixed (not just minimum) width — combined with the stretch below,
        // an unbounded ConstrainedBox(minWidth:...) let the Column expand to
        // fill the entire screen instead of staying a compact dropdown.
        width: 240,
        // stretch so each item's InkWell hover/ripple fills the full panel
        // width instead of just hugging the icon+text content.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            item(Icons.download_rounded, 'Download', widget.onDownload),
            item(Icons.camera_alt_rounded, 'Save current frame',
                widget.onSaveFrame),
            item(Icons.wallpaper_rounded, 'Set as wallpaper',
                widget.onSetWallpaper),
          ],
        ),
      ),
    );
  }
}
