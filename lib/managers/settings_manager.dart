// lib/managers/settings_manager.dart
import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/font_family.dart';
import '../enums/nav_bar_style.dart';
import '../enums/scroll_down_button_position.dart';
import '../enums/liquid_glass_quality.dart';
import '../enums/media_preload_mode.dart';
import '../utils/settings_backup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'secure_store.dart';
import 'fallback_storage.dart';

class SettingsManager {

  static const _chatBgKey = 'chat_background_path';
  static const _chatVideoBgKey = 'chat_video_background_path';
  static const _presetsKey = 'theme_presets_v1';
  static const _applyGlobKey = 'chat_background_apply_global';
  static const _blurKey = 'chat_background_blur';
  static const _blurSigmaKey = 'chat_background_blur_sigma';
  static const _debugModeKey = 'debug_mode_enabled';
  static const _showFpsKey = 'show_fps_overlay';
  static const _elementOpacityKey = 'element_opacity';
  static const _elementBrightnessKey = 'element_brightness';
  static const _inputBarMaxWidthKey = 'input_bar_max_width';
  static const _swapMessageAlignmentKey = 'swap_message_alignment';
  static const _alignAllMessagesRightKey = 'align_all_messages_right';
  static const _showAvatarInChatsKey = 'show_avatar_in_chats';
  static const _graphHandlePositionKey = 'graph_handle_position_fraction';
  static const _showAccountIndicatorKey = 'show_account_indicator';
  static const _smoothScrollKey = 'smooth_scroll_enabled';
  static const _messageAnimationsKey = 'message_animations_enabled';
  static const _autoLoadVideoKey = 'auto_load_video_enabled';
  static const _mediaPreloadModeKey = 'media_preload_mode';
  static const _chatListMoveAnimationsKey = 'chat_list_move_animations_enabled';
  static const _enablePerformanceOptimizationsKey =
      'enable_performance_optimizations';
  static const _navBarStyleKey = 'nav_bar_style';
  static const _scrollDownButtonPositionKey = 'scroll_down_button_position';
  static const _scrollDownButtonSizeKey = 'scroll_down_button_size';
  static const _liquidGlassQualityKey    = 'liquid_glass_quality';
  static const _liquidGlassExpansionKey  = 'liquid_glass_expansion';
  static const _liquidGlassBlurKey       = 'liquid_glass_blur';
  static const _liquidGlassTintKey       = 'liquid_glass_tint';
  static const _liquidGlassSaturationKey = 'liquid_glass_saturation';
  static const _liquidGlassOnCardsKey        = 'liquid_glass_on_cards';
  static const _liquidGlassCardsBlurKey      = 'liquid_glass_cards_blur';
  static const _liquidGlassCardsTintKey      = 'liquid_glass_cards_tint';
  static const _liquidGlassCardsSaturationKey= 'liquid_glass_cards_saturation';
  static const _liquidGlassJellyEnabledKey     = 'liquid_glass_jelly_enabled';
  static const _liquidGlassOnInputKey          = 'liquid_glass_on_input';
  static const _liquidGlassInputBlurKey        = 'liquid_glass_input_blur';
  static const _liquidGlassInputTintKey        = 'liquid_glass_input_tint';
  static const _liquidGlassInputSaturationKey  = 'liquid_glass_input_saturation';
  static const _liquidGlassOnSearchKey         = 'liquid_glass_on_search';
  static const _liquidGlassSearchBlurKey       = 'liquid_glass_search_blur';
  static const _liquidGlassSearchTintKey       = 'liquid_glass_search_tint';
  static const _liquidGlassSearchSaturationKey = 'liquid_glass_search_saturation';
  // Advanced per-element settings
  static const _liquidGlassChromaticKey        = 'liquid_glass_chromatic';
  static const _liquidGlassRefractiveKey       = 'liquid_glass_refractive';
  static const _liquidGlassLightIntensityKey   = 'liquid_glass_light_intensity';
  static const _liquidGlassThicknessKey        = 'liquid_glass_thickness';
  static const _liquidGlassCardsChromaticKey        = 'liquid_glass_cards_chromatic';
  static const _liquidGlassCardsRefractiveKey       = 'liquid_glass_cards_refractive';
  static const _liquidGlassCardsLightIntensityKey   = 'liquid_glass_cards_light_intensity';
  static const _liquidGlassCardsThicknessKey        = 'liquid_glass_cards_thickness';
  static const _liquidGlassInputChromaticKey        = 'liquid_glass_input_chromatic';
  static const _liquidGlassInputRefractiveKey       = 'liquid_glass_input_refractive';
  static const _liquidGlassInputLightIntensityKey   = 'liquid_glass_input_light_intensity';
  static const _liquidGlassInputThicknessKey        = 'liquid_glass_input_thickness';
  static const _liquidGlassSearchChromaticKey       = 'liquid_glass_search_chromatic';
  static const _liquidGlassSearchRefractiveKey      = 'liquid_glass_search_refractive';
  static const _liquidGlassSearchLightIntensityKey  = 'liquid_glass_search_light_intensity';
  static const _liquidGlassSearchThicknessKey       = 'liquid_glass_search_thickness';
  static const _liquidGlassOnNavBarKey      = 'liquid_glass_on_navbar';
  static const _liquidGlassNavBarQualityKey = 'liquid_glass_navbar_quality';
  static const _liquidGlassCardsQualityKey  = 'liquid_glass_cards_quality';
  static const _liquidGlassInputQualityKey  = 'liquid_glass_input_quality';
  static const _liquidGlassSearchQualityKey = 'liquid_glass_search_quality';
  static const _messagePaginationKey = 'message_pagination_enabled';
  static const _minimizeBottomNavKey = 'minimize_bottom_nav';
  static const _swipeTabsKey = 'swipe_tabs_enabled';
  static const _fontFamilyKey = 'font_family_type';
  static const _fontSizeKey = 'font_size_multiplier';
  static const _confirmFileUploadKey = 'confirm_file_upload';
  static const _confirmVoiceUploadKey = 'confirm_voice_upload';
  static const _statusVisibilityKey = 'status_visibility';
  static const _statusOnlineKey = 'status_online';
  static const _statusOfflineKey = 'status_offline';
  static const _hideFromSearchKey = 'hide_from_search';
  static const _desktopNavPositionKey = 'desktop_nav_position';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _notificationPositionKey = 'notification_position';
  static const _notifSoundEnabledKey = 'notif_sound_enabled';
  static const _notifSoundKey = 'notif_sound';
  static const _notifHideContentKey = 'notif_hide_content';
  static const _proxyEnabledKey = 'proxy_enabled';
  static const _proxyTypeKey = 'proxy_type';
  static const _proxyHostKey = 'proxy_host';
  static const _proxyPortKey = 'proxy_port';
  static const _proxyUsernameKey = 'proxy_username';
  static const _proxyPasswordKey = 'proxy_password';
  static const _enableLoggingKey = 'enable_logging';
  static const _showDisplayNameInGroupsKey = 'show_display_name_in_groups';
  static const _pinEnabledKey = 'pin_lock_enabled';
  static const _pinCodeSecureKey = 'pin_lock_code';
  static const _biometricEnabledKey = 'biometric_lock_enabled';
  static const _lockOnResumeKey = 'lock_on_resume';
  // PIN stashed in the OS keychain so biometrics can unlock the v3 (PIN-derived)
  // store on desktop. Kept in flutter_secure_storage directly — NOT in SecureStore,
  // which on desktop lives inside the very file we need the PIN to decrypt.
  //
  // macOS only: useDataProtectionKeyChain:false routes to the legacy login
  // keychain, which works for unsigned/dev builds (the data-protection keychain
  // needs the keychain-access-groups entitlement → otherwise errSecMissingEntitlement
  // / -34018). This mOptions is ignored on iOS/Android, so their behaviour is
  // unchanged.
  static const _biometricPinKey = 'biometric_unlock_pin';
  static const FlutterSecureStorage _bioKeychain = FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );
  static const _appLocaleKey = 'app_locale';
  static const _launchAtStartupKey = 'launch_at_startup';
  static const _audioInputDeviceKey = 'audio_input_device_id';
  static const _audioOutputDeviceKey = 'audio_output_device_id';
  static const _showAccountGraphKey       = 'show_account_graph';
  static const _graphOrbitSpeedKey        = 'graph_orbit_speed';
  static const _graphAnimationKey         = 'graph_animation_enabled';
  static const _graphPreservePositionKey  = 'graph_preserve_position';
  // WardLink — passive local-network sync of Favorites between trusted devices.
  static const _wardLinkEnabledKey          = 'wardlink_enabled';
  static const _wardLinkMaxFileSizeMbKey    = 'wardlink_max_file_size_mb';
  static const _wardLinkBubbleOnlyErrorsKey = 'wardlink_bubble_only_errors';
  static const _wardLinkBubbleSizeKey       = 'wardlink_bubble_size';
  // Download folder — custom save directory for received files (null = Downloads/ONYX).
  static const _downloadFolderPathKey     = 'download_folder_path';
  // Chat viewport render buffer beyond the visible area (px). Higher = smoother
  // scroll at the cost of memory and GPU fill. Default: 1500.
  static const _chatCacheExtentKey        = 'chat_cache_extent';
  // Max messages scanned for image preloading on chat open. Default: 60.
  static const _imagePreloadWindowKey     = 'image_preload_window';
  static const _snackbarEnabledKey        = 'snackbar_enabled';

  static String? _accountContext;
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static final ValueNotifier<String?> chatBackground =
      ValueNotifier<String?>(null);
  static final ValueNotifier<String?> chatVideoBackground =
      ValueNotifier<String?>(null);
  static final ValueNotifier<List<Map<String, dynamic>>> themePresets =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  static final ValueNotifier<bool> applyGlobally = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> blurBackground = ValueNotifier<bool>(false);
  static final ValueNotifier<double> blurSigma = ValueNotifier<double>(8.0);
  static final ValueNotifier<double> elementOpacity =
      ValueNotifier<double>(0.5);
  static final ValueNotifier<double> elementBrightness =
      ValueNotifier<double>(0.35);
  static final ValueNotifier<double> inputBarMaxWidth =
      ValueNotifier<double>(760.0);
  // Fraction (0..1) of screen height where the account-graph drag handle
  // sits. Defaults near the bottom of the screen.
  static final ValueNotifier<double> graphHandlePositionFraction =
      ValueNotifier<double>(0.85);

  static final ValueNotifier<bool> debugMode = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> showFpsOverlay = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> enableLogging = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> showDisplayNameInGroups =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> pinEnabled = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> biometricEnabled = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> biometricDeviceSupported = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> lockOnResume = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> swapMessageAlignment =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> alignAllMessagesRight =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> showAvatarInChats =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> showAccountIndicator =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> smoothScrollEnabled =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> messageAnimationsEnabled =
      ValueNotifier<bool>(true);

  /// When false (default), videos in chat are NOT downloaded/prepared
  /// automatically — they show a tap-to-load placeholder. Preparing video
  /// (download + decrypt + spin up a player) is expensive and janks scrolling,
  /// so it's opt-in.
  static final ValueNotifier<bool> autoLoadVideoEnabled =
      ValueNotifier<bool>(false);

  /// Controls proactive background warming (download+decrypt) of chat media
  /// around the open viewport so images are ready before you scroll to them.
  /// Default: warm only on Wi-Fi/ethernet to protect mobile data.
  static final ValueNotifier<MediaPreloadMode> mediaPreloadMode =
      ValueNotifier<MediaPreloadMode>(MediaPreloadMode.wifiOnly);

  static final ValueNotifier<bool> chatListMoveAnimationsEnabled =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> enablePerformanceOptimizations =
      ValueNotifier<bool>(true);

  static final ValueNotifier<NavBarStyle> navBarStyle = ValueNotifier<NavBarStyle>(NavBarStyle.standard);
  static final ValueNotifier<ScrollDownButtonPosition> scrollDownButtonPosition =
      ValueNotifier<ScrollDownButtonPosition>(ScrollDownButtonPosition.center);
  static final ValueNotifier<double> scrollDownButtonSize = ValueNotifier<double>(32.0);
  static final ValueNotifier<LiquidGlassQuality> liquidGlassQuality  = ValueNotifier<LiquidGlassQuality>(LiquidGlassQuality.quality);
  static final ValueNotifier<double> liquidGlassExpansion  = ValueNotifier<double>(14.0);
  static final ValueNotifier<double> liquidGlassBlur        = ValueNotifier<double>(7.0);
  static final ValueNotifier<double> liquidGlassTint        = ValueNotifier<double>(0.10);
  static final ValueNotifier<double> liquidGlassSaturation  = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool>   liquidGlassOnCards        = ValueNotifier<bool>(false);
  static final ValueNotifier<double> liquidGlassCardsBlur       = ValueNotifier<double>(7.0);
  static final ValueNotifier<double> liquidGlassCardsTint        = ValueNotifier<double>(0.10);
  static final ValueNotifier<double> liquidGlassCardsSaturation  = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool>   liquidGlassJellyEnabled      = ValueNotifier<bool>(true);
  static final ValueNotifier<bool>   liquidGlassOnInput           = ValueNotifier<bool>(true);
  static final ValueNotifier<double> liquidGlassInputBlur         = ValueNotifier<double>(7.0);
  static final ValueNotifier<double> liquidGlassInputTint         = ValueNotifier<double>(0.10);
  static final ValueNotifier<double> liquidGlassInputSaturation   = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool>   liquidGlassOnSearch          = ValueNotifier<bool>(false);
  static final ValueNotifier<double> liquidGlassSearchBlur        = ValueNotifier<double>(7.0);
  static final ValueNotifier<double> liquidGlassSearchTint        = ValueNotifier<double>(0.10);
  static final ValueNotifier<double> liquidGlassSearchSaturation  = ValueNotifier<double>(1.0);
  // Advanced per-element: Nav Bar
  static final ValueNotifier<double> liquidGlassChromatic       = ValueNotifier<double>(0.30);
  static final ValueNotifier<double> liquidGlassRefractive      = ValueNotifier<double>(1.59);
  static final ValueNotifier<double> liquidGlassLightIntensity  = ValueNotifier<double>(0.60);
  static final ValueNotifier<double> liquidGlassThickness       = ValueNotifier<double>(30.0);
  // Advanced per-element: Cards
  static final ValueNotifier<double> liquidGlassCardsChromatic       = ValueNotifier<double>(0.15);
  static final ValueNotifier<double> liquidGlassCardsRefractive      = ValueNotifier<double>(1.40);
  static final ValueNotifier<double> liquidGlassCardsLightIntensity  = ValueNotifier<double>(0.50);
  static final ValueNotifier<double> liquidGlassCardsThickness       = ValueNotifier<double>(20.0);
  // Advanced per-element: Input
  static final ValueNotifier<double> liquidGlassInputChromatic       = ValueNotifier<double>(0.15);
  static final ValueNotifier<double> liquidGlassInputRefractive      = ValueNotifier<double>(1.40);
  static final ValueNotifier<double> liquidGlassInputLightIntensity  = ValueNotifier<double>(0.50);
  static final ValueNotifier<double> liquidGlassInputThickness       = ValueNotifier<double>(20.0);
  // Advanced per-element: Search
  static final ValueNotifier<double> liquidGlassSearchChromatic       = ValueNotifier<double>(0.15);
  static final ValueNotifier<double> liquidGlassSearchRefractive      = ValueNotifier<double>(1.40);
  static final ValueNotifier<double> liquidGlassSearchLightIntensity  = ValueNotifier<double>(0.50);
  static final ValueNotifier<double> liquidGlassSearchThickness       = ValueNotifier<double>(24.0);
  // Per-element on/off and quality
  static final ValueNotifier<bool>               liquidGlassOnNavBar       = ValueNotifier<bool>(true);
  static final ValueNotifier<LiquidGlassQuality> liquidGlassNavBarQuality  = ValueNotifier<LiquidGlassQuality>(LiquidGlassQuality.quality);
  static final ValueNotifier<LiquidGlassQuality> liquidGlassCardsQuality   = ValueNotifier<LiquidGlassQuality>(LiquidGlassQuality.quality);
  static final ValueNotifier<LiquidGlassQuality> liquidGlassInputQuality   = ValueNotifier<LiquidGlassQuality>(LiquidGlassQuality.quality);
  static final ValueNotifier<LiquidGlassQuality> liquidGlassSearchQuality  = ValueNotifier<LiquidGlassQuality>(LiquidGlassQuality.quality);
  static final ValueNotifier<bool> messagePaginationEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> snackbarEnabled = ValueNotifier<bool>(true);

  static final ValueNotifier<bool> minimizeBottomNav =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> swipeTabsEnabled =
      ValueNotifier<bool>(true);

  static final ValueNotifier<FontFamilyType> fontFamily =
      ValueNotifier<FontFamilyType>(FontFamilyType.systemFont);

  static final ValueNotifier<double> fontSizeMultiplier =
      ValueNotifier<double>(1.0);

  static final ValueNotifier<bool> confirmFileUpload =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> confirmVoiceUpload =
      ValueNotifier<bool>(true);

  static final ValueNotifier<String> statusVisibility =
      ValueNotifier<String>('show');

  static final ValueNotifier<String> statusOnline =
      ValueNotifier<String>('online');

  static final ValueNotifier<String> statusOffline =
      ValueNotifier<String>('offline');

  static final ValueNotifier<bool> hideFromSearch = ValueNotifier<bool>(false);

  static final ValueNotifier<String> desktopNavPosition =
      ValueNotifier<String>('left');

  static final ValueNotifier<bool> notificationsEnabled =
      ValueNotifier<bool>(true);

  static final ValueNotifier<String> notificationPosition =
      ValueNotifier<String>('bottom_right');

  static final ValueNotifier<bool> notifSoundEnabled =
      ValueNotifier<bool>(true);

  static final ValueNotifier<String> notifSound =
      ValueNotifier<String>('notification0');

  static final ValueNotifier<bool> notifHideContent =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> proxyEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<String> proxyType = ValueNotifier<String>('http');
  static final ValueNotifier<String> proxyHost = ValueNotifier<String>('');
  static final ValueNotifier<String> proxyPort = ValueNotifier<String>('');
  static final ValueNotifier<String> proxyUsername = ValueNotifier<String>('');
  static final ValueNotifier<String> proxyPassword = ValueNotifier<String>('');

  static final ValueNotifier<Locale> appLocale =
      ValueNotifier<Locale>(const Locale('en'));

  static final ValueNotifier<bool> launchAtStartup = ValueNotifier<bool>(false);

  static final ValueNotifier<String> audioInputDeviceId = ValueNotifier<String>('');
  static final ValueNotifier<String> audioOutputDeviceId = ValueNotifier<String>('');
  static final ValueNotifier<bool>   showAccountGraph       = ValueNotifier<bool>(true);
  static final ValueNotifier<double> graphOrbitSpeed        = ValueNotifier<double>(120.0);
  static final ValueNotifier<bool>   graphAnimation         = ValueNotifier<bool>(true);
  static final ValueNotifier<bool>   graphPreservePosition  = ValueNotifier<bool>(true);

  // WardLink — passive local-network sync of Favorites. Master toggle is off by
  // default; sync only ever happens between manually-paired (QR-confirmed) devices.
  static final ValueNotifier<bool> wardLinkEnabled          = ValueNotifier<bool>(false);
  static final ValueNotifier<int>  wardLinkMaxFileSizeMb    = ValueNotifier<int>(2048);
  // false = always show bubble; true = show only on sync errors
  static final ValueNotifier<bool> wardLinkBubbleOnlyErrors = ValueNotifier<bool>(false);
  // Bubble diameter in logical pixels: 40 (small), 48 (normal), 58 (large)
  static final ValueNotifier<int>  wardLinkBubbleSize       = ValueNotifier<int>(48);

  // Custom download folder (null/empty = use system Downloads/ONYX).
  static final ValueNotifier<String> downloadFolderPath = ValueNotifier<String>('');

  static final ValueNotifier<double> chatCacheExtent    = ValueNotifier<double>(1500.0);
  static final ValueNotifier<int>    imagePreloadWindow = ValueNotifier<int>(60);

  static Future<void> init() async {
    final prefs = await _getPrefs();
    // Restore critical appearance/locale settings if SharedPreferences was
    // wiped (e.g. the ONYX data folder was accidentally deleted).
    await SettingsBackup.restoreIfEmpty(prefs);
    final path = prefs.getString(_chatBgKey);
    final apply = prefs.getBool(_applyGlobKey) ?? false;
    final blur = prefs.getBool(_blurKey) ?? false;
    final sigma = prefs.getDouble(_blurSigmaKey) ?? 8.0;
    final debug = prefs.getBool(_debugModeKey) ?? false;
    final showFps = prefs.getBool(_showFpsKey) ?? false;
    final enableLogging_ = prefs.getBool(_enableLoggingKey) ?? false;
    final showDisplayNameInGroups_ =
        prefs.getBool(_showDisplayNameInGroupsKey) ?? true;
    final opacity = prefs.getDouble(_elementOpacityKey) ?? 0.5;
    final brightness = prefs.getDouble(_elementBrightnessKey) ?? 0.35;
    final inputBarWidth = prefs.getDouble(_inputBarMaxWidthKey) ?? 760.0;
    final graphHandlePosition =
        prefs.getDouble(_graphHandlePositionKey) ?? 0.85;
    final swapAlign = prefs.getBool(_swapMessageAlignmentKey) ?? false;
    final alignAllRight = prefs.getBool(_alignAllMessagesRightKey) ?? false;
    final showAvatar = prefs.getBool(_showAvatarInChatsKey) ?? true;
    final showAccountInd = prefs.getBool(_showAccountIndicatorKey) ?? true;
    final smoothScroll = prefs.getBool(_smoothScrollKey) ?? false;
    final messageAnimations = prefs.getBool(_messageAnimationsKey) ?? true;
    final chatListMoveAnimations = prefs.getBool(_chatListMoveAnimationsKey) ?? true;
    final perfOptimizations =
        prefs.getBool(_enablePerformanceOptimizationsKey) ?? true;
    final navBarStyleStr = prefs.getString(_navBarStyleKey);
    final NavBarStyle navBarStyleVal;
    if (navBarStyleStr != null) {
      navBarStyleVal = switch (navBarStyleStr) {
        'liquid' || 'premium' => NavBarStyle.liquid,
        _ => NavBarStyle.standard,
      };
    } else {
      navBarStyleVal = NavBarStyle.standard;
    }
    final scrollDownPosStr = prefs.getString(_scrollDownButtonPositionKey);
    final scrollDownPosVal = ScrollDownButtonPosition.values.firstWhere(
      (e) => e.name == scrollDownPosStr,
      orElse: () => ScrollDownButtonPosition.center,
    );
    final scrollDownSize = prefs.getDouble(_scrollDownButtonSizeKey) ?? 32.0;
    final liquidQualityStr = prefs.getString(_liquidGlassQualityKey) ?? 'quality';
    final liquidQualityVal = LiquidGlassQuality.values.firstWhere(
      (e) => e.name == liquidQualityStr,
      orElse: () => LiquidGlassQuality.quality,
    );
    final liquidExpansion   = prefs.getDouble(_liquidGlassExpansionKey)  ?? 14.0;
    final liquidBlur        = prefs.getDouble(_liquidGlassBlurKey)        ?? 7.0;
    final liquidTint        = prefs.getDouble(_liquidGlassTintKey)        ?? 0.10;
    final liquidSaturation  = prefs.getDouble(_liquidGlassSaturationKey)  ?? 1.0;
    final liquidOnCards          = prefs.getBool(_liquidGlassOnCardsKey)           ?? false;
    final liquidCardsBlur        = prefs.getDouble(_liquidGlassCardsBlurKey)        ?? 7.0;
    final liquidCardsTint        = prefs.getDouble(_liquidGlassCardsTintKey)        ?? 0.10;
    final liquidCardsSaturation  = prefs.getDouble(_liquidGlassCardsSaturationKey)  ?? 1.0;
    final liquidJellyEnabled     = prefs.getBool(_liquidGlassJellyEnabledKey)        ?? false;
    final liquidOnInput          = prefs.getBool(_liquidGlassOnInputKey)             ?? false;
    final liquidInputBlur        = prefs.getDouble(_liquidGlassInputBlurKey)         ?? 7.0;
    final liquidInputTint        = prefs.getDouble(_liquidGlassInputTintKey)         ?? 0.10;
    final liquidInputSaturation  = prefs.getDouble(_liquidGlassInputSaturationKey)   ?? 1.0;
    final liquidOnSearch         = prefs.getBool(_liquidGlassOnSearchKey)            ?? false;
    final liquidSearchBlur       = prefs.getDouble(_liquidGlassSearchBlurKey)        ?? 7.0;
    final liquidSearchTint       = prefs.getDouble(_liquidGlassSearchTintKey)        ?? 0.10;
    final liquidSearchSaturation = prefs.getDouble(_liquidGlassSearchSaturationKey)  ?? 1.0;
    // Advanced
    final liquidChromatic       = prefs.getDouble(_liquidGlassChromaticKey)       ?? 0.30;
    final liquidRefractive      = prefs.getDouble(_liquidGlassRefractiveKey)      ?? 1.59;
    final liquidLightIntensity  = prefs.getDouble(_liquidGlassLightIntensityKey)  ?? 0.60;
    final liquidThickness       = prefs.getDouble(_liquidGlassThicknessKey)       ?? 30.0;
    final liquidCardsChromatic       = prefs.getDouble(_liquidGlassCardsChromaticKey)       ?? 0.15;
    final liquidCardsRefractive      = prefs.getDouble(_liquidGlassCardsRefractiveKey)      ?? 1.40;
    final liquidCardsLightIntensity  = prefs.getDouble(_liquidGlassCardsLightIntensityKey)  ?? 0.50;
    final liquidCardsThickness       = prefs.getDouble(_liquidGlassCardsThicknessKey)       ?? 20.0;
    final liquidInputChromatic       = prefs.getDouble(_liquidGlassInputChromaticKey)       ?? 0.15;
    final liquidInputRefractive      = prefs.getDouble(_liquidGlassInputRefractiveKey)      ?? 1.40;
    final liquidInputLightIntensity  = prefs.getDouble(_liquidGlassInputLightIntensityKey)  ?? 0.50;
    final liquidInputThickness       = prefs.getDouble(_liquidGlassInputThicknessKey)       ?? 20.0;
    final liquidSearchChromatic       = prefs.getDouble(_liquidGlassSearchChromaticKey)       ?? 0.15;
    final liquidSearchRefractive      = prefs.getDouble(_liquidGlassSearchRefractiveKey)      ?? 1.40;
    final liquidSearchLightIntensity  = prefs.getDouble(_liquidGlassSearchLightIntensityKey)  ?? 0.50;
    final liquidSearchThickness       = prefs.getDouble(_liquidGlassSearchThicknessKey)       ?? 24.0;
    final liquidOnNavBar          = prefs.getBool(_liquidGlassOnNavBarKey) ?? false;
    final liquidNavBarQualityStr  = prefs.getString(_liquidGlassNavBarQualityKey) ?? 'quality';
    final liquidNavBarQualityVal  = LiquidGlassQuality.values.firstWhere((e) => e.name == liquidNavBarQualityStr, orElse: () => LiquidGlassQuality.quality);
    final liquidCardsQualityStr   = prefs.getString(_liquidGlassCardsQualityKey)  ?? 'quality';
    final liquidCardsQualityVal   = LiquidGlassQuality.values.firstWhere((e) => e.name == liquidCardsQualityStr,  orElse: () => LiquidGlassQuality.quality);
    final liquidInputQualityStr   = prefs.getString(_liquidGlassInputQualityKey)  ?? 'quality';
    final liquidInputQualityVal   = LiquidGlassQuality.values.firstWhere((e) => e.name == liquidInputQualityStr,  orElse: () => LiquidGlassQuality.quality);
    final liquidSearchQualityStr  = prefs.getString(_liquidGlassSearchQualityKey) ?? 'quality';
    final liquidSearchQualityVal  = LiquidGlassQuality.values.firstWhere((e) => e.name == liquidSearchQualityStr, orElse: () => LiquidGlassQuality.quality);
    final messagePagination = prefs.getBool(_messagePaginationKey) ?? true;
    final snackbarEnabledVal = prefs.getBool(_snackbarEnabledKey) ?? true;
    final minimizeNav = prefs.getBool(_minimizeBottomNavKey) ?? false;
    final swipeTabs = prefs.getBool(_swipeTabsKey) ?? true;

    final fontFamilyStr = prefs.getString(_fontFamilyKey) ?? 'systemFont';
    final fontFamily_ = FontFamilyType.values.firstWhere(
      (e) => e.toString().split('.').last == fontFamilyStr,
      orElse: () => FontFamilyType.systemFont,
    );
    final fontSizeMultiplier_ = prefs.getDouble(_fontSizeKey) ?? 1.0;
    final confirmFile = prefs.getBool(_confirmFileUploadKey) ?? true;
    final confirmVoice = prefs.getBool(_confirmVoiceUploadKey) ?? true;
    final chatCacheExtent_ = prefs.getDouble(_chatCacheExtentKey) ?? 1500.0;
    final imagePreloadWindow_ = prefs.getInt(_imagePreloadWindowKey) ?? 60;

    final statusVisibility_ = prefs.getString(_statusVisibilityKey) ?? 'show';
    final statusOnline_ = prefs.getString(_statusOnlineKey) ?? 'online';
    final statusOffline_ = prefs.getString(_statusOfflineKey) ?? 'offline';
    final hideFromSearch_ = prefs.getBool(_hideFromSearchKey) ?? false;

    final desktopNavPosition_ =
        prefs.getString(_desktopNavPositionKey) ?? 'left';

    final notificationsEnabled_ =
        prefs.getBool(_notificationsEnabledKey) ?? true;
    final notificationPosition_ =
        prefs.getString(_notificationPositionKey) ?? 'bottom_right';
    final notifSoundEnabled_ =
        prefs.getBool(_notifSoundEnabledKey) ?? true;
    final notifSound_ =
        prefs.getString(_notifSoundKey) ?? 'notification0';
    final notifHideContent_ =
        prefs.getBool(_notifHideContentKey) ?? true;

    final proxyEnabled_ = prefs.getBool(_proxyEnabledKey) ?? false;
    final proxyType_ = prefs.getString(_proxyTypeKey) ?? 'http';
    final proxyHost_ = prefs.getString(_proxyHostKey) ?? '';
    final proxyPort_ = prefs.getString(_proxyPortKey) ?? '';

    String proxyUsername_ = await SecureStore.read( _proxyUsernameKey) ?? '';
    String proxyPassword_ = await SecureStore.read( _proxyPasswordKey) ?? '';
    if (proxyUsername_.isEmpty) {
      final legacy = prefs.getString(_proxyUsernameKey) ?? '';
      if (legacy.isNotEmpty) {
        proxyUsername_ = legacy;
        await SecureStore.write( _proxyUsernameKey, legacy);
        await prefs.remove(_proxyUsernameKey);
      }
    }
    if (proxyPassword_.isEmpty) {
      final legacy = prefs.getString(_proxyPasswordKey) ?? '';
      if (legacy.isNotEmpty) {
        proxyPassword_ = legacy;
        await SecureStore.write( _proxyPasswordKey, legacy);
        await prefs.remove(_proxyPasswordKey);
      }
    }

    chatBackground.value = path;
    chatVideoBackground.value = prefs.getString(_chatVideoBgKey);

    final rawPresets = prefs.getStringList(_presetsKey) ?? [];
    themePresets.value = rawPresets.map((s) {
      try { return Map<String, dynamic>.from(jsonDecode(s) as Map); }
      catch (_) { return null; }
    }).whereType<Map<String, dynamic>>().toList();

    applyGlobally.value = apply;
    blurBackground.value = blur;
    blurSigma.value = sigma;
    debugMode.value = debug;
    showFpsOverlay.value = showFps;
    elementOpacity.value = opacity;
    elementBrightness.value = brightness;
    inputBarMaxWidth.value = inputBarWidth;
    graphHandlePositionFraction.value = graphHandlePosition;
    swapMessageAlignment.value = swapAlign;
    alignAllMessagesRight.value = alignAllRight;
    showAvatarInChats.value = showAvatar;
    showAccountIndicator.value = showAccountInd;
    smoothScrollEnabled.value = smoothScroll;
    messageAnimationsEnabled.value = messageAnimations;
    chatListMoveAnimationsEnabled.value = chatListMoveAnimations;
    enablePerformanceOptimizations.value = perfOptimizations;
    SettingsManager.navBarStyle.value = navBarStyleVal;
    SettingsManager.scrollDownButtonPosition.value = scrollDownPosVal;
    SettingsManager.scrollDownButtonSize.value = scrollDownSize;
    SettingsManager.liquidGlassQuality.value   = liquidQualityVal;
    SettingsManager.liquidGlassExpansion.value  = liquidExpansion;
    SettingsManager.liquidGlassBlur.value       = liquidBlur;
    SettingsManager.liquidGlassTint.value       = liquidTint;
    SettingsManager.liquidGlassSaturation.value = liquidSaturation;
    SettingsManager.liquidGlassOnCards.value           = liquidOnCards;
    SettingsManager.liquidGlassCardsBlur.value          = liquidCardsBlur;
    SettingsManager.liquidGlassCardsTint.value          = liquidCardsTint;
    SettingsManager.liquidGlassCardsSaturation.value    = liquidCardsSaturation;
    SettingsManager.liquidGlassJellyEnabled.value        = liquidJellyEnabled;
    SettingsManager.liquidGlassOnInput.value             = liquidOnInput;
    SettingsManager.liquidGlassInputBlur.value           = liquidInputBlur;
    SettingsManager.liquidGlassInputTint.value           = liquidInputTint;
    SettingsManager.liquidGlassInputSaturation.value     = liquidInputSaturation;
    SettingsManager.liquidGlassOnSearch.value            = liquidOnSearch;
    SettingsManager.liquidGlassSearchBlur.value          = liquidSearchBlur;
    SettingsManager.liquidGlassSearchTint.value          = liquidSearchTint;
    SettingsManager.liquidGlassSearchSaturation.value    = liquidSearchSaturation;
    SettingsManager.liquidGlassChromatic.value           = liquidChromatic;
    SettingsManager.liquidGlassRefractive.value          = liquidRefractive;
    SettingsManager.liquidGlassLightIntensity.value      = liquidLightIntensity;
    SettingsManager.liquidGlassThickness.value           = liquidThickness;
    SettingsManager.liquidGlassCardsChromatic.value      = liquidCardsChromatic;
    SettingsManager.liquidGlassCardsRefractive.value     = liquidCardsRefractive;
    SettingsManager.liquidGlassCardsLightIntensity.value = liquidCardsLightIntensity;
    SettingsManager.liquidGlassCardsThickness.value      = liquidCardsThickness;
    SettingsManager.liquidGlassInputChromatic.value      = liquidInputChromatic;
    SettingsManager.liquidGlassInputRefractive.value     = liquidInputRefractive;
    SettingsManager.liquidGlassInputLightIntensity.value = liquidInputLightIntensity;
    SettingsManager.liquidGlassInputThickness.value      = liquidInputThickness;
    SettingsManager.liquidGlassSearchChromatic.value      = liquidSearchChromatic;
    SettingsManager.liquidGlassSearchRefractive.value     = liquidSearchRefractive;
    SettingsManager.liquidGlassSearchLightIntensity.value = liquidSearchLightIntensity;
    SettingsManager.liquidGlassSearchThickness.value      = liquidSearchThickness;
    SettingsManager.navBarStyle.value                  = NavBarStyle.liquid;
    SettingsManager.liquidGlassOnNavBar.value          = liquidOnNavBar;
    SettingsManager.liquidGlassNavBarQuality.value     = liquidNavBarQualityVal;
    SettingsManager.liquidGlassCardsQuality.value      = liquidCardsQualityVal;
    SettingsManager.liquidGlassInputQuality.value      = liquidInputQualityVal;
    SettingsManager.liquidGlassSearchQuality.value     = liquidSearchQualityVal;
    SettingsManager.messagePaginationEnabled.value = messagePagination;
    SettingsManager.snackbarEnabled.value = snackbarEnabledVal;
    SettingsManager.minimizeBottomNav.value = minimizeNav;
    SettingsManager.swipeTabsEnabled.value = swipeTabs;
    SettingsManager.fontFamily.value = fontFamily_;
    SettingsManager.fontSizeMultiplier.value = fontSizeMultiplier_;
    SettingsManager.confirmFileUpload.value = confirmFile;
    SettingsManager.confirmVoiceUpload.value = confirmVoice;
    SettingsManager.chatCacheExtent.value = chatCacheExtent_;
    SettingsManager.imagePreloadWindow.value = imagePreloadWindow_;
    SettingsManager.statusVisibility.value = statusVisibility_;
    SettingsManager.statusOnline.value = statusOnline_;
    SettingsManager.statusOffline.value = statusOffline_;
    SettingsManager.hideFromSearch.value = hideFromSearch_;
    SettingsManager.desktopNavPosition.value = desktopNavPosition_;
    SettingsManager.notificationsEnabled.value = notificationsEnabled_;
    SettingsManager.notificationPosition.value = notificationPosition_;
    SettingsManager.notifSoundEnabled.value = notifSoundEnabled_;
    SettingsManager.notifSound.value = notifSound_;
    SettingsManager.notifHideContent.value = notifHideContent_;
    SettingsManager.proxyEnabled.value = proxyEnabled_;
    SettingsManager.proxyType.value = proxyType_;
    SettingsManager.proxyHost.value = proxyHost_;
    SettingsManager.proxyPort.value = proxyPort_;
    SettingsManager.proxyUsername.value = proxyUsername_;
    SettingsManager.proxyPassword.value = proxyPassword_;
    SettingsManager.enableLogging.value = enableLogging_;
    SettingsManager.showDisplayNameInGroups.value = showDisplayNameInGroups_;
    SettingsManager.pinEnabled.value = prefs.getBool(_pinEnabledKey) ?? false;
    SettingsManager.biometricEnabled.value = prefs.getBool(_biometricEnabledKey) ?? false;
    SettingsManager.lockOnResume.value = prefs.getBool(_lockOnResumeKey) ?? false;
    unawaited(_checkBiometricDeviceSupport());

    final localeCode = prefs.getString(_appLocaleKey) ?? 'en';
    SettingsManager.appLocale.value = Locale(localeCode);

    SettingsManager.launchAtStartup.value = prefs.getBool(_launchAtStartupKey) ?? false;

    SettingsManager.audioInputDeviceId.value = prefs.getString(_audioInputDeviceKey) ?? '';
    SettingsManager.audioOutputDeviceId.value = prefs.getString(_audioOutputDeviceKey) ?? '';
    SettingsManager.showAccountGraph.value      = prefs.getBool(_showAccountGraphKey) ?? true;
    SettingsManager.graphOrbitSpeed.value       = prefs.getDouble(_graphOrbitSpeedKey) ?? 120.0;
    SettingsManager.graphAnimation.value        = prefs.getBool(_graphAnimationKey) ?? true;
    SettingsManager.graphPreservePosition.value = prefs.getBool(_graphPreservePositionKey) ?? true;

    SettingsManager.wardLinkEnabled.value          = prefs.getBool(_wardLinkEnabledKey) ?? false;
    SettingsManager.wardLinkMaxFileSizeMb.value    = prefs.getInt(_wardLinkMaxFileSizeMbKey) ?? 2048;
    SettingsManager.wardLinkBubbleOnlyErrors.value = prefs.getBool(_wardLinkBubbleOnlyErrorsKey) ?? false;
    SettingsManager.wardLinkBubbleSize.value       = prefs.getInt(_wardLinkBubbleSizeKey) ?? 48;

    SettingsManager.autoLoadVideoEnabled.value = prefs.getBool(_autoLoadVideoKey) ?? false;

    final mediaPreloadStr = prefs.getString(_mediaPreloadModeKey);
    SettingsManager.mediaPreloadMode.value = MediaPreloadMode.values.firstWhere(
      (e) => e.name == mediaPreloadStr,
      orElse: () => MediaPreloadMode.wifiOnly,
    );

    SettingsManager.downloadFolderPath.value = prefs.getString(_downloadFolderPathKey) ?? '';

    // Keep the bootstrap-level backup up to date so it reflects the latest settings.
    unawaited(SettingsBackup.save(prefs));
  }

  static String _scopedKey(String baseKey) {
    if (_accountContext == null) return baseKey;
    return '$baseKey:account:${_accountContext}';
  }

  static Future<void> setAccountContext(String? username) async {
    _accountContext = username;
    final prefs = await _getPrefs();

    final scopedVisibility = prefs.getString(_scopedKey(_statusVisibilityKey));
    final scopedOnline = prefs.getString(_scopedKey(_statusOnlineKey));
    final scopedOffline = prefs.getString(_scopedKey(_statusOfflineKey));

    if (scopedVisibility != null) statusVisibility.value = scopedVisibility;
    if (scopedOnline != null) statusOnline.value = scopedOnline;
    if (scopedOffline != null) statusOffline.value = scopedOffline;
  }

  static Future<void> setChatBackground(String? path) async {
    final prefs = await _getPrefs();

    try {
      final prev = chatBackground.value;
      if (prev != null) {
        try {
          await FileImage(File(prev)).evict();
        } catch (e) { debugPrint('[err] $e'); }
      }
    } catch (e) { debugPrint('[err] $e'); }

    if (path == null) {
      await prefs.remove(_chatBgKey);
    } else {
      await prefs.setString(_chatBgKey, path);

      try {
        await FileImage(File(path)).evict();
      } catch (e) { debugPrint('[err] $e'); }
    }

    chatBackground.value = path;
  }

  static Future<void> setChatVideoBackground(String? path) async {
    final prefs = await _getPrefs();
    if (path == null) {
      await prefs.remove(_chatVideoBgKey);
    } else {
      await prefs.setString(_chatVideoBgKey, path);
    }
    chatVideoBackground.value = path;
  }

  static Future<void> saveThemePreset(Map<String, dynamic> preset) async {
    final prefs = await _getPrefs();
    final list = List<Map<String, dynamic>>.from(themePresets.value);
    list.add(preset);
    await prefs.setStringList(_presetsKey, list.map(jsonEncode).toList());
    themePresets.value = list;
  }

  static Future<void> deleteThemePreset(int index) async {
    final prefs = await _getPrefs();
    final list = List<Map<String, dynamic>>.from(themePresets.value);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await prefs.setStringList(_presetsKey, list.map(jsonEncode).toList());
    themePresets.value = list;
  }

  static Future<void> setDebugMode(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_debugModeKey, val);
    debugMode.value = val;
  }

  static Future<void> setShowFpsOverlay(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_showFpsKey, val);
    showFpsOverlay.value = val;
  }

  static Future<void> setApplyGlobally(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_applyGlobKey, val);
    applyGlobally.value = val;
  }

  static Future<void> setBlurBackground(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_blurKey, val);
    blurBackground.value = val;
  }

  static Future<void> setBlurSigma(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_blurSigmaKey, val);
    blurSigma.value = val;
  }

  static Future<void> setGraphHandlePositionFraction(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_graphHandlePositionKey, val);
    graphHandlePositionFraction.value = val;
  }

  static Future<void> setElementOpacity(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_elementOpacityKey, val);
    elementOpacity.value = val;
  }

  static Future<void> setElementBrightness(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_elementBrightnessKey, val);
    elementBrightness.value = val;
  }

  static Future<void> setInputBarMaxWidth(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_inputBarMaxWidthKey, val);
    inputBarMaxWidth.value = val;
  }

  static Future<void> setSwapMessageAlignment(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_swapMessageAlignmentKey, val);
    swapMessageAlignment.value = val;
  }

  static Future<void> setAlignAllMessagesRight(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_alignAllMessagesRightKey, val);
    alignAllMessagesRight.value = val;
  }

  static Future<void> setShowAvatarInChats(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_showAvatarInChatsKey, val);
    showAvatarInChats.value = val;
  }

  static Future<void> setShowAccountIndicator(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_showAccountIndicatorKey, val);
    showAccountIndicator.value = val;
  }

  static Future<void> setSmoothScroll(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_smoothScrollKey, val);
    smoothScrollEnabled.value = val;
  }

  static Future<void> setMessageAnimationsEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_messageAnimationsKey, val);
    messageAnimationsEnabled.value = val;
  }

  static Future<void> setAutoLoadVideoEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_autoLoadVideoKey, val);
    autoLoadVideoEnabled.value = val;
  }

  static Future<void> setMediaPreloadMode(MediaPreloadMode val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_mediaPreloadModeKey, val.name);
    mediaPreloadMode.value = val;
  }

  static Future<void> setChatListMoveAnimationsEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_chatListMoveAnimationsKey, val);
    chatListMoveAnimationsEnabled.value = val;
  }

  static Future<void> setEnablePerformanceOptimizations(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_enablePerformanceOptimizationsKey, val);
    enablePerformanceOptimizations.value = val;
  }

  static Future<void> setNavBarStyle(NavBarStyle val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_navBarStyleKey, val.name);
    navBarStyle.value = val;
  }

  static Future<void> setScrollDownButtonPosition(ScrollDownButtonPosition val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_scrollDownButtonPositionKey, val.name);
    scrollDownButtonPosition.value = val;
  }

  static Future<void> setScrollDownButtonSize(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_scrollDownButtonSizeKey, val);
    scrollDownButtonSize.value = val;
  }

  // ── App theme (non-sensitive UI preference) ────────────────────────────────
  // Stored in SharedPreferences alongside the other appearance settings so it
  // persists reliably on desktop too. The old location was SecureStore, which on
  // macOS/Windows/Linux routes through the encrypted FallbackStorage — that is
  // locked behind the PIN at startup (and unavailable before unlock), so the
  // theme silently reset to the default. We migrate the legacy value once.
  static const _appThemeNameKey = 'app_theme_name';
  static const _appThemeIsDarkKey = 'app_theme_is_dark';

  static Future<({String? name, bool? isDark})> loadThemePreference() async {
    final prefs = await _getPrefs();
    String? name = prefs.getString(_appThemeNameKey);
    bool? isDark =
        prefs.containsKey(_appThemeIsDarkKey) ? prefs.getBool(_appThemeIsDarkKey) : null;

    // One-time migration from the legacy SecureStore location.
    if (name == null) {
      try {
        final legacyName = await SecureStore.read('app_theme_name');
        if (legacyName != null) {
          final legacyDark = await SecureStore.read('app_theme_is_dark');
          name = legacyName;
          isDark ??= legacyDark == null ? null : legacyDark == 'true';
          await prefs.setString(_appThemeNameKey, legacyName);
          if (isDark != null) await prefs.setBool(_appThemeIsDarkKey, isDark);
        }
      } catch (_) {}
    }
    return (name: name, isDark: isDark);
  }

  static Future<void> saveThemePreference(String name, bool isDark) async {
    final prefs = await _getPrefs();
    await prefs.setString(_appThemeNameKey, name);
    await prefs.setBool(_appThemeIsDarkKey, isDark);
    unawaited(SettingsBackup.save(prefs));
  }

  static Future<void> setLiquidGlassQuality(LiquidGlassQuality val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_liquidGlassQualityKey, val.name);
    liquidGlassQuality.value = val;
  }

  static Future<void> setLiquidGlassOnNavBar(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_liquidGlassOnNavBarKey, val);
    liquidGlassOnNavBar.value = val;
  }

  static Future<void> setLiquidGlassNavBarQuality(LiquidGlassQuality val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_liquidGlassNavBarQualityKey, val.name);
    liquidGlassNavBarQuality.value = val;
  }

  static Future<void> setLiquidGlassCardsQuality(LiquidGlassQuality val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_liquidGlassCardsQualityKey, val.name);
    liquidGlassCardsQuality.value = val;
  }

  static Future<void> setLiquidGlassInputQuality(LiquidGlassQuality val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_liquidGlassInputQualityKey, val.name);
    liquidGlassInputQuality.value = val;
  }

  static Future<void> setLiquidGlassSearchQuality(LiquidGlassQuality val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_liquidGlassSearchQualityKey, val.name);
    liquidGlassSearchQuality.value = val;
  }

  static Future<void> setLiquidGlassExpansion(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassExpansionKey, val);
    liquidGlassExpansion.value = val;
  }

  static Future<void> setLiquidGlassBlur(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassBlurKey, val);
    liquidGlassBlur.value = val;
  }

  static Future<void> setLiquidGlassTint(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassTintKey, val);
    liquidGlassTint.value = val;
  }

  static Future<void> setLiquidGlassSaturation(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSaturationKey, val);
    liquidGlassSaturation.value = val;
  }

  static Future<void> setLiquidGlassOnCards(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_liquidGlassOnCardsKey, val);
    liquidGlassOnCards.value = val;
  }

  static Future<void> setLiquidGlassCardsBlur(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsBlurKey, val);
    liquidGlassCardsBlur.value = val;
  }

  static Future<void> setLiquidGlassCardsTint(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsTintKey, val);
    liquidGlassCardsTint.value = val;
  }

  static Future<void> setLiquidGlassCardsSaturation(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsSaturationKey, val);
    liquidGlassCardsSaturation.value = val;
  }

  static Future<void> setLiquidGlassJellyEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_liquidGlassJellyEnabledKey, val);
    liquidGlassJellyEnabled.value = val;
  }

  static Future<void> setLiquidGlassOnInput(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_liquidGlassOnInputKey, val);
    liquidGlassOnInput.value = val;
  }

  static Future<void> setLiquidGlassInputBlur(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputBlurKey, val);
    liquidGlassInputBlur.value = val;
  }

  static Future<void> setLiquidGlassInputTint(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputTintKey, val);
    liquidGlassInputTint.value = val;
  }

  static Future<void> setLiquidGlassInputSaturation(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputSaturationKey, val);
    liquidGlassInputSaturation.value = val;
  }

  static Future<void> setLiquidGlassOnSearch(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_liquidGlassOnSearchKey, val);
    liquidGlassOnSearch.value = val;
  }

  static Future<void> setLiquidGlassSearchBlur(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchBlurKey, val);
    liquidGlassSearchBlur.value = val;
  }

  static Future<void> setLiquidGlassSearchTint(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchTintKey, val);
    liquidGlassSearchTint.value = val;
  }

  static Future<void> setLiquidGlassSearchSaturation(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchSaturationKey, val);
    liquidGlassSearchSaturation.value = val;
  }

  static Future<void> setLiquidGlassChromatic(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassChromaticKey, val);
    liquidGlassChromatic.value = val;
  }

  static Future<void> setLiquidGlassRefractive(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassRefractiveKey, val);
    liquidGlassRefractive.value = val;
  }

  static Future<void> setLiquidGlassLightIntensity(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassLightIntensityKey, val);
    liquidGlassLightIntensity.value = val;
  }

  static Future<void> setLiquidGlassThickness(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassThicknessKey, val);
    liquidGlassThickness.value = val;
  }

  static Future<void> setLiquidGlassCardsChromatic(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsChromaticKey, val);
    liquidGlassCardsChromatic.value = val;
  }

  static Future<void> setLiquidGlassCardsRefractive(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsRefractiveKey, val);
    liquidGlassCardsRefractive.value = val;
  }

  static Future<void> setLiquidGlassCardsLightIntensity(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsLightIntensityKey, val);
    liquidGlassCardsLightIntensity.value = val;
  }

  static Future<void> setLiquidGlassCardsThickness(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassCardsThicknessKey, val);
    liquidGlassCardsThickness.value = val;
  }

  static Future<void> setLiquidGlassInputChromatic(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputChromaticKey, val);
    liquidGlassInputChromatic.value = val;
  }

  static Future<void> setLiquidGlassInputRefractive(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputRefractiveKey, val);
    liquidGlassInputRefractive.value = val;
  }

  static Future<void> setLiquidGlassInputLightIntensity(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputLightIntensityKey, val);
    liquidGlassInputLightIntensity.value = val;
  }

  static Future<void> setLiquidGlassInputThickness(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassInputThicknessKey, val);
    liquidGlassInputThickness.value = val;
  }

  static Future<void> setLiquidGlassSearchChromatic(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchChromaticKey, val);
    liquidGlassSearchChromatic.value = val;
  }

  static Future<void> setLiquidGlassSearchRefractive(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchRefractiveKey, val);
    liquidGlassSearchRefractive.value = val;
  }

  static Future<void> setLiquidGlassSearchLightIntensity(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchLightIntensityKey, val);
    liquidGlassSearchLightIntensity.value = val;
  }

  static Future<void> setLiquidGlassSearchThickness(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_liquidGlassSearchThicknessKey, val);
    liquidGlassSearchThickness.value = val;
  }

  static Future<void> setMessagePaginationEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_messagePaginationKey, val);
    messagePaginationEnabled.value = val;
  }

  static Future<void> setSnackbarEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_snackbarEnabledKey, val);
    snackbarEnabled.value = val;
  }

  static Future<void> setMinimizeBottomNav(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_minimizeBottomNavKey, val);
    minimizeBottomNav.value = val;
  }

  static Future<void> setSwipeTabsEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_swipeTabsKey, val);
    swipeTabsEnabled.value = val;
  }

  static Future<void> setFontFamily(FontFamilyType val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_fontFamilyKey, val.toString().split('.').last);
    fontFamily.value = val;
  }

  static Future<void> setFontSizeMultiplier(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_fontSizeKey, val);
    fontSizeMultiplier.value = val;
  }

  static Future<void> setConfirmFileUpload(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_confirmFileUploadKey, val);
    confirmFileUpload.value = val;
  }

  static Future<void> setConfirmVoiceUpload(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_confirmVoiceUploadKey, val);
    confirmVoiceUpload.value = val;
  }

  static Future<void> setChatCacheExtent(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_chatCacheExtentKey, val);
    chatCacheExtent.value = val;
  }

  static Future<void> setImagePreloadWindow(int val) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_imagePreloadWindowKey, val);
    imagePreloadWindow.value = val;
  }

  static Future<void> setStatusVisibility(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_scopedKey(_statusVisibilityKey), val);
    statusVisibility.value = val;
  }

  static Future<void> setStatusOnline(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_scopedKey(_statusOnlineKey), val);
    statusOnline.value = val;
  }

  static Future<void> setStatusOffline(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_scopedKey(_statusOfflineKey), val);
    statusOffline.value = val;
  }

  static Future<void> setDesktopNavPosition(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_desktopNavPositionKey, val);
    desktopNavPosition.value = val;
  }

  static Future<void> setNotificationsEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_notificationsEnabledKey, val);
    notificationsEnabled.value = val;
  }

  static Future<void> setNotificationPosition(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_notificationPositionKey, val);
    notificationPosition.value = val;
  }

  static Future<void> setNotifSoundEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_notifSoundEnabledKey, val);
    notifSoundEnabled.value = val;
  }

  static Future<void> setNotifSound(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_notifSoundKey, val);
    notifSound.value = val;
  }

  static Future<void> setNotifHideContent(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_notifHideContentKey, val);
    notifHideContent.value = val;
  }

  static Future<void> setProxyEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_proxyEnabledKey, val);
    proxyEnabled.value = val;
  }

  static Future<void> setProxyType(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_proxyTypeKey, val);
    proxyType.value = val;
  }

  static Future<void> setProxyHost(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_proxyHostKey, val);
    proxyHost.value = val;
  }

  static Future<void> setProxyPort(String val) async {
    final prefs = await _getPrefs();
    await prefs.setString(_proxyPortKey, val);
    proxyPort.value = val;
  }

  static Future<void> setProxyUsername(String val) async {
    await SecureStore.write( _proxyUsernameKey, val);
    proxyUsername.value = val;
  }

  static Future<void> setProxyPassword(String val) async {
    await SecureStore.write( _proxyPasswordKey, val);
    proxyPassword.value = val;
  }

  static Future<void> setEnableLogging(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_enableLoggingKey, val);
    enableLogging.value = val;
  }

  static Future<void> setShowDisplayNameInGroups(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_showDisplayNameInGroupsKey, val);
    showDisplayNameInGroups.value = val;
  }

  static Future<void> setPinEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_pinEnabledKey, val);
    pinEnabled.value = val;
    // Mirror in encrypted storage so the flag survives SharedPreferences loss
    // (e.g. user deletes the old default data folder which contains shared_preferences.json).
    try { await SecureStore.write('pin_lock_enabled_secure', val ? '1' : '0'); } catch (_) {}
  }

  /// Restores pin_lock_enabled from encrypted storage if SharedPreferences lost it.
  /// Call after FallbackStorage is unlocked so SecureStore is readable.
  static Future<void> restorePinEnabledIfLost() async {
    if (pinEnabled.value) return;
    try {
      final backed = await SecureStore.read('pin_lock_enabled_secure');
      if (backed == '1') {
        final prefs = await _getPrefs();
        await prefs.setBool(_pinEnabledKey, true);
        pinEnabled.value = true;
      }
    } catch (_) {}
  }

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static Future<void> setPin(String pin) async {
    await SecureStore.write(_pinCodeSecureKey, pin);
    // On desktop: migrate storage to v3 (PIN-derived encryption).
    if (_isDesktop) {
      await FallbackStorage.main.migrateToV3(pin);
    }
    // Keep the biometric copy of the PIN in sync if biometrics are enabled.
    if (biometricEnabled.value) {
      await storeBiometricPin(pin);
    }
  }

  static Future<String?> getPin() async {
    return await SecureStore.read(_pinCodeSecureKey);
  }

  static Future<void> clearPin() async {
    await SecureStore.delete(_pinCodeSecureKey);
    await clearBiometricPin();
    // On desktop: migrate storage back to v2 (machine-derived encryption).
    if (_isDesktop) {
      await FallbackStorage.main.migrateToV2();
    }
  }

  static Future<void> _checkBiometricDeviceSupport() async {
    try {
      if (kIsWeb) return;
      final auth = LocalAuthentication();
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      biometricDeviceSupported.value = supported || canCheck;
    } catch (_) {
      biometricDeviceSupported.value = false;
    }
  }

  static Future<void> setLockOnResume(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_lockOnResumeKey, val);
    lockOnResume.value = val;
  }

  static Future<void> setBiometricEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_biometricEnabledKey, val);
    biometricEnabled.value = val;
    if (val) {
      // Stash the current PIN so biometrics can decrypt the store on desktop.
      // On desktop the live PIN is FallbackStorage's _unlockedPin; on mobile
      // fall back to the keychain-stored PIN.
      final pin = FallbackStorage.main.currentPin ?? await getPin();
      if (pin != null && pin.isNotEmpty) await storeBiometricPin(pin);
    } else {
      await clearBiometricPin();
    }
  }

  // ── Biometric PIN stash (OS keychain, gated by the local_auth prompt) ───────

  static Future<void> storeBiometricPin(String pin) async {
    try {
      await _bioKeychain.write(key: _biometricPinKey, value: pin);
      debugPrint('[biometric] storeBiometricPin: ok');
    } catch (e) {
      debugPrint('[biometric] storeBiometricPin FAILED: $e');
    }
  }

  static Future<String?> getBiometricPin() async {
    try {
      return await _bioKeychain.read(key: _biometricPinKey);
    } catch (e) {
      debugPrint('[biometric] getBiometricPin FAILED: $e');
      return null;
    }
  }

  static Future<void> clearBiometricPin() async {
    try {
      await _bioKeychain.delete(key: _biometricPinKey);
    } catch (_) {}
  }

  static Future<void> setAppLocale(Locale locale) async {
    final prefs = await _getPrefs();
    await prefs.setString(_appLocaleKey, locale.languageCode);
    appLocale.value = locale;
    unawaited(SettingsBackup.save(prefs));
  }

  static Future<void> setLaunchAtStartup(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_launchAtStartupKey, val);
    launchAtStartup.value = val;
  }

  static Future<void> setAudioInputDevice(String id) async {
    final prefs = await _getPrefs();
    await prefs.setString(_audioInputDeviceKey, id);
    audioInputDeviceId.value = id;
  }

  static Future<void> setAudioOutputDevice(String id) async {
    final prefs = await _getPrefs();
    await prefs.setString(_audioOutputDeviceKey, id);
    audioOutputDeviceId.value = id;
  }

  static Future<void> setShowAccountGraph(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_showAccountGraphKey, val);
    showAccountGraph.value = val;
  }

  static Future<void> setGraphOrbitSpeed(double val) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_graphOrbitSpeedKey, val);
    graphOrbitSpeed.value = val;
  }

  static Future<void> setGraphAnimation(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_graphAnimationKey, val);
    graphAnimation.value = val;
  }

  static Future<void> setGraphPreservePosition(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_graphPreservePositionKey, val);
    graphPreservePosition.value = val;
  }

  static Future<void> setHideFromSearch(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_hideFromSearchKey, val);
    hideFromSearch.value = val;
  }

  // ── WardLink ────────────────────────────────────────────────────────────────

  static Future<void> setWardLinkEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_wardLinkEnabledKey, val);
    wardLinkEnabled.value = val;
  }

  static Future<void> setWardLinkMaxFileSizeMb(int val) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_wardLinkMaxFileSizeMbKey, val);
    wardLinkMaxFileSizeMb.value = val;
  }

  static Future<void> setWardLinkBubbleOnlyErrors(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_wardLinkBubbleOnlyErrorsKey, val);
    wardLinkBubbleOnlyErrors.value = val;
  }

  static Future<void> setWardLinkBubbleSize(int val) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_wardLinkBubbleSizeKey, val);
    wardLinkBubbleSize.value = val;
  }

  static Future<void> setDownloadFolderPath(String val) async {
    final prefs = await _getPrefs();
    if (val.isEmpty) {
      await prefs.remove(_downloadFolderPathKey);
    } else {
      await prefs.setString(_downloadFolderPathKey, val);
    }
    downloadFolderPath.value = val;
  }

  static Color getElementColor(
    Color baseColor,
    double brightness,
  ) {
    
    final hslColor = HSLColor.fromColor(baseColor);

    final baseLightness = hslColor.lightness;

    final lightnessOffset = (brightness - 0.5) * 0.6; 
    final newLightness = (baseLightness + lightnessOffset).clamp(0.0, 1.0);

    return hslColor.withLightness(newLightness).toColor();
  }
}