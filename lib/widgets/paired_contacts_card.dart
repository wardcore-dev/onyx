// lib/widgets/paired_contacts_card.dart
//
// Entry points for Tor contacts, used by the profile dialog on the Accounts
// tab: [showOnionPairDialog] opens the QR dialog (show my code / scan a
// friend's) and [showPairedContactsDialog] lists everyone already paired,
// with removal. Replaces the old Onion Mode settings section.

import 'package:flutter/material.dart';

import '../globals.dart' show rootScreenKey;
import '../background/notification_service.dart';
import '../globals.dart' show avatarTokenProvider, serverBase, avatarVersion;
import '../l10n/app_localizations.dart';
import '../managers/account_manager.dart';
import 'avatar_widget.dart';
import '../screens/settings_tab.dart' show OnionQrDialog;
import '../services/onion/onion_account.dart';
import '../services/onion/onion_identity.dart';
import '../services/onion/onion_paired_peers.dart';
import '../services/onion/onion_transport_service.dart';
import 'onyx_dialog.dart';

Future<void> showOnionPairDialog(BuildContext context) async {
  final username = await AccountManager.getCurrentAccount();
  if (username == null) {
    rootScreenKey.currentState
        ?.showSnack(AppLocalizations.of(context).notLoggedIn);
    return;
  }
  if (!context.mounted) return;
  await showOnyxDialog<void>(
    context: context,
    barrierLabel: AppLocalizations.of(context).pairOverTor,
    builder: (_) => const OnionQrDialog(),
  );
}

Future<void> showPairedContactsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PairedContactsDialog(),
  );
}

/// This account's devices (see OnionAccount), with unlinking.
Future<void> showOwnDevicesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _OwnDevicesDialog(),
  );
}

class _OwnDevicesDialog extends StatelessWidget {
  const _OwnDevicesDialog();

  Future<void> _unlink(BuildContext context, RosterDevice d) async {
    final l = AppLocalizations.of(context);
    final ok = await showOnyxConfirmDialog(
      context: context,
      title: d.name.isNotEmpty ? d.name : l.myDevicesTitle,
      message: l.myDevicesUnlinkConfirm,
      confirmLabel: l.myDevicesUnlink,
      isDestructive: true,
      icon: Icons.link_off_rounded,
    );
    if (ok == true) {
      await OnionTransportService.instance.unlinkOwnDevice(d.pub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    Widget tile(RosterDevice d, {bool current = false}) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                d.os == 'android' || d.os == 'ios'
                    ? Icons.smartphone_rounded
                    : Icons.computer_rounded,
                color: cs.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      current
                          ? '${d.name} · ${l.myDevicesThisDevice}'
                          : d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(d.onion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          color: cs.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            if (!current)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l.myDevicesUnlink,
                icon: Icon(Icons.link_off_rounded, size: 20, color: cs.error),
                onPressed: () => _unlink(context, d),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Material(
          color: cs.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.devices_rounded,
                          color: cs.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l.myDevicesTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
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
              Flexible(
                child: ValueListenableBuilder<List<RosterDevice>>(
                  valueListenable: OnionAccount.otherDevices,
                  builder: (_, others, __) {
                    final self = OnionIdentity.isRunning
                        ? OnionAccount.roster
                            ?.device(OnionIdentity.publicKeyB64)
                        : null;
                    return ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      children: [
                        if (self != null) ...[
                          tile(self, current: true),
                          const SizedBox(height: 8),
                        ],
                        for (final d in others) ...[
                          tile(d),
                          const SizedBox(height: 8),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                          child: Text(l.myDevicesHint,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.55))),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PairedContactsDialog extends StatelessWidget {
  const _PairedContactsDialog();

  /// Removes the contact -- every device of theirs: a person with a phone
  /// and a computer is one contact.
  Future<void> _remove(BuildContext context, OnionPeer peer) async {
    final l = AppLocalizations.of(context);
    final ok = await showOnyxConfirmDialog(
      context: context,
      title: peer.name,
      message: l.contactsRemoveConfirm(peer.username),
      confirmLabel: l.remove,
      isDestructive: true,
      icon: Icons.link_off_rounded,
    );
    if (ok != true) return;
    final devices = OnionPairedPeers.allByUsername(peer.username);
    for (var i = 0; i < devices.length; i++) {
      await OnionPairedPeers.remove(devices[i].identityPubB64);
      rootScreenKey.currentState?.markOnionDeviceUnpaired(
          peer.username, devices[i].identityPubB64,
          hasOtherDevices: i < devices.length - 1);
    }
  }

  // Chrome matches AboutOnyxDialog: transparent Dialog + Material(radius 28)
  // card, tinted/bordered header strip, rounded-square icon and close button.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Material(
          color: cs.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.people_alt_rounded,
                          color: cs.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(AppLocalizations.of(context).contactsTitle,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
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
              Flexible(
                child: ValueListenableBuilder<List<OnionPeer>>(
                  valueListenable: OnionPairedPeers.peers,
                  builder: (_, allDevices, __) {
                    // One row per person, not per device.
                    final seen = <String>{};
                    final peers = [
                      for (final p in allDevices)
                        if (seen.add(p.username))
                          OnionPairedPeers.byUsername(p.username) ?? p,
                    ];
                    if (peers.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          AppLocalizations.of(context).contactsEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      itemCount: peers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final peer = peers[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(27),
                          onTap: () {
                            // Close every dialog (contacts + profile) and jump
                            // into the private chat with this contact.
                            Navigator.of(context)
                                .popUntil((r) => r is! PopupRoute);
                            NotificationService.openChat(peer.username);
                          },
                          child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(27),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.10),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: avatarVersion,
                                builder: (_, __, ___) => AvatarWidget(
                                  key: ValueKey('contact-avatar-${peer.username}'),
                                  username: peer.username,
                                  tokenProvider: avatarTokenProvider,
                                  avatarBaseUrl: serverBase,
                                  size: 40,
                                  editable: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(peer.username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(peer.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.6))),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 20, color: cs.error),
                                onPressed: () => _remove(context, peer),
                              ),
                            ],
                          ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
