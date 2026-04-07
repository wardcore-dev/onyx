// lib/utils/autostart_manager.dart
import 'dart:io';

/// Windows-only autostart manager.
/// Uses the built-in `reg` command — no COM, no PowerShell, no admin rights.
class AutostartManager {
  AutostartManager._();

  static const _regKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _approvedKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
  static const _valueName = 'ONYX';

  static Future<bool> isEnabled() async {
    final result = await Process.run('reg', [
      'query', _regKey, '/v', _valueName,
    ]);
    return result.exitCode == 0;
  }

  static Future<bool> enable() async {
    final value = '"${Platform.resolvedExecutable}"';

    final addRun = await Process.run('reg', [
      'add', _regKey,
      '/v', _valueName,
      '/t', 'REG_SZ',
      '/d', value,
      '/f',
    ]);
    if (addRun.exitCode != 0) {
      throw Exception('reg add failed (${addRun.exitCode}): ${addRun.stderr}');
    }

    // Windows 10/11 checks StartupApproved — byte[0]=2 means enabled.
    // Without this a previously-disabled entry stays suppressed.
    await Process.run('reg', [
      'add', _approvedKey,
      '/v', _valueName,
      '/t', 'REG_BINARY',
      '/d', '020000000000000000000000',
      '/f',
    ]);

    return true;
  }

  static Future<bool> disable() async {
    await Process.run('reg', ['delete', _regKey,       '/v', _valueName, '/f']);
    await Process.run('reg', ['delete', _approvedKey,  '/v', _valueName, '/f']);
    return true;
  }
}
