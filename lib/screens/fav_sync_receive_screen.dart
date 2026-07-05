// lib/screens/fav_sync_receive_screen.dart
//
// Receiver screen: shows a QR code that the sender scans.
// Displays detailed per-file progress and error list.
// After completion, merges received favourites into the app state.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../models/chat_message.dart';
import '../models/favorite_chat.dart';
import '../services/lan_fav_sync_service.dart';
import '../utils/wardlink_bubble_controller.dart';
import '../widgets/adaptive_glass_card.dart';

class FavSyncReceiveScreen extends StatefulWidget {
  const FavSyncReceiveScreen({super.key});

  @override
  State<FavSyncReceiveScreen> createState() => _FavSyncReceiveScreenState();
}

class _FavSyncReceiveScreenState extends State<FavSyncReceiveScreen> {
  LanFavSyncReceiverSession? _session;
  StreamSubscription<LanFavSyncEvent>? _sub;

  bool _starting = true;
  String? _fatalError;

  // Progress state
  String _statusText = 'Waiting for sender to scan QR code…';
  int _current = 0;
  int _total = 0;
  int _bytesTransferred = 0;
  int _fileBytes = 0;
  bool _done = false;

  // Per-file results: filename → (success, errorMsg)
  final List<({String filename, bool success, String? error})> _fileResults = [];
  bool _logExpanded = false;

  // On success
  LanFavSyncDone? _doneEvent;

  // Scan-sender-QR mode (mobile only)
  bool _scanningHandshake = false;
  bool _handshakeScanned = false;
  MobileScannerController? _handshakeScanCtrl;

  bool get _isMobile =>
      !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  late AppLocalizations _l;

  // Set to true before popping via minimize button so dispose() doesn't
  // cancel the stream subscription (the controller keeps it alive).
  bool _minimizing = false;

  // True when this dialog instance re-attached to an existing controller
  // session (opened after minimize tap on the bubble).
  bool _attachedToController = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l = AppLocalizations.of(context);
    if (_statusText.isEmpty) _statusText = _l.receiveFavoritesWaiting;
  }

  @override
  void initState() {
    super.initState();
    _statusText = '';
    // If a receive session is already active in the controller (user tapped
    // the bubble to reopen the dialog), attach to it instead of starting fresh.
    if (wardLinkBubbleController.isActive && !wardLinkBubbleController.isSend) {
      _attachToController();
    } else {
      _startServer();
    }
  }

  void _attachToController() {
    _attachedToController = true;
    _starting = false;
    _current = wardLinkBubbleController.current;
    _total = wardLinkBubbleController.total;
    _statusText = wardLinkBubbleController.statusText;
    _bytesTransferred = wardLinkBubbleController.bytesTransferred;
    _fileBytes = wardLinkBubbleController.fileBytes;
    _done = wardLinkBubbleController.phase == WardLinkBubblePhase.done;
    wardLinkBubbleController.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {
      _current = wardLinkBubbleController.current;
      _total = wardLinkBubbleController.total;
      _statusText = wardLinkBubbleController.statusText;
      _bytesTransferred = wardLinkBubbleController.bytesTransferred;
      _fileBytes = wardLinkBubbleController.fileBytes;
      _done = wardLinkBubbleController.phase == WardLinkBubblePhase.done;
    });
  }

  Future<void> _startServer() async {
    try {
      final session = await LanFavSyncService.startReceiver();
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
      // Register with global controller so the bubble can track this session.
      wardLinkBubbleController.beginReceive(session);
      _sub = session.events.listen(
        _onEvent,
        onError: (e) {
          if (mounted) setState(() => _fatalError = e.toString());
        },
        onDone: () {
          if (mounted && !_done) {
            setState(() {
              _done = true;
              _statusText = _l.receiveFavoritesComplete;
            });
          }
        },
      );
      setState(() => _starting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _fatalError = 'Could not start sync server: $e\n\n'
              'Make sure the app has local network permissions.';
        });
      }
    }
  }

  void _onEvent(LanFavSyncEvent event) {
    // Always forward to controller — this runs even after the dialog is
    // popped (minimized) since we don't cancel _sub in that case.
    wardLinkBubbleController.processEvent(event);

    // If minimized and transfer just completed, merge into app immediately —
    // the screen won't be around to call _applyAndClose().
    if (!mounted && event is LanFavSyncDone) {
      _mergeIntoApp(event.favorites, event.chats);
      return;
    }

    if (!mounted) return;
    setState(() {
      if (event is LanFavSyncStatus) {
        _statusText = event.message;
        _current = event.current;
        _total = event.total;
        _bytesTransferred = event.bytesTransferred;
        _fileBytes = event.fileBytes;
      } else if (event is LanFavSyncFileResult) {
        _fileResults.add((
          filename: event.filename,
          success: event.success,
          error: event.error,
        ));
      } else if (event is LanFavSyncDone) {
        _done = true;
        _doneEvent = event;
        final errs = event.fileErrors.length;
        _statusText = 'Received ${event.favoritesCount} chat'
            '${event.favoritesCount == 1 ? '' : 's'}'
            ', ${event.filesReceived} file'
            '${event.filesReceived == 1 ? '' : 's'}'
            '${errs > 0 ? ', $errs error${errs == 1 ? '' : 's'}' : ''}';
        _current = _total;
      } else if (event is LanFavSyncFatalError) {
        _fatalError = event.message;
        _done = true;
      }
    });
  }

  void _applyAndClose() {
    final ev = _doneEvent;
    if (ev == null) return;
    _mergeIntoApp(ev.favorites, ev.chats);
    Navigator.of(context).pop();
  }

  void _mergeIntoApp(
      List<FavoriteChat> favorites, Map<String, List<ChatMessage>> chats) {
    final root = rootScreenKey.currentState;
    if (root == null) return;
    root.importFavorites(favorites, chats);
  }

  void _minimize() {
    _minimizing = true;
    // Hand session ownership to the controller so it keeps the TCP server alive.
    if (_session != null) wardLinkBubbleController.takeReceiveSession(_session!);
    _session = null;
    wardLinkBubbleController.minimize();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (_attachedToController) {
      wardLinkBubbleController.removeListener(_onControllerUpdate);
    } else if (_minimizing) {
      // Leave _sub running — its _onEvent callback keeps forwarding events to
      // the controller even though this State is now unmounted.
      _sub = null;
      // _session is already null (handed to controller above).
    } else {
      _sub?.cancel();
      _session?.close();
      // Reset controller if we're closing normally (not minimizing).
      if (wardLinkBubbleController.isActive && !wardLinkBubbleController.isMinimized) {
        wardLinkBubbleController.reset();
      }
    }
    _handshakeScanCtrl?.dispose();
    super.dispose();
  }

  // ── Scan-sender-QR mode ────────────────────────────────────────────────────

  void _onHandshakeQrDetected(BarcodeCapture capture) {
    if (_handshakeScanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] != 'fav_sync_sender') return;
    } catch (_) {
      return;
    }
    _handshakeScanned = true;
    _handshakeScanCtrl?.dispose();
    setState(() => _scanningHandshake = false);
    _doHandshakeAck(raw);
  }

  Future<void> _doHandshakeAck(String senderQrJson) async {
    final session = _session;
    if (session == null) return;
    try {
      setState(() => _statusText = _l.receiveFavoritesConnecting);
      await LanFavSyncService.sendHandshakeAck(senderQrJson, session.qrJson);
      if (mounted) setState(() => _statusText = _l.receiveFavoritesConnected);
    } catch (e) {
      if (mounted) setState(() => _fatalError = 'Connection failed: $e');
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  void _cancelTransfer() {
    // Pop first to avoid visual glitch from controller notifyListeners()
    // firing during the dismiss animation.
    final sub = _sub;
    _sub = null;
    if (mounted) Navigator.of(context).pop();
    sub?.cancel();
    Future.delayed(const Duration(milliseconds: 300), () {
      wardLinkBubbleController.cancelTransfer();
    });
  }

  Widget _buildDialogTitleBar(ColorScheme cs) {
    final title = _scanningHandshake ? _l.receiveFavoritesScanSender : _l.receiveFavoritesTitle;
    // X button: minimizes when transfer is active, closes otherwise.
    final canMinimize = !_done && _fatalError == null && !_starting && !_scanningHandshake && _total > 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (_scanningHandshake)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _handshakeScanCtrl?.dispose();
                _handshakeScanCtrl = null;
                setState(() {
                  _scanningHandshake = false;
                  _handshakeScanned = false;
                });
              },
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: canMinimize ? _minimize : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (_scanningHandshake) {
      body = _buildHandshakeScanner(cs);
    } else if (_fatalError != null) {
      body = _buildError(cs);
    } else if (_starting) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_done) {
      body = _buildDone(cs);
    } else {
      body = _buildWaiting(cs);
    }

    // PopScope prevents the back-gesture/button from closing the dialog;
    // it minimizes instead while the transfer is active.
    final canMinimizeNow = !_done && _fatalError == null && !_starting && !_scanningHandshake && _total > 0;
    return PopScope(
      canPop: !canMinimizeNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDialogTitleBar(cs),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
              const SizedBox(height: 16),
              Text(
                'Sync failed',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: cs.error),
              ),
              const SizedBox(height: 12),
              Text(
                _fatalError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha:0.7), height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ],
          ),
        ),
      );

  Widget _buildWaiting(ColorScheme cs) {
    // When re-opened after minimize, _session is null — use QR from controller.
    final qrData = _session?.qrJson ?? wardLinkBubbleController.receiveQrJson ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // QR code card
        ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            return AdaptiveGlassCard(
              borderRadius: 20,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  children: [
                    Text(
                      _l.receiveFavoritesScanOnSender,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _l.receiveFavoritesInstruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha:0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha:0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1A1A1A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 14, color: cs.primary),
                        const SizedBox(height: 4),
                        Text(
                          _l.receiveFavoritesE2E,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Status + progress
        _buildStatusCard(cs),

        // Mobile: button to scan desktop's sender QR
        if (_isMobile) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                _handshakeScanCtrl = MobileScannerController(
                  detectionSpeed: DetectionSpeed.normal,
                  facing: CameraFacing.back,
                );
                setState(() {
                  _scanningHandshake = true;
                  _handshakeScanned = false;
                });
              },
              icon: const Icon(Icons.qr_code_scanner, size: 16),
              label: Text(_l.receiveFavoritesScanSender),
            ),
          ),
        ],

        // File results (populated as files arrive)
        if (_fileResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildFileResultsList(cs),
        ],

        // Show cancel only once the sender has actually started sending files.
        if (_total > 0) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            ),
            onPressed: _cancelTransfer,
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(_l.cancelTransfer),
          ),
        ],
      ],
    );
  }

  Widget _buildHandshakeScanner(ColorScheme cs) => Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _handshakeScanCtrl!,
                  onDetect: _onHandshakeQrDetected,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    color: Colors.black54,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(height: 6),
                        Text(
                          _l.receiveFavoritesScanHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _l.receiveFavoritesScanEncrypted,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  Widget _buildStatusCard(ColorScheme cs) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) => AdaptiveGlassCard(
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
                if (_total > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _total > 0 ? _current / _total : null,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_current / $_total files',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  // Per-file byte progress bar — shown only during active streaming.
                  if (_fileBytes > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _bytesTransferred / _fileBytes,
                        minHeight: 4,
                        color: cs.secondary,
                        backgroundColor:
                            cs.secondaryContainer.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_bytesTransferred * 100 ~/ _fileBytes}%  ·  '
                      '${_fmtBytes(_bytesTransferred)} / ${_fmtBytes(_fileBytes)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildDone(ColorScheme cs) {
    final ev = _doneEvent;
    final hasErrors = (ev?.fileErrors.isNotEmpty ?? false) ||
        _fileResults.any((r) => !r.success);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        // Success / partial icon
        Icon(
          hasErrors
              ? Icons.warning_amber_rounded
              : Icons.check_circle_outline_rounded,
          size: 64,
          color: hasErrors ? Colors.orange : cs.primary,
        ),
        const SizedBox(height: 12),
        Text(
          hasErrors ? 'Sync completed with errors' : 'Sync complete!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: hasErrors ? Colors.orange : cs.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: cs.onSurface.withValues(alpha:0.7), fontSize: 13, height: 1.4),
        ),

        const SizedBox(height: 24),

        // File results
        if (_fileResults.isNotEmpty) _buildFileResultsList(cs),

        if (_fatalError != null) ...[
          const SizedBox(height: 12),
          _buildErrorTile(cs, _fatalError!),
        ],

        const SizedBox(height: 24),

        // Action buttons
        if (ev != null)
          FilledButton.icon(
            onPressed: _applyAndClose,
            icon: const Icon(Icons.download_done_rounded),
            label: Text(
              ev.favoritesCount == 1
                  ? 'Add 1 chat to Favorites'
                  : 'Add ${ev.favoritesCount} chats to Favorites',
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildFileResultsList(ColorScheme cs) {
    return AdaptiveGlassCard(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _logExpanded = !_logExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'File transfer log (${_fileResults.length} file${_fileResults.length == 1 ? '' : 's'})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Icon(
                    _logExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (_logExpanded) ...[
            ..._fileResults.map((r) => _buildFileRow(cs, r)),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildFileRow(
    ColorScheme cs,
    ({String filename, bool success, String? error}) r,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.success
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                size: 16,
                color: r.success ? Colors.green : cs.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.filename,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (r.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                r.error!,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.error.withValues(alpha:0.8),
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorTile(ColorScheme cs, String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha:0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withValues(alpha:0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: cs.onSurface, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
