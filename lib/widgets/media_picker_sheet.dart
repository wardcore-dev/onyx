// lib/widgets/media_picker_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';

/// Shows a Telegram-style media picker bottom sheet.
/// Returns a list of selected file paths, or null if cancelled / nothing chosen.
/// On desktop platforms falls back immediately to the system file picker.
Future<List<String>?> showMediaPickerSheet(BuildContext context) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MediaPickerSheet(),
  );
}

/// Single-pick variant for wallpaper selection.
/// Tap on any asset immediately returns its path; no multi-select.
/// Uses FileType.media so both images and videos are accessible via file picker.
Future<String?> showWallpaperPickerSheet(BuildContext context) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WallpaperPickerSheet(),
  );
  return result;
}

class _MediaPickerSheet extends StatefulWidget {
  const _MediaPickerSheet();

  @override
  State<_MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<_MediaPickerSheet> {
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  bool _loading = true;
  bool _denied = false;

  // Pagination
  AssetPathEntity? _album;
  int _totalCount = 0;
  bool _loadingMore = false;
  static const _pageSize = 80;

  // Drag-select
  bool _isDragSelecting = false;
  bool _dragSelectAdding = true;
  int? _lastDragRow;
  Offset _lastPointerGlobal = Offset.zero;
  Timer? _autoScrollTimer;

  // Edge-scroll zone: 80px from top/bottom of the grid.
  static const _edgeZone = 80.0;
  // Max scroll speed in px per frame (reached at the very edge).
  static const _maxSpeed = 12.0;

  final _gridKey = GlobalKey();
  ScrollController? _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final permitted = await PhotoManager.requestPermissionExtend();
    if (!permitted.isAuth) {
      if (mounted) setState(() { _loading = false; _denied = true; });
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _album = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
    _totalCount = await _album!.assetCountAsync;
    final assets = await _album!.getAssetListRange(start: 0, end: _pageSize.clamp(0, _totalCount));
    if (mounted) setState(() { _assets = assets; _loading = false; });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _album == null || _assets.length >= _totalCount) return;
    setState(() => _loadingMore = true);
    final start = _assets.length;
    final end = (start + _pageSize).clamp(0, _totalCount);
    final more = await _album!.getAssetListRange(start: start, end: end);
    if (mounted) setState(() { _assets.addAll(more); _loadingMore = false; });
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null && mounted) Navigator.of(context).pop([picked.path]);
  }

  Future<void> _openFilePicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: true);
    if (result != null && mounted) {
      Navigator.of(context).pop(result.files.map((f) => f.path).whereType<String>().toList());
    }
  }

  void _toggleSelect(AssetEntity asset) {
    setState(() {
      if (_selected.contains(asset)) {
        _selected.remove(asset);
      } else {
        _selected.add(asset);
      }
    });
  }

  void _startDragSelect(AssetEntity asset) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragSelectAdding = !_selected.contains(asset);
      if (_dragSelectAdding) {
        _selected.add(asset);
      } else {
        _selected.remove(asset);
      }
      _isDragSelecting = true;
      _lastDragRow = null;
    });
  }

  // Selects the entire row under the pointer — iOS Photos style.
  void _onPointerMove(PointerMoveEvent e) {
    if (!_isDragSelecting) return;
    _lastPointerGlobal = e.position;
    _selectRowAtGlobal(e.position);
    _updateAutoScroll(e.position);
  }

  void _selectRowAtGlobal(Offset global) {
    final row = _rowAtGlobal(global);
    if (row == null || row == _lastDragRow) return;
    _lastDragRow = row;

    // Row 0: Camera(col0), File(col1), assets[0](col2) → only assets[0]
    // Row r≥1: assets[r*3-2], assets[r*3-1], assets[r*3]
    final List<int> indices;
    if (row == 0) {
      indices = [0];
    } else {
      final s = row * 3 - 2;
      indices = [s, s + 1, s + 2];
    }

    setState(() {
      for (final idx in indices) {
        if (idx < 0 || idx >= _assets.length) continue;
        final asset = _assets[idx];
        if (_dragSelectAdding && !_selected.contains(asset)) {
          _selected.add(asset);
        } else if (!_dragSelectAdding) {
          _selected.remove(asset);
        }
      }
    });
  }

  // Starts or stops the auto-scroll timer based on pointer proximity to edges.
  void _updateAutoScroll(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    final gridH = box.size.height;

    final nearBottom = local.dy > gridH - _edgeZone;
    final nearTop = local.dy < _edgeZone;

    if (nearBottom || nearTop) {
      _autoScrollTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _autoScrollTick(),
      );
    } else {
      _stopAutoScroll();
    }
  }

  void _autoScrollTick() {
    final ctrl = _scrollCtrl;
    if (ctrl == null || !ctrl.hasClients || !_isDragSelecting) {
      _stopAutoScroll();
      return;
    }

    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(_lastPointerGlobal);
    final gridH = box.size.height;

    double speed = 0;
    if (local.dy > gridH - _edgeZone) {
      // Bottom edge — scroll down. Speed proportional to how deep into the zone.
      final depth = (local.dy - (gridH - _edgeZone)) / _edgeZone;
      speed = depth.clamp(0.0, 1.0) * _maxSpeed;
    } else if (local.dy < _edgeZone) {
      // Top edge — scroll up.
      final depth = (_edgeZone - local.dy) / _edgeZone;
      speed = -(depth.clamp(0.0, 1.0) * _maxSpeed);
    } else {
      _stopAutoScroll();
      return;
    }

    final newOffset = (ctrl.offset + speed).clamp(0.0, ctrl.position.maxScrollExtent);
    ctrl.jumpTo(newOffset);

    // Re-evaluate which row is under the pointer after scroll.
    _selectRowAtGlobal(_lastPointerGlobal);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _onPointerUp(PointerUpEvent e) {
    _isDragSelecting = false;
    _lastDragRow = null;
    _stopAutoScroll();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _isDragSelecting = false;
    _lastDragRow = null;
    _stopAutoScroll();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  // Returns the grid row index under the given global position.
  int? _rowAtGlobal(Offset global) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    final scroll = _scrollCtrl?.offset ?? 0;
    final cellH = box.size.width / 3; // square cells
    if (cellH <= 0) return null;
    final row = ((local.dy + scroll) / cellH).floor();
    return row >= 0 ? row : null;
  }

  Future<void> _confirmSelection() async {
    final paths = <String>[];
    for (final asset in _selected) {
      final file = await asset.originFile;
      if (file != null) paths.add(file.path);
    }
    if (mounted) Navigator.of(context).pop(paths);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        _scrollCtrl = scrollCtrl;
        final l = AppLocalizations.of(context);
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.mediaPickerGallery,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _selected.isEmpty
                          ? const SizedBox.shrink()
                          : FilledButton.icon(
                              key: const ValueKey('send-btn'),
                              onPressed: _confirmSelection,
                              icon: const Icon(Icons.send, size: 16),
                              label: Text(l.mediaPickerSend(_selected.length)),
                              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _denied
                        ? _PermissionDenied(onFilePicker: _openFilePicker, onOpenSettings: openAppSettings)
                        : Listener(
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerCancel,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.extentAfter < 400) _loadMore();
                                return false;
                              },
                              child: GridView.builder(
                                key: _gridKey,
                                controller: scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2,
                                ),
                                // +2 for Camera/File, +1 for loading spinner row
                                itemCount: _assets.length + 2 + (_loadingMore ? 1 : 0),
                                itemBuilder: (ctx, i) {
                                  if (i == 0) {
                                    return _SpecialCell(
                                      icon: Icons.camera_alt_outlined,
                                      label: l.mediaPickerCamera,
                                      onTap: _openCamera,
                                      color: cs.primaryContainer,
                                      iconColor: cs.onPrimaryContainer,
                                    );
                                  }
                                  if (i == 1) {
                                    return _SpecialCell(
                                      icon: Icons.insert_drive_file_outlined,
                                      label: l.mediaPickerFile,
                                      onTap: _openFilePicker,
                                      color: cs.secondaryContainer,
                                      iconColor: cs.onSecondaryContainer,
                                    );
                                  }
                                  final assetIdx = i - 2;
                                  if (assetIdx >= _assets.length) {
                                    // Loading more indicator spans all 3 cols visually
                                    return const Center(child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ));
                                  }
                                  final asset = _assets[assetIdx];
                                  final selIdx = _selected.indexOf(asset);
                                  return _AssetThumbnail(
                                    asset: asset,
                                    selectionIndex: selIdx >= 0 ? selIdx + 1 : null,
                                    onTap: () => _toggleSelect(asset),
                                    onLongPress: () => _startDragSelect(asset),
                                  );
                                },
                              ),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── special action cell (camera / file) ──────────────────────────────────────

class _SpecialCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  const _SpecialCell({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── single asset thumbnail ────────────────────────────────────────────────────

class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final int? selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AssetThumbnail({
    required this.asset,
    required this.selectionIndex,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithOption(
      const ThumbnailOption(
        size: ThumbnailSize(200, 200),
        quality: 80,
        format: ThumbnailFormat.jpeg,
      ),
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = widget.selectionIndex != null;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // thumbnail
          _thumb != null
              ? Image.memory(_thumb!, fit: BoxFit.cover)
              : Container(color: cs.surfaceContainerHighest),

          // video badge
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              left: 4,
              child: Row(
                children: [
                  const Icon(Icons.play_arrow, color: Colors.white, size: 13),
                  const SizedBox(width: 1),
                  Text(
                    _formatDuration(widget.asset.videoDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),

          // selection overlay
          if (isSelected)
            Container(color: cs.primary.withValues(alpha: 0.3)),

          // selection circle
          Positioned(
            top: 5,
            right: 5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? cs.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? cs.primary : Colors.white,
                  width: 2,
                ),
                boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Text(
                      '${widget.selectionIndex}',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── wallpaper single-pick sheet ──────────────────────────────────────────────

class _WallpaperPickerSheet extends StatefulWidget {
  const _WallpaperPickerSheet();

  @override
  State<_WallpaperPickerSheet> createState() => _WallpaperPickerSheetState();
}

class _WallpaperPickerSheetState extends State<_WallpaperPickerSheet> {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  bool _denied = false;

  AssetPathEntity? _album;
  int _totalCount = 0;
  bool _loadingMore = false;
  static const _pageSize = 80;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final permitted = await PhotoManager.requestPermissionExtend();
    if (!permitted.isAuth) {
      if (mounted) setState(() { _loading = false; _denied = true; });
      return;
    }
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _album = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
    _totalCount = await _album!.assetCountAsync;
    final assets = await _album!.getAssetListRange(start: 0, end: _pageSize.clamp(0, _totalCount));
    if (mounted) setState(() { _assets = assets; _loading = false; });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _album == null || _assets.length >= _totalCount) return;
    setState(() => _loadingMore = true);
    final start = _assets.length;
    final end = (start + _pageSize).clamp(0, _totalCount);
    final more = await _album!.getAssetListRange(start: start, end: end);
    if (mounted) setState(() { _assets.addAll(more); _loadingMore = false; });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result != null && mounted) {
      final path = result.files.single.path;
      if (path != null) Navigator.of(context).pop(path);
    }
  }

  Future<void> _pick(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file != null && mounted) Navigator.of(context).pop(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).mediaPickerChooseWallpaper,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_outlined, size: 18),
                      label: Text(AppLocalizations.of(context).mediaPickerFiles),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _denied
                        ? _PermissionDenied(
                            onFilePicker: _pickFile,
                            onOpenSettings: openAppSettings,
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.extentAfter < 400) _loadMore();
                              return false;
                            },
                            child: GridView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 2,
                                crossAxisSpacing: 2,
                              ),
                              itemCount: _assets.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                if (i >= _assets.length) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ));
                                }
                                final asset = _assets[i];
                                return _WallpaperThumbnail(
                                  asset: asset,
                                  onTap: () => _pick(asset),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WallpaperThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _WallpaperThumbnail({required this.asset, required this.onTap});

  @override
  State<_WallpaperThumbnail> createState() => _WallpaperThumbnailState();
}

class _WallpaperThumbnailState extends State<_WallpaperThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.asset.thumbnailDataWithOption(
      const ThumbnailOption(
        size: ThumbnailSize(200, 200),
        quality: 80,
        format: ThumbnailFormat.jpeg,
      ),
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumb != null
              ? Image.memory(_thumb!, fit: BoxFit.cover)
              : Container(color: cs.surfaceContainerHighest),
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4,
              left: 4,
              child: Row(
                children: [
                  const Icon(Icons.play_arrow, color: Colors.white, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    _fmt(widget.asset.videoDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── permission denied placeholder ────────────────────────────────────────────

class _PermissionDenied extends StatelessWidget {
  final VoidCallback onFilePicker;
  final Future<bool> Function() onOpenSettings;

  const _PermissionDenied({
    required this.onFilePicker,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 56),
          const SizedBox(height: 12),
          Text(
            l.mediaPickerDeniedTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            l.mediaPickerDeniedBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: onFilePicker,
                child: Text(l.mediaPickerPickFile),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => onOpenSettings(),
                child: Text(l.mediaPickerOpenSettings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
