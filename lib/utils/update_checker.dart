// lib/utils/update_checker.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ValueNotifier;
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? assetName;
  final int fileSize;

  const UpdateInfo({
    required this.version,
    this.releaseNotes,
    this.downloadUrl,
    this.assetName,
    this.fileSize = 0,
  });
}

final ValueNotifier<UpdateInfo?> updateInfoNotifier =
    ValueNotifier<UpdateInfo?>(null);

class UpdateChecker {
  static const _apiUrl =
      'https://api.github.com/repos/wardcore-dev/onyx/releases/latest';

  static Future<UpdateInfo?> checkForUpdates(String currentVersion) async {
    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String? ?? '').trim();

      if (latestTag.isEmpty || latestTag == currentVersion) return null;

      final assets = (data['assets'] as List<dynamic>?) ?? [];

      String? platformAssetName;
      if (!kIsWeb) {
        if (Platform.isWindows) {
          platformAssetName = 'onyx-setup.exe';
        } else if (Platform.isMacOS) {
          platformAssetName = 'ONYX.dmg';
        } else if (Platform.isLinux) {
          platformAssetName = 'onyx-linux-x64.tar.gz';
        } else if (Platform.isAndroid) {
          platformAssetName = 'app-release.apk';
        }
      }

      String? downloadUrl;
      String? assetName;
      int fileSize = 0;

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name == platformAssetName) {
          downloadUrl = asset['browser_download_url'] as String?;
          assetName = name;
          fileSize = (asset['size'] as int?) ?? 0;
          break;
        }
      }

      return UpdateInfo(
        version: latestTag,
        releaseNotes: data['body'] as String?,
        downloadUrl: downloadUrl,
        assetName: assetName,
        fileSize: fileSize,
      );
    } catch (_) {
      return null;
    }
  }
}
