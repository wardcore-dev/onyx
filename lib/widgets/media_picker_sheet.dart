// lib/widgets/media_picker_sheet.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
    final filterOption = FilterOptionGroup(
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: filterOption,
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final allAlbum = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
    final assets = await allAlbum.getAssetListRange(start: 0, end: 200);
    if (mounted) setState(() { _assets = assets; _loading = false; });
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null && mounted) {
      Navigator.of(context).pop([picked.path]);
    }
  }

  Future<void> _openFilePicker() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.any, allowMultiple: true);
    if (result != null && mounted) {
      Navigator.of(context).pop(
        result.files.map((f) => f.path).whereType<String>().toList(),
      );
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

  Future<void> _confirmSelection() async {
    final paths = <String>[];
    for (final asset in _selected) {
      final file = await asset.originFile;
      if (file != null) paths.add(file.path);
    }
    if (mounted) Navigator.of(context).pop(paths);
  }

  Future<void> _sendSingle(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file != null && mounted) Navigator.of(context).pop([file.path]);
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gallery',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _selected.isEmpty
                          ? const SizedBox.shrink()
                          : FilledButton.icon(
                              key: const ValueKey('send-btn'),
                              onPressed: _confirmSelection,
                              icon: const Icon(Icons.send, size: 16),
                              label: Text('Send ${_selected.length}'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
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
                            onFilePicker: _openFilePicker,
                            onOpenSettings: openAppSettings,
                          )
                        : GridView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                            itemCount: _assets.length + 2,
                            itemBuilder: (ctx, i) {
                              if (i == 0) {
                                return _SpecialCell(
                                  icon: Icons.camera_alt_outlined,
                                  label: 'Camera',
                                  onTap: _openCamera,
                                  color: cs.primaryContainer,
                                  iconColor: cs.onPrimaryContainer,
                                );
                              }
                              if (i == 1) {
                                return _SpecialCell(
                                  icon: Icons.insert_drive_file_outlined,
                                  label: 'File',
                                  onTap: _openFilePicker,
                                  color: cs.secondaryContainer,
                                  iconColor: cs.onSecondaryContainer,
                                );
                              }
                              final asset = _assets[i - 2];
                              final selIdx = _selected.indexOf(asset);
                              return _AssetThumbnail(
                                asset: asset,
                                selectionIndex: selIdx >= 0 ? selIdx + 1 : null,
                                onTap: () => _toggleSelect(asset),
                                onLongPress: () => _sendSingle(asset),
                              );
                            },
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 56),
          const SizedBox(height: 12),
          const Text(
            'Gallery access denied',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'Allow access in settings or pick a file directly.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: onFilePicker,
                child: const Text('Pick File'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => onOpenSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
