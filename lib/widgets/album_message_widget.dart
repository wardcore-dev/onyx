// lib/widgets/album_message_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../utils/image_file_cache.dart';
import '../utils/file_utils.dart';
import '../utils/image_loader.dart';
import '../globals.dart';
import 'chat_images_scope.dart';
import 'blur_placeholder.dart';
import '../utils/blurhash_cache.dart';
import '../utils/wallpaper_util.dart';
import '../utils/font_utils.dart';
import '../l10n/app_localizations.dart';

enum _MenuAction { download, setWallpaper }

class AlbumItem {
  final String filename;
  final String orig;
  final String? owner;
  final String? mediaKeyB64;

  /// BlurHash for a blurred preview while the image downloads (null if absent).
  final String? blurHash;

  const AlbumItem({
    required this.filename,
    required this.orig,
    this.owner,
    this.mediaKeyB64,
    this.blurHash,
  });

  factory AlbumItem.fromJson(Map<String, dynamic> json) => AlbumItem(
        filename: json['filename'] as String? ?? json['url'] as String? ?? '',
        orig: json['orig'] as String? ?? 'image',
        owner: json['owner'] as String?,
        mediaKeyB64: json['key'] as String?,
        blurHash: json['blur'] as String?,
      );
}

class AlbumMessageWidget extends StatelessWidget {
  final List<AlbumItem> items;
  final String peerUsername;
  final bool isOutgoing;

  /// Scales the grid's displayed dimensions to match the app-wide "message
  /// size" setting, same as the text/timestamp scaling.
  final double fontSizeMultiplier;

  const AlbumMessageWidget({
    Key? key,
    required this.items,
    required this.peerUsername,
    this.isOutgoing = false,
    this.fontSizeMultiplier = 1.0,
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
        width: _totalWidth * fontSizeMultiplier,
        child: _buildGrid(context, clipped),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<AlbumItem> list) {
    final n = list.length;
    final w = _totalWidth * fontSizeMultiplier;
    final g = _gap * fontSizeMultiplier;
    final m = fontSizeMultiplier;

    if (n == 1) {
      return _t(context, list, 0, w: w, h: 280 * m);
    }

    if (n == 2) {
      final cw = (w - g) / 2;
      return _row([
        _t(context, list, 0, w: cw, h: 140 * m),
        _t(context, list, 1, w: cw, h: 140 * m),
      ]);
    }

    if (n == 3) {
      final cw = (w - g) / 2;
      return _col([
        _t(context, list, 0, w: w, h: 160 * m),
        _row([
          _t(context, list, 1, w: cw, h: 120 * m),
          _t(context, list, 2, w: cw, h: 120 * m),
        ]),
      ]);
    }

    if (n == 4) {
      final cw = (w - g) / 2;
      return _col([
        _row([
          _t(context, list, 0, w: cw, h: 120 * m),
          _t(context, list, 1, w: cw, h: 120 * m),
        ]),
        _row([
          _t(context, list, 2, w: cw, h: 120 * m),
          _t(context, list, 3, w: cw, h: 120 * m),
        ]),
      ]);
    }

    if (n == 5) {
      final cw2 = (w - g) / 2;
      final cw3 = (w - 2 * g) / 3;
      return _col([
        _row([
          _t(context, list, 0, w: cw2, h: 120 * m),
          _t(context, list, 1, w: cw2, h: 120 * m),
        ]),
        _row([
          _t(context, list, 2, w: cw3, h: 100 * m),
          _t(context, list, 3, w: cw3, h: 100 * m),
          _t(context, list, 4, w: cw3, h: 100 * m),
        ]),
      ]);
    }

    if (n == 6) {
      final cw = (w - 2 * g) / 3;
      return _col([
        _row([
          _t(context, list, 0, w: cw, h: 120 * m),
          _t(context, list, 1, w: cw, h: 120 * m),
          _t(context, list, 2, w: cw, h: 120 * m),
        ]),
        _row([
          _t(context, list, 3, w: cw, h: 120 * m),
          _t(context, list, 4, w: cw, h: 120 * m),
          _t(context, list, 5, w: cw, h: 120 * m),
        ]),
      ]);
    }

    final cw = (w - 2 * g) / 3;
    final ch = 90.0 * m;
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
        children:
            _intersperse(children, SizedBox(width: _gap * fontSizeMultiplier)),
      );

  Widget _col(List<Widget> children) => Column(
        mainAxisSize: MainAxisSize.min,
        children:
            _intersperse(children, SizedBox(height: _gap * fontSizeMultiplier)),
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
        // Key by filename so Flutter never recycles one thumb's State for a
        // different image during a rebuild — that recycling used to leave the
        // first albums stuck on the blurred placeholder after a chat opened.
        key: ValueKey(allItems[index].filename),
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
  // Filename this thumb is currently subscribed to via ImageLoader's per-file
  // listeners (null when not subscribed).
  String? _listeningFilename;

  @override
  void initState() {
    super.initState();
    final cached = imageFileCache[widget.item.filename];
    final hit = cached != null && cached.file.existsSync();
    if (hit) {
      _file = cached.file;
      _loading = false;
      BlurHashCache.instance.ensureFor(widget.item.filename, cached.file);
    } else {
      // Listen for THIS file landing in the cache (e.g. via the preloader or a
      // sibling) so we display it even if our own _loadFile setState is starved
      // when many thumbnails load at once — that left favorites albums stuck on
      // the placeholder until an unrelated rebuild (opening the app bar) ran.
      _startListeningCache();
      _loadFile();
    }
  }

  void _onCacheChanged() {
    if (!mounted || _file != null) return;
    // Trust the cache entry (ImageLoader verified the file exists before adding
    // it); avoid an existsSync here — this runs once per cached image across all
    // listening thumbs, so a syscall each time would itself jank a big album.
    final cached = imageFileCache[widget.item.filename];
    if (cached != null) {
      BlurHashCache.instance.ensureFor(widget.item.filename, cached.file);
      _stopListeningCache();
      setState(() {
        _file = cached.file;
        _loading = false;
        _error = false;
      });
    }
  }

  void _startListeningCache() {
    if (_listeningFilename == widget.item.filename) return;
    _stopListeningCache();
    ImageLoader.addFileListener(widget.item.filename, _onCacheChanged);
    _listeningFilename = widget.item.filename;
  }

  void _stopListeningCache() {
    final fn = _listeningFilename;
    if (fn != null) {
      ImageLoader.removeFileListener(fn, _onCacheChanged);
      _listeningFilename = null;
    }
  }

  @override
  void dispose() {
    _stopListeningCache();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AlbumThumb old) {
    super.didUpdateWidget(old);
    // Thumbs are keyed by filename, so the State is never reused for a
    // different image — but keep this defensive in case the key strategy
    // changes.
    if (old.item.filename != widget.item.filename) {
      final cached = imageFileCache[widget.item.filename];
      if (cached != null && cached.file.existsSync()) {
        _stopListeningCache();
        BlurHashCache.instance.ensureFor(widget.item.filename, cached.file);
        setState(() {
          _file = cached.file;
          _loading = false;
          _error = false;
        });
        return;
      }
      // Re-subscribe to the new filename before kicking off its load.
      _startListeningCache();
      setState(() {
        _loading = true;
        _error = false;
        _file = null;
      });
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    // Load exactly like a single photo (ImageMessageWidget): resolve from local
    // disk or download. ImageLoader handles lan://, fav://, http and standard
    // files, dedups concurrent requests for the same filename, populates
    // imageFileCache and computes the aspect ratio. Only `mounted` guards the
    // result — no generation counter, which previously dropped a completed
    // load during chat-open churn and left the first albums stuck.
    final entry = await ImageLoader.load(
      widget.item.filename,
      peerUsername: widget.peerUsername,
      owner: widget.item.owner,
      mediaKeyB64: widget.item.mediaKeyB64,
      // Album thumbs render at a fixed size — skip the per-image header read
      // that was throttling chat open.
      computeMetadata: false,
    );
    if (!mounted) return;
    if (entry != null) {
      BlurHashCache.instance.ensureFor(widget.item.filename, entry.file);
      _stopListeningCache();
    }
    setState(() {
      if (entry != null) {
        _file = entry.file;
        _loading = false;
        _error = false;
      } else {
        _error = true;
        _loading = false;
      }
    });
  }

  void _openGallery() {
    final scope = ChatImagesScope.maybeOf(context);
    List<AlbumItem> galleryItems;
    int initialIdx;

    if (scope != null && scope.allImages.isNotEmpty) {
      final idx =
          scope.allImages.indexWhere((i) => i.filename == widget.item.filename);
      if (idx >= 0) {
        galleryItems = scope.allImages;
        initialIdx = idx;
      } else {
        galleryItems = widget.allItems;
        initialIdx = widget.index;
      }
    } else {
      galleryItems = widget.allItems;
      initialIdx = widget.index;
    }

    Navigator.of(context).push(buildGalleryRoute(AlbumGallery(
      allItems: galleryItems,
      albumItems: widget.allItems.length > 1 ? widget.allItems : null,
      initialIndex: initialIdx,
      peerUsername: widget.peerUsername,
      isOutgoing: widget.isOutgoing,
    )));
  }

  @override
  Widget build(BuildContext context) {
    // Self-heal: if the file became available through any path (our own load,
    // the preloader, or a sibling thumb) adopt it on the next rebuild even if
    // our own load callback never fired. Cheap O(1) cache check; no setState
    // needed since we're already rebuilding.
    if (_file == null) {
      final cached = imageFileCache[widget.item.filename];
      if (cached != null && cached.file.existsSync()) {
        _file = cached.file;
        _loading = false;
        _error = false;
        _stopListeningCache();
      }
    }
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
    final hash = widget.item.blurHash ??
        BlurHashCache.instance.get(widget.item.filename);
    if (_loading) {
      return BlurPlaceholder(blurHash: hash, loading: true);
    }
    if (_error || _file == null) {
      return BlurPlaceholder(
        blurHash: hash,
        icon: Icons.refresh,
        onTap: () {
          setState(() {
            _error = false;
            _loading = true;
            _file = null;
          });
          _loadFile();
        },
      );
    }
    // Decode at roughly the displayed pixel size (capped at 560) instead of the
    // image's full resolution — a 4K photo into a ~90px cell would otherwise
    // decode a ~50 MB raster on the main isolate and jank the whole list.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (widget.width * dpr).round().clamp(64, 560);
    return Image.file(
      _file!,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Snappy scale+fade entrance for the fullscreen gallery — replaces the
/// default MaterialPageRoute slide, which felt sluggish opening straight
/// into a solid black scaffold with no sense of motion from the tapped thumb.
Route<T> buildGalleryRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    opaque: true,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Height of the desktop window's custom title bar (see main.dart's builder),
/// which sits on top of every screen.
double get _galleryTopInset =>
    (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS))
        ? 42.0
        : 0.0;

class AlbumGallery extends StatefulWidget {
  final List<AlbumItem> allItems;
  final int initialIndex;
  final String peerUsername;
  final bool isOutgoing;
  // Non-null only when opened from an actual album message; used for "Save All".
  final List<AlbumItem>? albumItems;

  const AlbumGallery({
    Key? key,
    required this.allItems,
    required this.initialIndex,
    required this.peerUsername,
    required this.isOutgoing,
    this.albumItems,
  }) : super(key: key);

  @override
  State<AlbumGallery> createState() => _AlbumGalleryState();
}

class _AlbumGalleryState extends State<AlbumGallery> {
  late PageController _ctrl;
  late ScrollController _stripCtrl;
  late int _current;

  static const double _thumbSize = 60.0;
  static const double _thumbGap = 4.0;

  // Swiping between photos and pinch-to-zoom on a photo both start as a
  // gesture on the same PageView area, so they compete in the same gesture
  // arena. Disable the page swipe (a) while a page is actually zoomed in,
  // and (b) the instant a second finger touches down — that second case
  // matters because PageView's single-pointer drag recognizer can otherwise
  // claim the very first finger of a pinch before the second one lands,
  // turning an intended zoom into an accidental swipe.
  bool _isZoomed = false;
  int _activePointers = 0;

  bool get _pageSwipeEnabled => !_isZoomed && _activePointers < 2;

  void _setZoomed(bool zoomed) {
    if (_isZoomed != zoomed) setState(() => _isZoomed = zoomed);
  }

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
    _stripCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToThumbnail(widget.initialIndex, animate: false));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _stripCtrl.dispose();
    super.dispose();
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_stripCtrl.hasClients) return;
    final totalItem = _thumbSize + _thumbGap;
    final offset = index * totalItem -
        (_stripCtrl.position.viewportDimension / 2 - _thumbSize / 2);
    final clamped = offset.clamp(0.0, _stripCtrl.position.maxScrollExtent);
    if (animate) {
      _stripCtrl.animateTo(clamped,
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    } else {
      _stripCtrl.jumpTo(clamped);
    }
  }

  void _prevPage() {
    if (_current > 0) {
      _ctrl.previousPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  void _nextPage() {
    if (_current < widget.allItems.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
    }
  }

  Widget _buildThumbItem(int i) {
    final isActive = i == _current;
    return GestureDetector(
      onTap: () => _ctrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      ),
      child: Container(
        width: _thumbSize,
        height: _thumbSize,
        margin: EdgeInsets.only(
            right: i < widget.allItems.length - 1 ? _thumbGap : 0),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? Colors.white : Colors.white24,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: _StripThumb(
            item: widget.allItems[i],
            peerUsername: widget.peerUsername,
            isOutgoing: widget.isOutgoing,
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    final totalContent = widget.allItems.length * _thumbSize +
        (widget.allItems.length - 1) * _thumbGap;

    return Container(
      color: Colors.black,
      height: _thumbSize + 12,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final fits = totalContent <= constraints.maxWidth - 16;
          if (fits) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < widget.allItems.length; i++)
                    _buildThumbItem(i),
                ],
              ),
            );
          }
          return ListView.builder(
            controller: _stripCtrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            itemCount: widget.allItems.length,
            itemBuilder: (_, i) => _buildThumbItem(i),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.keyA) {
          _prevPage();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyD) {
          _nextPage();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      // On desktop the app's own 42 px window title bar (the three dots) is
      // drawn on top of every screen; without this inset it covered this
      // AppBar -- the back arrow, the "N / M" counter and the menu.
      child: Padding(
        padding: EdgeInsets.only(top: _galleryTopInset),
        child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            '${_current + 1} / ${widget.allItems.length}',
            style: buildMessageTextStyle(
              context: context,
              baseFontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          actions: [
            PopupMenuButton<_MenuAction>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'More',
              useRootNavigator: true,
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.download:
                    _showSaveDialog();
                    break;
                  case _MenuAction.setWallpaper:
                    _setCurrentAsWallpaper();
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _MenuAction.download,
                  child: ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: Text(l.download),
                  ),
                ),
                PopupMenuItem(
                  value: _MenuAction.setWallpaper,
                  child: ListTile(
                    leading: const Icon(Icons.wallpaper_rounded),
                    title: Text(l.setAsWallpaper),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) =>
                    setState(() => _activePointers++),
                onPointerUp: (_) => setState(
                    () => _activePointers = (_activePointers - 1).clamp(0, 10)),
                onPointerCancel: (_) => setState(
                    () => _activePointers = (_activePointers - 1).clamp(0, 10)),
                child: Stack(
                children: [
                  PageView.builder(
                    controller: _ctrl,
                    physics: _pageSwipeEnabled
                        ? const PageScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: widget.allItems.length,
                    onPageChanged: (i) {
                      setState(() => _current = i);
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToThumbnail(i));
                    },
                    itemBuilder: (_, i) => _GalleryPage(
                      item: widget.allItems[i],
                      peerUsername: widget.peerUsername,
                      isOutgoing: widget.isOutgoing,
                      onZoomChanged: _setZoomed,
                    ),
                  ),
                  if (!kIsWeb &&
                      (Platform.isWindows ||
                          Platform.isLinux ||
                          Platform.isMacOS)) ...[
                    if (_current > 0)
                      Positioned(
                        left: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                            child: _NavArrow(
                                icon: Icons.arrow_back_ios_rounded,
                                onTap: _prevPage)),
                      ),
                    if (_current < widget.allItems.length - 1)
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                            child: _NavArrow(
                                icon: Icons.arrow_forward_ios_rounded,
                                onTap: _nextPage)),
                      ),
                  ],
                ],
                ),
              ),
            ),
            _buildThumbnailStrip(),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    final l = AppLocalizations.of(context);
    final isAlbum = (widget.albumItems?.length ?? 0) > 1;
    if (!isAlbum) {
      await _saveCurrentImage();
      return;
    }
    final result = await showDialog<_SaveChoice>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Save image', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Save only the current image or all images in the album?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _SaveChoice.cancel),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _SaveChoice.current),
            child: Text(l.current),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _SaveChoice.all),
            child: const Text('All'),
          ),
        ],
      ),
    );
    if (result == _SaveChoice.current) await _saveCurrentImage();
    if (result == _SaveChoice.all) await _saveAllImages();
  }

  Future<void> _setCurrentAsWallpaper() async {
    final item = widget.allItems[_current];
    final cached = imageFileCache[item.filename];
    if (cached == null) {
      rootScreenKey.currentState?.showSnack('Image not loaded yet');
      return;
    }
    try {
      await setFileAsChatWallpaper(cached.file, isVideo: false);
      rootScreenKey.currentState?.showSnack('Wallpaper set');
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Failed to set wallpaper: $e');
    }
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
        final saved = await saveImageToGallery(file.path);
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
        showSavedToSnack(destPath);
        return;
      }

      rootScreenKey.currentState
          ?.showSnack('Save not supported on this platform');
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  Future<void> _saveAllImages() async {
    if (kIsWeb) {
      rootScreenKey.currentState?.showSnack('Save not supported on web');
      return;
    }

    final items = widget.albumItems ?? widget.allItems;
    int saved = 0;
    int failed = 0;

    if (Platform.isAndroid || Platform.isIOS) {
      for (final item in items) {
        final cached = imageFileCache[item.filename];
        if (cached == null) {
          failed++;
          continue;
        }
        try {
          final result = await saveImageToGallery(cached.file.path);
          if (result == true) {
            saved++;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }
      rootScreenKey.currentState?.showSnack(
        failed == 0
            ? 'All $saved images saved to gallery'
            : '$saved saved, $failed failed',
      );
      return;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose folder to save all images',
      );
      if (dirPath == null || dirPath.isEmpty) {
        rootScreenKey.currentState?.showSnack('Save cancelled');
        return;
      }
      for (final item in items) {
        final cached = imageFileCache[item.filename];
        if (cached == null) {
          failed++;
          continue;
        }
        try {
          final orig =
              item.orig.isNotEmpty ? item.orig : p.basename(item.filename);
          await cached.file.copy(p.join(dirPath, orig));
          saved++;
        } catch (_) {
          failed++;
        }
      }
      rootScreenKey.currentState?.showSnack(
        failed == 0
            ? 'All $saved images saved to: $dirPath'
            : '$saved saved, $failed failed',
      );
      return;
    }

    rootScreenKey.currentState
        ?.showSnack('Save not supported on this platform');
  }
}

class _StripThumb extends StatefulWidget {
  final AlbumItem item;
  final String peerUsername;
  final bool isOutgoing;
  const _StripThumb({
    required this.item,
    required this.peerUsername,
    required this.isOutgoing,
  });

  @override
  State<_StripThumb> createState() => _StripThumbState();
}

class _StripThumbState extends State<_StripThumb> {
  File? _file;
  // Filename this thumb is currently subscribed to via ImageLoader's per-file
  // listeners (null when not subscribed) — mirrors _AlbumThumb's pattern.
  String? _listeningFilename;

  @override
  void initState() {
    super.initState();
    final cached = imageFileCache[widget.item.filename];
    if (cached != null && cached.file.existsSync()) {
      _file = cached.file;
    } else {
      // Unlike a chat thumb, this strip entry previously only ever read the
      // cache once and never triggered a fetch — distant images in the
      // fullscreen filmstrip that hadn't been viewed/cached yet stayed a flat
      // gray box forever. Fetch + listen just like _AlbumThumb does.
      _startListeningCache();
      _loadFile();
    }
  }

  @override
  void didUpdateWidget(covariant _StripThumb old) {
    super.didUpdateWidget(old);
    if (old.item.filename != widget.item.filename) {
      _stopListeningCache();
      final cached = imageFileCache[widget.item.filename];
      if (cached != null && cached.file.existsSync()) {
        setState(() => _file = cached.file);
      } else {
        setState(() => _file = null);
        _startListeningCache();
        _loadFile();
      }
    }
  }

  void _onCacheChanged() {
    if (!mounted || _file != null) return;
    final cached = imageFileCache[widget.item.filename];
    if (cached != null) {
      _stopListeningCache();
      setState(() => _file = cached.file);
    }
  }

  void _startListeningCache() {
    if (_listeningFilename == widget.item.filename) return;
    _stopListeningCache();
    ImageLoader.addFileListener(widget.item.filename, _onCacheChanged);
    _listeningFilename = widget.item.filename;
  }

  void _stopListeningCache() {
    final fn = _listeningFilename;
    if (fn != null) {
      ImageLoader.removeFileListener(fn, _onCacheChanged);
      _listeningFilename = null;
    }
  }

  Future<void> _loadFile() async {
    final entry = await ImageLoader.load(
      widget.item.filename,
      peerUsername: widget.peerUsername,
      owner: widget.item.owner,
      mediaKeyB64: widget.item.mediaKeyB64,
      computeMetadata: false,
    );
    if (!mounted || _file != null) return;
    if (entry != null) {
      _stopListeningCache();
      setState(() => _file = entry.file);
    }
  }

  @override
  void dispose() {
    _stopListeningCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Self-heal on rebuild in case the fetch/listener path was missed.
    if (_file == null) {
      final cached = imageFileCache[widget.item.filename];
      if (cached != null && cached.file.existsSync()) {
        _file = cached.file;
        _stopListeningCache();
      }
    }
    if (_file != null) {
      return Image.file(_file!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Container(color: Colors.grey[850]);
  }
}

class _GalleryPage extends StatefulWidget {
  final AlbumItem item;
  final String peerUsername;
  final bool isOutgoing;
  // Notified whenever this page's zoom level crosses in/out of "zoomed"
  // (scale > 1), so the parent PageView can disable page-swiping while the
  // user is zoomed into a photo.
  final ValueChanged<bool> onZoomChanged;

  const _GalleryPage({
    required this.item,
    required this.peerUsername,
    required this.isOutgoing,
    required this.onZoomChanged,
  });

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage>
    with SingleTickerProviderStateMixin {
  File? _file;
  final TransformationController _transformCtrl = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _reportedZoomed = false;

  late final AnimationController _zoomAnimController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    final cached = imageFileCache[widget.item.filename];
    if (cached != null && cached.file.existsSync()) {
      _file = cached.file;
    }
    _transformCtrl.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final zoomed = _transformCtrl.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _reportedZoomed) {
      _reportedZoomed = zoomed;
      widget.onZoomChanged(zoomed);
    }
  }

  // Tweens smoothly from the current transform to [end] instead of jumping
  // straight there, so double-tap zoom feels the same as Telegram/WhatsApp.
  void _animateTransformTo(Matrix4 end) {
    _zoomAnimation?.removeListener(_onZoomTick);
    final animation = Matrix4Tween(begin: _transformCtrl.value, end: end)
        .animate(CurvedAnimation(
      parent: _zoomAnimController,
      curve: Curves.easeOutCubic,
    ));
    _zoomAnimation = animation..addListener(_onZoomTick);
    _zoomAnimController
      ..reset()
      ..forward();
  }

  void _onZoomTick() {
    final animation = _zoomAnimation;
    if (animation != null) _transformCtrl.value = animation.value;
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (details == null) return;
    final isZoomedIn = _transformCtrl.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomedIn) {
      _animateTransformTo(Matrix4.identity());
      return;
    }
    final tapPos = details.localPosition;
    final zoomed = Matrix4.identity()
      ..translateByDouble(-tapPos.dx * (_doubleTapScale - 1),
          -tapPos.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    _animateTransformTo(zoomed);
  }

  @override
  void dispose() {
    if (_reportedZoomed) widget.onZoomChanged(false);
    _zoomAnimation?.removeListener(_onZoomTick);
    _zoomAnimController.dispose();
    _transformCtrl.removeListener(_onTransformChanged);
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_file != null) {
      return GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformCtrl,
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(child: Image.file(_file!, fit: BoxFit.contain)),
        ),
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

enum _SaveChoice { cancel, current, all }
