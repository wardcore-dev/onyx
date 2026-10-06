// lib/widgets/tor_circuit_dialog.dart
//
// Shows the Tor circuits the local tor daemon currently has built, so the
// user can see what their traffic to a given contact is actually routed
// through -- guard/middle/exit-style relay hops, by fingerprint and (when
// the relay's network-status entry could be looked up) advertised address.
// Onion-service traffic doesn't use a single simple 3-hop circuit like a
// regular exit connection, so this deliberately shows every circuit the
// daemon reports rather than trying to pick "the one" for this chat --
// there rarely are many at once in onion-only mode.
import 'package:flutter/material.dart';
import 'package:onyx_tor/onyx_tor.dart';

import '../services/onion/onion_identity.dart';
import '../services/onion/onion_paired_peers.dart';
import 'onyx_dialog.dart';
import '../l10n/app_localizations.dart';

void showTorCircuitDialog(BuildContext context, String otherUsername) {
  showOnyxDialog<void>(
    context: context,
    barrierLabel: 'circuit',
    builder: (ctx) => _TorCircuitDialog(otherUsername: otherUsername),
  );
}

class _TorCircuitDialog extends StatefulWidget {
  final String otherUsername;
  const _TorCircuitDialog({required this.otherUsername});

  @override
  State<_TorCircuitDialog> createState() => _TorCircuitDialogState();
}

class _TorCircuitDialogState extends State<_TorCircuitDialog> {
  List<TorCircuit>? _circuits;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Picks the one circuit that best represents "this chat"'s traffic, for
  /// the simple Tor-Browser-style view: the rendezvous/introduction circuit
  /// tied to this contact's onion address if we can match one, else the
  /// most relevant purpose available, else just the first built circuit --
  /// there usually isn't much choice in onion-only mode anyway.
  TorCircuit? _pickSimpleCircuit(List<TorCircuit> circuits) {
    if (circuits.isEmpty) return null;
    final peer = OnionPairedPeers.byUsername(widget.otherUsername);
    final peerId = peer?.onionAddress.replaceAll('.onion', '');
    if (peerId != null && peerId.isNotEmpty) {
      for (final c in circuits) {
        if (c.rendQuery == peerId) return c;
      }
    }
    for (final purpose in const [
      'HS_CLIENT_REND',
      'HS_SERVICE_REND',
      'HS_CLIENT_INTRO',
      'HS_SERVICE_INTRO',
    ]) {
      for (final c in circuits) {
        if (c.purpose == purpose && c.status == 'BUILT') return c;
      }
    }
    for (final c in circuits) {
      if (c.purpose == 'GENERAL' && c.status == 'BUILT') return c;
    }
    for (final c in circuits) {
      if (c.status == 'BUILT') return c;
    }
    return circuits.first;
  }

  Future<void> _load() async {
    setState(() {
      _circuits = null;
      _error = null;
    });
    try {
      final circuits = await OnionIdentity.plugin.getCircuits();
      if (!mounted) return;
      setState(() => _circuits = circuits);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return OnyxDialogShell(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.route_outlined, size: 20, color: cs.primary),
            ),
            title: Text(
              l.viewCircuitTitle,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            subtitle: Text(
              l.viewCircuitSubtitle,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            onClose: () => Navigator.of(context).pop(),
          ),
          SizedBox(
            height: 420,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: _buildStatus(cs, l) ?? _buildSimple(cs, l),
            ),
          ),
        ],
      ),
    );
  }

  /// Loading/error/empty states shared by both tabs -- returned instead of
  /// the TabBarView so a spinner or error doesn't have to be duplicated per
  /// tab. Null once there's a real (possibly empty-list) result to show.
  Widget? _buildStatus(ColorScheme cs, AppLocalizations l) {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!, style: TextStyle(fontSize: 13, color: cs.error)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
                padding: kOnyxDialogButtonPadding,
                shape: kOnyxDialogButtonShape),
            child: Text(l.retry),
          ),
        ],
      );
    }
    if (_circuits == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return null;
  }

  Widget _buildSimple(ColorScheme cs, AppLocalizations l) {
    final circuits = _circuits!;
    final c = circuits.isEmpty ? null : _pickSimpleCircuit(circuits);
    if (c == null) {
      return Center(
        child: Text(
          l.viewCircuitEmpty,
          style:
              TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
        ),
      );
    }
    return SingleChildScrollView(
      child: _CircuitCard(circuit: c, showHeader: false),
    );
  }
}

/// Regional-indicator flag emoji for a 2-letter ISO country code, the same
/// trick every "country code -> flag" tool uses: each letter maps 1:1 onto a
/// Unicode regional-indicator symbol, no image assets or lookup table needed.
String? _flagFor(String? countryCode) {
  if (countryCode == null || countryCode.length != 2) return null;
  final upper = countryCode.toUpperCase();
  const base = 0x1F1E6; // regional indicator 'A'
  final a = upper.codeUnitAt(0) - 0x41;
  final b = upper.codeUnitAt(1) - 0x41;
  if (a < 0 || a > 25 || b < 0 || b > 25) return null;
  return String.fromCharCodes([base + a, base + b]);
}

// A modest set of the countries relays most commonly report; anything else
// just falls back to showing the bare code, which is still meaningful.
const Map<String, String> _countryNamesRu = {
  'US': 'США', 'DE': 'Германия', 'FR': 'Франция', 'NL': 'Нидерланды',
  'GB': 'Великобритания', 'CH': 'Швейцария', 'SE': 'Швеция', 'RO': 'Румыния',
  'FI': 'Финляндия', 'CA': 'Канада', 'AT': 'Австрия', 'LU': 'Люксембург',
  'PL': 'Польша', 'RU': 'Россия', 'JP': 'Япония', 'SG': 'Сингапур',
  'AU': 'Австралия', 'IE': 'Ирландия', 'NO': 'Норвегия', 'DK': 'Дания',
  'CZ': 'Чехия', 'ES': 'Испания', 'IT': 'Италия', 'BG': 'Болгария',
  'UA': 'Украина', 'LT': 'Литва', 'LV': 'Латвия', 'EE': 'Эстония',
  'IN': 'Индия', 'BR': 'Бразилия', 'HK': 'Гонконг', 'MD': 'Молдова',
  'IS': 'Исландия', 'PT': 'Португалия', 'BE': 'Бельгия', 'GR': 'Греция',
  'HU': 'Венгрия', 'KR': 'Южная Корея', 'ZA': 'ЮАР',
};

String _countryLabel(TorRelayHop hop) {
  final code = hop.countryCode;
  if (code == null) return '';
  return _countryNamesRu[code] ?? code;
}

/// Role suffix shown after the country name for a hop, matching Tor
/// Browser's own circuit view ("Germany (guard)"): only the first hop (our
/// guard/entry) and, for onion-service circuits, the last hop (their
/// introduction/rendezvous point) get one -- middle hops show none.
String? _roleFor(TorCircuit circuit, int index, AppLocalizations l) {
  if (index == 0) return l.circuitRoleGuard;
  if (index == circuit.hops.length - 1) {
    switch (circuit.purpose) {
      case 'HS_CLIENT_INTRO':
      case 'HS_SERVICE_INTRO':
        return l.circuitRoleIntro;
      case 'HS_CLIENT_REND':
      case 'HS_SERVICE_REND':
        return l.circuitRoleRend;
    }
  }
  return null;
}

class _CircuitCard extends StatelessWidget {
  final TorCircuit circuit;
  final bool showHeader;
  const _CircuitCard({required this.circuit, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final built = circuit.status == 'BUILT';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: showHeader
          ? BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Icon(
                  built ? Icons.check_circle_outline : Icons.hourglass_empty,
                  size: 14,
                  color: built ? const Color(0xFF2ECC71) : Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  '${circuit.purpose} · ${circuit.status}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _NodeRow(label: l.circuitThisDevice, isDevice: true),
          _Connector(cs: cs),
          for (var i = 0; i < circuit.hops.length; i++) ...[
            _NodeRow(
              flag: _flagFor(circuit.hops[i].countryCode),
              label: _countryLabel(circuit.hops[i]).isNotEmpty
                  ? _countryLabel(circuit.hops[i])
                  : (circuit.hops[i].nickname ?? l.circuitUnknownRelay),
              role: _roleFor(circuit, i, l),
              detail: [
                if (showHeader && circuit.hops[i].nickname != null)
                  circuit.hops[i].nickname!,
                if (circuit.hops[i].address != null)
                  circuit.hops[i].address!,
              ].join(' · '),
            ),
            if (i != circuit.hops.length - 1) _Connector(cs: cs),
          ],
          if (circuit.rendQuery != null) ...[
            _Connector(cs: cs, label: l.circuitOnionRelay),
            _NodeRow(label: circuit.rendQuery!, monospace: true),
          ],
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final ColorScheme cs;
  final String? label;
  const _Connector({required this.cs, this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Row(
        children: [
          Container(
            width: 1,
            height: label == null ? 14 : 18,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(label!,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ],
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  final String label;
  final String? flag;
  final String? role;
  final String? detail;
  final bool isDevice;
  final bool monospace;
  const _NodeRow({
    required this.label,
    this.flag,
    this.role,
    this.detail,
    this.isDevice = false,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: isDevice ? 0.0 : 0.12),
            shape: BoxShape.circle,
            border: isDevice
                ? Border.all(color: cs.onSurface.withValues(alpha: 0.4))
                : null,
          ),
          child: flag != null
              ? Text(flag!, style: const TextStyle(fontSize: 14))
              : Icon(
                  isDevice ? Icons.smartphone_rounded : Icons.dns_rounded,
                  size: 13,
                  color: isDevice
                      ? cs.onSurface.withValues(alpha: 0.6)
                      : cs.primary,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: monospace ? 'monospace' : null,
                        color: cs.onSurface),
                    children: [
                      TextSpan(text: label),
                      if (role != null)
                        TextSpan(
                          text: ' ($role)',
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                    ],
                  ),
                ),
                if (detail != null && detail!.isNotEmpty)
                  Text(
                    detail!,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
