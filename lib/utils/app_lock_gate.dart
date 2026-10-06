// lib/utils/app_lock_gate.dart
//
// Asks for the app's own lock before a sensitive action -- the same check the
// account switcher does (biometrics first when enabled, then the PIN screen).
// With no PIN lock enabled there is nothing to unlock and it says yes at once.

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../managers/settings_manager.dart';
import '../screens/pin_code_screen.dart';

/// True if the user may go on: no PIN lock is enabled, or they proved it is
/// them (biometrics / device credential if enabled and it works, else PIN).
Future<bool> confirmWithAppLock(
  BuildContext context, {
  String reason = 'Confirm to continue',
}) async {
  if (!SettingsManager.pinEnabled.value) return true;

  final useBiometrics = SettingsManager.biometricEnabled.value;
  final localAuth = LocalAuthentication();

  if (useBiometrics) {
    try {
      if (await localAuth.isDeviceSupported()) {
        final ok = await localAuth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(biometricOnly: false),
        );
        if (ok) return true;
      }
    } catch (e) {
      debugPrint('[app-lock] biometric check failed: $e');
    }
  }

  if (!context.mounted) return false;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
    fullscreenDialog: true,
    builder: (routeCtx) => PinCodeScreen.verify(
      onSuccess: () => Navigator.of(routeCtx).pop(true),
      onCancel: () => Navigator.of(routeCtx).pop(false),
      onBiometric: useBiometrics
          ? () async {
              try {
                if (!await localAuth.isDeviceSupported()) return;
                final done = await localAuth.authenticate(
                  localizedReason: reason,
                  options: const AuthenticationOptions(biometricOnly: false),
                );
                if (done && routeCtx.mounted) Navigator.of(routeCtx).pop(true);
              } catch (e) {
                debugPrint('[app-lock] biometric check failed: $e');
              }
            }
          : null,
    ),
  ));
  return ok == true;
}
