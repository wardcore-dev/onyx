// lib/screens/accounts_tab.dart
import 'dart:async';
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
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/auth_dialog.dart';
import '../globals.dart';
import '../widgets/avatar_widget.dart';
import '../utils/global_log_collector.dart';
import '../l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

class AccountsTab extends StatefulWidget {
  final String? currentUsername;
  final String? currentUin;
  final String? identityPubFp;
  final Future<bool> Function(String, String) onLogin;
  final Future<String?> Function(String, String) onRegister;
  final Future<void> Function(String) onSwitchAccount;
  final Future<void> Function(String) onDeleteAccount;
  final List<String> logs;
  final AppTheme currentTheme;

  const AccountsTab({
    Key? key,
    required this.currentUsername,
    this.currentUin,
    required this.identityPubFp,
    required this.onLogin,
    required this.onRegister,
    required this.onSwitchAccount,
    required this.onDeleteAccount,
    required this.logs,
    required this.currentTheme,
  }) : super(key: key);

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

Widget _glassCard({required BuildContext context, required Widget child}) {
  final colorScheme = Theme.of(context).colorScheme;
  return ValueListenableBuilder<double>(
    valueListenable: SettingsManager.elementBrightness,
    builder: (_, brightness, __) {
      return ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementOpacity,
        builder: (_, opacity, __) {
          final baseColor = SettingsManager.getElementColor(
            colorScheme.surfaceContainerHighest,
            brightness,
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: child,
            ),
          );
        },
      );
    },
  );
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
    _accounts = List<String>.from(AccountManager.accountsNotifier.value);
    _updatePubFingerprintsFor(_accounts);
    _refreshMetaAndSort();

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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final surfaceVariantColor = SettingsManager.getElementColor(
              Theme.of(ctx).colorScheme.surfaceVariant,
              brightness,
            );
            final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Dialog(
                  backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: SettingsManager.elementOpacity.value),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(ctx).editProfile,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Column(
                        children: [
                          AvatarWidget(
                            username: username,
                            tokenProvider: avatarTokenProvider,
                            avatarBaseUrl: serverBase,
                            size: 96.0,
                            editable: true,
                            onUploaded: (url) {
                              avatarChanged = true;
                              
                              _showSnack(AppLocalizations.of(context).avatarUpdated);
                            },
                            onDeleted: () {
                              avatarChanged = true;
                              _showSnack(AppLocalizations.of(context).avatarRemoved);
                            },
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  _copyToClipboard(ctx, '@$username');
                                  _showSnack(AppLocalizations.of(context).copiedUsername(username));
                                },
                                child: Text(
                                  '@$username',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(ctx).colorScheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              if (widget.currentUin != null) ...[
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    _copyToClipboard(ctx, widget.currentUin!);
                                    _showSnack('${AppLocalizations.of(context).uinCopied}: ${widget.currentUin}');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '#${widget.currentUin}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap avatar to change • Long-press to remove',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      AppLocalizations.of(ctx).displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(ctx).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: displayNameCtrl,
                      maxLength: 16,
                      decoration: InputDecoration(
                        hintText: 'Enter your display name',
                        filled: true,
                        fillColor: surfaceVariantColor.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: TextStyle(
                          fontSize: 11,
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            final newName = displayNameCtrl.text.trim();
                            if (newName.isEmpty || newName.length > 16) {
                              _showSnack(AppLocalizations.of(context).displayNameLength);
                              return;
                            }
                            if (newName == currentDisplayName) {
                              Navigator.of(ctx).pop(false);
                              return;
                            }
                            Navigator.of(ctx).pop(true);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),           
              ),             
            ),               
          ),                 
        ),                   
      ),                     
    );                       
          },
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
    final notLoggedInMsg = AppLocalizations.of(context).notLoggedIn;
    final token = await AccountManager.getToken(username);
    if (token == null) {
      _showSnack(notLoggedInMsg);
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
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          
          if (widget.currentUsername != null)
            _glassCard(
              context: context,
              child: Row(
                children: [
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          rootScreenKey.currentState?.currentDisplayName ?? widget.currentUsername!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${widget.currentUsername}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          if (widget.currentUsername != null)
            ValueListenableBuilder<double>(
              valueListenable: SettingsManager.elementBrightness,
              builder: (_, brightness, __) {
                final baseColor = SettingsManager.getElementColor(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  brightness,
                );
                return ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: FilledButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: Icon(
                        Icons.edit,
                        size: 18,
                        color: (widget.currentTheme == AppTheme.grey &&
                                Theme.of(context).colorScheme.brightness == Brightness.dark)
                            ? const Color(0xFFA0A0A0)
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      label: Text(
                        AppLocalizations.of(context).editProfile,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementBrightness,
            builder: (_, brightness, __) {
              final baseColor = SettingsManager.getElementColor(
                Theme.of(context).colorScheme.surfaceContainerHighest,
                brightness,
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: FilledButton.icon(
                onPressed: () async {
                  if (isDesktop &&
                      rootScreenKey.currentState?.selectedChatOther != null) {
                    rootScreenKey.currentState?.hideDetailPanel();
                  }

                  await showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: 'Authentication',
                    transitionDuration: const Duration(milliseconds: 133),
                    pageBuilder: (ctx, anim1, anim2) => AuthDialog(
                      onLogin: widget.onLogin,
                      onRegister: widget.onRegister,
                    ),
                  );
                  if (mounted) {
                    
                    await AccountManager.ensureAccountsLoaded();
                  }
                },
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: (widget.currentTheme == AppTheme.grey &&
                          Theme.of(context).colorScheme.brightness == Brightness.dark)
                      ? const Color(0xFFA0A0A0)
                      : Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  AppLocalizations.of(context).addAccount,
                  style: TextStyle(
                    fontSize: 15,
                    color: (widget.currentTheme == AppTheme.grey &&
                            Theme.of(context).colorScheme.brightness == Brightness.dark)
                        ? const Color(0xFFA0A0A0)
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.currentTheme == AppTheme.grey
                      ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.06)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
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
                        child: _glassCard(
                          context: context,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            visualDensity: VisualDensity.compact,
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
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(AppLocalizations.of(ctx).deleteFromRecentTitle),
                                    content: Text(AppLocalizations.of(ctx).deleteFromRecentContent(acc)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: Text(AppLocalizations.of(ctx).cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: Text(AppLocalizations.of(ctx).delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await widget.onDeleteAccount(acc);
                                  if (mounted) await _loadAccounts();
                                }
                              },
                            ),
                            onTap: () {
                              if (isDesktop) {
                                rootScreenKey.currentState?.hideDetailPanel();
                              }
                              widget.onSwitchAccount(acc);
                            },
                          ),
                        ),
                      );
                    })
                    .toList(),
              ],
            ),
        ],
      ),
    );
  }
}