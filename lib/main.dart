// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File, Directory, FileMode, exit, RandomAccessFile, FileLock;
import 'dart:math';
import 'dart:typed_data';
import 'package:ONYX/background/background_worker.dart';
import 'package:ONYX/background/notification_service.dart';
import 'package:ONYX/background/register_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'utils/autostart_manager.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:workmanager/workmanager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'widgets/avatar_widget.dart';
import 'screens/root_screen_wrapper.dart';
import 'screens/pin_code_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'managers/settings_manager.dart';
import 'managers/blocklist_manager.dart';
import 'managers/mute_manager.dart';
import 'managers/account_manager.dart';
import 'managers/secure_store.dart';
import 'managers/onyx_tray_manager.dart';
import 'models/app_themes.dart';
import 'widgets/debug_overlay_v2.dart';
import 'widgets/vinyl_player_button.dart';
import 'widgets/voice_channel_bar.dart';
import 'voice/voice_channel_manager.dart';
import 'screens/call_overlay.dart';
import 'utils/fps_booster.dart';
import 'utils/performance_initializer.dart';
import 'utils/performance_config.dart';
import 'utils/proxy_manager.dart';
import 'utils/cert_pinning.dart';
import 'utils/media_cache.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'globals.dart';
import 'utils/global_audio_controller.dart';
import 'package:media_kit/media_kit.dart';

late File _logFile;
final List<String> _logBuffer = [];

RandomAccessFile? _lockFile;

Future<void> _initLogFile() async {
  try {
    late Directory appDir;
    if (Platform.isWindows) {
      appDir = Directory(Platform.environment['APPDATA'] ?? '');
      appDir = Directory('${appDir.path}\\ONYX');
    } else if (Platform.isMacOS) {
      appDir = Directory(
          '${Platform.environment['HOME']}/Library/Application Support/ONYX');
    } else if (Platform.isLinux) {
      appDir = Directory('${Platform.environment['HOME']}/.config/onyx');
    } else {
      final tempDir = await getApplicationDocumentsDirectory();
      appDir = Directory('${tempDir.path}/ONYX');
    }

    await appDir.create(recursive: true);

    final timestamp =
        DateTime.now().toString().replaceAll(':', '-').split('.')[0];
    _logFile = File('${appDir.path}/onyx_log_$timestamp.txt');

    if (!await _logFile.exists()) {
      await _logFile.create();
    }

    if (_logBuffer.isNotEmpty) {
      await _logFile.writeAsString(_logBuffer.join('\n') + '\n');
      _logBuffer.clear();
    }
  } catch (e) {
    debugPrint('[log] Failed to init log file: $e');
  }
}

Future<void> appLog(String message) async {
  debugPrint(message);

  if (!SettingsManager.enableLogging.value) return;

  if (_logFile != null && await _logFile.exists()) {
    try {
      await _logFile.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('[log] Failed to write to log file: $e');
    }
  } else {
    
    _logBuffer.add(message);
  }
}

Future<bool> _checkSingleInstance() async {
  try {
    late Directory lockDir;

    if (Platform.isWindows) {
      final tempDir = Platform.environment['TEMP'] ?? Platform.environment['TMP'] ?? 'C:\\Temp';
      lockDir = Directory(tempDir);
    } else if (Platform.isMacOS) {
      lockDir = Directory('/tmp');
    } else if (Platform.isLinux) {
      lockDir = Directory('/tmp');
    } else {
      return true; 
    }

    final lockFilePath = '${lockDir.path}${Platform.pathSeparator}onyx_app.lock';
    final lockFile = File(lockFilePath);

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        _lockFile = await lockFile.open(mode: FileMode.write);
        await _lockFile!.lock(FileLock.exclusive);

        await _lockFile!.writeString('${Platform.executable}\n');
        appLog('[single-instance] Lock acquired: $lockFilePath (attempt ${attempt + 1})');

        _startSignalWatcher(lockDir.path);

        return true;
      } catch (e) {
        
        appLog('[single-instance] Lock attempt ${attempt + 1} failed: $e');

        if (attempt < 4) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    appLog('[single-instance] Lock file is held by another instance');

    final signalFilePath = '${lockDir.path}${Platform.pathSeparator}onyx_show.signal';
    try {
      await File(signalFilePath).writeAsString('show');
      appLog('[single-instance] Signal sent to existing instance');
    } catch (signalError) {
      appLog('[single-instance] Failed to send signal: $signalError');
    }

    return false;
  } catch (e) {
    appLog('[single-instance] Error checking single instance: $e');
    
    return true;
  }
}

void _startSignalWatcher(String lockDirPath) {
  final signalFilePath = '$lockDirPath${Platform.pathSeparator}onyx_show.signal';

  Timer.periodic(const Duration(milliseconds: 250), (timer) async {
    try {
      final signalFile = File(signalFilePath);
      if (await signalFile.exists()) {
        appLog('[single-instance] Signal received - showing window');

        try {
          await signalFile.delete();
        } catch (e) { debugPrint('[err] $e'); }

        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (e) {
          debugPrint('[single-instance] Failed to show window: $e');
        }
      }
    } catch (e) {
      debugPrint('[err] $e');
    }
  });
}

const String serverBase =
    'https://api-onyx.wardcore.com'; 
const String wsUrl = 'wss://api-onyx.wardcore.com/ws'; 
const String publicIpApi = 'https://api.ipify.org';

enum MediaProvider {
  catbox;

  String get displayName => 'Catbox';
  String get apiUrl => 'https://catbox.moe/user/api.php';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await _initLogFile();

  if (isDesktop) {
    final isFirstInstance = await _checkSingleInstance();
    if (!isFirstInstance) {
      appLog('[single-instance] Another instance is running, exiting...');
      exit(0);
    }
  }

  appLog('');
  appLog('' * 60);
  appLog(' ONYX App Initialization Started');
  appLog('' * 60);
  appLog('Platform: ${Platform.operatingSystem}');
  appLog('Is Desktop: $isDesktop');
  appLog('Is Web: $kIsWeb');
  appLog('' * 60);
  appLog('');

  appLog('[settings] Loading SettingsManager...');
  await SettingsManager.init();
  await BlocklistManager.init();
  await MuteManager.init();

  await MediaCache.instance.init();

  unawaited(MediaCache.instance.clearDisplayCache());

  if (SettingsManager.proxyEnabled.value) {
    ProxyManager.deferToFirstConnect();
    applyCertPinning();
    appLog('[proxy] Proxy deferred — will apply after first WS connect');
  } else {
    ProxyManager.applyFromSettings();
    applyCertPinning();
    appLog('[proxy] Proxy settings applied (enabled=false)');
  }
  try {
    final cur = await AccountManager.getCurrentAccount();
    await SettingsManager.setAccountContext(cur);
    appLog('[settings] SettingsManager loaded (account: ${cur ?? "<none>"})');
  } catch (e) {
    appLog('[settings] SettingsManager loaded (failed to set account context): $e');
  }

  final initFutures = <Future>[];

  final perfOptEnabled = SettingsManager.enablePerformanceOptimizations.value;
  appLog('[performance] Performance optimizations setting: $perfOptEnabled');

  if (perfOptEnabled) {
    initFutures.add(PerformanceInitializer.initialize());
  }
  initFutures.add(_optimizePerformance());

  if (isDesktop) {
    initFutures.add(_initWindowManager());
    initFutures.add(_initTrayAndSingleInstance());
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    initFutures.add(
      Workmanager()
          .initialize(callbackDispatcher)
          .then((_) => appLog('[background] Workmanager initialized')),
    );

    // Initialise the foreground-task plugin so it's ready when the app is
    // backgrounded.  The actual service is started/stopped in root_screen.dart.
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'onyx_connection',
        channelName: 'Onyx',
        channelDescription: 'Keeps Onyx connected to receive messages',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    appLog('[background] FlutterForegroundTask initialized');
  } else {
    appLog('[background] Workmanager skipped on this platform');
  }

  initFutures.add(
    NotificationService.init()
        .then((_) => appLog('[services] NotificationService initialized')),
  );

  await Future.wait(initFutures, eagerError: false);

  _initMediaNotificationListener();

  setupDebugPrintCapture();
  appLog('[debug] Debug print capture ready');

  appLog('');
  appLog('' * 60);
  appLog(' ONYX App Initialization Complete');
  appLog('' * 60);
  appLog('');

  runApp(const MyApp());
}

void _initMediaNotificationListener() {
  String? lastTrack;
  bool? lastPlaying;
  bool lastActive = false;

  globalAudioController.addListener(() {
    final ctrl = globalAudioController;
    if (ctrl.isActive == lastActive &&
        ctrl.isPlaying == lastPlaying &&
        ctrl.trackName == lastTrack) {
      return;
    }
    lastActive = ctrl.isActive;
    lastPlaying = ctrl.isPlaying;
    lastTrack = ctrl.trackName;

    if (!ctrl.isActive) {
      NotificationService.cancelMediaNotification();
    } else {
      NotificationService.showMediaNotification(
        trackName: ctrl.trackName ?? 'Audio',
        isPlaying: ctrl.isPlaying,
      );
    }
  });
}

Future<void> _optimizePerformance() async {
  appLog(
      '[performance] Starting additional performance optimizations...');

  if (Platform.isAndroid || Platform.isWindows) {
    
    imageCache.maximumSize = 200;
    imageCache.maximumSizeBytes = 150 * 1024 * 1024;
    appLog('[performance] Image cache optimized: 150MB, 200 items');
  }

  try {
    if (Platform.isAndroid || Platform.isWindows) {
      const platform = MethodChannel('com.wardcore.onyx/performance');
      try {
        final res =
            await platform.invokeMethod<bool>('enableHighPerformanceMode');
        appLog('[performance] High performance mode: $res');

        if (Platform.isWindows) {
          try {
            final vsyncDisabled = await platform.invokeMethod<bool>('disableVSync');
            appLog('[performance]  VSync disabled via DWM API: $vsyncDisabled');
          } catch (e) {
            appLog('[performance] Failed to disable VSync via DWM: $e');
          }
        }
      } catch (e) {
        appLog('[performance] High performance mode not available: $e');
      }
    }
  } catch (e) {
    appLog('[performance] Performance optimization error: $e');
  }

  appLog('[performance]  Performance optimizations applied');
}

Future<void> _initWindowManager() async {
  appLog('[desktop] Initializing window manager...');
  await windowManager.ensureInitialized();
  appLog('[desktop] Window manager initialized');

  unawaited(windowManager.waitUntilReadyToShow(
    const WindowOptions(skipTaskbar: false),
    () async {
      appLog('[desktop] Setting title bar style...');
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setResizable(true);
      await windowManager.show();
      appLog('[desktop] Window manager ready and visible');
    },
  ));
}

Future<void> _initTrayAndSingleInstance() async {
  appLog('[desktop] Initializing system tray and single instance...');

  if (Platform.isWindows) {
    try {
      if (SettingsManager.launchAtStartup.value) {
        await AutostartManager.enable();
      } else {
        await AutostartManager.disable();
      }
      appLog('[desktop] Launch at startup configured (enabled=${SettingsManager.launchAtStartup.value})');
    } catch (e) {
      appLog('[desktop] Failed to configure launch at startup: $e');
    }
  } else {
    appLog('[desktop] Launch at startup skipped (Windows only)');
  }

  appLog('[desktop] System tray and single instance initialized');
}

class _BouncingScrollBehavior extends MaterialScrollBehavior {
  const _BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const ElegantMessenger();
}

class ElegantMessenger extends StatefulWidget {
  const ElegantMessenger({Key? key}) : super(key: key);

  @override
  State<ElegantMessenger> createState() => _ElegantMessengerState();
}

class _ElegantMessengerState extends State<ElegantMessenger> with WindowListener {
  AppTheme _currentTheme = AppTheme.deepPurple;
  bool _isDarkMode = true;
  final OnyxTrayManager _trayManager = OnyxTrayManager();

  // Merges all theme-affecting notifiers so one ListenableBuilder handles them all.
  late final _themeListenable = Listenable.merge([
    SettingsManager.elementOpacity,
    SettingsManager.elementBrightness,
    SettingsManager.fontSizeMultiplier,
    SettingsManager.fontFamily,
    SettingsManager.appLocale,
  ]);

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
    if (isDesktop) {
      _initDesktopFeatures();
    }
    // Pre-warm just_audio / ExoPlayer so first voice/music play is instant.
    // Delayed 6 s so it doesn't compete with chat loading on app start.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(seconds: 6));
        _preWarmAudio();
      });
    }
  }

  // Creates a throwaway AudioPlayer and prepares a bundled asset to force
  // ExoPlayer's codec pipeline to initialise in the background. After this
  // runs, the first real play() call is fast.
  static Future<void> _preWarmAudio() async {
    try {
      final p = ja.AudioPlayer();
      await p.setAudioSource(ja.AudioSource.asset('assets/notification0.wav'));
      await p.dispose();
    } catch (_) {}
  }

  Future<void> _initDesktopFeatures() async {
    
    await windowManager.waitUntilReadyToShow();

    windowManager.addListener(this);

    await windowManager.setPreventClose(true);

    await _trayManager.initialize(
      onConnect: _handleConnect,
      onDisconnect: _handleDisconnect,
      onBeforeClose: _handleBeforeClose,
      onShowWindow: _handleShowWindow,
    );

    debugPrint('[Desktop] All desktop features initialized');
  }

  void _handleConnect() async {
    debugPrint('[Tray]  Connect requested from tray menu ');
    final rootState = rootScreenKey.currentState;

    if (rootState != null) {
      debugPrint('[Tray] RootScreen is available, calling connectWs()');
      rootState.connectWs();

      debugPrint('[Tray] Updating tray menu after connect');
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('[Tray] Connect completed');
    } else {
      debugPrint('[Tray]  Connect FAILED - RootScreen not ready (currentState is null)');
    }
  }

  void _handleDisconnect() async {
    debugPrint('[Tray]  Disconnect requested from tray menu ');
    final rootState = rootScreenKey.currentState;

    if (rootState != null) {
      debugPrint('[Tray] RootScreen is available, calling disconnectWs()');
      rootState.disconnectWs();

      debugPrint('[Tray] Updating tray menu after disconnect');
      await _trayManager.updateMenuAfterDisconnect();
      debugPrint('[Tray] Disconnect completed');
    } else {
      debugPrint('[Tray]  Disconnect FAILED - RootScreen not ready (currentState is null)');
    }
  }

  Future<void> _handleBeforeClose() async {
    debugPrint('[Tray]  Before close - sending offline status ');
    final rootState = rootScreenKey.currentState;

    if (rootState != null) {
      debugPrint('[Tray] RootScreen is available, calling disconnectWs() before close');
      await rootState.disconnectWs();
      debugPrint('[Tray] Offline status sent before close');
    } else {
      debugPrint('[Tray]  Before close FAILED - RootScreen not ready (currentState is null)');
    }
  }

  void _handleShowWindow() {
    debugPrint('[Tray]  Window shown - sending online status ');
    final rootState = rootScreenKey.currentState;

    if (rootState != null) {
      debugPrint('[Tray] RootScreen is available, calling sendOnlineStatus()');
      rootState.sendOnlineStatus();
      debugPrint('[Tray] Online status sent after showing window');
    } else {
      debugPrint('[Tray]  Show window FAILED - RootScreen not ready (currentState is null)');
    }
  }

  @override
  void dispose() {
    if (isDesktop) {
      windowManager.removeListener(this);
      _trayManager.dispose();
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    
    debugPrint('[Window] Close requested - hiding to tray');
    await _trayManager.hideToTray();
  }

  @override
  void onWindowFocus() {
    debugPrint('[Window] Window focused');
    _handleShowWindow();
  }

  @override
  void onWindowBlur() {
    debugPrint('[Window] Window blurred');
  }

  @override
  void onWindowMaximize() {
    debugPrint('[Window] Window maximized');
  }

  @override
  void onWindowUnmaximize() {
    debugPrint('[Window] Window unmaximized');
  }

  @override
  void onWindowMinimize() {
    debugPrint('[Window] Window minimized');
  }

  @override
  void onWindowRestore() {
    debugPrint('[Window] Window restored');
    _handleShowWindow();
  }

  @override
  void onWindowResize() {
    
  }

  @override
  void onWindowMove() {
    
  }

  @override
  void onWindowEnterFullScreen() {
    debugPrint('[Window] Entered fullscreen');
  }

  @override
  void onWindowLeaveFullScreen() {
    debugPrint('[Window] Left fullscreen');
  }

  @override
  void onWindowEvent(String eventName) {
    debugPrint('[Window] Event: $eventName');
  }

  Future<void> _loadThemePreferences() async {
    String? themeName;
    String? isDark;
    try {
      themeName = await SecureStore.read('app_theme_name');
      isDark = await SecureStore.read('app_theme_is_dark');
    } catch (e) {
      debugPrint('[main] Theme read failed: $e');
    }

    AppTheme theme = AppTheme.deepPurple;
    if (themeName != null) {
      try {
        String normalize(String s) =>
            s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final normalizedThemeName = normalize(themeName);
        theme = AppTheme.values.firstWhere(
          (t) =>
              normalize(t.name) == normalizedThemeName ||
              normalize(t.toString().split('.').last) == normalizedThemeName,
          orElse: () => AppTheme.deepPurple,
        );
      } catch (e) {
        theme = AppTheme.deepPurple;
      }
    }

    setState(() {
      _currentTheme = theme;
      
      _isDarkMode = isDark == null ? true : isDark == 'true';
    });
  }

  Future<void> _setTheme(AppTheme theme, bool isDark) async {
    try {
      await SecureStore.write('app_theme_name', theme.name);
      await SecureStore.write('app_theme_is_dark', isDark.toString());
    } catch (e) {
      debugPrint('[main] Theme write failed: $e');
    }
    setState(() {
      _currentTheme = theme;
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return ListenableBuilder(
      listenable: _themeListenable,
      builder: (_, __) {
        final elementOpacity = SettingsManager.elementOpacity.value;
        final elementBrightness = SettingsManager.elementBrightness.value;
        final fontSizeMultiplier = SettingsManager.fontSizeMultiplier.value;
        final fontFamily = SettingsManager.fontFamily.value;
        final appLocale = SettingsManager.appLocale.value;
        return MaterialApp(
          navigatorKey: navigatorKey,
          scrollBehavior: const _BouncingScrollBehavior(),
          title: 'ONYX Messenger',
          locale: appLocale,
          supportedLocales: const [Locale('en'), Locale('ru')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _currentTheme.getThemeData(
            isDark: false,
            fontFamily: fontFamily,
            fontSizeMultiplier: fontSizeMultiplier,
            elementOpacity: elementOpacity,
            elementBrightness: elementBrightness,
          ),
          darkTheme: _currentTheme.getThemeData(
            isDark: true,
            fontFamily: fontFamily,
            fontSizeMultiplier: fontSizeMultiplier,
            elementOpacity: elementOpacity,
            elementBrightness: elementBrightness,
          ),
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (ctx, child) {
            return DebugOverlayV2(
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const CallOverlay(),
                  const VinylPlayerButton(),
                  const _GlobalVoiceBar(),
                ],
              ),
            );
          },
          navigatorObservers: [routeObserver],
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    return _PinGateWidget(
      currentTheme: _currentTheme,
      isDarkMode: _isDarkMode,
      onThemeChanged: _setTheme,
    );
  }

}

class _PinGateWidget extends StatefulWidget {
  final AppTheme currentTheme;
  final bool isDarkMode;
  final Future<void> Function(AppTheme, bool) onThemeChanged;

  const _PinGateWidget({
    required this.currentTheme,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<_PinGateWidget> createState() => _PinGateWidgetState();
}

class _PinGateWidgetState extends State<_PinGateWidget> {
  late bool _unlocked;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _unlocked = !SettingsManager.pinEnabled.value;
    if (!_unlocked && SettingsManager.biometricEnabled.value) {
      
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return;
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Unlock ONYX',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (didAuth && mounted) setState(() => _unlocked = true);
    } catch (e) {
      debugPrint('[biometric] auth error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return PinCodeScreen.verify(
        onSuccess: () => setState(() => _unlocked = true),
        onBiometric: SettingsManager.biometricEnabled.value ? _tryBiometric : null,
      );
    }
    return RootScreenWrapper(
      currentTheme: widget.currentTheme,
      isDarkMode: widget.isDarkMode,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}

// ── Global draggable voice bar – renders above ALL routes ─────────────────────

class _GlobalVoiceBar extends StatefulWidget {
  const _GlobalVoiceBar();

  @override
  State<_GlobalVoiceBar> createState() => _GlobalVoiceBarState();
}

class _GlobalVoiceBarState extends State<_GlobalVoiceBar> {
  double? _left;
  double? _bottom;
  bool _initialised = false;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDesktop = mq.size.width > 700;

    if (!_initialised) {
      _left = 12;
      _bottom = isDesktop ? 12 : 96;
      _initialised = true;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: VoiceChannelManager.instance.isInChannel,
      builder: (_, inChannel, __) {
        if (!inChannel) return const SizedBox.shrink();

        return Positioned(
          left: _left,
          bottom: _bottom,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _left = (_left! + details.delta.dx)
                    .clamp(0.0, mq.size.width - 260);
                _bottom = (_bottom! - details.delta.dy)
                    .clamp(0.0, mq.size.height - 80);
              });
            },
            child: const SizedBox(
              width: 280,
              child: VoiceChannelBar(),
            ),
          ),
        );
      },
    );
  }
}