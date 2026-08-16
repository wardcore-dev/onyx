import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../globals.dart' show rootScreenKey;
import '../l10n/app_localizations.dart' show lookupAppLocalizations;
import '../managers/settings_manager.dart';

/// Returns the directory where ONYX saves received files.
/// Uses the user-configured path if set, otherwise defaults to Downloads/ONYX.
Future<Directory?> getOnyxSaveDirectory() async {
  final custom = SettingsManager.downloadFolderPath.value.trim();
  if (custom.isNotEmpty) {
    final dir = Directory(custom);
    await dir.create(recursive: true);
    return dir;
  }
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final dl = await getDownloadsDirectory();
    if (dl == null) return null;
    final onyxDir = Directory('${dl.path}/ONYX');
    await onyxDir.create(recursive: true);
    return onyxDir;
  }
  return null;
}

/// Saves an image to the device gallery, handling .jfif by copying to .jpg first
/// (some native gallery plugins do not recognise the .jfif extension).
Future<bool> saveImageToGallery(String filePath,
    {String albumName = 'ONYX'}) async {
  File fileToSave = File(filePath);
  File? tempJpg;
  if (p.extension(filePath).toLowerCase() == '.jfif') {
    final tmp = await getTemporaryDirectory();
    final tempPath =
        '${tmp.path}/${p.basenameWithoutExtension(filePath)}.jpg';
    tempJpg = await File(filePath).copy(tempPath);
    fileToSave = tempJpg;
  }
  try {
    return await GallerySaver.saveImage(fileToSave.path,
            albumName: albumName) ==
        true;
  } finally {
    await tempJpg?.delete().catchError((_) => File(''));
  }
}

/// Opens the system file manager and selects/reveals [filePath].
/// Only works on desktop platforms (Windows, macOS, Linux).
Future<void> revealInFileSystem(String filePath) async {
  if (kIsWeb) return;
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,${filePath.replaceAll('/', '\\')}']);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [p.dirname(filePath)]);
    }
  } catch (e) {
    debugPrint('revealInFileSystem error: $e');
  }
}

/// Standard "Saved to: <path>" confirmation for an explicit save-to-disk
/// action (native Save As dialog, or the configured downloads folder) — on
/// desktop it adds a "Show in file system" action button so the user can
/// jump straight to the saved file. Never call this for files that only
/// landed in ONYX's own cache/support directories; those aren't meant to be
/// browsed by the user.
void showSavedToSnack(String path) {
  if (!kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    final l = lookupAppLocalizations(SettingsManager.appLocale.value);
    rootScreenKey.currentState?.showSnack(
      'Saved to: $path',
      actionLabel: l.showInFileSystem,
      onAction: () => revealInFileSystem(path),
    );
  } else {
    rootScreenKey.currentState?.showSnack('Saved to: $path');
  }
}

class FileTypeDetector {
  static const imageExtensions = {
    '.jpg', '.jpeg', '.jfif', '.png', '.gif', '.webp', '.bmp', '.svg'
  };

  static const videoExtensions = {
    '.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.m4v'
  };

  static const audioExtensions = {
    '.mp3', '.wav', '.aac', '.m4a', '.flac', '.ogg', '.wma'
  };

  static const documentExtensions = {
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.rtf'
  };

  static const compressExtensions = {
    '.zip', '.rar', '.7z', '.tar', '.gz'
  };

  static const dataExtensions = {
    '.json', '.xml', '.csv'
  };

  static const allowedExtensions = {
    ...imageExtensions,
    ...videoExtensions,
    ...audioExtensions,
    ...documentExtensions,
    ...compressExtensions,
    ...dataExtensions,
  };

  static String getExtension(String filePath) {
    return p.extension(filePath).toLowerCase();
  }

  static bool isImage(String filePath) {
    return imageExtensions.contains(getExtension(filePath));
  }

  static bool isVideo(String filePath) {
    return videoExtensions.contains(getExtension(filePath));
  }

  static bool isAudio(String filePath) {
    return audioExtensions.contains(getExtension(filePath));
  }

  static bool isDocument(String filePath) {
    return documentExtensions.contains(getExtension(filePath));
  }

  static bool isCompress(String filePath) {
    return compressExtensions.contains(getExtension(filePath));
  }

  static bool isData(String filePath) {
    return dataExtensions.contains(getExtension(filePath));
  }

  static bool isAllowed(String filePath) {
    
    return true;
  }

  static String getFileType(String filePath) {
    if (isImage(filePath)) return 'IMAGE';
    if (isVideo(filePath)) return 'VIDEO';
    if (isAudio(filePath)) return 'AUDIO';
    if (isDocument(filePath)) return 'DOCUMENT';
    if (isCompress(filePath)) return 'COMPRESS';
    if (isData(filePath)) return 'DATA';
    return 'FILE';
  }
}

class FileInfo {
  final String filePath;
  final String filename;
  final String extension;
  final int fileSize;
  final String fileType;
  final Uint8List? previewBytes;

  FileInfo({
    required this.filePath,
    required this.filename,
    required this.extension,
    required this.fileSize,
    required this.fileType,
    this.previewBytes,
  });

  String get formattedSize => _formatFileSize(fileSize);

  static String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(2)} ${suffixes[i]}';
  }

  static Future<FileInfo> fromPath(String filePath, {bool loadPreview = true}) async {
    final filename = p.basename(filePath);
    final extension = p.extension(filename).toLowerCase();
    final fileType = FileTypeDetector.getFileType(filePath);
    
    Uint8List? previewBytes;
    int fileSize = 0;

    if (kIsWeb) {
      
      fileSize = 0;
    } else {
      final file = File(filePath);
      if (await file.exists()) {
        fileSize = await file.length();
        if (loadPreview && FileTypeDetector.isImage(filePath)) {
          try {
            previewBytes = await file.readAsBytes();
          } catch (e) {
            debugPrint('Error loading preview: $e');
          }
        }
      }
    }

    return FileInfo(
      filePath: filePath,
      filename: filename,
      extension: extension,
      fileSize: fileSize,
      fileType: fileType,
      previewBytes: previewBytes,
    );
  }
}