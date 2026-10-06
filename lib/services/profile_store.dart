// lib/services/profile_store.dart
//
// Local-first profile (display name + avatar). There is no central server to
// hold these any more, so the device owns them: avatars live in
// <support>/avatars/avatar_<username>_<md5> (the same layout AvatarWidget
// reads), the display name in AccountManager's cache, and a per-account
// "updatedAt" stamp lets the newest edit win when profiles are synced between
// a user's own devices (WardLink) or sent to contacts (onion).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show md5;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../globals.dart' show avatarVersion, rootScreenKey;
import '../managers/account_manager.dart';
import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;

class ProfileStore {
  ProfileStore._();

  static String _stampKey(String username) => 'profile_updated_at_$username';

  static Future<Directory> _dir() async {
    final support = await getOnyxSupportDirectory();
    return Directory(p.join(support.path, 'avatars'));
  }

  static Future<int> updatedAt(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_stampKey(username)) ?? 0;
  }

  static Future<void> setUpdatedAt(String username, int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stampKey(username), ms);
  }

  /// Marks the profile as edited now and returns the stamp.
  static Future<int> touch(String username) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await setUpdatedAt(username, now);
    return now;
  }

  /// Newest cached avatar bytes for [username], or null.
  static Future<List<int>?> readAvatar(String username) async {
    try {
      final dir = await _dir();
      if (!await dir.exists()) return null;
      final prefix = 'avatar_${username}_';
      File? best;
      DateTime? bestTime;
      await for (final f in dir.list()) {
        if (f is! File) continue;
        final name = p.basename(f.path);
        if (!name.startsWith(prefix) || name.contains('.tmp_')) continue;
        final m = (await f.stat()).modified;
        if (bestTime == null || m.isAfter(bestTime)) {
          best = f;
          bestTime = m;
        }
      }
      return best == null ? null : await best.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Stores [bytes] as [username]'s avatar, replacing any previous one.
  static Future<void> writeAvatar(String username, List<int> bytes) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    final name = 'avatar_${username}_${md5.convert(bytes)}';
    final target = File(p.join(dir.path, name));
    await target.writeAsBytes(bytes, flush: true);
    await for (final f in dir.list()) {
      if (f is File &&
          p.basename(f.path).startsWith('avatar_${username}_') &&
          f.path != target.path) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    avatarVersion.value++;
  }

  static Future<void> deleteAvatar(String username) async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      if (f is File && p.basename(f.path).startsWith('avatar_${username}_')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    avatarVersion.value++;
  }

  /// Snapshot of our own profile for sending to a contact / own device.
  static Future<Map<String, dynamic>> exportProfile(String username) async {
    final name = await AccountManager.getCachedDisplayName(username);
    final avatar = await readAvatar(username);
    return {
      'updatedAt': await updatedAt(username),
      if (name != null && name.isNotEmpty) 'name': name,
      if (avatar != null) 'avatar': base64Encode(avatar),
    };
  }

  /// Applies a profile received from one of OUR OWN devices (newest wins).
  /// Returns true if anything changed.
  static Future<bool> applyOwnProfile(
      String username, Map<String, dynamic> profile) async {
    final remoteAt = (profile['updatedAt'] as num?)?.toInt() ?? 0;
    if (remoteAt <= await updatedAt(username)) return false;
    final name = profile['name'] as String?;
    if (name != null && name.isNotEmpty) {
      await AccountManager.cacheDisplayName(username, name);
      final root = rootScreenKey.currentState;
      if (root != null && root.currentUsername == username) {
        // ignore: invalid_use_of_protected_member
        root.setState(() => root.currentDisplayName = name);
      }
    }
    final avatarB64 = profile['avatar'] as String?;
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      await writeAvatar(username, base64Decode(avatarB64));
    } else {
      await deleteAvatar(username);
    }
    await setUpdatedAt(username, remoteAt);
    return true;
  }
}
