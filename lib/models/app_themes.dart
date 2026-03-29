import 'package:flutter/material.dart';
import 'font_family.dart';
import '../managers/settings_manager.dart';

enum AppTheme {
  deepPurple, 
  darkBlue, 
  darkGreen, 
  orange, 
  pink, 
  red, 
  cyan, 
  indigo, 
  teal, 
  grey, 
}

extension AppThemeExtension on AppTheme {
  String get name {
    switch (this) {
      case AppTheme.deepPurple:
        return 'Deep Purple';
      case AppTheme.darkBlue:
        return 'Dark Blue';
      case AppTheme.darkGreen:
        return 'Dark Green';
      case AppTheme.orange:
        return 'Orange';
      case AppTheme.pink:
        return 'Pink';
      case AppTheme.red:
        return 'Red';
      case AppTheme.cyan:
        return 'Cyan';
      case AppTheme.indigo:
        return 'Indigo';
      case AppTheme.teal:
        return 'Teal';
      case AppTheme.grey:
        return 'Graphite';
    }
  }

  Color get color {
    switch (this) {
      case AppTheme.deepPurple:
        return Colors.deepPurple;
      case AppTheme.darkBlue:
        return const Color(0xFF0084B4); 
      case AppTheme.darkGreen:
        return const Color(0xFF00A651);
      case AppTheme.orange:
        return Colors.orange;
      case AppTheme.pink:
        return Colors.pink;
      case AppTheme.red:
        return Colors.red;
      case AppTheme.cyan:
        return Colors.cyan;
      case AppTheme.indigo:
        return Colors.indigo;
      case AppTheme.teal:
        return Colors.teal;
      case AppTheme.grey:
        return Colors.grey; 
    }
  }

  ThemeData getThemeData({
    required bool isDark,
    FontFamilyType fontFamily = FontFamilyType.systemFont,
    double fontSizeMultiplier = 1.0,
    double elementOpacity = 1.0,
    double elementBrightness = 0.5,
  }) {
    Color seedColor = color;
    final colorScheme = this == AppTheme.grey
        ? _getGreyColorScheme(isDark)
        : ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: isDark ? Brightness.dark : Brightness.light,
          );
    
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.grey.shade800
            : const Color.fromARGB(172, 255, 255, 255),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    final textTheme = fontFamily.getTextTheme(isDark: isDark);
    final scaledTextTheme = textTheme.apply(
      bodyColor: baseTheme.colorScheme.onSurface,
    );

    final scaledTheme = baseTheme.copyWith(
      textTheme: _scaleTextTheme(scaledTextTheme, fontSizeMultiplier),
    );

    final popupMenuTheme = scaledTheme.popupMenuTheme.copyWith(
      color: scaledTheme.colorScheme.surface.withOpacity(elementOpacity),
    );

    final dialogColor = SettingsManager.getElementColor(
      scaledTheme.colorScheme.surface,
      elementBrightness,
    );

    final bottomSheetTheme = scaledTheme.bottomSheetTheme.copyWith(
      modalBackgroundColor: dialogColor.withOpacity(elementOpacity),
      backgroundColor: dialogColor.withOpacity(elementOpacity),
    );

    return scaledTheme.copyWith(
      dialogBackgroundColor: dialogColor.withOpacity(elementOpacity),
      popupMenuTheme: popupMenuTheme,
      bottomSheetTheme: bottomSheetTheme,
    );
  }

  static TextTheme _scaleTextTheme(TextTheme theme, double multiplier) {
    return theme.copyWith(
      displayLarge: theme.displayLarge?.apply(fontSizeFactor: multiplier),
      displayMedium: theme.displayMedium?.apply(fontSizeFactor: multiplier),
      displaySmall: theme.displaySmall?.apply(fontSizeFactor: multiplier),
      headlineLarge: theme.headlineLarge?.apply(fontSizeFactor: multiplier),
      headlineMedium: theme.headlineMedium?.apply(fontSizeFactor: multiplier),
      headlineSmall: theme.headlineSmall?.apply(fontSizeFactor: multiplier),
      titleLarge: theme.titleLarge?.apply(fontSizeFactor: multiplier),
      titleMedium: theme.titleMedium?.apply(fontSizeFactor: multiplier),
      titleSmall: theme.titleSmall?.apply(fontSizeFactor: multiplier),
      bodyLarge: theme.bodyLarge?.apply(fontSizeFactor: multiplier),
      bodyMedium: theme.bodyMedium?.apply(fontSizeFactor: multiplier),
      bodySmall: theme.bodySmall?.apply(fontSizeFactor: multiplier),
      labelLarge: theme.labelLarge?.apply(fontSizeFactor: multiplier),
      labelMedium: theme.labelMedium?.apply(fontSizeFactor: multiplier),
      labelSmall: theme.labelSmall?.apply(fontSizeFactor: multiplier),
    );
  }

  static ColorScheme _getGreyColorScheme(bool isDark) {
    if (isDark) {
      
      return const ColorScheme.dark(
        primary: Color(0xFF808080),
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFF2D2D2D),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFF0F0F0F),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFF262626),
        onSecondaryContainer: Color(0xFFFFFFFF),
        tertiary: Color(0xFF1F1F1F),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFF333333),
        onTertiaryContainer: Color(0xFFFFFFFF),
        error: Color(0xFFCF6679),
        onError: Color(0xFF140B0E),
        errorContainer: Color(0xFF93000A),
        onErrorContainer: Color(0xFFF9DEDC),
        background: Color(0xFF000000),
        onBackground: Color(0xFFFFFFFF),
        surface: Color(0xFF0A0A0A),
        onSurface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFF1A1A1A),
        onSurfaceVariant: Color(0xFFE0E0E0),
        outline: Color(0xFF404040),
        outlineVariant: Color(0xFF1A1A1A),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFFFFFFFF),
        inversePrimary: Color(0xFF333333),
      );
    } else {
      
      return const ColorScheme.light(
        primary: Color(0xFF606060),
        onPrimary: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE0E0E0),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFF707070),
        onSecondary: Color(0xFFFFFFFF),
        secondaryContainer: Color(0xFFE8E8E8),
        onSecondaryContainer: Color(0xFF000000),
        tertiary: Color(0xFF808080),
        onTertiary: Color(0xFFFFFFFF),
        tertiaryContainer: Color(0xFFEFEFEF),
        onTertiaryContainer: Color(0xFF000000),
        error: Color(0xFFB3261E),
        onError: Color(0xFFFFFFFF),
        errorContainer: Color(0xFFF9DEDC),
        onErrorContainer: Color(0xFF410E0B),
        background: Color(0xFFFAFAFA),
        onBackground: Color(0xFF1C1C1C),
        surface: Color(0xFFFCFCFC),
        onSurface: Color(0xFF1C1C1C),
        surfaceVariant: Color(0xFFEFEFEF),
        onSurfaceVariant: Color(0xFF505050),
        outline: Color(0xFF787878),
        outlineVariant: Color(0xFFD0D0D0),
        scrim: Color(0xFF000000),
        inverseSurface: Color(0xFF313131),
        inversePrimary: Color(0xFFC0C0C0),
      );
    }
  }
}