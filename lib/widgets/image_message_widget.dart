// lib/widgets/image_message_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, File, Directory;
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxDocumentsDirectory, getOnyxSupportDirectory;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:file_picker/file_picker.dart';
import '../globals.dart';
import '../managers/external_server_manager.dart';
import 'album_message_widget.dart';
import 'chat_images_scope.dart';
import 'blur_placeholder.dart';
import '../utils/image_size_cache.dart';
import '../utils/image_file_cache.dart';
import '../utils/blurhash_cache.dart';
import '../utils/wallpaper_util.dart';

enum _ImageMenuAction { download, setWallpaper }

// Singleton future so all widgets share one async init instead of each awaiting separately.
Future<String>? _imageDirFuture;
Future<String> _getImageDirPath() {
  return _imageDirFuture ??= () async {
    final appSupport = await getOnyxSupportDirectory();
    final dir = Directory('${appSupport.path}/image_cache');
    await dir.create(recursive: true);
    return dir.path;
  }();
}

class ImageMessageWidget extends StatefulWidget {
  final String filename;
  final String? owner;
  final String peerUsername;
  final bool isOutgoing;
  final String? mediaKeyB64;
  /// BlurHash from the message metadata — shows a blurred preview while the
  /// full image is still downloading. Null for images sent before this feature.
  final String? blurHash;
  /// Aspect ratio embedded in the message metadata, used to size the placeholder
  /// correctly before the real image dimensions are known.
  final double? initialAspectRatio;
  /// Decode width passed to [Image.file]'s `cacheWidth`. Defaults to 280
  /// (chat-bubble size). Callers that render this widget much smaller (e.g.
  /// a gallery grid tile shrunk via FittedBox) should pass the actual
  /// on-screen pixel width instead — decoding at the full bubble size only
  /// to immediately downscale it wastes CPU and is the main cause of laggy
  /// thumbnails when scrolling a dense grid.
  final int? cacheWidth;

  const ImageMessageWidget({
    Key? key,
    required this.filename,
    this.owner,
    required this.peerUsername,
    this.isOutgoing = false,
    this.mediaKeyB64,
    this.blurHash,
    this.initialAspectRatio,
    this.cacheWidth,
  }) : super(key: key);

  @override
  State<ImageMessageWidget> createState() => _ImageMessageWidgetState();
}

class _ImageMessageWidgetState extends State<ImageMessageWidget> {
  File? _imageFile;
  bool _loading = true;
  String? _error;
  double? _aspectRatio;


  @override
  void initState() {
    super.initState();
    
    final cached = imageFileCache[widget.filename];
    if (cached != null && cached.file.existsSync()) {
      _imageFile = cached.file;
      _aspectRatio = cached.aspectRatio;
      _loading = false;
      BlurHashCache.instance.ensureFor(widget.filename, cached.file);
    } else {
      _aspectRatio = widget.initialAspectRatio;
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
        BlurHashCache.instance.ensureFor(widget.filename, cached.file);
        setState(() {
          _imageFile = cached.file;
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

      final cacheDirPath = await _getImageDirPath();

      File? cachedFile;

      if (widget.filename.startsWith('file://')) {
        cachedFile = File(widget.filename.substring(7));
        if (!(await cachedFile.exists())) {
          throw Exception('Mesh file not found: ${widget.filename}');
        }
      } else if (widget.filename.startsWith('lan://')) {
        debugPrint('[ImageWidget] LAN file detected: ${widget.filename}');

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
        final ext = _guessExtension(url) ?? '.jpg';
        cachedFile = File('${cacheDirPath}/$safeName$ext');

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
        
        final cachedPath = '${cacheDirPath}/${widget.filename}';
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

        // Remember a BlurHash for this image so future loads-from-cache (and
        // images sent without an embedded hash) still show a blurred preview.
        BlurHashCache.instance.ensureFor(widget.filename, cachedFile);

        if (mounted) {
          setState(() {
            _imageFile = cachedFile;
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

  Future<void> _setImageAsWallpaper() async {
    final file = _imageFile;
    if (file == null || !(await file.exists())) {
      rootScreenKey.currentState?.showSnack('Image not downloaded');
      return;
    }
    try {
      await setFileAsChatWallpaper(file, isVideo: false);
      rootScreenKey.currentState?.showSnack('Wallpaper set');
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Failed to set wallpaper: $e');
    }
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
        File saveFile = file;
        File? tempJpg;
        if (p.extension(file.path).toLowerCase() == '.jfif') {
          final tmp = await getTemporaryDirectory();
          tempJpg = File('${tmp.path}/${p.basenameWithoutExtension(file.path)}.jpg');
          await file.copy(tempJpg.path);
          saveFile = tempJpg;
        }
        final saved = await GallerySaver.saveImage(saveFile.path, albumName: 'ONYX');
        await tempJpg?.delete().catchError((_) => File(''));
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

    final scope = ChatImagesScope.maybeOf(context);
    if (scope != null && scope.allImages.isNotEmpty) {
      final idx = scope.allImages.indexWhere((i) => i.filename == widget.filename);
      if (idx >= 0) {
        Navigator.of(context).push(buildGalleryRoute(AlbumGallery(
          allItems: scope.allImages,
          initialIndex: idx,
          peerUsername: widget.peerUsername,
          isOutgoing: widget.isOutgoing,
        )));
        return;
      }
    }

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
                          child: PopupMenuButton<_ImageMenuAction>(
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.white),
                            tooltip: 'More',
                            useRootNavigator: true,
                            onSelected: (action) {
                              switch (action) {
                                case _ImageMenuAction.download:
                                  _saveImageToGalleryOrFolder();
                                  break;
                                case _ImageMenuAction.setWallpaper:
                                  _setImageAsWallpaper();
                                  break;
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _ImageMenuAction.download,
                                child: ListTile(
                                  leading: Icon(Icons.download_rounded),
                                  title: Text('Download'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _ImageMenuAction.setWallpaper,
                                child: ListTile(
                                  leading: Icon(Icons.wallpaper_rounded),
                                  title: Text('Set as wallpaper'),
                                ),
                              ),
                            ],
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
      );
    });
  }

  /// Blurred placeholder (BlurHash + centre button) sized to the message's
  /// aspect ratio. Shown while downloading and on error.
  Widget _placeholderBox(
      {required IconData icon, VoidCallback? onTap, bool loading = false}) {
    final aspectRatio = _aspectRatio ?? widget.initialAspectRatio ?? 4 / 3;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 400),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BlurPlaceholder(
            blurHash: widget.blurHash ??
                BlurHashCache.instance.get(widget.filename),
            icon: icon,
            onTap: onTap,
            loading: loading,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _placeholderBox(
        icon: Icons.refresh,
        onTap: () {
          setState(() {
            _error = null;
            _loading = true;
          });
          _loadImageFile();
        },
      );
    }
    if (_imageFile != null) {
      // The image is loaded — always render it. (Previously large images were
      // hidden behind a grey "Scroll to load" box when off-screen to save
      // memory; that made already-loaded photos look unloaded until tapped.
      // Decoding is bounded by cacheWidth below, so memory stays in check.)
      final aspectRatio = _aspectRatio ?? 4 / 3;
      return RepaintBoundary(
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
                    cacheWidth: widget.cacheWidth ?? 560,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return _placeholderBox(icon: Icons.close, loading: true);
    }
    return const Text(' No image');
  }
}