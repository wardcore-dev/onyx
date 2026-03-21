// lib/utils/clipboard_image.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';
import 'image_file_cache.dart';
import '../globals.dart';

/// Copies an IMAGEv1: message's image to the system clipboard.
/// Shows snack messages via [showSnack].
Future<void> copyMessageImageToClipboard(
  String content,
  void Function(String) showSnack,
) async {
  try {
    if (!content.startsWith('IMAGEv1:')) return;
    final data = jsonDecode(content.substring('IMAGEv1:'.length)) as Map<String, dynamic>;
    final filename = data['url'] as String? ?? data['filename'] as String? ?? '';
    if (filename.isEmpty) return;

    final cached = imageFileCache[filename];
    if (cached == null) {
      showSnack('Image not loaded yet — open it first');
      return;
    }
    await copyFileImageToClipboard(cached.file, showSnack);
  } catch (e) {
    showSnack('Copy failed: $e');
  }
}

/// Copies [imageFile] bytes to the system clipboard as an image.
Future<void> copyFileImageToClipboard(
  File imageFile,
  void Function(String) showSnack,
) async {
  try {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      showSnack('Clipboard not available on this device');
      return;
    }
    final bytes = await imageFile.readAsBytes();
    final item = DataWriterItem();
    final ext = p.extension(imageFile.path).toLowerCase();
    if (ext == '.png') {
      item.add(Formats.png(bytes));
    } else {
      // JPEG, WEBP, etc. — write as JPEG
      item.add(Formats.jpeg(bytes));
    }
    await clipboard.write([item]);
    showSnack('Image copied to clipboard');
  } catch (e) {
    showSnack('Copy failed: $e');
  }
}
