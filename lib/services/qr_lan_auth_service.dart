// lib/services/qr_lan_auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:flutter/foundation.dart' show kDebugMode;

import 'onion/onion_account_sync.dart';

class QrAuthCredentials {
  final String token;
  final String username;
  final String uin;
  final String serverBase;
  final bool isPrimary;

  /// Onion identity of the account (see OnionAccountSync). The central server
  /// is gone, so linking a device now hands over the account itself.
  final Map<String, dynamic>? onionBundle;

  const QrAuthCredentials({
    required this.token,
    required this.username,
    required this.uin,
    required this.serverBase,
    required this.isPrimary,
    this.onionBundle,
  });
}

class QrAuthSession {
  final String qrJson;
  final Stream<QrAuthCredentials> stream;
  final Future<void> Function() close;

  const QrAuthSession({
    required this.qrJson,
    required this.stream,
    required this.close,
  });
}

// Used by the desktop "grant session to phone" flow.
class QrGrantSession {
  final String qrJson;
  final Stream<bool> stream;
  final Future<void> Function() close;

  const QrGrantSession({
    required this.qrJson,
    required this.stream,
    required this.close,
  });
}

class QrLanAuthService {
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();

  // HKDF-SHA256 — same implementation as LANMessageManager
  static List<int> _hkdfSha256(List<int> ikm, List<int> info, int length) {
    final zeroes = List<int>.filled(32, 0);
    final prk = dart_crypto.Hmac(dart_crypto.sha256, zeroes).convert(ikm).bytes;
    final okm = <int>[];
    var previous = <int>[];
    var counter = 1;
    while (okm.length < length) {
      final data = <int>[...previous, ...info, counter];
      final t = dart_crypto.Hmac(dart_crypto.sha256, prk).convert(data).bytes;
      okm.addAll(t);
      previous = t;
      counter++;
    }
    return okm.sublist(0, length);
  }

  static Future<SecretKey> _deriveSharedKey(
    SimpleKeyPair myKeyPair,
    List<int> peerPubBytes,
  ) async {
    final peerPub = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPub,
    );
    final sharedBytes = await sharedSecret.extractBytes();
    final keyBytes = _hkdfSha256(sharedBytes, utf8.encode('onyx-qr-auth-v1'), 32);
    return SecretKey(keyBytes);
  }

  // Returns all private IPv4 addresses, preferring 192.168.x / 10.x over
  // 172.x (which is often a Docker/VMware/VPN virtual adapter).
  static Future<List<String>> _getLocalIps() async {
    final preferred = <String>[];
    final fallback = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (a.startsWith('192.168.') || a.startsWith('10.')) {
            preferred.add(a);
          } else if (a.startsWith('172.')) {
            fallback.add(a);
          }
        }
      }
    } catch (_) {}
    final all = [...preferred, ...fallback];
    if (all.isEmpty) all.add('127.0.0.1');
    if (kDebugMode) print('[QrAuth] Local IPs: $all');
    return all;
  }

  /// Start a temporary HTTP server waiting for QR auth.
  /// Call on the device that wants to log in (shows the QR code).
  static Future<QrAuthSession> startAuthServer() async {
    final keyPair = await _x25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();

    // Random 16-byte nonce for anti-replay
    final nonce =
        Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256)));
    final nonceB64 = base64Encode(nonce);

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    final ips = await _getLocalIps();

    if (kDebugMode) print('[QrAuth] Listening on $ips:$port');

    final qrJson = jsonEncode({
      'v': 1,
      'type': 'qr_auth',
      'pub': base64Encode(pubKey.bytes),
      'ips': ips,
      'port': port,
      'nonce': nonceB64,
      'device_name': Platform.localHostname,
      'device_os': Platform.operatingSystem,
    });

    final controller = StreamController<QrAuthCredentials>();

    // Auto-close after 3 minutes — prevents the server from lingering if the
    // user walks away without cancelling, and limits the QR's usable window.
    final timeout = Timer(const Duration(minutes: 3), () async {
      if (!controller.isClosed) {
        if (kDebugMode) print('[QrAuth] Session timed out');
        await server.close(force: true);
        await controller.close();
      }
    });

    server.listen(
      (req) async {
        if (req.method != 'POST' || req.uri.path != '/auth') {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        try {
          final body = await utf8.decoder.bind(req).join();
          final json = jsonDecode(body) as Map<String, dynamic>;

          final senderPubBytes = base64Decode(json['pub'] as String);
          final cipherBytes = base64Decode(json['cipher'] as String);
          final cipherNonce = base64Decode(json['cn'] as String);
          final mac = Mac(base64Decode(json['mac'] as String));

          final sharedKey = await _deriveSharedKey(keyPair, senderPubBytes);
          final secretBox = SecretBox(cipherBytes, nonce: cipherNonce, mac: mac);
          final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: sharedKey);
          final plain = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;

          // Verify anti-replay nonce
          if (plain['nonce'] != nonceB64) {
            if (kDebugMode) print('[QrAuth] Nonce mismatch — replay?');
            req.response.statusCode = 400;
            await req.response.close();
            return;
          }

          final creds = QrAuthCredentials(
            token: (plain['token'] as String?) ?? '',
            username: plain['username'] as String,
            uin: (plain['uin'] ?? '').toString(),
            serverBase: (plain['server_base'] as String?) ?? '',
            isPrimary: plain['is_primary'] as bool? ?? false,
            onionBundle: plain['onion'] as Map<String, dynamic>?,
          );

          req.response.statusCode = 200;
          req.response.write('ok');
          await req.response.close();

          timeout.cancel();
          controller.add(creds);
          await controller.close();
          await server.close();
          if (kDebugMode) print('[QrAuth] Credentials received for ${creds.username}');
        } catch (e) {
          if (kDebugMode) print('[QrAuth] Request error: $e');
          req.response.statusCode = 400;
          await req.response.close();
        }
      },
      onError: (e) {
        if (kDebugMode) print('[QrAuth] Server error: $e');
      },
    );

    return QrAuthSession(
      qrJson: qrJson,
      stream: controller.stream,
      close: () async {
        timeout.cancel();
        await server.close(force: true);
        if (!controller.isClosed) await controller.close();
      },
    );
  }

  /// Send this account to the waiting device over LAN. The receiver shows the
  /// QR ([qr_auth]); we hand over the username and the account's onion
  /// identity so both devices share one Tor address. Returns null on success,
  /// or an error string on failure.
  static Future<String?> sendCredentials({
    required String qrJson,
    required String username,
  }) async {
    Map<String, dynamic> qr;
    try {
      qr = jsonDecode(qrJson) as Map<String, dynamic>;
    } catch (_) {
      return 'Invalid QR format';
    }
    if (qr['v'] != 1 || qr['type'] != 'qr_auth') {
      return 'Not an Onyx QR auth code';
    }

    // Support both old single-ip format and new multi-ip format.
    final List<String> ips;
    if (qr['ips'] is List) {
      ips = List<String>.from(qr['ips'] as List);
    } else if (qr['ip'] is String) {
      ips = [qr['ip'] as String];
    } else {
      return 'No IP address in QR payload';
    }
    final port = qr['port'] as int? ?? 0;

    final bundle = await OnionAccountSync.exportBundle(username);
    if (bundle == null) {
      return 'This device has no Tor address yet. Turn on Onion mode first.';
    }

    try {
      final theirPubBytes = base64Decode(qr['pub'] as String);
      final nonceB64 = qr['nonce'] as String;

      final myKeyPair = await _x25519.newKeyPair();
      final myPub = await myKeyPair.extractPublicKey();
      final sharedKey = await _deriveSharedKey(myKeyPair, theirPubBytes);

      final plaintext = utf8.encode(jsonEncode({
        'username': username,
        'is_primary': false,
        'onion': bundle,
        'nonce': nonceB64,
      }));

      final secretBox = await _aesGcm.encrypt(plaintext, secretKey: sharedKey);

      final body = jsonEncode({
        'pub': base64Encode(myPub.bytes),
        'cipher': base64Encode(secretBox.cipherText),
        'cn': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      });

      // Try each IP in order — 192.168/10.x preferred, 172.x fallback.
      String? lastError;
      for (final ip in ips) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
        try {
          if (kDebugMode) print('[QrAuth] Trying $ip:$port …');
          final httpReq = await client.postUrl(Uri.parse('http://$ip:$port/auth'));
          httpReq.headers.contentType = ContentType.json;
          httpReq.write(body);
          final resp = await httpReq.close();
          await resp.drain<void>();
          client.close();
          if (kDebugMode) print('[QrAuth] $ip → ${resp.statusCode}');
          if (resp.statusCode == 200) return null;
          lastError = 'Server at $ip returned ${resp.statusCode}';
        } on SocketException catch (e) {
          client.close();
          lastError = 'Cannot reach $ip:$port — ${e.message}';
          if (kDebugMode) print('[QrAuth] $ip failed: ${e.message}');
        } on HttpException catch (e) {
          client.close();
          lastError = 'HTTP error on $ip — ${e.message}';
          if (kDebugMode) print('[QrAuth] $ip http error: ${e.message}');
        }
      }
      return lastError ?? 'All addresses unreachable';
    } catch (e) {
      if (kDebugMode) print('[QrAuth] sendCredentials error: $e');
      return e.toString();
    }
  }

  // ── Desktop → Phone grant ─────────────────────────────────────────────────

  /// Start a temporary HTTP server that issues a fresh session to a phone.
  /// Call on the authenticated desktop that wants to grant access to a phone.
  /// The phone scans the returned QR, connects, and receives its encrypted token.
  static Future<QrGrantSession> startGrantServer({
    required String username,
  }) async {
    final nonce =
        Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256)));
    final nonceB64 = base64Encode(nonce);

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    final ips = await _getLocalIps();

    if (kDebugMode) print('[QrGrant] Listening on $ips:$port');

    final qrJson = jsonEncode({
      'v': 1,
      'type': 'qr_grant',
      'ips': ips,
      'port': port,
      'nonce': nonceB64,
      'device_name': Platform.localHostname,
      'device_os': Platform.operatingSystem,
    });

    final controller = StreamController<bool>();

    final timeout = Timer(const Duration(minutes: 3), () async {
      if (!controller.isClosed) {
        if (kDebugMode) print('[QrGrant] Session timed out');
        await server.close(force: true);
        await controller.close();
      }
    });

    server.listen(
      (req) async {
        if (req.method != 'POST' || req.uri.path != '/auth') {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        try {
          final body = await utf8.decoder.bind(req).join();
          final json = jsonDecode(body) as Map<String, dynamic>;

          if (json['nonce'] != nonceB64) {
            if (kDebugMode) print('[QrGrant] Nonce mismatch');
            req.response.statusCode = 400;
            await req.response.close();
            return;
          }

          final phonePubBytes = base64Decode(json['pub'] as String);

          final bundle = await OnionAccountSync.exportBundle(username);
          if (bundle == null) {
            if (kDebugMode) print('[QrGrant] no onion identity to hand over');
            req.response.statusCode = 409;
            await req.response.close();
            return;
          }

          // Encrypt response with phone's ephemeral pub key
          final ephemeralKeyPair = await _x25519.newKeyPair();
          final ephemeralPub = await ephemeralKeyPair.extractPublicKey();
          final sharedKey = await _deriveSharedKey(ephemeralKeyPair, phonePubBytes);

          final plaintext = utf8.encode(jsonEncode({
            'username': username,
            'is_primary': false,
            'onion': bundle,
            'nonce': nonceB64,
          }));

          final secretBox = await _aesGcm.encrypt(plaintext, secretKey: sharedKey);

          final responseBody = jsonEncode({
            'pub': base64Encode(ephemeralPub.bytes),
            'cipher': base64Encode(secretBox.cipherText),
            'cn': base64Encode(secretBox.nonce),
            'mac': base64Encode(secretBox.mac.bytes),
          });

          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(responseBody);
          await req.response.close();

          timeout.cancel();
          controller.add(true);
          await controller.close();
          await server.close();
          if (kDebugMode) print('[QrGrant] Account granted to $username');
        } catch (e) {
          if (kDebugMode) print('[QrGrant] Error: $e');
          req.response.statusCode = 500;
          await req.response.close();
        }
      },
      onError: (e) => kDebugMode ? print('[QrGrant] Server error: $e') : null,
    );

    return QrGrantSession(
      qrJson: qrJson,
      stream: controller.stream,
      close: () async {
        timeout.cancel();
        await server.close(force: true);
        if (!controller.isClosed) await controller.close();
      },
    );
  }

  /// Receive a granted session from a desktop.
  /// Call on the phone side after scanning a [qr_grant] QR code.
  /// Returns credentials on success, null on failure.
  static Future<QrAuthCredentials?> receiveGrantedSession({
    required String qrJson,
  }) async {
    Map<String, dynamic> qr;
    try {
      qr = jsonDecode(qrJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    if (qr['v'] != 1 || qr['type'] != 'qr_grant') return null;

    final List<String> ips;
    if (qr['ips'] is List) {
      ips = List<String>.from(qr['ips'] as List);
    } else {
      return null;
    }
    final port = qr['port'] as int? ?? 0;
    final nonceB64 = qr['nonce'] as String;

    // Ephemeral keypair for key exchange
    final myKeyPair = await _x25519.newKeyPair();
    final myPub = await myKeyPair.extractPublicKey();

    final requestBody = jsonEncode({
      'pub': base64Encode(myPub.bytes),
      'nonce': nonceB64,
      'device_name': Platform.localHostname,
      'device_os': Platform.operatingSystem,
    });

    String? lastError;
    for (final ip in ips) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        if (kDebugMode) print('[QrGrant] Trying $ip:$port …');
        final httpReq = await client.postUrl(Uri.parse('http://$ip:$port/auth'));
        httpReq.headers.contentType = ContentType.json;
        httpReq.write(requestBody);
        final resp = await httpReq.close();
        final body = await utf8.decoder.bind(resp).join();
        client.close();

        if (resp.statusCode == 200) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final serverEphemeralPubBytes = base64Decode(json['pub'] as String);
          final sharedKey = await _deriveSharedKey(myKeyPair, serverEphemeralPubBytes);

          final cipherBytes = base64Decode(json['cipher'] as String);
          final cipherNonce = base64Decode(json['cn'] as String);
          final mac = Mac(base64Decode(json['mac'] as String));

          final secretBox = SecretBox(cipherBytes, nonce: cipherNonce, mac: mac);
          final plainBytes = await _aesGcm.decrypt(secretBox, secretKey: sharedKey);
          final plain = jsonDecode(utf8.decode(plainBytes)) as Map<String, dynamic>;

          if (kDebugMode) print('[QrGrant] Received session for ${plain['username']}');
          return QrAuthCredentials(
            token: (plain['token'] as String?) ?? '',
            username: plain['username'] as String,
            uin: (plain['uin'] ?? '').toString(),
            serverBase: (plain['server_base'] as String?) ?? '',
            isPrimary: plain['is_primary'] as bool? ?? false,
            onionBundle: plain['onion'] as Map<String, dynamic>?,
          );
        }
        lastError = 'Server at $ip returned ${resp.statusCode}';
      } on SocketException catch (e) {
        client.close();
        lastError = 'Cannot reach $ip:$port — ${e.message}';
        if (kDebugMode) print('[QrGrant] $ip failed: ${e.message}');
      } catch (e) {
        client.close();
        lastError = 'Error on $ip — $e';
        if (kDebugMode) print('[QrGrant] $ip error: $e');
      }
    }

    if (kDebugMode) print('[QrGrant] All addresses failed: $lastError');
    return null;
  }
}
