// lib/services/mesh/mesh_manager.dart
//
// BLE Mesh transport orchestrator — v2 (true mesh with epidemic routing).
//
// Neighbour discovery:
//   1. UDP broadcast on port 45688 — WiFi/USB-tethering without internet.
//   2. BLE peripheral (GATT server + advertising) + BLE scan.
//
// Routing: Epidemic routing with TTL.
//   Each node relays every unknown packet to all visible neighbours.
//   PacketId deduplication prevents loops.
//   TTL limits blast radius.
//
// Privacy:
//   • Content:           E2E encrypted (XChaCha20-Poly1305 + X25519 ECDH)
//   • Sender identity:   EPHEMERAL key per packet — relay nodes cannot link
//                        packets to a sender's permanent identity.
//   • Recipient identity: SHA-256 truncated keyhash (16 bytes) — permanent
//                         pseudonym, visible to relay nodes. Rotatable in
//                         a future version.
//
// Packet formats:
//   MSG v2  [0x4F 0x4D 0x02] recipientHash(16) ephSenderPub(32) ttl(1)
//           packetId(8) payloadLen(4) encryptedPayload
//   ACK     [0x4F 0x41]      recipientHash(16) ephSenderPub(32) ttl(1)
//           ackPacketId(8) payloadLen(4) encryptedPayload
//   NLIST   [0x4F 0x4E]      senderHash(16) ttl(1) packetId(8)
//           payloadLen(4) payload(JSON, plaintext)
//   HELLO   [0x4F 0x48]      pubKey(32) username(utf8)  — unchanged

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart' as pkg_crypto;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, ValueNotifier;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../enums/delivery_mode.dart';
import '../../enums/mesh_delivery_status.dart';
import '../../managers/lan_message_manager.dart';
import '../../managers/settings_manager.dart';
import '../../models/chat_message.dart';
import '../wardlink/wardlink_identity.dart';
import 'mesh_crypto.dart';
import 'mesh_file_transfer.dart';
import 'mesh_neighbor_table.dart';
import 'mesh_peripheral.dart';

// ── UUIDs ──────────────────────────────────────────────────────────────────

const String kMeshServiceUuid  = '4f4e5958-4d45-5348-0000-000000000001';
const String kIdentityCharUuid = '4f4e5958-4d45-5348-0000-000000000002';
const String kInboxCharUuid    = '4f4e5958-4d45-5348-0000-000000000003';

const int kMeshDiscoveryPort = 45688;

// ── Пакетные константы ─────────────────────────────────────────────────────

const int _kDefaultTtl        = 4;   // макс. хопов для сообщений
const int _kNeighborTtl       = 2;   // макс. хопов для NLIST
const int _kMaxRelayQueue     = 40;  // максимум пакетов на ретрансляцию
const int _kMaxSeenIds        = 600; // дедупликация
const int _kMaxRelayBatch     = 3;   // пакетов за один flush к одному соседу
const int _kAckTimeoutMs      = 15 * 60 * 1000; // 15 минут

// ── MeshManager ────────────────────────────────────────────────────────────

class MeshManager {
  MeshManager._();
  static final MeshManager instance = MeshManager._();

  // ── Публичное состояние ────────────────────────────────────────────────────

  final MeshNeighborTable neighbors = MeshNeighborTable();

  final _incomingCtrl = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get incomingMessages => _incomingCtrl.stream;

  /// Обновления статуса доставки для исходящих mesh-сообщений.
  /// Подписывайся в mesh_chat_screen для обновления пузырьков.
  final _deliveryCtrl =
      StreamController<({String messageId, MeshDeliveryStatus status})>.broadcast();
  Stream<({String messageId, MeshDeliveryStatus status})> get meshDeliveryUpdates =>
      _deliveryCtrl.stream;

  bool get isRunning => _running;
  bool _running = false;

  void onResume() {
    if (!_running) return;
    _broadcastPresence();
    if (_bleAvailable) _doScan();
    debugPrint('[Mesh] onResume — restarted scan + broadcast');
  }

  /// UDP mesh works on all non-web platforms (including Windows/Linux desktop).
  static bool get isPlatformSupported => !kIsWeb;

  /// BLE peripheral+scan only available on Android, iOS, macOS.
  static bool get isBleSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  bool _bleAvailable = false;
  bool get isAvailable => _bleAvailable;

  /// Prompts the OS to turn Bluetooth on (Android only — iOS/macOS don't
  /// allow apps to toggle the adapter programmatically, the caller should
  /// send the user to system settings instead in that case).
  /// Returns true if the adapter is on (or the OS prompt was shown), false
  /// if it's off and we have no way to prompt for it here.
  Future<bool> requestEnableBluetooth() async {
    if (_bleAvailable) return true;
    if (!isBleSupported) return false;
    if (!Platform.isAndroid) return false;
    try {
      await FlutterBluePlus.turnOn();
      return true;
    } catch (e) {
      debugPrint('[Mesh] requestEnableBluetooth error: $e');
      return false;
    }
  }

  // ── Внутреннее состояние ──────────────────────────────────────────────────

  StreamSubscription? _scanSub;
  StreamSubscription? _adapterSub;
  StreamSubscription? _peripheralSub;
  StreamSubscription? _connectivitySub;
  Timer? _evictTimer;
  Timer? _scanCycleTimer;
  Timer? _ackTimeoutTimer;
  Timer? _neighborBroadcastTimer;
  Timer? _udpBroadcastTimer;
  Timer? _fastBleWindowTimer;
  bool _fastBleMode = false;
  RawDatagramSocket? _udpSocket;
  String? _myUsername;
  Uint8List? _identityPayload;
  Set<ConnectivityResult> _prevConnectivity = {};

  final _pendingReads = <String>{};

  // Outbox: прямая очередь (получатель ещё не виден ни одному узлу)
  final _outbox = <({ChatMessage message, String recipient})>[];

  // Relay queue: пакеты на пересылку через mesh
  final _relayQueue = <Uint8List>[];

  // Дедупликация по packetId
  final _seenPacketIds = <int>{};

  // packetId → messageId: ожидаем ACK
  final _pendingAcks = <int, String>{};
  // packetId → sent timestamp (для таймаута)
  final _pendingAckTimes = <int, int>{};

  // Per-device BLE operation queues — serializes all BLE writes per device.
  final _bleQueues = <String, _BleQueue>{};

  // Таблица маршрутизации: keyHash соседа → Set keyHash его соседей
  // Используется для умного relay (Stage 3)
  final _neighborKnowledge = <String, Set<String>>{};

  final locationServicesRequired = ValueNotifier<bool>(false);

  // Low-order counter mixed into packetId so fanning a message out to
  // several neighbors in the same millisecond (multi-device recipient)
  // never produces two packets with the same id.
  int _packetIdCounter = 0;
  int _nextPacketId() =>
      (DateTime.now().millisecondsSinceEpoch << 12) | (_packetIdCounter++ & 0xFFF);

  final _lanManager = LANMessageManager();

  // ── Запуск / Остановка ────────────────────────────────────────────────────

  Future<void> start(String username) async {
    if (_running) return;
    _myUsername = username;
    _running = true;

    if (!kIsWeb) await _startUdpDiscovery();

    if (!kIsWeb) {
      final initial = await Connectivity().checkConnectivity();
      _prevConnectivity = initial.toSet();
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    }

    if (isBleSupported) await _startBle();

    // Wire file transfer service
    MeshFileTransferService.instance.onSendPacket = (packet, neighbor) {
      // UDP path only — BLE is handled by onSendBleTransfer below.
      if (neighbor.hasUdpAddress) {
        _sendViaUdp(packet, neighbor.internetAddress!);
      }
    };
    MeshFileTransferService.instance.onSendBleTransfer =
        (packets, neighbor, transferId, updateProgress) {
      _bleQueue(neighbor.deviceId).add(() async {
        final success =
            await _sendFilePacketsViaBle(packets, neighbor, updateProgress);
        _deliveryCtrl.add((
          messageId: 'mf_$transferId',
          status: success
              ? MeshDeliveryStatus.delivered
              : MeshDeliveryStatus.failed,
        ));
      });
    };
    MeshFileTransferService.instance.onFileReceived = (msg) {
      _incomingCtrl.add(msg);
    };

    _evictTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      neighbors.evictStale();
    });

    _ackTimeoutTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _checkAckTimeouts();
    });

    _neighborBroadcastTimer =
        Timer.periodic(const Duration(seconds: 45), (_) {
      if (_running) _scheduleNeighborListBroadcast();
    });

    debugPrint('[Mesh] started (UDP + BLE). BLE available: $_bleAvailable');
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _bleAvailable = false;

    _udpBroadcastTimer?.cancel();
    _scanCycleTimer?.cancel();
    _fastBleWindowTimer?.cancel();
    _fastBleMode = false;
    _evictTimer?.cancel();
    _ackTimeoutTimer?.cancel();
    _neighborBroadcastTimer?.cancel();
    _adapterSub?.cancel();
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _scanSub?.cancel();
    _scanSub = null;
    await _peripheralSub?.cancel();
    _peripheralSub = null;

    _udpSocket?.close();
    _udpSocket = null;

    await MeshPeripheral.stop();

    try {
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    } catch (_) {}

    neighbors.clear();
    debugPrint('[Mesh] stopped');
  }

  // ── Connectivity ────────────────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_running) return;
    final current = results.toSet();
    final hadWifi = _prevConnectivity.contains(ConnectivityResult.wifi);
    final hasWifi = current.contains(ConnectivityResult.wifi);
    _prevConnectivity = current;

    if (!hadWifi && hasWifi) {
      // WiFi just connected — burst UDP broadcasts so peers discover us fast,
      // even if the peer's UDP listener wasn't bound yet at t=0.
      for (final ms in const [0, 300, 700, 1500, 3000]) {
        Timer(Duration(milliseconds: ms), () { if (_running) _broadcastPresence(); });
      }
      debugPrint('[Mesh] WiFi connected — burst UDP broadcast');
    } else if (hadWifi && !hasWifi) {
      // WiFi just disconnected — evict stale LAN neighbors immediately instead
      // of waiting for the 20-second TTL, then fall back to BLE with a
      // temporarily tightened scan cadence so peers are found fast.
      _evictLanNeighbors();
      if (_bleAvailable) {
        _beginFastBleWindow();
        unawaited(_doScan());
      }
      debugPrint('[Mesh] WiFi disconnected — LAN neighbors evicted, fast BLE scan triggered');
    }
  }

  /// Temporarily tightens the BLE scan cycle (no gap between scans instead
  /// of the normal 2s gap) for a short window after we lose WiFi, so a peer
  /// that's already advertising over BLE gets found within seconds instead
  /// of up to ~12s. Reverts to the normal cadence afterwards to save battery.
  void _beginFastBleWindow() {
    _fastBleMode = true;
    _fastBleWindowTimer?.cancel();
    _fastBleWindowTimer = Timer(const Duration(seconds: 30), () {
      _fastBleMode = false;
      if (_running && _bleAvailable) _startScanCycle();
    });
    _startScanCycle();
  }

  void _evictBleNeighbors() {
    final bleIds = neighbors.neighbors
        .where((n) => !n.isLan)
        .map((n) => n.deviceId)
        .toList();
    for (final id in bleIds) { neighbors.remove(id); }
    if (bleIds.isNotEmpty) {
      debugPrint('[Mesh] Evicted ${bleIds.length} BLE neighbor(s) — BT off');
    }
  }

  void _evictLanNeighbors() {
    final lanIds = neighbors.neighbors
        .where((n) => n.isLan)
        .map((n) => n.deviceId)
        .toList();
    for (final id in lanIds) {
      neighbors.remove(id);
    }
  }

  // ── UDP обнаружение ────────────────────────────────────────────────────────

  Future<void> _startUdpDiscovery() async {
    await _ensureUdpSocket();
    _udpBroadcastTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_running) _broadcastPresence();
    });
  }

  Future<void> _ensureUdpSocket() async {
    if (_udpSocket != null) return;
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kMeshDiscoveryPort,
        reuseAddress: true,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _udpSocket?.receive();
        if (dg != null) _handleUdpPacket(dg);
      });
      debugPrint('[Mesh] UDP discovery started on port $kMeshDiscoveryPort');
      _broadcastPresence();
    } catch (e) {
      debugPrint('[Mesh] UDP discovery error: $e');
    }
  }

  void _broadcastPresence() {
    if (_myUsername == null) return;
    if (_udpSocket == null) {
      unawaited(_ensureUdpSocket());
      return;
    }
    try {
      final payload = utf8.encode(jsonEncode({
        't': 'om',
        'u': _myUsername,
        'pk': base64.encode(MeshCrypto.myPublicKeyBytes),
      }));
      _udpSocket!.send(
          payload, InternetAddress('255.255.255.255'), kMeshDiscoveryPort);
    } catch (e) {
      debugPrint('[Mesh] UDP broadcast error: $e');
      _udpSocket?.close();
      _udpSocket = null;
    }
  }

  void _handleUdpPacket(Datagram datagram) {
    final raw = datagram.data;
    if (raw.isEmpty) return;

    // Binary mesh packet starts with 0x4F ('O'); JSON presence starts with '{' (0x7B)
    if (raw[0] == 0x4F && raw.length > 2) {
      _handleIncomingPacket(Uint8List.fromList(raw),
          senderAddr: 'udp:${datagram.address.address}');
      _flushRelayQueueViaUdp();
      return;
    }

    // JSON presence packet
    try {
      final data = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      if (data['t'] != 'om') return;
      final username = data['u'] as String?;
      if (username == null || username.isEmpty || username == _myUsername) return;
      Uint8List? realPubKey;
      final pkB64 = data['pk'] as String?;
      if (pkB64 != null) {
        try { realPubKey = base64.decode(pkB64); } catch (_) {}
      }
      _upsertLanNeighbor(username, datagram.address, realPubKey: realPubKey);
      if (data['r'] != true) _sendUdpUnicast(datagram.address);
    } catch (_) {}
  }

  void _sendUdpUnicast(InternetAddress target) {
    if (_udpSocket == null || _myUsername == null) return;
    try {
      final payload = utf8.encode(jsonEncode({
        't': 'om',
        'u': _myUsername,
        'r': true,
        'pk': base64.encode(MeshCrypto.myPublicKeyBytes),
      }));
      _udpSocket!.send(payload, target, kMeshDiscoveryPort);
    } catch (e) {
      debugPrint('[Mesh] UDP unicast reply error: $e');
    }
  }

  void _upsertLanNeighbor(String username, InternetAddress address, {Uint8List? realPubKey}) {
    final hash = pkg_crypto.sha256.convert(utf8.encode(username)).bytes;
    final fakePub = realPubKey ?? Uint8List.fromList(hash);
    final fakeKeyHash = realPubKey != null
        ? Uint8List.fromList(pkg_crypto.sha256.convert(realPubKey).bytes.sublist(0, 16))
        : Uint8List.fromList(hash.sublist(0, 16));

    // Include the device's own key hash in the id so two different devices
    // logged into the same username (e.g. phone + desktop) coexist as
    // separate LAN neighbors instead of overwriting each other's IP.
    final deviceId =
        'lan:$username:${fakeKeyHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join().substring(0, 8)}';

    final existing = neighbors.neighbors
        .cast<MeshNeighbor?>()
        .firstWhere((n) => n?.deviceId == deviceId, orElse: () => null);

    if (existing != null) {
      neighbors.updateSignal(deviceId, existing.rssi, internetAddress: address);
    } else {
      neighbors.upsert(MeshNeighbor(
        deviceId: deviceId,
        keyHash: fakeKeyHash,
        publicKey: fakePub,
        username: username,
        rssi: -55,
        lastSeen: DateTime.now(),
        transport: MeshTransport.lan,
        internetAddress: address,
      ));
      debugPrint('[Mesh] LAN neighbor discovered: $username');
    }
  }

  // ── BLE инициализация ─────────────────────────────────────────────────────

  Future<void> _startBle() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      if (Platform.isAndroid) await Permission.bluetoothAdvertise.request();

      if (Platform.isAndroid) {
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdk <= 30) await Permission.locationWhenInUse.request();
      }
    }

    await WardLinkIdentity.ensureLoaded();

    final pubKey = MeshCrypto.myPublicKeyBytes;
    final usernameBytes = utf8.encode(_myUsername ?? '');
    _identityPayload = Uint8List(pubKey.length + usernameBytes.length)
      ..setAll(0, pubKey)
      ..setAll(pubKey.length, usernameBytes);
    await MeshPeripheral.start(_identityPayload!);

    _peripheralSub = MeshPeripheral.incomingPackets.listen((event) {
      _handleIncomingPacket(event.data, senderAddr: event.senderAddr);
    });

    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      _bleAvailable = state == BluetoothAdapterState.on;
      if (_bleAvailable && _running) {
        // Restart peripheral advertising — the OS stops it when BT turns off.
        unawaited(MeshPeripheral.start(_identityPayload!));
        _startScanCycle();
      } else if (!_bleAvailable) {
        // BT turned off — evict BLE neighbors immediately so the UI updates
        // and doesn't show a stale BT connection for up to 50s.
        _evictBleNeighbors();
      }
    });

    final initialState = await FlutterBluePlus.adapterState.first;
    _bleAvailable = initialState == BluetoothAdapterState.on;
    if (_bleAvailable) _startScanCycle();
  }

  // ── BLE сканирование ──────────────────────────────────────────────────────

  void _startScanCycle() {
    _scanCycleTimer?.cancel();
    _doScan();
    // Normal cadence: 12-second cycle (10s scan + 2s gap).
    // Fast cadence (briefly used right after losing WiFi, see
    // _beginFastBleWindow): back-to-back 10s scans with no gap, so a peer
    // that's already advertising is found within one scan instead of
    // waiting out the gap too.
    final cycle = _fastBleMode
        ? const Duration(seconds: 10)
        : const Duration(seconds: 12);
    _scanCycleTimer = Timer.periodic(cycle, (_) {
      if (_running && _bleAvailable) _doScan();
    });
  }

  Future<void> _doScan() async {
    if (!_running || !_bleAvailable) return;

    try {
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.onScanResults.listen(_onScanResult);
      await FlutterBluePlus.startScan(
        withServices: [Guid(kMeshServiceUuid)],
        androidScanMode: AndroidScanMode.lowLatency,
        timeout: const Duration(seconds: 10),
      );
      locationServicesRequired.value = false;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Location services are required') ||
          msg.contains('location')) {
        locationServicesRequired.value = true;
        debugPrint('[Mesh] BLE scan blocked: location services disabled');
      } else {
        debugPrint('[Mesh] BLE scan error: $e');
      }
    }
  }

  void _onScanResult(List<ScanResult> results) {
    for (final r in results) {
      _handleFoundDevice(r.device, r.rssi, r.advertisementData);
    }
  }

  Future<void> _handleFoundDevice(
    BluetoothDevice device,
    int rssi,
    AdvertisementData advData,
  ) async {
    final deviceId = device.remoteId.str;
    if (_pendingReads.contains(deviceId)) return;

    final existing = neighbors.neighbors
        .cast<MeshNeighbor?>()
        .firstWhere((n) => n?.deviceId == deviceId, orElse: () => null);

    if (existing != null) {
      neighbors.updateSignal(deviceId, rssi);
      _flushOutbox();
      await _flushRelayQueueToPeer(device);
      return;
    }

    _pendingReads.add(deviceId);
    await _readIdentity(device, rssi);
    _pendingReads.remove(deviceId);
    _flushOutbox();
  }

  Future<void> _readIdentity(BluetoothDevice device, int rssi) async {
    try {
      await device.connect(timeout: const Duration(seconds: 6));
      final services = await device.discoverServices();

      BluetoothService? meshService;
      for (final s in services) {
        if (s.uuid.str.toLowerCase() == kMeshServiceUuid) {
          meshService = s;
          break;
        }
      }
      if (meshService == null) { await device.disconnect(); return; }

      BluetoothCharacteristic? identityChar;
      BluetoothCharacteristic? inboxChar;
      for (final c in meshService.characteristics) {
        final uuid = c.uuid.str.toLowerCase();
        if (uuid == kIdentityCharUuid) identityChar = c;
        if (uuid == kInboxCharUuid) inboxChar = c;
      }

      if (identityChar == null) { await device.disconnect(); return; }

      final raw = await identityChar.read();
      if (raw.length < 32) { await device.disconnect(); return; }

      final pubKey = Uint8List.fromList(raw.sublist(0, 32));
      final keyHash = MeshCrypto.keyHashFromPub(pubKey);
      final username = raw.length > 32
          ? utf8.decode(raw.sublist(32), allowMalformed: true)
          : null;

      final neighbor = MeshNeighbor(
        deviceId: device.remoteId.str,
        keyHash: keyHash,
        publicKey: pubKey,
        username: username?.isNotEmpty == true ? username : null,
        rssi: rssi,
        lastSeen: DateTime.now(),
      );
      neighbors.upsert(neighbor);
      debugPrint('[Mesh] BLE neighbor found: ${neighbor.label} (${neighbor.rssi} dBm)');

      if (inboxChar != null) {
        if (inboxChar.properties.writeWithoutResponse || inboxChar.properties.write) {
          try {
            final myPub = MeshCrypto.myPublicKeyBytes;
            final myName = utf8.encode(_myUsername ?? '');
            final hello = Uint8List(2 + myPub.length + myName.length)
              ..[0] = 0x4F
              ..[1] = 0x48;
            hello.setAll(2, myPub);
            hello.setAll(2 + myPub.length, myName);
            await inboxChar.write(
                hello, withoutResponse: inboxChar.properties.writeWithoutResponse);
          } catch (e) {
            debugPrint('[Mesh] hello write error: $e');
          }

          // Отправляем накопленные relay-пакеты этому соседу
          await _writeRelayBatch(inboxChar);
        }

        if (inboxChar.properties.notify) {
          await inboxChar.setNotifyValue(true);
          inboxChar.onValueReceived.listen((data) {
            _handleIncomingPacket(Uint8List.fromList(data));
          });
        }
      }

      await device.disconnect();
    } catch (e) {
      debugPrint('[Mesh] identity read error for ${device.remoteId}: $e');
      try { await device.disconnect(); } catch (_) {}
    }
  }

  // ── Relay Queue ───────────────────────────────────────────────────────────

  /// Пересылает накопленные relay-пакеты через уже открытую характеристику.
  Future<void> _writeRelayBatch(BluetoothCharacteristic inboxChar) async {
    if (_relayQueue.isEmpty) return;
    final batch = _relayQueue.take(_kMaxRelayBatch).toList();
    for (final packet in batch) {
      try {
        await inboxChar.write(
            packet, withoutResponse: inboxChar.properties.writeWithoutResponse);
      } catch (_) {}
    }
    // Удаляем только успешно отправленные (упрощённо: удаляем всю batch)
    for (int i = 0; i < batch.length && _relayQueue.isNotEmpty; i++) {
      _relayQueue.removeAt(0);
    }
  }

  /// Подключается к известному соседу только чтобы сбросить relay queue.
  Future<void> _flushRelayQueueToPeer(BluetoothDevice device) async {
    if (_relayQueue.isEmpty) return;
    try {
      await device.connect(timeout: const Duration(seconds: 6));
      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid.str.toLowerCase() != kMeshServiceUuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid.str.toLowerCase() != kInboxCharUuid) continue;
          await _writeRelayBatch(c);
          break;
        }
        break;
      }
      await device.disconnect();
    } catch (_) {
      try { await device.disconnect(); } catch (_) {}
    }
  }

  void _addToRelay(Uint8List packet) {
    if (_relayQueue.length >= _kMaxRelayQueue) {
      _relayQueue.removeAt(0); // вытесняем самый старый
    }
    _relayQueue.add(packet);
  }

  void _addToSeen(int packetId) {
    if (_seenPacketIds.length >= _kMaxSeenIds) {
      _seenPacketIds.remove(_seenPacketIds.first);
    }
    _seenPacketIds.add(packetId);
  }

  // ── UDP отправка ──────────────────────────────────────────────────────────

  /// Отправляет сырой пакет через UDP unicast на IP соседа.
  void _sendViaUdp(Uint8List packet, InternetAddress address) {
    if (_udpSocket == null) return;
    try {
      _udpSocket!.send(packet, address, kMeshDiscoveryPort);
    } catch (e) {
      debugPrint('[Mesh] UDP send error: $e');
    }
  }

  /// Сбрасывает relay queue всем LAN-соседям у которых есть IP.
  void _flushRelayQueueViaUdp() {
    if (_relayQueue.isEmpty || _udpSocket == null) return;
    final lanNeighbors = neighbors.neighbors
        .where((n) => n.isLan && n.internetAddress != null)
        .toList();
    if (lanNeighbors.isEmpty) return;
    final batch = _relayQueue.take(_kMaxRelayBatch).toList();
    for (final n in lanNeighbors) {
      for (final packet in batch) {
        _sendViaUdp(packet, n.internetAddress!);
      }
    }
    for (int i = 0; i < batch.length && _relayQueue.isNotEmpty; i++) {
      _relayQueue.removeAt(0);
    }
  }

  // ── Отправка сообщений ────────────────────────────────────────────────────

  Future<bool> sendMessage(ChatMessage message, String recipientUsername) async {
    // The recipient's username may be logged into more than one device at
    // once (e.g. phone + desktop). We still fan out to every device of
    // theirs we see — but all via the SAME transport, never Wi-Fi to one
    // device and Bluetooth to another in the same send. Mixing transports
    // per-send is what made delivery feel random; picking one keeps it
    // predictable and matches the manual override below.
    final matches = neighbors.neighborsByUsername(recipientUsername);
    final lanTargets = matches.where((n) => n.hasUdpAddress).toList();
    final bleTargets = matches.where((n) => !n.isLan).toList();

    final mode = SettingsManager.meshTransportMode.value; // 'auto'|'wifi'|'ble'
    final useLan = mode == 'wifi'
        ? true
        : mode == 'ble'
            ? false
            : lanTargets.isNotEmpty; // auto: prefer Wi-Fi when any device has it

    bool sentAny = false;

    if (useLan) {
      // Wi-Fi (UDP) — every device of theirs we have an IP for.
      for (final n in lanTargets) {
        message.meshTransportUsed = 'wifi';
        unawaited(_sendViaMeshPacketUdp(message, n));
        sentAny = true;
      }

      // WardLink LAN (для paired devices) — also Wi-Fi based, so only tried
      // when we're not forced into Bluetooth-only mode.
      if (_lanManager.isUserAvailableInLAN(recipientUsername)) {
        final lanMsg = ChatMessage(
          id: message.id,
          from: message.from,
          to: message.to,
          content: message.content,
          outgoing: true,
          delivered: false,
          time: message.time,
          replyToId: message.replyToId,
          replyToSender: message.replyToSender,
          replyToContent: message.replyToContent,
          deliveryMode: DeliveryMode.bleMesh,
        );
        final wardlinkSent =
            await _lanManager.sendMessage(lanMsg, recipientUsername);
        sentAny = wardlinkSent || sentAny;
      }
    } else {
      // Bluetooth — every device only reachable this way, enqueued
      // per-device so it doesn't conflict with file transfers.
      for (final n in bleTargets) {
        message.meshTransportUsed = 'ble';
        _bleQueue(n.deviceId).add(() => _sendViaBle(message, n));
        sentAny = true;
      }
    }

    if (sentAny) return true;

    // Out of range — put in outbox, mesh relay will try to carry it
    final alreadyQueued = _outbox.any((e) => e.message.id == message.id);
    if (!alreadyQueued) {
      _outbox.add((message: message, recipient: recipientUsername));
      debugPrint(
          '[Mesh] $recipientUsername out of range — queued (outbox: ${_outbox.length})');
    }
    return true;
  }

  /// Отправляет зашифрованный mesh-пакет через UDP unicast.
  Future<bool> _sendViaMeshPacketUdp(
      ChatMessage message, MeshNeighbor recipient) async {
    final ephKeyPair = await MeshCrypto.generateEphemeralKeyPair();
    final ephPubObj = await ephKeyPair.extractPublicKey();
    final ephPub = Uint8List.fromList(ephPubObj.bytes);

    final sharedKey =
        await MeshCrypto.deriveSharedKeyFrom(ephKeyPair, recipient.publicKey);

    final packetId = _nextPacketId();

    final payloadBytes = utf8.encode(jsonEncode({
      'from': message.from,
      'fromPub': base64.encode(MeshCrypto.myPublicKeyBytes),
      'content': message.content,
      'time': message.time.millisecondsSinceEpoch,
      'id': message.id,
      if (message.replyToId != null) 'replyToId': message.replyToId,
      if (message.replyToSender != null) 'replyToSender': message.replyToSender,
      if (message.replyToContent != null) 'replyToContent': message.replyToContent,
    }));

    final encrypted = await MeshCrypto.encrypt(sharedKey, payloadBytes);
    final packet = _buildMsgPacket(
      recipientHash: Uint8List.fromList(recipient.keyHash),
      ephPub: ephPub,
      packetId: packetId,
      encryptedPayload: encrypted,
    );

    _pendingAcks[packetId] = message.id;
    _pendingAckTimes[packetId] = DateTime.now().millisecondsSinceEpoch;
    message.meshPacketId = packetId;

    _addToSeen(packetId);
    _sendViaUdp(packet, recipient.internetAddress!);
    debugPrint('[Mesh] UDP send OK: ${recipient.label}');
    return true;
  }

  void _flushOutbox() {
    if (_outbox.isEmpty) return;
    final toSend = _outbox
        .where((e) =>
            neighbors.neighborByUsername(e.recipient) != null ||
            _lanManager.isUserAvailableInLAN(e.recipient))
        .toList();
    for (final entry in toSend) {
      _outbox.remove(entry);
      debugPrint('[Mesh] flushing queued message to ${entry.recipient}');
      unawaited(sendMessage(entry.message, entry.recipient));
    }
  }

  // ── BLE отправка (v2 — эфемерный ключ отправителя) ────────────────────────

  Future<void> _sendViaBle(ChatMessage message, MeshNeighbor recipient) async {
    // Генерируем одноразовую keypair — relay-узлы не видят личность отправителя
    final ephKeyPair = await MeshCrypto.generateEphemeralKeyPair();
    final ephPubObj = await ephKeyPair.extractPublicKey();
    final ephPub = Uint8List.fromList(ephPubObj.bytes);

    // Шифруем: ECDH(ephPriv, recipientPermanentPub)
    final sharedKey =
        await MeshCrypto.deriveSharedKeyFrom(ephKeyPair, recipient.publicKey);

    final packetId = _nextPacketId();

    final payloadBytes = utf8.encode(jsonEncode({
      'from': message.from,
      // Постоянный публичный ключ отправителя — только получатель увидит
      'fromPub': base64.encode(MeshCrypto.myPublicKeyBytes),
      'content': message.content,
      'time': message.time.millisecondsSinceEpoch,
      'id': message.id,
      if (message.replyToId != null) 'replyToId': message.replyToId,
      if (message.replyToSender != null) 'replyToSender': message.replyToSender,
      if (message.replyToContent != null) 'replyToContent': message.replyToContent,
    }));

    final encrypted = await MeshCrypto.encrypt(sharedKey, payloadBytes);
    final packet = _buildMsgPacket(
      recipientHash: Uint8List.fromList(recipient.keyHash),
      ephPub: ephPub,
      packetId: packetId,
      encryptedPayload: encrypted,
    );

    // Запоминаем для ACK
    _pendingAcks[packetId] = message.id;
    _pendingAckTimes[packetId] = DateTime.now().millisecondsSinceEpoch;

    // Обновляем meshPacketId в сообщении чтобы UI мог сопоставить ACK
    message.meshPacketId = packetId;

    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 1500));
        debugPrint('[Mesh] BLE send retry (attempt 2): ${recipient.label}');
      }
      try {
        final device = BluetoothDevice.fromId(recipient.deviceId);
        await device.connect(timeout: const Duration(seconds: 8));
        final services = await device.discoverServices();

        for (final s in services) {
          if (s.uuid.str.toLowerCase() != kMeshServiceUuid) continue;
          for (final c in s.characteristics) {
            if (c.uuid.str.toLowerCase() != kInboxCharUuid) continue;
            await c.write(packet, withoutResponse: true);
            // Заодно сбрасываем relay queue
            await _writeRelayBatch(c);
            await device.disconnect();
            debugPrint('[Mesh] BLE send OK v2: ${recipient.label}');
            return;
          }
        }
        await device.disconnect();
      } catch (e) {
        debugPrint('[Mesh] BLE send error (attempt ${attempt + 1}): $e');
        try {
          await BluetoothDevice.fromId(recipient.deviceId).disconnect();
        } catch (_) {}
      }
    }

    // Прямая доставка не удалась — кладём в relay queue
    // Другие узлы понесут пакет дальше
    _addToSeen(packetId);
    _addToRelay(packet);
    debugPrint('[Mesh] direct BLE failed — added to relay queue');
  }

  // ── ACK ───────────────────────────────────────────────────────────────────

  Future<void> _sendAck(int originalPacketId, List<int> senderPermPubBytes) async {
    try {
      final ephKeyPair = await MeshCrypto.generateEphemeralKeyPair();
      final ephPubObj = await ephKeyPair.extractPublicKey();
      final ephPub = Uint8List.fromList(ephPubObj.bytes);

      final sharedKey =
          await MeshCrypto.deriveSharedKeyFrom(ephKeyPair, senderPermPubBytes);
      final payloadBytes =
          utf8.encode(jsonEncode({'ackFor': originalPacketId}));
      final encrypted = await MeshCrypto.encrypt(sharedKey, payloadBytes);

      final senderKeyHash = MeshCrypto.keyHashFromPub(senderPermPubBytes);
      final ackId = DateTime.now().millisecondsSinceEpoch ^ 0x1;

      final bb = BytesBuilder()
        ..add([0x4F, 0x41])
        ..add(senderKeyHash)
        ..add(ephPub)
        ..addByte(_kDefaultTtl)
        ..add((ByteData(8)..setInt64(0, ackId, Endian.big)).buffer.asUint8List())
        ..add((ByteData(4)..setUint32(0, encrypted.length, Endian.big))
            .buffer
            .asUint8List())
        ..add(encrypted);

      final ackPacket = bb.toBytes();
      _addToSeen(ackId);
      _addToRelay(ackPacket); // ACK тоже путешествует через mesh
      debugPrint('[Mesh] ACK queued for relay (ackFor=$originalPacketId)');
    } catch (e) {
      debugPrint('[Mesh] _sendAck error: $e');
    }
  }

  void _checkAckTimeouts() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = _pendingAcks.keys
        .where((id) => (now - (_pendingAckTimes[id] ?? now)) > _kAckTimeoutMs)
        .toList();
    for (final id in expired) {
      final msgId = _pendingAcks.remove(id);
      _pendingAckTimes.remove(id);
      if (msgId != null) {
        debugPrint('[Mesh] ACK timeout for packetId=$id msgId=$msgId');
        _deliveryCtrl.add(
            (messageId: msgId, status: MeshDeliveryStatus.failed));
      }
    }
  }

  // ── Построение пакетов ────────────────────────────────────────────────────

  /// MSG v2: [0x4F 0x4D 0x02] recipientHash(16) ephPub(32) ttl(1) id(8) len(4) payload
  Uint8List _buildMsgPacket({
    required Uint8List recipientHash,
    required Uint8List ephPub,
    required int packetId,
    required Uint8List encryptedPayload,
    int ttl = _kDefaultTtl,
  }) {
    final bb = BytesBuilder()
      ..add([0x4F, 0x4D, 0x02])
      ..add(recipientHash)
      ..add(ephPub)
      ..addByte(ttl)
      ..add((ByteData(8)..setInt64(0, packetId, Endian.big)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, encryptedPayload.length, Endian.big))
          .buffer
          .asUint8List())
      ..add(encryptedPayload);
    return bb.toBytes();
  }

  // ── Обработка входящих пакетов ────────────────────────────────────────────

  Future<void> _handleIncomingPacket(Uint8List data,
      {String? senderAddr}) async {
    if (data.length < 2) return;

    // FILE_* packets — routed to MeshFileTransferService
    if (data[0] == 0x4F && data[1] == 0x46) {
      final from = _senderUsernameFromAddr(senderAddr);
      final transport = senderAddr?.startsWith('udp:') == true ? 'wifi' : 'ble';
      unawaited(MeshFileTransferService.instance.handlePacket(data, from, transport: transport));
      return;
    }

    // HELLO packet (unchanged)
    if (data[0] == 0x4F && data[1] == 0x48) {
      _handleHello(data, senderAddr);
      return;
    }

    // ACK packet
    if (data[0] == 0x4F && data[1] == 0x41) {
      await _handleAck(data);
      return;
    }

    // NLIST — neighbour exchange
    if (data[0] == 0x4F && data[1] == 0x4E) {
      _handleNeighborList(data);
      return;
    }

    // MSG v2
    if (data.length >= 64 &&
        data[0] == 0x4F &&
        data[1] == 0x4D &&
        data[2] == 0x02) {
      await _handleMsgV2(data, senderAddr);
      return;
    }

    // MSG v1 (legacy, backward compat — read-only, не relay)
    if (data.length >= 63 && data[0] == 0x4F && data[1] == 0x4D) {
      await _handleMsgV1(data, senderAddr);
      return;
    }
  }

  // ── Hello ─────────────────────────────────────────────────────────────────

  void _handleHello(Uint8List data, String? senderAddr) {
    if (data.length < 34) return;
    final pubKey = Uint8List.fromList(data.sublist(2, 34));
    final username = data.length > 34
        ? utf8.decode(data.sublist(34), allowMalformed: true)
        : null;
    if (username == null || username.isEmpty) return;

    final keyHash = MeshCrypto.keyHashFromPub(pubKey);
    final deviceId = senderAddr?.isNotEmpty == true
        ? senderAddr!
        : 'ble:${pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    // Always upsert so that the real MAC (senderAddr) replaces any stale
    // 'ble:pubkey' fallback deviceId — critical for _senderUsernameFromAddr.
    neighbors.upsert(MeshNeighbor(
      deviceId: deviceId,
      keyHash: keyHash,
      publicKey: pubKey,
      username: username,
      rssi: -70,
      lastSeen: DateTime.now(),
    ));
    debugPrint('[Mesh] hello received from $username — upserted neighbor');
  }

  // ── MSG v2 ────────────────────────────────────────────────────────────────

  Future<void> _handleMsgV2(Uint8List data, String? senderAddr) async {
    // Layout: [3] magic+ver | [16] recipHash | [32] ephPub | [1] ttl |
    //         [8] packetId  | [4] payloadLen | [N] payload
    final recipientHash = data.sublist(3, 19);
    final ephSenderPub  = data.sublist(19, 51);
    final ttl           = data[51];
    final packetId      = ByteData.sublistView(data, 52, 60).getInt64(0, Endian.big);
    final payloadLen    = ByteData.sublistView(data, 60, 64).getUint32(0, Endian.big);
    if (data.length < 64 + payloadLen) return;

    // Дедупликация
    if (_seenPacketIds.contains(packetId)) return;
    _addToSeen(packetId);

    final myHash = MeshCrypto.myKeyHash;
    final isForUs = _bytesEqual(recipientHash, myHash);

    if (!isForUs) {
      // Relay: кладём в очередь с уменьшенным TTL
      if (ttl > 0) {
        final relay = Uint8List.fromList(data);
        relay[51] = ttl - 1;
        _addToRelay(relay);
        debugPrint('[Mesh] relaying MSG v2 (ttl=${ttl - 1})');
      }
      return;
    }

    // Пакет для нас — расшифровываем
    final encryptedPayload = data.sublist(64, 64 + payloadLen);
    try {
      // ECDH(myPermanentPriv, ephSenderPub)
      final sharedKey = await MeshCrypto.deriveSharedKey(ephSenderPub);
      final plainBytes = await MeshCrypto.decrypt(sharedKey, encryptedPayload);
      if (plainBytes == null) return;

      final json = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
      final fromPubB64 = json['fromPub'] as String?;

      final msg = ChatMessage(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        from: json['from']?.toString() ?? '',
        to: _myUsername ?? '',
        content: json['content']?.toString() ?? '',
        outgoing: false,
        delivered: true,
        isRead: false,
        time: json['time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['time'] as int)
            : DateTime.now(),
        deliveryMode: DeliveryMode.bleMesh,
        replyToId: json['replyToId'] as int?,
        replyToSender: json['replyToSender'] as String?,
        replyToContent: json['replyToContent'] as String?,
        meshTransportUsed: (senderAddr?.startsWith('udp:') == true) ? 'wifi' : 'ble',
      );

      // Добавляем отправителя как соседа (reverse discovery)
      if (fromPubB64 != null) {
        final senderPub = base64.decode(fromPubB64);
        _upsertBleNeighborFromPacket(senderPub, msg.from, senderAddr);
        // Шлём ACK обратно через mesh
        await _sendAck(packetId, senderPub);
      }

      _incomingCtrl.add(msg);
    } catch (e) {
      debugPrint('[Mesh] MSG v2 decrypt error: $e');
    }
  }

  // ── ACK ───────────────────────────────────────────────────────────────────

  Future<void> _handleAck(Uint8List data) async {
    // Layout: [2] magic | [16] recipHash | [32] ephPub | [1] ttl |
    //         [8] ackId | [4] payloadLen | [N] payload
    if (data.length < 63) return;

    final recipientHash = data.sublist(2, 18);
    final ephPub        = data.sublist(18, 50);
    final ttl           = data[50];
    final ackId         = ByteData.sublistView(data, 51, 59).getInt64(0, Endian.big);
    final payloadLen    = ByteData.sublistView(data, 59, 63).getUint32(0, Endian.big);
    if (data.length < 63 + payloadLen) return;

    if (_seenPacketIds.contains(ackId)) return;
    _addToSeen(ackId);

    final myHash = MeshCrypto.myKeyHash;
    final isForUs = _bytesEqual(recipientHash, myHash);

    if (!isForUs) {
      if (ttl > 0) {
        final relay = Uint8List.fromList(data);
        relay[50] = ttl - 1;
        _addToRelay(relay);
      }
      return;
    }

    final encryptedPayload = data.sublist(63, 63 + payloadLen);
    try {
      final sharedKey = await MeshCrypto.deriveSharedKey(ephPub);
      final plainBytes = await MeshCrypto.decrypt(sharedKey, encryptedPayload);
      if (plainBytes == null) return;

      final json = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
      final ackFor = json['ackFor'];
      final originalPacketId =
          ackFor is int ? ackFor : int.tryParse(ackFor.toString());
      if (originalPacketId == null) return;

      final msgId = _pendingAcks.remove(originalPacketId);
      _pendingAckTimes.remove(originalPacketId);
      if (msgId != null) {
        debugPrint('[Mesh] ACK received for msgId=$msgId');
        _deliveryCtrl.add(
            (messageId: msgId, status: MeshDeliveryStatus.delivered));
      }
    } catch (e) {
      debugPrint('[Mesh] ACK decrypt error: $e');
    }
  }

  // ── NLIST — обмен таблицами соседей (Stage 3) ─────────────────────────────

  void _scheduleNeighborListBroadcast() {
    if (neighbors.neighbors.isEmpty) return;

    final myNeighborHashes = neighbors.neighbors
        .map((n) => base64.encode(n.keyHash))
        .toList();

    final payloadBytes =
        utf8.encode(jsonEncode({'neighbors': myNeighborHashes}));

    final packetId =
        DateTime.now().millisecondsSinceEpoch | 0x8000000000000000;
    if (_seenPacketIds.contains(packetId)) return;
    _addToSeen(packetId);

    final bb = BytesBuilder()
      ..add([0x4F, 0x4E])
      ..add(MeshCrypto.myKeyHash)
      ..addByte(_kNeighborTtl)
      ..add((ByteData(8)..setInt64(0, packetId, Endian.big)).buffer.asUint8List())
      ..add((ByteData(4)..setUint32(0, payloadBytes.length, Endian.big))
          .buffer
          .asUint8List())
      ..add(payloadBytes);

    _addToRelay(bb.toBytes());
  }

  void _handleNeighborList(Uint8List data) {
    // Layout: [2] magic | [16] senderHash | [1] ttl | [8] packetId |
    //         [4] payloadLen | [N] payload (JSON plaintext)
    if (data.length < 31) return;

    final senderHash = data.sublist(2, 18);
    final ttl        = data[18];
    final packetId   = ByteData.sublistView(data, 19, 27).getInt64(0, Endian.big);
    final payloadLen = ByteData.sublistView(data, 27, 31).getUint32(0, Endian.big);
    if (data.length < 31 + payloadLen) return;

    if (_seenPacketIds.contains(packetId)) return;
    _addToSeen(packetId);

    try {
      final json = jsonDecode(
              utf8.decode(data.sublist(31, 31 + payloadLen)))
          as Map<String, dynamic>;
      final hashes = (json['neighbors'] as List).cast<String>();
      _neighborKnowledge[base64.encode(senderHash)] = Set.from(hashes);
      debugPrint(
          '[Mesh] NLIST from ${base64.encode(senderHash)}: ${hashes.length} neighbors');

      // Relay NLIST с уменьшенным TTL
      if (ttl > 0) {
        final relay = Uint8List.fromList(data);
        relay[18] = ttl - 1;
        _addToRelay(relay);
      }
    } catch (e) {
      debugPrint('[Mesh] NLIST parse error: $e');
    }
  }

  // ── MSG v1 (legacy) ───────────────────────────────────────────────────────

  Future<void> _handleMsgV1(Uint8List data, String? senderAddr) async {
    if (data.length < 63) return;

    final recipientHash = data.sublist(2, 18);
    final myHash = MeshCrypto.myKeyHash;
    if (!_bytesEqual(recipientHash, myHash)) return; // v1 не relay-им

    final senderPub = data.sublist(18, 50);
    if (data[50] == 0) return;

    final payloadLength =
        ByteData.sublistView(data, 59, 63).getUint32(0, Endian.big);
    if (data.length < 63 + payloadLength) return;

    final encryptedPayload = data.sublist(63, 63 + payloadLength);
    try {
      final sharedKey = await MeshCrypto.deriveSharedKey(senderPub);
      final plainBytes = await MeshCrypto.decrypt(sharedKey, encryptedPayload);
      if (plainBytes == null) return;

      final json =
          jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;
      final msg = ChatMessage(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        from: json['from']?.toString() ?? '',
        to: _myUsername ?? '',
        content: json['content']?.toString() ?? '',
        outgoing: false,
        delivered: true,
        isRead: false,
        time: json['time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['time'] as int)
            : DateTime.now(),
        deliveryMode: DeliveryMode.bleMesh,
        replyToId: json['replyToId'] as int?,
        replyToSender: json['replyToSender'] as String?,
        replyToContent: json['replyToContent'] as String?,
      );

      if (senderAddr != null && senderAddr.isNotEmpty && msg.from.isNotEmpty) {
        _upsertBleNeighborFromPacket(senderPub, msg.from, senderAddr);
      }

      _incomingCtrl.add(msg);
    } catch (e) {
      debugPrint('[Mesh] MSG v1 decrypt error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _upsertBleNeighborFromPacket(
      List<int> pubKey, String username, String? deviceId) {
    if (username.isEmpty) return;
    final keyHash = MeshCrypto.keyHashFromPub(pubKey);
    final id = deviceId?.isNotEmpty == true
        ? deviceId!
        : 'ble:${pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

    final existing = neighbors.neighbors
        .cast<MeshNeighbor?>()
        .firstWhere((n) => n?.deviceId == id, orElse: () => null);
    if (existing == null) {
      neighbors.upsert(MeshNeighbor(
        deviceId: id,
        keyHash: keyHash,
        publicKey: Uint8List.fromList(pubKey),
        username: username,
        rssi: -70,
        lastSeen: DateTime.now(),
      ));
    } else {
      neighbors.updateSignal(id, existing.rssi);
    }
  }

  /// Resolves a sender's username from their BLE MAC or LAN device ID / UDP addr.
  String _senderUsernameFromAddr(String? addr) {
    if (addr == null || addr.isEmpty) return '';
    // BLE: deviceId match
    final byId = neighbors.neighbors
        .cast<MeshNeighbor?>()
        .firstWhere((n) => n?.deviceId == addr, orElse: () => null);
    if (byId != null) return byId.username ?? '';
    // UDP: addr is 'udp:<IP>' — match by internetAddress
    if (addr.startsWith('udp:')) {
      final ip = addr.substring(4);
      final byIp = neighbors.neighbors
          .cast<MeshNeighbor?>()
          .firstWhere((n) => n?.internetAddress?.address == ip, orElse: () => null);
      return byIp?.username ?? '';
    }
    return '';
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Отправка сообщения через LAN ──────────────────────────────────────────

  int get outboxCount => _outbox.length;
  String? get myUsername => _myUsername;

  // ── BLE per-device queue ──────────────────────────────────────────────────

  _BleQueue _bleQueue(String deviceId) =>
      _bleQueues.putIfAbsent(deviceId, () => _BleQueue());

  // ── BLE file transfer (persistent connection) ─────────────────────────────

  /// Opens one BLE connection to [neighbor], writes all [packets] in order
  /// (OFFER + CHUNKs + DONE), then disconnects. Retries once on failure.
  Future<bool> _sendFilePacketsViaBle(
    List<Uint8List> packets,
    MeshNeighbor neighbor,
    void Function(double) updateProgress,
  ) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('[Mesh] BLE file retry (attempt 2): ${neighbor.label}');
      }
      BluetoothDevice? device;
      try {
        device = BluetoothDevice.fromId(neighbor.deviceId);
        await device.connect(timeout: const Duration(seconds: 10));

        // Request the largest MTU the OS allows (512 bytes).
        // This increases effective throughput from ~23B → ~512B per write.
        try { await device.requestMtu(512); } catch (_) {}

        final services = await device.discoverServices();
        BluetoothCharacteristic? inboxChar;
        for (final s in services) {
          if (s.uuid.str.toLowerCase() != kMeshServiceUuid) continue;
          for (final c in s.characteristics) {
            if (c.uuid.str.toLowerCase() == kInboxCharUuid) {
              inboxChar = c;
              break;
            }
          }
          if (inboxChar != null) break;
        }
        if (inboxChar == null) {
          await device.disconnect();
          return false;
        }

        // Send HELLO first so the recipient knows our username before the
        // FILE_OFFER arrives. Without this, _senderUsernameFromAddr returns ''
        // and the received file is stored under the wrong chatId.
        try {
          final myPub = MeshCrypto.myPublicKeyBytes;
          final myName = utf8.encode(_myUsername ?? '');
          final hello = Uint8List(2 + myPub.length + myName.length)
            ..[0] = 0x4F
            ..[1] = 0x48;
          hello.setAll(2, myPub);
          hello.setAll(2 + myPub.length, myName);
          await inboxChar.write(hello, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          debugPrint('[Mesh] file-pre-hello error (non-fatal): $e');
        }

        final total = packets.length;

        for (int i = 0; i < total; i++) {
          // Give the receiver ~350 ms after the OFFER to finish ECDH key
          // derivation before the first chunk arrives. Without this delay,
          // chunks race ahead of _handleOffer and are silently dropped.
          if (i == 1) await Future.delayed(const Duration(milliseconds: 350));

          // The peripheral inbox characteristic only advertises WRITE_NO_RESPONSE.
          // Attempting a confirmed write (withoutResponse: false) on such a
          // characteristic throws and kills the entire transfer. Always use WWR.
          await inboxChar.write(packets[i], withoutResponse: true);

          // Drain the Android BLE TX buffer every 20 packets with a longer
          // pause; otherwise back-pressure builds and the peripheral drops writes.
          if ((i + 1) % 20 == 0) {
            await Future.delayed(const Duration(milliseconds: 80));
          } else {
            await Future.delayed(const Duration(milliseconds: 10));
          }

          updateProgress((i + 1) / total);
        }

        // Also flush any pending relay packets while we have the connection.
        // File data is fully delivered. Relay flush + disconnect are best-effort:
        // a failure here must NOT mark the transfer as failed.
        try { await _writeRelayBatch(inboxChar); } catch (e) {
          debugPrint('[Mesh] post-file relay error (non-fatal): $e');
        }
        try { await device.disconnect(); } catch (e) {
          debugPrint('[Mesh] post-file disconnect error (non-fatal): $e');
        }
        debugPrint('[Mesh] BLE file done: ${packets.length} packets → ${neighbor.label}');
        return true;
      } catch (e) {
        debugPrint('[Mesh] BLE file error (attempt ${attempt + 1}): $e');
        try { await device?.disconnect(); } catch (_) {}
      }
    }
    debugPrint('[Mesh] BLE file transfer failed after 2 attempts: ${neighbor.label}');
    return false;
  }
}

// ── BLE per-device operation queue ────────────────────────────────────────────
// Serializes all BLE writes to a single device by chaining Futures.
// Text messages and file transfers for the same device never overlap.

class _BleQueue {
  Future<void> _tail = Future.value();

  void add(Future<void> Function() task) {
    _tail = _tail.then((_) => task()).catchError((_) {});
  }
}
