// lib/managers/mute_manager.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MuteManager {
  static const _key = 'muted_usernames';

  static final ValueNotifier<Set<String>> mutedUsers =
      ValueNotifier<Set<String>>({});

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> init() async {
    final prefs = await _getPrefs();
    final list = prefs.getStringList(_key) ?? [];
    mutedUsers.value = Set<String>.from(list);
  }

  static bool isMuted(String username) =>
      mutedUsers.value.contains(username);

  static Future<void> mute(String username) async {
    final prefs = await _getPrefs();
    final newSet = Set<String>.from(mutedUsers.value)..add(username);
    await prefs.setStringList(_key, newSet.toList());
    mutedUsers.value = newSet;
  }

  static Future<void> unmute(String username) async {
    final prefs = await _getPrefs();
    final newSet = Set<String>.from(mutedUsers.value)..remove(username);
    await prefs.setStringList(_key, newSet.toList());
    mutedUsers.value = newSet;
  }
}
