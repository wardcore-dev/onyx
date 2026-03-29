// lib/managers/lan_message_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import '../models/chat_message.dart';

class LANMessageManager {
  static final LANMessageManager _instance = LANMessageManager._internal();
  factory LANMessageManager() => _instance;
  LANMessageManager._internal();

  static const int discoveryPort = 45678;
  static const int messagePort   = 45679;

  static const int _pubKeyLen = 32; 
  static const int _nonceLen  = 12; 
  static const int _macLen    = 16; 

  RawDatagramSocket? _discoverySocket;
  RawDatagramSocket? _messageSocket;

  final Map<String, InternetAddress> _discoveredDevices = {};

  final Map<String, List<int>> _peerPubKeys = {};

  Function(ChatMessage)? onMessageReceived;
  Function(String, String, Uint8List, String, String, Map<String, dynamic>?)? onMediaReceived;
  // Called when a peer's key changes after first contact (possible MITM).
  // username — whose key changed, fingerprint — SHA-256 prefix of the NEW key.
  Function(String username, String fingerprint)? onKeyMismatch;

  final Map<String, Map<int, String>> _chunkBuffers  = {};
  final Map<String, Map<String, dynamic>> _chunkMetadata = {};

  final _x25519  = X25519();
  final _aesGcm  = AesGcm.with256bits();

  SimpleKeyPair? _ephemeralKeyPair;
  List<int>?     _ephemeralPubKeyBytes; 

  bool _isInitialized = false;

  String _fingerprintOf(List<int> keyBytes) {
    final digest = dart_crypto.sha256.convert(keyBytes).bytes;
    return digest.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  /// Returns a short fingerprint of the known public key for [username],
  /// or null if the key is not yet cached.
  String? getKeyFingerprint(String username) {
    final key = _peerPubKeys[username];
    return key == null ? null : _fingerprintOf(key);
  }

  List<int> _hkdfSha256(List<int> ikm, List<int> info, int length) {
    
    final zeroes = List<int>.filled(32, 0);
    final prk = dart_crypto.Hmac(dart_crypto.sha256, zeroes).convert(ikm).bytes;

    final okm = <int>[];
    var previous = <int>[];
    var counter  = 1;
    while (okm.length < length) {
      final data = <int>[...previous, ...info, counter];
      final t = dart_crypto.Hmac(dart_crypto.sha256, prk).convert(data).bytes;
      okm.addAll(t);
      previous = t;
      counter++;
    }
    return okm.sublist(0, length);
  }

  Future<SecretKey> _deriveSharedKey(
    SimpleKeyPair myKeyPair,
    List<int> peerPubBytes,
  ) async {
    final peerPub = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair:         myKeyPair,
      remotePublicKey: peerPub,
    );
    final sharedBytes = await sharedSecret.extractBytes();
    final keyBytes = _hkdfSha256(sharedBytes, utf8.encode('onyx-lan-v2'), 32);
    return SecretKey(keyBytes);
  }

  Future<void> initialize(String username) async {
    if (_isInitialized) return;

    _ephemeralKeyPair    = await _x25519.newKeyPair();
    final ephPub         = await _ephemeralKeyPair!.extractPublicKey();
    _ephemeralPubKeyBytes = ephPub.bytes;

    if (kDebugMode) {
      print('[LAN] Ephemeral pubkey: ${base64Encode(_ephemeralPubKeyBytes!)}');
    }

    try {
      await _startMessageListener();
      await _startDiscoveryBroadcaster(username);
      await _startDiscoveryListener();
      _isInitialized = true;
      if (kDebugMode) print('[LAN] Initialized with ephemeral ECDH (v2)');
    } catch (e) {
      if (kDebugMode) print('[LAN] Failed to initialize: $e');
    }
  }

  Future<void> _startDiscoveryBroadcaster(String username) async {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_ephemeralPubKeyBytes == null) return;
      await _broadcastDiscovery(username);
    });
  }

  Future<void> _broadcastDiscovery(String username) async {
    if (_ephemeralPubKeyBytes == null) return;

    final message = utf8.encode(jsonEncode({
      'type':      'discover',
      'username':  username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'pubkey':    base64Encode(_ephemeralPubKeyBytes!),
    }));

    // Send on every IPv4 interface so both Ethernet and WiFi are covered.
    List<NetworkInterface> interfaces = [];
    try {
      interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
    } catch (e) {
      if (kDebugMode) print('[LAN] NetworkInterface.list error: $e');
    }

    // Always include a fallback send via anyIPv4 in case interface list is empty.
    final bindAddresses = interfaces.expand((i) => i.addresses).toList();
    if (bindAddresses.isEmpty) {
      bindAddresses.add(InternetAddress.anyIPv4);
    }

    for (final addr in bindAddresses) {
      try {
        final socket = await RawDatagramSocket.bind(addr, 0);
        socket.broadcastEnabled = true;
        socket.send(message, InternetAddress('255.255.255.255'), discoveryPort);
        await Future.delayed(const Duration(milliseconds: 50));
        socket.close();
      } catch (e) {
        if (kDebugMode) print('[LAN] Broadcast error on ${addr.address}: $e');
      }
    }
  }

  Future<void> _startDiscoveryListener() async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );

      _discoverySocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _discoverySocket!.receive();
        if (datagram == null) return;

        try {
          final data = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
          if (data['type'] != 'discover') return;

          final username = data['username'] as String?;
          if (username == null) return;

          _discoveredDevices[username] = datagram.address;

          final pubkeyB64 = data['pubkey'] as String?;
          if (pubkeyB64 != null) {
            final pubBytes = base64Decode(pubkeyB64);
            if (pubBytes.length == _pubKeyLen) {
              final existing = _peerPubKeys[username];
              if (existing == null) {
                // First contact — trust and store (TOFU).
                _peerPubKeys[username] = pubBytes;
              } else {
                // Subsequent broadcast — only accept if key is identical.
                bool same = existing.length == pubBytes.length;
                if (same) {
                  for (int i = 0; i < existing.length; i++) {
                    if (existing[i] != pubBytes[i]) { same = false; break; }
                  }
                }
                if (!same) {
                  // Key changed after first contact — accept silently (ephemeral keys
                  // rotate on every app launch, so this is normal when the same user
                  // runs the app on multiple devices or restarts it).
                  _peerPubKeys[username] = pubBytes;
                  if (kDebugMode) {
                    print('[LAN] Key rotated for $username — updated cache silently');
                  }
                  onKeyMismatch?.call(username, _fingerprintOf(pubBytes));
                }
              }
            }
          }

          if (kDebugMode) {
            print('[LAN] Discovered: $username at ${datagram.address.address}'
                  ' (has pubkey: ${_peerPubKeys.containsKey(username)})');
          }
        } catch (e) {
          if (kDebugMode) print('[LAN] Discovery parse error: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) print('[LAN] Failed to start discovery listener: $e');
    }
  }

  Future<void> _startMessageListener() async {
    try {
      _messageSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        messagePort,
      );

      _messageSocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _messageSocket!.receive();
        if (datagram == null) return;
        _handleIncomingMessage(datagram.data);
      });
    } catch (e) {
      if (kDebugMode) print('[LAN] Failed to start message listener: $e');
    }
  }

  Future<void> _handleIncomingMessage(Uint8List encryptedData) async {
    try {
      final decrypted = await _decryptPacket(encryptedData);
      if (decrypted == null) {
        if (kDebugMode) print('[LAN] Failed to decrypt incoming packet');
        return;
      }
      final messageData = jsonDecode(decrypted) as Map<String, dynamic>;

      if (messageData['type'] == 'media_chunk') {
        final transferId  = messageData['transferId']  as String;
        final chunkIndex  = messageData['chunkIndex']  as int;
        final totalChunks = messageData['totalChunks'] as int;
        final chunkData   = messageData['data']        as String;

        _chunkBuffers.putIfAbsent(transferId, () => {});
        _chunkBuffers[transferId]![chunkIndex] = chunkData;

        if (chunkIndex == 0) _chunkMetadata[transferId] = messageData;

        if (kDebugMode) {
          print('[LAN] Received chunk $chunkIndex/$totalChunks for $transferId');
        }

        if (_chunkBuffers[transferId]!.length == totalChunks) {
          final buffer = StringBuffer();
          for (int i = 0; i < totalChunks; i++) {
            buffer.write(_chunkBuffers[transferId]![i]);
          }

          final mediaBytes = base64Decode(buffer.toString());
          final metadata   = _chunkMetadata[transferId]!;
          final mediaType  = metadata['mediaType'] as String;
          final filename   = metadata['filename']  as String;
          final from       = metadata['from']      as String;
          final to         = metadata['to']        as String;
          final replyTo    = messageData['replyTo'] as Map<String, dynamic>?;

          if (kDebugMode) {
            print('[LAN] Complete $mediaType from $from (${mediaBytes.length} B, $totalChunks chunks)');
          }

          _chunkBuffers.remove(transferId);
          _chunkMetadata.remove(transferId);

          onMediaReceived?.call(mediaType, filename, mediaBytes, from, to, replyTo);
        }
      } else if (messageData['type'] == 'media') {
        final mediaType  = messageData['mediaType'] as String;
        final filename   = messageData['filename']  as String;
        final base64Data = messageData['data']      as String;
        final from       = messageData['from']      as String;
        final to         = messageData['to']        as String;
        final replyTo    = messageData['replyTo']   as Map<String, dynamic>?;
        final mediaBytes = base64Decode(base64Data);

        if (kDebugMode) {
          print('[LAN] Received $mediaType from $from (${mediaBytes.length} B)');
        }
        onMediaReceived?.call(mediaType, filename, mediaBytes, from, to, replyTo);
      } else {
        final message = ChatMessage.fromJson(messageData);
        if (kDebugMode) print('[LAN] Received message from ${message.from}');
        onMessageReceived?.call(message);
      }
    } catch (e) {
      if (kDebugMode) print('[LAN] Message parse error: $e');
    }
  }

  Future<bool> sendMessage(ChatMessage message, String recipientUsername) async {
    final recipientAddress = _discoveredDevices[recipientUsername];
    if (recipientAddress == null) {
      if (kDebugMode) print('[LAN] Recipient $recipientUsername not found in LAN');
      return false;
    }

    final peerPubBytes = _peerPubKeys[recipientUsername];
    if (peerPubBytes == null) {
      if (kDebugMode) print('[LAN] No pubkey for $recipientUsername — cannot encrypt');
      return false;
    }

    try {
      final messageJson = jsonEncode(message.toJson());
      final encrypted   = await _encryptPacket(messageJson, peerPubBytes);

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.send(encrypted, recipientAddress, messagePort);
      await Future.delayed(const Duration(milliseconds: 100));
      socket.close();

      if (kDebugMode) {
        print('[LAN] Sent message to $recipientUsername at ${recipientAddress.address}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('[LAN] Failed to send message: $e');
      return false;
    }
  }

  Future<bool> sendMediaMessage({
    required String from,
    required String to,
    required String mediaType,
    required Uint8List mediaData,
    required String filename,
    Map<String, dynamic>? replyTo,
  }) async {
    final recipientAddress = _discoveredDevices[to];
    if (recipientAddress == null) {
      if (kDebugMode) print('[LAN] Recipient $to not found in LAN');
      return false;
    }

    final peerPubBytes = _peerPubKeys[to];
    if (peerPubBytes == null) {
      if (kDebugMode) print('[LAN] No pubkey for $to — cannot encrypt media');
      return false;
    }

    if (kDebugMode) print('[LAN] Sending $mediaType: ${mediaData.length} bytes');

    try {
      const int maxChunkSize = 32000;
      final base64Data = base64Encode(mediaData);

      final chunks = <String>[];
      for (int i = 0; i < base64Data.length; i += maxChunkSize) {
        final end = (i + maxChunkSize < base64Data.length)
            ? i + maxChunkSize
            : base64Data.length;
        chunks.add(base64Data.substring(i, end));
      }

      final totalChunks = chunks.length;
      final transferId  = DateTime.now().millisecondsSinceEpoch.toString();

      if (kDebugMode) print('[LAN] Sending $totalChunks chunks for $filename');

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      for (int i = 0; i < chunks.length; i++) {
        final messageData = {
          'type':        'media_chunk',
          'transferId':  transferId,
          'chunkIndex':  i,
          'totalChunks': totalChunks,
          'mediaType':   mediaType,
          'filename':    filename,
          'data':        chunks[i],
          'from':        from,
          'to':          to,
          'time':        DateTime.now().toIso8601String(),
          if (i == totalChunks - 1 && replyTo != null) 'replyTo': replyTo,
        };

        final messageJson = jsonEncode(messageData);
        final encrypted   = await _encryptPacket(messageJson, peerPubBytes);
        socket.send(encrypted, recipientAddress, messagePort);

        if (i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));
      socket.close();

      if (kDebugMode) {
        print('[LAN] Sent $mediaType to $to (${mediaData.length} B, $totalChunks chunks)');
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('[LAN] Failed to send media: $e');
      return false;
    }
  }

  Future<Uint8List> _encryptPacket(String plainText, List<int> peerPubBytes) async {
    if (_ephemeralKeyPair == null || _ephemeralPubKeyBytes == null) {
      throw StateError('[LAN] Not initialized — no ephemeral keypair');
    }

    final aesKey = await _deriveSharedKey(_ephemeralKeyPair!, peerPubBytes);

    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plainText),
      secretKey: aesKey,
    );

    final result = BytesBuilder()
      ..add(_ephemeralPubKeyBytes!)   
      ..add(secretBox.nonce)          
      ..add(secretBox.cipherText)     
      ..add(secretBox.mac.bytes);     
    return result.toBytes();
  }

  Future<String?> _decryptPacket(Uint8List data) async {
    if (_ephemeralKeyPair == null) return null;

    if (data.length < _pubKeyLen + _nonceLen + _macLen) return null;

    try {
      
      final senderPubBytes = data.sublist(0, _pubKeyLen);
      final nonce          = data.sublist(_pubKeyLen, _pubKeyLen + _nonceLen);
      final mac            = Mac(data.sublist(data.length - _macLen));
      final cipherText     = data.sublist(_pubKeyLen + _nonceLen, data.length - _macLen);

      final aesKey    = await _deriveSharedKey(_ephemeralKeyPair!, senderPubBytes);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: aesKey);
      return utf8.decode(plainBytes);
    } catch (e) {
      if (kDebugMode) print('[LAN] Decryption failed: $e');
      return null;
    }
  }

  bool isUserAvailableInLAN(String username) =>
      _discoveredDevices.containsKey(username);

  List<String> getDiscoveredUsers() => _discoveredDevices.keys.toList();

  void dispose() {
    _discoverySocket?.close();
    _messageSocket?.close();
    _discoveredDevices.clear();
    _peerPubKeys.clear();
    _chunkBuffers.clear();
    _chunkMetadata.clear();
    _isInitialized = false;
  }
}