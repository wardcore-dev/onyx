import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';
import '../models/font_family.dart';

TextStyle buildMessageTextStyle({
  required BuildContext context,
  double baseFontSize = 14,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
}) {
  final currentFont = SettingsManager.fontFamily.value;
  final fontMultiplier = SettingsManager.fontSizeMultiplier.value;
  final finalFontSize = baseFontSize * fontMultiplier;

  return currentFont.getBodyTextStyle(
    fontSize: finalFontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

TextStyle getMessageBubbleTextStyle({
  required BuildContext context,
  double baseFontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
}) {
  final currentFont = SettingsManager.fontFamily.value;
  final fontMultiplier = SettingsManager.fontSizeMultiplier.value;
  final finalFontSize = baseFontSize * fontMultiplier;

  return currentFont.getBodyTextStyle(
    fontSize: finalFontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

extension TextStyleExtension on TextStyle {
  
  TextStyle withFontSizeMultiplier(double multiplier) {
    if (fontSize == null) return this;
    return copyWith(fontSize: fontSize! * multiplier);
  }
}