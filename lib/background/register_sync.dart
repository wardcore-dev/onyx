// lib/background/register_sync.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:workmanager/workmanager.dart';

const String syncTaskName = 'syncMessagesTask';

Future<void> registerAdaptiveSync({Duration? interval}) async {
  
  if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    if (kIsWeb) {
      
    } else {
      debugPrint('[sync] Workmanager skipped on ${Platform.operatingSystem}');
    }
    return;
  }

  await Workmanager().cancelByUniqueName(syncTaskName);

  await Workmanager().registerPeriodicTask(
    syncTaskName,
    syncTaskName,
    frequency: interval ?? const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}