// lib/utils/wallpaper_util.dart
//
// Sets a local image/video file as the in-app chat wallpaper. Shared by the
// "Set as wallpaper" menu action on image and video fullscreen viewers, so
// the copy/clear logic mirrors what Settings > Chat Background already does.
import 'dart:io';
import 'package:flutter/widgets.dart' show FileImage;
import 'package:path/path.dart' as p;
import '../managers/settings_manager.dart';
import 'onyx_base_dir.dart';

Future<void> setFileAsChatWallpaper(File sourceFile, {required bool isVideo}) async {
  final ext = p.extension(sourceFile.path).toLowerCase();
  final dir = await getOnyxSupportDirectory();
  final bgDir = Directory('${dir.path}/backgrounds');
  await bgDir.create(recursive: true);

  if (isVideo) {
    final files = bgDir.listSync().whereType<File>().toList();
    for (final f in files) {
      if (p.basename(f.path).startsWith('chat_video_bg')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    final videoExt = ext.isNotEmpty ? ext : '.mp4';
    final dest =
        '${bgDir.path}/chat_video_bg_${DateTime.now().millisecondsSinceEpoch}$videoExt';
    await sourceFile.copy(dest);
    await SettingsManager.setChatVideoBackground(dest);
    await SettingsManager.setChatBackground(null);
  } else {
    final files = bgDir.listSync().whereType<File>().toList();
    for (final f in files) {
      final name = p.basename(f.path);
      if (name.startsWith('chat_bg') && !name.startsWith('chat_video_bg')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    final imgExt = ext.isNotEmpty ? ext : '.jpg';
    final dest =
        '${bgDir.path}/chat_bg_${DateTime.now().millisecondsSinceEpoch}$imgExt';
    await sourceFile.copy(dest);

    try {
      final prev = SettingsManager.chatBackground.value;
      if (prev != null) await FileImage(File(prev)).evict();
      await FileImage(File(dest)).evict();
    } catch (_) {}

    await SettingsManager.setChatBackground(dest);
    await SettingsManager.setChatVideoBackground(null);
  }
}
