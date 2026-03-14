// lib/widgets/video_message_widget.dart
import 'package:flutter/material.dart';
import 'dart:io' show File, Directory, Platform;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../managers/account_manager.dart';
import '../managers/external_server_manager.dart';
import '../globals.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final Map<String, File?> _globalVideoCache = {};

class VideoMessageWidget extends StatefulWidget {
  final String filename; 
  final String? owner;
  final String peerUsername;
  final String? mediaKeyB64;

  const VideoMessageWidget({
    Key? key,
    required this.filename,
    this.owner,
    required this.peerUsername,
    this.mediaKeyB64,
  }) : super(key: key);

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
  bool _isVisible = false; 
  bool _hasStartedLoading = false; 

  Offset? _lastTapPosition;

  void _storeTapPosition(TapDownDetails details) =>
      _lastTapPosition = details.globalPosition;

  Future<void> _showContextMenu() async {
    final pos = _lastTapPosition;
    if (pos == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(value: 'save', child: Text('Save')),
      ],
    );
    if (selected == 'open') return _openVideo();
    if (selected == 'save') return _saveVideo();
  }

  @override
  void initState() {
    super.initState();
    
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final newVisibility = info.visibleFraction > 0.1; 
    if (_isVisible != newVisibility && mounted) {
      setState(() => _isVisible = newVisibility);

      if (newVisibility && !_hasStartedLoading && _cachedFile == null) {
        _hasStartedLoading = true;
        _loading = true;
        _loadOrDownload();
      }
    }
  }

  Future<void> _loadOrDownload() async {
    debugPrint('[VideoWidget] Loading video: "${widget.filename}"');

    final appSupport = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appSupport.path}/video_cache');
    await cacheDir.create(recursive: true);

    File? cachedFile;

    if (widget.filename.startsWith('lan://')) {
      debugPrint('[VideoWidget] LAN file detected: ${widget.filename}');
      
      final lanFilename = widget.filename.substring(6); 
      final appDocuments = await getApplicationDocumentsDirectory();
      cachedFile = File('${appDocuments.path}/lan_media/$lanFilename');
      if (!(await cachedFile.exists())) {
        throw Exception('LAN file not found: $lanFilename');
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
            debugPrint('[VideoWidget] Added auth token to URL');
          }
        } else {
          debugPrint('[VideoWidget] Token already present in URL');
        }

        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          await cachedFile.writeAsBytes(res.bodyBytes);
        } else {
          throw Exception('HTTP ${res.statusCode}');
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
        final res = await http.get(
          Uri.parse(videoUrl),
          headers: {'authorization': 'Bearer $token'},
        );
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        if (res.bodyBytes.isEmpty) throw Exception('Empty response');

        final root = rootScreenKey.currentState;
        if (root == null) throw Exception('RootScreen not ready');

        final plainBytes = await root.decryptMediaFromPeer(
          widget.peerUsername,
          res.bodyBytes,
          kind: 'video',
          mediaKeyB64: widget.mediaKeyB64,
        );
        await cachedFile.writeAsBytes(plainBytes, flush: true);
        _globalVideoCache[widget.filename] = cachedFile;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _cachedFile = cachedFile;
      });
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

  Future<void> _openVideo() async {
    if (_cachedFile == null || !await _cachedFile!.exists()) {
      rootScreenKey.currentState?.showSnack('Video not available');
      return;
    }
    try {
      await OpenFilex.open(_cachedFile!.path);
    } catch (e, st) {
      debugPrint(' _openVideo error: $e\n$st');
      rootScreenKey.currentState?.showSnack('Failed to open video');
    }
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
          final dl = await getDownloadsDirectory();
          if (dl == null) {
            rootScreenKey.currentState?.showSnack('Cannot access save directory');
            return;
          }
          destPath = '${dl.path}/$safeName';
        }

        final savedFile = File(destPath);
        await _cachedFile!.copy(savedFile.path);
        rootScreenKey.currentState?.showSnack('Saved to: ${savedFile.path}');
        return;
      }

      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack('Save not supported on web — open the video and save it');
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

      final targetPath = '${targetDir.path}/$safeName';
      final savedFile = File(targetPath);
      await _cachedFile!.copy(savedFile.path);

      rootScreenKey.currentState?.showSnack('Saved to: ${savedFile.path}');

      if (Platform.isAndroid) {
        await OpenFilex.open(savedFile.path);
      }
    } catch (e, st) {
      debugPrint(' _saveVideo error: $e\n$st');
      rootScreenKey.currentState?.showSnack(' Save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RepaintBoundary(
      child: VisibilityDetector(
        key: Key('video_${widget.filename}_${widget.peerUsername}'),
        onVisibilityChanged: _onVisibilityChanged,
        child: _buildVideoWidget(context),
      ),
    );
  }

  Widget _buildVideoWidget(BuildContext context) {
    
    if (!_hasStartedLoading && _cachedFile == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 150, maxHeight: 300, maxWidth: 400),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_file, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('Scroll to load', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_loading) {
      return Container(
        constraints: const BoxConstraints(minHeight: 150, maxHeight: 300, maxWidth: 400),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error) {
      return Container(
        constraints: const BoxConstraints(minHeight: 150, maxHeight: 300, maxWidth: 400),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(' Failed to load video', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_errorDetails != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorDetails!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _loading = true;
                    _error = false;
                    _errorDetails = null;
                    _cachedFile = null;
                  });
                  _loadOrDownload();
                }
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _storeTapPosition,
      onSecondaryTapDown: _storeTapPosition,
      onLongPressStart: (details) {
        _lastTapPosition = details.globalPosition;
        _showContextMenu();
      },
      onSecondaryTap: () => _showContextMenu(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 150, maxHeight: 300, maxWidth: 400),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_file, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _openVideo,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Open', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saveVideo,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Save', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}