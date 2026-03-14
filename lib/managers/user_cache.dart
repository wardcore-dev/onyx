// lib/managers/user_cache.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart';
import 'account_manager.dart';

class UserProfile {
  final String username;
  final String displayName;
  final String description;
  final String? uin;

  UserProfile({
    required this.username,
    required this.displayName,
    required this.description,
    this.uin,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          displayName == other.displayName;

  @override
  int get hashCode => username.hashCode ^ displayName.hashCode;
}

class UserCache {
  static final Map<String, UserProfile> _cache = {};

  static final ValueNotifier<Set<String>> updatedUsers = ValueNotifier<Set<String>>({});

  static final Set<String> _pendingFetches = {};

  static void invalidate(String username) {
    _cache.remove(username);
    updatedUsers.value = {...updatedUsers.value, username};
  }

  static UserProfile? getSync(String username) {
    return _cache[username];
  }

  static String? getDescription(String username) {
    final info = _cache[username];
    return info?.description;
  }

  static Future<UserProfile> get(String username) async {
    
    if (_cache.containsKey(username)) {
      return _cache[username]!;
    }

    if (_pendingFetches.contains(username)) {
      
      await Future.delayed(const Duration(milliseconds: 50));
      if (_cache.containsKey(username)) return _cache[username]!;
    }

    _pendingFetches.add(username);

    try {
      final acc = await AccountManager.getCurrentAccount();
      final token = acc != null ? await AccountManager.getToken(acc) : null;
      final res = await http.get(
        Uri.parse('$serverBase/profile/$username'),
        headers: token != null ? {'authorization': 'Bearer $token'} : {},
      );
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final info = UserProfile(
          username: username,
          displayName: j['display_name'] ?? username,
          description: j['description'] ?? '',
          uin: j['uin']?.toString(),
        );
        _cache[username] = info;
        updatedUsers.value = {...updatedUsers.value, username};
        return info;
      }
    } catch (e) {
      debugPrint('[err] $e');
    } finally {
      _pendingFetches.remove(username);
    }

    final fallback = UserProfile(username: username, displayName: username, description: '');
    _cache[username] = fallback;
    updatedUsers.value = {...updatedUsers.value, username};
    return fallback;
  }
}