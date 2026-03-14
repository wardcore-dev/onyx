// lib/utils/pubkey_cache.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PubkeyCache {
  static final PubkeyCache _instance = PubkeyCache._internal();

  factory PubkeyCache() {
    return _instance;
  }

  PubkeyCache._internal();

  final Map<String, _CacheEntry> _cache = {};

  final Duration _cacheTTL = const Duration(minutes: 30);

  final int _maxEntries = 1000;

  Future<String?> getPubkey(String username, String serverBase, {String? token}) async {
    
    final cached = _cache[username];
    if (cached != null && !cached.isExpired()) {
      return cached.pubkey;
    }

    try {
      final headers = token != null ? {'authorization': 'Bearer $token'} : <String, String>{};
      final response = await http
          .get(Uri.parse('$serverBase/pubkey/$username'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final pubkey = body['pubkey'] as String?;
        if (pubkey != null) {
          
          _set(username, pubkey);
          return pubkey;
        }
      }
    } catch (e) {
      debugPrint('[err] $e');
    }
    return null;
  }

  void _set(String username, String pubkey) {
    _cache[username] = _CacheEntry(pubkey, DateTime.now());

    if (_cache.length > _maxEntries) {
      final oldest = _cache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b);
      _cache.remove(oldest.key);
    }
  }

  void setPubkey(String username, String pubkey) {
    _set(username, pubkey);
  }

  void invalidate(String username) {
    _cache.remove(username);
  }

  void clear() {
    _cache.clear();
  }

  int getSize() => _cache.length;
}

class _CacheEntry {
  final String pubkey;
  final DateTime timestamp;

  _CacheEntry(this.pubkey, this.timestamp);

  bool isExpired() {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 30);
  }
}