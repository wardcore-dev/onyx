import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';

class FileMessageWidget extends StatefulWidget {
  final String filename;
  final String? owner;
  final String peerUsername;
  final bool isOutgoing;
  final String? senderUsername;
  final String? directUrl; 
  final String? mediaKeyB64;

  const FileMessageWidget(
      {Key? key,
      required this.filename,
      this.owner,
      required this.peerUsername,
      required this.isOutgoing,
      this.senderUsername,
      this.directUrl,
      this.mediaKeyB64})
      : super(key: key);

  @override
  State<FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<FileMessageWidget> {
  bool _isLoading = false;
  String? _lastEnsureError;
  double? _downloadProgress; 
  File? _cachedFile;
  http.Client? _activeClient;
  bool _cancelRequested = false;

  void _cancelDownload() {
    _cancelRequested = true;
    _activeClient?.close();
    _activeClient = null;
    if (mounted) setState(() { _isLoading = false; _downloadProgress = null; });
  }

  String get filename => widget.filename;
  String get peerUsername => widget.peerUsername;
  bool get isOutgoing => widget.isOutgoing;
  String? get senderUsername => widget.senderUsername;
  String? get directUrl => widget.directUrl;

  IconData _iconForExt(String ext) {
    ext = ext.toLowerCase();
    if (['.pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['.doc', '.docx'].contains(ext)) return Icons.description;
    if (['.xls', '.xlsx'].contains(ext)) return Icons.table_chart;
    if (['.ppt', '.pptx'].contains(ext)) return Icons.slideshow;
    if (['.zip', '.rar', '.7z', '.tar', '.gz'].contains(ext)) {
      return Icons.folder_zip;
    }
    if (['.txt', '.rtf', '.json', '.xml', '.csv'].contains(ext)) {
      return Icons.text_snippet;
    }
    return Icons.attach_file;
  }

  Future<File?> _ensureCached({void Function(double)? onProgress}) async {
    try {
      debugPrint('[FileWidget] Loading file: "$filename"');

      if (filename.startsWith('lan://')) {
        debugPrint('[FileWidget] LAN file detected: $filename');
        final lanFilename = filename.substring(6); 
        final appDocuments = await getApplicationDocumentsDirectory();
        final lanFile = File('${appDocuments.path}/lan_media/$lanFilename');
        if (await lanFile.exists()) {
          debugPrint('FileMessageWidget: LAN file found at ${lanFile.path}');
          return lanFile;
        } else {
          debugPrint('FileMessageWidget: LAN file not found: $lanFilename');
          return null;
        }
      }

      if (directUrl != null && directUrl!.isNotEmpty) {
        debugPrint('FileMessageWidget: Using direct URL: $directUrl');
        final cached = await _downloadFromDirectUrl(directUrl!, filename,
            onProgress: onProgress);
        if (cached != null) {
          debugPrint(
              'FileMessageWidget: file cached successfully at ${cached.path}');
        } else {
          debugPrint('FileMessageWidget: failed to cache file from direct URL');
        }
        return cached;
      }

      final root = rootScreenKey.currentState;
      if (root == null) {
        debugPrint('FileMessageWidget: root screen state is null');
        return null;
      }
      
      final username =
          senderUsername?.isNotEmpty == true ? senderUsername! : peerUsername;
      debugPrint(
          'FileMessageWidget: downloading/caching file $filename from peer $username');
      final cached = await root.downloadFileToCache(filename,
          peerUsername: username, owner: widget.owner, mediaKeyB64: widget.mediaKeyB64, onProgress: onProgress);
      if (cached != null) {
        debugPrint(
            'FileMessageWidget: file cached successfully at ${cached.path}');
      } else {
        debugPrint('FileMessageWidget: failed to cache file $filename');
      }
      return cached;
    } catch (e, st) {
      _lastEnsureError = e.toString();
      debugPrint('FileMessageWidget download error: $e\n$st');
      return null;
    }
  }

  Future<String?> _saveWithDialog(File f, BuildContext context) async {
    try {
      final basename = p.basename(f.path);

      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final dl = await getDownloadsDirectory();
        if (dl == null) {
          rootScreenKey.currentState
              ?.showSnack('Cannot access Downloads directory');
          return null;
        }
        final onyxDir = Directory('${dl.path}/ONYX');
        await onyxDir.create(recursive: true);
        final destPath = '${onyxDir.path}/$basename';
        final savedFile = File(destPath);
        await f.copy(savedFile.path);
        return savedFile.path;
      }

      if (kIsWeb) {
        rootScreenKey.currentState?.showSnack(
            'Save not supported on web — open the file and save');
        return null;
      }

      if (Platform.isAndroid) {
        final bytes = await f.readAsBytes();
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save file',
          fileName: basename,
          bytes: bytes,
        );
        return savedPath;
      }

      if (Platform.isIOS) {
        final targetDir = await getApplicationDocumentsDirectory();
        final destPath = '${targetDir.path}/$basename';
        final savedFile = File(destPath);
        await f.copy(savedFile.path);
        return savedFile.path;
      }

      return null;
    } catch (e, st) {
      debugPrint('File save failed: $e\n$st');
      return null;
    }
  }

  Future<File?> _downloadFromDirectUrl(String url, String filename,
      {void Function(double)? onProgress}) async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/file_cache');
      await cacheDir.create(recursive: true);

      final ext = p.extension(filename);
      final baseName = p.basenameWithoutExtension(filename);
      final localPath = '${cacheDir.path}/$baseName$ext';
      final localFile = File(localPath);

      if (await localFile.exists()) {
        debugPrint('[FileWidget] File already cached: $localPath');
        return localFile;
      }

      debugPrint('[FileWidget] Downloading from direct URL: $url');

      _activeClient = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        final streamedResponse = await _activeClient!.send(request);

        if (streamedResponse.statusCode != 200) {
          _lastEnsureError = 'HTTP ${streamedResponse.statusCode}';
          return null;
        }

        final contentLength = streamedResponse.contentLength;
        final chunks = <List<int>>[];
        int received = 0;

        await for (final chunk in streamedResponse.stream) {
          if (_cancelRequested) return null;
          chunks.add(chunk);
          received += chunk.length;
          if (contentLength != null && contentLength > 0) {
            onProgress?.call((received / contentLength).clamp(0.0, 1.0));
          }
        }

        if (_cancelRequested) return null;
        final bytes = chunks.expand((c) => c).toList();
        await localFile.writeAsBytes(bytes, flush: true);
        debugPrint('[FileWidget] Downloaded successfully to: $localPath');
        return localFile;
      } finally {
        _activeClient?.close();
        _activeClient = null;
      }
    } catch (e, st) {
      _lastEnsureError = e.toString();
      debugPrint('[FileWidget] Direct URL download error: $e\n$st');
      return null;
    }
  }

  String _getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.apk':
        return 'application/vnd.android.package-archive';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.zip':
      case '.rar':
      case '.7z':
        return 'application/octet-stream';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.mp4':
      case '.avi':
      case '.mov':
        return 'video/mp4';
      case '.mp3':
      case '.wav':
      case '.flac':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _openFile(File f) async {
    try {
      final mimeType = _getMimeType(f.path);
      debugPrint('Opening file: ${f.path} with MIME type: $mimeType');
      await OpenFilex.open(f.path);
    } catch (e) {
      debugPrint('Error opening file: $e');
      rootScreenKey.currentState?.showSnack('Cannot open file');
    }
  }

  Future<void> _downloadThenRun(Future<void> Function(File) action) async {
    
    if (_cachedFile != null && await _cachedFile!.exists()) {
      await action(_cachedFile!);
      return;
    }

    _cancelRequested = false;
    setState(() {
      _isLoading = true;
      _downloadProgress = 0.0;
    });
    _lastEnsureError = null;
    try {
      final cached = await _ensureCached(
          onProgress: (prog) {
            if (mounted) setState(() => _downloadProgress = prog);
          });
      if (cached == null) {
        if (_cancelRequested) return; 
        if (mounted) {
          final raw = _lastEnsureError ?? '';
          final msg = (raw.contains('404') ||
                  raw.toLowerCase().contains('not found'))
              ? 'File not found on server'
              : raw.isNotEmpty
                  ? 'Download failed: $raw'
                  : 'Download failed';
          rootScreenKey.currentState?.showSnack(msg);
        }
        return;
      }
      _cachedFile = cached;
      mediaFilePathRegistry[widget.filename] = cached.path;
      if (!mounted) return;
      await action(cached);
    } finally {
      if (mounted) setState(() { _isLoading = false; _downloadProgress = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = p.extension(filename).toLowerCase();
    final icon = _iconForExt(ext);
    final showProgress = _downloadProgress != null;

    return GestureDetector(
      onTap: _isLoading ? null : () => _downloadThenRun(_openFile),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),

                if (showProgress) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_downloadProgress! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _cancelDownload,
                        child: Icon(Icons.close, size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await _downloadThenRun((cached) async {
                                
                                if (mounted) {
                                  setState(() => _downloadProgress = null);
                                }
                                final saved =
                                    await _saveWithDialog(cached, context);
                                if (mounted) {
                                  if (saved != null) {
                                    rootScreenKey.currentState
                                        ?.showSnack('Saved to $saved');
                                  } else {
                                    rootScreenKey.currentState
                                        ?.showSnack('Failed to save file');
                                  }
                                }
                              });
                            },
                      icon: (_isLoading && _downloadProgress == null)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_as, size: 16),
                      label: Text(_isLoading
                          ? (_downloadProgress != null
                              ? 'Downloading...'
                              : 'Saving...')
                          : 'Save As'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(100, 36)),
                    ),
                  ],
                ),
              ],
            ),
            ), // Flexible
          ],
        ),
      ),
    );
  }
}