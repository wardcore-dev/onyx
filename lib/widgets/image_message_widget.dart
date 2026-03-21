// lib/widgets/image_message_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File, Directory;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../globals.dart';
import '../screens/chat_screen.dart';
import '../managers/external_server_manager.dart';
import '../utils/image_size_cache.dart';
import '../utils/image_file_cache.dart';

class ImageMessageWidget extends StatefulWidget {
  final String filename; 
  final String? owner;
  final String peerUsername;
  final bool isOutgoing;
  final String? mediaKeyB64;

  const ImageMessageWidget({
    Key? key,
    required this.filename,
    this.owner,
    required this.peerUsername,
    this.isOutgoing = false,
    this.mediaKeyB64,
  }) : super(key: key);

  @override
  State<ImageMessageWidget> createState() => _ImageMessageWidgetState();
}

class _ImageMessageWidgetState extends State<ImageMessageWidget> {
  File? _imageFile;
  bool _loading = true;
  String? _error;
  bool _isVisible = true;  
  int? _fileSizeBytes;  
  double? _aspectRatio;  


  @override
  void initState() {
    super.initState();
    
    final cached = imageFileCache[widget.filename];
    if (cached != null && cached.file.existsSync()) {
      _imageFile = cached.file;
      _fileSizeBytes = cached.size;
      _aspectRatio = cached.aspectRatio;
      _loading = false;
    } else {
      _loadImageFile();
    }
  }

  @override
  void didUpdateWidget(covariant ImageMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filename != widget.filename ||
        oldWidget.isOutgoing != widget.isOutgoing) {
      
      final cached = imageFileCache[widget.filename];
      if (cached != null && cached.file.existsSync()) {
        setState(() {
          _imageFile = cached.file;
          _fileSizeBytes = cached.size;
          _aspectRatio = cached.aspectRatio;
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = true;
        _error = null;
        _imageFile = null;
      });
      _loadImageFile();
    }
  }

  Future<void> _loadImageFile() async {
    try {
      debugPrint('[ImageWidget] Loading image: "${widget.filename}" (isOutgoing: ${widget.isOutgoing})');

      final appSupport = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/image_cache');
      await cacheDir.create(recursive: true);

      File? cachedFile;

      if (widget.filename.startsWith('lan://')) {
        debugPrint('[ImageWidget] LAN file detected: ${widget.filename}');
        
        final lanFilename = widget.filename.substring(6); 
        final appDocuments = await getApplicationDocumentsDirectory();
        cachedFile = File('${appDocuments.path}/lan_media/$lanFilename');
        if (!(await cachedFile.exists())) {
          throw Exception('LAN file not found: $lanFilename');
        }
      } else if (widget.filename.startsWith('http')) {
        
        var url = widget.filename;
        final safeName = _sanitizeFilename(Uri.parse(url).pathSegments.last);
        final ext = _guessExtension(url) ?? '.jpg';
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
              debugPrint('[ImageWidget] Added auth token to URL');
            }
          } else {
            debugPrint('[ImageWidget] Token already present in URL');
          }

          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await cachedFile.writeAsBytes(res.bodyBytes);
          } else {
            throw Exception('HTTP ${res.statusCode}');
          }
        }
      } else {
        
        final cachedPath = '${cacheDir.path}/${widget.filename}';
        cachedFile = File(cachedPath);
        if (!(await cachedFile.exists())) {
          final root = rootScreenKey.currentState;
          if (root == null) throw Exception('RootScreen not ready');
          final downloadedFile = await root.downloadImageToCache(
            widget.filename,
            peerUsername: widget.peerUsername,
            owner: widget.owner,
            mediaKeyB64: widget.mediaKeyB64,
          );
          if (downloadedFile == null) throw Exception('File not available');
          cachedFile = downloadedFile;
        }
      }

      if (mounted && cachedFile != null) {
        
        final aspectRatio = await ImageSizeCache().getOrComputeAspectRatio(cachedFile);
        final fileSize = cachedFile.lengthSync();

        imageFileCache[widget.filename] = (
          file: cachedFile,
          size: fileSize,
          aspectRatio: aspectRatio,
        );

        if (mounted) {
          setState(() {
            _imageFile = cachedFile;
            _fileSizeBytes = fileSize;
            _aspectRatio = aspectRatio;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  static String? _guessExtension(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.gif')) return '.gif';
    if (path.endsWith('.webp')) return '.webp';
    return null;
  }

  Future<void> _saveImageToGalleryOrFolder() async {
    final file = _imageFile;
    if (file == null || !(await file.exists())) {
      rootScreenKey.currentState?.showSnack('Image not downloaded');
      return; 
    }

    final filename = _suggestFilename(widget.filename);
    try {
      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack('Save not supported on web — open the image and save');
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        
        final saved = await GallerySaver.saveImage(file.path, albumName: 'ONYX');
        if (saved == true) {
          rootScreenKey.currentState?.showSnack('Saved to gallery');
        } else {
          rootScreenKey.currentState?.showSnack('Failed to save to gallery');
        }
        return;
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        String? destPath;
        var dialogSupported = true;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save image as',
            fileName: filename,
            type: FileType.custom,
            allowedExtensions: [p.extension(filename).replaceFirst('.', '')],
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
          
          final directoryPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Choose folder to save image',
          );
          if (directoryPath == null || directoryPath.isEmpty) {
            rootScreenKey.currentState?.showSnack('Save cancelled');
            return;
          }
          destPath = p.join(directoryPath, filename);
        }

        final nonNullDest = destPath!;
        await file.copy(nonNullDest);
        rootScreenKey.currentState?.showSnack('Saved to: $nonNullDest');
        return;
      }

      rootScreenKey.currentState?.showSnack('Save not supported on this platform');
    } catch (e) {
      rootScreenKey.currentState?.showSnack(' Save failed: $e');
    }
  }

  String _suggestFilename(String raw) {
    final base = raw.startsWith('http')
        ? Uri.parse(raw).pathSegments.last
        : p.basename(raw);
    final clean = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    if (clean.isEmpty)
      return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    if (!clean.contains('.')) return '$clean.jpg';
    return clean;
  }

  void _showFullscreen(File file) {
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    final chatState = context.findAncestorStateOfType<ChatScreenState>();

    Future.microtask(() {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogCtx) => FocusScope(
          canRequestFocus: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: GestureDetector(
              onTap: () => Navigator.of(dialogCtx).pop(),
              child: Stack(
                children: [
                  InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4,
                    child: Container(
                      color: Colors.black,
                      width: double.infinity,
                      height: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(file, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SafeArea(
                      child: ClipOval(
                        child: Material(
                          color: Colors.black45,
                          child: IconButton(
                            icon: const Icon(Icons.download_rounded, size: 20, color: Colors.white),
                            onPressed: _saveImageToGalleryOrFolder,
                            tooltip: Platform.isAndroid ? 'Save to gallery' : 'Save image',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: SafeArea(
                      child: ClipOval(
                        child: Material(
                          color: Colors.black45,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.white),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            tooltip: 'Close',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) {

      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text(' Failed: $_error');
    if (_imageFile != null) {
      
      final isLanFile = widget.filename.startsWith('lan://');
      final isLargeFile = !isLanFile &&
          _fileSizeBytes != null &&
          _fileSizeBytes! > 2 * 1024 * 1024;

      if (isLargeFile && !_isVisible) {
        return Container(
          constraints: BoxConstraints(
            minHeight: 150,
            maxHeight: 300,
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('Scroll to load', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      }

      final aspectRatio = _aspectRatio ?? 4 / 3;
      return RepaintBoundary(
        child: VisibilityDetector(
          key: Key('image_${widget.filename}_${widget.peerUsername}'),
          onVisibilityChanged: (VisibilityInfo info) {
            final newVisibility = info.visibleFraction > 0.05; 
            if (_isVisible != newVisibility && mounted) {
              setState(() => _isVisible = newVisibility);
            }
          },
          child: GestureDetector(
            onTap: () => _showFullscreen(_imageFile!),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 280, 
                maxHeight: 400, 
              ),
              child: AspectRatio(
                aspectRatio: aspectRatio, 
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      
                      cacheWidth: 560, 
                      filterQuality: FilterQuality.medium, 
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_loading) {
      final aspectRatio = _aspectRatio ?? 4 / 3; 
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 280, 
          maxHeight: 400, 
        ),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    return const Text(' No image');
  }
}