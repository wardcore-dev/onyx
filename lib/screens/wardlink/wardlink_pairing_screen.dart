// lib/screens/wardlink/wardlink_pairing_screen.dart
//
// Pairs this device with another of the user's devices for WardLink sync.
// One scan establishes mutual trust: the scanning device pins the shown
// device, then notifies it over the LAN so it trusts back (see
// WardLinkSyncService.completePairingFromQr / _handlePair).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../managers/account_manager.dart';
import '../../managers/settings_manager.dart';
import '../../services/wardlink/wardlink_sync_service.dart';
import '../../widgets/adaptive_glass_card.dart';

class WardLinkPairingScreen extends StatefulWidget {
  const WardLinkPairingScreen({super.key, this.startInScanMode = false});

  final bool startInScanMode;

  @override
  State<WardLinkPairingScreen> createState() => _WardLinkPairingScreenState();
}

class _WardLinkPairingScreenState extends State<WardLinkPairingScreen> {
  bool get _isMobile =>
      !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  String? _username;
  String? _qrJson;
  bool _scanning = false;
  bool _handled = false;
  bool _busy = false;
  String? _error;
  MobileScannerController? _scanCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.startInScanMode) {
      _startScan();
    }
    _prepare();
  }

  Future<void> _prepare() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) {
      if (mounted) setState(() => _error = 'Not logged in');
      return;
    }
    // Ensure the daemon is up so the scanning device can complete pairing.
    await WardLinkSyncService.instance.start(username);
    if (mounted) setState(() => _username = username);
    // Only build QR when not in scan-only mode.
    if (!widget.startInScanMode) {
      final qr = await WardLinkSyncService.instance.pairingQrJson(username);
      if (!mounted) return;
      setState(() => _qrJson = qr);
    }
  }

  @override
  void dispose() {
    _scanCtrl?.dispose();
    super.dispose();
  }

  void _startScan() {
    _scanCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _scanning = true;
      _handled = false;
      _error = null;
    });
  }

  void _stopScan() {
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() => _scanning = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _username == null) return;
    if (!raw.contains('wardlink_pair')) return;
    _handled = true;
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() {
      _scanning = false;
      _busy = true;
    });

    final err =
        await WardLinkSyncService.instance.completePairingFromQr(raw, _username!);
    if (!mounted) return;
    setState(() => _busy = false);

    final l = AppLocalizations.of(context);
    if (err == null) {
      _showSnack(l.wardLinkPairedOk);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = '${l.wardLinkPairFailed}: $err');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final brightness = SettingsManager.elementBrightness.value;
    final opacity = SettingsManager.elementOpacity.value;
    final bg = SettingsManager.getElementColor(cs.surfaceContainerHighest, brightness)
        .withValues(alpha: opacity);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          text,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_scanning ? l.wardLinkScanCode : l.wardLinkPairTitle),
        // In scan-only mode the OS back button pops the route; otherwise
        // a custom back button stops scanning and returns to the QR view.
        leading: _scanning && !widget.startInScanMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _stopScan,
              )
            : null,
      ),
      body: _scanning ? _buildScanner(cs, l) : _buildShow(cs, l),
    );
  }

  Widget _buildScanner(ColorScheme cs, AppLocalizations l) => Stack(
        children: [
          MobileScanner(controller: _scanCtrl!, onDetect: _onDetect),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              color: Colors.black54,
              child: Text(
                l.wardLinkScanInstruction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      );

  Widget _buildShow(ColorScheme cs, AppLocalizations l) {
    if (_error != null && _qrJson == null) {
      return Center(child: Text(_error!));
    }
    if (_qrJson == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AdaptiveGlassCard(
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Text(
                  l.wardLinkShowInstruction,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: _qrJson!,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1A1A1A)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l.wardLinkE2E,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.error, fontSize: 13),
          ),
        ],
        if (_isMobile) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _startScan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(l.wardLinkScanCode),
          ),
        ],
      ],
    );
  }
}
