// lib/services/mesh/mesh_file_transfer.dart
//
// Chunked file transfer over BLE and UDP mesh transport.
//
// Packet types (binary, all start with 0x4F 0x46):
//   FILE_OFFER  [0x4F 0x46 0x01] recipientHash(16) ephPub(32) ttl(1)
//               transferId(16) payloadLen(4) encrypted{filename,mime,size,chunks}
//   FILE_CHUNK  [0x4F 0x46 0x02] transferId(16) chunkIndex(4) totalChunks(4)
//               dataLen(2) rawChunkData
//   FILE_DONE   [0x4F 0x46 0x03] transferId(16)
//   FILE_REJECT [0x4F 0x46 0x04] transferId(16)
//
// Transport selection:
//   video/* → UDP only (blocked if BLE-only)
//   image/*, audio/* → UDP preferred, BLE fallback
//   BLE size limit: 10 MB
//   UDP size limit: 200 MB

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../enums/delivery_mode.dart';
import '../../enums/mesh_delivery_status.dart';
import '../../models/chat_message.dart';
import 'mesh_crypto.dart';
import 'mesh_neighbor_table.dart';

// Chunk sizes
const int _kBleChunkBytes = 400;    // fits inside GATT MTU after framing
const int _kUdpChunkBytes = 8192;   // safe UDP payload

const int _kMaxFileSizeBle = 10 * 1024 * 1024;   // 10 MB over BLE
const int _kMaxFileSizeUdp = 200 * 1024 * 1024;  // 200 MB over UDP

enum MeshTransferValidationError {
  videoRequiresWifi,
  fileTooLargeForBle,
  fileTooLarge,
}

/// Describes an in-progress inbound transfer.
class _InboundTransfer {
  final String transferId;
  final String filename;
  final String mimeType;
  final int totalBytes;
  final int totalChunks;
  final SecretKey sharedKey;
  final String fromUsername;
  final String? transport;
  final Map<int, Uint8List> chunks = {};

  _InboundTransfer({
    required this.transferId,
    required this.filename,
    required this.mimeType,
    required this.totalBytes,
    required this.totalChunks,
    required this.sharedKey,
    required this.fromUsername,
    this.transport,
  });

  double get progress =>
      totalChunks == 0 ? 0 : chunks.length / totalChunks;

  bool get isComplete => chunks.length >= totalChunks;
}

/// Describes an in-progress outbound transfer.
class _OutboundTransfer {
  final String transferId;
  final Uint8List fileBytes;
  final String filename;
  final String mimeType;
  final MeshNeighbor recipient;
  int chunksSent = 0;

  _OutboundTransfer({
    required this.transferId,
    required this.fileBytes,
    required this.filename,
    required this.mimeType,
    required this.recipient,
  });

  int get chunkSize =>
      recipient.hasUdpAddress ? _kUdpChunkBytes : _kBleChunkBytes;

  int get totalChunks =>
      (fileBytes.length / chunkSize).ceil().clamp(1, 1 << 30);

  double get progress =>
      totalChunks == 0 ? 0 : chunksSent / totalChunks;
}

String _newTransferId() {
  final rng = Random.secure();
  final bytes = Uint8List(16);
  for (int i = 0; i < 16; i++) {
    bytes[i] = rng.nextInt(256);
  }
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

typedef MeshFileSendFn = void Function(Uint8List packet, MeshNeighbor neighbor);
typedef MeshFileMessageFn = void Function(ChatMessage msg);

/// Called for BLE-only neighbors: receives ALL packets (OFFER + CHUNKs + DONE)
/// at once so MeshManager can open one connection and stream them all through.
/// [updateProgress] should be called with 0.0..1.0 as chunks are written.
typedef MeshFileBleTransferFn = void Function(
  List<Uint8List> packets,
  MeshNeighbor neighbor,
  String transferId,
  void Function(double) updateProgress,
);

class MeshFileTransferService {
  MeshFileTransferService._();
  static final MeshFileTransferService instance = MeshFileTransferService._();

  /// Wired by MeshManager — used for UDP (Wi-Fi) only.
  MeshFileSendFn? onSendPacket;

  /// Wired by MeshManager — used for BLE-only neighbors.
  /// Receives all packets pre-built so the manager can open one connection.
  MeshFileBleTransferFn? onSendBleTransfer;

  /// Called when an inbound file transfer completes — delivers synthetic ChatMessage.
  MeshFileMessageFn? onFileReceived;

  final _inbound  = <String, _InboundTransfer>{};
  final _outbound = <String, _OutboundTransfer>{};

  // Inbound transfer timeout: clean up stale transfers after 5 minutes.
  final _inboundTimers = <String, Timer>{};

  /// transferId → 0.0..1.0 progress (both in and out).
  final progress = ValueNotifier<Map<String, double>>({});

  void _updateProgress(String id, double v) {
    final m = Map<String, double>.from(progress.value)..[id] = v;
    progress.value = m;
  }

  void _clearProgress(String id) {
    final m = Map<String, double>.from(progress.value);
    m.remove(id);
    progress.value = m;
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Returns null if OK, or a [MeshTransferValidationError] enum value.
  MeshTransferValidationError? validateTransfer({
    required String mimeType,
    required int fileSize,
    required bool hasUdp,
  }) {
    if (mimeType.startsWith('video/') && !hasUdp) {
      return MeshTransferValidationError.videoRequiresWifi;
    }
    if (!hasUdp && fileSize > _kMaxFileSizeBle) {
      return MeshTransferValidationError.fileTooLargeForBle;
    }
    if (fileSize > _kMaxFileSizeUdp) {
      return MeshTransferValidationError.fileTooLarge;
    }
    return null;
  }

  // ── Outbound ───────────────────────────────────────────────────────────────

  Future<ChatMessage?> sendFile({
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    required MeshNeighbor recipient,
    required String myUsername,
    String? transport, // 'wifi' | 'ble'
  }) async {
    final transferId = _newTransferId();
    final idBytes    = _hexToBytes(transferId);

    final ephKeyPair = await MeshCrypto.generateEphemeralKeyPair();
    final ephPubObj  = await ephKeyPair.extractPublicKey();
    final ephPub     = Uint8List.fromList(ephPubObj.bytes);
    final sharedKey  =
        await MeshCrypto.deriveSharedKeyFrom(ephKeyPair, recipient.publicKey);

    final isBle = !recipient.hasUdpAddress;
    final chunkSize = isBle ? _kBleChunkBytes : _kUdpChunkBytes;
    final totalChunks =
        (fileBytes.length / chunkSize).ceil().clamp(1, 1 << 30);

    final offerPayload = utf8.encode(jsonEncode({
      'transferId': transferId,
      'filename':   filename,
      'mimeType':   mimeType,
      'size':       fileBytes.length,
      'chunks':     totalChunks,
    }));
    final encOffer = await MeshCrypto.encrypt(sharedKey, offerPayload);

    final offerPacket = (BytesBuilder()
          ..add([0x4F, 0x46, 0x01])
          ..add(recipient.keyHash)
          ..add(ephPub)
          ..addByte(4)
          ..add(idBytes)
          ..add(
              (ByteData(4)..setUint32(0, encOffer.length, Endian.big))
                  .buffer
                  .asUint8List())
          ..add(encOffer))
        .toBytes();

    _updateProgress(transferId, 0.0);

    if (isBle && onSendBleTransfer != null) {
      // BLE path: build all packets upfront, hand off to MeshManager which
      // opens one persistent connection and streams them all through.
      final allPackets = _buildBlePackets(
        transferId: transferId,
        idBytes: idBytes,
        fileBytes: fileBytes,
        totalChunks: totalChunks,
        offerPacket: offerPacket,
      );
      onSendBleTransfer!(
        allPackets,
        recipient,
        transferId,
        (p) => _updateProgress(transferId, p),
      );
    } else {
      // UDP path: stream packets as before.
      final transfer = _OutboundTransfer(
        transferId: transferId,
        fileBytes:  fileBytes,
        filename:   filename,
        mimeType:   mimeType,
        recipient:  recipient,
      );
      _outbound[transferId] = transfer;
      onSendPacket?.call(offerPacket, recipient);
      Future.delayed(
        const Duration(milliseconds: 300),
        () => _sendChunksUdp(transferId),
      );
    }

    return ChatMessage(
      id:                  'mf_$transferId',
      from:                myUsername,
      to:                  recipient.username ?? '',
      content:             'MESH_FILE:$filename',
      outgoing:            true,
      delivered:           false,
      deliveryMode:        DeliveryMode.bleMesh,
      meshTransportUsed:   transport,
      meshFileId:          transferId,
      meshFileName:        filename,
      meshFileMimeType:    mimeType,
      meshFileSize:        fileBytes.length,
      meshDeliveryStatus:  MeshDeliveryStatus.sending,
    );
  }

  /// Builds the complete ordered list of BLE packets for one transfer:
  /// [FILE_OFFER, FILE_CHUNK×N, FILE_DONE]
  List<Uint8List> _buildBlePackets({
    required String transferId,
    required Uint8List idBytes,
    required Uint8List fileBytes,
    required int totalChunks,
    required Uint8List offerPacket,
  }) {
    final packets = <Uint8List>[offerPacket];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * _kBleChunkBytes;
      final end   = (start + _kBleChunkBytes).clamp(0, fileBytes.length);
      final chunk = fileBytes.sublist(start, end);

      packets.add((BytesBuilder()
            ..add([0x4F, 0x46, 0x02])
            ..add(idBytes)
            ..add((ByteData(4)..setUint32(0, i, Endian.big)).buffer.asUint8List())
            ..add((ByteData(4)..setUint32(0, totalChunks, Endian.big)).buffer.asUint8List())
            ..add((ByteData(2)..setUint16(0, chunk.length, Endian.big)).buffer.asUint8List())
            ..add(chunk))
          .toBytes());
    }

    packets.add((BytesBuilder()
          ..add([0x4F, 0x46, 0x03])
          ..add(idBytes))
        .toBytes());

    return packets;
  }

  /// UDP-only: stream chunks one by one (original approach for Wi-Fi).
  Future<void> _sendChunksUdp(String transferId) async {
    final transfer = _outbound[transferId];
    if (transfer == null) return;

    final totalChunks = transfer.totalChunks;
    final chunkSize   = transfer.chunkSize;
    final idBytes     = _hexToBytes(transferId);

    for (int i = 0; i < totalChunks; i++) {
      if (!_outbound.containsKey(transferId)) return;

      final start = i * chunkSize;
      final end   = (start + chunkSize).clamp(0, transfer.fileBytes.length);
      final chunk = transfer.fileBytes.sublist(start, end);

      final chunkPacket = (BytesBuilder()
            ..add([0x4F, 0x46, 0x02])
            ..add(idBytes)
            ..add((ByteData(4)..setUint32(0, i, Endian.big)).buffer.asUint8List())
            ..add((ByteData(4)..setUint32(0, totalChunks, Endian.big)).buffer.asUint8List())
            ..add((ByteData(2)..setUint16(0, chunk.length, Endian.big)).buffer.asUint8List())
            ..add(chunk))
          .toBytes();

      onSendPacket?.call(chunkPacket, transfer.recipient);
      transfer.chunksSent = i + 1;
      _updateProgress(transferId, transfer.progress);

      await Future.delayed(const Duration(milliseconds: 5));
    }

    final donePacket = (BytesBuilder()
          ..add([0x4F, 0x46, 0x03])
          ..add(idBytes))
        .toBytes();
    onSendPacket?.call(donePacket, transfer.recipient);
    _outbound.remove(transferId);
    _updateProgress(transferId, 1.0);
    debugPrint('[MeshFile] UDP sent $transferId ($totalChunks chunks)');
  }

  // ── Inbound ────────────────────────────────────────────────────────────────

  Future<void> handlePacket(Uint8List data, String fromUsername, {String? transport}) async {
    if (data.length < 3 || data[0] != 0x4F || data[1] != 0x46) return;

    switch (data[2]) {
      case 0x01:
        await _handleOffer(data, fromUsername, transport: transport);
      case 0x02:
        await _handleChunk(data);
      case 0x03:
        await _handleDone(data);
      case 0x04:
        _handleReject(data);
    }
  }

  Future<void> _handleOffer(Uint8List data, String fromUsername, {String? transport}) async {
    // [3] magic | [16] recipHash | [32] ephPub | [1] ttl |
    // [16] transferId | [4] payloadLen | payload
    if (data.length < 72) return;

    final recipHash = data.sublist(3, 19);
    final myHash    = MeshCrypto.myKeyHash;
    if (!_bytesEqual(recipHash, myHash)) return;

    final ephPub     = data.sublist(19, 51);
    final idBytes    = data.sublist(52, 68);
    final transferId = _bytesToHex(idBytes);
    final payloadLen =
        ByteData.sublistView(data, 68, 72).getUint32(0, Endian.big);
    if (data.length < 72 + payloadLen) return;

    try {
      final sharedKey = await MeshCrypto.deriveSharedKey(ephPub);
      final plain =
          await MeshCrypto.decrypt(sharedKey, data.sublist(72, 72 + payloadLen));
      if (plain == null) return;

      final json        = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      final filename    = json['filename']  as String? ?? 'file';
      final mimeType    = json['mimeType']  as String? ?? 'application/octet-stream';
      final size        = json['size']      as int?    ?? 0;
      final totalChunks = json['chunks']    as int?    ?? 1;

      _inbound[transferId] = _InboundTransfer(
        transferId:   transferId,
        filename:     filename,
        mimeType:     mimeType,
        totalBytes:   size,
        totalChunks:  totalChunks,
        sharedKey:    sharedKey,
        fromUsername: fromUsername,
        transport:    transport,
      );
      _updateProgress(transferId, 0.0);

      // Auto-evict stale inbound transfer if nothing arrives within 5 minutes.
      _inboundTimers[transferId]?.cancel();
      _inboundTimers[transferId] = Timer(const Duration(minutes: 5), () {
        if (_inbound.remove(transferId) != null) {
          _clearProgress(transferId);
          debugPrint('[MeshFile] inbound $transferId timed out — evicted');
        }
        _inboundTimers.remove(transferId);
      });

      debugPrint('[MeshFile] offer: $filename ($size B, $totalChunks chunks)');
    } catch (e) {
      debugPrint('[MeshFile] offer parse error: $e');
    }
  }

  Future<void> _handleChunk(Uint8List data) async {
    // [3] magic | [16] transferId | [4] chunkIndex | [4] totalChunks |
    // [2] dataLen | data
    if (data.length < 29) return;

    final transferId = _bytesToHex(data.sublist(3, 19));
    final chunkIndex =
        ByteData.sublistView(data, 19, 23).getUint32(0, Endian.big);
    final dataLen =
        ByteData.sublistView(data, 27, 29).getUint16(0, Endian.big);
    if (data.length < 29 + dataLen) return;

    final transfer = _inbound[transferId];
    if (transfer == null) return;

    transfer.chunks[chunkIndex] =
        Uint8List.fromList(data.sublist(29, 29 + dataLen));
    _updateProgress(transferId, transfer.progress);
  }

  Future<void> _handleDone(Uint8List data) async {
    if (data.length < 19) return;
    final transferId = _bytesToHex(data.sublist(3, 19));

    _inboundTimers.remove(transferId)?.cancel();
    final transfer = _inbound.remove(transferId);
    if (transfer == null) return;

    if (!transfer.isComplete) {
      final missing = transfer.totalChunks - transfer.chunks.length;
      debugPrint('[MeshFile] done but $missing chunks missing — dropping');
      _clearProgress(transferId);
      return;
    }

    final bb = BytesBuilder();
    for (int i = 0; i < transfer.totalChunks; i++) {
      final chunk = transfer.chunks[i];
      if (chunk == null) {
        _clearProgress(transferId);
        return;
      }
      bb.add(chunk);
    }
    final fileBytes = bb.toBytes();

    final dir = await _meshFilesDir();
    final safe = transfer.filename.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(fileBytes);

    _updateProgress(transferId, 1.0);
    debugPrint('[MeshFile] saved: ${file.path}');

    final msg = ChatMessage(
      id:               'mf_${transferId}_in',
      from:             transfer.fromUsername,
      to:               '',
      content:          'MESH_FILE:${transfer.filename}',
      outgoing:         false,
      delivered:        true,
      deliveryMode:     DeliveryMode.bleMesh,
      meshTransportUsed: transfer.transport,
      meshFileId:       transferId,
      meshFileName:     transfer.filename,
      meshFileMimeType: transfer.mimeType,
      meshFileSize:     transfer.totalBytes,
      meshFileLocalPath: file.path,
    );
    onFileReceived?.call(msg);

    Future.delayed(
      const Duration(seconds: 3),
      () => _clearProgress(transferId),
    );
  }

  void _handleReject(Uint8List data) {
    if (data.length < 19) return;
    final transferId = _bytesToHex(data.sublist(3, 19));
    _outbound.remove(transferId);
    _clearProgress(transferId);
    debugPrint('[MeshFile] $transferId rejected by peer');
  }

  // ── Static helpers ─────────────────────────────────────────────────────────

  static Future<Directory> _meshFilesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/mesh_files');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool isVideo(String? mime) => mime?.startsWith('video/') == true;
  static bool isImage(String? mime) => mime?.startsWith('image/') == true;
  static bool isAudio(String? mime) => mime?.startsWith('audio/') == true;

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
