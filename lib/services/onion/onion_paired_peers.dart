// lib/services/onion/onion_paired_peers.dart
//
// The set of Onyx contacts the user has paired for onion-mode 1:1 chat,
// scoped to the currently-logged-in account. Mirrors
// lib/services/wardlink/wardlink_paired_devices.dart in shape, but keyed by
// Onyx *username* rather than device identity: onion mode routes a specific
// 1:1 chat, so root_screen needs "is this chat's other user onion-paired,
// and if so at what address" -- not "is this device trusted".
//
// Public keys and onion addresses are not secret, so this lives in
// SharedPreferences rather than the keychain.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnionPeer {
  final String username;
  final String identityPubB64;
  final String onionAddress;
  final String name;
  final String os;
  final DateTime pairedAt;

  /// The contact's account key (see onion_account.dart), once a device of
  /// theirs presented a roster signed by it. Every device that key lists is
  /// a device of this contact.
  final String? accountPubB64;

  const OnionPeer({
    required this.username,
    required this.identityPubB64,
    required this.onionAddress,
    required this.name,
    required this.os,
    required this.pairedAt,
    this.accountPubB64,
  });

  List<int> get identityPub => base64Decode(identityPubB64);

  OnionPeer withAccount(String? acct) => OnionPeer(
        username: username,
        identityPubB64: identityPubB64,
        onionAddress: onionAddress,
        name: name,
        os: os,
        pairedAt: pairedAt,
        accountPubB64: acct,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'identityPub': identityPubB64,
        'onionAddress': onionAddress,
        'name': name,
        'os': os,
        'pairedAt': pairedAt.toIso8601String(),
        if (accountPubB64 != null) 'acct': accountPubB64,
      };

  factory OnionPeer.fromJson(Map<String, dynamic> j) => OnionPeer(
        username: j['username'] as String,
        identityPubB64: j['identityPub'] as String,
        onionAddress: j['onionAddress'] as String,
        name: (j['name'] as String?) ?? 'Onyx user',
        os: (j['os'] as String?) ?? 'unknown',
        pairedAt: DateTime.tryParse(j['pairedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        accountPubB64: j['acct'] as String?,
      );
}

class OnionPairedPeers {
  OnionPairedPeers._();

  static String _key(String account) => 'onion_paired_$account';

  /// In-memory reactive copy for the current account; the UI listens to this.
  static final ValueNotifier<List<OnionPeer>> peers =
      ValueNotifier<List<OnionPeer>>([]);

  static String? _account;

  static String _tombKey(String account) => 'onion_paired_rm_$account';

  /// When each device was unpaired (pub -> ms), so our own other devices
  /// (see OnionTransportService's contact sync) drop it too instead of
  /// handing it back.
  static Map<String, int> _tombs = {};

  static Map<String, int> get tombstones => Map.unmodifiable(_tombs);

  static List<OnionPeer> _decode(List<String> raw) => raw
      .map((s) {
        try {
          return OnionPeer.fromJson(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      })
      .whereType<OnionPeer>()
      .toList();

  static Map<String, int> _decodeTombs(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> load(String username) async {
    _account = username;
    final prefs = await SharedPreferences.getInstance();
    peers.value = _decode(prefs.getStringList(_key(username)) ?? []);
    _tombs = _decodeTombs(prefs.getString(_tombKey(username)));
  }

  static Future<void> _persist() async {
    final account = _account;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(account),
      peers.value.map((p) => jsonEncode(p.toJson())).toList(),
    );
    await prefs.setString(_tombKey(account), jsonEncode(_tombs));
  }

  static bool isTrusted(String username) =>
      peers.value.any((p) => p.username == username);

  /// First paired device for [username], for call sites that only need "is
  /// there one, and what does it look like" (e.g. a display name). A contact
  /// paired from more than one of *their* devices has more than one entry
  /// sharing this username -- see [allByUsername] for anything that needs
  /// to reach all of them.
  static OnionPeer? byUsername(String username) {
    // A contact can have several entries (older pairings under a previous
    // key/address, a second device). The MOST RECENT pairing is the live one;
    // returning the first would pin the UI to a stale entry forever.
    OnionPeer? best;
    for (final p in peers.value) {
      if (p.username != username) continue;
      if (best == null || p.pairedAt.isAfter(best.pairedAt)) best = p;
    }
    return best;
  }

  /// Every paired device for [username]. Onion identity is per-device (each
  /// install generates its own Tor hidden service), so a contact running
  /// Onyx on two devices needs two separate [OnionPeer] entries here, one
  /// per device pubkey/address -- otherwise pairing their second device
  /// would silently evict the first from this list, and sends would only
  /// ever reach whichever device paired most recently.
  static List<OnionPeer> allByUsername(String username) =>
      peers.value.where((p) => p.username == username).toList();

  static OnionPeer? byPub(String identityPubB64) {
    for (final p in peers.value) {
      if (p.identityPubB64 == identityPubB64) return p;
    }
    return null;
  }

  /// Upserts one device's pairing record, keyed by its identity pubkey --
  /// NOT by username. Two devices belonging to the same contact (or two of
  /// our own re-pairs from the same device, e.g. a refreshed name) must
  /// coexist here; only an entry with the exact same pubkey gets replaced.
  static Future<void> add(OnionPeer peer) async {
    // Same pubkey = same device (refresh). Same username AND same onion
    // address with a different pubkey = the same device after a key change
    // (e.g. it adopted a shared account key) — the old record is dead weight
    // and would otherwise shadow the fresh one.
    // A refresh that doesn't know the account key (e.g. a name update) must
    // not lose it.
    final prev = byPub(peer.identityPubB64);
    if (peer.accountPubB64 == null && prev?.accountPubB64 != null) {
      peer = peer.withAccount(prev!.accountPubB64);
    }
    final list = List<OnionPeer>.from(peers.value)
      ..removeWhere((p) =>
          p.identityPubB64 == peer.identityPubB64 ||
          (p.username == peer.username &&
              p.onionAddress == peer.onionAddress));
    list.add(peer);
    peers.value = list;
    await _persist();
  }

  /// Unpairs one specific device (by pubkey) -- not "this username", since
  /// a contact may still have other devices paired that must stay untouched.
  static Future<void> remove(String identityPubB64) async {
    peers.value =
        peers.value.where((p) => p.identityPubB64 != identityPubB64).toList();
    _tombs[identityPubB64] = DateTime.now().millisecondsSinceEpoch;
    await _persist();
  }

  /// Binds [acct] to every listed device of [username] that has no account
  /// key yet.
  static Future<void> bindAccount(
      String username, Iterable<String> pubs, String acct) async {
    final set = pubs.toSet();
    var changed = false;
    final list = [
      for (final p in peers.value)
        if (p.username == username &&
            p.accountPubB64 == null &&
            set.contains(p.identityPubB64))
          (() {
            changed = true;
            return p.withAccount(acct);
          })()
        else
          p,
    ];
    if (!changed) return;
    peers.value = list;
    await _persist();
  }

  /// Merges the contact list of another of OUR devices. Newest wins per
  /// device: a removal newer than our record drops it, a record newer than
  /// our removal (re-added since) comes back. Returns the devices added.
  static Future<List<OnionPeer>> mergeSynced(
      List<OnionPeer> incoming, Map<String, int> tombs) async {
    final list = List<OnionPeer>.from(peers.value);
    var changed = false;
    tombs.forEach((pub, at) {
      if ((_tombs[pub] ?? 0) < at) {
        _tombs[pub] = at;
        changed = true;
      }
      final before = list.length;
      list.removeWhere((p) =>
          p.identityPubB64 == pub && p.pairedAt.millisecondsSinceEpoch < at);
      if (list.length != before) changed = true;
    });
    final added = <OnionPeer>[];
    for (final p in incoming) {
      final i = list.indexWhere((x) => x.identityPubB64 == p.identityPubB64);
      if (i >= 0) {
        if (list[i].accountPubB64 == null && p.accountPubB64 != null) {
          list[i] = list[i].withAccount(p.accountPubB64);
          changed = true;
        }
        continue;
      }
      if ((_tombs[p.identityPubB64] ?? 0) >= p.pairedAt.millisecondsSinceEpoch) {
        continue;
      }
      list.add(p);
      added.add(p);
      changed = true;
    }
    if (!changed) return added;
    peers.value = list;
    await _persist();
    return added;
  }

  /// Adds [incoming] to [account]'s stored contacts without loading it --
  /// for a device being linked, before it ever starts under that account.
  static Future<void> storeForAccount(
      String account, List<OnionPeer> incoming) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getStringList(_key(account)) ?? []);
    for (final p in incoming) {
      if (list.any((x) => x.identityPubB64 == p.identityPubB64)) continue;
      list.add(p);
    }
    await prefs.setStringList(
        _key(account), list.map((p) => jsonEncode(p.toJson())).toList());
    if (_account == account) peers.value = list;
  }
}
