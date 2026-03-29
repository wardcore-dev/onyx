// lib/managers/settings_manager.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/font_family.dart';
import 'secure_store.dart';

class SettingsManager {

  static const _chatBgKey = 'chat_background_path';
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
  static const _smoothScrollKey = 'smooth_scroll_enabled';
  static const _messageAnimationsKey = 'message_animations_enabled';
  static const _enablePerformanceOptimizationsKey =
      'enable_performance_optimizations';
  static const _useLiquidGlassKey = 'use_liquid_glass_nav';
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
  static const _desktopNavPositionKey = 'desktop_nav_position';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _notificationPositionKey = 'notification_position';
  static const _notifSoundEnabledKey = 'notif_sound_enabled';
  static const _notifSoundKey = 'notif_sound';
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
  static const _appLocaleKey = 'app_locale';

  static String? _accountContext;
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  static final ValueNotifier<String?> chatBackground =
      ValueNotifier<String?>(null);
  static final ValueNotifier<bool> applyGlobally = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> blurBackground = ValueNotifier<bool>(false);
  static final ValueNotifier<double> blurSigma = ValueNotifier<double>(8.0);
  static final ValueNotifier<double> elementOpacity =
      ValueNotifier<double>(0.5);
  static final ValueNotifier<double> elementBrightness =
      ValueNotifier<double>(0.35);
  static final ValueNotifier<double> inputBarMaxWidth =
      ValueNotifier<double>(760.0);

  static final ValueNotifier<bool> debugMode = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> showFpsOverlay = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> enableLogging = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> showDisplayNameInGroups =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> pinEnabled = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> biometricEnabled = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> swapMessageAlignment =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> alignAllMessagesRight =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> showAvatarInChats =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> smoothScrollEnabled =
      ValueNotifier<bool>(false);

  static final ValueNotifier<bool> messageAnimationsEnabled =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> enablePerformanceOptimizations =
      ValueNotifier<bool>(true);

  static final ValueNotifier<bool> useLiquidGlass = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> messagePaginationEnabled = ValueNotifier<bool>(true);

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

  static final ValueNotifier<bool> proxyEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<String> proxyType = ValueNotifier<String>('http');
  static final ValueNotifier<String> proxyHost = ValueNotifier<String>('');
  static final ValueNotifier<String> proxyPort = ValueNotifier<String>('');
  static final ValueNotifier<String> proxyUsername = ValueNotifier<String>('');
  static final ValueNotifier<String> proxyPassword = ValueNotifier<String>('');

  static final ValueNotifier<Locale> appLocale =
      ValueNotifier<Locale>(const Locale('en'));

  static Future<void> init() async {
    final prefs = await _getPrefs();
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
    final swapAlign = prefs.getBool(_swapMessageAlignmentKey) ?? false;
    final alignAllRight = prefs.getBool(_alignAllMessagesRightKey) ?? false;
    final showAvatar = prefs.getBool(_showAvatarInChatsKey) ?? true;
    final smoothScroll = prefs.getBool(_smoothScrollKey) ?? false;
    final messageAnimations = prefs.getBool(_messageAnimationsKey) ?? true;
    final perfOptimizations =
        prefs.getBool(_enablePerformanceOptimizationsKey) ?? true;
    final useLiquidGlass = prefs.getBool(_useLiquidGlassKey) ?? true;
    final messagePagination = prefs.getBool(_messagePaginationKey) ?? true;
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

    final statusVisibility_ = prefs.getString(_statusVisibilityKey) ?? 'show';
    final statusOnline_ = prefs.getString(_statusOnlineKey) ?? 'online';
    final statusOffline_ = prefs.getString(_statusOfflineKey) ?? 'offline';

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
    applyGlobally.value = apply;
    blurBackground.value = blur;
    blurSigma.value = sigma;
    debugMode.value = debug;
    showFpsOverlay.value = showFps;
    elementOpacity.value = opacity;
    elementBrightness.value = brightness;
    inputBarMaxWidth.value = inputBarWidth;
    swapMessageAlignment.value = swapAlign;
    alignAllMessagesRight.value = alignAllRight;
    showAvatarInChats.value = showAvatar;
    smoothScrollEnabled.value = smoothScroll;
    messageAnimationsEnabled.value = messageAnimations;
    enablePerformanceOptimizations.value = perfOptimizations;
    SettingsManager.useLiquidGlass.value = useLiquidGlass;
    SettingsManager.messagePaginationEnabled.value = messagePagination;
    SettingsManager.minimizeBottomNav.value = minimizeNav;
    SettingsManager.swipeTabsEnabled.value = swipeTabs;
    SettingsManager.fontFamily.value = fontFamily_;
    SettingsManager.fontSizeMultiplier.value = fontSizeMultiplier_;
    SettingsManager.confirmFileUpload.value = confirmFile;
    SettingsManager.confirmVoiceUpload.value = confirmVoice;
    SettingsManager.statusVisibility.value = statusVisibility_;
    SettingsManager.statusOnline.value = statusOnline_;
    SettingsManager.statusOffline.value = statusOffline_;
    SettingsManager.desktopNavPosition.value = desktopNavPosition_;
    SettingsManager.notificationsEnabled.value = notificationsEnabled_;
    SettingsManager.notificationPosition.value = notificationPosition_;
    SettingsManager.notifSoundEnabled.value = notifSoundEnabled_;
    SettingsManager.notifSound.value = notifSound_;
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

    final localeCode = prefs.getString(_appLocaleKey) ?? 'en';
    SettingsManager.appLocale.value = Locale(localeCode);

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

  static Future<void> setEnablePerformanceOptimizations(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_enablePerformanceOptimizationsKey, val);
    enablePerformanceOptimizations.value = val;
  }

  static Future<void> setUseLiquidGlass(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_useLiquidGlassKey, val);
    useLiquidGlass.value = val;
  }

  static Future<void> setMessagePaginationEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_messagePaginationKey, val);
    messagePaginationEnabled.value = val;
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
  }

  static Future<void> setPin(String pin) async {
    await SecureStore.write( _pinCodeSecureKey, pin);
  }

  static Future<String?> getPin() async {
    return await SecureStore.read( _pinCodeSecureKey);
  }

  static Future<void> clearPin() async {
    await SecureStore.delete(_pinCodeSecureKey);
  }

  static Future<void> setBiometricEnabled(bool val) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_biometricEnabledKey, val);
    biometricEnabled.value = val;
  }

  static Future<void> setAppLocale(Locale locale) async {
    final prefs = await _getPrefs();
    await prefs.setString(_appLocaleKey, locale.languageCode);
    appLocale.value = locale;
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