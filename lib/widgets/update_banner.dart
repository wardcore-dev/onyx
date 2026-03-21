// lib/widgets/update_banner.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/update_checker.dart';
import '../l10n/app_localizations.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: updateInfoNotifier,
      builder: (context, info, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: info == null
              ? const SizedBox.shrink()
              : _UpdateBannerContent(info: info),
        );
      },
    );
  }
}

class _UpdateBannerContent extends StatelessWidget {
  final UpdateInfo info;

  const _UpdateBannerContent({required this.info});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.18),
            width: 0.8,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              Icon(
                Icons.autorenew_rounded,
                size: 17,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${AppLocalizations.of(context).updateAvailableLabel}: ${info.version}',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _showDownloadDialog(context, info),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(AppLocalizations.of(context).updateDownload),
              ),
              GestureDetector(
                onTap: () => updateInfoNotifier.value = null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 15,
                    color: colorScheme.primary.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(info: info),
    );
  }
}

class _DownloadDialog extends StatefulWidget {
  final UpdateInfo info;

  const _DownloadDialog({required this.info});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;
  String _status = 'Ready to download';
  bool _downloading = false;
  bool _done = false;
  String? _savedPath;
  bool _cancelled = false;
  http.Client? _client;

  @override
  void dispose() {
    _cancelled = true;
    _client?.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _status = 'Downloading...';
      _progress = 0;
    });

    try {
      // iOS — открываем браузер (App Store не позволяет sideload)
      if (!kIsWeb && Platform.isIOS) {
        final url = Uri.parse(widget.info.downloadUrl ?? '');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final url = widget.info.downloadUrl;
      if (url == null) {
        setState(() {
          _status = 'No download available for this platform';
          _downloading = false;
        });
        return;
      }

      // Выбираем папку для сохранения
      Directory saveDir;
      if (Platform.isWindows) {
        saveDir = await getTemporaryDirectory();
      } else {
        final home = Platform.environment['HOME'] ??
            (await getTemporaryDirectory()).path;
        saveDir = Directory('$home/Downloads');
        if (!await saveDir.exists()) {
          saveDir = await getTemporaryDirectory();
        }
      }

      final savePath =
          '${saveDir.path}${Platform.isWindows ? r'\' : '/'}${widget.info.assetName ?? 'onyx_update'}';

      // Стриминговая загрузка с прогрессом
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client!.send(request);

      final totalBytes =
          response.contentLength ?? widget.info.fileSize;
      int receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        if (_cancelled) {
          await sink.close();
          if (await file.exists()) await file.delete();
          return;
        }
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _progress = receivedBytes / totalBytes);
        }
      }

      await sink.close();
      _savedPath = savePath;

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _status = 'Download complete!';
          _downloading = false;
          _done = true;
        });
      }

      // На Windows и Android — сразу запускаем установщик
      if (!kIsWeb && (Platform.isWindows || Platform.isAndroid) && mounted) {
        await _launchInstaller();
      }
    } catch (e) {
      if (mounted && !_cancelled) {
        setState(() {
          _status = 'Error: ${e.toString()}';
          _downloading = false;
        });
      }
    }
  }

  Future<void> _launchInstaller() async {
    final path = _savedPath;
    if (path == null) return;
    try {
      if (!kIsWeb && Platform.isWindows) {
        await Process.start(path, [], mode: ProcessStartMode.detached);
        exit(0);
      } else if (!kIsWeb && Platform.isAndroid) {
        await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
        if (mounted) Navigator.of(context).pop();
      } else if (!kIsWeb && Platform.isMacOS) {
        await Process.run('open', [path]);
        if (mounted) Navigator.of(context).pop();
      } else if (!kIsWeb && Platform.isLinux) {
        await Process.run('xdg-open', [File(path).parent.path]);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Saved to: $path\nLaunch it manually.');
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileSizeStr = _formatBytes(widget.info.fileSize);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.autorenew_rounded, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Download Update'),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Version: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  widget.info.version,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (fileSizeStr.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    fileSizeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ],
            ),
            if (widget.info.releaseNotes != null &&
                widget.info.releaseNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'What\'s new:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.releaseNotes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_downloading || _done) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 5,
                  backgroundColor:
                      colorScheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _downloading
                    ? '${(_progress * 100).toStringAsFixed(0)}%'
                    : _status,
                style: TextStyle(
                  fontSize: 12,
                  color: _done
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ] else ...[
              Text(
                _status,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_downloading && !_done) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text('Download & Install'),
          ),
        ],
        if (_done && !kIsWeb && !Platform.isWindows) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: _launchInstaller,
            child: const Text('Open'),
          ),
        ],
        if (_downloading)
          TextButton(
            onPressed: () {
              _cancelled = true;
              _client?.close();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        if (!_downloading && !_done && _status.startsWith('Error'))
          FilledButton(
            onPressed: _startDownload,
            child: const Text('Retry'),
          ),
      ],
    );
  }
}
