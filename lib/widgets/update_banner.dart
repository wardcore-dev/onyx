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

// ── Simple inline Markdown renderer (no external package needed) ────────────
class MarkdownText extends StatelessWidget {
  final String data;
  final Color textColor;
  final double baseFontSize;

  const MarkdownText({
    super.key,
    required this.data,
    required this.textColor,
    this.baseFontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final lines = data.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trimRight();

      if (line.startsWith('### ')) {
        widgets.add(_headingLine(line.substring(4), baseFontSize + 0, FontWeight.w700));
      } else if (line.startsWith('## ')) {
        widgets.add(_headingLine(line.substring(3), baseFontSize + 1, FontWeight.w700));
      } else if (line.startsWith('# ')) {
        widgets.add(_headingLine(line.substring(2), baseFontSize + 2, FontWeight.bold));
      } else if (line.startsWith('* ') || line.startsWith('- ')) {
        widgets.add(_bulletLine(line.substring(2)));
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 4));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _inlineText(line, baseFontSize, FontWeight.normal),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _headingLine(String text, double size, FontWeight weight) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: _inlineText(text, size, weight),
    );
  }

  Widget _bulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: _inlineText(text, baseFontSize, FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _inlineText(String text, double size, FontWeight defaultWeight) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int cursor = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: size - 1,
            color: textColor.withValues(alpha: 0.8),
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: size,
          fontWeight: defaultWeight,
          color: textColor,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
}
// ────────────────────────────────────────────────────────────────────────────

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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Download Update',
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
      pageBuilder: (_, __, ___) => _DownloadDialog(info: info),
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
  late String _status;
  bool _statusInitialized = false;
  bool _downloading = false;
  bool _done = false;
  String? _savedPath;
  bool _cancelled = false;
  http.Client? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_statusInitialized) {
      _status = AppLocalizations.of(context).downloadUpdateReady;
      _statusInitialized = true;
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _client?.close();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _downloading = true;
      _status = l.downloadUpdateDownloading;
      _progress = 0;
    });

    try {
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
          _status = l.downloadUpdateNoPlatform;
          _downloading = false;
        });
        return;
      }

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

      _client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client!.send(request);

      final totalBytes = response.contentLength ?? widget.info.fileSize;
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
          _status = l.downloadUpdateComplete;
          _downloading = false;
          _done = true;
        });
      }

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
        await OpenFilex.open(path,
            type: 'application/vnd.android.package-archive');
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

  void _cancel() {
    _cancelled = true;
    _client?.close();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final fileSizeStr = _formatBytes(widget.info.fileSize);
    final hasNotes = widget.info.releaseNotes != null &&
        widget.info.releaseNotes!.trim().isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.07),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.system_update_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.downloadUpdateTitle,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.info.version,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                if (fileSizeStr.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    fileSizeStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // X кнопка
                      if (!_downloading)
                        GestureDetector(
                          onTap: _cancel,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Release notes ────────────────────────────────────────
                if (hasNotes)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l.downloadUpdateWhatsNew,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                            color: colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: SingleChildScrollView(
                            child: MarkdownText(
                              data: widget.info.releaseNotes!,
                              textColor: colorScheme.onSurface
                                  .withValues(alpha: 0.65),
                              baseFontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Progress / status ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_downloading || _done) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            minHeight: 6,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor:
                                AlwaysStoppedAnimation(colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _downloading
                              ? '${(_progress * 100).toStringAsFixed(0)}%  —  $_status'
                              : _status,
                          style: TextStyle(
                            fontSize: 12,
                            color: _done
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ] else
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Action buttons ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_downloading && !_done)
                        FilledButton.icon(
                          onPressed: _startDownload,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(
                            l.downloadUpdateInstall,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_downloading)
                        OutlinedButton(
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(l.downloadUpdateCancel),
                        ),
                      if (_done && !kIsWeb && !Platform.isWindows)
                        FilledButton(
                          onPressed: _launchInstaller,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            l.downloadUpdateOpen,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (!_downloading && !_done && _status.startsWith('Error'))
                        FilledButton.icon(
                          onPressed: _startDownload,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(l.downloadUpdateRetry),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
