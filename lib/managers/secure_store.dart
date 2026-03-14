// lib/managers/secure_store.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'fallback_storage.dart';

class SecureStore {
  static const _keychain = FlutterSecureStorage();
  static final _fallback = FallbackStorage();

  static bool get _useFallback => !kIsWeb && Platform.isMacOS;

  static Future<String?> read(String key) async {
    if (_useFallback) return _fallback.read(key);
    return _keychain.read(key: key);
  }

  static Future<void> write(String key, String value) async {
    if (_useFallback) return _fallback.write(key, value);
    return _keychain.write(key: key, value: value);
  }

  static Future<void> delete(String key) async {
    if (_useFallback) return _fallback.delete(key);
    return _keychain.delete(key: key);
  }

  static Future<void> clear() async {
    if (_useFallback) return _fallback.clear();
    return _keychain.deleteAll();
  }
}