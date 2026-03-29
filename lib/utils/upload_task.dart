// lib/utils/upload_task.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum UploadStatus { preparing, uploading, paused, failed, done }

/// Tracks the state of a single pending media upload across all chat screens.
class UploadTask {
  final String id;

  /// 'image' | 'video' | 'voice' | 'file'
  final String type;
  final String localPath;
  final String basename;

  /// Plain (unencrypted) bytes used for blurred image preview.
  Uint8List? previewBytes;

  /// Encrypted bytes stored so resume doesn't need to re-encrypt.
  Uint8List? encryptedBytes;

  String? mediaKey;
  String? presignType;
  String? presignExt;
  String? presignContentType;

  /// Progress 0.0..1.0 — backed by notifier so PendingUploadCard auto-rebuilds.
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  double get progress => progressNotifier.value;
  set progress(double v) => progressNotifier.value = v;

  /// Upload status — backed by notifier so PendingUploadCard auto-rebuilds.
  final ValueNotifier<UploadStatus> statusNotifier =
      ValueNotifier(UploadStatus.preparing);
  UploadStatus get status => statusNotifier.value;
  set status(UploadStatus v) => statusNotifier.value = v;

  http.Client? activeClient;

  /// Called with the server filename once upload + confirm succeeds.
  Future<void> Function(String filename)? onComplete;

  /// Used by group/external screens (catbox / multipart) to restart the whole
  /// upload pipeline when the user taps Resume.
  Future<void> Function()? onRetry;

  UploadTask({
    required this.id,
    required this.type,
    required this.localPath,
    required this.basename,
  });
}
