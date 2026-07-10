// lib/widgets/pending_device_dialog.dart
//
// Modal list of devices awaiting approval from THIS (trusted) device.
// Dismissing it (tap outside / back) does NOT clear PendingDeviceApprovals —
// the floating bubble keeps reminding until each entry is approved or denied.
//
// Styled to match about_onyx_dialog.dart (the server-info / what's-new
// window): tinted header on colorScheme.primary, square close button,
// uppercase section label, bordered surface cards. No orange — device cards
// use the theme's primary color instead of a hardcoded warning color.
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../services/pending_device_approvals.dart';

Future<void> showPendingDeviceApprovalsDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const PendingDeviceApprovalsDialog(),
  );
}

class PendingDeviceApprovalsDialog extends StatefulWidget {
  const PendingDeviceApprovalsDialog({super.key});

  @override
  State<PendingDeviceApprovalsDialog> createState() => _PendingDeviceApprovalsDialogState();
}

class _PendingDeviceApprovalsDialogState extends State<PendingDeviceApprovalsDialog> {
  final Set<int> _busy = {};

  IconData _deviceIcon(String? os) {
    final lower = (os ?? '').toLowerCase();
    if (lower.contains('android')) return Icons.phone_android;
    if (lower.contains('ios')) return Icons.phone_iphone;
    if (lower.contains('windows')) return Icons.desktop_windows;
    if (lower.contains('mac')) return Icons.laptop_mac;
    if (lower.contains('linux')) return Icons.computer;
    return Icons.devices_other;
  }

  String _formatWhen(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approve(int id) async {
    setState(() => _busy.add(id));
    await PendingDeviceApprovals.approve(id);
    if (mounted) setState(() => _busy.remove(id));
  }

  Future<void> _deny(int id) async {
    setState(() => _busy.add(id));
    await PendingDeviceApprovals.deny(id);
    if (mounted) setState(() => _busy.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final brightness = SettingsManager.elementBrightness.value;
    final opacity = SettingsManager.elementOpacity.value;
    final surfaceColor = SettingsManager.getElementColor(
      cs.surface,
      brightness,
    ).withValues(alpha: opacity);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Material(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            child: ValueListenableBuilder<List<PendingDeviceApproval>>(
              valueListenable: PendingDeviceApprovals.list,
              builder: (_, items, __) {
                if (items.isEmpty) {
                  // Everything got resolved while the dialog was open.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(context).pop();
                  });
                  return const SizedBox(height: 1);
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        border: Border(
                          bottom: BorderSide(
                            color: cs.primary.withValues(alpha: 0.10),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.shield_outlined, color: cs.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              items.length == 1
                                  ? l10n.pendingDeviceTitleSingle
                                  : l10n.pendingDeviceTitleMulti(items.length),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final isBusy = _busy.contains(item.id);
                          final quorum = item.approvalsRequired > 1;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                                      child: Icon(_deviceIcon(item.deviceOs), color: cs.primary, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(
                                            '${item.deviceOs ?? 'Unknown OS'} · ${_formatWhen(item.requestedAt)}',
                                            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                                          ),
                                          if (quorum)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                '${l10n.approvalsProgress} ${item.approvals}/${item.approvalsRequired}',
                                                style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isBusy ? null : () => _deny(item.id),
                                        icon: Icon(Icons.logout, size: 16, color: Colors.red.shade400),
                                        label: Text(l10n.pendingDeviceDeny, style: TextStyle(color: Colors.red.shade400)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: isBusy ? null : () => _approve(item.id),
                                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                                        icon: isBusy
                                            ? const SizedBox(
                                                height: 14, width: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.check, size: 16, color: Colors.white),
                                        label: Text(l10n.pendingDeviceApprove, style: const TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ],
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
        ),
      ),
    );
  }
}
