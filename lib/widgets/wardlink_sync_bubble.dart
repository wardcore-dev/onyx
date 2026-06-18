// lib/widgets/wardlink_sync_bubble.dart
//
// A floating, draggable circle that surfaces *passive* WardLink sync — the
// same look as the QR-transfer bubble (WardLinkBubble), but driven by
// WardLinkSyncService.status. While syncing it shows a progress ring + spinner
// + a count badge; tapping it opens a live detail panel (peer, current file and
// %, files transferred, and the per-file list). It auto-hides ~3s after a sync
// finishes. Mount once at the global Stack level (MaterialApp.builder).

import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';

import '../globals.dart' show navigatorKey;
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../services/wardlink/wardlink_sync_service.dart';

class WardLinkSyncBubble extends StatefulWidget {
  const WardLinkSyncBubble({super.key});

  @override
  State<WardLinkSyncBubble> createState() => _WardLinkSyncBubbleState();
}

class _WardLinkSyncBubbleState extends State<WardLinkSyncBubble>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  // Drives the scale + fade appear/disappear of the whole bubble.
  late final AnimationController _appear;
  late final Animation<double> _appearCurve;
  Offset? _pos;
  bool _wasSyncing = false;
  bool _flashDone = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _appearCurve = CurvedAnimation(
      parent: _appear,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    WardLinkSyncService.instance.status.addListener(_onStatus);
    SettingsManager.wardLinkBubbleOnlyErrors.addListener(_onSettingChanged);
    SettingsManager.wardLinkBubbleSize.addListener(_onSettingChanged);
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
    _syncVisibility();
  }

  bool get _wantVisible {
    final st = WardLinkSyncService.instance.status.value;
    if (SettingsManager.wardLinkBubbleOnlyErrors.value) {
      // Errors-only: only show the post-sync flash, and only when it failed.
      return _flashDone;
    }
    return st.syncing || _flashDone;
  }

  void _syncVisibility() {
    if (_wantVisible) {
      _appear.forward();
    } else {
      _appear.reverse();
    }
  }

  void _onStatus() {
    if (!mounted) return;
    final st = WardLinkSyncService.instance.status.value;
    final syncing = st.syncing;
    final onlyErrors = SettingsManager.wardLinkBubbleOnlyErrors.value;
    if (_wasSyncing && !syncing) {
      _flashTimer?.cancel();
      // In errors-only mode flash only when the sync actually failed.
      if (!onlyErrors || st.lastSyncFailed) {
        _flashDone = true;
        _flashTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _flashDone = false);
            _syncVisibility();
          }
        });
      }
    } else if (syncing && _flashDone) {
      _flashDone = false;
    }
    _wasSyncing = syncing;
    _syncVisibility();
    setState(() {});
  }

  @override
  void dispose() {
    WardLinkSyncService.instance.status.removeListener(_onStatus);
    SettingsManager.wardLinkBubbleOnlyErrors.removeListener(_onSettingChanged);
    SettingsManager.wardLinkBubbleSize.removeListener(_onSettingChanged);
    _flashTimer?.cancel();
    _spin.dispose();
    _appear.dispose();
    super.dispose();
  }

  void _openDetails() {
    final navCtx = navigatorKey.currentState?.overlay?.context;
    if (navCtx == null) return;
    showDialog(
      context: navCtx,
      barrierColor: Colors.black54,
      builder: (_) => const _WardLinkDetailsDialog(),
    );
  }

  void _openLog() {
    final navCtx = navigatorKey.currentState?.overlay?.context;
    if (navCtx == null) return;
    showDialog(
      context: navCtx,
      barrierColor: Colors.black54,
      builder: (_) => const _WardLinkLogDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = WardLinkSyncService.instance.status.value;
    // Stay mounted through the exit animation; only vanish once fully collapsed.
    if (!_wantVisible && _appear.isDismissed) return const SizedBox.shrink();

    final sz = SettingsManager.wardLinkBubbleSize.value.toDouble();
    final mq = MediaQuery.of(context);
    _pos ??= Offset(mq.size.width - sz - 16, mq.size.height - 220);

    final cs = Theme.of(context).colorScheme;
    final isDone = _flashDone && !st.syncing;
    final isFailed = st.lastSyncFailed && _flashDone;
    final progress = st.fileProgress;
    final scale = _appearCurve.value.clamp(0.0, 1.0);

    return Positioned(
      left: _pos!.dx,
      top: _pos!.dy,
      child: Opacity(
        opacity: _appear.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          setState(() {
            _pos = Offset(
              (_pos!.dx + d.delta.dx).clamp(0.0, mq.size.width - sz),
              (_pos!.dy + d.delta.dy)
                  .clamp(mq.viewPadding.top, mq.size.height - 90),
            );
          });
        },
        onTap: isDone ? null : _openDetails,
        onLongPress: _openLog,
        child: SizedBox(
          width: sz,
          height: sz,
          child: AnimatedBuilder(
            animation: _spin,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: sz,
                    height: sz,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFailed
                          ? cs.errorContainer
                          : isDone
                              ? cs.primary
                              : cs.primaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: (isFailed ? cs.error : cs.primary)
                              .withValues(alpha: 0.30),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  if (!isDone)
                    SizedBox(
                      width: sz - 6,
                      height: sz - 6,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(cs.primary),
                      ),
                    ),
                  isDone
                      ? Icon(
                          isFailed ? Icons.sync_problem_rounded : Icons.check_rounded,
                          size: sz * 0.48,
                          color: isFailed ? cs.onErrorContainer : cs.onPrimary,
                        )
                      : Transform.rotate(
                          angle: _spin.value * 2 * pi,
                          child: Icon(Icons.sync_rounded,
                              size: sz * 0.42, color: cs.onPrimaryContainer),
                        ),
                  // Count badge.
                  if (!isDone && st.filesDone > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 1.5),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${st.filesDone}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimary),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
          ), // GestureDetector
        ), // Transform.scale
      ), // Opacity
    ); // Positioned
  }
}

class _WardLinkDetailsDialog extends StatelessWidget {
  const _WardLinkDetailsDialog();

  String _human(int b) {
    if (b <= 0) return '';
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ValueListenableBuilder<WardLinkStatus>(
          valueListenable: WardLinkSyncService.instance.status,
          builder: (_, st, __) {
            final pct = st.fileProgress != null
                ? '${(st.fileProgress! * 100).round()}%'
                : '';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          st.peerName != null
                              ? 'WardLink · ${st.peerName}'
                              : 'WardLink',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Current file + progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st.syncing
                            ? l.wardLinkSyncingNow
                            : (st.filesDone > 0
                                ? l.wardLinkDone
                                : l.wardLinkUpToDate),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary),
                      ),
                      if (st.currentFile != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                st.currentFile!,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (pct.isNotEmpty)
                              Text(pct,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: st.fileProgress,
                            minHeight: 5,
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        if (st.bytesTotal > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_human(st.bytesReceived)} / ${_human(st.bytesTotal)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      Text(
                        l.wardLinkFilesDone(st.filesDone),
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // File list
                Flexible(
                  child: st.files.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              l.wardLinkNoFilesYet,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: st.files.length,
                          itemBuilder: (_, i) {
                            // newest first
                            final f = st.files[st.files.length - 1 - i];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: f.done
                                  ? Icon(Icons.check_circle_rounded,
                                      size: 18, color: Colors.green)
                                  : SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: cs.primary),
                                    ),
                              title: Text(
                                f.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Long-press dialog: chats being synced (with their files) + expandable log.
class _WardLinkLogDialog extends StatefulWidget {
  const _WardLinkLogDialog();

  @override
  State<_WardLinkLogDialog> createState() => _WardLinkLogDialogState();
}

class _WardLinkLogDialogState extends State<_WardLinkLogDialog> {
  bool _logExpanded = false;
  final ScrollController _logScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WardLinkSyncService.instance.status.addListener(_rebuild);
    WardLinkSyncService.instance.log.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WardLinkSyncService.instance.status.removeListener(_rebuild);
    WardLinkSyncService.instance.log.removeListener(_rebuild);
    _logScroll.dispose();
    super.dispose();
  }

  Color _levelColor(ColorScheme cs, WardLinkLogLevel lvl) => switch (lvl) {
        WardLinkLogLevel.error => cs.error,
        WardLinkLogLevel.warn => Colors.orange,
        WardLinkLogLevel.info => cs.onSurface.withValues(alpha: 0.65),
      };

  String _ts(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Builder(
          builder: (_) {
            final st = WardLinkSyncService.instance.status.value;
            final logs = WardLinkSyncService.instance.log.value;
            final hasErrors =
                logs.any((e) => e.level == WardLinkLogLevel.error);
            final pct = st.fileProgress != null
                ? ' · ${(st.fileProgress! * 100).round()}%'
                : '';
            final activity = st.syncing
                ? '${l.wardLinkSyncingNow}'
                    '${st.currentFile != null ? '  ${st.currentFile}$pct' : ''}'
                : (st.filesDone > 0 ? l.wardLinkDone : l.wardLinkUpToDate);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              st.peerName != null
                                  ? 'WardLink · ${st.peerName}'
                                  : 'WardLink',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              activity,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.55)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Chat list (scrollable) ─────────────────────────────────
                Flexible(
                  child: st.chatEntries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              l.wardLinkLogEmpty,
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.45)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          itemCount: st.chatEntries.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) {
                            final chat = st.chatEntries[i];
                            final allDone =
                                chat.files.every((f) => f.done || f.error);
                            final anyError = chat.files.any((f) => f.error);
                            final icon = chat.files.isEmpty
                                ? Icons.chat_outlined
                                : anyError
                                    ? Icons.warning_amber_rounded
                                    : allDone
                                        ? Icons.check_circle_rounded
                                        : Icons.sync_rounded;
                            final iconColor = anyError
                                ? cs.error
                                : allDone
                                    ? Colors.green
                                    : cs.primary;
                            return ExpansionTile(
                              leading: Icon(icon, color: iconColor, size: 22),
                              title: Text(
                                chat.title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                chat.newMessages == 1
                                    ? '1 new message'
                                    : '${chat.newMessages} new messages'
                                        '${chat.files.isNotEmpty ? ', ${chat.files.length} file(s)' : ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.55)),
                              ),
                              tilePadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              childrenPadding: EdgeInsets.zero,
                              children: chat.files.isEmpty
                                  ? [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            52, 0, 16, 12),
                                        child: Text(
                                          'No media files',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.4)),
                                        ),
                                      ),
                                    ]
                                  : [
                                      for (final f in chat.files)
                                        ListTile(
                                          dense: true,
                                          visualDensity:
                                              VisualDensity.compact,
                                          contentPadding:
                                              const EdgeInsets.only(
                                                  left: 52, right: 16),
                                          leading: f.error
                                              ? Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 16,
                                                  color: cs.error)
                                              : f.done
                                                  ? const Icon(
                                                      Icons
                                                          .check_circle_outline_rounded,
                                                      size: 16,
                                                      color: Colors.green)
                                                  : SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  cs.primary),
                                                    ),
                                          title: Text(
                                            f.name,
                                            style: const TextStyle(
                                                fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                            );
                          },
                        ),
                ),

                // ── Expandable log ────────────────────────────────────────
                const Divider(height: 1),
                InkWell(
                  onTap: () =>
                      setState(() => _logExpanded = !_logExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          hasErrors
                              ? Icons.error_outline_rounded
                              : Icons.receipt_long_rounded,
                          size: 16,
                          color: hasErrors
                              ? cs.error
                              : cs.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.wardLinkLog +
                                (hasErrors ? '  ⚠ errors' : ''),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: hasErrors
                                  ? cs.error
                                  : cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        Icon(
                          _logExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_logExpanded)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: logs.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(l.wardLinkLogEmpty,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4))),
                          )
                        : ListView.builder(
                            controller: _logScroll,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            itemCount: logs.length,
                            itemBuilder: (_, i) {
                              final e = logs[logs.length - 1 - i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _ts(e.time),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: cs.onSurface
                                              .withValues(alpha: 0.35)),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        e.message,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.3,
                                          color: _levelColor(cs, e.level),
                                          fontWeight:
                                              e.level ==
                                                      WardLinkLogLevel.error
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
