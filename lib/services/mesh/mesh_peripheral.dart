// lib/services/mesh/mesh_peripheral.dart
//
// Flutter-обёртка над нативным Android BLE GATT-сервером + advertising.
// iOS/macOS — заглушка (можно добавить CBPeripheralManager позже).

import 'dart:io';

import 'package:flutter/services.dart';

/// Incoming packet from the GATT server (peripheral role).
/// [senderAddr] — BLE MAC address of the device that wrote to our inbox.
/// [data]       — raw packet bytes.
typedef MeshIncomingPacket = ({String senderAddr, Uint8List data});

class MeshPeripheral {
  static const _method = MethodChannel('com.wardcore.onyx/mesh_peripheral');
  static const _events = EventChannel('com.wardcore.onyx/mesh_peripheral/events');

  static Stream<MeshIncomingPacket>? _stream;

  /// Incoming BLE packets written to the Inbox characteristic.
  /// Each event carries the sender's BLE MAC address and the raw packet bytes.
  static Stream<MeshIncomingPacket> get incomingPackets {
    _stream ??= _events
        .receiveBroadcastStream()
        .map<MeshIncomingPacket>((raw) {
          final bytes = raw is Uint8List
              ? raw
              : Uint8List.fromList((raw as List).cast<int>());
          if (bytes.length < 2) return (senderAddr: '', data: Uint8List(0));
          final addrLen = bytes[0];
          if (bytes.length < 1 + addrLen) return (senderAddr: '', data: Uint8List(0));
          final senderAddr = String.fromCharCodes(bytes, 1, 1 + addrLen);
          final data = bytes.sublist(1 + addrLen);
          return (senderAddr: senderAddr, data: data);
        })
        .where((e) => e.data.isNotEmpty);
    return _stream!;
  }

  /// Запускает GATT-сервер и BLE-рекламу.
  /// [identity] = pubKey(32 байта) + utf8(username).
  static Future<void> start(Uint8List identity) async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod<void>('start', {'identity': identity});
    } catch (e) {
      // ignore — устройство может не поддерживать peripheral mode
    }
  }

  /// Останавливает рекламу и закрывает GATT-сервер.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Открывает системные настройки геолокации Android (нужно для Android ≤11).
  static Future<void> openLocationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _method.invokeMethod<void>('openLocationSettings');
    } catch (_) {}
  }
}
