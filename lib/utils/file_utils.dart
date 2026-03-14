import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path/path.dart' as p;

class FileTypeDetector {
  static const imageExtensions = {
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'
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