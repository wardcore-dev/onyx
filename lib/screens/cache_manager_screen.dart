// lib/screens/cache_manager_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../utils/media_cache.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class _MediaEntry {
  final String filename;
  final int size;
  final DateTime? lastModified;
  const _MediaEntry({required this.filename, required this.size, this.lastModified});
  factory _MediaEntry.fromJson(Map<String, dynamic> j) => _MediaEntry(
        filename: j['filename'] as String,
        size: (j['size'] as num?)?.toInt() ?? 0,
        lastModified: j['last_modified'] != null
            ? DateTime.tryParse(j['last_modified'] as String)
            : null,
      );
}

class _LocalFile {
  final String filename; // without .enc suffix
  final int sizeBytes;
  const _LocalFile(this.filename, this.sizeBytes);
}

class _LocalType {
  final String dirName;
  final IconData icon;
  final String label;
  final bool isImage;
  const _LocalType(this.dirName, this.icon, this.label, {this.isImage = false});
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
  _LocalType('image_cache',    Icons.image_outlined,             'Images',    isImage: true),
  _LocalType('voice_cache',    Icons.mic_outlined,               'Voice'),
  _LocalType('audio_cache',    Icons.music_note_outlined,        'Audio'),
  _LocalType('video_cache',    Icons.videocam_outlined,          'Video'),
  _LocalType('file_cache',     Icons.insert_drive_file_outlined, 'Files'),
  _LocalType('document_cache', Icons.description_outlined,       'Documents'),
  _LocalType('archive_cache',  Icons.folder_zip_outlined,        'Archives'),
  _LocalType('data_cache',     Icons.storage_outlined,           'Data'),
];

const _serverTypes = ['image', 'voice', 'video', 'file', 'avatar'];

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

Future<void> showCacheManagerSheet(BuildContext context, {String? token}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CacheManagerSheet(token: token),
  );
}

// ─── Sheet widget ──────────────────────────────────────────────────────────────

class _CacheManagerSheet extends StatefulWidget {
  final String? token;
  const _CacheManagerSheet({this.token});

  @override
  State<_CacheManagerSheet> createState() => _CacheManagerSheetState();
}

class _CacheManagerSheetState extends State<_CacheManagerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  // Server state
  bool _serverLoading = false;
  String? _serverError;
  Map<String, List<_MediaEntry>> _serverFiles = {};
  int? _quotaUsedBytes;
  int? _quotaLimitBytes;

  // Server expand/select
  String? _expandedServerType;
  final Set<String> _selectedServer = {};
  bool _deletingServerSelected = false;

  // Avatar preview
  Uint8List? _cachedAvatarBytes;

  // Deferred loading — starts only after the sheet opening animation completes
  bool _loadingStarted = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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
    if (widget.token != null) _loadServer();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    _tabController.dispose();
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
      final dir = await getApplicationSupportDirectory();
      _localBasePath = dir.path;
      final info = await compute(_scanLocalCacheDirs, dir.path);
      if (mounted) setState(() { _localInfo = info; _localLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  Future<void> _clearLocalType(_LocalTypeInfo info) async {
    final dirName = info.type.dirName;
    setState(() => _clearingLocal.add(dirName));
    try {
      final dir = await getApplicationSupportDirectory();
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
    final dir = await getApplicationSupportDirectory();
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
        final encFile = File('$basePath/$dirName/$filename.enc');
        if (await encFile.exists()) await encFile.delete();
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

  // ── Server loading ───────────────────────────────────────────────────────────

  Future<void> _loadServer() async {
    if (widget.token == null) return;
    setState(() { _serverLoading = true; _serverError = null; });
    try {
      final results = await Future.wait([
        http.get(
          Uri.parse('$serverBase/me/media-list'),
          headers: {'authorization': 'Bearer ${widget.token}'},
        ),
        http.get(
          Uri.parse('$serverBase/me/storage-quota'),
          headers: {'authorization': 'Bearer ${widget.token}'},
        ),
      ]);
      if (!mounted) return;

      final mediaRes = results[0];
      final quotaRes = results[1];

      if (mediaRes.statusCode == 200) {
        final data = jsonDecode(mediaRes.body) as Map<String, dynamic>;
        final map = <String, List<_MediaEntry>>{};
        for (final type in _serverTypes) {
          final raw = (data[type] as List?) ?? [];
          map[type] = raw
              .map((e) => _MediaEntry.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => (b.lastModified ?? DateTime(0))
                .compareTo(a.lastModified ?? DateTime(0)));
        }
        int? usedBytes;
        int? limitBytes;
        if (quotaRes.statusCode == 200) {
          final q = jsonDecode(quotaRes.body) as Map<String, dynamic>;
          usedBytes = (q['used_bytes'] as num?)?.toInt();
          limitBytes = (q['quota_bytes'] as num?)?.toInt();
        }
        setState(() {
          _serverFiles = map;
          _quotaUsedBytes = usedBytes;
          _quotaLimitBytes = limitBytes;
          _serverLoading = false;
        });
      } else {
        final detail =
            (jsonDecode(mediaRes.body) as Map?)?['detail'] ?? 'Error ${mediaRes.statusCode}';
        setState(() { _serverError = detail.toString(); _serverLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _serverError = e.toString(); _serverLoading = false; });
    }
  }

  Future<void> _clearServerType(String type, String typeName) async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.cacheClearTabTitle, l.cacheClearTabContent(typeName));
    if (!ok || !mounted) return;
    final entries = List<_MediaEntry>.from(_serverFiles[type] ?? []);
    int deleted = 0;
    for (final entry in entries) {
      try {
        final res = type == 'avatar'
            ? await http.delete(Uri.parse('$serverBase/media/avatar/me'),
                headers: {'authorization': 'Bearer ${widget.token}'})
            : await http.delete(Uri.parse('$serverBase/media/single'),
                headers: {
                  'authorization': 'Bearer ${widget.token}',
                  'content-type': 'application/json',
                },
                body: jsonEncode({'filename': entry.filename, 'type': type}));
        if (res.statusCode == 200) {
          deleted++;
          if (mounted) setState(() => _serverFiles[type]?.remove(entry));
        }
      } catch (_) {}
    }
    if (mounted) _showSnack(AppLocalizations.of(context).cacheFilesDeleted(deleted));
  }

  void _toggleExpandServer(String type) {
    setState(() {
      if (_expandedServerType == type) {
        _selectedServer.removeWhere((k) => k.startsWith('${type}__'));
        _expandedServerType = null;
      } else {
        if (_expandedServerType != null) {
          _selectedServer.removeWhere((k) => k.startsWith('${_expandedServerType}__'));
        }
        _expandedServerType = type;
      }
    });
    if (type == 'avatar' && _cachedAvatarBytes == null) {
      _loadAvatarBytes();
    }
  }

  void _toggleSelectServer(String key) {
    setState(() {
      if (_selectedServer.contains(key)) {
        _selectedServer.remove(key);
      } else {
        _selectedServer.add(key);
      }
    });
  }

  Future<void> _deleteSelectedServer() async {
    if (_selectedServer.isEmpty) return;
    setState(() => _deletingServerSelected = true);
    final toDelete = Set<String>.from(_selectedServer);
    setState(() => _selectedServer.clear());
    int deleted = 0;
    for (final key in toDelete) {
      final idx = key.indexOf('__');
      if (idx < 0) continue;
      final type = key.substring(0, idx);
      final filename = key.substring(idx + 2);
      try {
        final res = type == 'avatar'
            ? await http.delete(
                Uri.parse('$serverBase/media/avatar/me'),
                headers: {'authorization': 'Bearer ${widget.token}'},
              )
            : await http.delete(
                Uri.parse('$serverBase/media/single'),
                headers: {
                  'authorization': 'Bearer ${widget.token}',
                  'content-type': 'application/json',
                },
                body: jsonEncode({'filename': filename, 'type': type}),
              );
        if (res.statusCode == 200) {
          deleted++;
          if (mounted) {
            setState(() => _serverFiles[type]?.removeWhere((e) => e.filename == filename));
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _deletingServerSelected = false);
      _showSnack(AppLocalizations.of(context).cacheFilesDeleted(deleted));
    }
  }

  Future<void> _loadAvatarBytes() async {
    if (_cachedAvatarBytes != null || widget.token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$serverBase/media/avatar/me'),
        headers: {'authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && mounted) {
        setState(() => _cachedAvatarBytes = res.bodyBytes);
      }
    } catch (_) {}
  }

  Future<void> _clearAllServer() async {
    final l = AppLocalizations.of(context);
    final ok = await _confirm(l.clearServerCacheTitle, l.clearServerCacheContent);
    if (!ok || !mounted) return;
    try {
      final res = await http.post(
        Uri.parse('$serverBase/me/cleanup'),
        headers: {'authorization': 'Bearer ${widget.token}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          for (final t in _serverTypes) {
            _serverFiles[t] = [];
          }
        });
        _showSnack(l.serverMediaCleared);
      }
    } catch (_) {}
  }

  // ── Shared helpers ───────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String content) async {
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l.cancel)),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l.clearAll),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final bg = SettingsManager.getElementColor(
      cs.surfaceContainerHighest,
      SettingsManager.elementBrightness.value,
    ).withValues(alpha: SettingsManager.elementOpacity.value);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          textAlign: TextAlign.center),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  String _serverTypeLabel(String type, AppLocalizations l) {
    switch (type) {
      case 'image':  return l.cacheTabImages;
      case 'voice':  return l.cacheTabVoice;
      case 'video':  return l.cacheTabVideo;
      case 'file':   return l.cacheTabFiles;
      case 'avatar': return l.cacheTabAvatars;
      default:       return type;
    }
  }

  IconData _serverTypeIcon(String type) {
    switch (type) {
      case 'image':  return Icons.image_outlined;
      case 'voice':  return Icons.mic_outlined;
      case 'video':  return Icons.videocam_outlined;
      case 'file':   return Icons.insert_drive_file_outlined;
      case 'avatar': return Icons.account_circle_outlined;
      default:       return Icons.attach_file;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.87,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.manageCacheTitle,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    (Platform.isAndroid || Platform.isIOS)
                        ? Icons.phone_android
                        : Icons.computer,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(l.localCacheTab),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(l.serverCacheTab),
                ]),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLocalTab(l, cs),
                _buildServerTab(l, cs),
              ],
            ),
          ),
        ],
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
        const Divider(height: 1),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        ListTile(
          leading: Icon(info.type.icon, size: 22,
              color: isEmpty ? cs.onSurfaceVariant.withValues(alpha: 0.35) : null),
          title: Text(info.type.label,
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

        const Divider(height: 1, indent: 16),
      ],
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

  // ── Quota bar ────────────────────────────────────────────────────────────────

  Widget _buildQuotaBar(ColorScheme cs) {
    final used = _quotaUsedBytes ?? 0;
    final limit = _quotaLimitBytes ?? 1;
    final fraction = (used / limit).clamp(0.0, 1.0);
    final pct = (fraction * 100).toStringAsFixed(1);
    final Color barColor = fraction >= 0.9
        ? Colors.red
        : fraction >= 0.7
            ? Colors.orange
            : cs.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, size: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                '${_fmtSize(used)} / ${_fmtSize(limit)}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85)),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Server tab ───────────────────────────────────────────────────────────────

  Widget _buildServerTab(AppLocalizations l, ColorScheme cs) {
    if (widget.token == null) {
      return Center(
          child: Text(l.notLoggedIn,
              style: const TextStyle(color: Colors.grey)));
    }
    if (_serverLoading) return const Center(child: CircularProgressIndicator());
    if (_serverError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline,
              size: 40, color: Colors.red.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(_serverError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: _loadServer, child: const Text('Retry')),
        ]),
      );
    }

    final totalFiles =
        _serverFiles.values.fold<int>(0, (s, l) => s + l.length);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$totalFiles ${totalFiles == 1 ? 'file' : 'files'} on server',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
                onPressed: _loadServer,
              ),
              if (totalFiles > 0)
                TextButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: Text(l.clearAll),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      visualDensity: VisualDensity.compact),
                  onPressed: _clearAllServer,
                ),
            ],
          ),
        ),
        if (_quotaLimitBytes != null) _buildQuotaBar(cs),
        const Divider(height: 1),
        Expanded(
          child: totalFiles == 0
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_done_outlined,
                        size: 40,
                        color: Colors.green.withValues(alpha: 0.7)),
                    const SizedBox(height: 10),
                    Text(l.cacheNoFiles,
                        style: const TextStyle(color: Colors.grey)),
                  ]),
                )
              : ListView(
                  children: _serverTypes
                      .map((t) => _buildServerGroup(t, l, cs))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildServerGroup(String type, AppLocalizations l, ColorScheme cs) {
    final entries = _serverFiles[type] ?? [];
    final totalBytes = entries.fold<int>(0, (s, e) => s + e.size);
    final label = _serverTypeLabel(type, l);
    final isExpanded = _expandedServerType == type;
    final isEmpty = entries.isEmpty;
    final selectedInType =
        _selectedServer.where((k) => k.startsWith('${type}__')).length;
    final allSelected =
        !isEmpty && isExpanded && selectedInType == entries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(_serverTypeIcon(type), size: 22,
              color: isEmpty ? cs.onSurfaceVariant.withValues(alpha: 0.35) : null),
          title: Text(label,
              style: TextStyle(
                  color: isEmpty
                      ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                      : null)),
          subtitle: Text(
            isEmpty
                ? l.cacheNoFiles
                : '${entries.length} ${entries.length == 1 ? 'file' : 'files'} · ${_fmtSize(totalBytes)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: isEmpty ? null : () => _toggleExpandServer(type),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!isEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                color: Colors.red.withValues(alpha: 0.7),
                tooltip: l.cacheClearTab,
                visualDensity: VisualDensity.compact,
                onPressed: () => _clearServerType(type, label),
              ),
            if (!isEmpty)
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                child: Icon(Icons.expand_more,
                    size: 20, color: cs.onSurfaceVariant),
              ),
          ]),
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
                        child: Row(children: [
                          TextButton(
                            style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () => setState(() {
                              if (allSelected) {
                                _selectedServer.removeWhere(
                                    (k) => k.startsWith('${type}__'));
                              } else {
                                _selectedServer.removeWhere(
                                    (k) => k.startsWith('${type}__'));
                                _selectedServer.addAll(entries
                                    .map((e) => '${type}__${e.filename}'));
                              }
                            }),
                            child: Text(
                                allSelected
                                    ? l.cacheDeselectAll
                                    : l.cacheSelectAll,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          const Spacer(),
                          if (selectedInType > 0) ...[
                            Text('$selectedInType ${l.cacheSelected}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            _deletingServerSelected
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
                                    onPressed: _deleteSelectedServer,
                                    child: Text(
                                        '${l.delete} ($selectedInType)',
                                        style:
                                            const TextStyle(fontSize: 12)),
                                  ),
                          ],
                        ]),
                      ),
                      ...entries.map((e) => _buildServerFileTile(type, e, cs)),
                    ],
                  )
                : const SizedBox(),
          ),
        ),

        const Divider(height: 1, indent: 16),
      ],
    );
  }

  Widget _buildServerFileTile(String type, _MediaEntry entry, ColorScheme cs) {
    final key = '${type}__${entry.filename}';
    final isSelected = _selectedServer.contains(key);
    final label = _labelForFilename(entry.filename);

    Widget? leadingWidget;
    if (type == 'avatar' && _cachedAvatarBytes != null) {
      leadingWidget = SizedBox(
        width: 36,
        height: 36,
        child: ClipOval(
          child: Image.memory(_cachedAvatarBytes!,
              fit: BoxFit.cover, gaplessPlayback: true),
        ),
      );
    } else if (type == 'image' &&
        _localBasePath != null &&
        File('$_localBasePath/image_cache/${entry.filename}.enc').existsSync()) {
      leadingWidget = SizedBox(
        width: 36,
        height: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: FutureBuilder<Uint8List?>(
            future: _loadThumbnail(entry.filename),
            builder: (_, snap) => snap.data != null
                ? Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true)
                : Icon(_serverTypeIcon(type), size: 20),
          ),
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: leadingWidget,
      title: Text(label,
          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _fmtSize(entry.size) +
            (entry.lastModified != null
                ? '  ·  ${_fmtDate(entry.lastModified!)}'
                : ''),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      onTap: () => _toggleSelectServer(key),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: cs.primary, size: 20)
          : Icon(Icons.radio_button_unchecked,
              size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
    );
  }
}
