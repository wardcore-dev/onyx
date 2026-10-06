// lib/widgets/peer_id_block.dart
//
// The "ID" line of a contact's profile card: their compact onion address
// (tap to copy the full one) plus a toggle that reveals a QR code of it, so
// the contact can be shared with a friend. Shows nothing for contacts that
// aren't paired.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../globals.dart' show rootScreenKey;
import '../l10n/app_localizations.dart';
import '../services/onion/onion_paired_peers.dart';
import '../utils/onion_names.dart';

class PeerIdBlock extends StatefulWidget {
  final String username;
  const PeerIdBlock({super.key, required this.username});

  @override
  State<PeerIdBlock> createState() => _PeerIdBlockState();
}

class _PeerIdBlockState extends State<PeerIdBlock> {
  bool _qr = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final peer = OnionPairedPeers.byUsername(widget.username);

    // Not a paired contact (removed, or not loaded yet): there's no address
    // to show, and the old server-era @username is just the raw key here.
    if (peer == null) return const SizedBox.shrink();

    final addr = peer.onionAddress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: addr));
            rootScreenKey.currentState?.showSnack(l.peerAddressCopied);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  compactAddress(addr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 14, color: cs.primary),
            ],
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => setState(() => _qr = !_qr),
          icon: Icon(_qr ? Icons.close_rounded : Icons.qr_code_2_rounded,
              size: 16),
          label: Text(_qr ? l.peerHideQr : l.peerShowQr),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
          ),
        ),
        if (_qr) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: addr,
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ],
    );
  }
}
