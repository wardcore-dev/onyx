// lib/utils/dialog_utils.dart
import 'package:flutter/material.dart';

/// Dismisses the keyboard (if one is open) and waits for its hide animation
/// to settle before the caller opens a dialog/bottom sheet.
///
/// Calling `FocusScope.of(context).unfocus()` and immediately pushing a
/// dialog on the same frame makes the IME-hide inset animation and the
/// dialog's enter transition fight over the same frame budget — on Android
/// in particular this shows up as a visible freeze/jank for a few frames.
/// When no field is focused this is a no-op with zero added latency.
Future<void> unfocusAndSettle(BuildContext context) async {
  final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
  FocusScope.of(context).unfocus();
  if (keyboardOpen) {
    await Future.delayed(const Duration(milliseconds: 180));
  }
}
