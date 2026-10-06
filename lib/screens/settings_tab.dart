// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute, ValueListenable, kIsWeb;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;
import '../utils/onyx_base_dir.dart';
import '../widgets/onyx_dialog.dart';
import '../utils/settings_backup.dart';
import '../services/backup/backup_service.dart';
import '../services/wardlink/wardlink_tombstones.dart';
import '../services/wardlink/wardlink_pending_deletions.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../managers/secure_store.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../enums/liquid_glass_quality.dart';
import '../enums/media_preload_mode.dart';
import '../enums/scroll_down_button_position.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_extra.dart';
import 'pin_code_screen.dart';
import 'decoy_setup_screen.dart';
import 'cache_manager_screen.dart';
import 'active_sessions_screen.dart' show ActiveDevicesPanel;
import 'package:local_auth/local_auth.dart';
import '../globals.dart';
import '../widgets/adaptive_blur.dart';
import '../widgets/adaptive_glass_card.dart';
import '../models/app_themes.dart';
import '../models/font_family.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/autostart_manager.dart';
import '../managers/blocklist_manager.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show MediaDeviceInfo, navigator;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../widgets/media_picker_sheet.dart';
import '../services/wardlink/wardlink_sync_service.dart';
import '../services/wardlink/wardlink_paired_devices.dart';
import '../services/mesh/mesh_manager.dart';
import '../services/onion/onion_transport_service.dart';
import '../services/onion/onion_paired_peers.dart';
import '../services/onion/onion_requests.dart';
import 'mesh_graph_screen.dart' show showMeshRadarSheet;
import 'package:permission_handler/permission_handler.dart';
import '../managers/trash_manager.dart';
import '../widgets/inline_search_bar.dart';
import '../widgets/message_bubble.dart';

void _showStyledSnack(BuildContext context, String text,
    {Duration duration = const Duration(seconds: 2)}) {
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
        style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500),
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
  const _Coin(
      {required this.name,
      required this.symbol,
      required this.address,
      required this.color,
      required this.pros,
      required this.cons});
}

const _kCoins = [
  _Coin(
    name: 'Bitcoin',
    symbol: 'BTC',
    color: Color(0xFFF7931A),
    address: 'bc1qpw2amf3j7w4swunx8mdfvk703uq3uadg9748tm',
    pros: [
      'Most widely accepted',
      'Available on any exchange',
      'Maximum liquidity'
    ],
    cons: [
      'High transaction fees',
      'Transactions are public',
      'Slow confirmation (~10 min)'
    ],
  ),
  _Coin(
    name: 'Litecoin',
    symbol: 'LTC',
    color: Color(0xFF345D9D),
    address: 'ltc1qx37f0k2mckxp2je3cplkfvg7473nq8udpk4kg9',
    pros: [
      'Low fees',
      'Fast confirmation (~2.5 min)',
      'Available on most exchanges'
    ],
    cons: ['Transactions are public', 'Less popular than BTC'],
  ),
  _Coin(
    name: 'Monero',
    symbol: 'XMR',
    color: Color(0xFFFF6600),
    address:
        '88R9RYWEL38Aj7As8KnT9bia7HyQkPf7AC9XK8HuDofaevudWAkLw9sjMhkQ4aNvzVdjdgdWSpvTw8RyHePcuHov6cwBTT2',
    pros: [
      'Fully anonymous by default',
      'Untraceable transactions',
      'Best fit for a privacy app'
    ],
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
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
          Text(AppLocalizations.of(context).supportOnyx,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context).chooseCrypto,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: active
                          ? c.color.withValues(alpha: 0.15)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: active
                              ? c.color
                              : cs.outlineVariant.withValues(alpha: 0.3),
                          width: active ? 1.5 : 0.8),
                    ),
                    child: Text(
                      c.symbol,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? c.color
                              : cs.onSurface.withValues(alpha: 0.6)),
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
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: coin.color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...coin.pros.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 14, color: Colors.green.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  AppLocalizations.of(context)
                                      .localizeDonateText(p),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.85)))),
                        ]),
                      )),
                  if (coin.cons.isNotEmpty) const SizedBox(height: 4),
                  ...coin.cons.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          Icon(Icons.remove_circle_outline_rounded,
                              size: 14, color: Colors.red.shade300),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  AppLocalizations.of(context)
                                      .localizeDonateText(c),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.85)))),
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
              borderRadius: BorderRadius.circular(28),
            ),
            child: QrImageView(
              data: coin.address,
              version: QrVersions.auto,
              size: 180,
              eyeStyle:
                  QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    coin.address,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: cs.onSurface.withValues(alpha: 0.8)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: coin.address));
                    _showStyledSnack(context,
                        '${coin.symbol} ${AppLocalizations.of(context).addressCopied}',
                        duration: const Duration(seconds: 1));
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
  // Server now allows any trusted device (not just primary) to manage keys —
  // see requireTrustedDevice on the backend. Client gating follows that.
  final bool isE2eTrustedDevice;
  final Future<void> Function(
          String passphrase, String oldPassword, String newPassword)
      onChangePassword;
  final void Function(String username) onOpenChat;
  // Whether this tab is the one currently shown to the user. The PageView
  // hosting all bottom-nav tabs keeps every page mounted even when off-screen
  // (swiped away), so without this flag the settings search query would
  // silently survive a tab switch. Defaults to true for callers that mount
  // this tab standalone (e.g. the desktop left-sidebar layout, which already
  // disposes the widget on tab switch).
  final bool isActive;

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
    this.isE2eTrustedDevice = false,
    required this.onChangePassword,
    required this.onOpenChat,
    this.isActive = true,
  }) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  double? _cacheSizeMb;
  bool _cacheSizeLoaded = false;
  bool _purging = false;
  double? _orphanedSizeMb;
  bool _orphanedSizeLoaded = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isVisible = false;

  List<MediaDeviceInfo>? _audioDevices;

  SectionType? _expandedSection;
  // Accordion, same as _expandedSection above: opening a subsection closes
  // whichever other one was open (only one parent section is ever visible
  // at a time, so this only ever needs to track one open subsection).
  String? _expandedSubsectionKey;

  final TextEditingController _settingsSearchCtrl = TextEditingController();
  final GlobalKey _settingsSearchBarKey = GlobalKey();
  String _settingsSearchQuery = '';

  // Ambient context for search breadcrumb rendering (set during build, not setState)
  String? _searchSectionLabel;
  IconData? _searchSectionIcon;

  late TextEditingController _statusOnlineController;
  late TextEditingController _statusOfflineController;

  bool _isUpdatingControllers = false;

  // Cached future for old-folder check — avoids redoing filesystem I/O on every rebuild.
  Future<({String path, bool hasUserData})>? _oldFolderInfoFuture;

  late String _localStatusVisibility;
  bool _localHideFromSearch = false;


  @override
  void initState() {
    super.initState();

    _localStatusVisibility = SettingsManager.statusVisibility.value;
    _localHideFromSearch = SettingsManager.hideFromSearch.value;

    _statusOnlineController = TextEditingController(
      text: SettingsManager.statusOnline.value,
    );
    _statusOfflineController = TextEditingController(
      text: SettingsManager.statusOffline.value,
    );

    SettingsManager.statusOnline.addListener(_updateStatusOnlineController);
    SettingsManager.statusOffline.addListener(_updateStatusOfflineController);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      navigator.mediaDevices.enumerateDevices().then((devices) {
        if (mounted) setState(() => _audioDevices = devices);
      });
    }

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
        _loadOrphanedSize();
      }
    });
  }

  @override
  void didUpdateWidget(SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Leaving the tab (swipe or bottom-nav tap both flow through the same
    // isActive flag) clears whatever the user typed in the search box, so it
    // doesn't linger stale next time they open Settings.
    if (oldWidget.isActive &&
        !widget.isActive &&
        _settingsSearchQuery.isNotEmpty) {
      _settingsSearchCtrl.clear();
      setState(() => _settingsSearchQuery = '');
    }
  }

  @override
  void dispose() {
    SettingsManager.statusOnline.removeListener(_updateStatusOnlineController);
    SettingsManager.statusOffline
        .removeListener(_updateStatusOfflineController);
    _statusOnlineController.dispose();
    _statusOfflineController.dispose();
    _settingsSearchCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _sectionVisible(String title, String subtitle,
      [List<String> keywords = const []]) {
    if (_settingsSearchQuery.isEmpty) return true;
    final q = _settingsSearchQuery.toLowerCase().trim();
    if (q.isEmpty) return true;
    final words = q.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    if (words.isEmpty) return false;
    // Each item is checked independently — prevents false positives from words
    // scattered across unrelated keywords (e.g. "chat" in one key, "display" in another).
    for (final item in [title, subtitle, ...keywords]) {
      final lower = item.toLowerCase();
      if (lower.contains(q) || words.every((w) => lower.contains(w)))
        return true;
    }
    return false;
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
      final dir = await getOnyxSupportDirectory();

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

  Future<void> _loadOrphanedSize() async {
    if (_orphanedSizeLoaded) return;
    try {
      final bytes = await rootScreenKey.currentState?.scanOrphanedCacheBytes();
      if (mounted) {
        setState(() {
          _orphanedSizeMb = bytes != null ? bytes / (1024 * 1024) : null;
          _orphanedSizeLoaded = true;
        });
      }
    } catch (_) {}
  }

  void _toggleSection(SectionType section) {
    setState(() {
      _expandedSection = _expandedSection == section ? null : section;
      _expandedSubsectionKey = null;
    });
  }

  Future<void> _openCacheManager() async {
    await showCacheManagerSheet(context);

    setState(() {
      _cacheSizeMb = null;
      _cacheSizeLoaded = false;
    });
    _loadTotalCacheSize();
  }

  Future<void> _purgeOrphanedCache() async {
    final l = AppLocalizations.of(context);
    setState(() => _purging = true);
    try {
      final result = await rootScreenKey.currentState?.purgeOrphanedCache();
      if (!mounted) return;
      final msg = result == null
          ? l.orphanedCleanupAppNotReady
          : result.files == 0
              ? l.orphanedCleanupNoFiles
              : l.orphanedCleanupDeleted(
                  result.files,
                  (result.bytes / 1024 / 1024).toStringAsFixed(1),
                );
      _showSnack(msg);
      setState(() {
        _purging = false;
        _cacheSizeMb = null;
        _cacheSizeLoaded = false;
        _orphanedSizeMb = null;
        _orphanedSizeLoaded = false;
      });
      _loadTotalCacheSize();
      _loadOrphanedSize();
    } catch (e) {
      if (mounted) {
        setState(() => _purging = false);
        _showSnack('${l.error}: $e');
      }
    }
  }

  Widget _buildResetOption({
    required ColorScheme colorScheme,
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String title,
    required String subtitle,
  }) {
    final enabled = onChanged != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? () => onChanged(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? colorScheme.error.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? colorScheme.error.withValues(alpha: 0.35)
                : colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface
                            .withValues(alpha: enabled ? 0.6 : 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _factoryReset() async {
    final username = await AccountManager.getCurrentAccount();

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final resettingMsg = l.resetting;

    final result = await showOnyxDialog<({bool deleteAccount, bool deleteLocal})>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        bool deleteAccount = false;
        bool deleteLocal = false;
        return StatefulBuilder(
          builder: (ctx, setState) => OnyxDialogShell(
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
                      color: colorScheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.restart_alt_rounded,
                        size: 20, color: colorScheme.error),
                  ),
                  title: Text(
                    l.factoryReset,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  onClose: () => Navigator.of(ctx).pop(null),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    l.factoryResetHint,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildResetOption(
                    colorScheme: colorScheme,
                    value: deleteLocal,
                    onChanged: (v) => setState(() => deleteLocal = v ?? false),
                    title: l.resetDeleteLocal,
                    subtitle: l.resetDeleteLocalSubtitle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          padding: kOnyxDialogButtonPadding,
                          shape: kOnyxDialogButtonShape,
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                        ),
                        onPressed: (deleteAccount || deleteLocal)
                            ? () => Navigator.of(ctx).pop(
                                  (
                                    deleteAccount: deleteAccount,
                                    deleteLocal: deleteLocal
                                  ),
                                )
                            : null,
                        child: Text(l.reset),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(null),
                        style: OutlinedButton.styleFrom(
                          padding: kOnyxDialogButtonPadding,
                          shape: kOnyxDialogButtonShape,
                        ),
                        child: Text(l.cancel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    // Double confirmation before an irreversible destructive action:
    // first a plain "are you sure", then a harsher final check.
    final step1 = await showOnyxConfirmDialog(
      context: context,
      title: l.resetConfirmStep1Title,
      message: l.resetConfirmStep1Message,
      confirmLabel: l.yes,
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (step1 != true || !mounted) return;

    final step2 = await showOnyxConfirmDialog(
      context: context,
      title: l.resetConfirmStep2Title,
      message: l.resetConfirmStep2Message,
      confirmLabel: l.reset,
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (step2 != true || !mounted) return;

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
            throw Exception(
                'Server returned ${res.statusCode} while deleting account');
          }
        }
        debugPrint(' Account deleted from server');
      }

      if (result.deleteLocal) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint(' Cleared SharedPreferences');

        final appSupport = await getOnyxSupportDirectory();
        if (await appSupport.exists()) {
          await appSupport.delete(recursive: true);
          await appSupport.create(recursive: true);
          debugPrint(' Cleared Application Support directory');
        }

        final appDocs = await getOnyxDocumentsDirectory();
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
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .doneRestarting);
        await Future.delayed(const Duration(seconds: 2));
        await widget.onLogout();
      }
    } catch (e, st) {
      debugPrint(' _factoryReset error: $e\n$st');
      if (mounted) {
        _showStyledSnack(context,
            '${lookupAppLocalizations(SettingsManager.appLocale.value).resetFailed}: $e',
            duration: const Duration(seconds: 4));
      }
    }
  }

  Future<void> _showStatusDialog() async {
    final l = AppLocalizations.of(context);
    final savedOkMsg = l.statusSavedOk;
    final savedFailMsg = l.statusSavedFail;
    String localVisibility = _localStatusVisibility;
    final onlineCtrl =
        TextEditingController(text: SettingsManager.statusOnline.value);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Status',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 187),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final cs = Theme.of(ctx).colorScheme;
            const btnShape = RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(50)));
            const btnPadding = EdgeInsets.symmetric(vertical: 13);
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                        // ── Header ──────────────────────────────────────
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
                                child: Icon(Icons.manage_accounts_rounded,
                                    size: 18, color: cs.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l.statusSettings,
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: cs.onSurface)),
                              ),
                              GestureDetector(
                                onTap: () {
                                  onlineCtrl.dispose();
                                  Navigator.of(ctx).pop();
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cs.onSurface.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.close_rounded,
                                      size: 18,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.55)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Content ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Visibility (iOS-style draggable pill switch)
                              Row(
                                children: [
                                  Icon(Icons.visibility_rounded,
                                      size: 18,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(l.statusShowMyStatus,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface)),
                                        const SizedBox(height: 2),
                                        Text(l.statusShowMyStatusHint,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.55))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Switch(
                                    value: localVisibility != 'hide',
                                    onChanged: (v) => setDialogState(() =>
                                        localVisibility = v ? 'show' : 'hide'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Text fields
                              Row(
                                children: [
                                  Icon(Icons.edit_rounded,
                                      size: 15,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.6)),
                                  const SizedBox(width: 6),
                                  Text(l.statusCustomText,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.6))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: onlineCtrl,
                                decoration: InputDecoration(
                                  labelText: l.statusWhenOnline,
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
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
                                    borderSide: BorderSide(
                                        color: cs.primary, width: 1.4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    padding: btnPadding, shape: btnShape),
                                onPressed: () async {
                                  final onlineText =
                                      onlineCtrl.text.trim().isEmpty
                                          ? 'online'
                                          : onlineCtrl.text.trim();
                                  _isUpdatingControllers = true;
                                  await SettingsManager.setStatusVisibility(
                                      localVisibility);
                                  await SettingsManager.setStatusOnline(
                                      onlineText);
                                  _isUpdatingControllers = false;
                                  setState(() =>
                                      _localStatusVisibility = localVisibility);
                                  onlineCtrl.dispose();
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
      },
    );
  }

  Future<bool> _syncStatusSettings() async {
    if (kCentralServerRemoved) {
      // Presence travels peer-to-peer over Tor; the transport re-broadcasts
      // automatically whenever these settings change.
      return true;
    }
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

          final vis =
              Map<String, String>.from(userStatusVisibilityNotifier.value);

          if (SettingsManager.statusVisibility.value == 'hide') {
            statuses.remove(username);
            userStatusNotifier.value = statuses;
            final s = Set<String>.from(onlineUsersNotifier.value)
              ..remove(username);
            onlineUsersNotifier.value = s;
            vis[username] = 'hide';
            userStatusVisibilityNotifier.value = vis;
          } else {
            statuses[username] = SettingsManager.statusOnline.value;
            userStatusNotifier.value = statuses;
            final s = Set<String>.from(onlineUsersNotifier.value)
              ..add(username);
            onlineUsersNotifier.value = s;
            vis[username] = 'show';
            userStatusVisibilityNotifier.value = vis;
            try {
              rootScreenKey.currentState?.sendPresence('online');
            } catch (e) {
              debugPrint('[err] $e');
            }
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

  Future<bool> _syncPrivacySettings() async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return false;

      final token = await AccountManager.getToken(username);
      if (token == null) return false;

      final res = await http.post(
        Uri.parse('$serverBase/me/privacy-settings'),
        headers: {
          'authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'hide_from_search': SettingsManager.hideFromSearch.value,
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[err] Privacy sync error: $e');
      return false;
    }
  }

  Future<void> _deleteAllLogs() async {
    final l = AppLocalizations.of(context);
    final noLogsMsg = l.noLogsFound;
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.deleteAllLogsTitle,
      message: l.deleteAllLogsContent,
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
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
        final docs = await getOnyxDocumentsDirectory();
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
          ? lookupAppLocalizations(SettingsManager.appLocale.value)
              .deletedLogsCount(deleted)
          : noLogsMsg);
    } catch (e) {
      _showSnack(' $e');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    _showStyledSnack(context, text, duration: const Duration(seconds: 3));
  }

  Future<void> _pickChatBackground() async {
    try {
      final String? pickedPath;
      if (Platform.isAndroid || Platform.isIOS) {
        pickedPath = await showWallpaperPickerSheet(context);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'bmp',
            'heic',
            'heif',
            'mp4',
            'mov',
            'avi',
            'mkv',
            'webm',
            'flv',
            'm4v',
          ],
        );
        pickedPath = result?.files.single.path;
      }
      if (pickedPath == null) return;

      final ext = p.extension(pickedPath).toLowerCase();
      const videoExts = {
        '.mp4',
        '.mov',
        '.avi',
        '.mkv',
        '.webm',
        '.flv',
        '.m4v'
      };
      final isVideo = videoExts.contains(ext);

      final dir = await getOnyxSupportDirectory();
      final bgDir = Directory('${dir.path}/backgrounds');
      await bgDir.create(recursive: true);

      if (isVideo) {
        // Clear old video backgrounds
        try {
          final files = bgDir.listSync().whereType<File>().toList();
          for (final f in files) {
            if (p.basename(f.path).startsWith('chat_video_bg')) {
              try {
                await f.delete();
              } catch (e) {
                debugPrint('[err] $e');
              }
            }
          }
        } catch (e) {
          debugPrint('[err] $e');
        }

        final dest =
            '${bgDir.path}/chat_video_bg_${DateTime.now().millisecondsSinceEpoch}$ext';
        await File(pickedPath).copy(dest);
        await SettingsManager.setChatVideoBackground(dest);
        await SettingsManager.setChatBackground(null);
        _showSnack('Video wallpaper set');
      } else {
        // Clear old image backgrounds
        try {
          final files = bgDir.listSync().whereType<File>().toList();
          for (final f in files) {
            final name = p.basename(f.path);
            if (name.startsWith('chat_bg') &&
                !name.startsWith('chat_video_bg')) {
              try {
                await f.delete();
              } catch (e) {
                debugPrint('[err] $e');
              }
            }
          }
        } catch (e) {
          debugPrint('[err] $e');
        }

        final dest =
            '${bgDir.path}/chat_bg_${DateTime.now().millisecondsSinceEpoch}$ext';
        await File(pickedPath).copy(dest);

        try {
          final prev = SettingsManager.chatBackground.value;
          if (prev != null) await FileImage(File(prev)).evict();
          await FileImage(File(dest)).evict();
        } catch (e) {
          debugPrint('[err] $e');
        }

        await SettingsManager.setChatBackground(dest);
        await SettingsManager.setChatVideoBackground(null);
        _showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value).chatBgSet);
      }
    } catch (e) {
      _showSnack('$e');
    }
  }

  Future<void> _clearChatBackground() async {
    final l = AppLocalizations.of(context);
    final clearedMsg = l.chatBgCleared;
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.clearBgTitle,
      message: l.clearBgContent,
      confirmLabel: l.clear,
      icon: Icons.image_not_supported_outlined,
    );
    if (confirmed != true) return;

    try {
      final dir = await getOnyxSupportDirectory();
      final bgDir = Directory('${dir.path}/backgrounds');
      if (await bgDir.exists()) {
        final files = bgDir.listSync().whereType<File>().toList();
        for (final f in files) {
          final name = p.basename(f.path);
          if (name.startsWith('chat_bg')) {
            try {
              await f.delete();
            } catch (e) {
              debugPrint('[err] $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[err] $e');
    }

    try {
      final cur = SettingsManager.chatBackground.value;
      if (cur != null) await FileImage(File(cur)).evict();
    } catch (e) {
      debugPrint('[err] $e');
    }

    await SettingsManager.setChatBackground(null);
    _showSnack(clearedMsg);
  }

  Future<void> _clearChatVideoBackground() async {
    final clearedMsg = AppLocalizations.of(context).chatBgCleared;
    try {
      final dir = await getOnyxSupportDirectory();
      final bgDir = Directory('${dir.path}/backgrounds');
      if (await bgDir.exists()) {
        for (final f in bgDir.listSync().whereType<File>()) {
          if (p.basename(f.path).startsWith('chat_video_bg')) {
            try {
              await f.delete();
            } catch (e) {
              debugPrint('[err] $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[err] $e');
    }
    await SettingsManager.setChatVideoBackground(null);
    _showSnack(clearedMsg);
  }

  void _showPresetsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PresetsSheet(
        currentTheme: widget.currentTheme,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        onSnack: _showSnack,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    return FadeTransition(
      opacity: _isVisible ? _fadeAnimation : const AlwaysStoppedAnimation(0),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 8 + MediaQuery.paddingOf(context).bottom),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
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
                    border: Border.all(
                        color: themeColor.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_rounded, size: 17, color: themeColor),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context).supportOnyx,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: themeColor)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          InlineSearchBar(
            key: _settingsSearchBarKey,
            controller: _settingsSearchCtrl,
            onChanged: (q) {
              final trimmed = q.trim();
              if (trimmed == _settingsSearchQuery) return;
              setState(() => _settingsSearchQuery = trimmed);
            },
            hintText: AppLocalizations.of(context).searchSettingsHint,
            hasText: _settingsSearchQuery.isNotEmpty,
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
          const SizedBox(height: 16),
          if (_sectionVisible(l.securityTitle, l.securitySubtitle, [
            l.statusSettings,
            l.showDisplayNameInGroups,
            l.showDisplayNameSubtitle,
            l.pinLock,
            l.enablePinLock,
            l.enablePinSubtitle,
            l.useBiometrics,
            l.useBiometricsSubtitle,
            l.lockOnResume,
            l.lockOnResumeSubtitle,
            l.statusVisibility,
            l.statusShowStatus,
            l.statusHideStatus,
            l.statusCustomText,
            l.statusWhenOnline,
            l.statusWhenOffline,
            l.fakePinTitle,
            l.fakePinSubtitle,
            l.fakePinDescription,
            l.decoyAccountSection,
            l.decoyAccountSubtitle,
            l.decoyContactsSection,
            l.decoyContactsSubtitle,
            'Privacy',
            'Visibility and search settings',
            'PIN, biometrics and lock behavior'
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.security_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).securityTitle,
              subtitle: AppLocalizations.of(context).securitySubtitle,
              section: SectionType.security,
              expandedContentBuilder: _buildSecurityContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.wardLinkTitle, l.wardLinkSubtitle, [
            l.wardLinkEnable,
            l.wardLinkEnableDesc,
            l.wardLinkPairedDevices,
            l.wardLinkAddDevice,
            l.wardLinkMaxFileSize,
            l.wardLinkBubbleVisibility,
            l.wardLinkBubbleSize,
            l.wardLinkFavoritesOnlyNote,
            l.wardLinkSyncFromBeginning,
            l.wardLinkSyncFromBeginningDesc,
            l.wardLinkE2E,
            l.wardLinkHoldForLog,
            l.wardLinkLog,
            'Sync Settings',
            'File size limit and bubble notifications',
            'Add and manage paired devices'
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.sync_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).wardLinkTitle,
              subtitle: AppLocalizations.of(context).wardLinkSubtitle,
              section: SectionType.wardLink,
              expandedContentBuilder: _buildWardLinkContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.meshTitle, l.meshSubtitle,
              ['Mesh', 'Bluetooth', 'BLE', 'Radar', 'mesh', 'radar'])) ...[
            _buildLiquidGlassSection(
              icon: Icons.radar_rounded,
              iconHue: 1,
              title: l.meshTitle,
              subtitle: l.meshSubtitle,
              section: SectionType.mesh,
              expandedContentBuilder: _buildMeshContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.backupTitle, l.backupSubtitle, [
            l.backupExport,
            l.backupRestore,
            l.backupScope,
            l.backupFavorites,
            l.backupPersonal,
            l.backupIncludeMedia,
            l.backupSchedule,
            l.backupFolder,
            l.backupMediaImages,
            l.backupMediaVideos,
            l.backupMediaVoice,
            l.backupMediaOther
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.save_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).backupTitle,
              subtitle: AppLocalizations.of(context).backupSubtitle,
              section: SectionType.backup,
              expandedContentBuilder: () => const _BackupSection(),
            ),
            const SizedBox(height: 16),
          ],
          if ((Platform.isWindows || Platform.isMacOS || Platform.isLinux) &&
              _sectionVisible(l.audioTitle, l.audioSubtitle,
                  [l.audioTitle, l.audioSubtitle])) ...[
            _buildLiquidGlassSection(
              icon: Icons.headset_mic_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).audioTitle,
              subtitle: AppLocalizations.of(context).audioSubtitle,
              section: SectionType.audio,
              expandedContentBuilder: _buildAudioContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.notificationsTitle, l.notificationsSubtitle, [
            l.notifEnableLabel,
            l.notifHideContentLabel,
            l.notifSoundEnableLabel,
            l.notifSoundChooseLabel,
            l.notifPopupPosition,
            l.notifPopupPositionSubtitle,
            l.launchAtStartupLabel,
            l.launchAtStartupSubtitle,
            l.notificationsEnabled,
            l.notificationsEnabledSubtitle,
            'General',
            'Enable notifications and content visibility',
            'Notification sound and audio file',
            'Advanced',
            'Startup behavior and popup position'
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.notifications_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).notificationsTitle,
              subtitle: AppLocalizations.of(context).notificationsSubtitle,
              section: SectionType.notifications,
              expandedContentBuilder: _buildNotificationsContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.appearanceTitle, l.appearanceSubtitle, [
            l.selectTheme,
            l.darkMode,
            l.fontAndTextSize,
            l.fontFamily,
            l.messageSize,
            l.chatBackground,
            l.chatBgSubtitle,
            l.applyGlobally,
            l.applyGloballySubtitle,
            l.blurBackground,
            l.elementOpacity,
            l.elementBrightness,
            l.uiLayout,
            l.navBarPosition,
            l.inputBarMaxWidth,
            l.minimizeBottomNav,
            l.minimizeBottomNavSubtitle,
            l.swipeTabs,
            l.swipeTabsSubtitle,
            l.smoothScroll,
            l.performanceOptimizations,
            l.showAvatarInChats,
            l.showAvatarSubtitle,
            l.showAccountIndicator,
            l.showAccountIndicatorSubtitle,
            l.liquidGlassSubtitle,
            l.liquidGlassNavBarLabel,
            l.liquidGlassNavBarDesc,
            l.liquidGlassInputLabel,
            l.liquidGlassInputDesc,
            l.liquidGlassSearchLabel,
            l.liquidGlassSearchDesc,
            l.macOsWindowStyle,
            l.macOsWindowStyleSubtitle,
            l.messageAnimations,
            l.chatListMoveAnimations,
            l.smoothScrollDown,
            l.showSnackbars,
            l.tabSwiping,
            l.tabSwipingSubtitle,
            l.navPanelPosition,
            l.showAvatarsInChats,
            l.loadOlderMessagesOnScroll,
            l.ownMessagesRight,
            l.ownMessagesLeft,
            l.alignAllRight,
            l.alignAllRightSubtitle,
            l.presetsBackground,
            'Chat Display',
            'Alignment, avatars and animations',
            'Wallpaper, blur and opacity',
            'Layout',
            'Navigation, graph and tab swiping',
            'Liquid Glass Effects'
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.palette_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).appearanceTitle,
              subtitle: AppLocalizations.of(context).appearanceSubtitle,
              section: SectionType.appearance,
              expandedContentBuilder: _buildAppearanceContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.languageTitle, l.languageSubtitle,
              [l.languageEnglish, l.languageRussian])) ...[
            _buildLiquidGlassSection(
              icon: Icons.translate_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).languageTitle,
              subtitle: AppLocalizations.of(context).languageSubtitle,
              section: SectionType.language,
              expandedContentBuilder: _buildLanguageContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.cacheTitle, l.cacheSubtitle, [
            l.mediaCacheSize,
            l.clearLocalCache,
            l.serverMediaCacheSubtitle,
            l.clearServerCache,
            l.dangerZone,
            l.dangerZoneSubtitle,
            l.factoryReset,
            l.factoryResetHint,
            l.resetDeleteLocal,
            l.resetDeleteLocalSubtitle,
            l.manageCacheTitle,
            l.manageCacheButton,
            l.cleanUnusedFiles,
            'Storage',
            'Media cache and unused file cleanup'
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.cleaning_services_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).cacheTitle,
              subtitle: AppLocalizations.of(context).cacheSubtitle,
              section: SectionType.cache,
              expandedContentBuilder: _buildCacheContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.interactTitle, l.interactSubtitle, [
            l.confirmFileUpload,
            l.confirmFileUploadSubtitle,
            l.confirmVoiceMessage,
            l.confirmVoiceSubtitle,
            l.downloadFolder,
            l.downloadFolderSubtitle,
            l.autoLoadVideos,
            l.autoLoadVideosSubtitle,
            'Media & Uploads',
            'Confirmations, auto-load and image preloading',
            'Performance',
            'Scroll buffer and image preload window',
            'Files & Storage',
            'Download folder and app data management',
            l.debugTitle,
            l.debugSubtitle,
            l.debugMode,
            l.debugModeSubtitle,
            l.enableFileLogging,
            l.enableFileLoggingSubtitle,
            l.deleteAllLogs,
            l.blockedUsersTitle,
            l.blockedUsersSubtitle,
            l.blockedUsersEmpty,
            l.unblockAction,
            l.blockUserLabel,
            l.unblockUserLabel
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.tune_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).interactTitle,
              subtitle: AppLocalizations.of(context).interactSubtitle,
              section: SectionType.interact,
              expandedContentBuilder: _buildInteractContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.contactTitle, l.contactSubtitle, [
            l.contactWebsite,
            l.contactRepository,
            l.contactRepositoryServer,
            l.contactEmail,
            l.supportOnyx
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.info_outline_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).contactTitle,
              subtitle: AppLocalizations.of(context).contactSubtitle,
              section: SectionType.contact,
              expandedContentBuilder: _buildContactContent,
            ),
            const SizedBox(height: 16),
          ],
          if (_sectionVisible(l.recycleBinTitle, l.recycleBinSubtitle, [
            l.recycleBinPendingTitle,
            l.recycleBinNoPending,
            l.recycleBinResetTitle,
            l.recycleBinResetDesc,
            l.recycleBinResetButton
          ])) ...[
            _buildLiquidGlassSection(
              icon: Icons.delete_sweep_rounded,
              iconHue: 1,
              title: AppLocalizations.of(context).recycleBinTitle,
              subtitle: AppLocalizations.of(context).recycleBinSubtitle,
              section: SectionType.recycleBin,
              expandedContentBuilder: () => const _RecycleBinSection(),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              'open-beta 2.0',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.55),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
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
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.primary)),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        contactItem(
          icon: Icons.code_rounded,
          label: l.contactRepository,
          value: 'github.com/wardcore-dev/onyx',
          onTap: () => openUrl('https://github.com/wardcore-dev/onyx'),
        ),
        Divider(
            height: 1,
            indent: 50,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        contactItem(
          icon: Icons.dns_rounded,
          label: l.contactRepositoryServer,
          value: 'github.com/wardcore-dev/onyx-server',
          onTap: () => openUrl('https://github.com/wardcore-dev/onyx-server'),
        ),
        Divider(
            height: 1,
            indent: 50,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        contactItem(
          icon: Icons.mail_outline_rounded,
          label: l.contactEmail,
          value: 'wardcorebusiness@proton.me',
          onTap: () => openUrl('mailto:wardcorebusiness@proton.me'),
        ),
      ],
    );
  }

  Widget _buildBlockedUsersContent() {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable:
          Listenable.merge([BlocklistManager.blockedUsers, OnionRequests.blocked]),
      builder: (_, __) {
        final blocked = BlocklistManager.blockedUsers.value;
        final requesters = OnionRequests.blocked.value;
        if (blocked.isEmpty && requesters.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(width: 10),
                Text(
                  l.blockedUsersEmpty,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            ...blocked.map((username) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      username,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.onOpenChat(username),
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    tooltip: l.writeMessage,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: () => BlocklistManager.unblock(username),
                    icon: Icon(Icons.lock_open_rounded,
                        size: 20, color: colorScheme.primary),
                    tooltip: l.unblockAction,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            );
          }),
            // Blocked from the Requests screen: never contacts, blocked by
            // key -- shown with who they said they were.
            ...requesters.map((b) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name.isNotEmpty ? b.name : '@${b.username}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@${b.username} · ${l.blockedFromRequests}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => OnionRequests.unblock(b.pub),
                      icon: Icon(Icons.lock_open_rounded,
                          size: 20, color: colorScheme.primary),
                      tooltip: l.unblockAction,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildWardLinkContent() {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final showAll = _sectionVisible(l.wardLinkTitle, l.wardLinkSubtitle);

    Future<void> toggleEnabled(bool v) async {
      await SettingsManager.setWardLinkEnabled(v);
      final username = await AccountManager.getCurrentAccount();
      if (v && username != null) {
        await WardLinkSyncService.instance.start(username);
      } else {
        await WardLinkSyncService.instance.stop();
      }
    }

    Future<void> addDevice() async {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) {
        _showSnack(l.wardLinkPairFailed);
        return;
      }
      if (!mounted) return;
      await showOnyxDialog<void>(
        context: context,
        barrierLabel: l.wardLinkPairTitle,
        builder: (_) => const _WardLinkQrDialog(),
      );
    }

    Future<void> removeDevice(PairedDevice d) async {
      final ok = await showOnyxConfirmDialog(
        context: context,
        title: d.name,
        message: l.wardLinkRemoveConfirm,
        confirmLabel: l.wardLinkRemoveDevice,
        isDestructive: true,
        icon: Icons.link_off_rounded,
      );
      if (ok == true) {
        await WardLinkSyncService.instance.sendUnpair(d.identityPubB64);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.wardLinkEnabled,
          builder: (_, enabled, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.wardLinkEnable,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                value: enabled,
                onChanged: toggleEnabled,
              ),
              if (enabled) ...[
                ValueListenableBuilder<WardLinkStatus>(
                  valueListenable: WardLinkSyncService.instance.status,
                  builder: (_, st, __) =>
                      ValueListenableBuilder<List<PairedDevice>>(
                    valueListenable: WardLinkPairedDevices.devices,
                    builder: (_, devices, __) {
                      if (st.message.isEmpty && devices.isEmpty)
                        return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                st.syncing
                                    ? Icons.sync_rounded
                                    : Icons.check_rounded,
                                size: 13,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                st.message.isNotEmpty
                                    ? st.message
                                    : l.wardLinkFavoritesOnlyNote,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: cs.onSurface.withValues(alpha: 0.7)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (devices.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 22,
                                child: Stack(
                                  children: [
                                    for (var i = 0;
                                        i < devices.length.clamp(0, 3);
                                        i++)
                                      Padding(
                                        padding:
                                            EdgeInsets.only(left: i * 15.0),
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: cs.surface,
                                            border: Border.all(
                                                color: cs.surface, width: 1.5),
                                          ),
                                          child: CircleAvatar(
                                            radius: 11,
                                            backgroundColor:
                                                cs.primaryContainer,
                                            child: Icon(
                                              devices[i].os == 'android' ||
                                                      devices[i].os == 'ios'
                                                  ? Icons.smartphone_rounded
                                                  : Icons.computer_rounded,
                                              size: 11,
                                              color: cs.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                _buildSubSection(
                  key: 'wardlink_settings',
                  title: l.wardLinkSyncSettingsTitle,
                  subtitle: l.wardLinkSyncSettingsSubtitle,
                  icon: Icons.settings_rounded,
                  searchShowAll: showAll,
                  keywords: [
                    l.wardLinkMaxFileSize,
                    l.wardLinkBubbleVisibility,
                    l.wardLinkBubbleSize,
                    l.wardLinkSyncFavoritesToggle,
                    l.wardLinkSyncPersonalToggle,
                    'file size',
                    'bubble',
                    'sync',
                  ],
                  expandedContent: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Two independent, isolated sync scopes: enabling or
                      // disabling one never affects the other — each is its
                      // own manifest/import path in WardLinkSyncService.
                      ValueListenableBuilder<bool>(
                        valueListenable: SettingsManager.wardLinkSyncFavorites,
                        builder: (_, syncFavorites, __) => Row(
                          children: [
                            Expanded(
                              child: Text(l.wardLinkSyncFavoritesToggle,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ),
                            Switch(
                              value: syncFavorites,
                              onChanged: (v) =>
                                  SettingsManager.setWardLinkSyncFavorites(v),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            SettingsManager.wardLinkSyncPersonalOutgoing,
                        builder: (_, syncPersonal, __) => Row(
                          children: [
                            Expanded(
                              child: Text(l.wardLinkSyncPersonalToggle,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ),
                            Switch(
                              value: syncPersonal,
                              onChanged: (v) => SettingsManager
                                  .setWardLinkSyncPersonalOutgoing(v),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            SettingsManager.wardLinkSyncPersonalIncoming,
                        builder: (_, syncIncoming, __) => Row(
                          children: [
                            Expanded(
                              child: Text(l.wardLinkSyncIncomingToggle,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ),
                            Switch(
                              value: syncIncoming,
                              onChanged: (v) => SettingsManager
                                  .setWardLinkSyncPersonalIncoming(v),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Row(
                        children: [
                          Expanded(
                            child: Text(l.wardLinkMaxFileSize,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable:
                                SettingsManager.wardLinkMaxFileSizeMb,
                            builder: (_, mb, __) => DropdownButton<int>(
                              value: const [512, 1024, 2048, 4096].contains(mb)
                                  ? mb
                                  : 2048,
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(
                                    value: 512, child: Text('512 MB')),
                                DropdownMenuItem(
                                    value: 1024, child: Text('1 GB')),
                                DropdownMenuItem(
                                    value: 2048, child: Text('2 GB')),
                                DropdownMenuItem(
                                    value: 4096, child: Text('4 GB')),
                              ],
                              onChanged: (v) {
                                if (v != null)
                                  SettingsManager.setWardLinkMaxFileSizeMb(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            SettingsManager.wardLinkBubbleOnlyErrors,
                        builder: (_, onlyErrors, __) => Row(
                          children: [
                            Expanded(
                              child: Text(l.wardLinkBubbleVisibility,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ),
                            Switch(
                              value: !onlyErrors,
                              onChanged: (v) =>
                                  SettingsManager.setWardLinkBubbleOnlyErrors(
                                      !v),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ValueListenableBuilder<int>(
                        valueListenable: SettingsManager.wardLinkBubbleSize,
                        builder: (_, sz, __) => Row(
                          children: [
                            Expanded(
                              child: Text(l.wardLinkBubbleSize,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                            ),
                            SizedBox(
                              width: 140,
                              child: Slider(
                                value: sz.toDouble().clamp(32.0, 64.0),
                                min: 32.0,
                                max: 64.0,
                                divisions: 16,
                                label: sz.toString(),
                                onChanged: (v) =>
                                    SettingsManager.setWardLinkBubbleSize(
                                        v.round()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<PairedDevice>>(
                  valueListenable: WardLinkPairedDevices.devices,
                  builder: (_, devices, __) => _buildSubSection(
                    key: 'wardlink_devices',
                    title: l.wardLinkPairedDevices,
                    subtitle: l.wardLinkPairedDevicesSubtitle,
                    icon: Icons.devices_rounded,
                    trailingBadge:
                        devices.isNotEmpty ? '${devices.length}' : null,
                    searchShowAll: showAll,
                    keywords: [
                      l.wardLinkPairedDevices,
                      l.wardLinkAddDevice,
                      l.wardLinkE2E,
                      l.wardLinkSyncFromBeginning,
                      'device',
                      'pair',
                      'paired',
                    ],
                    expandedContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (devices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(l.wardLinkNoPairedDevices,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5))),
                          )
                        else
                          Column(
                            children: devices.map((d) {
                              final synced = d.lastSyncAt != null
                                  ? _shortWhen(d.lastSyncAt!)
                                  : l.wardLinkNeverSynced;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    leading: Icon(
                                      d.os == 'android' || d.os == 'ios'
                                          ? Icons.smartphone_rounded
                                          : Icons.computer_rounded,
                                      size: 20,
                                      color: cs.primary,
                                    ),
                                    title: Text(d.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(synced,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.5))),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: cs.error),
                                          onPressed: () => removeDevice(d),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: d.syncFromBeginning
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: cs.primary),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(l.wardLinkSyncPending,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: cs.primary)),
                                            ],
                                          )
                                        : Align(
                                            alignment: Alignment.center,
                                            child: FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: cs.primary
                                                    .withValues(alpha: 0.12),
                                                foregroundColor: cs.primary,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 6),
                                                shape: const StadiumBorder(),
                                                elevation: 0,
                                              ),
                                              onPressed: () async {
                                                await WardLinkPairedDevices
                                                    .setSyncFromBeginning(
                                                        d.identityPubB64, true);
                                                await WardLinkSyncService
                                                    .instance
                                                    .triggerResync(
                                                        d.identityPubB64);
                                              },
                                              child: Text(
                                                  l.wardLinkSyncFromBeginning,
                                                  style: const TextStyle(
                                                      fontSize: 11.5)),
                                            ),
                                          ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: addDevice,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(l.wardLinkAddDevice),
                          ),
                        ),
                        if (!kIsWeb &&
                            (Platform.isWindows ||
                                Platform.isMacOS ||
                                Platform.isLinux))
                          _buildWardLinkFirewallHint(context),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOnionModeContent() {
    final cs = Theme.of(context).colorScheme;

    Future<void> addPeer() async {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) {
        _showSnack('Not logged in');
        return;
      }
      if (!mounted) return;
      await showOnyxDialog<void>(
        context: context,
        barrierLabel: 'Pair over Tor',
        builder: (_) => const OnionQrDialog(),
      );
    }

    Future<void> removePeer(OnionPeer peer) async {
      // A contact can be paired from more than one of their devices (onion
      // identity is per-device) -- unpairing this one entry shouldn't be
      // described as dropping onion mode for ${peer.username} entirely
      // unless it's actually their last remaining paired device.
      final otherDevicesRemain = OnionPairedPeers.allByUsername(peer.username)
          .any((p) => p.identityPubB64 != peer.identityPubB64);
      final ok = await showOnyxConfirmDialog(
        context: context,
        title: peer.name,
        message: otherDevicesRemain
            ? 'Remove this onion pairing with ${peer.name}\'s device? Their other paired device is unaffected.'
            : 'Remove this onion pairing with ${peer.username}?',
        confirmLabel: 'Remove',
        isDestructive: true,
        icon: Icons.link_off_rounded,
      );
      if (ok == true) {
        await OnionPairedPeers.remove(peer.identityPubB64);
        rootScreenKey.currentState?.markOnionDeviceUnpaired(
            peer.username, peer.identityPubB64,
            hasOtherDevices: otherDevicesRemain);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Onion Mode is the app's only messaging transport now (see
        // SettingsManager.onionModeEnabled defaulting to true) — there is no
        // toggle to turn it off, so this reads as a status line rather than
        // a setting.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: cs.primary),
              const SizedBox(width: 6),
              Text('Прямая передача через Tor включена',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.primary)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Both people must be online at the same time for a message to go through — there is no store-and-forward yet.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<List<OnionPeer>>(
          valueListenable: OnionPairedPeers.peers,
          builder: (_, peersList, __) => _buildSubSection(
                    key: 'onion_peers',
                    title: 'Paired contacts',
                    subtitle: 'People you can reach directly over Tor',
                    icon: Icons.people_alt_rounded,
                    trailingBadge:
                        peersList.isNotEmpty ? '${peersList.length}' : null,
                    searchShowAll: true,
                    keywords: const ['onion peer', 'pair', 'contact'],
                    expandedContent: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (peersList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No onion-paired contacts yet',
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5))),
                          )
                        else
                          Column(
                            children: peersList.map((peer) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(
                                  peer.os == 'android' || peer.os == 'ios'
                                      ? Icons.smartphone_rounded
                                      : Icons.computer_rounded,
                                  size: 20,
                                  color: cs.primary,
                                ),
                                title: Text(peer.username,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5)),
                                subtitle: Text(peer.name,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            cs.onSurface.withValues(alpha: 0.6))),
                                trailing: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.delete_outline_rounded,
                                      size: 20, color: cs.error),
                                  onPressed: () => removePeer(peer),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: addPeer,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Pair a contact'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ],
    );
  }

  Widget _buildWardLinkFirewallHint(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    final String hint;
    if (Platform.isWindows) {
      hint = l.wardLinkFirewallHintWindows;
    } else if (Platform.isMacOS) {
      hint = l.wardLinkFirewallHintMac;
    } else {
      hint = l.wardLinkFirewallHintLinux;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 16, color: cs.secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortWhen(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildMeshContent() {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    Future<void> toggleMesh(bool v) async {
      await SettingsManager.setMeshModeEnabled(v);
      final username = await AccountManager.getCurrentAccount();
      if (v && username != null) {
        await MeshManager.instance.start(username);
      } else {
        await MeshManager.instance.stop();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.meshModeEnabled,
          builder: (_, enabled, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l.meshEnable,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l.meshEnableDesc,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                value: enabled,
                onChanged: MeshManager.isPlatformSupported ? toggleMesh : null,
              ),
              if (!MeshManager.isPlatformSupported)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.meshUnavailable,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              if (enabled) ...[
                const SizedBox(height: 8),
                _buildLiquidGlassButton(
                  icon: Icons.radar_rounded,
                  label: l.meshOpenRadar,
                  onPressed: () => showMeshRadarSheet(context),
                ),
                const SizedBox(height: 4),
                ListenableBuilder(
                  listenable: MeshManager.instance.neighbors,
                  builder: (_, __) {
                    final count =
                        MeshManager.instance.neighbors.neighbors.length;
                    if (count == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.bluetooth_rounded,
                              size: 14, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            l.meshNearbyCount(count),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final showAll =
        _sectionVisible(l.notificationsTitle, l.notificationsSubtitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSection(
          key: 'notif_general',
          title: l.notifGeneralTitle,
          subtitle: l.notifGeneralSubtitle,
          icon: Icons.notifications_rounded,
          searchShowAll: showAll,
          keywords: [
            l.notifEnableLabel,
            l.notifHideContentLabel,
            l.notificationsEnabled
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.notificationsEnabled,
                builder: (_, enabled, __) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.notifEnableLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l.notifEnabledSubtitle(enabled.toString()),
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  value: enabled,
                  onChanged: (v) => SettingsManager.setNotificationsEnabled(v),
                ),
              ),
              ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.notifHideContent,
                  builder: (_, hidden, __) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.notifHideContentLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        l.notifHideContentSubtitle(hidden.toString()),
                        style: TextStyle(
                            fontSize: 13, color: colorScheme.onSurfaceVariant)),
                    value: hidden,
                    onChanged: (v) => SettingsManager.setNotifHideContent(v),
                  ),
                ),
            ],
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(height: 8),
          _buildSubSection(
            key: 'notif_sound',
            title: l.notifSoundEnableLabel,
            subtitle: l.notifSoundSubtitle,
            icon: Icons.music_note_rounded,
            searchShowAll: showAll,
            keywords: [
              l.notifSoundEnableLabel,
              l.notifSoundChooseLabel,
              'sound',
              'audio',
              'notification'
            ],
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.notifSoundEnabled,
                  builder: (_, soundEnabled, __) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.notifSoundEnableLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        l.notifSoundEnabledSubtitle(soundEnabled.toString()),
                        style: TextStyle(
                            fontSize: 13, color: colorScheme.onSurfaceVariant)),
                    value: soundEnabled,
                    onChanged: (v) => SettingsManager.setNotifSoundEnabled(v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.notifSoundChooseLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: SettingsManager.notifSound,
                  builder: (_, currentSound, __) {
                    const builtInSounds = [
                      'notification0',
                      'notification1',
                      'notification2'
                    ];
                    final allSounds = <String>[...builtInSounds];
                    if (currentSound.startsWith('custom:') &&
                        !allSounds.contains(currentSound)) {
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
                                    AudioPlayer().play(
                                        DeviceFileSource(sound.substring(7)));
                                  } else {
                                    AudioPlayer()
                                        .play(AssetSource('$sound.wav'));
                                  }
                                } catch (e) {
                                  debugPrint('[err] $e');
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
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
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.play_circle_outline,
                                      size: 20,
                                      color: selected
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l.localizeNotifSound(sound),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
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
                                final result =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'wav',
                                    'mp3',
                                    'm4a',
                                    'ogg',
                                    'aac',
                                    'opus'
                                  ],
                                );
                                if (result == null || result.files.isEmpty)
                                  return;
                                final filePath = result.files.first.path;
                                if (filePath == null) return;
                                final appSupport =
                                    await getOnyxDocumentsDirectory();
                                final soundsDir = Directory(
                                    '${appSupport.path}/custom_sounds');
                                await soundsDir.create(recursive: true);
                                final fileName = p.basename(filePath);
                                final destFile =
                                    File('${soundsDir.path}/$fileName');
                                await File(filePath).copy(destFile.path);
                                final soundKey = 'custom:${destFile.path}';
                                SettingsManager.setNotifSound(soundKey);
                                try {
                                  AudioPlayer()
                                      .play(DeviceFileSource(destFile.path));
                                } catch (e) {
                                  debugPrint('[err] $e');
                                }
                                if (mounted)
                                  rootScreenKey.currentState
                                      ?.showSnack(l.notifSoundCustomLoaded);
                              } catch (e) {
                                debugPrint('[NotifSound] pick error: $e');
                                if (mounted)
                                  rootScreenKey.currentState?.showSnack(
                                      '${l.notifSoundCustomError}: $e');
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                    width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.file_upload_outlined,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 10),
                                  Text(l.notifSoundCustom,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: Text(l.notifSoundCustomInvalidFormat,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6))),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        if (Platform.isWindows || (isDesktop && !Platform.isMacOS)) ...[
          const SizedBox(height: 8),
          _buildSubSection(
            key: 'notif_advanced',
            title: l.notifAdvancedTitle,
            subtitle: l.notifAdvancedSubtitle,
            icon: Icons.tune_rounded,
            searchShowAll: showAll,
            keywords: [
              l.notifPopupPosition,
              l.notifPopupPositionSubtitle,
              l.launchAtStartupLabel,
              l.launchAtStartupSubtitle,
              'startup',
              'popup'
            ],
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (Platform.isWindows)
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsManager.launchAtStartup,
                    builder: (_, autostartEnabled, __) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.launchAtStartupLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l.launchAtStartupSubtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant)),
                      value: autostartEnabled,
                      onChanged: (val) async {
                        final l10n = AppLocalizations.of(context);
                        final scaffold = ScaffoldMessenger.of(context);
                        final cs = Theme.of(context).colorScheme;
                        void snack(String msg) {
                          final bg = SettingsManager.getElementColor(
                            cs.surfaceContainerHighest,
                            SettingsManager.elementBrightness.value,
                          ).withValues(
                              alpha: SettingsManager.elementOpacity.value);
                          scaffold
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: Text(msg,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center),
                              backgroundColor: bg,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              margin: const EdgeInsets.only(
                                  bottom: 16, left: 16, right: 16),
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
                          snack(val
                              ? l10n.launchAtStartupEnabled
                              : l10n.launchAtStartupDisabled);
                        } catch (e) {
                          debugPrint('[autostart] Failed to toggle: $e');
                          snack(l10n.launchAtStartupFailed);
                        }
                      },
                    ),
                  ),
                if (isDesktop && !Platform.isMacOS) ...[
                  if (Platform.isWindows) const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.picture_in_picture_rounded,
                          size: 16, color: colorScheme.onSurface),
                      const SizedBox(width: 6),
                      Text(l.notifPopupPosition,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(l.notifPopupPositionSubtitle,
                      style: TextStyle(
                          fontSize: 13, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: SettingsManager.notificationPosition,
                    builder: (_, pos, __) {
                      const positionKeys = [
                        'top_left',
                        'top_right',
                        'bottom_left',
                        'bottom_right'
                      ];
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
                                l.localizeNotifPosition(posKey),
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
                ],
              ],
            ),
          ),
        ],
        if (!isDesktop) ...[
          const SizedBox(height: 8),
          _buildSubSection(
            key: 'notif_background_service',
            title: l.backgroundServiceTitle,
            subtitle: l.backgroundServiceSubtitle,
            icon: Icons.sync_rounded,
            searchShowAll: showAll,
            keywords: [
              l.backgroundServiceTitle,
              'foreground service',
              'background',
              'keep alive',
            ],
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.backgroundServiceEnabled,
                  builder: (_, enabled, __) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.backgroundServiceEnableLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(l.backgroundServiceEnableSubtitle,
                        style: TextStyle(
                            fontSize: 13, color: colorScheme.onSurfaceVariant)),
                    value: enabled,
                    onChanged: (v) =>
                        SettingsManager.setBackgroundServiceEnabled(v),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.backgroundServiceEnabled,
                  builder: (_, enabled, __) {
                    if (!enabled) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.backgroundServiceTextLabel,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface)),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String>(
                            valueListenable:
                                SettingsManager.backgroundServiceNotificationText,
                            builder: (_, currentText, __) {
                              final controller = TextEditingController(
                                  text: currentText);
                              controller.selection = TextSelection.collapsed(
                                  offset: controller.text.length);
                              return Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: TextField(
                                  controller: controller,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: AppLocalizations.of(context)
                                        .backgroundServiceDefaultText,
                                    hintStyle: TextStyle(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 12),
                                  ),
                                  onSubmitted: (v) => SettingsManager
                                      .setBackgroundServiceNotificationText(v),
                                  onTapOutside: (_) => SettingsManager
                                      .setBackgroundServiceNotificationText(
                                          controller.text),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageContent() {
    final l = AppLocalizations.of(context);

    const languages = [
      {'code': 'en', 'label': 'English', 'native': 'English', 'flag': '🇺🇸'},
      {'code': 'ru', 'label': 'Russian', 'native': 'Русский', 'flag': '🇷🇺'},
      {'code': 'es', 'label': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
      {'code': 'de', 'label': 'German', 'native': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'fr', 'label': 'French', 'native': 'Français', 'flag': '🇫🇷'},
      {
        'code': 'pt',
        'label': 'Portuguese',
        'native': 'Português',
        'flag': '🇧🇷'
      },
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
                                margin:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                decoration: BoxDecoration(
                                  color: sheetColor,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 36,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color:
                                            cs.onSurface.withValues(alpha: 0.2),
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
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        children: languages.map((lang) {
                                          final isSelected =
                                              currentLocale.languageCode ==
                                                  lang['code'];
                                          return ListTile(
                                            leading: Text(
                                              lang['flag']!,
                                              style:
                                                  const TextStyle(fontSize: 22),
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
                                                ? Icon(
                                                    Icons.check_circle_rounded,
                                                    color: cs.primary)
                                                : Icon(
                                                    Icons
                                                        .radio_button_unchecked_rounded,
                                                    color: cs.onSurface
                                                        .withValues(alpha: 0.3),
                                                  ),
                                            selected: isSelected,
                                            selectedTileColor: cs.primary
                                                .withValues(alpha: 0.08),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            onTap: () async {
                                              await SettingsManager
                                                  .setAppLocale(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.22),
                      width: 0.8,
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

  Widget _buildSecurityContent() {
    final l = AppLocalizations.of(context);
    final showAll = _sectionVisible(l.securityTitle, l.securitySubtitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSection(
          key: 'security_privacy',
          title: l.securityPrivacyTitle,
          subtitle: l.securityPrivacySubtitle,
          icon: Icons.visibility_off_rounded,
          searchShowAll: showAll,
          keywords: [
            l.showDisplayNameInGroups,
            l.showDisplayNameSubtitle,
            l.statusSettings,
            l.statusVisibility,
            l.statusShowStatus,
            l.statusHideStatus,
            l.statusCustomText,
            l.statusWhenOnline,
            l.statusWhenOffline,
            l.fakePinTitle,
            l.fakePinSubtitle,
            l.decoyAccountSection,
            l.decoyContactsSection,
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiquidGlassButton(
                icon: Icons.manage_accounts_rounded,
                label: l.statusSettings,
                fontSize: 15,
                onPressed: () => _showStatusDialog(),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.showDisplayNameInGroups,
                builder: (context, showDN, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.showDisplayNameInGroups,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(l.showDisplayNameSubtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  value: showDN,
                  onChanged: (val) =>
                      SettingsManager.setShowDisplayNameInGroups(val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'security_pin',
          title: l.pinLock,
          subtitle: 'PIN, biometrics and lock behavior',
          icon: Icons.pin_rounded,
          searchShowAll: showAll,
          keywords: [
            l.enablePinLock,
            l.enablePinSubtitle,
            l.useBiometrics,
            l.useBiometricsSubtitle,
            l.lockOnResume,
            l.lockOnResumeSubtitle,
            l.fakePinTitle,
            l.fakePinSubtitle,
            'biometric',
            'fingerprint',
            'password',
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.pinEnabled,
                builder: (context, pinOn, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.enablePinLock,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(l.enablePinSubtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  value: pinOn,
                  onChanged: (val) async {
                    if (val) {
                      final pinEnabledMsg = l.pinLockEnabled;
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
                      final pinDisabledMsg = l.pinLockDisabled;
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
                    valueListenable: SettingsManager.biometricDeviceSupported,
                    builder: (context, bioSupported, _) {
                      if (!bioSupported) return const SizedBox.shrink();
                      return ValueListenableBuilder<bool>(
                        valueListenable: SettingsManager.biometricEnabled,
                        builder: (context, bioOn, _) => SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.useBiometrics,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(l.useBiometricsSubtitle,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          secondary: const Icon(Icons.fingerprint_rounded),
                          value: bioOn,
                          onChanged: (val) async {
                            if (val) {
                              final unavailMsg = l.biometricsUnavailable;
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
                  );
                },
              ),
              if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.pinEnabled,
                  builder: (context, pinOn, _) {
                    if (!pinOn) return const SizedBox.shrink();
                    return ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.lockOnResume,
                      builder: (context, lockOn, _) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.lock_clock_outlined),
                        title: Text(l.lockOnResume,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(l.lockOnResumeSubtitle,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        value: lockOn,
                        onChanged: (val) =>
                            SettingsManager.setLockOnResume(val),
                      ),
                    );
                  },
                ),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.pinEnabled,
                builder: (context, pinOn, _) {
                  if (!pinOn) return const SizedBox.shrink();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.theater_comedy_outlined),
                    title: Text(l.fakePinTitle,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(l.fakePinSubtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => showDecoySetupSheet(context),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ONYX data folder ────────────────────────────────────────────────────────

  Widget _buildAppDataContent() {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final custom = OnyxBaseDir.customBase;

    return FutureBuilder<String>(
      future: OnyxBaseDir.supportDir().then((d) => d.path),
      builder: (ctx, snap) {
        final displayPath = snap.data ?? custom ?? l.appDataDefault;
        final isCustom = custom != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(l.appDataTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                displayPath,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      final picked = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: l.appDataMove,
                        initialDirectory: custom ?? snap.data,
                      );
                      if (picked == null || picked.isEmpty || !mounted) return;
                      _showMigrationDialog(context, picked);
                    },
                    child: Text(l.appDataMove),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final path = custom ?? snap.data;
                      if (path == null) return;
                      try {
                        if (Platform.isWindows) {
                          await Process.run(
                              'explorer', [path.replaceAll('/', '\\')]);
                        } else if (Platform.isMacOS) {
                          await Process.run('open', [path]);
                        } else {
                          await Process.run('xdg-open', [path]);
                        }
                      } catch (_) {}
                    },
                    child: Text(l.appDataOpenFolder),
                  ),
                  if (isCustom)
                    OutlinedButton(
                      onPressed: () => _showResetDialog(context),
                      child: Text(l.appDataReset),
                    ),
                ],
              ),
            ),

            // Delete previous (default system) folder — only shown after migration
            if (isCustom) _buildDeleteOldFolderTile(context, cs),
          ],
        );
      },
    );
  }

  // Files that the app creates in any support directory automatically.
  // Presence of only these files means there is no actual user data to warn about.
  static const _kOldFolderSystemFiles = {
    '.onyx_docs_consolidated',
    'libCachedImageData.json',
    'shared_preferences.json',
  };

  static Future<({String path, bool hasUserData})> _oldFolderInfo() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) return (path: dir.path, hasUserData: false);
    final entities = await dir.list().toList();
    final hasUserData = entities.any((e) {
      final name = e.path.split(Platform.pathSeparator).last;
      return !_kOldFolderSystemFiles.contains(name);
    });
    return (path: dir.path, hasUserData: hasUserData);
  }

  Widget _buildDeleteOldFolderTile(BuildContext ctx, ColorScheme cs) {
    final l = AppLocalizations.of(ctx);
    _oldFolderInfoFuture ??= _oldFolderInfo();
    return FutureBuilder<({String path, bool hasUserData})>(
      future: _oldFolderInfoFuture,
      builder: (_, snap) {
        final info = snap.data;
        if (info == null || !info.hasUserData) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(l.appDataDeleteOldFolder,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.error)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                info.path,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(l.appDataDeleteOldFolder),
                onPressed: () => _showDeleteOldFolderDialog(ctx, info.path),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteOldFolderDialog(
      BuildContext ctx, String oldPath) async {
    final l = AppLocalizations.of(ctx);
    final confirmed = await showOnyxConfirmDialog(
      context: ctx,
      title: l.appDataDeleteOldFolder,
      message: l.appDataDeleteOldFolderConfirm,
      confirmLabel: l.appDataDeleteOldFolder,
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed != true) return;
    try {
      final d = Directory(oldPath);
      if (await d.exists()) {
        // Delete user data files but keep Flutter infrastructure files
        // that the app still reads from this location (SharedPreferences,
        // image cache). Without this, settings like pin_lock_enabled
        // are lost because Flutter always writes SharedPreferences to
        // the default AppSupport directory regardless of custom base.
        final entities = await d.list().toList();
        for (final e in entities) {
          final name = p.basename(e.path);
          if (_kOldFolderSystemFiles.contains(name)) continue;
          await e.delete(recursive: true);
        }
      }
      if (ctx.mounted) {
        _showStyledSnack(ctx, l.appDataDeleteOldFolderSuccess);
        setState(() {
          _oldFolderInfoFuture = null;
        }); // invalidate cache
      }
    } catch (e) {
      if (ctx.mounted) {
        _showStyledSnack(ctx, '${l.appDataDeleteOldFolderError}$e');
      }
    }
  }

  void _showMigrationDialog(BuildContext ctx, String targetPath) {
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _MigrationDialog(targetPath: targetPath),
    );
  }

  void _showResetDialog(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _MigrationDialog(targetPath: null),
    );
  }

  Widget _buildCacheContent() {
    final l = AppLocalizations.of(context);
    final showAll = _sectionVisible(l.cacheTitle, l.cacheSubtitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSection(
          key: 'cache_storage',
          searchShowAll: showAll,
          title: l.cacheStorageTitle,
          subtitle: l.cacheStorageSubtitle,
          icon: Icons.storage_rounded,
          keywords: [
            l.mediaCacheSize,
            l.manageCacheButton,
            l.manageCacheTitle,
            l.cleanUnusedFiles,
            l.clearLocalCache,
            'storage',
            'cache',
            'cleanup'
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.mediaCacheSize}${_cacheSizeMb != null ? '${_cacheSizeMb!.toStringAsFixed(1)} MB' : l.loading}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              _buildLiquidGlassButton(
                icon: Icons.storage_rounded,
                label: l.manageCacheButton,
                fontSize: 14,
                onPressed: _openCacheManager,
              ),
              const SizedBox(height: 8),
              Text(
                'Unused Files: ${_orphanedSizeMb != null ? '${_orphanedSizeMb!.toStringAsFixed(1)} MB' : l.loading}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 6),
              _buildLiquidGlassButton(
                icon: _purging
                    ? Icons.hourglass_top_rounded
                    : Icons.auto_delete_rounded,
                label: _purging ? l.cleaningUnusedFiles : l.cleanUnusedFiles,
                fontSize: 14,
                onPressed: _purging ? null : _purgeOrphanedCache,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'cache_danger',
          title: l.dangerZone,
          subtitle: l.dangerZoneSubtitle,
          icon: Icons.warning_rounded,
          searchShowAll: showAll,
          keywords: [
            l.dangerZone,
            l.dangerZoneSubtitle,
            l.factoryReset,
            l.factoryResetHint,
            l.resetDeleteLocal,
            'reset',
            'delete',
            'wipe'
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLiquidGlassButton(
                  icon: Icons.restore,
                  label: l.factoryReset,
                  fontSize: 14,
                  onPressed: _factoryReset),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionContent() {
    final l = AppLocalizations.of(context);
    final showAll = _sectionVisible(l.connectionTitle, l.connectionSubtitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSection(
          key: 'connection_server',
          searchShowAll: showAll,
          title: l.connectionServerTitle,
          subtitle: l.connectionServerSubtitle,
          icon: Icons.wifi_rounded,
          keywords: [
            l.connect,
            l.disconnect,
            'websocket',
            'server',
            'connection'
          ],
          expandedContent: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildLiquidGlassButton(
                  icon: Icons.wifi,
                  label: l.connect,
                  fontSize: 14,
                  onPressed: widget.onConnectWs),
              _buildLiquidGlassButton(
                  icon: Icons.wifi_off,
                  label: l.disconnect,
                  fontSize: 14,
                  onPressed: widget.onDisconnectWs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractContent() {
    final l = AppLocalizations.of(context);
    final showAll = _sectionVisible(l.interactTitle, l.interactSubtitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubSection(
          key: 'interact_media',
          searchShowAll: showAll,
          title: 'Media & Uploads',
          subtitle: 'Confirmations, auto-load and image preloading',
          icon: Icons.perm_media_rounded,
          keywords: [
            l.confirmFileUpload,
            l.confirmFileUploadSubtitle,
            l.confirmVoiceMessage,
            l.confirmVoiceSubtitle,
            l.autoLoadVideos,
            l.autoLoadVideosSubtitle,
            'upload',
            'media',
            'video',
            'voice'
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.confirmFileUpload,
                builder: (_, confirmFile, __) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.confirmFileUpload),
                  subtitle: Text(l.confirmFileUploadSubtitle),
                  value: confirmFile,
                  onChanged: (val) async =>
                      await SettingsManager.setConfirmFileUpload(val),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.confirmVoiceUpload,
                builder: (_, confirmVoice, __) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.confirmVoiceMessage),
                  subtitle: Text(l.confirmVoiceSubtitle),
                  value: confirmVoice,
                  onChanged: (val) async =>
                      await SettingsManager.setConfirmVoiceUpload(val),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.autoLoadVideoEnabled,
                builder: (_, autoLoadVideo, __) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.autoLoadVideos),
                  subtitle: Text(l.autoLoadVideosSubtitle),
                  value: autoLoadVideo,
                  onChanged: (val) async =>
                      await SettingsManager.setAutoLoadVideoEnabled(val),
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<MediaPreloadMode>(
                valueListenable: SettingsManager.mediaPreloadMode,
                builder: (_, mode, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Preload chat images',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Download images around the open chat in the background so they are ready before you scroll to them.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<MediaPreloadMode>(
                      value: mode,
                      underline: const SizedBox.shrink(),
                      onChanged: (val) async {
                        if (val != null)
                          await SettingsManager.setMediaPreloadMode(val);
                      },
                      items: [
                        const DropdownMenuItem(
                            value: MediaPreloadMode.off, child: Text('Off')),
                        DropdownMenuItem(
                            value: MediaPreloadMode.wifiOnly,
                            child: Text(
                                AppLocalizations.of(context).wifiOnlyOption)),
                        DropdownMenuItem(
                            value: MediaPreloadMode.always,
                            child: Text(AppLocalizations.of(context).always)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'interact_messages',
          searchShowAll: showAll,
          title: l.messagesSectionTitle,
          subtitle: l.messagesSectionSubtitle,
          icon: Icons.chat_bubble_outline_rounded,
          keywords: [
            'messages',
            'retry',
            'offline',
            'interval',
            'tor',
            'delivery'
          ],
          expandedContent: ValueListenableBuilder<int>(
            valueListenable: SettingsManager.onionRetryIntervalSeconds,
            builder: (_, seconds, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.retryIntervalTitle,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  l.retryIntervalDesc,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: const [10, 20, 30, 60, 120, 300].contains(seconds)
                      ? seconds
                      : 20,
                  underline: const SizedBox.shrink(),
                  onChanged: (val) async {
                    if (val != null) {
                      await SettingsManager.setOnionRetryIntervalSeconds(val);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                        value: 10, child: Text(l.intervalSeconds(10))),
                    DropdownMenuItem(
                        value: 20, child: Text(l.intervalSeconds(20))),
                    DropdownMenuItem(
                        value: 30, child: Text(l.intervalSeconds(30))),
                    DropdownMenuItem(
                        value: 60, child: Text(l.intervalMinutes(1))),
                    DropdownMenuItem(
                        value: 120, child: Text(l.intervalMinutes(2))),
                    DropdownMenuItem(
                        value: 300, child: Text(l.intervalMinutes(5))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'interact_performance',
          title: l.interactPerformanceTitle,
          subtitle: l.interactPerformanceSubtitle,
          icon: Icons.speed_rounded,
          searchShowAll: showAll,
          keywords: [
            'scroll buffer',
            'image preload',
            'preload window',
            'cache extent'
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.chatCacheExtent,
                builder: (_, extent, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scroll buffer',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Pixels rendered beyond the visible chat area. Higher = smoother scrolling, more memory. Current: ${extent.toStringAsFixed(0)} px',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                    ),
                    Slider(
                      value: extent,
                      min: 0,
                      max: 5000,
                      divisions: 20,
                      label: '${extent.toStringAsFixed(0)} px',
                      onChanged: (val) async =>
                          await SettingsManager.setChatCacheExtent(val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: SettingsManager.imagePreloadWindow,
                builder: (_, window, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Image preload window',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Messages scanned for images when opening a chat. Higher = more images ready before you scroll. Current: $window messages',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                    ),
                    Slider(
                      value: window.toDouble(),
                      min: 0,
                      max: 300,
                      divisions: 15,
                      label: '$window',
                      onChanged: (val) async =>
                          await SettingsManager.setImagePreloadWindow(
                              val.round()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) ...[
          const SizedBox(height: 8),
          _buildSubSection(
            key: 'interact_files',
            title: l.interactFilesTitle,
            subtitle: l.interactFilesSubtitle,
            icon: Icons.folder_rounded,
            searchShowAll: showAll,
            keywords: [
              l.downloadFolder,
              l.downloadFolderSubtitle,
              'download',
              'folder',
              'storage'
            ],
            expandedContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDownloadFolderTile(context),
                const SizedBox(height: 8),
                _buildAppDataContent(),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'interact_debug',
          searchShowAll: showAll,
          title: l.debugTitle,
          subtitle: l.debugSubtitle,
          icon: Icons.bug_report_rounded,
          keywords: [
            l.debugMode,
            l.debugModeSubtitle,
            l.enableFileLogging,
            l.enableFileLoggingSubtitle,
            l.deleteAllLogs
          ],
          expandedContent: _buildDebugContent(),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'interact_blocked_users',
          searchShowAll: showAll,
          title: l.blockedUsersTitle,
          subtitle: l.blockedUsersSubtitle,
          icon: Icons.block_rounded,
          keywords: [
            l.blockedUsersEmpty,
            l.unblockAction,
            l.blockUserLabel,
            l.unblockUserLabel
          ],
          expandedContent: _buildBlockedUsersContent(),
        ),
      ],
    );
  }

  Widget _buildDownloadFolderTile(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: SettingsManager.downloadFolderPath,
      builder: (_, path, __) {
        final hasCustom = path.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(l.downloadFolder,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                hasCustom ? path : l.downloadFolderDefault,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () async {
                      final picked = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: l.downloadFolderChange,
                        initialDirectory: hasCustom ? path : null,
                      );
                      if (picked != null && picked.isNotEmpty) {
                        await SettingsManager.setDownloadFolderPath(picked);
                      }
                    },
                    child: Text(l.downloadFolderChange),
                  ),
                  if (hasCustom) ...[
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          if (Platform.isWindows) {
                            await Process.run(
                                'explorer', [path.replaceAll('/', '\\')]);
                          } else if (Platform.isMacOS) {
                            await Process.run('open', [path]);
                          } else if (Platform.isLinux) {
                            await Process.run('xdg-open', [path]);
                          }
                        } catch (_) {}
                      },
                      child: const Icon(Icons.folder_open_rounded, size: 18),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          SettingsManager.setDownloadFolderPath(''),
                      child: Text(l.downloadFolderReset),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildDebugContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.debugMode,
          builder: (_, debugEnabled, __) => SwitchListTile(
            title: Text(AppLocalizations.of(context).debugMode),
            subtitle: Text(AppLocalizations.of(context).debugModeSubtitle),
            value: debugEnabled,
            onChanged: (val) async => await SettingsManager.setDebugMode(val),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.enableLogging,
          builder: (_, loggingEnabled, __) => SwitchListTile(
            title: Text(AppLocalizations.of(context).enableFileLogging),
            subtitle:
                Text(AppLocalizations.of(context).enableFileLoggingSubtitle),
            value: loggingEnabled,
            onChanged: (val) async =>
                await SettingsManager.setEnableLogging(val),
          ),
        ),
        const SizedBox(height: 8),
        _buildLiquidGlassButton(
            icon: Icons.delete_outline,
            label: AppLocalizations.of(context).deleteAllLogs,
            fontSize: 14,
            onPressed: _deleteAllLogs),
      ],
    );
  }

  Widget _buildAudioContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    if (_audioDevices == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final devices = _audioDevices!;
    final inputs = devices.where((d) => d.kind == 'audioinput').toList();
    final outputs = devices.where((d) => d.kind == 'audiooutput').toList();

    Widget deviceDropdown({
      required String label,
      required IconData icon,
      required List<MediaDeviceInfo> deviceList,
      required ValueNotifier<String> notifier,
      required Future<void> Function(String) onChanged,
    }) {
      return ValueListenableBuilder<String>(
        valueListenable: notifier,
        builder: (_, selected, __) {
          final validId =
              deviceList.any((d) => d.deviceId == selected) ? selected : '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: validId,
                    isExpanded: true,
                    isDense: false,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(28),
                    icon: Icon(Icons.expand_more_rounded,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.5)),
                    style:
                        TextStyle(fontSize: 13, color: colorScheme.onSurface),
                    dropdownColor: colorScheme.surfaceContainerHigh,
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          l.audioSystemDefault,
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.55)),
                        ),
                      ),
                      ...deviceList.map((d) => DropdownMenuItem(
                            value: d.deviceId,
                            child: Text(
                              d.label.isNotEmpty ? d.label : d.deviceId,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (id) => onChanged(id ?? ''),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        deviceDropdown(
          label: l.audioMicInput,
          icon: Icons.mic_rounded,
          deviceList: inputs,
          notifier: SettingsManager.audioInputDeviceId,
          onChanged: SettingsManager.setAudioInputDevice,
        ),
        if (outputs.isNotEmpty) ...[
          const SizedBox(height: 16),
          deviceDropdown(
            label: l.audioSpeakerOutput,
            icon: Icons.volume_up_rounded,
            deviceList: outputs,
            notifier: SettingsManager.audioOutputDeviceId,
            onChanged: SettingsManager.setAudioOutputDevice,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l.audioChangesNote,
          style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _buildLiquidElementSection({
    required BuildContext context,
    required String label,
    required String description,
    ValueListenable<dynamic>? toggleListenable,
    bool Function(dynamic)? toggleGetter,
    Future<void> Function(bool)? onToggle,
    required List<_LiquidItem> sliders,
    ValueNotifier<LiquidGlassQuality>? qualityNotifier,
    Future<void> Function(LiquidGlassQuality)? onQualityChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    // Without a toggle the block is always open (the "common settings" card).
    Widget buildBlock(bool enabled) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: enabled
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(description,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    if (onToggle != null)
                      Switch(value: enabled, onChanged: onToggle),
                  ],
                ),
              ),
              if (enabled) ...[
                Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (qualityNotifier != null &&
                          onQualityChanged != null) ...[
                        Text(AppLocalizations.of(context).glassQualityTitle,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ValueListenableBuilder<LiquidGlassQuality>(
                          valueListenable: qualityNotifier,
                          builder: (_, currentQuality, __) {
                            final primary = colorScheme.primary;
                            final surface = colorScheme.surfaceContainerHighest;
                            return Row(
                              children: LiquidGlassQuality.values.map((q) {
                                final sel = q == currentQuality;
                                final gl = AppLocalizations.of(context);
                                final (lbl, sub) = switch (q) {
                                  LiquidGlassQuality.fast => (
                                      gl.glassQualityFast,
                                      gl.glassQualityFastDesc
                                    ),
                                  LiquidGlassQuality.medium => (
                                      gl.glassQualityMedium,
                                      gl.glassQualityMediumDesc
                                    ),
                                  LiquidGlassQuality.quality => (
                                      gl.glassQualityHigh,
                                      gl.glassQualityHighDesc
                                    ),
                                };
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => onQualityChanged(q),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? primary.withValues(alpha: 0.15)
                                            : surface.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: sel
                                                ? primary
                                                : Colors.transparent,
                                            width: 1.5),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(lbl,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: sel
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                                  color: sel ? primary : null)),
                                          const SizedBox(height: 2),
                                          Text(sub,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey),
                                              maxLines: 2),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Divider(
                            height: 1,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                      ],
                      ...sliders.map((item) =>
                          _buildLiquidItem(context: context, item: item)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
    }

    if (toggleListenable == null || toggleGetter == null) {
      return buildBlock(true);
    }
    return ValueListenableBuilder(
      valueListenable: toggleListenable,
      builder: (_, val, __) => buildBlock(toggleGetter(val)),
    );
  }

  Widget _buildLiquidItem(
      {required BuildContext context, required _LiquidItem item}) {
    return switch (item) {
      _LiquidSliderConfig config =>
        _buildLiquidSlider(context: context, config: config),
      _LiquidToggleItem toggle =>
        _buildInlineLiquidToggle(context: context, item: toggle),
    };
  }

  Widget _buildLiquidSlider({
    required BuildContext context,
    required _LiquidSliderConfig config,
  }) =>
      _LiquidSliderTile(config: config);

  Widget _buildInlineLiquidToggle(
      {required BuildContext context, required _LiquidToggleItem item}) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: item.listenable,
      builder: (_, value, __) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(item.description,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Switch(value: value, onChanged: item.onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionIcon(IconData icon, int? hue) {
    final cs = Theme.of(context).colorScheme;
    if (hue == null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: cs.primary),
    );
  }

  Widget _buildLiquidGlassSection({
    required String title,
    required String subtitle,
    required SectionType section,
    required Widget Function() expandedContentBuilder,
    IconData? icon,
    int? iconHue,
  }) {
    final isExpanded =
        _expandedSection == section || _settingsSearchQuery.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    // In search mode: set ambient breadcrumb context, return flat content, then clear context
    if (_settingsSearchQuery.isNotEmpty) {
      _searchSectionLabel = title;
      _searchSectionIcon = icon;
      final content = expandedContentBuilder();
      _searchSectionLabel = null;
      _searchSectionIcon = null;
      return content;
    }

    return AdaptiveGlassCard(
      borderRadius: 28,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _toggleSection(section),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (icon != null) ...[
                    _buildSectionIcon(icon, iconHue),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
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
                    child: expandedContentBuilder(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubSection({
    required String key,
    required String title,
    required String subtitle,
    required Widget expandedContent,
    IconData? icon,
    List<String> keywords = const [],
    bool searchShowAll = false,
    String? trailingBadge,
    bool animateExpand = true,
  }) {
    // Capture breadcrumb context before visibility check clears it
    final breadcrumb = _searchSectionLabel;
    final breadcrumbIcon = _searchSectionIcon;

    final searchActive = _settingsSearchQuery.isNotEmpty;
    if (searchActive &&
        !searchShowAll &&
        !_sectionVisible(title, subtitle, keywords)) {
      return const SizedBox.shrink();
    }
    final isExpanded = (_expandedSubsectionKey == key) || searchActive;
    final colorScheme = Theme.of(context).colorScheme;

    final card = AdaptiveGlassCard(
      borderRadius: 28,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => setState(
                () => _expandedSubsectionKey = isExpanded ? null : key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 16, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (trailingBadge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        trailingBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: animateExpand
                  ? const Duration(milliseconds: 220)
                  : Duration.zero,
              curve: Curves.easeInOut,
              clipBehavior: Clip.hardEdge,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: expandedContent,
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );

    if (searchActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (breadcrumb != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 4),
              child: Row(
                children: [
                  if (breadcrumbIcon != null)
                    Icon(breadcrumbIcon, size: 13, color: colorScheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    breadcrumb,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          card,
          const SizedBox(height: 8),
        ],
      );
    }

    return card;
  }

  Widget _buildAppearanceContent() {
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final l = AppLocalizations.of(context);
    final showAll = _sectionVisible(l.appearanceTitle, l.appearanceSubtitle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Theme & Colors ────────────────────────
        _buildSubSection(
          key: 'appearance_theme',
          title: l.selectTheme,
          subtitle: l.darkMode,
          searchShowAll: showAll,
          icon: Icons.color_lens_rounded,
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: AppTheme.values.map((theme) {
                  final isSelected = widget.currentTheme == theme;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async =>
                            widget.onThemeChanged(theme, widget.isDarkMode),
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
                              fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(l.darkMode),
                  const SizedBox(width: 12),
                  Switch(
                    value: widget.isDarkMode,
                    onChanged: (val) async =>
                        widget.onThemeChanged(widget.currentTheme, val),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Typography ───────────────────────────
        _buildSubSection(
          key: 'appearance_typography',
          title: l.fontAndTextSize,
          subtitle: l.fontFamily,
          searchShowAll: showAll,
          icon: Icons.text_fields_rounded,
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Live bubble preview — the exact same MessageBubble widget
              // used in chat_screen, so it reacts to font/size settings
              // identically to a real message.
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MessageBubble(
                  text: l.fontPreviewMessage,
                  outgoing: true,
                  time: DateTime.now(),
                  peerUsername: 'preview',
                ),
              ),
              ValueListenableBuilder<FontFamilyType>(
                valueListenable: SettingsManager.fontFamily,
                builder: (_, currentFont, __) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.fontFamily,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
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
                                            brightness);
                                    return DraggableScrollableSheet(
                                      initialChildSize: 0.6,
                                      minChildSize: 0.4,
                                      maxChildSize: 0.95,
                                      expand: false,
                                      builder: (_, sc) => Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            12, 0, 12, 12),
                                        decoration: BoxDecoration(
                                            color: sheetColor,
                                            borderRadius:
                                                BorderRadius.circular(28)),
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
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 4),
                                              child: Text(l.fontFamily,
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: cs.onSurface)),
                                            ),
                                            Expanded(
                                              child: ListView(
                                                controller: sc,
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                children: FontFamilyType.values
                                                    .map((font) {
                                                  final isSel =
                                                      currentFont == font;
                                                  return ListTile(
                                                    title: Text(
                                                        font.displayName,
                                                        style: font
                                                            .getBodyTextStyle(
                                                                fontSize: 14)),
                                                    subtitle: Text(
                                                        l.localizeFontDescription(
                                                            font.description),
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: cs.onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.5))),
                                                    trailing: isSel
                                                        ? Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            color: cs.primary)
                                                        : Icon(
                                                            Icons
                                                                .radio_button_unchecked_rounded,
                                                            color: cs.onSurface
                                                                .withValues(
                                                                    alpha:
                                                                        0.3)),
                                                    selected: isSel,
                                                    selectedTileColor:
                                                        cs.primary.withValues(
                                                            alpha: 0.08),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    onTap: () async {
                                                      await SettingsManager
                                                          .setFontFamily(font);
                                                      if (ctx.mounted)
                                                        Navigator.of(ctx).pop();
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.05),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                  ),
                                  child: Text(
                                    'Aa',
                                    style: currentFont
                                        .getBodyTextStyle(fontSize: 17)
                                        .copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(currentFont.displayName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                          l.localizeFontDescription(
                                              currentFont.description),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.06),
                                  ),
                                  child: Icon(Icons.chevron_right_rounded,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.55)),
                                ),
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
                  final cs = Theme.of(context).colorScheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l.messageSize,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${(sizeMultiplier * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: List.generate(values.length, (idx) {
                            final val = values[idx];
                            final label = labels[idx];
                            final isSel = (sizeMultiplier - val).abs() < 0.01;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () async =>
                                    SettingsManager.setFontSizeMultiplier(val),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color:
                                        isSel ? cs.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Center(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 13,
                                        color: isSel
                                            ? cs.onPrimary
                                            : cs.onSurface
                                                .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: cs.primary,
                          inactiveTrackColor:
                              cs.primary.withValues(alpha: 0.15),
                          thumbColor: cs.primary,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
                          value: sizeMultiplier,
                          min: 0.8,
                          max: 1.3,
                          divisions: 10,
                          onChanged: (val) async =>
                              SettingsManager.setFontSizeMultiplier(val),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Chat Display ─────────────────────────
        _buildSubSection(
          key: 'appearance_chat',
          title: l.appearanceChatDisplayTitle,
          subtitle: l.appearanceChatDisplaySubtitle,
          searchShowAll: showAll,
          icon: Icons.chat_bubble_outline_rounded,
          keywords: [
            l.ownMessagesRight,
            l.ownMessagesLeft,
            l.alignAllRight,
            l.alignAllRightSubtitle,
            l.showAvatarsInChats,
            l.showAvatarSubtitle,
            l.showAccountIndicator,
            l.showAccountIndicatorSubtitle,
            l.smoothScrollDown,
            l.messageAnimations,
            l.chatListMoveAnimations,
            l.loadOlderMessagesOnScroll,
            l.showSnackbars,
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.swapMessageAlignment,
                builder: (_, swapped, __) => Row(
                  children: [
                    Text(swapped ? l.ownMessagesLeft : l.ownMessagesRight),
                    const SizedBox(width: 12),
                    Switch(
                        value: swapped,
                        onChanged: (val) async =>
                            SettingsManager.setSwapMessageAlignment(val)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.swapMessageAlignment,
                builder: (_, swappedMsg, __) => ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.alignAllMessagesRight,
                  builder: (_, alignRight, __) => Row(
                    children: [
                      Text(alignRight
                          ? (swappedMsg
                              ? l.allMessagesLeft
                              : l.allMessagesRight2)
                          : l.allMessagesMixed),
                      const SizedBox(width: 12),
                      Switch(
                          value: alignRight,
                          onChanged: (val) async =>
                              SettingsManager.setAlignAllMessagesRight(val)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.showAvatarInChats,
                builder: (_, showAvatar, __) => Row(
                  children: [
                    Text(l.showAvatarsInChats),
                    const SizedBox(width: 12),
                    Switch(
                        value: showAvatar,
                        onChanged: (val) async =>
                            SettingsManager.setShowAvatarInChats(val)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.showAccountIndicator,
                builder: (_, showInd, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l.showAccountIndicator),
                        const SizedBox(width: 12),
                        Switch(
                            value: showInd,
                            onChanged: (val) async =>
                                SettingsManager.setShowAccountIndicator(val)),
                      ],
                    ),
                    Text(l.showAccountIndicatorSubtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.smoothScrollEnabled,
                builder: (_, v, __) => Row(
                  children: [
                    Text(l.smoothScrollDown),
                    const SizedBox(width: 12),
                    Switch(
                        value: v,
                        onChanged: (val) async =>
                            SettingsManager.setSmoothScroll(val)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.messageAnimationsEnabled,
                builder: (_, v, __) => Row(
                  children: [
                    Text(l.messageAnimations),
                    const SizedBox(width: 12),
                    Switch(
                        value: v,
                        onChanged: (val) async =>
                            SettingsManager.setMessageAnimationsEnabled(val)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.chatListMoveAnimationsEnabled,
                builder: (_, v, __) => Row(
                  children: [
                    Text(l.chatListMoveAnimations),
                    const SizedBox(width: 12),
                    Switch(
                        value: v,
                        onChanged: (val) async =>
                            SettingsManager.setChatListMoveAnimationsEnabled(
                                val)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.messagePaginationEnabled,
                builder: (_, v, __) => Row(
                  children: [
                    Text(l.loadOlderMessagesOnScroll),
                    const SizedBox(width: 12),
                    Switch(
                        value: v,
                        onChanged: (val) async =>
                            SettingsManager.setMessagePaginationEnabled(val)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.snackbarEnabled,
                builder: (_, v, __) => Row(
                  children: [
                    Text(l.showSnackbars),
                    const SizedBox(width: 12),
                    Switch(
                        value: v,
                        onChanged: (val) async =>
                            SettingsManager.setSnackbarEnabled(val)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(l.scrollDownButtonPosition,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ValueListenableBuilder<ScrollDownButtonPosition>(
                valueListenable: SettingsManager.scrollDownButtonPosition,
                builder: (_, selected, __) {
                  final options =
                      <(ScrollDownButtonPosition, IconData, String)>[
                    (
                      ScrollDownButtonPosition.left,
                      Icons.format_align_left_rounded,
                      l.scrollDownButtonPositionLeft
                    ),
                    (
                      ScrollDownButtonPosition.center,
                      Icons.format_align_center_rounded,
                      l.scrollDownButtonPositionCenter
                    ),
                    (
                      ScrollDownButtonPosition.right,
                      Icons.format_align_right_rounded,
                      l.scrollDownButtonPositionRight
                    ),
                  ];
                  return Column(
                    children: options.map((opt) {
                      final (pos, icon, label) = opt;
                      final isSel = selected == pos;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () async =>
                              SettingsManager.setScrollDownButtonPosition(pos),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                                width: isSel ? 2 : 1,
                              ),
                              color: isSel
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1)
                                  : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Icon(icon,
                                    size: 18,
                                    color: isSel
                                        ? Theme.of(context).colorScheme.primary
                                        : null),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(label,
                                      style: TextStyle(
                                          fontWeight: isSel
                                              ? FontWeight.w600
                                              : FontWeight.normal)),
                                ),
                                if (isSel)
                                  Icon(Icons.check_rounded,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.scrollDownButtonSize,
                builder: (_, size, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.scrollDownButtonSize,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            min: 28.0,
                            max: 56.0,
                            divisions: 14,
                            value: size,
                            label: '${size.toInt()} px',
                            onChanged: (v) =>
                                SettingsManager.setScrollDownButtonSize(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                            width: 50,
                            child: Text('${size.toInt()} px',
                                textAlign: TextAlign.right)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Background ───────────────────────────
        _buildSubSection(
          key: 'appearance_background',
          title: l.chatBackground,
          subtitle: 'Wallpaper, blur and opacity',
          searchShowAll: showAll,
          icon: Icons.wallpaper_rounded,
          keywords: [
            l.blurBackground,
            l.presetsBackground,
            l.applyGlobally,
            l.applyGloballySubtitle,
            l.elementOpacity,
            l.elementBrightness,
            'wallpaper',
            'opacity',
            'brightness',
            l.chooseBackground,
            l.clearBackground2,
          ],
          expandedContent: ValueListenableBuilder<String?>(
            valueListenable: SettingsManager.chatVideoBackground,
            builder: (_, videoPath, __) => ValueListenableBuilder<String?>(
              valueListenable: SettingsManager.chatBackground,
              builder: (_, path, __) {
                final aspect = isDesktop ? (16 / 9) : (9 / 16);
                Widget preview;
                if (videoPath != null && File(videoPath).existsSync()) {
                  preview = ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                        aspectRatio: aspect,
                        child: _VideoPreviewWidget(path: videoPath)),
                  );
                } else if (path != null && File(path).existsSync()) {
                  preview = ClipRRect(
                    borderRadius: BorderRadius.circular(28),
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
                                  valueListenable: SettingsManager.blurSigma,
                                  builder: (_, sigma, __) => AdaptiveBlur(
                                      imageProvider: provider,
                                      sigma: sigma,
                                      fit: BoxFit.cover),
                                )
                              : img;
                        },
                      ),
                    ),
                  );
                } else {
                  preview = ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.elementOpacity,
                        builder: (_, opacity, __) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: opacity * 0.47),
                          child: Icon(Icons.photo_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: isDesktop ? 320 : 160, child: preview),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAppleButton(
                            icon: Icons.photo_outlined,
                            label: l.chooseBackground,
                            onPressed: _pickChatBackground),
                        _buildAppleButton(
                            icon: Icons.auto_awesome_rounded,
                            label: l.presetsBackground,
                            onPressed: _showPresetsSheet),
                        if (path != null || videoPath != null)
                          _buildAppleButton(
                            icon: Icons.close_rounded,
                            label: l.clearBackground2,
                            onPressed: () async {
                              await _clearChatBackground();
                              await _clearChatVideoBackground();
                            },
                            isDestructive: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.applyGlobally,
                      builder: (_, apply, __) => SwitchListTile(
                        title: Text(l.applyBackgroundToApp),
                        value: apply,
                        onChanged: (val) =>
                            SettingsManager.setApplyGlobally(val),
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<double>(
                      valueListenable: SettingsManager.elementOpacity,
                      builder: (_, opacity, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.uiElementsOpacityLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                                          '${(opacity * 100).toStringAsFixed(0)}%',
                                      onChanged: (v) =>
                                          SettingsManager.setElementOpacity(
                                              v))),
                              const SizedBox(width: 8),
                              SizedBox(
                                  width: 50,
                                  child: Text(
                                      '${(opacity * 100).toStringAsFixed(0)}%',
                                      textAlign: TextAlign.right)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<double>(
                      valueListenable: SettingsManager.elementBrightness,
                      builder: (_, brightness, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.uiElementsBrightnessLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                                          '${(brightness * 100).toStringAsFixed(0)}%',
                                      onChanged: (v) =>
                                          SettingsManager.setElementBrightness(
                                              v))),
                              const SizedBox(width: 8),
                              SizedBox(
                                  width: 50,
                                  child: Text(
                                      '${(brightness * 100).toStringAsFixed(0)}%',
                                      textAlign: TextAlign.right)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Layout ───────────────────────────────
        _buildSubSection(
          key: 'appearance_layout',
          title: l.appearanceLayoutTitle,
          subtitle: l.appearanceLayoutSubtitle,
          searchShowAll: showAll,
          icon: Icons.view_quilt_rounded,
          keywords: [
            l.inputBarMaxWidth,
            l.navPanelPosition,
            l.minimizeBottomNav,
            l.minimizeBottomNavSubtitle,
            l.swipeTabs,
            l.swipeTabsSubtitle,
            l.tabSwiping,
            l.tabSwipingSubtitle,
            l.navBarPosition,
            l.uiLayout,
            l.smoothScroll,
            'navigation',
            'sidebar',
            l.accountGraph,
            l.accountGraphSubtitleDesktopOn,
            l.accountGraphSubtitleMobileOn,
            l.accountGraphSubtitleDesktopOff,
            l.accountGraphSubtitleMobileOff,
            l.animateGraph,
            l.orbitSpeed,
            'account graph',
            'график аккаунтов',
            'графа аккаунтов',
          ],
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) ...[
                ValueListenableBuilder<double>(
                  valueListenable: SettingsManager.inputBarMaxWidth,
                  builder: (_, width, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.inputBarMaxWidth,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                      SettingsManager.setInputBarMaxWidth(v))),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 72,
                              child: Text('${width.toInt()} px',
                                  textAlign: TextAlign.right)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: SettingsManager.desktopNavPosition,
                  builder: (_, navPos, __) {
                    final isBottom = navPos == 'bottom';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.navPanelPosition,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(isBottom ? l.navPosBottom : l.navPosLeft),
                            const SizedBox(width: 12),
                            Switch(
                                value: isBottom,
                                onChanged: (val) async =>
                                    SettingsManager.setDesktopNavPosition(
                                        val ? 'bottom' : 'left')),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              ValueListenableBuilder<bool>(
                valueListenable: SettingsManager.showAccountGraph,
                builder: (_, showGraph, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.accountGraph,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        showGraph
                            ? (isDesktop
                                ? l.accountGraphSubtitleDesktopOn
                                : l.accountGraphSubtitleMobileOn)
                            : (isDesktop
                                ? l.accountGraphSubtitleDesktopOff
                                : l.accountGraphSubtitleMobileOff),
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      value: showGraph,
                      onChanged: (v) => SettingsManager.setShowAccountGraph(v),
                    ),
                    if (showGraph) ...[
                      const SizedBox(height: 4),
                      ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.graphOrbitSpeed,
                        builder: (_, speed, __) {
                          final label = speed < 60
                              ? l.secOrbit(speed.round())
                              : l.minOrbit((speed / 60).round());
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l.orbitSpeed,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ],
                              ),
                              Slider(
                                  min: 30.0,
                                  max: 600.0,
                                  value: speed,
                                  onChanged:
                                      SettingsManager.setGraphOrbitSpeed),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<bool>(
                        valueListenable: SettingsManager.graphAnimation,
                        builder: (_, anim, __) => SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.animateGraph,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              anim ? l.animateGraphOn : l.animateGraphOff,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          value: anim,
                          onChanged: SettingsManager.setGraphAnimation,
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: SettingsManager.graphPreservePosition,
                        builder: (_, preserve, __) => SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.preserveView,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              preserve ? l.preserveViewOn : l.preserveViewOff,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          value: preserve,
                          onChanged: SettingsManager.setGraphPreservePosition,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.swipeTabsEnabled,
                  builder: (_, swipeTabs, __) => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.tabSwiping,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(l.tabSwipingSubtitle,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Switch(
                          value: swipeTabs,
                          onChanged: (val) async =>
                              SettingsManager.setSwipeTabsEnabled(val)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!Platform.isWindows && !Platform.isLinux) ...[
          const SizedBox(height: 8),
          // ── Liquid Glass ─────────────────────────
          _buildSubSection(
            key: 'appearance_glass',
            title: l.appearanceLiquidGlassTitle,
            subtitle: l.liquidGlassSubtitle,
            searchShowAll: showAll,
            icon: Icons.blur_on_rounded,
            keywords: [
              l.liquidGlassNavBarLabel,
              l.liquidGlassNavBarDesc,
              l.liquidGlassInputLabel,
              l.liquidGlassInputDesc,
              l.liquidGlassSearchLabel,
              l.liquidGlassSearchDesc,
              l.liquidGlassAppBarLabel,
              l.liquidGlassAppBarDesc,
              'blur',
              'tint',
              'glass',
              'chromatic',
              'refraction',
              'opacity',
              'saturation',
            ],
            // Its own paint layer, so the open/close animation of this tall
            // list doesn't repaint the whole settings page every frame.
            expandedContent:
                RepaintBoundary(child: _buildLiquidGlassBody(context, l)),
          ),
        ],
      ],
    );
  }

  // ── Liquid Glass: one common block + an "Advanced" accordion ──────────────
  // min, max, divisions, format kind
  // (0 integer, 1 percent, 2 one decimal, 3 two decimals)
  static const _glassSliderSpecs = <(double, double, int, int)>[
    (0, 15, 15, 0), // blur
    (0, 0.30, 30, 1), // tint
    (0.3, 2.0, 17, 2), // saturation
    (0, 1.0, 20, 3), // chromatic aberration
    (1.0, 2.5, 15, 3), // refractive index
    (0, 1.0, 20, 3), // light intensity
    (0, 60, 12, 0), // thickness
  ];

  List<(String, String)> _glassTexts(AppLocalizations l) => [
        (l.glassBlur, l.glassBlurDesc),
        (l.glassTint, l.glassTintDesc),
        (l.glassSaturation, l.glassSaturationDesc),
        (l.glassChromatic, l.glassChromaticDesc),
        (l.glassRefractive, l.glassRefractiveDesc),
        (l.glassLight, l.glassLightDesc),
        (l.glassThickness, l.glassThicknessDesc),
      ];

  // Per element, in the order of _glassSliderSpecs: blur, tint, saturation,
  // chromatic, refractive, light intensity, thickness.
  static final _glassNav = (
    <ValueNotifier<double>>[
      SettingsManager.liquidGlassBlur,
      SettingsManager.liquidGlassTint,
      SettingsManager.liquidGlassSaturation,
      SettingsManager.liquidGlassChromatic,
      SettingsManager.liquidGlassRefractive,
      SettingsManager.liquidGlassLightIntensity,
      SettingsManager.liquidGlassThickness,
    ],
    <Future<void> Function(double)>[
      SettingsManager.setLiquidGlassBlur,
      SettingsManager.setLiquidGlassTint,
      SettingsManager.setLiquidGlassSaturation,
      SettingsManager.setLiquidGlassChromatic,
      SettingsManager.setLiquidGlassRefractive,
      SettingsManager.setLiquidGlassLightIntensity,
      SettingsManager.setLiquidGlassThickness,
    ],
  );
  static final _glassInput = (
    <ValueNotifier<double>>[
      SettingsManager.liquidGlassInputBlur,
      SettingsManager.liquidGlassInputTint,
      SettingsManager.liquidGlassInputSaturation,
      SettingsManager.liquidGlassInputChromatic,
      SettingsManager.liquidGlassInputRefractive,
      SettingsManager.liquidGlassInputLightIntensity,
      SettingsManager.liquidGlassInputThickness,
    ],
    <Future<void> Function(double)>[
      SettingsManager.setLiquidGlassInputBlur,
      SettingsManager.setLiquidGlassInputTint,
      SettingsManager.setLiquidGlassInputSaturation,
      SettingsManager.setLiquidGlassInputChromatic,
      SettingsManager.setLiquidGlassInputRefractive,
      SettingsManager.setLiquidGlassInputLightIntensity,
      SettingsManager.setLiquidGlassInputThickness,
    ],
  );
  static final _glassSearch = (
    <ValueNotifier<double>>[
      SettingsManager.liquidGlassSearchBlur,
      SettingsManager.liquidGlassSearchTint,
      SettingsManager.liquidGlassSearchSaturation,
      SettingsManager.liquidGlassSearchChromatic,
      SettingsManager.liquidGlassSearchRefractive,
      SettingsManager.liquidGlassSearchLightIntensity,
      SettingsManager.liquidGlassSearchThickness,
    ],
    <Future<void> Function(double)>[
      SettingsManager.setLiquidGlassSearchBlur,
      SettingsManager.setLiquidGlassSearchTint,
      SettingsManager.setLiquidGlassSearchSaturation,
      SettingsManager.setLiquidGlassSearchChromatic,
      SettingsManager.setLiquidGlassSearchRefractive,
      SettingsManager.setLiquidGlassSearchLightIntensity,
      SettingsManager.setLiquidGlassSearchThickness,
    ],
  );
  static final _glassAppBar = (
    <ValueNotifier<double>>[
      SettingsManager.liquidGlassAppBarBlur,
      SettingsManager.liquidGlassAppBarTint,
      SettingsManager.liquidGlassAppBarSaturation,
      SettingsManager.liquidGlassAppBarChromatic,
      SettingsManager.liquidGlassAppBarRefractive,
      SettingsManager.liquidGlassAppBarLightIntensity,
      SettingsManager.liquidGlassAppBarThickness,
    ],
    <Future<void> Function(double)>[
      SettingsManager.setLiquidGlassAppBarBlur,
      SettingsManager.setLiquidGlassAppBarTint,
      SettingsManager.setLiquidGlassAppBarSaturation,
      SettingsManager.setLiquidGlassAppBarChromatic,
      SettingsManager.setLiquidGlassAppBarRefractive,
      SettingsManager.setLiquidGlassAppBarLightIntensity,
      SettingsManager.setLiquidGlassAppBarThickness,
    ],
  );

  /// The navigation bar's defaults -- the defaults of every glass element.
  static const _glassDefaults = <double>[7, 0.10, 1.0, 0.30, 1.59, 0.60, 30];

  String _glassFormat(int kind, double v) => switch (kind) {
        0 => v.toStringAsFixed(0),
        1 => '${(v * 100).toStringAsFixed(0)}%',
        2 => v.toStringAsFixed(1),
        _ => v.toStringAsFixed(2),
      };

  /// Sliders for one element, or -- with several [elements] -- one set that
  /// shows the first element's values and writes every change to all of them.
  List<_LiquidItem> _glassSliders(
    AppLocalizations l,
    List<(List<ValueNotifier<double>>, List<Future<void> Function(double)>)>
        elements, {
    List<_LiquidItem> extra = const [],
  }) {
    final texts = _glassTexts(l);
    return [
      for (var i = 0; i < _glassSliderSpecs.length; i++)
        _LiquidSliderConfig(
          label: texts[i].$1,
          description: texts[i].$2,
          listenable: elements.first.$1[i],
          min: _glassSliderSpecs[i].$1,
          max: _glassSliderSpecs[i].$2,
          divisions: _glassSliderSpecs[i].$3,
          format: (v) => _glassFormat(_glassSliderSpecs[i].$4, v),
          onChanged: (v) async {
            for (final e in elements) {
              await e.$2[i](v);
            }
          },
        ),
      ...extra,
    ];
  }

  Future<void> _setGlassQualityAll(LiquidGlassQuality q) async {
    await SettingsManager.setLiquidGlassNavBarQuality(q);
    await SettingsManager.setLiquidGlassInputQuality(q);
    await SettingsManager.setLiquidGlassSearchQuality(q);
    await SettingsManager.setLiquidGlassAppBarQuality(q);
  }

  Future<void> _resetGlassToDefaults() async {
    for (final e in [_glassNav, _glassInput, _glassSearch, _glassAppBar]) {
      for (var i = 0; i < _glassDefaults.length; i++) {
        await e.$2[i](_glassDefaults[i]);
      }
    }
    await _setGlassQualityAll(LiquidGlassQuality.quality);
    await SettingsManager.setLiquidGlassExpansion(14);
  }

  Future<void> _setAllGlassElements(bool on) async {
    await SettingsManager.setLiquidGlassOnNavBar(on);
    await SettingsManager.setLiquidGlassOnInput(on);
    await SettingsManager.setLiquidGlassOnSearch(on);
    await SettingsManager.setLiquidGlassOnAppBar(on);
  }

  /// "General" mode: the navigation bar's values become everybody's.
  Future<void> _applyGlassCommonToAll() async {
    for (final e in [_glassInput, _glassSearch, _glassAppBar]) {
      for (var i = 0; i < _glassNav.$1.length; i++) {
        await e.$2[i](_glassNav.$1[i].value);
      }
    }
    await _setGlassQualityAll(SettingsManager.liquidGlassNavBarQuality.value);
  }

  Future<void> _setGlassMaster(bool on) async {
    if (!on) {
      final mask = (SettingsManager.liquidGlassOnNavBar.value ? 1 : 0) |
          (SettingsManager.liquidGlassOnInput.value ? 2 : 0) |
          (SettingsManager.liquidGlassOnSearch.value ? 4 : 0) |
          (SettingsManager.liquidGlassOnAppBar.value ? 8 : 0);
      if (mask != 0) await SettingsManager.setLiquidGlassSavedFlags(mask);
      await SettingsManager.setLiquidGlassMaster(false);
      await _setAllGlassElements(false);
      return;
    }
    await SettingsManager.setLiquidGlassMaster(true);
    if (!SettingsManager.liquidGlassAdvancedMode.value) {
      await _setAllGlassElements(true);
      await _applyGlassCommonToAll();
    } else {
      final m = SettingsManager.liquidGlassSavedFlags == 0
          ? 15
          : SettingsManager.liquidGlassSavedFlags;
      await SettingsManager.setLiquidGlassOnNavBar(m & 1 != 0);
      await SettingsManager.setLiquidGlassOnInput(m & 2 != 0);
      await SettingsManager.setLiquidGlassOnSearch(m & 4 != 0);
      await SettingsManager.setLiquidGlassOnAppBar(m & 8 != 0);
    }
  }

  Future<void> _setGlassAdvancedMode(bool advanced) async {
    if (SettingsManager.liquidGlassAdvancedMode.value == advanced) return;
    await SettingsManager.setLiquidGlassAdvancedMode(advanced);
    if (!advanced) {
      // Back to "General": every element on, with the common values.
      await _setAllGlassElements(true);
      await _applyGlassCommonToAll();
    }
  }

  BoxDecoration _glassCardDecoration(ColorScheme cs, {bool active = false}) =>
      BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: active
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.15),
        ),
      );

  Widget _buildGlassTabs(
      ColorScheme cs, AppLocalizations l, bool advanced) {
    Widget tab(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _glassCardDecoration(cs),
      child: Row(
        children: [
          tab(l.glassTabGeneral, !advanced, () => _setGlassAdvancedMode(false)),
          tab(l.glassTabAdvanced, advanced, () => _setGlassAdvancedMode(true)),
        ],
      ),
    );
  }

  Widget _buildLiquidGlassBody(BuildContext context, AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        SettingsManager.liquidGlassMaster,
        SettingsManager.liquidGlassAdvancedMode,
      ]),
      builder: (_, __) {
        final master = SettingsManager.liquidGlassMaster.value;
        final advanced = SettingsManager.liquidGlassAdvancedMode.value;
        final all = [_glassNav, _glassInput, _glassSearch, _glassAppBar];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Master switch.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: _glassCardDecoration(cs, active: master),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.glassMasterTitle,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(l.glassMasterDesc,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  Switch(value: master, onChanged: _setGlassMaster),
                ],
              ),
            ),
            // Effects off: nothing else is built or shown.
            if (master) ...[
              const SizedBox(height: 12),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGlassTabs(cs, l, advanced),
                    const SizedBox(height: 12),
                    if (!advanced) ...[
                      // General: one set of values for every element.
                      _buildLiquidElementSection(
                        context: context,
                        label: l.glassSimpleTitle,
                        description: l.glassSimpleDesc,
                        qualityNotifier:
                            SettingsManager.liquidGlassNavBarQuality,
                        onQualityChanged: _setGlassQualityAll,
                        sliders: _glassSliders(l, all),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await _resetGlassToDefaults();
                          },
                          icon: const Icon(Icons.restart_alt_rounded,
                              size: 18),
                          label: Text(l.glassResetAll),
                        ),
                      ),
                    ] else ...[
                      // Advanced: every element on/off and tuned on its own.
                      _buildLiquidElementSection(
                        context: context,
                        label: l.liquidGlassNavBarLabel,
                        description: l.liquidGlassNavBarDesc,
                        toggleListenable: SettingsManager.liquidGlassOnNavBar,
                        toggleGetter: (v) => v as bool,
                        onToggle: SettingsManager.setLiquidGlassOnNavBar,
                        qualityNotifier:
                            SettingsManager.liquidGlassNavBarQuality,
                        onQualityChanged:
                            SettingsManager.setLiquidGlassNavBarQuality,
                        sliders: _glassSliders(l, [
                          _glassNav
                        ], extra: [
                          _LiquidSliderConfig(
                              label: l.glassJelly,
                              description: l.glassJellyDesc,
                              listenable:
                                  SettingsManager.liquidGlassExpansion,
                              min: 0,
                              max: 28,
                              divisions: 28,
                              format: (v) => v.toStringAsFixed(0),
                              onChanged:
                                  SettingsManager.setLiquidGlassExpansion),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      _buildLiquidElementSection(
                        context: context,
                        label: l.liquidGlassInputLabel,
                        description: l.liquidGlassInputDesc,
                        toggleListenable: SettingsManager.liquidGlassOnInput,
                        toggleGetter: (v) => v as bool,
                        onToggle: SettingsManager.setLiquidGlassOnInput,
                        qualityNotifier:
                            SettingsManager.liquidGlassInputQuality,
                        onQualityChanged:
                            SettingsManager.setLiquidGlassInputQuality,
                        sliders: _glassSliders(l, [_glassInput]),
                      ),
                      const SizedBox(height: 12),
                      _buildLiquidElementSection(
                        context: context,
                        label: l.liquidGlassSearchLabel,
                        description: l.liquidGlassSearchDesc,
                        toggleListenable: SettingsManager.liquidGlassOnSearch,
                        toggleGetter: (v) => v as bool,
                        onToggle: SettingsManager.setLiquidGlassOnSearch,
                        qualityNotifier:
                            SettingsManager.liquidGlassSearchQuality,
                        onQualityChanged:
                            SettingsManager.setLiquidGlassSearchQuality,
                        sliders: _glassSliders(l, [_glassSearch]),
                      ),
                      const SizedBox(height: 12),
                      _buildLiquidElementSection(
                        context: context,
                        label: l.liquidGlassAppBarLabel,
                        description: l.liquidGlassAppBarDesc,
                        toggleListenable: SettingsManager.liquidGlassOnAppBar,
                        toggleGetter: (v) => v as bool,
                        onToggle: SettingsManager.setLiquidGlassOnAppBar,
                        qualityNotifier:
                            SettingsManager.liquidGlassAppBarQuality,
                        onQualityChanged:
                            SettingsManager.setLiquidGlassAppBarQuality,
                        sliders: _glassSliders(l, [_glassAppBar]),
                      ),
                    ],
                  ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAppleButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isDestructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive
        ? Colors.red.shade400
        : cs.onSurface.withValues(alpha: 0.85);
    final bgColor = isDestructive
        ? Colors.red.withValues(alpha: 0.10)
        : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: (isDestructive ? Colors.red : cs.outlineVariant)
                  .withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
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
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: buttonWidth,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(999),
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    shape: const StadiumBorder(),
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

enum SectionType {
  security,
  notifications,
  appearance,
  language,
  cache,
  connection,
  interact,
  contact,
  audio,
  wardLink,
  mesh,
  onionMode,
  backup,
  recycleBin
}

// ── Inline change-password form, embedded as a Security sub-section instead
// of a modal dialog so it matches the WardLink-style nested-accordion look.
class _ChangePasswordForm extends StatefulWidget {
  final Future<void> Function(
      String passphrase, String oldPassword, String newPassword) onSubmit;
  final void Function(String) onSnack;

  const _ChangePasswordForm({required this.onSubmit, required this.onSnack});

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _passphraseCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(
    BuildContext ctx, {
    required String label,
    required IconData prefixIconData,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final brightness = SettingsManager.elementBrightness.value;
    final fillColor =
        SettingsManager.getElementColor(cs.surfaceContainerHighest, brightness);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
      prefixIcon:
          Icon(prefixIconData, color: cs.onSurface.withValues(alpha: 0.6)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
    );
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final passphrase = _passphraseCtrl.text.trim();
    final oldPass = _oldPassCtrl.text;
    final newPass = _newPassCtrl.text;

    if (passphrase.isEmpty || oldPass.isEmpty || newPass.isEmpty) {
      widget.onSnack(l.changePasswordFieldsRequired);
      return;
    }
    if (newPass.length < 16) {
      widget.onSnack(l.changePasswordTooShort);
      return;
    }

    setState(() => _submitting = true);
    widget.onSnack(l.changePasswordChanging);
    try {
      await widget.onSubmit(passphrase, oldPass, newPass);
      widget.onSnack(l.changePasswordSuccess);
      _passphraseCtrl.clear();
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
    } catch (e) {
      widget.onSnack(' $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
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
                child: Text(l.changePasswordInfo,
                    style:
                        TextStyle(fontSize: 13, color: cs.onPrimaryContainer)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passphraseCtrl,
          style: TextStyle(color: cs.onSurface),
          decoration: _dec(context,
              label: l.changePasswordPassphraseLabel,
              prefixIconData: Icons.key_rounded),
          maxLines: 2,
          minLines: 1,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _oldPassCtrl,
          obscureText: _obscureOld,
          style: TextStyle(color: cs.onSurface),
          decoration: _dec(
            context,
            label: l.changePasswordCurrentLabel,
            prefixIconData: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility,
                  size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
              onPressed: () => setState(() => _obscureOld = !_obscureOld),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          style: TextStyle(color: cs.onSurface),
          decoration: _dec(
            context,
            label: l.changePasswordNewLabel,
            prefixIconData: Icons.lock_reset,
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility,
                  size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(l.changePasswordChange),
          ),
        ),
      ],
    );
  }
}

// ── WardLink QR pairing dialog ────────────────────────────────────────────────

class _WardLinkQrDialog extends StatefulWidget {
  const _WardLinkQrDialog();
  @override
  State<_WardLinkQrDialog> createState() => _WardLinkQrDialogState();
}

class _WardLinkQrDialogState extends State<_WardLinkQrDialog> {
  String? _qrJson;
  String? _username;
  String? _error;
  bool _showScanner = false;
  bool _handled = false;
  bool _busy = false;
  bool _poppingDialog = false;
  MobileScannerController? _scanCtrl;
  int _initialDeviceCount = 0;

  bool get _isMobile =>
      !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _initialDeviceCount = WardLinkPairedDevices.devices.value.length;
    WardLinkPairedDevices.devices.addListener(_onDevicesChanged);
    _prepare();
  }

  @override
  void dispose() {
    WardLinkPairedDevices.devices.removeListener(_onDevicesChanged);
    _scanCtrl?.dispose();
    super.dispose();
  }

  // Fires when the other device scans our QR and the daemon saves the pairing.
  void _onDevicesChanged() {
    if (!mounted) return;
    // If _handled is true, we're the scanning device and _onDetect is already
    // managing the pop — skip here to avoid a double Navigator.pop that would
    // dismiss the settings tab and leave a black screen.
    if (_handled || _poppingDialog) return;
    if (WardLinkPairedDevices.devices.value.length > _initialDeviceCount) {
      _poppingDialog = true;
      // Stop camera first so it doesn't flash black during the pop animation.
      _scanCtrl?.dispose();
      _scanCtrl = null;
      final l = AppLocalizations.of(context);
      // Defer the pop to the next frame — the listener may fire synchronously
      // inside an HTTP handler; calling Navigator.pop inside that can corrupt
      // the widget tree and cause a black screen on both devices.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        rootScreenKey.currentState?.showSnack(l.wardLinkPairedOk);
      });
    }
  }

  Future<void> _prepare() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) {
      if (mounted) setState(() => _error = 'Not logged in');
      return;
    }
    await WardLinkSyncService.instance.start(username);
    final qr = await WardLinkSyncService.instance.pairingQrJson(username);
    if (mounted)
      setState(() {
        _username = username;
        _qrJson = qr;
      });
  }

  void _startScan() {
    _scanCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _showScanner = true;
      _handled = false;
      _error = null;
    });
  }

  void _stopScan() {
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() => _showScanner = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _username == null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.contains('wardlink_pair')) return;
    _handled = true;
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() {
      _showScanner = false;
      _busy = true;
    });

    final err = await WardLinkSyncService.instance
        .completePairingFromQr(raw, _username!);
    if (!mounted) return;
    setState(() => _busy = false);

    final l = AppLocalizations.of(context);
    if (err == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        rootScreenKey.currentState?.showSnack(l.wardLinkPairedOk);
      });
    } else {
      setState(() => _error = '${l.wardLinkPairFailed}: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    // ── Scanner view ───────────────────────────────────────────────────────────
    if (_showScanner && _scanCtrl != null) {
      return OnyxDialogShell(
        maxWidth: 340,
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
                child: Icon(Icons.qr_code_scanner_rounded,
                    size: 20, color: cs.primary),
              ),
              title: Text(
                l.wardLinkScanCode,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
              onClose: _stopScan,
            ),
            RepaintBoundary(
              child: SizedBox(
                height: 260,
                child: MobileScanner(
                  controller: _scanCtrl!,
                  onDetect: _onDetect,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                l.wardLinkScanInstruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: OutlinedButton(
                onPressed: _stopScan,
                style: OutlinedButton.styleFrom(
                  padding: kOnyxDialogButtonPadding,
                  shape: kOnyxDialogButtonShape,
                ),
                child: Text(l.cancel),
              ),
            ),
          ],
        ),
      );
    }

    // ── QR / loading / error view ──────────────────────────────────────────────
    Widget body;
    if (_busy) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null && _qrJson == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(_error!,
            style: TextStyle(color: cs.error), textAlign: TextAlign.center),
      );
    } else if (_qrJson == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.wardLinkShowInstruction,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              // QrImageView regenerates its QR matrix (Reed-Solomon ECC etc.)
              // in paint(), not just build() — without this boundary, the
              // dialog's close scale/fade transition (which repaints its
              // subtree every frame without rebuilding it) would re-run that
              // expensive computation ~11 times over the 187ms transition.
              // The boundary caches the rasterized QR as its own layer so
              // the transition just transforms/fades the cached bitmap.
              child: RepaintBoundary(
                child: QrImageView(
                  data: _qrJson!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: cs.primary),
              const SizedBox(width: 5),
              Text(
                l.wardLinkE2E,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: cs.error, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ],
      );
    }

    return OnyxDialogShell(
      maxWidth: 340,
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
              child: Icon(Icons.devices_other_rounded,
                  size: 20, color: cs.primary),
            ),
            title: Text(
              l.wardLinkPairTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface),
            ),
            onClose: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: body,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isMobile && _qrJson != null && !_busy)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: kOnyxDialogButtonPadding,
                      shape: kOnyxDialogButtonShape,
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(l.wardLinkScanCode),
                    onPressed: _startScan,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onion Mode pairing dialog ──────────────────────────────────────────────────
// Structural copy of _WardLinkQrDialog: same show-QR/scan-QR flow, but the
// payload carries an onion address instead of a LAN ip:port, and pairing
// completes over a Tor dial (OnionTransportService.completePairingFromQr)
// instead of an HTTP POST to a local IP.
class OnionQrDialog extends StatefulWidget {
  const OnionQrDialog();
  @override
  State<OnionQrDialog> createState() => OnionQrDialogState();
}

class OnionQrDialogState extends State<OnionQrDialog> {
  String? _qrJson;
  String? _username;
  String? _error;
  String? _busyMessage;
  bool _showScanner = false;
  bool _handled = false;
  bool _busy = false;
  bool _poppingDialog = false;
  MobileScannerController? _scanCtrl;
  int _initialPeerCount = 0;

  bool get _isMobile =>
      !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _initialPeerCount = OnionPairedPeers.peers.value.length;
    OnionPairedPeers.peers.addListener(_onPeersChanged);
    _prepare();
  }

  @override
  void dispose() {
    OnionPairedPeers.peers.removeListener(_onPeersChanged);
    if (OnionTransportService.instance.onPairingRetry == _onPairingRetry) {
      OnionTransportService.instance.onPairingRetry = null;
    }
    _scanCtrl?.dispose();
    super.dispose();
  }

  // A fresh onion service's descriptor can take up to a couple of minutes
  // to finish publishing across the Tor network -- completePairingFromQr
  // retries the dial with backoff rather than failing immediately, so this
  // just keeps the busy spinner honest about why it's taking a while.
  void _onPairingRetry(int attempt, int maxAttempts) {
    if (!mounted) return;
    setState(() {
      _busyMessage =
          AppLocalizations.of(context).pairRetry(attempt, maxAttempts);
    });
  }

  // Fires when the other side dials us back after scanning our QR.
  void _onPeersChanged() {
    if (!mounted) return;
    if (_handled || _poppingDialog) return;
    if (OnionPairedPeers.peers.value.length > _initialPeerCount) {
      _poppingDialog = true;
      _scanCtrl?.dispose();
      _scanCtrl = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        rootScreenKey.currentState?.showSnack(AppLocalizations.of(context).pairedOverTor);
      });
    }
  }

  Future<void> _prepare() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).notLoggedIn);
      return;
    }
    try {
      if (!OnionTransportService.instance.isRunning) {
        final support = await getOnyxSupportDirectory();
        // Same per-account folder as RootScreen._startOnionMode: another
        // folder would mean another Tor data directory and a different
        // onion address (and key) than the one this account really has.
        final stateDir = p.join(support.path, 'onion_hs_$username');
        setState(() => _busy = true);
        await OnionTransportService.instance.start(username, stateDir);
      }
      final qr = await OnionTransportService.instance.pairingQrJson(username);
      if (mounted) {
        setState(() {
          _username = username;
          _qrJson = qr;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = AppLocalizations.of(context).pairStartFailed('$e');
        _busy = false;
      });
    }
  }

  void _startScan() {
    _scanCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    setState(() {
      _showScanner = true;
      _handled = false;
      _error = null;
    });
  }

  void _stopScan() {
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() => _showScanner = false);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _username == null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.contains('onion_pair')) return;
    _handled = true;
    _scanCtrl?.dispose();
    _scanCtrl = null;
    setState(() {
      _showScanner = false;
      _busy = true;
      _busyMessage = AppLocalizations.of(context).pairing;
    });

    OnionTransportService.instance.onPairingRetry = _onPairingRetry;
    final err = await OnionTransportService.instance
        .completePairingFromQr(raw, _username!);
    OnionTransportService.instance.onPairingRetry = null;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyMessage = null;
    });

    if (err == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        rootScreenKey.currentState?.showSnack(AppLocalizations.of(context).pairedOverTor);
      });
    } else {
      setState(() => _error = AppLocalizations.of(context).pairFailedWith(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_showScanner && _scanCtrl != null) {
      return OnyxDialogShell(
        maxWidth: 340,
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
                child: Icon(Icons.qr_code_scanner_rounded,
                    size: 20, color: cs.primary),
              ),
              title: Text(
                AppLocalizations.of(context).pairScanTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface),
              ),
              onClose: _stopScan,
            ),
            RepaintBoundary(
              child: SizedBox(
                height: 260,
                child: MobileScanner(
                  controller: _scanCtrl!,
                  onDetect: _onDetect,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                AppLocalizations.of(context).pairScanHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: OutlinedButton(
                onPressed: _stopScan,
                style: OutlinedButton.styleFrom(
                  padding: kOnyxDialogButtonPadding,
                  shape: kOnyxDialogButtonShape,
                ),
                child: Text(AppLocalizations.of(context).cancel),
              ),
            ),
          ],
        ),
      );
    }

    Widget body;
    if (_busy) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: CircularProgressIndicator()),
            if (_busyMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _busyMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      );
    } else if (_error != null && _qrJson == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(_error!,
            style: TextStyle(color: cs.error), textAlign: TextAlign.center),
      );
    } else if (_qrJson == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context).pairShowHint,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: RepaintBoundary(
                child: QrImageView(
                  data: _qrJson!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Color(0xFF1A1A1A)),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: cs.primary),
              const SizedBox(width: 5),
              Text(
                AppLocalizations.of(context).pairEncrypted,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: cs.error, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ],
      );
    }

    return OnyxDialogShell(
      maxWidth: 340,
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
              child: Icon(Icons.security_rounded, size: 20, color: cs.primary),
            ),
            title: Text(
              AppLocalizations.of(context).pairOverTor,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface),
            ),
            onClose: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: body,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isMobile && _qrJson != null && !_busy)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: kOnyxDialogButtonPadding,
                      shape: kOnyxDialogButtonShape,
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(AppLocalizations.of(context).pairScanCode),
                    onPressed: _startScan,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Migration blocking dialog ─────────────────────────────────────────────────
//
// [targetPath] == null  →  "reset to defaults" (just clears the bootstrap config)
// [targetPath] != null  →  full migration to the given directory

class _MigrationDialog extends StatefulWidget {
  final String? targetPath;
  const _MigrationDialog({required this.targetPath});

  @override
  State<_MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends State<_MigrationDialog> {
  bool _done = false;
  bool _error = false;
  String _step = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    try {
      if (widget.targetPath == null) {
        _setStep(l.appDataMigrating);
        await OnyxBaseDir.setCustomBase(null);
      } else {
        // Capture old base path before migration so we can rewrite avatar paths.
        final oldBase = (await OnyxBaseDir.supportDir()).path;

        await OnyxBaseDir.migrate(
          widget.targetPath!,
          onStep: (s) => _setStep(s),
        );

        // Rewrite absolute avatarPaths in all favorites_* keys.
        _setStep('Updating avatar paths…');
        await _rewriteFavoriteAvatarPaths(oldBase, widget.targetPath!);

        // Refresh the settings backup so it contains the updated avatar paths.
        final prefs = await SharedPreferences.getInstance();
        await SettingsBackup.save(prefs);
      }
      if (mounted)
        setState(() {
          _done = true;
          _step = l.appDataRestartRequired;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _done = true;
          _error = true;
          _step = '${l.appDataMigrateError}: $e';
        });
    }
  }

  /// Replaces [oldBase] with [newBase] in every avatarPath stored inside
  /// favorites_* and fav_structure_* SharedPreferences keys.
  static Future<void> _rewriteFavoriteAvatarPaths(
      String oldBase, String newBase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldNorm = oldBase.replaceAll('\\', '/');
      final newNorm = newBase.replaceAll('\\', '/');

      for (final key in prefs.getKeys()) {
        if (!key.startsWith('favorites_')) continue;
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
          bool changed = false;
          final updated = list.map((fav) {
            final ap = fav['avatarPath'] as String?;
            if (ap == null) return fav;
            final apNorm = ap.replaceAll('\\', '/');
            if (!apNorm.startsWith(oldNorm)) return fav;
            final newAp = newNorm + apNorm.substring(oldNorm.length);
            // Preserve original path separator style on Windows.
            final finalAp =
                Platform.isWindows ? newAp.replaceAll('/', '\\') : newAp;
            changed = true;
            return {...fav, 'avatarPath': finalAp};
          }).toList();
          if (changed) {
            await prefs.setString(key, jsonEncode(updated));
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _setStep(String s) {
    if (mounted) setState(() => _step = s);
  }

  void _restart() {
    try {
      final exe = Platform.resolvedExecutable;
      Process.start(exe, [], mode: ProcessStartMode.detached);
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l.appDataTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_done) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(l.appDataMigrating,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ] else ...[
              Icon(
                _error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: _error ? cs.error : Colors.green,
                size: 32,
              ),
              const SizedBox(height: 8),
            ],
            if (_step.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_step,
                  style: TextStyle(
                    fontSize: 12,
                    color: _error && _done
                        ? cs.error
                        : cs.onSurface.withValues(alpha: 0.7),
                  )),
            ],
          ],
        ),
        actions: _done
            ? [
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(l.appDataRestart),
                ),
              ]
            : const [],
      ),
    );
  }
}

// ── Video preview for wallpaper settings ─────────────────────────────────────

class _VideoPreviewWidget extends StatefulWidget {
  final String path;
  const _VideoPreviewWidget({required this.path});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.setPlaylistMode(PlaylistMode.single);
    _player.open(Media(widget.path), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(
            controller: _controller,
            fit: BoxFit.cover,
            controls: NoVideoControls),
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text('Video',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Theme Presets Sheet ───────────────────────────────────────────────────────

class _PresetsSheet extends StatefulWidget {
  final AppTheme currentTheme;
  final bool isDarkMode;
  final Future<void> Function(AppTheme, bool) onThemeChanged;
  final void Function(String) onSnack;

  const _PresetsSheet({
    required this.currentTheme,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onSnack,
  });

  @override
  State<_PresetsSheet> createState() => _PresetsSheetState();
}

class _PresetsSheetState extends State<_PresetsSheet> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      widget.onSnack('Enter a preset name');
      return;
    }

    // Copy wallpaper/video to stable preset_wallpapers/ dir so they survive
    // when the user later picks a new background (which deletes chat_bg* files)
    String? stableWallpaper;
    String? stableVideo;
    try {
      final dir = await getOnyxSupportDirectory();
      final wpDir = Directory('${dir.path}/preset_wallpapers');
      await wpDir.create(recursive: true);

      final wallpaperPath = SettingsManager.chatBackground.value;
      if (wallpaperPath != null) {
        final src = File(wallpaperPath);
        if (await src.exists()) {
          final ext = p.extension(wallpaperPath);
          final dest =
              '${wpDir.path}/wp_${DateTime.now().millisecondsSinceEpoch}$ext';
          await src.copy(dest);
          stableWallpaper = dest;
        }
      }

      final videoPath = SettingsManager.chatVideoBackground.value;
      if (videoPath != null) {
        final src = File(videoPath);
        if (await src.exists()) {
          final ext = p.extension(videoPath);
          final dest =
              '${wpDir.path}/vid_${DateTime.now().millisecondsSinceEpoch}$ext';
          await src.copy(dest);
          stableVideo = dest;
        }
      }
    } catch (e) {
      debugPrint('[preset save] $e');
    }

    final preset = <String, dynamic>{
      'name': name,
      'theme': widget.currentTheme.name,
      'isDark': widget.isDarkMode,
      'wallpaper': stableWallpaper,
      'video': stableVideo,
      // UI elements
      'elementOpacity': SettingsManager.elementOpacity.value,
      'elementBrightness': SettingsManager.elementBrightness.value,
      // Liquid glass — navbar
      'lgOnNavBar': SettingsManager.liquidGlassOnNavBar.value,
      'lgNavBarQuality': SettingsManager.liquidGlassNavBarQuality.value.name,
      // Liquid glass — main
      'lgQuality': SettingsManager.liquidGlassQuality.value.name,
      'lgExpansion': SettingsManager.liquidGlassExpansion.value,
      'lgBlur': SettingsManager.liquidGlassBlur.value,
      'lgTint': SettingsManager.liquidGlassTint.value,
      'lgSaturation': SettingsManager.liquidGlassSaturation.value,
      'lgChromatic': SettingsManager.liquidGlassChromatic.value,
      'lgRefractive': SettingsManager.liquidGlassRefractive.value,
      'lgLightIntensity': SettingsManager.liquidGlassLightIntensity.value,
      'lgThickness': SettingsManager.liquidGlassThickness.value,
      'lgJelly': SettingsManager.liquidGlassJellyEnabled.value,
      // Liquid glass — input
      'lgOnInput': SettingsManager.liquidGlassOnInput.value,
      'lgInputQuality': SettingsManager.liquidGlassInputQuality.value.name,
      'lgInputBlur': SettingsManager.liquidGlassInputBlur.value,
      'lgInputTint': SettingsManager.liquidGlassInputTint.value,
      'lgInputSaturation': SettingsManager.liquidGlassInputSaturation.value,
      'lgInputChromatic': SettingsManager.liquidGlassInputChromatic.value,
      'lgInputRefractive': SettingsManager.liquidGlassInputRefractive.value,
      'lgInputLightIntensity':
          SettingsManager.liquidGlassInputLightIntensity.value,
      'lgInputThickness': SettingsManager.liquidGlassInputThickness.value,
      // Liquid glass — search
      'lgOnSearch': SettingsManager.liquidGlassOnSearch.value,
      'lgSearchQuality': SettingsManager.liquidGlassSearchQuality.value.name,
      'lgSearchBlur': SettingsManager.liquidGlassSearchBlur.value,
      'lgSearchTint': SettingsManager.liquidGlassSearchTint.value,
      'lgSearchSaturation': SettingsManager.liquidGlassSearchSaturation.value,
      'lgSearchChromatic': SettingsManager.liquidGlassSearchChromatic.value,
      'lgSearchRefractive': SettingsManager.liquidGlassSearchRefractive.value,
      'lgSearchLightIntensity':
          SettingsManager.liquidGlassSearchLightIntensity.value,
      'lgSearchThickness': SettingsManager.liquidGlassSearchThickness.value,
      // Liquid glass — app bar
      'lgOnAppBar': SettingsManager.liquidGlassOnAppBar.value,
      'lgAppBarQuality': SettingsManager.liquidGlassAppBarQuality.value.name,
      'lgAppBarBlur': SettingsManager.liquidGlassAppBarBlur.value,
      'lgAppBarTint': SettingsManager.liquidGlassAppBarTint.value,
      'lgAppBarSaturation': SettingsManager.liquidGlassAppBarSaturation.value,
      'lgAppBarChromatic': SettingsManager.liquidGlassAppBarChromatic.value,
      'lgAppBarRefractive': SettingsManager.liquidGlassAppBarRefractive.value,
      'lgAppBarLightIntensity':
          SettingsManager.liquidGlassAppBarLightIntensity.value,
      'lgAppBarThickness': SettingsManager.liquidGlassAppBarThickness.value,
    };
    await SettingsManager.saveThemePreset(preset);
    _nameCtrl.clear();
    widget.onSnack('Preset "$name" saved');
  }

  Future<void> _apply(Map<String, dynamic> preset) async {
    try {
      // helpers
      String normalize(String s) =>
          s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      LiquidGlassQuality qualityByName(String? n) =>
          LiquidGlassQuality.values.firstWhere(
            (e) => e.name == (n ?? ''),
            orElse: () => LiquidGlassQuality.quality,
          );
      double d(String key, double fallback) =>
          (preset[key] as num?)?.toDouble() ?? fallback;
      bool b(String key, bool fallback) => (preset[key] as bool?) ?? fallback;

      // Theme
      final themeName = preset['theme'] as String? ?? '';
      final isDark = preset['isDark'] as bool? ?? true;
      final theme = AppTheme.values.firstWhere(
        (t) => normalize(t.name) == normalize(themeName),
        orElse: () => AppTheme.deepPurple,
      );
      await widget.onThemeChanged(theme, isDark);

      // Wallpaper
      await SettingsManager.setChatBackground(preset['wallpaper'] as String?);
      await SettingsManager.setChatVideoBackground(preset['video'] as String?);

      // UI elements
      await SettingsManager.setElementOpacity(d('elementOpacity', 0.5));
      await SettingsManager.setElementBrightness(d('elementBrightness', 0.35));

      // Liquid glass — navbar
      await SettingsManager.setLiquidGlassOnNavBar(b('lgOnNavBar', true));
      await SettingsManager.setLiquidGlassNavBarQuality(
          qualityByName(preset['lgNavBarQuality'] as String?));

      // Liquid glass — main
      await SettingsManager.setLiquidGlassQuality(
          qualityByName(preset['lgQuality'] as String?));
      await SettingsManager.setLiquidGlassExpansion(d('lgExpansion', 14.0));
      await SettingsManager.setLiquidGlassBlur(d('lgBlur', 7.0));
      await SettingsManager.setLiquidGlassTint(d('lgTint', 0.10));
      await SettingsManager.setLiquidGlassSaturation(d('lgSaturation', 1.0));
      await SettingsManager.setLiquidGlassChromatic(d('lgChromatic', 0.30));
      await SettingsManager.setLiquidGlassRefractive(d('lgRefractive', 1.59));
      await SettingsManager.setLiquidGlassLightIntensity(
          d('lgLightIntensity', 0.60));
      await SettingsManager.setLiquidGlassThickness(d('lgThickness', 30.0));
      await SettingsManager.setLiquidGlassJellyEnabled(b('lgJelly', true));

      // Liquid glass — input
      await SettingsManager.setLiquidGlassOnInput(b('lgOnInput', true));
      await SettingsManager.setLiquidGlassInputQuality(
          qualityByName(preset['lgInputQuality'] as String?));
      await SettingsManager.setLiquidGlassInputBlur(d('lgInputBlur', 7.0));
      await SettingsManager.setLiquidGlassInputTint(d('lgInputTint', 0.10));
      await SettingsManager.setLiquidGlassInputSaturation(
          d('lgInputSaturation', 1.0));
      await SettingsManager.setLiquidGlassInputChromatic(
          d('lgInputChromatic', 0.15));
      await SettingsManager.setLiquidGlassInputRefractive(
          d('lgInputRefractive', 1.40));
      await SettingsManager.setLiquidGlassInputLightIntensity(
          d('lgInputLightIntensity', 0.50));
      await SettingsManager.setLiquidGlassInputThickness(
          d('lgInputThickness', 20.0));

      // Liquid glass — search
      await SettingsManager.setLiquidGlassOnSearch(b('lgOnSearch', false));
      await SettingsManager.setLiquidGlassSearchQuality(
          qualityByName(preset['lgSearchQuality'] as String?));
      await SettingsManager.setLiquidGlassSearchBlur(d('lgSearchBlur', 7.0));
      await SettingsManager.setLiquidGlassSearchTint(d('lgSearchTint', 0.10));
      await SettingsManager.setLiquidGlassSearchSaturation(
          d('lgSearchSaturation', 1.0));
      await SettingsManager.setLiquidGlassSearchChromatic(
          d('lgSearchChromatic', 0.15));
      await SettingsManager.setLiquidGlassSearchRefractive(
          d('lgSearchRefractive', 1.40));
      await SettingsManager.setLiquidGlassSearchLightIntensity(
          d('lgSearchLightIntensity', 0.50));
      await SettingsManager.setLiquidGlassSearchThickness(
          d('lgSearchThickness', 24.0));

      // Liquid glass — app bar
      await SettingsManager.setLiquidGlassOnAppBar(b('lgOnAppBar', false));
      await SettingsManager.setLiquidGlassAppBarQuality(
          qualityByName(preset['lgAppBarQuality'] as String?));
      await SettingsManager.setLiquidGlassAppBarBlur(d('lgAppBarBlur', 7.0));
      await SettingsManager.setLiquidGlassAppBarTint(d('lgAppBarTint', 0.10));
      await SettingsManager.setLiquidGlassAppBarSaturation(
          d('lgAppBarSaturation', 1.0));
      await SettingsManager.setLiquidGlassAppBarChromatic(
          d('lgAppBarChromatic', 0.15));
      await SettingsManager.setLiquidGlassAppBarRefractive(
          d('lgAppBarRefractive', 1.40));
      await SettingsManager.setLiquidGlassAppBarLightIntensity(
          d('lgAppBarLightIntensity', 0.50));
      await SettingsManager.setLiquidGlassAppBarThickness(
          d('lgAppBarThickness', 20.0));

      widget.onSnack('Preset "${preset['name']}" applied');
    } catch (e) {
      widget.onSnack('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Theme Presets',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Save and apply combinations of theme, color scheme and wallpaper.',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Preset name…',
                          filled: true,
                          fillColor:
                              cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Current: ${widget.currentTheme.name} • ${widget.isDarkMode ? "Dark" : "Light"}',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45)),
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: SettingsManager.themePresets,
                  builder: (_, presets, __) {
                    if (presets.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.palette_outlined,
                                size: 40,
                                color: cs.onSurface.withValues(alpha: 0.25)),
                            const SizedBox(height: 8),
                            Text(
                              'No presets yet',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurface.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: presets.length,
                      itemBuilder: (_, i) {
                        final p = presets[i];
                        final hasWallpaper =
                            (p['wallpaper'] as String?) != null;
                        final hasVideo = (p['video'] as String?) != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.2)),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 8, 8, 8),
                              leading: () {
                                final wallpaperPath = p['wallpaper'] as String?;
                                final videoPath = p['video'] as String?;
                                final themeName = p['theme'] as String? ?? '';
                                String normalize(String s) => s
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[^a-z0-9]'), '');
                                final themeColor = AppTheme.values
                                    .firstWhere(
                                      (t) =>
                                          normalize(t.name) ==
                                          normalize(themeName),
                                      orElse: () => AppTheme.deepPurple,
                                    )
                                    .color;

                                if (videoPath != null &&
                                    File(videoPath).existsSync()) {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.black87,
                                    child: const Icon(Icons.videocam,
                                        size: 16, color: Colors.white),
                                  );
                                } else if (wallpaperPath != null &&
                                    File(wallpaperPath).existsSync()) {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundImage:
                                        FileImage(File(wallpaperPath)),
                                  );
                                } else {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundColor: themeColor,
                                    child: Icon(
                                      (p['isDark'] as bool? ?? true)
                                          ? Icons.dark_mode
                                          : Icons.light_mode,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  );
                                }
                              }(),
                              title: Text(
                                p['name'] as String? ?? 'Preset',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                [
                                  p['theme'] as String? ?? '',
                                  (p['isDark'] as bool? ?? true)
                                      ? 'Dark'
                                      : 'Light',
                                  if (hasVideo)
                                    'Video wallpaper'
                                  else if (hasWallpaper)
                                    'Image wallpaper',
                                  if (p.containsKey('elementOpacity') ||
                                      p.containsKey('lgOnInput'))
                                    'UI effects',
                                ].join(' • '),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _apply(p),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            cs.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        'Apply',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.primary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 18,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4)),
                                    onPressed: () async {
                                      await SettingsManager.deleteThemePreset(
                                          i);
                                    },
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
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
        );
      },
    );
  }
}

sealed class _LiquidItem {
  const _LiquidItem();
}

class _LiquidSliderConfig extends _LiquidItem {
  const _LiquidSliderConfig({
    required this.label,
    required this.description,
    required this.listenable,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });
  final String label;
  final String description;
  final ValueNotifier<double> listenable;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final Future<void> Function(double) onChanged;
}

/// One glass slider. While the thumb is dragged only this tile repaints; the
/// value is applied (and saved) when the finger lifts. Applying it on every
/// tick re-rendered the glass shaders of the nav bar / input bar / search and
/// wrote to disk up to four times per frame, which made the phone stutter.
class _LiquidSliderTile extends StatefulWidget {
  const _LiquidSliderTile({required this.config});
  final _LiquidSliderConfig config;

  @override
  State<_LiquidSliderTile> createState() => _LiquidSliderTileState();
}

class _LiquidSliderTileState extends State<_LiquidSliderTile> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return ValueListenableBuilder<double>(
      valueListenable: config.listenable,
      builder: (_, stored, __) {
        final value = (_drag ?? stored).clamp(config.min, config.max);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(config.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Text(config.format(value),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 2),
            Text(config.description,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Slider(
              min: config.min,
              max: config.max,
              divisions: config.divisions,
              value: value,
              onChanged: (v) => setState(() => _drag = v),
              onChangeEnd: (v) async {
                await config.onChanged(v);
                if (mounted) setState(() => _drag = null);
              },
            ),
          ],
        );
      },
    );
  }
}

class _LiquidToggleItem extends _LiquidItem {
  const _LiquidToggleItem({
    required this.label,
    required this.description,
    required this.listenable,
    required this.onChanged,
  });
  final String label;
  final String description;
  final ValueNotifier<bool> listenable;
  final Future<void> Function(bool) onChanged;
}

// ── Backup section ────────────────────────────────────────────────────────────

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection>
    with SingleTickerProviderStateMixin {
  BackupOptions _opts = const BackupOptions();
  BackupFrequency _freq = BackupFrequency.monthly;
  DateTime? _lastAuto;
  String _dir = '';
  bool _busy = false;
  double _progress = 0;
  String _label = '';
  BackupCancelToken? _cancelToken;

  // Vertical reveal so the section grows open like the others (the parent's
  // AnimatedSize alone doesn't animate this async-built child cleanly).
  late final AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _load();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final opts = await BackupService.loadOptions();
    final freq = await BackupService.loadFrequency();
    final last = await BackupService.lastAutoBackup();
    final dir = await BackupService.backupDir();
    if (!mounted) return;
    setState(() {
      _opts = opts;
      _freq = freq;
      _lastAuto = last;
      _dir = dir;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    final root = rootScreenKey.currentState;
    if (root != null) {
      root.showSnack(msg);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _updateOpts(BackupOptions o) async {
    setState(() => _opts = o);
    await BackupService.saveOptions(o);
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final root = rootScreenKey.currentState;
    final username = root?.currentUsername;
    if (username == null) {
      _snack(l.backupNoAccount);
      return;
    }
    if (!_opts.favorites && !_opts.personal) {
      _snack(l.backupSelectScope);
      return;
    }
    if (Platform.isAndroid) {
      final granted = await _ensureAndroidStoragePermission();
      if (!granted) {
        _snack(l.backupNoPermission);
        return;
      }
    }
    String? dir;
    if (!Platform.isAndroid) {
      dir = await FilePicker.platform
          .getDirectoryPath(dialogTitle: l.backupExport);
    }
    dir ??= await BackupService.backupDir();
    await Directory(dir).create(recursive: true);
    final ts =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.\-]'), '');
    final dest = p.join(dir, 'onyx_backup_$ts.zip');
    final token = BackupCancelToken();
    setState(() {
      _busy = true;
      _progress = 0;
      _label = l.backupInProgress;
      _cancelToken = token;
    });
    try {
      await BackupService.export(
        username: username,
        chats: root!.chats,
        opts: _opts,
        destPath: dest,
        cancelToken: token,
        onProgress: (pr, label) {
          if (mounted)
            setState(() {
              _progress = pr;
              _label = label;
            });
        },
      );
      _snack('${l.backupExport}: $dest');
    } on BackupCancelledException {
      try {
        await File(dest).delete();
      } catch (_) {}
      _snack(l.cancelled);
    } catch (e) {
      _snack('${l.error}: $e');
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _cancelToken = null;
        });
    }
  }

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    final root = rootScreenKey.currentState;
    final username = root?.currentUsername;
    if (username == null) {
      _snack(l.backupNoAccount);
      return;
    }
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = res?.files.single.path;
    if (path == null) return;

    final manifest = await BackupService.peekManifest(path);
    if (!mounted) return;
    final created = manifest?['createdAt']?.toString();
    final ok = await showOnyxConfirmDialog(
      context: context,
      title: l.backupRestoreConfirmTitle,
      message:
          '${l.backupRestoreConfirmBody}${created != null ? '\n\n($created)' : ''}',
      confirmLabel: l.backupRestore,
      icon: Icons.restore_rounded,
    );
    if (ok != true) return;

    try {
      setState(() {
        _busy = true;
        _progress = 0;
        _label = l.backupRestoring;
      });
      final r = await BackupService.import(
        path,
        username: username,
        onProgress: (pr, label) {
          if (mounted) {
            setState(() {
              _progress = pr;
              _label = label;
            });
          }
        },
      );
      _snack('${l.backupRestore}: ${r.chats} chats, ${r.messages} msgs, '
          '${r.mediaFiles} media. ${l.backupRestartHint}');
    } catch (e) {
      _snack('${l.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeFolder() async {
    final l = AppLocalizations.of(context);
    final raw = await FilePicker.platform.getDirectoryPath();
    if (raw == null) return;
    final resolved = Platform.isAndroid ? _resolveAndroidSafPath(raw) : raw;
    if (resolved == null) {
      _snack(l.backupFolderUnsupported);
      return;
    }
    await BackupService.setBackupDir(resolved);
    await _load();
  }

  /// Converts an Android SAF content URI to a real filesystem path.
  /// Works for primary/internal storage only.
  /// Example: content://com.android.externalstorage.documents/tree/primary%3ADownload%2FMyFolder
  ///       → /storage/emulated/0/Download/MyFolder
  static String? _resolveAndroidSafPath(String raw) {
    if (!raw.startsWith('content://')) return raw;
    try {
      final uri = Uri.parse(raw);
      final segments = uri.pathSegments; // already percent-decoded by Dart
      // Expect ['tree', 'primary:relative/path'] or ['tree', 'primary:']
      if (segments.length >= 2 && segments[0] == 'tree') {
        final treeId = segments[1];
        if (treeId.startsWith('primary:')) {
          final rel = treeId.substring('primary:'.length);
          return rel.isEmpty
              ? '/storage/emulated/0'
              : '/storage/emulated/0/$rel';
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _setFreq(BackupFrequency f) async {
    setState(() => _freq = f);
    await BackupService.saveFrequency(f);
  }

  Future<bool> _ensureAndroidStoragePermission() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    await Permission.manageExternalStorage.request();
    return Permission.manageExternalStorage.isGranted;
  }

  Future<void> _openBackupFolder() async {
    final errorPrefix = AppLocalizations.of(context).error;
    try {
      await Directory(_dir).create(recursive: true);
      if (Platform.isAndroid) {
        const storageRoot = '/storage/emulated/0/';
        if (_dir.startsWith(storageRoot)) {
          final rel = _dir.substring(storageRoot.length);
          final enc = Uri.encodeComponent(rel);
          final uri = Uri.parse(
              'content://com.android.externalstorage.documents/document/primary%3A$enc');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      await launchUrl(Uri.file(_dir), mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack('$errorPrefix: $e');
    }
  }

  BackupOptions _copy({
    bool? favorites,
    bool? personal,
    bool? includeMedia,
    bool? mediaImages,
    bool? mediaVideos,
    bool? mediaVoice,
    bool? mediaOther,
  }) =>
      BackupOptions(
        favorites: favorites ?? _opts.favorites,
        personal: personal ?? _opts.personal,
        includeMedia: includeMedia ?? _opts.includeMedia,
        mediaImages: mediaImages ?? _opts.mediaImages,
        mediaVideos: mediaVideos ?? _opts.mediaVideos,
        mediaVoice: mediaVoice ?? _opts.mediaVoice,
        mediaOther: mediaOther ?? _opts.mediaOther,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    String freqLabel(BackupFrequency f) => switch (f) {
          BackupFrequency.off => l.backupFreqOff,
          BackupFrequency.daily => l.backupFreqDaily,
          BackupFrequency.weekly => l.backupFreqWeekly,
          BackupFrequency.monthly => l.backupFreqMonthly,
        };

    Widget check(String title, bool value, ValueChanged<bool> onChanged,
            {bool dense = false}) =>
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: dense,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(title, style: TextStyle(fontSize: dense ? 13 : 14)),
          value: value,
          onChanged: _busy ? null : (v) => onChanged(v ?? false),
        );

    Widget group(IconData icon, String title, List<Widget> children) =>
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.primary)),
                ],
              ),
              const SizedBox(height: 2),
              ...children,
            ],
          ),
        );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_label,
                          style: TextStyle(fontSize: 12, color: cs.primary)),
                    ),
                    if (_cancelToken != null)
                      GestureDetector(
                        onTap: () => _cancelToken?.cancel(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(Icons.cancel_outlined,
                              size: 18, color: cs.error),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                      minHeight: 6, value: _progress == 0 ? null : _progress),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _export,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(l.backupExport),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : _restore,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: Text(l.backupRestore),
          ),
        ),
        group(Icons.inventory_2_rounded, l.backupScope, [
          check(l.backupFavorites, _opts.favorites,
              (v) => _updateOpts(_copy(favorites: v))),
          check(l.backupPersonal, _opts.personal,
              (v) => _updateOpts(_copy(personal: v))),
          check(l.backupIncludeMedia, _opts.includeMedia,
              (v) => _updateOpts(_copy(includeMedia: v))),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _opts.includeMedia
                ? Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      children: [
                        check(l.backupMediaImages, _opts.mediaImages,
                            (v) => _updateOpts(_copy(mediaImages: v)),
                            dense: true),
                        check(l.backupMediaVideos, _opts.mediaVideos,
                            (v) => _updateOpts(_copy(mediaVideos: v)),
                            dense: true),
                        check(l.backupMediaVoice, _opts.mediaVoice,
                            (v) => _updateOpts(_copy(mediaVoice: v)),
                            dense: true),
                        check(l.backupMediaOther, _opts.mediaOther,
                            (v) => _updateOpts(_copy(mediaOther: v)),
                            dense: true),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
        group(Icons.schedule_rounded, l.backupSchedule, [
          const SizedBox(height: 6),
          DropdownButton<BackupFrequency>(
            value: _freq,
            isExpanded: true,
            onChanged: _busy
                ? null
                : (f) {
                    if (f != null) _setFreq(f);
                  },
            items: BackupFrequency.values
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(freqLabel(f)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Text('${l.backupFolder}:\n$_dir',
              style: TextStyle(
                  fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _backupActionButton(
                icon: Icons.folder_open_rounded,
                label: l.backupOpenFolder,
                onPressed: _busy ? null : _openBackupFolder,
              ),
              _backupActionButton(
                icon: Icons.edit_rounded,
                label: l.backupChangeFolder,
                onPressed: _busy ? null : _changeFolder,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l.backupLastAuto}: ${_lastAuto != null ? _lastAuto!.toLocal().toString().split('.').first : l.backupNever}',
            style: TextStyle(
                fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ]),
      ],
    );

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _reveal, curve: Curves.easeOut),
      axisAlignment: -1.0,
      child: content,
    );
  }

  // Mirrors _SettingsTabState._buildAppleButton so backup actions match the
  // pill-button style used for wallpaper/preset actions elsewhere in Settings.
  Widget _backupActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.onSurface.withValues(alpha: 0.85);
    final bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.55);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trash section ─────────────────────────────────────────────────────────────

class _RecycleBinSection extends StatefulWidget {
  const _RecycleBinSection();

  @override
  State<_RecycleBinSection> createState() => _RecycleBinSectionState();
}

class _RecycleBinSectionState extends State<_RecycleBinSection> {
  bool _busy = false;
  // Accordion — opening one subsection closes whichever other one was open.
  String? _expandedSubsectionKey;

  Widget _buildSubSection({
    required String key,
    required String title,
    required String subtitle,
    required Widget expandedContent,
    IconData? icon,
  }) {
    final isExpanded = _expandedSubsectionKey == key;
    final cs = Theme.of(context).colorScheme;
    return AdaptiveGlassCard(
      borderRadius: 28,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => setState(
                () => _expandedSubsectionKey = isExpanded ? null : key),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 16, color: cs.primary),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: cs.onSurface)),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: cs.onSurface.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              clipBehavior: Clip.hardEdge,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: expandedContent,
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    final root = rootScreenKey.currentState;
    if (root != null) {
      root.showSnack(msg);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _applyPending(PendingBulkDelete req) async {
    setState(() => _busy = true);
    try {
      final taken = await WardLinkPendingDeletions.take(req.peerPub);
      if (taken != null) {
        await WardLinkTombstones.recordFavs(taken.favs);
        rootScreenKey.currentState
            ?.applyRemoteDeletions(taken.favs.keys.toSet(), const {});
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keepPending(PendingBulkDelete req) async {
    setState(() => _busy = true);
    try {
      await WardLinkPendingDeletions.keep(req.peerPub);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetTombstones() async {
    final l = AppLocalizations.of(context);
    final ok = await showOnyxConfirmDialog(
      context: context,
      title: l.recycleBinResetTitle,
      message: l.recycleBinResetConfirm,
      confirmLabel: l.recycleBinResetButton,
      isDestructive: true,
      icon: Icons.restore_from_trash_rounded,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await WardLinkTombstones.clearAll();
      await WardLinkPendingDeletions.clearKept();
      _snack(l.recycleBinResetDone);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearAll(BuildContext ctx) async {
    final totalChats = TrashManager.instance.deletedChats.length;
    final totalMsgs = TrashManager.instance.deletedMessages.length;
    if (totalChats == 0 && totalMsgs == 0) return;
    final confirmed = await showOnyxConfirmDialog(
      context: ctx,
      title: 'Empty Trash?',
      message:
          'Permanently delete $totalChats chat${totalChats == 1 ? '' : 's'} '
          'and $totalMsgs message${totalMsgs == 1 ? '' : 's'}? '
          'This cannot be undone.',
      confirmLabel: 'Empty Trash',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed == true) {
      TrashManager.instance.clearAll();
      _snack('Trash emptied');
    }
  }

  void _restoreChat(TrashedChat chat) {
    rootScreenKey.currentState?.restoreDeletedChat(chat);
    _snack('Chat "${chat.displayName}" restored');
  }

  void _restoreMessage(TrashedMessage item) {
    rootScreenKey.currentState?.restoreDeletedMessage(item);
    _snack('Message restored');
  }

  Future<void> _permanentlyDeleteChat(
      BuildContext ctx, TrashedChat chat) async {
    final confirmed = await showOnyxConfirmDialog(
      context: ctx,
      title: 'Delete permanently?',
      message: 'Remove "${chat.displayName}" from Trash forever?',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed == true) {
      TrashManager.instance.permanentlyDeleteChat(chat.id);
    }
  }

  Future<void> _permanentlyDeleteMessage(
      BuildContext ctx, TrashedMessage item) async {
    final confirmed = await showOnyxConfirmDialog(
      context: ctx,
      title: 'Delete permanently?',
      message: 'Remove this message from Trash forever?',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (confirmed == true) {
      TrashManager.instance.permanentlyDeleteMessage(item.id);
    }
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  Widget _tooManyItems(int count, String kind, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count $kind — too many to display safely. Use "Empty Trash" above to clear all.',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatTypeIcon(TrashedChatType type, ColorScheme cs) {
    final icon = switch (type) {
      TrashedChatType.group => Icons.group,
      TrashedChatType.favorite => Icons.bookmark,
      TrashedChatType.dm => Icons.person,
    };
    return CircleAvatar(
      radius: 16,
      backgroundColor: cs.surfaceContainerHighest,
      child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Empty-trash banner ──────────────────────────────────────────────
        ValueListenableBuilder<int>(
          valueListenable: TrashManager.instance.chatsNotifier,
          builder: (_, __, ___) {
            final totalChats = TrashManager.instance.deletedChats.length;
            final totalMsgs = TrashManager.instance.deletedMessages.length;
            final isEmpty = totalChats == 0 && totalMsgs == 0;
            return AdaptiveGlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          size: 18,
                          color: cs.onSurface
                              .withValues(alpha: isEmpty ? 0.3 : 0.6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isEmpty
                              ? l.trashIsEmpty
                              : l.trashSummary(totalChats, totalMsgs),
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface
                                .withValues(alpha: isEmpty ? 0.35 : 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: isEmpty ? null : () => _clearAll(context),
                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                      label: Text(l.emptyTrash),
                      style: FilledButton.styleFrom(
                        foregroundColor: isEmpty ? null : cs.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'trash_chats',
          title: l.trashChatsTitle,
          subtitle: l.trashChatsSubtitle,
          icon: Icons.chat_bubble_outline_rounded,
          expandedContent: ValueListenableBuilder<int>(
            valueListenable: TrashManager.instance.chatsNotifier,
            builder: (_, __, ___) {
              final chats = TrashManager.instance.deletedChats;
              if (chats.isEmpty) {
                return Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('No deleted chats',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                );
              }
              if (chats.length > 200) {
                return _tooManyItems(chats.length, 'chats', cs);
              }
              return Column(
                children: chats
                    .map((chat) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            children: [
                              _chatTypeIcon(chat.type, cs),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(chat.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                        '${chat.messages.length} msg · ${_ago(chat.deletedAt)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.55))),
                                  ],
                                ),
                              ),
                              if (chat.type != TrashedChatType.group)
                                IconButton(
                                  icon: Icon(Icons.restore_rounded,
                                      size: 20, color: cs.primary),
                                  tooltip: 'Restore',
                                  onPressed: () => _restoreChat(chat),
                                ),
                              IconButton(
                                icon: Icon(Icons.delete_forever_rounded,
                                    size: 20, color: cs.error),
                                tooltip: 'Delete permanently',
                                onPressed: () =>
                                    _permanentlyDeleteChat(context, chat),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'trash_messages',
          title: l.trashMessagesTitle,
          subtitle: l.trashMessagesSubtitle,
          icon: Icons.message_outlined,
          expandedContent: ValueListenableBuilder<int>(
            valueListenable: TrashManager.instance.messagesNotifier,
            builder: (_, __, ___) {
              final messages = TrashManager.instance.deletedMessages;
              if (messages.isEmpty) {
                return Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('No deleted messages',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                );
              }
              if (messages.length > 200) {
                return _tooManyItems(messages.length, 'messages', cs);
              }
              return Column(
                children: messages
                    .map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: cs.surfaceContainerHighest,
                                child: Icon(Icons.message_rounded,
                                    size: 16, color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.chatDisplayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                    Text(item.message.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.7))),
                                    Text(_ago(item.deletedAt),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.45))),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.restore_rounded,
                                    size: 20, color: cs.primary),
                                tooltip: 'Restore',
                                onPressed: () => _restoreMessage(item),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_forever_rounded,
                                    size: 20, color: cs.error),
                                tooltip: 'Delete permanently',
                                onPressed: () =>
                                    _permanentlyDeleteMessage(context, item),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildSubSection(
          key: 'trash_settings',
          title: 'Auto-clean & Sync',
          subtitle:
              'Auto-delete schedule, pending WardLink deletions and tombstone reset',
          icon: Icons.auto_delete_rounded,
          expandedContent: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Auto-clean',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                  'Items in Trash are automatically deleted after the selected period.',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: TrashManager.autoCleanDays,
                builder: (_, days, __) {
                  const options = [
                    (0, 'Never'),
                    (7, '7 days'),
                    (14, '14 days'),
                    (30, '30 days'),
                    (60, '60 days'),
                    (90, '90 days'),
                  ];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: cs.outline.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: DropdownButton<int>(
                      value: days,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: options
                          .map((o) =>
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) TrashManager.setAutoCleanDays(v);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(l.recycleBinPendingTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<PendingBulkDelete>>(
                valueListenable: WardLinkPendingDeletions.pending,
                builder: (_, pending, __) {
                  if (pending.isEmpty) {
                    return Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(l.recycleBinNoPending,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.6)))),
                      ],
                    );
                  }
                  return Column(
                    children: pending
                        .map((req) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    cs.errorContainer.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color: cs.error.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 18, color: cs.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              l.recycleBinPendingDesc(
                                                  req.peerName,
                                                  req.favs.length),
                                              style: const TextStyle(
                                                  fontSize: 13))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _applyPending(req),
                                        child: Text(l.recycleBinApply,
                                            style: TextStyle(color: cs.error)),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonal(
                                        onPressed: _busy
                                            ? null
                                            : () => _keepPending(req),
                                        child: Text(l.recycleBinKeep),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(l.recycleBinResetTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(l.recycleBinResetDesc,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _resetTombstones,
                icon: const Icon(Icons.restore_from_trash_rounded, size: 18),
                label: Text(l.recycleBinResetButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
