// lib/services/wardlink/wardlink_paired_devices.dart
//
// The set of devices the user has explicitly trusted for WardLink sync, scoped
// to the currently-logged-in account. Pairing happens once via QR; afterwards a
// device is recognised purely by its pinned identity public key. Public keys
// are not secret, so this lives in SharedPreferences rather than the keychain.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PairedDevice {
  final String deviceId;
  final String identityPubB64;
  final String name;
  final String os;
  final DateTime pairedAt;
  final DateTime? lastSyncAt;
  /// When true, sync pulls the full message history instead of only messages
  /// created after pairing. The user enables this per device in settings.
  final bool syncFromBeginning;

  const PairedDevice({
    required this.deviceId,
    required this.identityPubB64,
    required this.name,
    required this.os,
    required this.pairedAt,
    this.lastSyncAt,
    this.syncFromBeginning = false,
  });

  List<int> get identityPub => base64Decode(identityPubB64);

  PairedDevice copyWith({
    String? name,
    DateTime? lastSyncAt,
    bool? syncFromBeginning,
  }) =>
      PairedDevice(
        deviceId: deviceId,
        identityPubB64: identityPubB64,
        name: name ?? this.name,
        os: os,
        pairedAt: pairedAt,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        syncFromBeginning: syncFromBeginning ?? this.syncFromBeginning,
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'identityPub': identityPubB64,
        'name': name,
        'os': os,
        'pairedAt': pairedAt.toIso8601String(),
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'syncFromBeginning': syncFromBeginning,
      };

  factory PairedDevice.fromJson(Map<String, dynamic> j) => PairedDevice(
        deviceId: j['deviceId'] as String,
        identityPubB64: j['identityPub'] as String,
        name: (j['name'] as String?) ?? 'Device',
        os: (j['os'] as String?) ?? 'unknown',
        pairedAt: DateTime.tryParse(j['pairedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        lastSyncAt: j['lastSyncAt'] != null
            ? DateTime.tryParse(j['lastSyncAt'] as String)
            : null,
        syncFromBeginning: (j['syncFromBeginning'] as bool?) ?? false,
      );
}

class WardLinkPairedDevices {
  static String _key(String username) => 'wardlink_paired_$username';

  /// In-memory reactive copy for the current account; the UI listens to this.
  static final ValueNotifier<List<PairedDevice>> devices =
      ValueNotifier<List<PairedDevice>>([]);

  static String? _account;

  static Future<void> load(String username) async {
    _account = username;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(username)) ?? [];
    devices.value = raw
        .map((s) {
          try {
            return PairedDevice.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PairedDevice>()
        .toList();
  }

  static Future<void> _persist() async {
    final account = _account;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(account),
      devices.value.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }

  static bool isTrusted(String identityPubB64) =>
      devices.value.any((d) => d.identityPubB64 == identityPubB64);

  static PairedDevice? byPub(String identityPubB64) {
    for (final d in devices.value) {
      if (d.identityPubB64 == identityPubB64) return d;
    }
    return null;
  }

  static Future<void> add(PairedDevice device) async {
    final list = List<PairedDevice>.from(devices.value)
      ..removeWhere((d) => d.identityPubB64 == device.identityPubB64);
    list.add(device);
    devices.value = list;
    await _persist();
  }

  static Future<void> remove(String identityPubB64) async {
    devices.value = devices.value
        .where((d) => d.identityPubB64 != identityPubB64)
        .toList();
    await _persist();
  }

  static Future<void> markSynced(String identityPubB64) async {
    devices.value = devices.value
        .map((d) => d.identityPubB64 == identityPubB64
            ? d.copyWith(lastSyncAt: DateTime.now(), syncFromBeginning: false)
            : d)
        .toList();
    await _persist();
  }

  static Future<void> setSyncFromBeginning(
      String identityPubB64, bool value) async {
    devices.value = devices.value
        .map((d) => d.identityPubB64 == identityPubB64
            ? d.copyWith(syncFromBeginning: value)
            : d)
        .toList();
    await _persist();
  }
}
