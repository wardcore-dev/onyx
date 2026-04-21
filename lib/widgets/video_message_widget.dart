// lib/widgets/video_message_widget.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode, SystemUiOverlay;
import 'dart:io' show File, Directory, Platform;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../managers/account_manager.dart';
import '../managers/external_server_manager.dart';
import '../globals.dart';
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

  const VideoMessageWidget({
    super.key,
    required this.filename,
    this.owner,
    required this.peerUsername,
    this.mediaKeyB64,
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
    // Start loading immediately — don't wait for scroll visibility
    _loading = true;
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
        setState(() => _aspectRatio = ar);
      }
    });
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
      final appSupport = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/video_cache');
      await cacheDir.create(recursive: true);

      File? cachedFile;

      if (widget.filename.startsWith('lan://')) {
        final lanFilename = widget.filename.substring(6);
        final appDocuments = await getApplicationDocumentsDirectory();
        cachedFile = File('${appDocuments.path}/lan_media/$lanFilename');
        if (!(await cachedFile.exists())) {
          throw Exception('LAN file not found: $lanFilename');
        }
      } else if (widget.filename.startsWith('http')) {
        var url = widget.filename;
        final safeName =
            _sanitizeFilename(Uri.parse(url).pathSegments.last);
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
              url =
                  '$url?token=${Uri.encodeComponent(matching.first.token)}';
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
          final currentUsername =
              rootScreenKey.currentState?.currentUsername;
          final token =
              await AccountManager.getToken(currentUsername ?? '');
          if (token == null) throw Exception('Not logged in');

          final videoUrl =
              (widget.owner != null && widget.owner!.isNotEmpty)
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
      final ext =
          p.extension(origName) == '' ? '.mp4' : p.extension(origName);
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
          final dl = await getDownloadsDirectory();
          if (dl == null) {
            rootScreenKey.currentState
                ?.showSnack('Cannot access save directory');
            return;
          }
          destPath = '${dl.path}/$safeName';
        }
        final savedFile = File(destPath);
        await _cachedFile!.copy(savedFile.path);
        rootScreenKey.currentState
            ?.showSnack('Saved to: ${savedFile.path}');
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

      final dl = await getDownloadsDirectory();
      if (dl == null) {
        rootScreenKey.currentState?.showSnack('Cannot access save directory');
        return;
      }
      final savedFile = File('${dl.path}/$safeName');
      await _cachedFile!.copy(savedFile.path);
      rootScreenKey.currentState?.showSnack('Saved to: ${savedFile.path}');
    } catch (e, st) {
      debugPrint(' _saveVideo error: $e\n$st');
      rootScreenKey.currentState?.showSnack(' Save failed: $e');
    }
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
    // Cancel our listener but DO NOT dispose the player —
    // it lives in _globalPlayerCache and will be reused when the user
    // navigates back to this chat.
    _videoParamsSub?.cancel();
    _videoParamsSub = null;
    // Just drop local references; the cache keeps the player alive.
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
    if (_loading) {
      return _sizedBox(
        context,
        child: Center(
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

  /// A container sized to match the video's aspect ratio.
  Widget _sizedBox(BuildContext context,
      {required Widget child, Color color = Colors.transparent}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 380,
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Container(color: color, child: child),
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      width: 380,
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
        ),
        fullscreen: MaterialDesktopVideoControlsThemeData(
          seekBarThumbColor: primary,
          seekBarPositionColor: primary,
          seekBarBufferColor: primary.withValues(alpha: 0.3),
        ),
        child: Video(
          controller: _videoController!,
          controls: MaterialDesktopVideoControls,
        ),
      );
    } else {
      videoWithTheme = MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          seekBarThumbColor: primary,
          seekBarPositionColor: primary,
          seekBarBufferColor: primary.withValues(alpha: 0.3),
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
          },
          onExitFullscreen: () async {
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
        // Explicit size with real aspect ratio — prevents zero-dimension
        // transform matrix crash in Flutter's rendering layer.
        child: SizedBox(
          width: 380,
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Stack(
              children: [
                AbsorbPointer(absorbing: _suppressHover, child: videoWithTheme),
                // Save button — top right corner
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _saveVideoWithState,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: _saving
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
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
