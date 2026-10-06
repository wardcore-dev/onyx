// lib/screens/cache_manager_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;
import '../l10n/app_localizations.dart';
import '../utils/media_cache.dart';
import '../widgets/onyx_dialog.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class _LocalFile {
  final String filename; // without .enc suffix
  final int sizeBytes;
  const _LocalFile(this.filename, this.sizeBytes);
}

class _LocalType {
  final String dirName;
  final IconData icon;
  final bool isImage;
  const _LocalType(this.dirName, this.icon, {this.isImage = false});
}

class _LocalTypeInfo {
  final _LocalType type;
  int fileCount;
  int totalBytes;
  List<_LocalFile> files;
  _LocalTypeInfo(this.type)
      : fileCount = 0,
        totalBytes = 0,
        files = [];
}

// ─── Constants ────────────────────────────────────────────────────────────────

const _localTypes = [
  _LocalType('image_cache',    Icons.image_outlined,             isImage: true),
  _LocalType('voice_cache',    Icons.mic_outlined),
  _LocalType('audio_cache',    Icons.music_note_outlined),
  _LocalType('video_cache',    Icons.videocam_outlined),
  _LocalType('file_cache',     Icons.insert_drive_file_outlined),
  _LocalType('document_cache', Icons.description_outlined),
  _LocalType('archive_cache',  Icons.folder_zip_outlined),
  _LocalType('data_cache',     Icons.storage_outlined),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

// Tries to render a filename as a human-readable label.
// If the name (without extension) is a Unix ms timestamp, returns "DD.MM.YYYY HH:MM".
String _labelForFilename(String filename) {
  final noExt = filename.contains('.')
      ? filename.substring(0, filename.lastIndexOf('.'))
      : filename;
  final ts = int.tryParse(noExt);
  if (ts != null && ts > 1000000000000) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${_fmtDate(dt)}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return filename;
}

// Top-level function for compute()
List<_LocalTypeInfo> _scanLocalCacheDirs(String basePath) {
  final result = <_LocalTypeInfo>[];
  for (final type in _localTypes) {
    final info = _LocalTypeInfo(type);
    final dir = Directory('$basePath/${type.dirName}');
    if (dir.existsSync()) {
      for (final entity in dir.listSync(recursive: false, followLinks: false)) {
        if (entity is File) {
          final sizeBytes = entity.lengthSync();
          info.fileCount++;
          info.totalBytes += sizeBytes;
          final name = p.basename(entity.path);
          final noEnc = name.endsWith('.enc')
              ? name.substring(0, name.length - 4)
              : name;
          info.files.add(_LocalFile(noEnc, sizeBytes));
        }
      }
      // Sort newest first (timestamp-based filenames)
      info.files.sort((a, b) => b.filename.compareTo(a.filename));
    }
    result.add(info);
  }
  return result;
}

// ─── Public entry point ────────────────────────────────────────────────────────

Future<void> showCacheManagerSheet(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Manage Cache',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (_, __, ___) => const _CacheManagerSheet(),
  );
}

// ─── Sheet widget ──────────────────────────────────────────────────────────────

class _CacheManagerSheet extends StatefulWidget {
  const _CacheManagerSheet();

  @override
  State<_CacheManagerSheet> createState() => _CacheManagerSheetState();
}

class _CacheManagerSheetState extends State<_CacheManagerSheet> {
  // Local state
  bool _localLoading = true;
  List<_LocalTypeInfo> _localInfo = [];
  String? _localBasePath;
  final Set<String> _clearingLocal = {};

  // Expand / select (shared across all local types)
  String? _expandedLocalDir;
  final Set<String> _selectedLocal = {};
  bool _deletingLocalSelected = false;

  // Image thumbnail cache (only for image_cache type)
  final Map<String, Uint8List?> _thumbnailCache = {};

  // Deferred loading — starts only after the sheet opening animation completes
  bool _loadingStarted = false;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadingStarted) {
      _routeAnimation = ModalRoute.of(context)?.animation;
      if (_routeAnimation == null ||
          _routeAnimation!.status == AnimationStatus.completed) {
        _startLoading();
      } else {
        _routeAnimation!.addStatusListener(_onRouteAnimation);
      }
    }
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_onRouteAnimation);
      _startLoading();
    }
  }

  void _startLoading() {
    if (_loadingStarted || !mounted) return;
    _loadingStarted = true;
    _loadLocal();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    super.dispose();
  }

  // ── Local loading ────────────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    setState(() {
      _localLoading = true;
      _thumbnailCache.clear();
      _selectedLocal.clear();
    });
    try {
      final dir = await getOnyxSupportDirectory();
      _localBasePath = dir.path;
      final info = await compute(_scanLocalCacheDirs, dir.path);
      if (mounted) setState(() { _localInfo = info; _localLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  Future<void> _clearLocalType(_LocalTypeInfo info) async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(
      l.cacheClearTabTitle,
      l.cacheClearTabContent(_localTypeLabel(info.type.dirName, l)),
    );
    if (!ok || !mounted) return;
    final dirName = info.type.dirName;
    setState(() => _clearingLocal.add(dirName));
    try {
      final dir = await getOnyxSupportDirectory();
      final typeDir = Directory('${dir.path}/$dirName');
      if (await typeDir.exists()) {
        await typeDir.delete(recursive: true);
        await typeDir.create();
      }
      if (info.type.isImage) {
        try { await MediaCache.instance.clearDisplayCache(); } catch (_) {}
        _thumbnailCache.clear();
      }
      if (_expandedLocalDir == dirName) {
        _selectedLocal.clear();
        _expandedLocalDir = null;
      }
      if (mounted) await _loadLocal();
    } finally {
      if (mounted) setState(() => _clearingLocal.remove(dirName));
    }
  }

  Future<void> _clearAllLocal() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.clearLocalCacheDialogTitle, l.clearLocalCacheDialogContent);
    if (!ok || !mounted) return;
    final dir = await getOnyxSupportDirectory();
    for (final type in _localTypes) {
      try {
        final d = Directory('${dir.path}/${type.dirName}');
        if (await d.exists()) await d.delete(recursive: true);
        await d.create();
      } catch (_) {}
    }
    try { await MediaCache.instance.clearDisplayCache(); } catch (_) {}
    _thumbnailCache.clear();
    _selectedLocal.clear();
    _expandedLocalDir = null;
    if (mounted) _loadLocal();
  }

  // ── Expand / select / delete (local) ─────────────────────────────────────────

  void _toggleExpand(String dirName) {
    setState(() {
      if (_expandedLocalDir == dirName) {
        _expandedLocalDir = null;
      } else {
        _expandedLocalDir = dirName;
        _selectedLocal.clear();
      }
    });
  }

  void _toggleSelect(String filename) {
    setState(() {
      if (_selectedLocal.contains(filename)) {
        _selectedLocal.remove(filename);
      } else {
        _selectedLocal.add(filename);
      }
    });
  }

  Future<void> _deleteSelectedLocal() async {
    final basePath = _localBasePath;
    final dirName = _expandedLocalDir;
    if (basePath == null || dirName == null || _selectedLocal.isEmpty) return;

    setState(() => _deletingLocalSelected = true);
    final toDelete = Set<String>.from(_selectedLocal);
    setState(() => _selectedLocal.clear());

    final isImage = dirName == 'image_cache';

    for (final filename in toDelete) {
      try {
        // Delete both plain and encrypted variants (WardLink saves plain files).
        for (final name in [filename, '$filename.enc']) {
          final f = File('$basePath/$dirName/$name');
          if (await f.exists()) await f.delete();
        }
        if (isImage) {
          _thumbnailCache.remove(filename);
          final displayDir = await MediaCache.instance.displayDirFor('image');
          final displayFile = File('${displayDir.path}/$filename');
          if (await displayFile.exists()) await displayFile.delete();
        }
      } catch (_) {}
    }

    setState(() => _deletingLocalSelected = false);
    if (mounted) await _loadLocal();
  }

  // ── Thumbnails (image_cache only) ────────────────────────────────────────────

  Future<Uint8List?> _loadThumbnail(String filename) async {
    if (_thumbnailCache.containsKey(filename)) return _thumbnailCache[filename];
    final basePath = _localBasePath;
    if (basePath == null) return null;
    try {
      await MediaCache.instance.init();
      final encFile = File('$basePath/image_cache/$filename.enc');
      if (!await encFile.exists()) {
        _thumbnailCache[filename] = null;
        return null;
      }
      final encBytes = await encFile.readAsBytes();
      final plainBytes = await MediaCache.instance.decrypt(encBytes);
      _thumbnailCache[filename] = plainBytes;
      return plainBytes;
    } catch (_) {
      _thumbnailCache[filename] = null;
      return null;
    }
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String content) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: title,
      message: content,
      confirmLabel: l.clearAll,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    return confirmed ?? false;
  }

  String _localTypeLabel(String dirName, AppLocalizations l) {
    switch (dirName) {
      case 'image_cache': return l.cacheTabImages;
      case 'voice_cache': return l.cacheTabVoice;
      case 'audio_cache': return l.cacheTabAudio;
      case 'video_cache': return l.cacheTabVideo;
      case 'file_cache': return l.cacheTabFiles;
      case 'document_cache': return l.cacheTabDocuments;
      case 'archive_cache': return l.cacheTabArchives;
      case 'data_cache': return l.cacheTabData;
      default: return dirName;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                          color: cs.primary.withValues(alpha: 0.10), width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.storage_rounded,
                            size: 18, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l.manageCacheTitle,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close_rounded,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: _buildLocalTab(l, cs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Local tab ────────────────────────────────────────────────────────────────

  Widget _buildLocalTab(AppLocalizations l, ColorScheme cs) {
    if (_localLoading) return const Center(child: CircularProgressIndicator());

    final total = _localInfo.fold<int>(0, (s, i) => s + i.totalBytes);
    final hasAny = _localInfo.any((i) => i.fileCount > 0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${l.mediaCacheSize}${_fmtSize(total)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
              if (hasAny)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(l.clearAll),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact),
                  onPressed: _clearAllLocal,
                ),
            ],
          ),
        ),
        Expanded(
          child: !hasAny
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline,
                        size: 40, color: Colors.green.withValues(alpha: 0.7)),
                    const SizedBox(height: 10),
                    Text(l.cacheNoFiles,
                        style: const TextStyle(color: Colors.grey)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _localInfo.length,
                  itemBuilder: (_, i) =>
                      _buildExpandableTile(_localInfo[i], l, cs),
                ),
        ),
      ],
    );
  }

  Widget _buildExpandableTile(
      _LocalTypeInfo info, AppLocalizations l, ColorScheme cs) {
    final dirName = info.type.dirName;
    final isEmpty = info.fileCount == 0;
    final isExpanded = _expandedLocalDir == dirName;
    final isClearing = _clearingLocal.contains(dirName);
    final allSelected = !isEmpty &&
        isExpanded &&
        _selectedLocal.length == info.files.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: isEmpty ? 0.18 : 0.35),
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        ListTile(
          leading: Icon(info.type.icon, size: 22,
              color: isEmpty ? cs.onSurfaceVariant.withValues(alpha: 0.35) : null),
          title: Text(_localTypeLabel(info.type.dirName, l),
              style: TextStyle(
                  color: isEmpty
                      ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                      : null)),
          subtitle: Text(
            isEmpty
                ? l.cacheNoFiles
                : '${info.fileCount} ${info.fileCount == 1 ? 'file' : 'files'} · ${_fmtSize(info.totalBytes)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: isEmpty ? null : () => _toggleExpand(dirName),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEmpty)
                isClearing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red.withValues(alpha: 0.8),
                        tooltip: l.cacheClearTab,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _clearLocalType(info),
                      ),
              if (!isEmpty)
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOut,
                  child: Icon(Icons.expand_more,
                      size: 20, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),

        // ── Expandable content (lazy + animated) ──
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: (isExpanded && !isEmpty)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        color: cs.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        child: Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              onPressed: () => setState(() {
                                if (allSelected) {
                                  _selectedLocal.clear();
                                } else {
                                  _selectedLocal
                                    ..clear()
                                    ..addAll(
                                        info.files.map((f) => f.filename));
                                }
                              }),
                              child: Text(
                                allSelected
                                    ? l.cacheDeselectAll
                                    : l.cacheSelectAll,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const Spacer(),
                            if (_selectedLocal.isNotEmpty) ...[
                              Text(
                                '${_selectedLocal.length} ${l.cacheSelected}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              _deletingLocalSelected
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red
                                            .withValues(alpha: 0.12),
                                        foregroundColor: Colors.red,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: _deleteSelectedLocal,
                                      child: Text(
                                        '${l.delete} (${_selectedLocal.length})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                            ],
                          ],
                        ),
                      ),
                      info.type.isImage
                          ? _buildImageGrid(info.files, cs)
                          : _buildFileList(info.files, info.type.icon, cs),
                    ],
                  )
                : const SizedBox(),
          ),
        ),
      ],
        ),
      ),
    );
  }

  // ── Image grid ───────────────────────────────────────────────────────────────

  Widget _buildImageGrid(List<_LocalFile> files, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: files.length,
        itemBuilder: (_, i) => _buildThumbnailCell(files[i], cs),
      ),
    );
  }

  Widget _buildThumbnailCell(_LocalFile file, ColorScheme cs) {
    final isSelected = _selectedLocal.contains(file.filename);

    return GestureDetector(
      onTap: () => _toggleSelect(file.filename),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _loadThumbnail(file.filename),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Container(
                  color: cs.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
                );
              }
              if (snap.data == null) {
                return Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined,
                      size: 24,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                );
              }
              return Image.memory(snap.data!,
                  fit: BoxFit.cover, gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_outlined,
                            size: 24,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      ));
            },
          ),
          if (isSelected) Container(color: cs.primary.withValues(alpha: 0.42)),
          Positioned(
            top: 4, right: 4,
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? cs.primary : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── File list (all non-image types) ──────────────────────────────────────────

  Widget _buildFileList(List<_LocalFile> files, IconData typeIcon, ColorScheme cs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 56, endIndent: 16),
      itemBuilder: (_, i) {
        final file = files[i];
        final isSelected = _selectedLocal.contains(file.filename);

        return ListTile(
          onTap: () => _toggleSelect(file.filename),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.14)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: cs.primary, width: 1.5)
                  : null,
            ),
            child: Icon(typeIcon,
                size: 18,
                color: isSelected ? cs.primary : cs.onSurfaceVariant),
          ),
          title: Text(
            _labelForFilename(file.filename),
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _fmtSize(file.sizeBytes),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: cs.primary, size: 20)
              : Icon(Icons.radio_button_unchecked,
                  size: 20,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
        );
      },
    );
  }

}
