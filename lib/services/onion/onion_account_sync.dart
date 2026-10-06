// lib/services/onion/onion_account_sync.dart
//
// Hands this account to another of the user's devices (inside WardLink's
// pairing reply, encrypted with the pairing session key). The new device
// gets the account signing key, the signed device roster and our contacts
// -- NOT our onion key or device key: it mints its own address and key and
// then announces itself to us and to every contact via the roster (see
// onion_account.dart). Sharing one address between two devices is what
// used to make both look offline while both were on.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../managers/account_manager.dart';
import '../profile_store.dart';
import '../../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;
import 'onion_account.dart';
import 'onion_account_key.dart';
import 'onion_identity.dart';
import 'onion_paired_peers.dart';

class OnionAccountSync {
  OnionAccountSync._();

  static const _keyFile = 'hs_ed25519_key_blob';

  static Future<File> _blobFile(String username) async {
    final support = await getOnyxSupportDirectory();
    return File(p.join(support.path, 'onion_hs_$username', _keyFile));
  }

  /// Null until this device's onion service is up under [username] (its own
  /// entry on the roster needs its address).
  static Future<Map<String, dynamic>?> exportBundle(String username) async {
    if (!OnionIdentity.isRunning || !OnionAccount.isLoaded) return null;
    final seed = await OnionAccount.exportSeedB64();
    final roster = await OnionAccount.signedRoster();
    if (seed == null || roster == null) return null;
    final displayName = await AccountManager.getCachedDisplayName(username);
    final avatar = await ProfileStore.readAvatar(username);
    return {
      'v': 2,
      // Which device this comes from: a device that has the same key is a
      // copy of it (an older build's linking) and must get keys of its own.
      'from': OnionIdentity.publicKeyB64,
      'acctSeed': seed,
      'roster': roster,
      'contacts': [
        for (final c in OnionPairedPeers.peers.value) c.toJson(),
      ],
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      if (avatar != null) 'avatar': base64Encode(avatar),
      'profileUpdatedAt': await ProfileStore.updatedAt(username),
    };
  }

  /// Sets this (new) device up as one more device of [username]'s account.
  /// Must run before the account's onion service starts here.
  static Future<bool> importBundle(
      String username, Map<String, dynamic> bundle) async {
    var ok = false;
    if (bundle['v'] == 2) {
      final seed = bundle['acctSeed'] as String?;
      // This device's key for the account, if it has been on it before.
      final localPub = await OnionAccountKey.peekPublicKeyB64(username);
      final roster = seed == null
          ? null
          : await OnionAccount.importFromLink(username, seed, bundle['roster']);
      if (roster != null) {
        // Linked again while already a device of this account: it keeps its
        // key and address -- a new pair would show up as a second device.
        // Otherwise (new here, unlinked earlier, or a copy of the other
        // device's keys from an older build) a key and address of its own.
        final already = localPub != null &&
            localPub != bundle['from'] &&
            roster.lists(localPub);
        if (!already) {
          await OnionAccountKey.discard(username);
          final blob = await _blobFile(username);
          if (await blob.exists()) await blob.delete();
        }
        final contacts = <OnionPeer>[];
        for (final c in (bundle['contacts'] as List? ?? const [])) {
          try {
            contacts.add(OnionPeer.fromJson(Map<String, dynamic>.from(c as Map)));
          } catch (_) {}
        }
        await OnionPairedPeers.storeForAccount(username, contacts);
        ok = true;
      }
    }
    // An older build's bundle carries the other device's own keys; adopting
    // them is exactly what broke multi-device. Only the profile is taken.

    // Profile: best effort, never fails the account hand-over.
    try {
      final name = bundle['displayName'] as String?;
      if (name != null && name.isNotEmpty) {
        await AccountManager.cacheDisplayName(username, name);
      }
      final avatarB64 = bundle['avatar'] as String?;
      if (avatarB64 != null && avatarB64.isNotEmpty) {
        await ProfileStore.writeAvatar(username, base64Decode(avatarB64));
      }
      await ProfileStore.setUpdatedAt(
          username, (bundle['profileUpdatedAt'] as num?)?.toInt() ?? 0);
    } catch (_) {}
    return ok;
  }
}
