// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../managers/secure_store.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import '../utils/proxy_manager.dart';
import 'pin_code_screen.dart';
import 'package:local_auth/local_auth.dart';
import '../globals.dart';
import '../widgets/adaptive_blur.dart';
import '../models/app_themes.dart';
import '../models/font_family.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/autostart_manager.dart';

void _showStyledSnack(BuildContext context, String text, {Duration duration = const Duration(seconds: 2)}) {
  final colorScheme = Theme.of(context).colorScheme;
  final brightness = SettingsManager.elementBrightness.value;
  final opacity = SettingsManager.elementOpacity.value;
  final backgroundColor = SettingsManager.getElementColor(
    colorScheme.surfaceContainerHighest,
    brightness,
  ).withValues(alpha: opacity);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        text,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 4,
      duration: duration,
    ),
  );
}

class _Coin {
  final String name;
  final String symbol;
  final String address;
  final Color color;
  final List<String> pros;
  final List<String> cons;
  const _Coin({required this.name, required this.symbol, required this.address, required this.color, required this.pros, required this.cons});
}

const _kCoins = [
  _Coin(
    name: 'Bitcoin', symbol: 'BTC', color: Color(0xFFF7931A),
    address: 'bc1qpw2amf3j7w4swunx8mdfvk703uq3uadg9748tm',
    pros: ['Most widely accepted', 'Available on any exchange', 'Maximum liquidity'],
    cons: ['High transaction fees', 'Transactions are public', 'Slow confirmation (~10 min)'],
  ),
  _Coin(
    name: 'Litecoin', symbol: 'LTC', color: Color(0xFF345D9D),
    address: 'ltc1qx37f0k2mckxp2je3cplkfvg7473nq8udpk4kg9',
    pros: ['Low fees', 'Fast confirmation (~2.5 min)', 'Available on most exchanges'],
    cons: ['Transactions are public', 'Less popular than BTC'],
  ),
  _Coin(
    name: 'Monero', symbol: 'XMR', color: Color(0xFFFF6600),
    address: '88R9RYWEL38Aj7As8KnT9bia7HyQkPf7AC9XK8HuDofaevudWAkLw9sjMhkQ4aNvzVdjdgdWSpvTw8RyHePcuHov6cwBTT2',
    pros: ['Fully anonymous by default', 'Untraceable transactions', 'Best fit for a privacy app'],
    cons: ['Harder to buy (limited exchanges)', 'Longer sync time in wallet'],
  ),
];

class SupportSheet extends StatefulWidget {
  const SupportSheet({super.key});
  @override
  State<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<SupportSheet> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coin = _kCoins[_selected];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Text(AppLocalizations.of(context).supportOnyx, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context).chooseCrypto, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kCoins.length, (i) {
              final c = _kCoins[i];
              final active = i == _selected;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? c.color.withValues(alpha: 0.15) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: active ? c.color : cs.outlineVariant.withValues(alpha: 0.3), width: active ? 1.5 : 0.8),
                    ),
                    child: Text(
                      c.symbol,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? c.color : cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_selected),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: coin.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: coin.color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...coin.pros.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.green.shade400),
                      const SizedBox(width: 6),
                      Expanded(child: Text(AppLocalizations.of(context).localizeDonateText(p), style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)))),
                    ]),
                  )),
                  if (coin.cons.isNotEmpty) const SizedBox(height: 4),
                  ...coin.cons.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.remove_circle_outline_rounded, size: 14, color: Colors.red.shade300),
                      const SizedBox(width: 6),
                      Expanded(child: Text(AppLocalizations.of(context).localizeDonateText(c), style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)))),
                    ]),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: coin.address,
              version: QrVersions.auto,
              size: 180,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    coin.address,
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurface.withValues(alpha: 0.8)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: coin.address));
                    _showStyledSnack(context, '${coin.symbol} ${AppLocalizations.of(context).addressCopied}', duration: const Duration(seconds: 1));
                  },
                  child: Icon(Icons.copy_rounded, size: 18, color: cs.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<double> _calculateCacheSizeInBackground(String basePath) async {
  final mediaDirs = [
    '$basePath/voice_cache',
    '$basePath/image_cache',
    '$basePath/video_cache',
    '$basePath/file_cache',
    '$basePath/document_cache',
    '$basePath/archive_cache',
    '$basePath/data_cache',
    '$basePath/audio_cache',
  ];

  int totalBytes = 0;
  for (final path in mediaDirs) {
    final cacheDir = Directory(path);
    if (await cacheDir.exists()) {
      final files = cacheDir.listSync(recursive: true, followLinks: false);
      for (final f in files) {
        if (f is File) {
          totalBytes += await f.length();
        }
      }
    }
  }
  return totalBytes / (1024 * 1024);
}

class SettingsTab extends StatefulWidget {
  final AppTheme currentTheme;
  final bool isDarkMode;
  final Future<void> Function(AppTheme theme, bool isDark) onThemeChanged;
  final Future<void> Function() onGenerateIdentity;
  final Future<bool> Function() onUploadPubkey;
  
  final Future<void> Function() onRotateKey;
  
  final Future<void> Function() onFullSessionReset;
  final VoidCallback onConnectWs;
  final VoidCallback onDisconnectWs;
  final Future<void> Function() onLogout;
  final List<String> logs;
  
  final bool isPrimaryDevice;
  final VoidCallback onShowPassphrase;
  final Future<void> Function(String passphrase, String oldPassword, String newPassword) onChangePassword;
  final VoidCallback onOpenSessions;

  const SettingsTab({
    Key? key,
    required this.currentTheme,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onGenerateIdentity,
    required this.onUploadPubkey,
    required this.onRotateKey,
    required this.onFullSessionReset,
    required this.onConnectWs,
    required this.onDisconnectWs,
    required this.onLogout,
    required this.logs,
    required this.isPrimaryDevice,
    required this.onShowPassphrase,
    required this.onChangePassword,
    required this.onOpenSessions,
  }) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  late final int _randomTipIndex;
  double? _cacheSizeMb;
  bool _cacheSizeLoaded = false; 

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isVisible = false;

  SectionType? _expandedSection;

  late TextEditingController _statusOnlineController;
  late TextEditingController _statusOfflineController;
  
  bool _isUpdatingControllers = false;

  late TextEditingController _proxyHostController;
  late TextEditingController _proxyPortController;
  late TextEditingController _proxyUsernameController;
  late TextEditingController _proxyPasswordController;
  bool _proxyPasswordVisible = false;
  bool _proxyTesting = false;
  String? _proxyTestResult; 
  
  late String _localStatusVisibility;

  @override
  void initState() {
    super.initState();
    _randomTipIndex = Random().nextInt(6);

    _localStatusVisibility = SettingsManager.statusVisibility.value;

    _statusOnlineController = TextEditingController(
      text: SettingsManager.statusOnline.value,
    );
    _statusOfflineController = TextEditingController(
      text: SettingsManager.statusOffline.value,
    );

    _proxyHostController = TextEditingController(
      text: SettingsManager.proxyHost.value,
    );
    _proxyPortController = TextEditingController(
      text: SettingsManager.proxyPort.value,
    );
    _proxyUsernameController = TextEditingController(
      text: SettingsManager.proxyUsername.value,
    );
    _proxyPasswordController = TextEditingController(
      text: SettingsManager.proxyPassword.value,
    );

    SettingsManager.statusOnline.addListener(_updateStatusOnlineController);
    SettingsManager.statusOffline.addListener(_updateStatusOfflineController);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isVisible = true);
        _fadeController.forward();
        
        _loadTotalCacheSize();
      }
    });
  }

  @override
  void dispose() {
    SettingsManager.statusOnline.removeListener(_updateStatusOnlineController);
    SettingsManager.statusOffline
        .removeListener(_updateStatusOfflineController);
    _statusOnlineController.dispose();
    _statusOfflineController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _proxyUsernameController.dispose();
    _proxyPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _updateStatusOnlineController() {
    
    if (_isUpdatingControllers) return;
    if (_statusOnlineController.text != SettingsManager.statusOnline.value) {
      _statusOnlineController.text = SettingsManager.statusOnline.value;
    }
  }

  void _updateStatusOfflineController() {
    
    if (_isUpdatingControllers) return;
    if (_statusOfflineController.text != SettingsManager.statusOffline.value) {
      _statusOfflineController.text = SettingsManager.statusOffline.value;
    }
  }

  void _updateLocalStatusVisibility() {
    
    _localStatusVisibility = SettingsManager.statusVisibility.value;
  }

  Future<void> _loadTotalCacheSize() async {
    if (_cacheSizeLoaded) return; 

    try {
      final dir = await getApplicationSupportDirectory();
      
      final sizeMb = await compute(_calculateCacheSizeInBackground, dir.path);

      if (mounted) {
        setState(() {
          _cacheSizeMb = sizeMb;
          _cacheSizeLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[_loadTotalCacheSize] error: $e');
    }
  }

  void _toggleSection(SectionType section) {
    setState(() {
      _expandedSection = _expandedSection == section ? null : section;
    });
  }

  Future<void> _clearCache() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearLocalCacheDialogTitle),
        content: Text(l.clearLocalCacheDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.clearAll),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final appSupport = await getApplicationSupportDirectory();
      final baseDir = appSupport.path;

      final mediaDirs = [
        '$baseDir/voice_cache',
        '$baseDir/image_cache',
        '$baseDir/video_cache',
        '$baseDir/file_cache',
        '$baseDir/document_cache',
        '$baseDir/archive_cache',
        '$baseDir/data_cache',
        '$baseDir/audio_cache',
      ];

      int totalDeleted = 0;
      for (final path in mediaDirs) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          totalDeleted++;
        }
      }

      for (final path in mediaDirs) {
        await Directory(path).create(recursive: true);
      }

      if (mounted) {
        setState(() {
          _cacheSizeMb = null;
          _cacheSizeLoaded = false;
        });
      }

      await _loadTotalCacheSize();

      rootScreenKey.currentState?.showSnack(
        AppLocalizations(SettingsManager.appLocale.value).mediaCachesCleared(totalDeleted),
      );
    } catch (e, st) {
      debugPrint(' _clearCache error: $e\n$st');
      if (mounted) {
        rootScreenKey.currentState?.showSnack(' $e');
      }
    }
  }

  Future<void> _factoryReset() async {
    final username = await AccountManager.getCurrentAccount();

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final resettingMsg = l.resetting;
    
    final result = await showDialog<({bool deleteAccount, bool deleteLocal})>(
      context: context,
      builder: (ctx) {
        bool deleteAccount = false;
        bool deleteLocal = false;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l.factoryReset),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.factoryResetHint,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: deleteAccount,
                  onChanged: username == null
                      ? null
                      : (v) => setState(() => deleteAccount = v ?? false),
                  title: Text(
                    l.resetDeleteAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    username != null
                        ? l.resetDeleteAccountSubtitle(username)
                        : l.resetNoAccount,
                    style: const TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: deleteLocal,
                  onChanged: (v) => setState(() => deleteLocal = v ?? false),
                  title: Text(
                    l.resetDeleteLocal,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l.resetDeleteLocalSubtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(l.cancel),
              ),
              StatefulBuilder(
                builder: (ctx2, _) => FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (deleteAccount || deleteLocal)
                      ? () => Navigator.of(ctx).pop(
                            (deleteAccount: deleteAccount, deleteLocal: deleteLocal),
                          )
                      : null,
                  child: Text(l.reset),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      if (mounted) rootScreenKey.currentState?.showSnack(resettingMsg);

      if (result.deleteAccount && username != null) {
        final token = await AccountManager.getToken(username);
        if (token != null) {
          final res = await http.delete(
            Uri.parse('$serverBase/api/me'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (res.statusCode != 200) {
            throw Exception('Server returned ${res.statusCode} while deleting account');
          }
        }
        debugPrint(' Account deleted from server');
      }

      if (result.deleteLocal) {
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint(' Cleared SharedPreferences');

        final appSupport = await getApplicationSupportDirectory();
        if (await appSupport.exists()) {
          await appSupport.delete(recursive: true);
          await appSupport.create(recursive: true);
          debugPrint(' Cleared Application Support directory');
        }

        final appDocs = await getApplicationDocumentsDirectory();
        if (await appDocs.exists()) {
          await appDocs.delete(recursive: true);
          await appDocs.create(recursive: true);
          debugPrint(' Cleared Application Documents directory');
        }

        try {
          await SecureStore.clear();
          debugPrint(' Cleared Secure Storage');
        } catch (e) {
          debugPrint(' Failed to clear secure storage: $e');
        }

        AccountManager.accountsNotifier.value = [];
        chatsVersion.value++;
        favoritesVersion.value++;
        groupsVersion.value++;

        final root = rootScreenKey.currentState;
        if (root != null) {
          root.chats.clear();
          
        }
        debugPrint(' Cleared local data');
      }

      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).doneRestarting);
        await Future.delayed(const Duration(seconds: 2));
        await widget.onLogout();
      }
    } catch (e, st) {
      debugPrint(' _factoryReset error: $e\n$st');
      if (mounted) {
        _showStyledSnack(context, '${AppLocalizations(SettingsManager.appLocale.value).resetFailed}: $e',
            duration: const Duration(seconds: 4));
      }
    }
  }

  Future<void> _showStatusDialog() async {
    final l = AppLocalizations.of(context);
    final savedOkMsg = l.statusSavedOk;
    final savedFailMsg = l.statusSavedFail;
    String localVisibility = _localStatusVisibility;
    final onlineCtrl = TextEditingController(text: SettingsManager.statusOnline.value);
    final offlineCtrl = TextEditingController(text: SettingsManager.statusOffline.value);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.manage_accounts_rounded, size: 20),
                const SizedBox(width: 8),
                Text(l.statusSettings),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.visibility_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(l.statusVisibility, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['show', 'hide'].map((opt) {
                        return FilterChip(
                          label: Text(opt == 'show' ? l.statusShowStatus : l.statusHideStatus),
                          selected: localVisibility == opt,
                          onSelected: (sel) {
                            if (sel) setDialogState(() => localVisibility = opt);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.edit_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(l.statusCustomText, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: onlineCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l.statusWhenOnline,
                        hintText: 'e.g., "custom online"',
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surface,
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: offlineCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l.statusWhenOffline,
                        hintText: 'e.g., "custom offline"',
                        filled: true,
                        fillColor: Theme.of(ctx).colorScheme.surface,
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  onlineCtrl.dispose();
                  offlineCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () async {
                  final onlineText = onlineCtrl.text.trim().isEmpty ? 'online' : onlineCtrl.text.trim();
                  final offlineText = offlineCtrl.text.trim().isEmpty ? 'offline' : offlineCtrl.text.trim();
                  _isUpdatingControllers = true;
                  await SettingsManager.setStatusVisibility(localVisibility);
                  await SettingsManager.setStatusOnline(onlineText);
                  await SettingsManager.setStatusOffline(offlineText);
                  _isUpdatingControllers = false;
                  setState(() => _localStatusVisibility = localVisibility);
                  onlineCtrl.dispose();
                  offlineCtrl.dispose();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  final ok = await _syncStatusSettings();
                  if (mounted) {
                    _showSnack(ok ? savedOkMsg : savedFailMsg);
                  }
                },
                child: Text(l.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _syncStatusSettings() async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return false;

      final token = await AccountManager.getToken(username);
      if (token == null) return false;

      final res = await http.post(
        Uri.parse('$serverBase/me/status-settings'),
        headers: {
          'authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status_visibility': SettingsManager.statusVisibility.value,
          'status_online': SettingsManager.statusOnline.value,
          'status_offline': SettingsManager.statusOffline.value,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint(' Status settings synced to server');

        final username = await AccountManager.getCurrentAccount();
        if (username != null) {
          final statuses = Map<String, String>.from(userStatusNotifier.value);

          final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);

          if (SettingsManager.statusVisibility.value == 'hide') {
            
            statuses.remove(username);
            userStatusNotifier.value = statuses;
            final s = Set<String>.from(onlineUsersNotifier.value)..remove(username);
            onlineUsersNotifier.value = s;
            vis[username] = 'hide';
            userStatusVisibilityNotifier.value = vis;
          } else {
            
            statuses[username] = SettingsManager.statusOnline.value;
            userStatusNotifier.value = statuses;
            final s = Set<String>.from(onlineUsersNotifier.value)..add(username);
            onlineUsersNotifier.value = s;
            vis[username] = 'show';
            userStatusVisibilityNotifier.value = vis;
            try {
              rootScreenKey.currentState?.sendPresence('online');
            } catch (e) { debugPrint('[err] $e'); }
          }
        }

        return true;
      } else {
        debugPrint(' Failed to sync status settings: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint(' Status sync error: $e');
      return false;
    }
  }

  Future<void> _clearServerCache() async {
    final l = AppLocalizations.of(context);
    final notLoggedInMsg = l.notLoggedIn;
    final clearedMsg = l.serverMediaCleared;
    final netErrPrefix = l.networkError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearServerCacheTitle),
        content: Text(l.clearServerCacheContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.clearAll),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final username = await AccountManager.getCurrentAccount();
    if (username == null) return;

    final token = await AccountManager.getToken(username);
    if (token == null) {
      _showSnack(notLoggedInMsg);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$serverBase/me/cleanup'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _showSnack(clearedMsg);
        avatarVersion.value++;
      } else {
        final msg = jsonDecode(res.body)['detail'] ?? 'Unknown error';
        _showSnack(' $msg');
      }
    } catch (e) {
      _showSnack('$netErrPrefix: $e');
    }
  }

  Future<void> _deleteAllLogs() async {
    final l = AppLocalizations.of(context);
    final noLogsMsg = l.noLogsFound;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteAllLogsTitle),
        content: Text(l.deleteAllLogsContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      late Directory appDir;
      if (Platform.isWindows) {
        appDir = Directory('${Platform.environment['APPDATA'] ?? ''}\\ONYX');
      } else if (Platform.isMacOS) {
        appDir = Directory(
            '${Platform.environment['HOME']}/Library/Application Support/ONYX');
      } else if (Platform.isLinux) {
        appDir = Directory('${Platform.environment['HOME']}/.config/onyx');
      } else {
        final docs = await getApplicationDocumentsDirectory();
        appDir = Directory('${docs.path}/ONYX');
      }

      if (!await appDir.exists()) {
        _showSnack(noLogsMsg);
        return;
      }

      int deleted = 0;
      await for (final entity in appDir.list()) {
        if (entity is File &&
            entity.path.contains('onyx_log_') &&
            entity.path.endsWith('.txt')) {
          await entity.delete();
          deleted++;
        }
      }

      _showSnack(deleted > 0
          ? AppLocalizations(SettingsManager.appLocale.value).deletedLogsCount(deleted)
          : noLogsMsg);
    } catch (e) {
      _showSnack(' $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    _showStyledSnack(context, text, duration: const Duration(seconds: 3));
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final passphraseCtrl = TextEditingController();
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;

    InputDecoration glassDec(BuildContext ctx, {
      required String label,
      required IconData prefixIconData,
      Widget? suffixIcon,
    }) {
      final cs = Theme.of(ctx).colorScheme;
      final brightness = SettingsManager.elementBrightness.value;
      final fillColor = SettingsManager.getElementColor(
        cs.surfaceContainerHighest, brightness,
      );
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        prefixIcon: Icon(prefixIconData, color: cs.onSurface.withValues(alpha: 0.6)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
      );
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.password_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.changePassword, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.changePasswordInfo,
                            style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passphraseCtrl,
                    style: TextStyle(color: cs.onSurface),
                    decoration: glassDec(
                      ctx,
                      label: l.changePasswordPassphraseLabel,
                      prefixIconData: Icons.key_rounded,
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    style: TextStyle(color: cs.onSurface),
                    decoration: glassDec(
                      ctx,
                      label: l.changePasswordCurrentLabel,
                      prefixIconData: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: TextStyle(color: cs.onSurface),
                    decoration: glassDec(
                      ctx,
                      label: l.changePasswordNewLabel,
                      prefixIconData: Icons.lock_reset,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.changePasswordChange),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final passphrase = passphraseCtrl.text.trim();
    final oldPass = oldPassCtrl.text;
    final newPass = newPassCtrl.text;

    if (passphrase.isEmpty || oldPass.isEmpty || newPass.isEmpty) {
      _showSnack(l.changePasswordFieldsRequired);
      return;
    }
    if (newPass.length < 16) {
      _showSnack(l.changePasswordTooShort);
      return;
    }

    _showSnack(l.changePasswordChanging);
    try {
      await widget.onChangePassword(passphrase, oldPass, newPass);
      _showSnack(l.changePasswordSuccess);
    } catch (e) {
      _showSnack(' $e');
    }
  }

  Future<void> _pickChatBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null) return;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return;
      final dir = await getApplicationSupportDirectory();
      final bgDir = Directory('${dir.path}/backgrounds');
      await bgDir.create(recursive: true);

      try {
        final files = bgDir.listSync().whereType<File>().toList();
        for (final f in files) {
          final name = p.basename(f.path);
          if (name.startsWith('chat_bg')) {
            try {
              await f.delete();
            } catch (e) { debugPrint('[err] $e'); }
          }
        }
      } catch (e) { debugPrint('[err] $e'); }

      final ext = p.extension(pickedPath);
      final dest =
          '${bgDir.path}/chat_bg_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(pickedPath).copy(dest);

      try {
        final prev = SettingsManager.chatBackground.value;
        if (prev != null) {
          await FileImage(File(prev)).evict();
        }
        await FileImage(File(dest)).evict();
      } catch (e) { debugPrint('[err] $e'); }

      await SettingsManager.setChatBackground(dest);
      _showSnack(AppLocalizations(SettingsManager.appLocale.value).chatBgSet);
    } catch (e) {
      _showSnack(' $e');
    }
  }

  Future<void> _clearChatBackground() async {
    final l = AppLocalizations.of(context);
    final clearedMsg = l.chatBgCleared;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clearBgTitle),
        content: Text(l.clearBgContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.clear)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final bgDir = Directory('${dir.path}/backgrounds');
      if (await bgDir.exists()) {
        final files = bgDir.listSync().whereType<File>().toList();
        for (final f in files) {
          final name = p.basename(f.path);
          if (name.startsWith('chat_bg')) {
            try {
              await f.delete();
            } catch (e) { debugPrint('[err] $e'); }
          }
        }
      }
    } catch (e) { debugPrint('[err] $e'); }

    try {
      final cur = SettingsManager.chatBackground.value;
      if (cur != null) await FileImage(File(cur)).evict();
    } catch (e) { debugPrint('[err] $e'); }

    await SettingsManager.setChatBackground(null);
    _showSnack(clearedMsg);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return FadeTransition(
      opacity: _isVisible ? _fadeAnimation : const AlwaysStoppedAnimation(0),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8 + MediaQuery.paddingOf(context).bottom),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const SupportSheet(),
            ),
            child: Builder(
              builder: (context) {
                final themeColor = Theme.of(context).colorScheme.primary;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withValues(alpha: 0.18),
                        themeColor.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_rounded, size: 17, color: themeColor),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).supportOnyx, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: themeColor)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          _buildLiquidGlassSection(
            icon: Icons.security_rounded,
            title: AppLocalizations.of(context).securityTitle,
            subtitle: AppLocalizations.of(context).securitySubtitle,
            section: SectionType.security,
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).tipOfTheDay, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).securityTips[_randomTipIndex],
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildLiquidGlassButton(
                  icon: Icons.manage_accounts_rounded,
                  label: AppLocalizations.of(context).statusSettings,
                  fontSize: 15,
                  onPressed: () => _showStatusDialog(),
                ),

                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.showDisplayNameInGroups,
                  builder: (context, showDN, _) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context).showDisplayNameInGroups,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      AppLocalizations.of(context).showDisplayNameSubtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: showDN,
                    onChanged: (val) =>
                        SettingsManager.setShowDisplayNameInGroups(val),
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.pin_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).pinLock, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.pinEnabled,
                  builder: (context, pinOn, _) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context).enablePinLock,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      AppLocalizations.of(context).enablePinSubtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    value: pinOn,
                    onChanged: (val) async {
                      if (val) {
                        
                        final pinEnabledMsg = AppLocalizations.of(context).pinLockEnabled;
                        final result = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => PinCodeScreen.setup(
                              onPinSet: (pin) => Navigator.pop(context, pin),
                              onCancel: () => Navigator.pop(context),
                            ),
                          ),
                        );
                        if (result != null && result.length == 4) {
                          await SettingsManager.setPin(result);
                          await SettingsManager.setPinEnabled(true);
                          _showSnack(pinEnabledMsg);
                        }
                      } else {
                        
                        final pinDisabledMsg = AppLocalizations.of(context).pinLockDisabled;
                        final confirmed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => PinCodeScreen.disable(
                              onSuccess: () => Navigator.pop(context, true),
                              onCancel: () => Navigator.pop(context, false),
                            ),
                          ),
                        );
                        if (confirmed == true) {
                          await SettingsManager.setPinEnabled(false);
                          await SettingsManager.clearPin();
                          await SettingsManager.setBiometricEnabled(false);
                          _showSnack(pinDisabledMsg);
                        }
                      }
                    },
                  ),
                ),

                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.pinEnabled,
                  builder: (context, pinOn, _) {
                    if (!pinOn) return const SizedBox.shrink();
                    return ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.biometricEnabled,
                      builder: (context, bioOn, _) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppLocalizations.of(context).useBiometrics,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          AppLocalizations.of(context).useBiometricsSubtitle,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        secondary: const Icon(Icons.fingerprint_rounded),
                        value: bioOn,
                        onChanged: (val) async {
                          if (val) {
                            final unavailMsg = AppLocalizations.of(context).biometricsUnavailable;
                            final auth = LocalAuthentication();
                            final supported = await auth.isDeviceSupported();
                            final canCheck = await auth.canCheckBiometrics;
                            if (!supported || !canCheck) {
                              _showSnack(unavailMsg);
                              return;
                            }
                          }
                          await SettingsManager.setBiometricEnabled(val);
                        },
                      ),
                    );
                  },
                ),

              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.key_rounded,
            title: AppLocalizations.of(context).keyMgmtTitle,
            subtitle: AppLocalizations.of(context).keyMgmtSubtitle,
            section: SectionType.keyManagement,
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).keyMgmtDescription,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                Opacity(
                  opacity: widget.isPrimaryDevice ? 1.0 : 0.4,
                  child: _buildLiquidGlassButton(
                    icon: Icons.devices_rounded,
                    label: widget.isPrimaryDevice
                        ? AppLocalizations.of(context).activeDevices
                        : AppLocalizations.of(context).activeDevicesPrimaryOnly,
                    fontSize: 14,
                    onPressed: widget.isPrimaryDevice ? widget.onOpenSessions : null,
                  ),
                ),
                const SizedBox(height: 10),

                Opacity(
                  opacity: widget.isPrimaryDevice ? 1.0 : 0.4,
                  child: _buildLiquidGlassButton(
                    icon: Icons.visibility_rounded,
                    label: widget.isPrimaryDevice
                        ? AppLocalizations.of(context).showPassphrase
                        : AppLocalizations.of(context).showPassphrasePrimaryOnly,
                    fontSize: 14,
                    onPressed: widget.isPrimaryDevice ? widget.onShowPassphrase : null,
                  ),
                ),
                const SizedBox(height: 10),

                Opacity(
                  opacity: widget.isPrimaryDevice ? 1.0 : 0.4,
                  child: _buildLiquidGlassButton(
                    icon: Icons.password_rounded,
                    label: widget.isPrimaryDevice
                        ? AppLocalizations.of(context).changePassword
                        : AppLocalizations.of(context).changePasswordPrimaryOnly,
                    fontSize: 14,
                    color: widget.isPrimaryDevice ? null : Colors.grey,
                    onPressed: widget.isPrimaryDevice
                        ? () => _showChangePasswordDialog(context)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.notifications_rounded,
            title: AppLocalizations.of(context).notificationsTitle,
            subtitle: AppLocalizations.of(context).notificationsSubtitle,
            section: SectionType.notifications,
            expandedContent: _buildNotificationsContent(),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.palette_rounded,
            title: AppLocalizations.of(context).appearanceTitle,
            subtitle: AppLocalizations.of(context).appearanceSubtitle,
            section: SectionType.appearance,
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).selectTheme,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: AppTheme.values.map((theme) {
                    final isSelected = widget.currentTheme == theme;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await widget.onThemeChanged(
                                theme, widget.isDarkMode);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.color,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: isSelected ? 3 : 0,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: theme.color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 60,
                          child: Text(
                            theme.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(AppLocalizations.of(context).darkMode),
                    const SizedBox(width: 12),
                    Switch(
                      value: widget.isDarkMode,
                      onChanged: (val) async {
                        await widget.onThemeChanged(widget.currentTheme, val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).fontAndTextSize,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<FontFamilyType>(
                  valueListenable: SettingsManager.fontFamily,
                  builder: (_, currentFont, __) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).fontFamily,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) {
                                  final cs = Theme.of(ctx).colorScheme;
                                  return ValueListenableBuilder<double>(
                                    valueListenable:
                                        SettingsManager.elementBrightness,
                                    builder: (_, brightness, __) {
                                      final sheetColor =
                                          SettingsManager.getElementColor(
                                        cs.surfaceContainerHighest,
                                        brightness,
                                      );
                                      return DraggableScrollableSheet(
                                        initialChildSize: 0.6,
                                        minChildSize: 0.4,
                                        maxChildSize: 0.95,
                                        expand: false,
                                        builder: (_, scrollController) {
                                          return Container(
                                            margin: const EdgeInsets.fromLTRB(
                                                12, 0, 12, 12),
                                            decoration: BoxDecoration(
                                              color: sheetColor,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: 36,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: cs.onSurface
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 4),
                                                  child: Text(
                                                    AppLocalizations.of(context).fontFamily,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: cs.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: ListView(
                                                    controller: scrollController,
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 8),
                                                    children: FontFamilyType
                                                        .values
                                                        .map((font) {
                                                      final isSelected =
                                                          currentFont == font;
                                                      return ListTile(
                                                        title: Text(
                                                          font.displayName,
                                                          style: font
                                                              .getBodyTextStyle(
                                                                  fontSize: 14),
                                                        ),
                                                        subtitle: Text(
                                                          AppLocalizations.of(context).localizeFontDescription(font.description),
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: cs.onSurface
                                                                .withValues(
                                                                    alpha: 0.5),
                                                          ),
                                                        ),
                                                        trailing: isSelected
                                                            ? Icon(
                                                                Icons
                                                                    .check_circle_rounded,
                                                                color: cs
                                                                    .primary,
                                                              )
                                                            : Icon(
                                                                Icons
                                                                    .radio_button_unchecked_rounded,
                                                                color: cs
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.3),
                                                              ),
                                                        selected: isSelected,
                                                        selectedTileColor: cs
                                                            .primary
                                                            .withValues(
                                                                alpha: 0.08),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        onTap: () async {
                                                          await SettingsManager
                                                              .setFontFamily(
                                                                  font);
                                                          if (ctx.mounted) {
                                                            Navigator.of(ctx)
                                                                .pop();
                                                          }
                                                        },
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentFont.displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppLocalizations.of(context).localizeFontDescription(currentFont.description),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: SettingsManager.fontSizeMultiplier,
                  builder: (_, sizeMultiplier, __) {
                    final labels = ['S', 'M', 'L', 'XL'];
                    final values = [0.9, 1.0, 1.1, 1.2];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.of(context).messageSize,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            Text(
                              '${(sizeMultiplier * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                            children: List.generate(values.length, (idx) {
                          final val = values[idx];
                          final label = labels[idx];
                          final isSelected =
                              (sizeMultiplier - val).abs() < 0.01;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () async {
                                  await SettingsManager.setFontSizeMultiplier(
                                      val);
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .outline,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1)
                                        : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList()),
                        const SizedBox(height: 8),
                        Slider(
                          value: sizeMultiplier,
                          min: 0.8,
                          max: 1.3,
                          divisions: 10,
                          onChanged: (val) async {
                            await SettingsManager.setFontSizeMultiplier(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.swapMessageAlignment,
                  builder: (_, swapped, __) {
                    final label = swapped
                        ? AppLocalizations.of(context).ownMessagesLeft
                        : AppLocalizations.of(context).ownMessagesRight;
                    return Row(
                      children: [
                        Text(label),
                        const SizedBox(width: 12),
                        Switch(
                          value: swapped,
                          onChanged: (val) async {
                            await SettingsManager.setSwapMessageAlignment(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.swapMessageAlignment,
                  builder: (_, swappedMsg, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.alignAllMessagesRight,
                      builder: (_, alignRight, __) {
                        final label = alignRight
                            ? (swappedMsg
                                ? AppLocalizations.of(context).allMessagesLeft
                                : AppLocalizations.of(context).allMessagesRight2)
                            : AppLocalizations.of(context).allMessagesMixed;
                        return Row(
                          children: [
                            Text(label),
                            const SizedBox(width: 12),
                            Switch(
                              value: alignRight,
                              onChanged: (val) async {
                                await SettingsManager.setAlignAllMessagesRight(
                                    val);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.showAvatarInChats,
                  builder: (_, showAvatar, __) {
                    return Row(
                      children: [
                        Text(AppLocalizations.of(context).showAvatarsInChats),
                        const SizedBox(width: 12),
                        Switch(
                          value: showAvatar,
                          onChanged: (val) async {
                            await SettingsManager.setShowAvatarInChats(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.smoothScrollEnabled,
                  builder: (_, smoothScroll, __) {
                    return Row(
                      children: [
                        Text(AppLocalizations.of(context).smoothScrollDown),
                        const SizedBox(width: 12),
                        Switch(
                          value: smoothScroll,
                          onChanged: (val) async {
                            await SettingsManager.setSmoothScroll(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.messageAnimationsEnabled,
                  builder: (_, animationsEnabled, __) {
                    return Row(
                      children: [
                        Text(AppLocalizations.of(context).messageAnimations),
                        const SizedBox(width: 12),
                        Switch(
                          value: animationsEnabled,
                          onChanged: (val) async {
                            await SettingsManager.setMessageAnimationsEnabled(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.messagePaginationEnabled,
                  builder: (_, paginationEnabled, __) {
                    return Row(
                      children: [
                        Text(AppLocalizations.of(context).loadOlderMessagesOnScroll),
                        const SizedBox(width: 12),
                        Switch(
                          value: paginationEnabled,
                          onChanged: (val) async {
                            await SettingsManager.setMessagePaginationEnabled(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).chatBackground,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String?>(
                  valueListenable: SettingsManager.chatBackground,
                  builder: (_, path, __) {
                    final aspect = isDesktop ? (16 / 9) : (9 / 16);
                    Widget preview;
                    if (path != null && File(path).existsSync()) {
                      preview = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: aspect,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: SettingsManager.blurBackground,
                            builder: (_, blur, __) {
                              final provider = FileImage(File(path));
                              final img = Image(
                                  image: provider,
                                  width: double.infinity,
                                  fit: BoxFit.cover);
                              return blur
                                  ? ValueListenableBuilder<double>(
                                      valueListenable:
                                          SettingsManager.blurSigma,
                                      builder: (_, sigma, __) {
                                        return AdaptiveBlur(
                                            imageProvider: provider,
                                            sigma: sigma,
                                            fit: BoxFit.cover);
                                      },
                                    )
                                  : img;
                            },
                          ),
                        ),
                      );
                    } else {
                      preview = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: aspect,
                          child: ValueListenableBuilder<double>(
                            valueListenable: SettingsManager.elementOpacity,
                            builder: (_, opacity, __) {
                              return Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withValues(alpha: opacity * 0.47),
                                child: Icon(Icons.photo,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.6)),
                              );
                            },
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: isDesktop ? 320 : 140,
                          child: preview,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildLiquidGlassButton(
                              icon: Icons.photo,
                              label: AppLocalizations.of(context).chooseBackground,
                              fontSize: 14,
                              onPressed: _pickChatBackground,
                            ),
                            TextButton(
                              onPressed: _clearChatBackground,
                              child: Text(AppLocalizations.of(context).clear),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable: SettingsManager.applyGlobally,
                          builder: (_, apply, __) {
                            return SwitchListTile(
                              title: Text(AppLocalizations.of(context).applyBackgroundToApp),
                              value: apply,
                              onChanged: (val) =>
                                  SettingsManager.setApplyGlobally(val),
                              contentPadding: EdgeInsets.zero,
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<double>(
                          valueListenable: SettingsManager.elementOpacity,
                          builder: (_, opacity, __) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).uiElementsOpacityLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        min: 0.1,
                                        max: 1.0,
                                        divisions: 18,
                                        value: opacity,
                                        label:
                                            (opacity * 100).toStringAsFixed(0) +
                                                '%',
                                        onChanged: (v) =>
                                            SettingsManager.setElementOpacity(
                                                v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                          '${(opacity * 100).toStringAsFixed(0)}%',
                                          textAlign: TextAlign.right),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<double>(
                          valueListenable: SettingsManager.elementBrightness,
                          builder: (_, brightness, __) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).uiElementsBrightnessLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        min: 0.0,
                                        max: 1.0,
                                        divisions: 20,
                                        value: brightness,
                                        label:
                                            (brightness * 100).toStringAsFixed(0) +
                                                '%',
                                        onChanged: (v) =>
                                            SettingsManager.setElementBrightness(
                                                v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                          '${(brightness * 100).toStringAsFixed(0)}%',
                                          textAlign: TextAlign.right),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (isDesktop)
                  ValueListenableBuilder<double>(
                    valueListenable: SettingsManager.inputBarMaxWidth,
                    builder: (_, width, __) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).inputBarMaxWidth,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  min: 320,
                                  max: 1600,
                                  divisions: 27,
                                  value: width,
                                  label: '${width.toInt()} px',
                                  onChanged: (v) =>
                                      SettingsManager.setInputBarMaxWidth(v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: Text('${width.toInt()} px',
                                    textAlign: TextAlign.right),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                if (isDesktop)
                  const SizedBox(height: 16),
                if (isDesktop)
                  ValueListenableBuilder<String>(
                    valueListenable: SettingsManager.desktopNavPosition,
                    builder: (_, navPosition, __) {
                      final isBottom = navPosition == 'bottom';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).navPanelPosition,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(isBottom ? AppLocalizations.of(context).navPosBottom : AppLocalizations.of(context).navPosLeft),
                              const SizedBox(width: 12),
                              Switch(
                                value: isBottom,
                                onChanged: (val) async {
                                  await SettingsManager.setDesktopNavPosition(
                                    val ? 'bottom' : 'left',
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                if (!isDesktop) ...[
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsManager.swipeTabsEnabled,
                    builder: (_, swipeTabs, __) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.of(context).tabSwiping, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  AppLocalizations.of(context).tabSwipingSubtitle,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: swipeTabs,
                            onChanged: (val) async {
                              await SettingsManager.setSwipeTabsEnabled(val);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.translate_rounded,
            title: AppLocalizations.of(context).languageTitle,
            subtitle: AppLocalizations.of(context).languageSubtitle,
            section: SectionType.language,
            expandedContent: _buildLanguageContent(),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.cleaning_services_rounded,
            title: AppLocalizations.of(context).cacheTitle,
            subtitle: AppLocalizations.of(context).cacheSubtitle,
            section: SectionType.cache,
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.of(context).mediaCacheSize}${_cacheSizeMb != null ? '${_cacheSizeMb!.toStringAsFixed(1)} MB' : AppLocalizations.of(context).loading}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildLiquidGlassButton(
                  icon: Icons.delete_outline,
                  label: AppLocalizations.of(context).clearLocalCache,
                  fontSize: 14,
                  onPressed: _clearCache,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.cloud_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).serverMediaCache, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  AppLocalizations.of(context).serverMediaCacheSubtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _buildLiquidGlassButton(
                  icon: Icons.delete_forever,
                  label: AppLocalizations.of(context).clearServerCache,
                  fontSize: 14,
                  onPressed: _clearServerCache,
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).dangerZone,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).dangerZoneSubtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                _buildLiquidGlassButton(
                  icon: Icons.restore,
                  label: AppLocalizations.of(context).factoryReset,
                  fontSize: 14,
                  onPressed: _factoryReset,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.cell_tower_rounded,
            title: AppLocalizations.of(context).connectionTitle,
            subtitle: AppLocalizations.of(context).connectionSubtitle,
            section: SectionType.connection,
            expandedContent: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildLiquidGlassButton(
                  icon: Icons.wifi,
                  label: AppLocalizations.of(context).connect,
                  fontSize: 14,
                  onPressed: widget.onConnectWs,
                ),
                _buildLiquidGlassButton(
                  icon: Icons.wifi_off,
                  label: AppLocalizations.of(context).disconnect,
                  fontSize: 14,
                  onPressed: widget.onDisconnectWs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.language_rounded,
            title: AppLocalizations.of(context).proxyTitle,
            subtitle: AppLocalizations.of(context).proxySubtitle,
            section: SectionType.proxy,
            expandedContent: _buildProxyContent(),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.tune_rounded,
            title: AppLocalizations.of(context).interactTitle,
            subtitle: AppLocalizations.of(context).interactSubtitle,
            section: SectionType.interact,
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.confirmFileUpload,
                  builder: (_, confirmFile, __) {
                    return SwitchListTile(
                      title: Text(AppLocalizations.of(context).confirmFileUpload),
                      subtitle: Text(AppLocalizations.of(context).confirmFileUploadSubtitle),
                      value: confirmFile,
                      onChanged: (val) async =>
                          await SettingsManager.setConfirmFileUpload(val),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.confirmVoiceUpload,
                  builder: (_, confirmVoice, __) {
                    return SwitchListTile(
                      title: Text(AppLocalizations.of(context).confirmVoiceMessage),
                      subtitle: Text(AppLocalizations.of(context).confirmVoiceSubtitle),
                      value: confirmVoice,
                      onChanged: (val) async =>
                          await SettingsManager.setConfirmVoiceUpload(val),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLiquidGlassSection(
            icon: Icons.bug_report_rounded,
            title: AppLocalizations.of(context).debugTitle,
            subtitle: AppLocalizations.of(context).debugSubtitle,
            section: SectionType.debug,
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.debugMode,
                  builder: (_, debugEnabled, __) {
                    return SwitchListTile(
                      title: Text(AppLocalizations.of(context).debugMode),
                      subtitle: Text(AppLocalizations.of(context).debugModeSubtitle),
                      value: debugEnabled,
                      onChanged: (val) async =>
                          await SettingsManager.setDebugMode(val),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.enableLogging,
                  builder: (_, loggingEnabled, __) {
                    return SwitchListTile(
                      title: Text(AppLocalizations.of(context).enableFileLogging),
                      subtitle: Text(AppLocalizations.of(context).enableFileLoggingSubtitle),
                      value: loggingEnabled,
                      onChanged: (val) async =>
                          await SettingsManager.setEnableLogging(val),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildLiquidGlassButton(
                  icon: Icons.delete_outline,
                  label: AppLocalizations.of(context).deleteAllLogs,
                  fontSize: 14,
                  onPressed: _deleteAllLogs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildLiquidGlassSection(
            icon: Icons.info_outline_rounded,
            title: AppLocalizations.of(context).contactTitle,
            subtitle: AppLocalizations.of(context).contactSubtitle,
            section: SectionType.contact,
            expandedContent: _buildContactContent(),
          ),
          const SizedBox(height: 20),
          
          Center( 
            child: Text(
              'open-beta 1.2a',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '\u00a9 2026 WARDCORE',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildContactContent() {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    Widget contactItem({
      required IconData icon,
      required String label,
      required String value,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        contactItem(
          icon: Icons.language_rounded,
          label: l.contactWebsite,
          value: 'onyx.wardcore.com',
          onTap: () => openUrl('https://onyx.wardcore.com/'),
        ),
        Divider(height: 1, indent: 50, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        contactItem(
          icon: Icons.code_rounded,
          label: l.contactRepository,
          value: 'github.com/wardcore-dev/onyx',
          onTap: () => openUrl('https://github.com/wardcore-dev/onyx'),
        ),
        Divider(height: 1, indent: 50, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        contactItem(
          icon: Icons.dns_rounded,
          label: l.contactRepositoryServer,
          value: 'github.com/wardcore-dev/onyx-server',
          onTap: () => openUrl('https://github.com/wardcore-dev/onyx-server'),
        ),
        Divider(height: 1, indent: 50, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        contactItem(
          icon: Icons.mail_outline_rounded,
          label: l.contactEmail,
          value: 'wardcorebusiness@proton.me',
          onTap: () => openUrl('mailto:wardcorebusiness@proton.me'),
        ),
      ],
    );
  }

  Widget _buildNotificationsContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.tertiary.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: colorScheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).notifWarning,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onTertiaryContainer,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 4),

        ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.notificationsEnabled,
          builder: (_, enabled, __) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).notifEnableLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                AppLocalizations.of(context).notifEnabledSubtitle(enabled),
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant),
              ),
              value: enabled,
              onChanged: (v) => SettingsManager.setNotificationsEnabled(v),
            );
          },
        ),

        if (isDesktop) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsManager.notifSoundEnabled,
            builder: (_, soundEnabled, __) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.of(context).notifSoundEnableLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  AppLocalizations.of(context).notifSoundEnabledSubtitle(soundEnabled),
                  style: TextStyle(
                      fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                value: soundEnabled,
                onChanged: (v) => SettingsManager.setNotifSoundEnabled(v),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).notifSoundChooseLabel,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: SettingsManager.notifSound,
            builder: (_, currentSound, __) {
              const builtInSounds = ['notification0', 'notification1', 'notification2'];
              
              final allSounds = <String>[...builtInSounds];
              if (currentSound.startsWith('custom:') && !allSounds.contains(currentSound)) {
                allSounds.add(currentSound);
              }

              return Column(
                children: [
                  ...allSounds.map((sound) {
                    final selected = currentSound == sound;
                    final isCustom = sound.startsWith('custom:');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () {
                          SettingsManager.setNotifSound(sound);
                          
                          try {
                            if (isCustom) {
                              AudioPlayer().play(DeviceFileSource(sound.substring(7)));
                            } else {
                              AudioPlayer().play(AssetSource('$sound.wav'));
                            }
                          } catch (e) { debugPrint('[err] $e'); }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? colorScheme.primaryContainer.withValues(alpha: 0.85)
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
                              width: selected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.check_circle : Icons.play_circle_outline,
                                size: 20,
                                color: selected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).localizeNotifSound(sound),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    color: selected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['wav', 'mp3', 'm4a', 'ogg', 'aac', 'opus'],
                          );
                          if (result == null || result.files.isEmpty) return;
                          final filePath = result.files.first.path;
                          if (filePath == null) return;

                          final appSupport = await getApplicationDocumentsDirectory();
                          final soundsDir = Directory('${appSupport.path}/custom_sounds');
                          await soundsDir.create(recursive: true);
                          final fileName = p.basename(filePath);
                          final destFile = File('${soundsDir.path}/$fileName');
                          await File(filePath).copy(destFile.path);

                          final soundKey = 'custom:${destFile.path}';
                          SettingsManager.setNotifSound(soundKey);

                          try {
                            AudioPlayer().play(DeviceFileSource(destFile.path));
                          } catch (e) { debugPrint('[err] $e'); }

                          if (mounted) {
                            rootScreenKey.currentState?.showSnack(
                              AppLocalizations.of(context).notifSoundCustomLoaded,
                            );
                          }
                        } catch (e) {
                          debugPrint('[NotifSound] pick error: $e');
                          if (mounted) {
                            rootScreenKey.currentState?.showSnack(
                              '${AppLocalizations.of(context).notifSoundCustomError}: $e',
                            );
                          }
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.file_upload_outlined, size: 20,
                                color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context).notifSoundCustom,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      AppLocalizations.of(context).notifSoundCustomInvalidFormat,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],

        if (Platform.isWindows) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsManager.launchAtStartup,
            builder: (_, autostartEnabled, __) {
              return Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context).launchAtStartupLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context).launchAtStartupSubtitle,
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    ),
                    value: autostartEnabled,
                    onChanged: (val) async {
                      // Pre-capture everything from context before the first await
                      final l10n = AppLocalizations.of(context);
                      final scaffold = ScaffoldMessenger.of(context);
                      final cs = Theme.of(context).colorScheme;

                      void snack(String msg) {
                        final bg = SettingsManager.getElementColor(
                          cs.surfaceContainerHighest,
                          SettingsManager.elementBrightness.value,
                        ).withValues(alpha: SettingsManager.elementOpacity.value);
                        scaffold
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text(msg,
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center),
                            backgroundColor: bg,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                            elevation: 4,
                            duration: const Duration(seconds: 2),
                          ));
                      }

                      try {
                        if (val) {
                          await AutostartManager.enable();
                        } else {
                          await AutostartManager.disable();
                        }
                        final actual = await AutostartManager.isEnabled();
                        if (actual != val) {
                          snack(l10n.launchAtStartupFailed);
                          return;
                        }
                        await SettingsManager.setLaunchAtStartup(val);
                        snack(val ? l10n.launchAtStartupEnabled : l10n.launchAtStartupDisabled);
                      } catch (e) {
                        debugPrint('[autostart] Failed to toggle: $e');
                        snack(l10n.launchAtStartupFailed);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],

        if (isDesktop && !Platform.isMacOS) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.picture_in_picture_rounded, size: 16, color: colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).notifPopupPosition,
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).notifPopupPositionSubtitle,
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: SettingsManager.notificationPosition,
            builder: (_, pos, __) {
              
              const positionKeys = ['top_left', 'top_right', 'bottom_left', 'bottom_right'];
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 3.4,
                children: positionKeys.map((String posKey) {
                  final selected = pos == posKey;
                  return GestureDetector(
                    onTap: () =>
                        SettingsManager.setNotificationPosition(posKey),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primaryContainer
                                .withValues(alpha: 0.85)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                          width: selected ? 1.5 : 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context).localizeNotifPosition(posKey),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildProxyContent() {
    final colorScheme = Theme.of(context).colorScheme;

    InputDecoration fieldDecor(String label, {String? hint, bool enabled = true}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: enabled ? 0.5 : 0.2),
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );

    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.proxyEnabled,
      builder: (_, enabled, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).useProxy,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                enabled ? AppLocalizations.of(context).proxyRouted : AppLocalizations.of(context).proxyDirectConnection,
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              value: enabled,
              onChanged: (v) {
                SettingsManager.setProxyEnabled(v);
                if (!v) proxyActiveNotifier.value = false;
              },
            ),

            if (enabled)
              ValueListenableBuilder<bool>(
                valueListenable: proxyActiveNotifier,
                builder: (_, connected, __) {
                  final host = SettingsManager.proxyHost.value.trim();
                  final port = SettingsManager.proxyPort.value.trim();
                  final server = host.isNotEmpty
                      ? '$host${port.isNotEmpty ? ':$port' : ''}'
                      : null;
                  final statusColor = connected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          connected
                              ? Icons.shield_rounded
                              : Icons.shield_outlined,
                          size: 15,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            connected
                                ? '${AppLocalizations.of(context).proxyConnectedStatus}${server != null ? ' · $server' : ''}'
                                : '${AppLocalizations.of(context).proxyNotConnectedStatus}${server != null ? ' · $server' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const Divider(),
            const SizedBox(height: 8),

            Text(AppLocalizations.of(context).proxyType,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: SettingsManager.proxyType,
              builder: (_, type, __) {
                return Row(
                  children: [
                    for (final (val, label) in [
                      ('http', 'HTTP'),
                      ('socks5', 'SOCKS5'),
                    ]) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: enabled
                              ? () => SettingsManager.setProxyType(val)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: type == val
                                  ? colorScheme.primaryContainer
                                      .withValues(alpha: enabled ? 0.85 : 0.4)
                                  : colorScheme.surfaceContainerHighest
                                      .withValues(alpha: enabled ? 0.45 : 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: type == val
                                    ? colorScheme.primary
                                        .withValues(alpha: enabled ? 1.0 : 0.3)
                                    : colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                width: type == val ? 1.5 : 0.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: type == val
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: type == val
                                    ? colorScheme.onPrimaryContainer
                                        .withValues(alpha: enabled ? 1.0 : 0.5)
                                    : colorScheme.onSurfaceVariant
                                        .withValues(alpha: enabled ? 1.0 : 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (val != 'socks5') const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _proxyHostController,
                    enabled: enabled,
                    decoration: fieldDecor(AppLocalizations.of(context).proxyHost, hint: '127.0.0.1'),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (v) => SettingsManager.setProxyHost(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _proxyPortController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecor(AppLocalizations.of(context).proxyPort, hint: '8080'),
                    style: const TextStyle(fontSize: 14),
                    onChanged: (v) => SettingsManager.setProxyPort(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _proxyUsernameController,
              enabled: enabled,
              decoration: fieldDecor(AppLocalizations.of(context).proxyLoginOptional),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) => SettingsManager.setProxyUsername(v),
            ),
            const SizedBox(height: 12),

            StatefulBuilder(
              builder: (_, setLocal) => TextField(
                controller: _proxyPasswordController,
                enabled: enabled,
                obscureText: !_proxyPasswordVisible,
                decoration: fieldDecor(AppLocalizations.of(context).proxyPasswordOptional).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_proxyPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(
                        () => _proxyPasswordVisible = !_proxyPasswordVisible),
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (v) => SettingsManager.setProxyPassword(v),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            if (_proxyTestResult != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _proxyTestResult!.startsWith('')
                      ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _proxyTestResult!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _proxyTestResult!.startsWith('')
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildLiquidGlassButton(
                  icon: _proxyTesting
                      ? Icons.hourglass_empty
                      : Icons.network_check_rounded,
                  label: _proxyTesting ? AppLocalizations.of(context).proxyTesting : AppLocalizations.of(context).testProxy,
                  fontSize: 14,
                  onPressed: enabled && !_proxyTesting
                      ? () async {
                          setState(() {
                            _proxyTesting = true;
                            _proxyTestResult = null;
                          });
                          final (ok, msg) =
                              await ProxyManager.testConnection();
                          if (mounted) {
                            setState(() {
                              _proxyTesting = false;
                              _proxyTestResult =
                                  ok ? ' $msg' : ' $msg';
                            });
                          }
                        }
                      : null,
                ),
                _buildLiquidGlassButton(
                  icon: Icons.check_circle_outline_rounded,
                  label: AppLocalizations.of(context).proxyApplyReconnect,
                  fontSize: 14,
                  onPressed: () async {
                    final host = SettingsManager.proxyHost.value.trim();
                    final port = int.tryParse(SettingsManager.proxyPort.value.trim()) ?? 0;
                    if (host.isEmpty || port <= 0) return;
                    
                    await SettingsManager.setProxyEnabled(true);
                    ProxyManager.applyFromSettings();
                    proxyActiveNotifier.value = false;
                    widget.onDisconnectWs();
                    Future.delayed(const Duration(milliseconds: 400),
                        widget.onConnectWs);
                    if (mounted) setState(() => _proxyTestResult = null);
                    
                    final (ok, _) = await ProxyManager.testConnection();
                    if (ok && SettingsManager.proxyEnabled.value) {
                      proxyActiveNotifier.value = true;
                    }
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: proxyActiveNotifier,
                  builder: (_, active, __) {
                    if (!active) return const SizedBox.shrink();
                    return _buildLiquidGlassButton(
                      icon: Icons.link_off_rounded,
                      label: AppLocalizations.of(context).disconnect,
                      fontSize: 14,
                      color: colorScheme.error,
                      onPressed: () {
                        ProxyManager.reset();
                        proxyActiveNotifier.value = false;
                        SettingsManager.setProxyEnabled(false);
                        widget.onDisconnectWs();
                        Future.delayed(const Duration(milliseconds: 400),
                            widget.onConnectWs);
                        if (mounted) setState(() => _proxyTestResult = null);
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageContent() {
    final l = AppLocalizations.of(context);

    const languages = [
      {'code': 'en', 'label': 'English', 'native': 'English', 'flag': '🇺🇸'},
      {'code': 'ru', 'label': 'Russian', 'native': 'Русский', 'flag': '🇷🇺'},
    ];

    return ValueListenableBuilder<Locale>(
      valueListenable: SettingsManager.appLocale,
      builder: (context, currentLocale, _) {
        final current = languages.firstWhere(
          (lang) => lang['code'] == currentLocale.languageCode,
          orElse: () => languages.first,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.languageTitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      final cs = Theme.of(ctx).colorScheme;
                      return ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.elementBrightness,
                        builder: (_, brightness, __) {
                          final sheetColor = SettingsManager.getElementColor(
                            cs.surfaceContainerHighest,
                            brightness,
                          );
                          return DraggableScrollableSheet(
                            initialChildSize: 0.4,
                            minChildSize: 0.3,
                            maxChildSize: 0.6,
                            expand: false,
                            builder: (_, scrollController) {
                              return Container(
                                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                decoration: BoxDecoration(
                                  color: sheetColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 36,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: cs.onSurface.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      child: Text(
                                        l.languageTitle,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        controller: scrollController,
                                        padding: const EdgeInsets.only(bottom: 8),
                                        children: languages.map((lang) {
                                          final isSelected =
                                              currentLocale.languageCode == lang['code'];
                                          return ListTile(
                                            leading: Text(
                                              lang['flag']!,
                                              style: const TextStyle(fontSize: 22),
                                            ),
                                            title: Text(lang['native']!),
                                            subtitle: Text(
                                              lang['label']!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            trailing: isSelected
                                                ? Icon(Icons.check_circle_rounded,
                                                    color: cs.primary)
                                                : Icon(
                                                    Icons.radio_button_unchecked_rounded,
                                                    color: cs.onSurface
                                                        .withValues(alpha: 0.3),
                                                  ),
                                            selected: isSelected,
                                            selectedTileColor:
                                                cs.primary.withValues(alpha: 0.08),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            onTap: () async {
                                              await SettingsManager.setAppLocale(
                                                  Locale(lang['code']!));
                                              if (ctx.mounted) {
                                                Navigator.of(ctx).pop();
                                              }
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            current['flag']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current['native']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                current['label']!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiquidGlassSection({
    required String title,
    required String subtitle,
    required SectionType section,
    required Widget expandedContent,
    IconData? icon,
  }) {
    final isExpanded = _expandedSection == section;
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, ___) {
            final baseColor = SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest,
              brightness,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _toggleSection(section),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, size: 18, color: colorScheme.primary),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        RotationTransition(
                          turns: Tween<double>(begin: 0.0, end: 0.5).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: Interval(
                                isExpanded ? 0.5 : 0.0,
                                isExpanded ? 1.0 : 0.5,
                                curve: Curves.easeInOut,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: isExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: expandedContent,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _featureRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    double fontSize = 15,
    double? buttonWidth,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, ___) {
            final baseColor = SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest,
              brightness,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: buttonWidth,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18, color: effectiveColor),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  color: effectiveColor,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }
}

enum SectionType { security, keyManagement, notifications, appearance, language, cache, connection, proxy, interact, debug, contact }