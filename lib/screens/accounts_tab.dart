// lib/screens/accounts_tab.dart
import 'dart:async';
import '../widgets/onyx_dialog.dart';
import 'package:ONYX/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/app_themes.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:convert/convert.dart';
import 'dart:convert';
import 'dart:math';
import '../managers/account_manager.dart';
import '../managers/decoy_manager.dart';
import 'decoy_setup_screen.dart' show DecoyAvatarPreview;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/auth_dialog.dart';
import '../screens/device_auth_screen.dart';
import '../globals.dart';
import '../widgets/avatar_widget.dart';
import '../utils/global_log_collector.dart';
import '../l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import '../widgets/adaptive_glass_card.dart';
import '../services/onion/onion_identity.dart';
import '../services/onion/onion_transport_service.dart';
import '../widgets/identity_onboarding_dialog.dart';
import '../utils/app_lock_gate.dart';
import '../widgets/paired_contacts_card.dart';

class AccountsTab extends StatefulWidget {
  final String? currentUsername;
  final String? currentUin;
  final String? identityPubFp;
  final Future<bool> Function(String, String) onLogin;
  final Future<String?> Function(String, String) onRegister;
  final Future<bool> Function({
    required String username,
    required String token,
    required String uin,
    required bool isPrimary,
  }) onQrLogin;
  final Future<void> Function(String) onSwitchAccount;
  final Future<void> Function(String) onDeleteAccount;
  final List<String> logs;
  final AppTheme currentTheme;
  // Re-fetches display_name/uin from the server for the current account.
  // Called on tab open so a numeric id changed directly in the DB doesn't
  // stay stuck at a stale cached value.
  final VoidCallback? onRefreshProfile;

  const AccountsTab({
    Key? key,
    required this.currentUsername,
    this.currentUin,
    required this.identityPubFp,
    required this.onLogin,
    required this.onRegister,
    required this.onQrLogin,
    required this.onSwitchAccount,
    required this.onDeleteAccount,
    required this.logs,
    required this.currentTheme,
    this.onRefreshProfile,
  }) : super(key: key);

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  List<String> _accounts = [];
  Map<String, String?> _pubFingerprints = {};

  Map<String, String?> _displayNames = {};

  Map<String, DateTime?> _lastUsed = {};
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isVisible = false;

  Future<void> _refreshMetaAndSort() async {
    final meta = await AccountManager.getAccountsMeta();
    final displayNames = <String, String?>{};
    final lastUsed = <String, DateTime?>{};
    for (final username in _accounts) {
      final m = meta[username];
      if (m != null) {
        final dn = m['displayName'] as String?;
        displayNames[username] =
            (dn != null && dn.isNotEmpty && dn != username) ? dn : null;
        final tsStr = m['lastUsed'] as String?;
        if (tsStr != null) {
          try {
            lastUsed[username] = DateTime.parse(tsStr);
          } catch (e) { debugPrint('[err] $e'); }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _displayNames.addAll(displayNames);
      _lastUsed.addAll(lastUsed);
      
      _accounts.sort((a, b) {
        final ta = _lastUsed[a];
        final tb = _lastUsed[b];
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    
    AccountManager.ensureAccountsLoaded();
    AccountManager.accountsNotifier.addListener(_onAccountsChanged);
    if (!DecoyManager.isActive.value) {
      _accounts = List<String>.from(AccountManager.accountsNotifier.value);
    }
    _updatePubFingerprintsFor(_accounts);
    _refreshMetaAndSort();
    widget.onRefreshProfile?.call();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _isVisible = true);
        _fadeController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AccountsTab old) {
    super.didUpdateWidget(old);

    if (old.currentUsername != widget.currentUsername) {
      _refreshMetaAndSort();
    }
  }

  @override
  void dispose() {
    AccountManager.accountsNotifier.removeListener(_onAccountsChanged);
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (DecoyManager.isActive.value) {
      if (mounted) setState(() { _accounts = []; _pubFingerprints = {}; });
      return;
    }
    final accounts = await AccountManager.getAccountsList();
    final Map<String, String?> fps = {};
    for (final acc in accounts) {
      final id = await AccountManager.getIdentity(acc);
      if (id != null) {
        try {
          final fp = _computePubkeyFpHex(
            base64Decode(id['pub']!),
          ).substring(0, 16);
          fps[acc] = fp;
        } catch (e) {
          fps[acc] = null;
        }
      } else {
        fps[acc] = null;
      }
    }
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _pubFingerprints = fps;
      });
    }
    
    AccountManager.accountsNotifier.value = List<String>.from(accounts);
  }

  void _onAccountsChanged() {
    if (DecoyManager.isActive.value) return;
    final accounts = AccountManager.accountsNotifier.value;
    
    _updatePubFingerprintsForNewAccounts(accounts);
    if (mounted) {
      setState(() {
        _accounts = List<String>.from(accounts);
      });
      _refreshMetaAndSort();
    }
  }

  void _updatePubFingerprintsForNewAccounts(List<String> accounts) async {
    final newAccounts = accounts.where((acc) => !_pubFingerprints.containsKey(acc)).toList();

    if (newAccounts.isEmpty) return; 

    final Map<String, String?> newFps = {};
    for (final acc in newAccounts) {
      final id = await AccountManager.getIdentity(acc);
      if (id != null) {
        try {
          final fp = _computePubkeyFpHex(base64Decode(id['pub']!)).substring(0, 16);
          newFps[acc] = fp;
        } catch (e) {
          newFps[acc] = null;
        }
      } else {
        newFps[acc] = null;
      }
    }

    if (mounted && newFps.isNotEmpty) {
      setState(() {
        _pubFingerprints.addAll(newFps);
      });
    }
  }

  void _updatePubFingerprintsFor(List<String> accounts) async {
    final Map<String, String?> fps = {};
    for (final acc in accounts) {
      final id = await AccountManager.getIdentity(acc);
      if (id != null) {
        try {
          final fp = _computePubkeyFpHex(base64Decode(id['pub']!)).substring(0, 16);
          fps[acc] = fp;
        } catch (e) {
          fps[acc] = null;
        }
      } else {
        fps[acc] = null;
      }
    }
    if (mounted) {
      setState(() {
        _pubFingerprints = fps;
      });
    }
  }

  String _computePubkeyFpHex(List<int> raw) {
    final d = dart_crypto.sha256.convert(raw);
    return hex.encode(d.bytes);
  }

  Future<void> _showEditProfileDialog() async {
    if (widget.currentUsername == null) return;

    final username = widget.currentUsername!;
    final currentDisplayName =
        rootScreenKey.currentState?.currentDisplayName ?? username;

    final displayNameCtrl = TextEditingController(text: currentDisplayName);

    void _copyToClipboard(BuildContext ctx, String text) {
      Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
    }

    bool avatarChanged = false;
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 187),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) {
        final cs = Theme.of(ctx).colorScheme;
        final l = AppLocalizations.of(ctx);
        const btnShape = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(50)));
        const btnPadding = EdgeInsets.symmetric(vertical: 13);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header tinted ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        border: Border(
                          bottom: BorderSide(
                              color: cs.primary.withValues(alpha: 0.10),
                              width: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.editProfile,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(false),
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
                    // ── Content ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                AvatarWidget(
                                  username: username,
                                  tokenProvider: avatarTokenProvider,
                                  avatarBaseUrl: serverBase,
                                  size: 88.0,
                                  editable: true,
                                  onUploaded: (url) {
                                    avatarChanged = true;
                                    _showSnack(l.avatarUpdated);
                                  },
                                  onDeleted: () {
                                    avatarChanged = true;
                                    _showSnack(l.avatarRemoved);
                                  },
                                ),
                                const SizedBox(height: 10),
                                ValueListenableBuilder<bool>(
                                  valueListenable:
                                      SettingsManager.onionModeEnabled,
                                  builder: (_, onionOn, __) {
                                    // With several devices: an onyx: code
                                    // listing all of their addresses.
                                    final onionAddress =
                                        onionOn && OnionIdentity.isRunning
                                            ? OnionTransportService
                                                .instance.myContactCode
                                            : null;
                                    if (onionAddress == null) {
                                      // Tor still bootstrapping (or off): the
                                      // old @username / #UIN are server-era
                                      // leftovers, so show nothing until the
                                      // onion address exists.
                                      return const SizedBox.shrink();
                                    }
                                    // Onion Mode on: this account has no
                                    // username/UIN anyone off-device can use
                                    // to reach it -- the onion address is the
                                    // only thing that actually works, so it
                                    // replaces both, plus a QR someone can
                                    // scan straight into "Connect via Tor".
                                    return Column(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            _copyToClipboard(
                                                ctx, onionAddress);
                                            _showSnack('Onion address copied');
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  onionAddress,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontFamily: 'monospace',
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: cs.primary,
                                                    decoration: TextDecoration
                                                        .underline,
                                                    decorationColor: cs
                                                        .primary
                                                        .withValues(
                                                            alpha: 0.4),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.copy_rounded,
                                                  size: 14, color: cs.primary),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                shape: const StadiumBorder(),
                                                side: BorderSide(
                                                    color: cs.primary.withValues(alpha: 0.5)),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 10),
                                              ),
                                              onPressed: () =>
                                                  showOnionPairDialog(ctx),
                                              icon: const Icon(
                                                  Icons.qr_code_2_rounded,
                                                  size: 16),
                                              label: Text(l.addContactQr),
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                shape: const StadiumBorder(),
                                                side: BorderSide(
                                                    color: cs.primary.withValues(alpha: 0.5)),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 10),
                                              ),
                                              onPressed: () =>
                                                  showPairedContactsDialog(
                                                      ctx),
                                              icon: const Icon(
                                                  Icons.people_alt_rounded,
                                                  size: 16),
                                              label: Text(l.contactsTitle),
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                shape: const StadiumBorder(),
                                                side: BorderSide(
                                                    color: cs.primary.withValues(alpha: 0.5)),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 16, vertical: 10),
                                              ),
                                              onPressed: () =>
                                                  showOwnDevicesDialog(ctx),
                                              icon: const Icon(
                                                  Icons.devices_rounded,
                                                  size: 16),
                                              label: Text(l.myDevicesTitle),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l.tapAvatarHint,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<double>(
                            valueListenable: SettingsManager.elementBrightness,
                            builder: (_, brightness, __) {
                              final baseColor = SettingsManager.getElementColor(
                                cs.surfaceContainerHighest, brightness);
                              return TextField(
                                controller: displayNameCtrl,
                                onTapOutside: (_) =>
                                    FocusManager.instance.primaryFocus?.unfocus(),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: baseColor.withValues(alpha: 0.5),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide: BorderSide(
                                        color: cs.outlineVariant
                                            .withValues(alpha: 0.3),
                                        width: 0.8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    borderSide:
                                        BorderSide(color: cs.primary, width: 1.4),
                                  ),
                                  counterStyle: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.45),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: btnPadding,
                              shape: btnShape,
                            ),
                            onPressed: () {
                              final newName = displayNameCtrl.text.trim();
                              if (newName.isEmpty) {
                                _showSnack(l.displayNameRequired);
                                return;
                              }
                              if (newName == currentDisplayName) {
                                Navigator.of(ctx).pop(false);
                                return;
                              }
                              Navigator.of(ctx).pop(true);
                            },
                            child: Text(l.save),
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
      },
    );

    if (result == true) {
      final newName = displayNameCtrl.text.trim();
      await _saveDisplayName(username, newName);
    }

    if (avatarChanged) {
      
      avatarVersion.value++;
      if (mounted) setState(() {});
    }

    displayNameCtrl.dispose();
  }

  Future<void> _saveDisplayName(String username, String newName) async {
    final token = await AccountManager.getToken(username);
    if (token == null) {
      // No server token -- this is a decentralized (onion-only) account, not
      // an expired session. There is no server to notify, so the name is
      // just a local fact about this device's identity.
      await AccountManager.cacheDisplayName(username, newName);
      rootScreenKey.currentState?.setState(() {
        rootScreenKey.currentState!.currentDisplayName = newName;
      });
      if (!mounted) return;
      setState(() => _displayNames[username] = newName != username ? newName : null);
      _showSnack(AppLocalizations.of(context).displayNameUpdated);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$serverBase/profile/display_name'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({'display_name': newName}),
      );

      if (res.statusCode == 200) {
        rootScreenKey.currentState?.setState(() {
          rootScreenKey.currentState!.currentDisplayName = newName;
        });
        
        unawaited(AccountManager.cacheDisplayName(username, newName));
        if (mounted) {
          setState(() => _displayNames[username] = newName != username ? newName : null);
        }
        _showSnack(' Display name updated');
      } else {
        final msg = jsonDecode(res.body)['detail'] ?? 'Unknown error';
        _showSnack(' $msg');
      }
    } catch (e) {
      _showSnack(' Network error: $e');
    }
  }


  void _showSnack(String text) {
    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = SettingsManager.elementBrightness.value;
    final opacity = SettingsManager.elementOpacity.value;
    final backgroundColor = SettingsManager.getElementColor(
      colorScheme.surfaceContainerHighest,
      brightness,
    ).withValues(alpha: opacity);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        elevation: 4,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FadeTransition(
      opacity: _isVisible ? _fadeAnimation : const AlwaysStoppedAnimation(0),
      child: ListView(
        // Same bottom gap as the other tabs (room for the nav bar).
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 8 + MediaQuery.paddingOf(context).bottom),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          
          if (widget.currentUsername != null)
            AdaptiveGlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.all(12),
              onTap: _showEditProfileDialog,
              child: Row(
                children: [
                  if (DecoyManager.isActive.value)
                    DecoyAvatarPreview(
                      avatarPath: DecoyManager.avatarPath,
                      displayName: DecoyManager.displayName,
                      size: 52,
                    )
                  else
                    ValueListenableBuilder<int>(
                      valueListenable: avatarVersion,
                      builder: (context, _, __) => AvatarWidget(
                        key: ValueKey('avatar-${widget.currentUsername ?? ''}'),
                        username: widget.currentUsername ?? '',
                        tokenProvider: avatarTokenProvider,
                        avatarBaseUrl: serverBase,
                        size: 52.0,
                        editable: false,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.onionModeEnabled,
                      builder: (context, onionEnabled, __) {
                        final cs = Theme.of(context).colorScheme;
                        final title =
                            rootScreenKey.currentState?.currentDisplayName ??
                                widget.currentUsername!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!onionEnabled) ...[
                              Text(
                                '@${widget.currentUsername}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.currentUin != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '#${widget.currentUin}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        cs.primary.withValues(alpha: 0.8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // (The "session expired" / "session expires in N days" banners are
          // gone: they were about the central server's login token, and
          // accounts are Tor identities now -- nothing expires.)

          const SizedBox(height: 16),

          // New decentralized identity (Tor-based, no server) — this is now
          // the only way to add an account; the old server-registration
          // "Add Account" flow (AuthDialog) has been removed in favour of it.
          ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementBrightness,
            builder: (_, brightness, __) {
              final baseColor = SettingsManager.getElementColor(
                Theme.of(context).colorScheme.surfaceContainerHighest,
                brightness,
              );
              final fgColor = (widget.currentTheme == AppTheme.grey &&
                      Theme.of(context).colorScheme.brightness == Brightness.dark)
                  ? const Color(0xFFA0A0A0)
                  : Theme.of(context).colorScheme.primary;
              // IntrinsicHeight so CrossAxisAlignment.stretch has a definite
              // height to stretch to -- this Row sits inside a ListView,
              // which gives it unbounded height (0..Infinity), and stretch
              // against an unbounded constraint throws a layout assertion
              // that cascades into every sibling below it in the list.
              return IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: FilledButton.icon(
                          onPressed: () async {
                            await showIdentityOnboardingDialog(
                              context,
                              onSwitchAccount: widget.onSwitchAccount,
                            );
                            if (mounted) {
                              await AccountManager.ensureAccountsLoaded();
                            }
                          },
                          icon: Icon(Icons.add, size: 18, color: fgColor),
                          label: Text(
                            AppLocalizations.of(context).identityNewIdentityButton,
                            style: TextStyle(fontSize: 15, color: fgColor),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.currentTheme == AppTheme.grey
                                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.06)
                                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: AppLocalizations.of(context).identityInfoTooltip,
                    child: GestureDetector(
                      onTap: () => showIdentityInfoDialog(context),
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.help_outline_rounded, size: 20, color: fgColor),
                      ),
                    ),
                  ),
                ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Link Device — same secondary colour as Edit Profile
          ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementBrightness,
            builder: (_, brightness, __) {
              final baseColor = SettingsManager.getElementColor(
                Theme.of(context).colorScheme.surfaceContainerHighest,
                brightness,
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: FilledButton.icon(
                    onPressed: () async {
                      // Linking hands this account (key, contacts) to another
                      // device, so it needs the same unlock as switching
                      // accounts -- but only if a PIN lock is enabled at all.
                      if (!await confirmWithAppLock(context,
                          reason: 'Confirm linking a new device')) {
                        return;
                      }
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (_) => DeviceAuthScreen(
                          currentUsername: widget.currentUsername,
                          onQrLogin: widget.onQrLogin,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.devices_rounded,
                      size: 18,
                      color: (widget.currentTheme == AppTheme.grey &&
                              Theme.of(context).colorScheme.brightness == Brightness.dark)
                          ? const Color(0xFFA0A0A0)
                          : Theme.of(context).colorScheme.secondary,
                    ),
                    label: Text(
                      AppLocalizations.of(context).deviceAuthTitle,
                      style: TextStyle(
                        fontSize: 15,
                        color: (widget.currentTheme == AppTheme.grey &&
                                Theme.of(context).colorScheme.brightness == Brightness.dark)
                            ? const Color(0xFFA0A0A0)
                            : Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.currentTheme == AppTheme.grey
                          ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.06)
                          : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                  ),
                ),
              );
            },
          ),

          ValueListenableBuilder<bool>(
            valueListenable: SettingsManager.pinEnabled,
            builder: (_, pinOn, __) {
              if (!pinOn && !DecoyManager.isActive.value) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ValueListenableBuilder<double>(
                  valueListenable: SettingsManager.elementBrightness,
                  builder: (_, brightness, __) {
                    final baseColor = SettingsManager.getElementColor(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      brightness,
                    );
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: FilledButton.icon(
                          onPressed: () => DecoyManager.onLockRequest?.call(),
                          icon: Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: (widget.currentTheme == AppTheme.grey &&
                                    Theme.of(context).colorScheme.brightness == Brightness.dark)
                                ? const Color(0xFFA0A0A0)
                                : Theme.of(context).colorScheme.secondary,
                          ),
                          label: Text(
                            AppLocalizations.of(context).lock,
                            style: TextStyle(
                              fontSize: 15,
                              color: (widget.currentTheme == AppTheme.grey &&
                                      Theme.of(context).colorScheme.brightness == Brightness.dark)
                                  ? const Color(0xFFA0A0A0)
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.currentTheme == AppTheme.grey
                                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.06)
                                : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                            foregroundColor: Theme.of(context).colorScheme.secondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          if (_accounts.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).otherAccounts,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ..._accounts
                    .where((acc) => acc != widget.currentUsername)
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                      final i = entry.key;
                      final acc = entry.value;
                      final displayName = _displayNames[acc];
                      return FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(
                            parent: _fadeAnimation,
                            curve: Interval(
                              i * 0.05,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: AdaptiveGlassCard(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            if (isDesktop) {
                              rootScreenKey.currentState?.hideDetailPanel();
                            }
                            widget.onSwitchAccount(acc);
                          },
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            mouseCursor: SystemMouseCursors.click,
                            title: Text(
                              displayName ?? acc,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              displayName != null ? '@$acc' : AppLocalizations.of(context).tapToSwitch,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                            ),
                            trailing: IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                final confirmed = await showOnyxConfirmDialog(
                                  context: context,
                                  title: AppLocalizations.of(context)
                                      .deleteFromRecentTitle,
                                  message: AppLocalizations.of(context)
                                      .deleteFromRecentContent(acc),
                                  confirmLabel:
                                      AppLocalizations.of(context).delete,
                                  isDestructive: true,
                                  icon: Icons.delete_outline_rounded,
                                );
                                if (confirmed == true) {
                                  await widget.onDeleteAccount(acc);
                                  if (mounted) await _loadAccounts();
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    }),
              ],
            ),
        ],
      ),
    );
  }
}

