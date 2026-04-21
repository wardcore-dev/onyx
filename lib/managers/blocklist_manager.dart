// lib/managers/blocklist_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlocklistManager {
  static const _key = 'blocklist_usernames';

  static final ValueNotifier<Set<String>> blockedUsers =
      ValueNotifier<Set<String>>({});

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> init() async {
    final prefs = await _getPrefs();
    final list = prefs.getStringList(_key) ?? [];
    blockedUsers.value = Set<String>.from(list);
  }

  static bool isBlocked(String username) =>
      blockedUsers.value.contains(username);

  static Future<void> block(String username) async {
    final prefs = await _getPrefs();
    final newSet = Set<String>.from(blockedUsers.value)..add(username);
    await prefs.setStringList(_key, newSet.toList());
    blockedUsers.value = newSet;
  }

  static Future<void> unblock(String username) async {
    final prefs = await _getPrefs();
    final newSet = Set<String>.from(blockedUsers.value)..remove(username);
    await prefs.setStringList(_key, newSet.toList());
    blockedUsers.value = newSet;
  }

  /// Replaces the local blocklist with the authoritative list from the server.
  static Future<void> syncFromServer(List<String> serverList) async {
    final prefs = await _getPrefs();
    final newSet = Set<String>.from(serverList);
    await prefs.setStringList(_key, newSet.toList());
    blockedUsers.value = newSet;
  }
}
