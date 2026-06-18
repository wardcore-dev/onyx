// lib/screens/root_screen_wrapper.dart
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';
import '../managers/account_manager.dart';
import '../managers/decoy_manager.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/migration_dialog.dart';
import 'root_screen.dart';
import 'device_auth_screen.dart';
import '../models/app_themes.dart';

class RootScreenWrapper extends StatefulWidget {
  final AppTheme currentTheme;
  final bool isDarkMode;
  final Future<void> Function(AppTheme theme, bool isDark) onThemeChanged;

  const RootScreenWrapper({
    Key? key,
    required this.currentTheme,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<RootScreenWrapper> createState() => _RootScreenWrapperState();
}

class _RootScreenWrapperState extends State<RootScreenWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showMigrationDialogIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RootScreen(
          key: rootScreenKey,
          currentTheme: widget.currentTheme,
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
        ),
        ValueListenableBuilder<bool>(
          valueListenable: DecoyManager.isActive,
          builder: (context, decoyActive, _) =>
          ValueListenableBuilder<List<String>>(
          valueListenable: AccountManager.accountsNotifier,
          builder: (context, accounts, _) {
            if (accounts.isNotEmpty || decoyActive) return const SizedBox.shrink();
            return _WelcomeOverlay(
              onLogin: (u, p) async {
                final state = rootScreenKey.currentState;
                if (state == null) return false;
                return state.loginAccount(u, p);
              },
              onRegister: (u, p) async {
                final state = rootScreenKey.currentState;
                if (state == null) return null;
                return state.registerAccount(u, p);
              },
              onQrLogin: ({
                required username,
                required token,
                required uin,
                required isPrimary,
              }) async {
                final state = rootScreenKey.currentState;
                if (state == null) return false;
                return state.loginWithQrToken(
                  username: username,
                  token: token,
                  uin: uin,
                  isPrimary: isPrimary,
                );
              },
            );
          },
          ),
        ),
      ],
    );
  }
}

class _WelcomeOverlay extends StatefulWidget {
  final Future<bool> Function(String, String) onLogin;
  final Future<String?> Function(String, String) onRegister;
  final Future<bool> Function({
    required String username,
    required String token,
    required String uin,
    required bool isPrimary,
  }) onQrLogin;

  const _WelcomeOverlay({
    required this.onLogin,
    required this.onRegister,
    required this.onQrLogin,
  });

  @override
  State<_WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<_WelcomeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadelogo;
  late Animation<Offset> _slideLogo;
  late Animation<double> _fadeText;
  late Animation<Offset> _slideText;
  late Animation<double> _fadeBtn1;
  late Animation<double> _scaleBtn1;
  late Animation<double> _fadeBtn2;
  late Animation<double> _scaleBtn2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadelogo = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _slideLogo = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    ));

    _fadeText = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.60, curve: Curves.easeOut),
    );
    _slideText = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.60, curve: Curves.easeOutCubic),
    ));

    // Add Account — появляется первым
    _fadeBtn1 = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.54, 0.74, curve: Curves.easeOut),
    );
    _scaleBtn1 = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.54, 0.78, curve: Curves.easeOutBack),
      ),
    );

    // Link Device — с небольшим отставанием
    _fadeBtn2 = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.68, 0.88, curve: Curves.easeOut),
    );
    _scaleBtn2 = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.68, 0.92, curve: Curves.easeOutBack),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openAuthDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Authentication',
      transitionDuration: const Duration(milliseconds: 133),
      pageBuilder: (ctx, anim1, anim2) => AuthDialog(
        onLogin: widget.onLogin,
        onRegister: widget.onRegister,
        onQrLogin: widget.onQrLogin,
      ),
    );
  }

  void _openLinkDevice(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DeviceAuthScreen(
        currentUsername: null,
        onQrLogin: widget.onQrLogin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Locale>(
      valueListenable: SettingsManager.appLocale,
      builder: (context, locale, _) {
        final l = AppLocalizations(locale);
        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  FadeTransition(
                    opacity: _fadelogo,
                    child: SlideTransition(
                      position: _slideLogo,
                      child: Image.asset(
                        'assets/onyx-512.png',
                        width: 220,
                        height: 220,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  FadeTransition(
                    opacity: _fadeText,
                    child: SlideTransition(
                      position: _slideText,
                      child: Text(
                        'ONYX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          height: 1.1,
                          letterSpacing: 4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  ValueListenableBuilder<double>(
                    valueListenable: SettingsManager.elementBrightness,
                    builder: (_, brightness, __) {
                      final baseColor = SettingsManager.getElementColor(
                        colorScheme.surfaceContainerHighest,
                        brightness,
                      );
                      return Column(
                        children: [
                          // Add Account — первая
                          FadeTransition(
                            opacity: _fadeBtn1,
                            child: ScaleTransition(
                              scale: _scaleBtn1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: baseColor.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withValues(alpha: 0.15),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _openAuthDialog(context),
                                      icon: Icon(
                                        Icons.add,
                                        size: 18,
                                        color: colorScheme.primary,
                                      ),
                                      label: Text(
                                        l.addAccount,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.primary.withValues(alpha: 0.12),
                                        foregroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Link Device — вторая, с задержкой
                          FadeTransition(
                            opacity: _fadeBtn2,
                            child: ScaleTransition(
                              scale: _scaleBtn2,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: baseColor.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .dividerColor
                                          .withValues(alpha: 0.15),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () => _openLinkDevice(context),
                                      icon: Icon(
                                        Icons.devices_rounded,
                                        size: 18,
                                        color: colorScheme.secondary,
                                      ),
                                      label: Text(
                                        l.deviceAuthTitle,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.secondary.withValues(alpha: 0.12),
                                        foregroundColor: colorScheme.secondary,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}