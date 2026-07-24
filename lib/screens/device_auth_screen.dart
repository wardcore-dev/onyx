// lib/screens/device_auth_screen.dart
//
// Unified device-linking dialog — two tabs:
//
//  [QR]   — this device shows a QR code someone else scans:
//             logged-in  → qr_grant  (grants session to scanner)
//             logged-out → qr_auth   (receives session from scanner)
//
//  [Scan] — this device receives/sends authorization:
//             mobile     → camera; auto-detects qr_auth & qr_grant
//             desktop    → shows qr_auth QR (no camera; receives session)
//
// Default tab: desktop → QR, mobile → Scan.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../globals.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import '../services/qr_lan_auth_service.dart';

enum _Step { loading, ready, success, failed }

class DeviceAuthScreen extends StatefulWidget {
  final String? currentUsername;
  final Future<bool> Function({
    required String username,
    required String token,
    required String uin,
    required bool isPrimary,
  }) onQrLogin;

  const DeviceAuthScreen({
    super.key,
    required this.currentUsername,
    required this.onQrLogin,
  });

  @override
  State<DeviceAuthScreen> createState() => _DeviceAuthScreenState();
}

class _DeviceAuthScreenState extends State<DeviceAuthScreen> {
  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  bool get _isLoggedIn => widget.currentUsername != null;

  late int _tabIndex; // 0 = QR, 1 = Scan

  _Step _step = _Step.loading;
  String? _errorDetail;

  QrAuthSession? _authSession;
  QrGrantSession? _grantSession;
  StreamSubscription? _sub;

  MobileScannerController? _scanCtrl;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    // Unauthenticated users can only scan — force Scan tab regardless of platform
    _tabIndex = (!_isLoggedIn || !_isDesktop) ? 1 : 0;
    _initTab();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  Future<void> _cleanup() async {
    await _sub?.cancel();
    _sub = null;
    if (_authSession != null) {
      await _authSession!.close();
      _authSession = null;
    }
    if (_grantSession != null) {
      await _grantSession!.close();
      _grantSession = null;
    }
    _scanCtrl?.dispose();
    _scanCtrl = null;
    _handling = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSession?.close();
    _grantSession?.close();
    _scanCtrl?.dispose();
    super.dispose();
  }

  // ── Tab init ─────────────────────────────────────────────────────────────────

  Future<void> _initTab() async {
    if (_tabIndex == 0) {
      // QR tab: logged-in → grant, logged-out → auth
      if (_isLoggedIn) {
        await _startGrantServer();
      } else {
        await _startAuthServer();
      }
    } else {
      // Scan tab
      if (_isDesktop) {
        // Desktop has no camera → show qr_auth QR (receives session)
        await _startAuthServer();
      } else {
        _startMobileScanner();
      }
    }
  }

  // ── QR auth server (this device receives a session) ──────────────────────────

  Future<void> _startAuthServer() async {
    try {
      final session = await QrLanAuthService.startAuthServer();
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _authSession = session;
        _step = _Step.ready;
      });
      _sub = session.stream.listen(
        (creds) async {
          final ok = await widget.onQrLogin(
            username: creds.username,
            token: creds.token,
            uin: creds.uin,
            isPrimary: creds.isPrimary,
          );
          if (!mounted) return;
          setState(() => _step = ok ? _Step.success : _Step.failed);
          if (ok) {
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.of(context).pop(true);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _errorDetail = e.toString();
              _step = _Step.failed;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorDetail = e.toString();
          _step = _Step.failed;
        });
      }
    }
  }

  // ── QR grant server (this device grants a session to the scanner) ─────────────

  Future<void> _startGrantServer() async {
    final token = await AccountManager.getToken(widget.currentUsername!);
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _errorDetail = 'No active session';
        _step = _Step.failed;
      });
      return;
    }
    try {
      final session = await QrLanAuthService.startGrantServer(
        token: token,
        serverBase: serverBase,
      );
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _grantSession = session;
        _step = _Step.ready;
      });
      _sub = session.stream.listen(
        (_) {
          if (!mounted) return;
          setState(() => _step = _Step.success);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _errorDetail = e.toString();
              _step = _Step.failed;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorDetail = e.toString();
          _step = _Step.failed;
        });
      }
    }
  }

  // ── Mobile scanner ───────────────────────────────────────────────────────────

  void _startMobileScanner() {
    _scanCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() => _step = _Step.ready);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = json['type'] as String?;
    if (type == 'qr_grant') {
      _handling = true;
      _handleReceiveGrant(raw);
    } else if (type == 'qr_auth' && _isLoggedIn) {
      _handling = true;
      _handleSendAuth(raw);
    }
  }

  Future<void> _handleReceiveGrant(String qrJson) async {
    setState(() => _step = _Step.loading);
    final creds =
        await QrLanAuthService.receiveGrantedSession(qrJson: qrJson);
    if (!mounted) return;
    if (creds == null) {
      setState(() {
        _step = _Step.failed;
        _handling = false;
      });
      return;
    }
    Navigator.of(context).pop(true);
    widget.onQrLogin(
      username: creds.username,
      token: creds.token,
      uin: creds.uin,
      isPrimary: creds.isPrimary,
    );
  }

  Future<void> _handleSendAuth(String qrJson) async {
    setState(() => _step = _Step.loading);
    final token = await AccountManager.getToken(widget.currentUsername!);
    if (!mounted) return;
    if (token == null) {
      setState(() {
        _errorDetail = 'No active session';
        _step = _Step.failed;
        _handling = false;
      });
      return;
    }
    final error = await QrLanAuthService.sendCredentials(
      qrJson: qrJson,
      token: token,
      serverBase: serverBase,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorDetail = error;
        _step = _Step.failed;
        _handling = false;
      });
    }
  }

  // ── Tab switching ────────────────────────────────────────────────────────────

  Future<void> _switchTab(int index) async {
    if (index == _tabIndex) return;
    await _cleanup();
    if (!mounted) return;
    setState(() {
      _tabIndex = index;
      _step = _Step.loading;
      _errorDetail = null;
      _handling = false;
    });
    await _initTab();
  }

  Future<void> _retry() async {
    await _cleanup();
    if (!mounted) return;
    setState(() {
      _step = _Step.loading;
      _errorDetail = null;
      _handling = false;
    });
    await _initTab();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = lookupAppLocalizations(SettingsManager.appLocale.value);
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(l, cs),
            if (_isLoggedIn) _buildTabBar(l, cs),
            if (_isLoggedIn) const SizedBox(height: 4),
            _buildLanNote(l, cs),
            _buildBody(l, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
      child: Row(
        children: [
          Icon(Icons.devices_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.deviceAuthTitle,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: l.close,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              index: 0,
              icon: Icons.qr_code_2,
              label: l.deviceAuthTabQr,
              cs: cs,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tabButton(
              index: 1,
              icon: _isDesktop ? Icons.qr_code_2 : Icons.photo_camera_rounded,
              label: l.deviceAuthTabScan,
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String label,
    required ColorScheme cs,
  }) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => _switchTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.45)
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body states ──────────────────────────────────────────────────────────────

  Widget _buildBody(AppLocalizations l, ColorScheme cs) {
    switch (_step) {
      case _Step.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        );

      case _Step.success:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(
                  _isLoggedIn
                      ? l.authorizeDeviceSuccess
                      : l.qrAuthSuccess,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case _Step.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: cs.error, size: 64),
                const SizedBox(height: 16),
                Text(
                  _isLoggedIn
                      ? l.authorizeDeviceFailed
                      : l.qrAuthFailed,
                  style: TextStyle(fontSize: 16, color: cs.error),
                  textAlign: TextAlign.center,
                ),
                if (_errorDetail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorDetail!,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l.ok),
                ),
              ],
            ),
          ),
        );

      case _Step.ready:
        if (_tabIndex == 1 && !_isDesktop) {
          return _buildMobileScannerView(l, cs);
        }
        return _buildQrView(l, cs);
    }
  }

  // ── QR view (both tabs on desktop, QR tab on mobile) ─────────────────────────

  Widget _buildQrView(AppLocalizations l, ColorScheme cs) {
    final qrData = _authSession?.qrJson ?? _grantSession?.qrJson ?? '';
    final hint = _tabIndex == 0
        ? (_isLoggedIn ? l.grantDeviceSubtitle : l.qrAuthWaitingSubtitle)
        : l.qrAuthWaitingSubtitle; // desktop Scan tab = qr_auth

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.65),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _encryptedBadge(cs, l),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Mobile camera view ───────────────────────────────────────────────────────

  Widget _buildMobileScannerView(AppLocalizations l, ColorScheme cs) {
    // If not logged in: scanning for qr_grant (receive session from authorized device)
    // If logged in: scanning for qr_auth (send session to new device)
    // Hint reflects both possibilities
    final hint = _isLoggedIn
        ? l.authorizeDeviceScanHint
        : l.scanFromPcHint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _scanCtrl!,
                onDetect: _onDetect,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            children: [
              Text(
                hint,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              _encryptedBadge(cs, l),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanNote(AppLocalizations l, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.wifi, size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.deviceAuthLanNote,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encryptedBadge(ColorScheme cs, AppLocalizations l) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline,
            size: 12, color: cs.primary.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          l.qrAuthEncryptedNote,
          style: TextStyle(
              fontSize: 11, color: cs.primary.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
