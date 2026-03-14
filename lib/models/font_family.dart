import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum FontFamilyType {
  systemFont,    
  openSans,      
  roboto,        
  noto,          
  inter,         
  poppins,       
  sanFrancisco,  
}

extension FontFamilyTypeExtension on FontFamilyType {
  String get displayName {
    switch (this) {
      case FontFamilyType.systemFont:
        return 'System Font';
      case FontFamilyType.openSans:
        return 'Open Sans (Google)';
      case FontFamilyType.roboto:
        return 'Roboto (Google)';
      case FontFamilyType.noto:
        return 'Noto Sans (Google)';
      case FontFamilyType.inter:
        return 'Inter (Google)';
      case FontFamilyType.poppins:
        return 'Poppins (Google)';
      case FontFamilyType.sanFrancisco:
        return 'San Francisco (Apple)';
    }
  }

  String get description {
    switch (this) {
      case FontFamilyType.systemFont:
        return 'Default system font';
      case FontFamilyType.openSans:
        return 'Friendly and open-ended';
      case FontFamilyType.roboto:
        return 'Classic modern sans-serif';
      case FontFamilyType.noto:
        return 'Clean and universal';
      case FontFamilyType.inter:
        return 'Optimized for screen display';
      case FontFamilyType.poppins:
        return 'Bold rounded geometric';
      case FontFamilyType.sanFrancisco:
        return 'Bold rounded Apple design';
    }
  }

  String get fontFamilyName {
    switch (this) {
      case FontFamilyType.systemFont:
        return '';  
      case FontFamilyType.openSans:
        return 'Open Sans';
      case FontFamilyType.roboto:
        return 'Roboto';
      case FontFamilyType.noto:
        return 'Noto Sans';
      case FontFamilyType.inter:
        return 'Inter';
      case FontFamilyType.poppins:
        return 'Poppins';
      case FontFamilyType.sanFrancisco:
        return '.SF Pro Display';
    }
  }

  TextTheme getTextTheme({bool isDark = false}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;

    switch (this) {
      case FontFamilyType.systemFont:
        
        return ThemeData(brightness: brightness).textTheme;
      case FontFamilyType.openSans:
        return GoogleFonts.openSansTextTheme(
          ThemeData(brightness: brightness).textTheme,
        );
      case FontFamilyType.roboto:
        return GoogleFonts.robotoTextTheme(
          ThemeData(brightness: brightness).textTheme,
        );
      case FontFamilyType.noto:
        return GoogleFonts.notoSansTextTheme(
          ThemeData(brightness: brightness).textTheme,
        );
      case FontFamilyType.inter:
        return GoogleFonts.interTextTheme(
          ThemeData(brightness: brightness).textTheme,
        );
      case FontFamilyType.poppins:
        return GoogleFonts.poppinsTextTheme(
          ThemeData(brightness: brightness).textTheme,
        );
      case FontFamilyType.sanFrancisco:
        
        return ThemeData(brightness: brightness)
            .textTheme
            .apply(fontFamily: '.SF Pro Display');
    }
  }

  TextStyle getBodyTextStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    
    if (this == FontFamilyType.systemFont) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }

    if (this == FontFamilyType.sanFrancisco) {
      return TextStyle(
        fontFamily: '.SF Pro Display',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }

    switch (this) {
      case FontFamilyType.openSans:
        return GoogleFonts.openSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case FontFamilyType.roboto:
        return GoogleFonts.roboto(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case FontFamilyType.noto:
        return GoogleFonts.notoSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case FontFamilyType.inter:
        return GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case FontFamilyType.poppins:
        return GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case FontFamilyType.sanFrancisco:
        return TextStyle(
          fontFamily: '.SF Pro Display',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
      case FontFamilyType.systemFont:
        return TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        );
    }
  }
}