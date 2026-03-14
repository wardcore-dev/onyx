// lib/widgets/album_message_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/image_file_cache.dart';
import '../utils/image_size_cache.dart';
import '../globals.dart';
import '../managers/external_server_manager.dart';

class AlbumItem {
  final String filename; 
  final String orig; 
  final String? owner; 
  final String? mediaKeyB64; 

  const AlbumItem({required this.filename, required this.orig, this.owner, this.mediaKeyB64});

  factory AlbumItem.fromJson(Map<String, dynamic> json) => AlbumItem(
        filename: json['filename'] as String? ?? json['url'] as String? ?? '',
        orig: json['orig'] as String? ?? 'image',
        owner: json['owner'] as String?,
        mediaKeyB64: json['key'] as String?,
      );
}

class AlbumMessageWidget extends StatelessWidget {
  final List<AlbumItem> items;
  final String peerUsername;
  final bool isOutgoing;

  const AlbumMessageWidget({
    Key? key,
    required this.items,
    required this.peerUsername,
    this.isOutgoing = false,
  }) : super(key: key);

  static const double _totalWidth = 280.0;
  static const double _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final clipped = items.take(10).toList();
    if (clipped.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: _totalWidth,
        child: _buildGrid(context, clipped),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<AlbumItem> list) {
    final n = list.length;
    const w = _totalWidth;
    const g = _gap;

    if (n == 1) {
      return _t(context, list, 0, w: w, h: 280);
    }

    if (n == 2) {
      final cw = (w - g) / 2;
      return _row([
        _t(context, list, 0, w: cw, h: 140),
        _t(context, list, 1, w: cw, h: 140),
      ]);
    }

    if (n == 3) {
      final cw = (w - g) / 2;
      return _col([
        _t(context, list, 0, w: w, h: 160),
        _row([
          _t(context, list, 1, w: cw, h: 120),
          _t(context, list, 2, w: cw, h: 120),
        ]),
      ]);
    }

    if (n == 4) {
      final cw = (w - g) / 2;
      return _col([
        _row([
          _t(context, list, 0, w: cw, h: 120),
          _t(context, list, 1, w: cw, h: 120),
        ]),
        _row([
          _t(context, list, 2, w: cw, h: 120),
          _t(context, list, 3, w: cw, h: 120),
        ]),
      ]);
    }

    if (n == 5) {
      final cw2 = (w - g) / 2;
      final cw3 = (w - 2 * g) / 3;
      return _col([
        _row([
          _t(context, list, 0, w: cw2, h: 120),
          _t(context, list, 1, w: cw2, h: 120),
        ]),
        _row([
          _t(context, list, 2, w: cw3, h: 100),
          _t(context, list, 3, w: cw3, h: 100),
          _t(context, list, 4, w: cw3, h: 100),
        ]),
      ]);
    }

    if (n == 6) {
      final cw = (w - 2 * g) / 3;
      return _col([
        _row([
          _t(context, list, 0, w: cw, h: 120),
          _t(context, list, 1, w: cw, h: 120),
          _t(context, list, 2, w: cw, h: 120),
        ]),
        _row([
          _t(context, list, 3, w: cw, h: 120),
          _t(context, list, 4, w: cw, h: 120),
          _t(context, list, 5, w: cw, h: 120),
        ]),
      ]);
    }

    final cw = (w - 2 * g) / 3;
    const ch = 90.0;
    final rows = <Widget>[];
    for (int i = 0; i < n; i += 3) {
      final end = (i + 3 < n) ? i + 3 : n;
      final rowChildren = <Widget>[];
      for (int j = i; j < end; j++) {
        rowChildren.add(_t(context, list, j, w: cw, h: ch));
      }
      
      while (rowChildren.length < 3) {
        rowChildren.add(SizedBox(width: cw, height: ch));
      }
      rows.add(_row(rowChildren));
    }
    return _col(rows);
  }

  Widget _row(List<Widget> children) => Row(
        mainAxisSize: MainAxisSize.min,
        children: _intersperse(children, const SizedBox(width: _gap)),
      );

  Widget _col(List<Widget> children) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _intersperse(children, const SizedBox(height: _gap)),
      );

  List<Widget> _intersperse(List<Widget> list, Widget sep) {
    final result = <Widget>[];
    for (int i = 0; i < list.length; i++) {
      if (i > 0) result.add(sep);
      result.add(list[i]);
    }
    return result;
  }

  Widget _t(
    BuildContext context,
    List<AlbumItem> allItems,
    int index, {
    required double w,
    required double h,
  }) =>
      _AlbumThumb(
        item: allItems[index],
        allItems: allItems,
        index: index,
        width: w,
        height: h,
        peerUsername: peerUsername,
        isOutgoing: isOutgoing,
      );
}

class _AlbumThumb extends StatefulWidget {
  final AlbumItem item;
  final List<AlbumItem> allItems;
  final int index;
  final double width;
  final double height;
  final String peerUsername;
  final bool isOutgoing;

  const _AlbumThumb({
    Key? key,
    required this.item,
    required this.allItems,
    required this.index,
    required this.width,
    required this.height,
    required this.peerUsername,
    required this.isOutgoing,
  }) : super(key: key);

  @override
  State<_AlbumThumb> createState() => _AlbumThumbState();
}

class _AlbumThumbState extends State<_AlbumThumb> {
  File? _file;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    final cached = imageFileCache[widget.item.filename];
    if (cached != null && cached.file.existsSync()) {
      _file = cached.file;
      _loading = false;
    } else {
      _loadFile();
    }
  }

  @override
  void didUpdateWidget(covariant _AlbumThumb old) {
    super.didUpdateWidget(old);
    if (old.item.filename != widget.item.filename) {
      final cached = imageFileCache[widget.item.filename];
      if (cached != null && cached.file.existsSync()) {
        setState(() {
          _file = cached.file;
          _loading = false;
          _error = false;
        });
        return;
      }
      setState(() {
        _loading = true;
        _error = false;
        _file = null;
      });
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/image_cache');
      await cacheDir.create(recursive: true);

      File? resolved;
      final filename = widget.item.filename;

      if (filename.startsWith('lan://')) {
        final lanFilename = filename.substring(6);
        final appDoc = await getApplicationDocumentsDirectory();
        resolved = File('${appDoc.path}/lan_media/$lanFilename');
        if (!await resolved.exists()) throw Exception('LAN file not found');
      } else if (filename.startsWith('http')) {
        var url = filename;
        final pathSeg = Uri.parse(url).pathSegments.last;
        final safeName = pathSeg.replaceAll(RegExp(r'[^\w\-.]'), '_');
        final ext = _guessExt(url) ?? '.jpg';
        resolved = File('${cacheDir.path}/$safeName$ext');
        if (!await resolved.exists()) {
          final uri = Uri.parse(url);
          if (!url.contains('?token=') && !url.contains('&token=')) {
            final servers = ExternalServerManager.servers.value;
            if (servers.any((s) => s.host == uri.host && s.port == uri.port)) {
              final srv = servers.firstWhere(
                  (s) => s.host == uri.host && s.port == uri.port);
              url = '$url?token=${Uri.encodeComponent(srv.token)}';
            }
          }
          final res = await http.get(Uri.parse(url));
          if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
          await resolved.writeAsBytes(res.bodyBytes);
        }
      } else {
        resolved = File('${cacheDir.path}/$filename');
        if (!await resolved.exists()) {
          final root = rootScreenKey.currentState;
          if (root == null) throw Exception('RootScreen not ready');
          final dl = await root.downloadImageToCache(
            filename,
            peerUsername: widget.peerUsername,
            owner: widget.item.owner,
            mediaKeyB64: widget.item.mediaKeyB64,
          );
          if (dl == null) throw Exception('File not available');
          resolved = dl;
        }
      }

      if (!mounted) return;
      final ar = await ImageSizeCache().getOrComputeAspectRatio(resolved);
      imageFileCache[widget.item.filename] = (
        file: resolved,
        size: resolved.lengthSync(),
        aspectRatio: ar,
      );
      if (mounted) setState(() { _file = resolved; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  void _openGallery() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AlbumGallery(
        allItems: widget.allItems,
        initialIndex: widget.index,
        peerUsername: widget.peerUsername,
        isOutgoing: widget.isOutgoing,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _file != null ? _openGallery : null,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _content(),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error || _file == null) {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
        ),
      );
    }
    return Image.file(
      _file!,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}

class _AlbumGallery extends StatefulWidget {
  final List<AlbumItem> allItems;
  final int initialIndex;
  final String peerUsername;
  final bool isOutgoing;

  const _AlbumGallery({
    Key? key,
    required this.allItems,
    required this.initialIndex,
    required this.peerUsername,
    required this.isOutgoing,
  }) : super(key: key);

  @override
  State<_AlbumGallery> createState() => _AlbumGalleryState();
}

class _AlbumGalleryState extends State<_AlbumGallery> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _prevPage() {
    if (_current > 0) {
      _ctrl.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  void _nextPage() {
    if (_current < widget.allItems.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
          _prevPage();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
          _nextPage();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            '${_current + 1} / ${widget.allItems.length}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              tooltip: 'Save',
              onPressed: _saveCurrentImage,
            ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.allItems.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => _GalleryPage(
                item: widget.allItems[i],
                peerUsername: widget.peerUsername,
                isOutgoing: widget.isOutgoing,
              ),
            ),
            if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) ...[
              if (_current > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _NavArrow(icon: Icons.arrow_back_ios_rounded, onTap: _prevPage)),
                ),
              if (_current < widget.allItems.length - 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _NavArrow(icon: Icons.arrow_forward_ios_rounded, onTap: _nextPage)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentImage() async {
    final item = widget.allItems[_current];
    final cached = imageFileCache[item.filename];
    if (cached == null) {
      rootScreenKey.currentState?.showSnack('Image not loaded yet');
      return;
    }
    final file = cached.file;
    final orig = item.orig.isNotEmpty ? item.orig : p.basename(item.filename);
    try {
      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack('Save not supported on web');
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        
        final saved = await GallerySaver.saveImage(file.path, albumName: 'ONYX');
        rootScreenKey.currentState?.showSnack(
            saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        return;
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final ext = p.extension(orig).replaceFirst('.', '');
        String? destPath;
        var dialogSupported = true;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save image as',
            fileName: orig,
            type: FileType.custom,
            allowedExtensions: ext.isNotEmpty ? [ext] : ['jpg'],
          );
        } catch (e) {
          dialogSupported = false;
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
          destPath = p.join(directoryPath, orig);
        }

        await file.copy(destPath);
        rootScreenKey.currentState?.showSnack('Saved to: $destPath');
        return;
      }

      rootScreenKey.currentState?.showSnack('Save not supported on this platform');
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }
}

class _GalleryPage extends StatefulWidget {
  final AlbumItem item;
  final String peerUsername;
  final bool isOutgoing;

  const _GalleryPage({
    Key? key,
    required this.item,
    required this.peerUsername,
    required this.isOutgoing,
  }) : super(key: key);

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    final cached = imageFileCache[widget.item.filename];
    if (cached != null && cached.file.existsSync()) {
      _file = cached.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file != null) {
      return InteractiveViewer(
        child: Center(child: Image.file(_file!, fit: BoxFit.contain)),
      );
    }
    
    return _AlbumThumb(
      item: widget.item,
      allItems: [widget.item],
      index: 0,
      width: double.infinity,
      height: double.infinity,
      peerUsername: widget.peerUsername,
      isOutgoing: widget.isOutgoing,
    );
  }
}

class _NavArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

String? _guessExt(String url) {
  final lower = url.toLowerCase().split('?').first;
  for (final ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']) {
    if (lower.endsWith(ext)) return ext;
  }
  return null;
}