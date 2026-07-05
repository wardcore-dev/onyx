// lib/services/mesh/mesh_neighbor_table.dart
//
// В-памяти таблица соседних ONYX устройств в BLE Mesh.
// Запись удаляется если устройство не видно >90 секунд.

import 'dart:io';

import 'package:flutter/foundation.dart';

enum MeshTransport { ble, lan }

/// Одна запись в таблице соседей.
class MeshNeighbor {
  final String deviceId;           // BLE device ID или "lan:<username>:<keyHash8>"
  final Uint8List keyHash;         // 16-байтный хэш публичного ключа
  final Uint8List publicKey;       // 32-байтный X25519 публичный ключ
  final String? username;          // @username
  final String? displayName;       // display name
  final int rssi;                  // сила сигнала; для LAN = -55 (условно)
  final DateTime lastSeen;
  final MeshTransport transport;   // откуда обнаружен
  // IP-адрес для UDP-транспорта (только LAN-соседи)
  final InternetAddress? internetAddress;

  const MeshNeighbor({
    required this.deviceId,
    required this.keyHash,
    required this.publicKey,
    this.username,
    this.displayName,
    required this.rssi,
    required this.lastSeen,
    this.transport = MeshTransport.ble,
    this.internetAddress,
  });

  bool get isLan => transport == MeshTransport.lan;
  bool get hasUdpAddress => internetAddress != null;

  MeshNeighbor copyWith({
    String? username,
    String? displayName,
    int? rssi,
    DateTime? lastSeen,
    Uint8List? publicKey,
    MeshTransport? transport,
    InternetAddress? internetAddress,
    bool clearAddress = false,
  }) =>
      MeshNeighbor(
        deviceId: deviceId,
        keyHash: keyHash,
        publicKey: publicKey ?? this.publicKey,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        rssi: rssi ?? this.rssi,
        lastSeen: lastSeen ?? this.lastSeen,
        transport: transport ?? this.transport,
        internetAddress: clearAddress ? null : (internetAddress ?? this.internetAddress),
      );

  /// Уникальный цвет пользователя — берём из MeshCrypto.
  /// Здесь не импортируем напрямую, возвращаем данные для вычисления снаружи.
  String get keyHashHex =>
      keyHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Первая буква для аватара: из displayName, username или первого байта хэша.
  String get avatarLetter {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName![0].toUpperCase();
    }
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }
    return keyHash[0].toRadixString(16).toUpperCase().padLeft(2, '0')[0];
  }

  /// Отображаемое имя для UI.
  String get label => displayName ?? username ?? '@${keyHashHex.substring(0, 8)}';

  /// Расстояние на радаре (0.0 = центр, 1.0 = край).
  double get radarDistance {
    if (isLan) return 0.35; // LAN — всегда во втором круге
    final clamped = rssi.clamp(-90, -40);
    return (clamped + 40).abs() / 50.0;
  }
}

/// Живая таблица BLE соседей. Потокобезопасна для Flutter UI потока.
class MeshNeighborTable extends ChangeNotifier {
  // LAN: UDP broadcast every 8s — evict after 2 missed broadcasts
  static const _ttlLan = Duration(seconds: 20);
  // BLE: scan cycle 15s — allow a couple missed cycles
  static const _ttlBle = Duration(seconds: 50);

  final Map<String, MeshNeighbor> _table = {};

  List<MeshNeighbor> get neighbors => List.unmodifiable(_table.values.toList());

  bool isNearby(String username) =>
      _table.values.any((n) => n.username == username);

  MeshNeighbor? neighborByUsername(String username) {
    // Prefer LAN (UDP/Wi-Fi) over BLE when both are present for the same user.
    MeshNeighbor? ble;
    for (final n in _table.values) {
      if (n.username != username) continue;
      if (n.isLan) return n;
      ble = n;
    }
    return ble;
  }

  /// All neighbors matching [username] — a user can be logged into more than
  /// one device (phone + desktop) at once, each showing up as its own
  /// neighbor entry (keyed by device identity, not just username). Used when
  /// fanning a message out to every device the recipient is currently on.
  List<MeshNeighbor> neighborsByUsername(String username) =>
      _table.values.where((n) => n.username == username).toList();

  MeshNeighbor? neighborByKeyHash(Uint8List hash) =>
      _table.values.cast<MeshNeighbor?>().firstWhere(
        (n) => _hashesEqual(n!.keyHash, hash),
        orElse: () => null,
      );

  /// Добавить или обновить соседа.
  /// LAN (UDP) и BLE записи могут сосуществовать для одного пользователя —
  /// это позволяет использовать Wi-Fi когда он доступен без потери BLE-резерва.
  /// Несколько *разных устройств* с одним и тем же username (напр. телефон +
  /// компьютер с одним аккаунтом) тоже должны сосуществовать — поэтому
  /// дубликаты определяются по keyHash (личность устройства), а не по
  /// username. Удаляем только запись того же физического устройства с
  /// изменившимся deviceId (например у BLE поменялся MAC-адрес).
  void upsert(MeshNeighbor neighbor) {
    final staleKey = _table.entries
        .where((e) =>
            e.key != neighbor.deviceId &&
            e.value.isLan == neighbor.isLan &&
            _hashesEqual(e.value.keyHash, neighbor.keyHash))
        .map((e) => e.key)
        .toList();
    for (final k in staleKey) {
      _table.remove(k);
    }
    _table[neighbor.deviceId] = neighbor;
    notifyListeners();
  }

  /// Обновить RSSI, lastSeen и опционально IP-адрес для существующего соседа.
  void updateSignal(String deviceId, int rssi, {InternetAddress? internetAddress}) {
    final existing = _table[deviceId];
    if (existing == null) return;
    _table[deviceId] = existing.copyWith(
      rssi: rssi,
      lastSeen: DateTime.now(),
      internetAddress: internetAddress,
    );
    notifyListeners();
  }

  /// Удалить соседа по BLE device ID.
  void remove(String deviceId) {
    if (_table.remove(deviceId) != null) notifyListeners();
  }

  /// Удалить всех соседей у которых lastSeen > TTL.
  void evictStale() {
    final now = DateTime.now();
    final stale = _table.entries
        .where((e) {
          final ttl = e.value.isLan ? _ttlLan : _ttlBle;
          return now.difference(e.value.lastSeen) > ttl;
        })
        .map((e) => e.key)
        .toList();
    if (stale.isEmpty) return;
    for (final key in stale) {
      _table.remove(key);
    }
    notifyListeners();
  }

  void clear() {
    _table.clear();
    notifyListeners();
  }

  static bool _hashesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
