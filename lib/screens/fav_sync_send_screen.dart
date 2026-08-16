// lib/screens/fav_sync_send_screen.dart
//
// Sender screen: lets the user pick which favourite chats to send,
// then either scans the receiver's QR code (mobile) or shows its own
// handshake QR code (desktop) and streams the transfer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../dialogs/pin_lock_dialog.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_extra.dart';
import '../managers/lock_manager.dart';
import '../managers/settings_manager.dart';
import '../models/fav_folder.dart';
import '../models/favorite_chat.dart';
import '../services/lan_fav_sync_service.dart';
import '../utils/wardlink_bubble_controller.dart';
import '../widgets/adaptive_glass_card.dart';

class FavSyncSendScreen extends StatefulWidget {
  const FavSyncSendScreen({super.key});

  @override
  State<FavSyncSendScreen> createState() => _FavSyncSendScreenState();
}

class _FavSyncSendScreenState extends State<FavSyncSendScreen> {
  // ── Step 1: select chats ───────────────────────────────────────────────────
  late List<FavoriteChat> _allFavorites;
  late List<FavFolder> _favFolders;
  late List<String> _favTopOrder;
  final Set<String> _selectedIds = {};
  final Set<String> _expandedFolderIds = {};

  // ── Platform ───────────────────────────────────────────────────────────────
  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  // ── Step 2: scan QR (mobile) or show handshake QR (desktop) ───────────────
  bool _scanning = false;
  bool _qrScanned = false;
  MobileScannerController? _scanCtrl;

  // Desktop handshake
  LanFavSyncSenderHandshakeSession? _handshakeSession;

  // ── Step 3: transfer ───────────────────────────────────────────────────────
  bool _transferring = false;
  bool _done = false;
  String? _fatalError;
  String _statusText = '';
  int _current = 0;
  int _total = 0;
  int _bytesTransferred = 0;
  int _fileBytes = 0;
  StreamSubscription<LanFavSyncEvent>? _sub;
  final List<({String filename, bool success, String? error})> _fileResults = [];
  bool _logExpanded = false;

  // Set true before minimize-pop so dispose() leaves _sub alive.
  bool _minimizing = false;

  // True when this instance re-attached to an existing controller session
  // (dialog opened after tapping the bubble).
  bool _attachedToController = false;

  @override
  void initState() {
    super.initState();
    // If a send session is already active (user tapped bubble to reopen),
    // attach to the controller state instead of starting a fresh selection.
    if (wardLinkBubbleController.isActive && wardLinkBubbleController.isSend) {
      _attachToController();
      return;
    }
    final root = rootScreenKey.currentState;
    _allFavorites = List.from(root?.favorites ?? const []);
    _favFolders = List.from(root?.favFolders ?? const []);
    _favTopOrder = List.from(root?.favTopOrder ?? const []);
    if (!_isDesktop) {
      _scanCtrl = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  void _attachToController() {
    _attachedToController = true;
    _transferring = wardLinkBubbleController.phase == WardLinkBubblePhase.transferring;
    _done = wardLinkBubbleController.phase == WardLinkBubblePhase.done;
    _current = wardLinkBubbleController.current;
    _total = wardLinkBubbleController.total;
    _statusText = wardLinkBubbleController.statusText;
    _bytesTransferred = wardLinkBubbleController.bytesTransferred;
    _fileBytes = wardLinkBubbleController.fileBytes;
    wardLinkBubbleController.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {
      _transferring = wardLinkBubbleController.phase == WardLinkBubblePhase.transferring;
      _done = wardLinkBubbleController.phase == WardLinkBubblePhase.done;
      _current = wardLinkBubbleController.current;
      _total = wardLinkBubbleController.total;
      _statusText = wardLinkBubbleController.statusText;
      _bytesTransferred = wardLinkBubbleController.bytesTransferred;
      _fileBytes = wardLinkBubbleController.fileBytes;
    });
  }

  void _minimize() {
    _minimizing = true;
    // Transfer ownership to controller so dispose() won't close/cancel them.
    if (_sub != null) {
      wardLinkBubbleController.takeSendSub(_sub!);
      _sub = null;
    }
    if (_handshakeSession != null) {
      wardLinkBubbleController.takeSenderHandshakeSession(_handshakeSession!);
      _handshakeSession = null;
    }
    wardLinkBubbleController.minimize();
    Navigator.of(context).pop();
  }

  void _cancelTransfer() {
    final sub = _sub;
    _sub = null;
    if (mounted) Navigator.of(context).pop();
    sub?.cancel();
    Future.delayed(const Duration(milliseconds: 300), () {
      wardLinkBubbleController.cancelTransfer();
    });
  }

  @override
  void dispose() {
    _scanCtrl?.dispose();
    if (_attachedToController) {
      wardLinkBubbleController.removeListener(_onControllerUpdate);
    } else if (_minimizing) {
      // _sub already handed to controller above — don't cancel.
    } else {
      _sub?.cancel();
      if (wardLinkBubbleController.isActive && !wardLinkBubbleController.isMinimized) {
        wardLinkBubbleController.reset();
      }
    }
    // _handshakeSession is null when minimizing (handed to controller above).
    if (!_minimizing) _handshakeSession?.close();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onScanPressed() {
    if (_selectedIds.isEmpty) return;
    setState(() => _scanning = true);
    if (_isDesktop) _startHandshake();
  }

  Future<void> _startHandshake() async {
    try {
      final session = await LanFavSyncService.startSenderHandshake(
        _selectedIds.toList(),
      );
      if (!mounted) {
        session.close();
        return;
      }
      setState(() => _handshakeSession = session);

      _sub = session.events.listen(
        (event) {
          if (mounted && _scanning) {
            wardLinkBubbleController.beginSend();
            setState(() {
              _scanning = false;
              _transferring = true;
            });
          }
          _onEvent(event);
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _fatalError = e.toString();
              _scanning = false;
              _done = true;
              _transferring = false;
            });
          }
        },
        onDone: () {
          if (mounted && !_done) {
            setState(() {
              _done = true;
              _transferring = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _fatalError = e.toString();
          _scanning = false;
        });
      }
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_qrScanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    // Validate it's a fav_sync QR
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] != 'fav_sync') return;
    } catch (_) {
      return;
    }

    _qrScanned = true;
    _scanCtrl?.dispose();
    _startTransfer(raw);
  }

  void _startTransfer(String qrJson) {
    wardLinkBubbleController.beginSend();
    setState(() {
      _scanning = false;
      _transferring = true;
      _statusText = 'Connecting to receiver…';
    });

    final stream = LanFavSyncService.sendFavorites(
      qrJson: qrJson,
      favIds: _selectedIds.toList(),
    );

    _sub = stream.listen(
      _onEvent,
      onError: (e) {
        if (mounted) {
          setState(() {
            _fatalError = e.toString();
            _done = true;
            _transferring = false;
          });
        }
      },
      onDone: () {
        if (mounted && !_done) {
          setState(() {
            _done = true;
            _transferring = false;
          });
        }
      },
    );
  }

  void _onEvent(LanFavSyncEvent event) {
    // Forward to controller before mounted check so the bubble stays updated
    // even after the dialog has been minimized and this State unmounted.
    wardLinkBubbleController.processEvent(event);

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
        _transferring = false;
        final errs = _fileResults.where((r) => !r.success).length;
        _statusText = 'Sent ${event.favoritesCount} chat'
            '${event.favoritesCount == 1 ? '' : 's'}'
            ', ${event.filesReceived} file'
            '${event.filesReceived == 1 ? '' : 's'}'
            '${errs > 0 ? ', $errs error${errs == 1 ? '' : 's'}' : ''}';
        _current = _total;
      } else if (event is LanFavSyncFatalError) {
        _fatalError = event.message;
        _done = true;
        _transferring = false;
      }
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (_scanning) {
      body = _isDesktop ? _buildDesktopHandshakeQr(cs) : _buildScanner(cs);
    } else if (_transferring || _done || _fatalError != null) {
      body = _buildProgress(cs);
    } else {
      body = _buildSelection(cs);
    }

    final canMinimizeNow = _transferring && !_done && _fatalError == null && _total > 0;
    return PopScope(
      canPop: !canMinimizeNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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

  Widget _buildDialogTitleBar(ColorScheme cs) {
    final l = AppLocalizations.of(context);
    final title = _scanning
        ? (_isDesktop ? l.sendFavoritesShowQrToReceiver : l.sendFavoritesScanReceiver)
        : _transferring || _done
            ? l.sendFavoritesSending
            : l.sendFavoritesTitle;
    final canMinimize = _transferring && !_done && _fatalError == null && _total > 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          if (_scanning)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _sub?.cancel();
                _sub = null;
                _handshakeSession?.close();
                _handshakeSession = null;
                setState(() {
                  _scanning = false;
                  _qrScanned = false;
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

  // ── Step 1: chat selection ─────────────────────────────────────────────────

  Widget _buildSelection(ColorScheme cs) {
    final hasChats = _allFavorites.isNotEmpty;
    final allChats = rootScreenKey.currentState?.chats ?? {};

    // Build ordered list of widgets representing top-level items + folder children
    List<Widget> chatItems = [];
    if (hasChats) {
      // Select-all header
      chatItems.add(CheckboxListTile(
        value: _selectedIds.length == _allFavorites.length,
        tristate: _selectedIds.isNotEmpty &&
            _selectedIds.length < _allFavorites.length,
        onChanged: (_) {
          setState(() {
            if (_selectedIds.length == _allFavorites.length) {
              _selectedIds.clear();
            } else {
              _selectedIds.addAll(_allFavorites.map((f) => f.id));
            }
          });
        },
        title: Text(
          AppLocalizations.of(context).allChatsCount(_allFavorites.length),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ));
      chatItems.add(const Divider(height: 1, indent: 16, endIndent: 16));

      final favMap = {for (final f in _allFavorites) f.id: f};
      final folderMap = {for (final f in _favFolders) f.id: f};
      final shownFolderIds = <String>{};
      final shownChatIds = <String>{};

      // Walk favTopOrder in user-defined order
      for (final itemId in _favTopOrder) {
        final folder = folderMap[itemId];
        if (folder != null) {
          chatItems.addAll(_buildFolderTile(cs, folder, favMap, allChats));
          shownFolderIds.add(folder.id);
        } else {
          final fav = favMap[itemId];
          if (fav != null) {
            final msgs = allChats['fav:${fav.id}'] ?? [];
            chatItems.add(_buildChatCheckbox(cs, fav, msgs));
            shownChatIds.add(fav.id);
          }
        }
      }

      // Folders not present in favTopOrder (e.g. created before order was persisted)
      for (final folder in _favFolders) {
        if (shownFolderIds.contains(folder.id)) continue;
        chatItems.addAll(_buildFolderTile(cs, folder, favMap, allChats));
        shownFolderIds.add(folder.id);
      }

      // Unfoldered chats not yet shown (safety fallback)
      final inFolders = _favFolders.expand((f) => f.chatIds).toSet();
      for (final fav in _allFavorites) {
        if (shownChatIds.contains(fav.id)) continue;
        if (inFolders.contains(fav.id)) continue;
        final msgs = allChats['fav:${fav.id}'] ?? [];
        chatItems.add(_buildChatCheckbox(cs, fav, msgs));
      }
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              AdaptiveGlassCard(
                borderRadius: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).sendFavoritesSelectTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isDesktop
                            ? AppLocalizations.of(context).sendFavoritesHintDesktop
                            : AppLocalizations.of(context).sendFavoritesHintMobile,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!hasChats)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    AppLocalizations.of(context).sendFavoritesNoFavs,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                )
              else
                AdaptiveGlassCard(
                  borderRadius: 16,
                  child: Column(children: chatItems),
                ),
            ],
          ),
        ),
        _buildBottomBar(cs),
      ],
    );
  }

  List<Widget> _buildFolderTile(
    ColorScheme cs,
    FavFolder folder,
    Map<String, FavoriteChat> favMap,
    Map<String, List> allChats,
  ) {
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final folderChats = folder.chatIds
        .map((id) => favMap[id])
        .whereType<FavoriteChat>()
        .toList();
    final selectedInFolder =
        folderChats.where((f) => _selectedIds.contains(f.id)).length;

    final result = <Widget>[
      ListTile(
        leading: folder.avatarPath != null &&
                File(folder.avatarPath!).existsSync()
            ? CircleAvatar(
                radius: 18,
                backgroundImage: FileImage(File(folder.avatarPath!)))
            : CircleAvatar(
                radius: 18,
                backgroundColor: cs.surfaceContainerHighest,
                child:
                    Icon(Icons.folder_rounded, size: 18, color: cs.primary)),
        title: Row(
          children: [
            if (LockManager.isLocked('fav_folder_${folder.id}')) ...[
              Icon(Icons.lock_rounded,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.45)),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(folder.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
        subtitle: Text(
          selectedInFolder > 0
              ? '$selectedInFolder/${folderChats.length} selected'
              : '${folderChats.length} chat${folderChats.length == 1 ? '' : 's'}',
          style: TextStyle(
              fontSize: 11,
              color: selectedInFolder > 0
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.5)),
        ),
        trailing: Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
        onTap: () async {
          if (!isExpanded) {
            final folderLockId = 'fav_folder_${folder.id}';
            if (LockManager.isLocked(folderLockId)) {
              final ok = await showPinDialog(
                  context, PinDialogMode.verify, folderLockId);
              if (!ok) return;
            }
          }
          setState(() {
            if (isExpanded) {
              _expandedFolderIds.remove(folder.id);
            } else {
              _expandedFolderIds.add(folder.id);
            }
          });
        },
      ),
    ];

    if (isExpanded) {
      for (final fav in folderChats) {
        final msgs = allChats['fav:${fav.id}'] ?? [];
        result.add(_buildChatCheckbox(cs, fav, msgs, indent: true));
      }
    }

    return result;
  }

  Widget _buildChatCheckbox(
    ColorScheme cs,
    FavoriteChat fav,
    List msgs, {
    bool indent = false,
  }) {
    final lockId = 'fav_${fav.id}';
    final isLocked = LockManager.isLocked(lockId);
    return CheckboxListTile(
      contentPadding: EdgeInsets.only(
          left: indent ? 32.0 : 16.0, right: 16.0),
      value: _selectedIds.contains(fav.id),
      onChanged: (_) async {
        if (!_selectedIds.contains(fav.id) && isLocked) {
          final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
          if (!ok) return;
        }
        setState(() {
          if (_selectedIds.contains(fav.id)) {
            _selectedIds.remove(fav.id);
          } else {
            _selectedIds.add(fav.id);
          }
        });
      },
      title: Row(
        children: [
          if (isLocked) ...[
            Icon(Icons.lock_rounded,
                size: 13, color: cs.onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              fav.title,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${msgs.length} message${msgs.length == 1 ? '' : 's'}',
        style: TextStyle(
            fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
      ),
      secondary: _buildFavAvatar(cs, fav),
    );
  }

  Widget _buildFavAvatar(ColorScheme cs, FavoriteChat fav) {
    final path = fav.avatarPath;
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(File(path)),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: cs.surfaceContainerHighest,
      child: Icon(Icons.bookmark, size: 16, color: cs.primary),
    );
  }

  Widget _buildBottomBar(ColorScheme cs) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.9),
          border: Border(
              top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedIds.isEmpty
                    ? AppLocalizations.of(context).sendFavoritesSelectAtLeastOne
                    : AppLocalizations.of(context).chatsSelected(_selectedIds.length),
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _selectedIds.isEmpty ? null : _onScanPressed,
              icon: Icon(
                _isDesktop ? Icons.qr_code : Icons.qr_code_scanner,
                size: 18,
              ),
              label: Text(_isDesktop ? AppLocalizations.of(context).sendFavoritesShowQrBtn : AppLocalizations.of(context).sendFavoritesScanQrBtn),
            ),
          ],
        ),
      );

  // ── Step 2a: desktop — show handshake QR ───────────────────────────────────

  Widget _buildDesktopHandshakeQr(ColorScheme cs) {
    final qrJson = _handshakeSession?.qrJson;

    if (qrJson == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) => AdaptiveGlassCard(
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Show to receiver device',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open Favorites on the phone → Sync → Receive, then scan this code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
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
                          color: cs.shadow.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: qrJson,
                      version: QrVersions.auto,
                      size: 220,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 14, color: cs.primary),
                      const SizedBox(width: 5),
                      Text(
                        'End-to-end encrypted · local network only',
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
          ),
        ),
        const SizedBox(height: 16),
        AdaptiveGlassCard(
          borderRadius: 16,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Waiting for phone to scan QR code…',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2b: mobile — QR scanner ───────────────────────────────────────────

  Widget _buildScanner(ColorScheme cs) => Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scanCtrl!,
                  onDetect: _onQrDetected,
                ),
                // Corner overlay hint
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
                          AppLocalizations.of(context).sendFavoritesScanHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).receiveFavoritesScanEncrypted,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
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

  // ── Step 3: progress / done ────────────────────────────────────────────────

  Widget _buildProgress(ColorScheme cs) {
    final hasErrors = _fileResults.any((r) => !r.success);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        // Icon
        if (_done) ...[
          Icon(
            _fatalError != null
                ? Icons.error_outline_rounded
                : hasErrors
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
            size: 64,
            color: _fatalError != null
                ? cs.error
                : hasErrors
                    ? Colors.orange
                    : cs.primary,
          ),
          const SizedBox(height: 12),
          Text(
            _fatalError != null
                ? 'Transfer failed'
                : hasErrors
                    ? 'Sent with errors'
                    : 'Sent successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _fatalError != null
                  ? cs.error
                  : hasErrors
                      ? Colors.orange
                      : cs.primary,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Status / progress card
        AdaptiveGlassCard(
          borderRadius: 16,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!_done)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Icon(
                        _fatalError != null
                            ? Icons.error_outline_rounded
                            : Icons.check_rounded,
                        size: 18,
                        color: _fatalError != null ? cs.error : cs.primary,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _fatalError ?? _statusText,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: _fatalError != null ? cs.error : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_total > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _done ? 1.0 : (_total > 0 ? _current / _total : null),
                      minHeight: 5,
                      color: _fatalError != null ? cs.error : null,
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
                  if (_fileBytes > 0 && !_done) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _bytesTransferred / _fileBytes,
                        minHeight: 4,
                        color: cs.secondary,
                        backgroundColor: cs.secondaryContainer.withValues(alpha: 0.4),
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

        // File transfer log
        if (_fileResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildFileResultsList(cs),
        ],

        const SizedBox(height: 20),
        if (!_done && _total > 0) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            ),
            onPressed: _cancelTransfer,
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(AppLocalizations.of(context).cancelTransfer),
          ),
        ] else if (_done)
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).close),
          ),
      ],
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  Widget _buildFileResultsList(ColorScheme cs) => AdaptiveGlassCard(
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
              ..._fileResults.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 5),
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
                                color: cs.error.withValues(alpha: 0.8),
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
            ],
          ],
        ),
      );
}
