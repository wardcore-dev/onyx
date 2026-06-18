// lib/services/wardlink/wardlink_pending_deletions.dart
//
// Quarantine for *bulk* deletions that arrive over WardLink. When a single sync
// would remove more favourites than the safety threshold, the removals are NOT
// applied automatically — they are parked here and surfaced in the "Recycle
// bin" settings section, where the user explicitly Applies or Keeps them.
//
// This is the safe-by-default half of the mass-delete guard: if the user never
// looks, nothing is deleted (their data stays). Scoped to the current account;
// stored in SharedPreferences.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingBulkDelete {
  final String peerPub;
  final String peerName;
  final Map<String, int> favs; // favId -> deletedAt ms
  final DateTime firstSeen;

  const PendingBulkDelete({
    required this.peerPub,
    required this.peerName,
    required this.favs,
    required this.firstSeen,
  });

  Map<String, dynamic> toJson() => {
        'peerPub': peerPub,
        'peerName': peerName,
        'favs': favs,
        'firstSeen': firstSeen.toIso8601String(),
      };

  factory PendingBulkDelete.fromJson(Map<String, dynamic> j) =>
      PendingBulkDelete(
        peerPub: j['peerPub'] as String,
        peerName: (j['peerName'] as String?) ?? 'device',
        favs: (j['favs'] as Map?)?.map((k, v) =>
                MapEntry('$k', (v as num).toInt())) ??
            <String, int>{},
        firstSeen: DateTime.tryParse(j['firstSeen'] as String? ?? '') ??
            DateTime.now(),
      );
}

class WardLinkPendingDeletions {
  static String _pendingKey(String u) => 'wardlink_pending_del_$u';
  static String _keptKey(String u) => 'wardlink_kept_favs_$u';

  static String? _account;

  /// Quarantined bulk-delete requests awaiting the user's decision.
  static final ValueNotifier<List<PendingBulkDelete>> pending =
      ValueNotifier<List<PendingBulkDelete>>([]);

  /// Favourites the user explicitly chose to keep; never re-deleted by sync.
  static final Set<String> _kept = {};

  static Set<String> get keptFavs => _kept;

  static Future<void> load(String username) async {
    _account = username;
    _kept.clear();
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_pendingKey(username));
      if (raw != null) {
        pending.value = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map(PendingBulkDelete.fromJson)
            .toList();
      } else {
        pending.value = [];
      }
    } catch (_) {
      pending.value = [];
    }
    try {
      _kept.addAll(prefs.getStringList(_keptKey(username)) ?? const []);
    } catch (_) {}
  }

  static Future<void> _persist() async {
    final account = _account;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey(account),
        jsonEncode(pending.value.map((e) => e.toJson()).toList()));
    await prefs.setStringList(_keptKey(account), _kept.toList());
  }

  /// Park (or update) a peer's quarantined bulk-delete request. Multiple syncs
  /// from the same peer merge into one entry.
  static Future<void> record(
      String peerPub, String peerName, Map<String, int> favs) async {
    if (favs.isEmpty) return;
    final list = List<PendingBulkDelete>.from(pending.value);
    final idx = list.indexWhere((e) => e.peerPub == peerPub);
    if (idx >= 0) {
      final merged = {...list[idx].favs, ...favs};
      list[idx] = PendingBulkDelete(
        peerPub: peerPub,
        peerName: peerName,
        favs: merged,
        firstSeen: list[idx].firstSeen,
      );
    } else {
      list.add(PendingBulkDelete(
        peerPub: peerPub,
        peerName: peerName,
        favs: favs,
        firstSeen: DateTime.now(),
      ));
    }
    pending.value = list;
    await _persist();
  }

  /// Remove and return a peer's parked request (the user chose to Apply it).
  static Future<PendingBulkDelete?> take(String peerPub) async {
    final list = List<PendingBulkDelete>.from(pending.value);
    final idx = list.indexWhere((e) => e.peerPub == peerPub);
    if (idx < 0) return null;
    final req = list.removeAt(idx);
    pending.value = list;
    await _persist();
    return req;
  }

  /// Drop a peer's request and mark its favourites as "kept" so the same
  /// deletion is not re-quarantined on the next sync.
  static Future<void> keep(String peerPub) async {
    final req = await take(peerPub);
    if (req == null) return;
    _kept.addAll(req.favs.keys);
    await _persist();
  }

  static Future<void> clearKept() async {
    _kept.clear();
    await _persist();
  }
}
