// lib/widgets/avatar_widget.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';

import 'package:ONYX/widgets/avatar_crop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart' show unawaited;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:math' show min, max;
import 'package:image/image.dart' as img;

import '../globals.dart';
import '../managers/settings_manager.dart';
import '../managers/account_manager.dart';
import '../utils/lazy_image_cache.dart';

final Map<String, String> _globalAvatarPathCache = {};

final Map<String, Uint8List> _globalAvatarBytesCache = {};

class AvatarWidget extends StatefulWidget {
  final String username;
  final Future<String?> Function() tokenProvider;
  final String avatarBaseUrl;
  final double size;
  final bool editable;
  final void Function(String url)? onUploaded;
  final VoidCallback? onDeleted;

  const AvatarWidget({
    Key? key,
    required this.username,
    required this.tokenProvider,
    this.avatarBaseUrl = 'https://api-onyx.wardcore.com',
    this.size = 48.0,
    this.editable = false,
    this.onUploaded,
    this.onDeleted,
  }) : super(key: key);

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> with RouteAware {
  String? _cachedFilePath;
  String? _previousCachedFilePath;
  bool _loading = false;
  bool _uploading = false;
  bool _deleting = false;
  bool? _hasRemoteAvatar;

  bool _avatarExplicitlyDeleted = false; 

  bool _canEdit = false;

  bool _suppressAnimation = false;

  String get _avatarRawUrl {
    return '${widget.avatarBaseUrl.replaceAll(RegExp(r'/$'), '')}/avatar/${Uri.encodeComponent(widget.username)}/raw?v=${avatarVersion.value}';
  }

  @override
  void initState() {
    super.initState();
    _avatarExplicitlyDeleted = false; 
    
    _updateCanEdit();
  }

  @override
  void dispose() {
    
    try { routeObserver.unsubscribe(this); } catch (e) {}
    try { avatarVersion.removeListener(_onAvatarVersionChanged); } catch (e) {}
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username ||
        oldWidget.avatarBaseUrl != widget.avatarBaseUrl) {
      setState(() {
        _cachedFilePath = null;
        _previousCachedFilePath = null;
        _hasRemoteAvatar = null;
        _avatarExplicitlyDeleted = false; 
      });
      _tryLoadFromCacheOrFetch();
      _updateCanEdit();
    }
  }

  Future<File> _newCacheFile(Uint8List bytes) async {
    
    final appSupport = await getApplicationSupportDirectory();
    final avatarDir = Directory('${appSupport.path}/avatars');
    await avatarDir.create(recursive: true);
    final contentHash = md5.convert(bytes).toString();
    return File('${avatarDir.path}/avatar_${widget.username}_$contentHash');
  }

  Future<String?> _findExistingCacheFile() async {
    try {
      
      final cached = _globalAvatarPathCache[widget.username];
      if (cached != null) {
        final f = File(cached);
        if (await f.exists()) return cached;
        _globalAvatarPathCache.remove(widget.username);
      }

      final appSupport = await getApplicationSupportDirectory();
      final avatarDir = Directory('${appSupport.path}/avatars');
      final prefix = 'avatar_${widget.username}_';

      if (await avatarDir.exists()) {
        String? chosen;
        DateTime? latest;
        for (final f in avatarDir.listSync()) {
          if (f is File && f.path.contains(prefix)) {
            try {
              final stat = await f.stat();
              if (latest == null || stat.modified.isAfter(latest)) {
                latest = stat.modified;
                chosen = f.path;
              }
            } catch (e) {}
          }
        }
        if (chosen != null) {
          _globalAvatarPathCache[widget.username] = chosen;
          return chosen;
        }
      }

      final dir = await getTemporaryDirectory();
      final list = Directory(dir.path).listSync();
      String? chosenTemp;
      DateTime? latestTemp;
      for (final f in list) {
        if (f is File && f.path.contains(prefix)) {
          try {
            final stat = await f.stat();
            if (latestTemp == null || stat.modified.isAfter(latestTemp)) {
              latestTemp = stat.modified;
              chosenTemp = f.path;
            }
          } catch (e) {}
        }
      }
      if (chosenTemp != null) _globalAvatarPathCache[widget.username] = chosenTemp;
      return chosenTemp;
    } catch (e) {
      return null;
    }
  }

  Future<void> _onRouteEnter() async {
    if (!mounted) return;
    
    avatarVersion.addListener(_onAvatarVersionChanged);
    try {
      
      if (!_loading && _cachedFilePath == null) {
        await _tryLoadFromCacheOrFetch();
      }
    } finally {
      _updateCanEdit();
    }
  }

  void _onRouteExit() {
    
    try {
      avatarVersion.removeListener(_onAvatarVersionChanged);
    } catch (e) {}
  }

  void _onAvatarVersionChanged() {
    if (!mounted) return;
    
    unawaited(_tryLoadFromCacheOrFetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      try {
        routeObserver.subscribe(this, route);
      } catch (e) {}
    }
  }

  @override
  void didPush() {
    
    _onRouteEnter();
  }

  @override
  void didPopNext() {
    
    _onRouteEnter();
  }

  @override
  void didPushNext() {
    
    _onRouteExit();
  }

  @override
  void didPop() {
    
    _onRouteExit();
  }

  Future<void> _updateCanEdit() async {
    try {
      final cur = await AccountManager.getCurrentAccount();
      if (!mounted) return;
      setState(() {
        _canEdit = (cur == widget.username);
      });
    } catch (e) {
      
    }
  }

  Future<void> _tryLoadFromCacheOrFetch() async {
    if (!mounted) return;

    if (_avatarExplicitlyDeleted) {
      if (mounted) {
        setState(() {
          _cachedFilePath = null;
          _hasRemoteAvatar = false;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      if (_cachedFilePath == null) {
        final existing = await _findExistingCacheFile();
        if (existing != null) {
          if (mounted) setState(() => _cachedFilePath = existing);
          
          if (!_globalAvatarBytesCache.containsKey(widget.username)) {
            try {
              final bytes = await File(existing).readAsBytes();
              _globalAvatarBytesCache[widget.username] = bytes;
            } catch (e) {}
          }
        }
      }
    } catch (e) {}

    try {
      final uri = Uri.parse(_avatarRawUrl);
      final token = await widget.tokenProvider();
      final headers = token != null
          ? {'authorization': 'Bearer $token'}
          : <String, String>{};
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await _writeBytesAtomically(resp.bodyBytes);
      } else {
        
        if (resp.statusCode == 404) {
          await _deleteCache();
        } else {
          if (mounted) {
            setState(() {
              _hasRemoteAvatar = false;
            });
          }
        }
      }
    } catch (e) {
      
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _writeBytesAtomically(Uint8List bytes) async {
    final outFile = await _newCacheFile(bytes);
    final tmp = File('${outFile.path}.tmp_${DateTime.now().microsecondsSinceEpoch}');

    try {
      await tmp.writeAsBytes(bytes, flush: true);
      if (await tmp.exists()) {
        await tmp.rename(outFile.path);
      }

      _globalAvatarBytesCache[widget.username] = bytes;

      if (mounted) {
        final String? prev = _cachedFilePath;
        setState(() {
          _previousCachedFilePath = prev;
          _cachedFilePath = outFile.path;
          _hasRemoteAvatar = true;
          _avatarExplicitlyDeleted = false; 
          
          _globalAvatarPathCache[widget.username] = outFile.path;
        });
        
        Future.delayed(const Duration(milliseconds: 200), () {
          if (prev != null && prev != outFile.path) {
            try { LazyImageCache().remove(prev); } catch (e) {}
            unawaited(_evictImageProviders(file: File(prev)));
          }
        });
      }
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (e) {}
      }
    }

    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final appSupport = await getApplicationSupportDirectory();
        final avatarDir = Directory('${appSupport.path}/avatars');
        final prefix = 'avatar_${widget.username}_';
        if (await avatarDir.exists()) {
          for (final f in avatarDir.listSync()) {
            if (f is File && f.path.contains(prefix) && f.path != outFile.path) {
              try { await f.delete(); } catch (e) {}
            }
          }
        }
      } catch (e) {}
    });
  }

  Future<void> _deleteCache() async {
    try {
      if (_cachedFilePath != null) {
        final f = File(_cachedFilePath!);
        if (await f.exists()) await f.delete().catchError((_) {});
        try { await _evictImageProviders(file: f); } catch (_){ }
        try { LazyImageCache().remove(f.path); } catch (_){ }
      }
      if (_previousCachedFilePath != null) {
        final pf = File(_previousCachedFilePath!);
        if (await pf.exists()) await pf.delete().catchError((_) {});
        try { await _evictImageProviders(file: pf); } catch (_){ }
        try { LazyImageCache().remove(pf.path); } catch (_){ }
      }
    } catch (e) {}
    if (mounted) {
      setState(() {
        _cachedFilePath = null;
        _previousCachedFilePath = null;
        _hasRemoteAvatar = false;
      });
    }
    
    try {
      final appSupport = await getApplicationSupportDirectory();
      final avatarDir = Directory('${appSupport.path}/avatars');
      final prefix = 'avatar_${widget.username}_';
      if (await avatarDir.exists()) {
        for (final f in avatarDir.listSync()) {
          if (f is File && f.path.contains(prefix)) {
            try { await f.delete(); } catch (e) {}
          }
        }
      }
    } catch (e) {}

    _globalAvatarPathCache.remove(widget.username);

    _updateCanEdit();
  }

  Future<void> _evictImageProviders({File? file, String? networkUrl}) async {
    if (file != null && await file.exists()) {
      try {
        await FileImage(file).evict();
      } catch (e) {}
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      try {
        await NetworkImage(networkUrl).evict();
      } catch (e) {}
    }
  }

  Future<void> _pickAndUpload() async {
    
    final cur = await AccountManager.getCurrentAccount();
    if (cur != widget.username) {
      _showStyledSnack('Cannot edit avatar for other user', isError: true);
      return;
    }

    setState(() => _uploading = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.first;
      final originalBytes = f.bytes;
      final filename = f.name;

      if (originalBytes == null || originalBytes.isEmpty) {
        _showStyledSnack('Selected file is empty', isError: true);
        return;
      }

      if (!mounted) return;
      final cropped = await showAvatarCropScreen(context, originalBytes);
      if (cropped == null) return; 

      final bytes = cropped;

      final token = await widget.tokenProvider();
      if (token == null) {
        _showStyledSnack('Unauthorized', isError: true);
        return;
      }

      final uri = Uri.parse(
        '${widget.avatarBaseUrl.replaceAll(RegExp(r'/$'), '')}/avatar/upload',
      );
      final req = http.MultipartRequest('POST', uri);
      req.headers['authorization'] = 'Bearer $token';
      req.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        
        try {
          if (bytes.isNotEmpty) {
            await _writeBytesAtomically(bytes);
          }
        } catch (e) {}
        avatarVersion.value++;
        widget.onUploaded?.call(_avatarRawUrl);
        _showStyledSnack('Avatar uploaded');
      } else {
        String msg = 'Upload error: (${resp.statusCode})';
        try {
          final j = jsonDecode(resp.body);
          if (j is Map && j['detail'] != null) msg = j['detail'].toString();
        } catch (e) {}
        _showStyledSnack(msg, isError: true);
      }
    } catch (e) {
      _showStyledSnack('Upload error: $e', isError: true);
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAvatar() async {
    
    final cur = await AccountManager.getCurrentAccount();
    if (cur != widget.username) {
      _showStyledSnack('Cannot delete avatar for other user', isError: true);
      return;
    }

    setState(() => _deleting = true);
    try {
      final token = await widget.tokenProvider();
      if (token == null) {
        _showStyledSnack('Unauthorized', isError: true);
        return;
      }
      final uri = Uri.parse(
        '${widget.avatarBaseUrl.replaceAll(RegExp(r'/$'), '')}/avatar/me',
      );
      final resp = await http.delete(
        uri,
        headers: {'authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        await _deleteCache();
        _avatarExplicitlyDeleted = true; 
        avatarVersion.value++;
        widget.onDeleted?.call();
        _showStyledSnack('Avatar deleted');
      } else {
        _showStyledSnack('Delete error: ${resp.statusCode}', isError: true);
      }
    } catch (e) {
      _showStyledSnack('Delete error: $e', isError: true);
    } finally {
      setState(() => _deleting = false);
    }
  }

  void _showStyledSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: colorScheme.surfaceVariant.withOpacity(SettingsManager.elementOpacity.value),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFallbackLetter() {
    final letter = (widget.username.isNotEmpty
        ? widget.username[0].toUpperCase()
        : '?');
    return CircleAvatar(
      key: ValueKey('fallback:${widget.username}'),
      radius: widget.size / 2,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: widget.size / 2.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sz = widget.size;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        SizedBox(
          width: sz,
          height: sz,
          child: GestureDetector(
            onTap: (widget.editable && _canEdit && !_uploading && !_deleting) ? _pickAndUpload : null,
            onLongPress: (widget.editable && _canEdit && !_uploading && !_deleting) ? () async {
              final confirmed = await _confirmDialog(
                'Delete avatar?',
                'Are you sure you want to delete the current avatar?',
              );
              if (confirmed == true) {
                await _deleteAvatar();
              }
            } : null,
            child: ClipRRect(
              key: ValueKey(_cachedFilePath ?? _previousCachedFilePath ?? 'fallback_${widget.username}'),
              borderRadius: BorderRadius.circular(sz / 2),
              child: _buildImageWithFallback(sz),
            ),
          ),
        ),
        if (_uploading || _deleting)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(sz / 2),
              ),
              child: Center(
                child: SizedBox(
                  width: sz * 0.35,
                  height: sz * 0.35,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageWithFallback(double sz) {
    final mq = MediaQuery.of(context);
    final targetWidth = (sz * mq.devicePixelRatio).round();
    final cache = LazyImageCache();

    if (_cachedFilePath != null) {
      final base = cache.getOrCreate(_cachedFilePath!, () => FileImage(File(_cachedFilePath!)));
      final provider = ResizeImage(base, width: targetWidth);
      return Image(
        image: provider,
        key: ValueKey('file:${_cachedFilePath}'),
        width: sz,
        height: sz,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackLetter(),
      );
    }

    if (_previousCachedFilePath != null) {
      final oldFile = File(_previousCachedFilePath!);
      if (oldFile.existsSync()) {
        final baseOld = cache.getOrCreate(oldFile.path, () => FileImage(oldFile));
        final providerOld = ResizeImage(baseOld, width: targetWidth);
        return Image(
          image: providerOld,
          key: ValueKey('file:${oldFile.path}'),
          width: sz,
          height: sz,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackLetter(),
        );
      }
    }

    final globalBytes = _globalAvatarBytesCache[widget.username];
    if (globalBytes != null && globalBytes.isNotEmpty) {
      return Image(
        image: ResizeImage(MemoryImage(globalBytes), width: targetWidth),
        key: ValueKey('mem:${widget.username}'),
        width: sz,
        height: sz,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackLetter(),
      );
    }

    return _buildFallbackLetter();
  }

  Widget _buildEditButton() {
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _deleting
                ? null
                : () async {
                    final confirmed = await _confirmDialog(
                      'Delete avatar?',
                      'Are you sure you want to delete the current avatar?',
                    );
                    if (confirmed == true) {
                      await _deleteAvatar();
                    }
                  },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.delete,
                size: widget.size * 0.22,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.edit,
                size: widget.size * 0.22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDialog(String title, String text) async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}

Future<Uint8List?> getAvatarCachedBytes(String username) async {
  
  final cachedBytes = _globalAvatarBytesCache[username];
  if (cachedBytes != null && cachedBytes.isNotEmpty) return cachedBytes;

  final inMemPath = _globalAvatarPathCache[username];
  if (inMemPath != null) {
    try {
      final f = File(inMemPath);
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        _globalAvatarBytesCache[username] = bytes; 
        return bytes;
      }
    } catch (e) {}
    
    _globalAvatarPathCache.remove(username);
  }

  try {
    final appSupport = await getApplicationSupportDirectory();
    final avatarDir  = Directory('${appSupport.path}/avatars');
    final prefix     = 'avatar_${username}_';

    if (await avatarDir.exists()) {
      String?   chosen;
      DateTime? latest;
      for (final entry in avatarDir.listSync()) {
        if (entry is File && entry.path.contains(prefix)) {
          try {
            final stat = await entry.stat();
            if (latest == null || stat.modified.isAfter(latest)) {
              latest = stat.modified;
              chosen = entry.path;
            }
          } catch (e) {}
        }
      }
      if (chosen != null) {
        final bytes = await File(chosen).readAsBytes();
        _globalAvatarPathCache[username] = chosen;
        _globalAvatarBytesCache[username] = bytes; 
        return bytes;
      }
    }
  } catch (e) {}

  return null;
}