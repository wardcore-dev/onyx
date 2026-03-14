// lib/screens/root_screen_wrapper.dart
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';
import '../managers/account_manager.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../widgets/auth_dialog.dart';
import 'root_screen.dart';
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RootScreen(
          key: rootScreenKey,
          currentTheme: widget.currentTheme,
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
        ),
        ValueListenableBuilder<List<String>>(
          valueListenable: AccountManager.accountsNotifier,
          builder: (context, accounts, _) {
            if (accounts.isNotEmpty) return const SizedBox.shrink();
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
            );
          },
        ),
      ],
    );
  }
}

class _WelcomeOverlay extends StatefulWidget {
  final Future<bool> Function(String, String) onLogin;
  final Future<String?> Function(String, String) onRegister;

  const _WelcomeOverlay({required this.onLogin, required this.onRegister});

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
  late Animation<double> _fadeBtn;
  late Animation<Offset> _slideBtn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadelogo = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _slideLogo = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));

    _fadeText = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
    );
    _slideText = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.75, curve: Curves.easeOutCubic),
    ));

    _fadeBtn = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
    _slideBtn = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
    ));

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
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => AuthDialog(
        onLogin: widget.onLogin,
        onRegister: widget.onRegister,
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
                  
                  FadeTransition(
                    opacity: _fadeBtn,
                    child: SlideTransition(
                      position: _slideBtn,
                      child: ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.elementBrightness,
                        builder: (_, brightness, __) {
                          final baseColor = SettingsManager.getElementColor(
                            colorScheme.surfaceContainerHighest,
                            brightness,
                          );
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                color: baseColor.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
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
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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