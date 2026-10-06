// lib/services/lan_fav_sync_service.dart
//
// LAN synchronization of favorite chats.
//
// Flow:
//   Receiver (desktop / target device):
//     1. Call LanFavSyncService.startReceiver()
//     2. Display the returned qrJson as a QR code.
//     3. Listen to the events stream for progress / completion.
//     4. On LanFavSyncDone, call applyToApp() to merge data into the app state.
//
//   Sender (phone / source device):
//     1. Scan the QR code, obtain qrJson.
//     2. Call LanFavSyncService.sendFavorites(qrJson, favIds).
//     3. Listen to the returned stream for progress / completion.
//
// Encryption: X25519 ECDH + HKDF-SHA256 + AES-256-GCM,
// identical to the existing QrLanAuthService and LANMessageManager.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxDocumentsDirectory, getOnyxSupportDirectory;

import '../globals.dart';
import '../models/chat_message.dart';
import 'wardlink/wardlink_crypto.dart';
import '../models/favorite_chat.dart';
import '../utils/image_file_cache.dart';
import '../utils/media_cache.dart';

// ─────────────────────────── Events ──────────────────────────────────────────

sealed class LanFavSyncEvent {}

class LanFavSyncStatus extends LanFavSyncEvent {
  final String message;
  final int current;
  final int total;
  // Byte-level progress for the current file being transferred.
  // Both are 0 when no file-level progress is available.
  final int bytesTransferred;
  final int fileBytes;
  LanFavSyncStatus(this.message, {this.current = 0, this.total = 0,
      this.bytesTransferred = 0, this.fileBytes = 0});
}

class LanFavSyncFileResult extends LanFavSyncEvent {
  final String filename;
  final bool success;
  final String? error;
  LanFavSyncFileResult(this.filename, {required this.success, this.error});
}

class LanFavSyncDone extends LanFavSyncEvent {
  final int favoritesCount;
  final int filesReceived;
  final int filesSkipped;
  final List<FavSyncFileError> fileErrors;

  /// Accumulated data ready to be merged into the app.
  final List<FavoriteChat> favorites;
  final Map<String, List<ChatMessage>> chats;

  LanFavSyncDone({
    required this.favoritesCount,
    required this.filesReceived,
    required this.filesSkipped,
    required this.fileErrors,
    required this.favorites,
    required this.chats,
  });
}

class LanFavSyncFatalError extends LanFavSyncEvent {
  final String message;
  LanFavSyncFatalError(this.message);
}

class FavSyncFileError {
  final String key;
  final String reason;
  FavSyncFileError(this.key, this.reason);
}

// ─────────────────────────── Receiver session ────────────────────────────────

class LanFavSyncReceiverSession {
  final String qrJson;
  final Stream<LanFavSyncEvent> events;
  final Future<void> Function() close;

  const LanFavSyncReceiverSession({
    required this.qrJson,
    required this.events,
    required this.close,
  });
}

// ─────────────────────────── Sender handshake session ────────────────────────

/// Returned by [LanFavSyncService.startSenderHandshake].
/// Desktop shows [qrJson] as a QR code; phone scans it and auto-registers.
class LanFavSyncSenderHandshakeSession {
  final String qrJson;
  final Stream<LanFavSyncEvent> events;
  final Future<void> Function() close;

  const LanFavSyncSenderHandshakeSession({
    required this.qrJson,
    required this.events,
    required this.close,
  });
}

// ─────────────────────────── Main service ─────────────────────────────────────

class LanFavSyncService {
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();

  static const int _maxFileSizeBytes = 200 * 1024 * 1024; // 200 MB

  // ── crypto helpers (same as QrLanAuthService / LANMessageManager) ───────────

  static List<int> _hkdf(List<int> ikm, List<int> info, int len) {
    final zeroes = List<int>.filled(32, 0);
    final prk = dart_crypto.Hmac(dart_crypto.sha256, zeroes).convert(ikm).bytes;
    final okm = <int>[];
    var prev = <int>[];
    var ctr = 1;
    while (okm.length < len) {
      final t = dart_crypto.Hmac(dart_crypto.sha256, prk)
          .convert([...prev, ...info, ctr]).bytes;
      okm.addAll(t);
      prev = t;
      ctr++;
    }
    return okm.sublist(0, len);
  }

  static Future<SecretKey> _deriveSharedKey(
    SimpleKeyPair myKP,
    List<int> peerPub,
  ) async {
    final remote = SimplePublicKey(peerPub, type: KeyPairType.x25519);
    final ss = await _x25519.sharedSecretKey(keyPair: myKP, remotePublicKey: remote);
    final ssBytes = await ss.extractBytes();
    return SecretKey(_hkdf(ssBytes, utf8.encode('onyx-fav-sync-v1'), 32));
  }

  // Encrypt plaintext bytes → JSON envelope string
  static Future<String> _encrypt(Uint8List plain, List<int> peerPub) async {
    final kp = await _x25519.newKeyPair();
    final myPub = await kp.extractPublicKey();
    final sk = await _deriveSharedKey(kp, peerPub);
    final box = await _aesGcm.encrypt(plain, secretKey: sk);
    return jsonEncode({
      'pub': base64Encode(myPub.bytes),
      'cn': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  // Decrypt JSON envelope → plaintext bytes
  static Future<Uint8List?> _decrypt(String body, SimpleKeyPair myKP) async {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final senderPub = base64Decode(j['pub'] as String);
      final cipher = base64Decode(j['cipher'] as String);
      final cn = base64Decode(j['cn'] as String);
      final mac = Mac(base64Decode(j['mac'] as String));
      final sk = await _deriveSharedKey(myKP, senderPub);
      final box = SecretBox(cipher, nonce: cn, mac: mac);
      final plain = await _aesGcm.decrypt(box, secretKey: sk);
      return Uint8List.fromList(plain);
    } catch (e) {
      if (kDebugMode) print('[FavSync] decrypt error: $e');
      return null;
    }
  }

  // ── IP discovery (same logic as QrLanAuthService) ───────────────────────────

  static Future<List<String>> _localIps() async {
    final preferred = <String>[], fallback = <String>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in ifaces) {
        for (final a in iface.addresses) {
          if (a.address.startsWith('192.168.') || a.address.startsWith('10.')) {
            preferred.add(a.address);
          } else if (a.address.startsWith('172.')) {
            fallback.add(a.address);
          }
        }
      }
    } catch (_) {}
    final all = [...preferred, ...fallback];
    if (all.isEmpty) all.add('127.0.0.1');
    return all;
  }

  // ── SHA-256 helper ───────────────────────────────────────────────────────────

  static String _sha256hex(List<int> bytes) =>
      dart_crypto.sha256.convert(bytes).toString();

  // ─────────────────────────── RECEIVER ──────────────────────────────────────

  /// Start a receiver HTTP server and return a session with the QR payload.
  static Future<LanFavSyncReceiverSession> startReceiver() async {
    final keyPair = await _x25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    final nonce = base64Encode(
        Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256))));

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    final ips = await _localIps();

    final qrJson = jsonEncode({
      'v': 1,
      'type': 'fav_sync',
      'pub': base64Encode(pubKey.bytes),
      'ips': ips,
      'port': port,
      'nonce': nonce,
      'device_name': Platform.localHostname,
      'device_os': Platform.operatingSystem,
    });

    if (kDebugMode) print('[FavSync] Receiver listening on $ips:$port');

    final controller = StreamController<LanFavSyncEvent>.broadcast();

    // Session-level state
    List<Map<String, dynamic>>? metaFavorites; // parsed from /fav/meta
    final Map<String, String> fileTypeMap = {};   // key → 'image'|'video'|'audio'|'file'|'avatar'
    final Map<String, String> fileSha256Map = {}; // key → expected sha256
    final Map<String, String> savedFilePaths = {}; // key → local path
    int expectedFiles = 0;
    int receivedFiles = 0;
    final List<FavSyncFileError> fileErrors = [];
    // Streaming key negotiated during /fav/meta: used by /fav/file/stream to
    // decrypt large files without loading them fully into memory.
    SecretKey? streamKey;

    final timeout = Timer(const Duration(hours: 24), () async {
      if (!controller.isClosed) {
        controller.add(LanFavSyncFatalError('Session timed out'));
        await server.close(force: true);
        await controller.close();
      }
    });

    Future<void> closeAll() async {
      timeout.cancel();
      await server.close(force: true);
      if (!controller.isClosed) await controller.close();
    }

    server.listen(
      (req) async {
        if (req.method != 'POST') {
          req.response.statusCode = 405;
          await req.response.close();
          return;
        }

        // ── /fav/file/stream (streaming — must handle before reading body) ───────
        // Large files arrive as WardLink-style AES-GCM frames; we decrypt and
        // write each 64 KB chunk to disk without ever holding the full file in
        // RAM. Auth is a tiny ECDH-encrypted blob in the X-Fav-Auth header.
        if (req.uri.path == '/fav/file/stream') {
          final sk = streamKey;
          if (sk == null || metaFavorites == null) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Session not initialised — call /fav/meta first'}));
            await req.response.close();
            return;
          }

          final authB64 = req.headers.value('x-fav-auth');
          if (authB64 == null) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Missing x-fav-auth header'}));
            await req.response.close();
            return;
          }

          // Decrypt the auth blob (tiny ECDH envelope → {nonce, key, size}).
          Map<String, dynamic>? auth;
          try {
            final authJson = utf8.decode(base64Decode(authB64));
            final authPlain = await _decrypt(authJson, keyPair);
            if (authPlain != null) {
              auth = jsonDecode(utf8.decode(authPlain)) as Map<String, dynamic>;
            }
          } catch (_) {}
          if (auth == null || auth['nonce'] != nonce) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Auth failed'}));
            await req.response.close();
            return;
          }

          final fileKey = auth['key'] as String? ?? '';
          final type = fileTypeMap[fileKey] ?? 'file';
          // Total size from the auth blob (sent by the sender); used for progress.
          final fileSize = auth['size'] as int? ?? 0;
          String? savePath;
          try {
            savePath = await targetPathForKey(fileKey, type);
            final fileSink = File(savePath).openWrite();

            // Compute SHA-256 incrementally so we never re-read the file.
            dart_crypto.Digest? sha256Digest;
            final hashSink = dart_crypto.sha256.startChunkedConversion(
              ChunkedConversionSink<dart_crypto.Digest>.withCallback(
                  (d) => sha256Digest = d.single),
            );

            int bytesReceived = 0;
            int lastPct = -1;

            final reader = WardLinkFrameReader(req);
            try {
              while (true) {
                final lenBytes = await reader.readExact(4);
                if (lenBytes == null) break;
                final len =
                    ByteData.sublistView(lenBytes).getUint32(0, Endian.big);
                if (len == 0) break; // terminator
                final sealed = await reader.readExact(len);
                if (sealed == null) throw const FormatException('truncated frame');
                final plain = await WardLinkCrypto.openFrame(sealed, sk);
                fileSink.add(plain);
                hashSink.add(plain);
                // Emit per-1% byte progress to keep the UI updated.
                if (fileSize > 0) {
                  bytesReceived += plain.length;
                  final pct = bytesReceived * 100 ~/ fileSize;
                  if (pct != lastPct) {
                    lastPct = pct;
                    controller.add(LanFavSyncStatus(
                      'Receiving ${p.basename(fileKey)}',
                      current: receivedFiles,
                      total: expectedFiles,
                      bytesTransferred: bytesReceived,
                      fileBytes: fileSize,
                    ));
                  }
                }
              }
              hashSink.close();
              await fileSink.flush();
              await fileSink.close();
            } catch (e) {
              await reader.cancel();
              await fileSink.close();
              rethrow;
            }
            await reader.cancel();

            // Verify integrity via SHA-256 when the sender supplied one.
            final expectedSha = fileSha256Map[fileKey] ?? '';
            if (expectedSha.isNotEmpty) {
              final actualSha = sha256Digest?.toString() ?? '';
              if (actualSha != expectedSha) {
                await File(savePath).delete();
                throw Exception('Integrity check failed (sha256 mismatch)');
              }
            }

            registerSavedFile(fileKey, type, savePath,
                await File(savePath).length());
            savedFilePaths[fileKey] = savePath;
            receivedFiles++;

            controller.add(LanFavSyncFileResult(fileKey, success: true));
            controller.add(LanFavSyncStatus(
              'Received: ${p.basename(fileKey)} ($receivedFiles/$expectedFiles)',
              current: receivedFiles,
              total: expectedFiles,
            ));

            req.response.statusCode = 200;
            req.response.write(jsonEncode({'ok': true}));
          } catch (e) {
            final errMsg = e.toString();
            if (savePath != null) {
              try {
                await File(savePath).delete();
              } catch (_) {}
            }
            fileErrors.add(FavSyncFileError(fileKey, errMsg));
            controller.add(
                LanFavSyncFileResult(fileKey, success: false, error: errMsg));
            req.response.statusCode = 422;
            req.response.write(jsonEncode({'error': errMsg}));
          }
          await req.response.close();
          return;
        }

        final body = await utf8.decoder.bind(req).join();

        // ── /fav/meta ──────────────────────────────────────────────────────────
        if (req.uri.path == '/fav/meta') {
          final plain = await _decrypt(body, keyPair);
          if (plain == null) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Decryption failed'}));
            await req.response.close();
            return;
          }

          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
          } catch (e) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Invalid JSON: $e'}));
            await req.response.close();
            return;
          }

          if (payload['nonce'] != nonce) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Nonce mismatch'}));
            await req.response.close();
            return;
          }

          metaFavorites = (payload['favorites'] as List)
              .cast<Map<String, dynamic>>();

          // Derive per-session stream key from the sender's ephemeral pub.
          // Used by /fav/file/stream for large-file streaming (no base64/OOM).
          final streamPubB64 = payload['stream_pub'] as String?;
          if (streamPubB64 != null) {
            try {
              final streamPubBytes = base64Decode(streamPubB64);
              final shared = await _x25519.sharedSecretKey(
                keyPair: keyPair,
                remotePublicKey:
                    SimplePublicKey(streamPubBytes, type: KeyPairType.x25519),
              );
              final sharedBytes = await shared.extractBytes();
              streamKey = SecretKey(WardLinkCrypto.hkdf(
                  sharedBytes, utf8.encode('onyx-fav-stream-v1'), 32));
            } catch (_) {}
          }

          // Build file manifest
          for (final fav in metaFavorites!) {
            final files = (fav['files'] as List? ?? []).cast<Map<String, dynamic>>();
            for (final f in files) {
              final key = f['key'] as String;
              fileTypeMap[key] = f['type'] as String? ?? 'file';
              fileSha256Map[key] = f['sha256'] as String? ?? '';
            }
            final avatar = fav['avatar'] as Map<String, dynamic>?;
            if (avatar != null) {
              final key = avatar['key'] as String;
              fileTypeMap[key] = 'avatar';
              fileSha256Map[key] = avatar['sha256'] as String? ?? '';
            }
          }
          expectedFiles = fileTypeMap.length;

          final favCount = metaFavorites!.length;
          controller.add(LanFavSyncStatus(
            'Receiving $favCount favorite chat${favCount == 1 ? '' : 's'}'
            ' with $expectedFiles file${expectedFiles == 1 ? '' : 's'}…',
            current: 0, total: expectedFiles,
          ));

          req.response.statusCode = 200;
          req.response.write(jsonEncode({'ok': true, 'expected_files': expectedFiles}));
          await req.response.close();
          return;
        }

        // ── /fav/file ──────────────────────────────────────────────────────────
        if (req.uri.path == '/fav/file') {
          if (metaFavorites == null) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Must call /fav/meta first'}));
            await req.response.close();
            return;
          }

          final plain = await _decrypt(body, keyPair);
          if (plain == null) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Decryption failed'}));
            await req.response.close();
            return;
          }

          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
          } catch (e) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Invalid JSON: $e'}));
            await req.response.close();
            return;
          }

          if (payload['nonce'] != nonce) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Nonce mismatch'}));
            await req.response.close();
            return;
          }

          final key = payload['key'] as String? ?? '';
          final expectedSha = payload['sha256'] as String? ?? '';
          final dataB64 = payload['data'] as String? ?? '';

          String? savePath;
          try {
            final bytes = base64Decode(dataB64);

            // Integrity check
            final actualSha = _sha256hex(bytes);
            if (expectedSha.isNotEmpty && actualSha != expectedSha) {
              throw Exception(
                  'Integrity check failed: expected $expectedSha, got $actualSha');
            }

            final type = fileTypeMap[key] ?? 'file';
            savePath = await _saveFileForType(bytes, key, type);
            savedFilePaths[key] = savePath;
            receivedFiles++;

            controller.add(LanFavSyncFileResult(key, success: true));
            controller.add(LanFavSyncStatus(
              'Received: ${p.basename(key)} ($receivedFiles/$expectedFiles)',
              current: receivedFiles, total: expectedFiles,
            ));

            req.response.statusCode = 200;
            req.response.write(jsonEncode({'ok': true}));
          } catch (e) {
            final errMsg = e.toString();
            fileErrors.add(FavSyncFileError(key, errMsg));
            if (kDebugMode) print('[FavSync] File error ($key): $errMsg');
            controller.add(LanFavSyncFileResult(key, success: false, error: errMsg));
            req.response.statusCode = 422;
            req.response.write(jsonEncode({'error': errMsg}));
          }
          await req.response.close();
          return;
        }

        // ── /fav/done ──────────────────────────────────────────────────────────
        if (req.uri.path == '/fav/done') {
          final plain = await _decrypt(body, keyPair);
          if (plain == null) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Decryption failed'}));
            await req.response.close();
            return;
          }

          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
          } catch (e) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Invalid JSON: $e'}));
            await req.response.close();
            return;
          }

          if (payload['nonce'] != nonce) {
            req.response.statusCode = 400;
            req.response.write(jsonEncode({'error': 'Nonce mismatch'}));
            await req.response.close();
            return;
          }

          // Build favorites + chats from received metadata
          final favorites = <FavoriteChat>[];
          final chats = <String, List<ChatMessage>>{};

          for (final favData in (metaFavorites ?? [])) {
            final meta = favData['meta'] as Map<String, dynamic>;

            // Remap avatar path to saved local path
            String? avatarPath = meta['avatarPath'] as String?;
            if (avatarPath != null) {
              final avatarKey = 'avatar_${meta['id']}${p.extension(avatarPath)}';
              avatarPath = savedFilePaths[avatarKey] ?? avatarPath;
              // If the avatar file was not actually saved locally, clear the path
              if (!File(avatarPath).existsSync()) avatarPath = null;
            }

            final fav = FavoriteChat(
              id: meta['id'] as String,
              title: meta['title'] as String,
              avatarPath: avatarPath,
              createdAt: DateTime.parse(meta['createdAt'] as String),
            );
            favorites.add(fav);

            final messages = (favData['messages'] as List)
                .cast<Map<String, dynamic>>()
                .map(ChatMessage.fromJson)
                .toList();
            chats['fav:${fav.id}'] = messages;
          }

          final skipped = expectedFiles - receivedFiles;
          controller.add(LanFavSyncDone(
            favoritesCount: favorites.length,
            filesReceived: receivedFiles,
            filesSkipped: skipped,
            fileErrors: List.unmodifiable(fileErrors),
            favorites: favorites,
            chats: chats,
          ));

          req.response.statusCode = 200;
          req.response.write(jsonEncode({'ok': true}));
          await req.response.close();

          await closeAll();
          return;
        }

        req.response.statusCode = 404;
        await req.response.close();
      },
      onError: (e) {
        if (kDebugMode) print('[FavSync] Server error: $e');
      },
    );

    return LanFavSyncReceiverSession(
      qrJson: qrJson,
      events: controller.stream,
      close: closeAll,
    );
  }

  // ── File saving helpers (receiver side) ─────────────────────────────────────

  static Future<String> _saveFileForType(
      Uint8List bytes, String key, String type) async {
    final path = await targetPathForKey(key, type);
    await File(path).writeAsBytes(bytes, flush: true);
    registerSavedFile(key, type, path, bytes.length);
    return path;
  }

  /// Compute the on-disk destination for a file [key] of the given [type],
  /// creating its parent directory. Mirrors the original favorites storage
  /// layout. Shared with WardLink so a single source of truth governs where
  /// each media kind is written.
  static Future<String> targetPathForKey(String key, String type) async {
    final appDir = (await getOnyxSupportDirectory()).path;
    final basename = p.basename(key);

    // Files with the fav:// prefix are favorites-local files. Each widget
    // type expects them in a specific subfolder under applicationDocumentsDirectory.
    if (key.startsWith('fav://')) {
      final docDir = (await getOnyxDocumentsDirectory()).path;
      final String favDir;
      switch (type) {
        case 'voice':
        case 'audio':
          favDir = '$docDir/voice_cache';
        default:
          favDir = '$docDir/fav_media';
      }
      await Directory(favDir).create(recursive: true);
      return '$favDir/$basename';
    }

    String cacheDir;
    switch (type) {
      case 'image':
        cacheDir = '$appDir/image_cache';
      case 'video':
        cacheDir = '$appDir/video_cache';
      case 'audio':
      case 'voice':
        cacheDir = '$appDir/audio_cache';
      case 'avatar':
        cacheDir = '$appDir/fav_avatars';
      case 'document':
        cacheDir = '$appDir/document_cache';
      case 'archive':
        cacheDir = '$appDir/archive_cache';
      default:
        cacheDir = '$appDir/data_cache';
    }
    await Directory(cacheDir).create(recursive: true);
    return '$cacheDir/$basename';
  }

  /// Register an already-written file in the runtime caches so the UI can
  /// render it immediately. Shared with WardLink.
  static void registerSavedFile(String key, String type, String path, int size) {
    final basename = p.basename(key);
    if (key.startsWith('fav://')) {
      if (type != 'avatar') {
        mediaFilePathRegistry[basename] = path;
        mediaFilePathRegistry[key] = path;
      }
      return;
    }
    if (type == 'image') {
      imageFileCache[basename] = (file: File(path), size: size, aspectRatio: null);
    } else if (type != 'avatar') {
      mediaFilePathRegistry[basename] = path;
    }
  }

  /// Locate local files referenced by message [content]. Returns the files that
  /// actually exist on this device as (key, path, type). Used by WardLink to
  /// serve a requested file. Reuses the canonical extraction logic.
  static Future<List<({String key, String path, String type})>>
      locateFilesForContent(String content) async {
    final appDir = (await getOnyxSupportDirectory()).path;
    final entries = await _extractFileEntries(content, appDir);
    return [for (final e in entries) (key: e.key, path: e.path, type: e.type)];
  }

  /// Parse message [content] and return every file it references as (key, type),
  /// regardless of whether the file exists locally. Used by WardLink to decide
  /// which media a freshly-received message still needs to fetch.
  static List<({String key, String type})> referencedKeys(String content) {
    final out = <({String key, String type})>[];
    void add(String? fn, String type) {
      if (fn != null && fn.isNotEmpty) out.add((key: fn, type: type));
    }

    // Onion/LAN messages name their file in 'url' (onion://<name>), not
    // 'filename'; a server URL there is not a local file and is skipped.
    String? localName(Map<String, dynamic> d) {
      final fn = d['filename']?.toString();
      if (fn != null && fn.isNotEmpty) return fn;
      final url = d['url']?.toString();
      if (url != null &&
          (url.startsWith('onion://') ||
              url.startsWith('lan://') ||
              url.startsWith('fav://'))) {
        return url;
      }
      return d['orig']?.toString();
    }

    ({String tag, String type})? match;
    for (final m in const [
      (tag: 'IMAGEv1:', type: 'image'),
      (tag: 'VIDEOv1:', type: 'video'),
      (tag: 'VOICEv1:', type: 'voice'),
      (tag: 'AUDIOv1:', type: 'audio'),
      (tag: 'FILEv1:', type: 'file'),
      (tag: 'DOCUMENTv1:', type: 'document'),
      (tag: 'ARCHIVEv1:', type: 'archive'),
      (tag: 'DATAv1:', type: 'file'),
    ]) {
      if (content.startsWith(m.tag)) {
        match = m;
        break;
      }
    }

    try {
      if (content.startsWith('ALBUMv1:')) {
        final list = jsonDecode(content.substring('ALBUMv1:'.length)) as List;
        for (final item in list.cast<Map<String, dynamic>>()) {
          add(localName(item), 'image');
        }
      } else if (match != null) {
        final d = jsonDecode(content.substring(match.tag.length))
            as Map<String, dynamic>;
        add(localName(d), match.type);
      }
    } catch (_) {}
    return out;
  }

  // ─────────────────────────── SENDER HANDSHAKE (desktop → phone) ───────────

  /// Desktop-side: starts a handshake HTTP server and returns a QR code to display.
  /// When the phone scans the QR and POSTs its receiver QR back, the service
  /// automatically starts the file transfer and streams all events.
  static Future<LanFavSyncSenderHandshakeSession> startSenderHandshake(
      List<String> favIds) async {
    final keyPair = await _x25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    final nonce = base64Encode(
        Uint8List.fromList(List.generate(16, (_) => Random.secure().nextInt(256))));

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final port = server.port;
    final ips = await _localIps();

    final qrJson = jsonEncode({
      'v': 1,
      'type': 'fav_sync_sender',
      'pub': base64Encode(pubKey.bytes),
      'ips': ips,
      'port': port,
      'nonce': nonce,
      'device_name': Platform.localHostname,
      'device_os': Platform.operatingSystem,
    });

    if (kDebugMode) print('[FavSync] Handshake server on $ips:$port');

    final controller = StreamController<LanFavSyncEvent>.broadcast();
    bool handshakeDone = false;

    final timeout = Timer(const Duration(hours: 24), () async {
      if (!controller.isClosed) {
        controller.add(LanFavSyncFatalError('Session timed out'));
        await server.close(force: true);
        await controller.close();
      }
    });

    Future<void> closeAll() async {
      timeout.cancel();
      await server.close(force: true);
      if (!controller.isClosed) await controller.close();
    }

    server.listen(
      (req) async {
        if (req.method != 'POST' || req.uri.path != '/fav_sync_handshake') {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }

        if (handshakeDone) {
          req.response.statusCode = 409;
          req.response.write(jsonEncode({'error': 'Handshake already complete'}));
          await req.response.close();
          return;
        }

        final body = await utf8.decoder.bind(req).join();
        final plain = await _decrypt(body, keyPair);
        if (plain == null) {
          req.response.statusCode = 400;
          req.response.write(jsonEncode({'error': 'Decryption failed'}));
          await req.response.close();
          return;
        }

        Map<String, dynamic> payload;
        try {
          payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        } catch (e) {
          req.response.statusCode = 400;
          req.response.write(jsonEncode({'error': 'Invalid JSON: $e'}));
          await req.response.close();
          return;
        }

        if (payload['nonce'] != nonce) {
          req.response.statusCode = 400;
          req.response.write(jsonEncode({'error': 'Nonce mismatch'}));
          await req.response.close();
          return;
        }

        final receiverQrJson = payload['receiver_qr'] as String?;
        if (receiverQrJson == null) {
          req.response.statusCode = 400;
          req.response.write(jsonEncode({'error': 'Missing receiver_qr'}));
          await req.response.close();
          return;
        }

        handshakeDone = true;
        req.response.statusCode = 200;
        req.response.write(jsonEncode({'ok': true}));
        await req.response.close();

        // Close handshake server, start actual transfer
        timeout.cancel();
        await server.close(force: true);

        if (!controller.isClosed) {
          controller.add(LanFavSyncStatus('Phone connected, starting transfer…'));
        }

        final sendStream = sendFavorites(qrJson: receiverQrJson, favIds: favIds);
        await for (final event in sendStream) {
          if (!controller.isClosed) controller.add(event);
        }
        if (!controller.isClosed) await controller.close();
      },
      onError: (e) async {
        if (kDebugMode) print('[FavSync] Handshake server error: $e');
        await closeAll();
      },
    );

    return LanFavSyncSenderHandshakeSession(
      qrJson: qrJson,
      events: controller.stream,
      close: closeAll,
    );
  }

  /// Phone-side: when the phone scans a [senderQrJson] (type = fav_sync_sender),
  /// send back the phone's own receiver QR so the desktop can push files.
  static Future<void> sendHandshakeAck(
      String senderQrJson, String receiverQrJson) async {
    final senderQr = jsonDecode(senderQrJson) as Map<String, dynamic>;

    final List<String> ips;
    if (senderQr['ips'] is List) {
      ips = List<String>.from(senderQr['ips'] as List);
    } else if (senderQr['ip'] is String) {
      ips = [senderQr['ip'] as String];
    } else {
      throw Exception('No IP address in sender QR');
    }

    final port = senderQr['port'] as int? ?? 0;
    final senderPubBytes = base64Decode(senderQr['pub'] as String);
    final nonce = senderQr['nonce'] as String;

    String? reachableBase;
    for (final ip in ips) {
      try {
        final testSock = await Socket.connect(ip, port,
            timeout: const Duration(seconds: 4));
        testSock.destroy();
        reachableBase = 'http://$ip:$port';
        break;
      } catch (_) {}
    }

    if (reachableBase == null) {
      throw Exception(
          'Cannot reach sender. Make sure both devices are on the same network.');
    }

    final payload = utf8.encode(jsonEncode({
      'nonce': nonce,
      'receiver_qr': receiverQrJson,
    }));

    final error = await _post(
        '$reachableBase/fav_sync_handshake', payload, senderPubBytes);
    if (error != null) throw Exception('Handshake failed: $error');
  }

  // ─────────────────────────── SENDER ────────────────────────────────────────

  /// Send selected favorite chats to the receiver identified by [qrJson].
  /// Returns a stream of events. The method drives the entire transfer.
  static Stream<LanFavSyncEvent> sendFavorites({
    required String qrJson,
    required List<String> favIds,
  }) {
    final controller = StreamController<LanFavSyncEvent>();
    _runSend(qrJson, favIds, controller);
    return controller.stream;
  }

  static Future<void> _runSend(
    String qrJson,
    List<String> favIds,
    StreamController<LanFavSyncEvent> ctrl,
  ) async {
    void emit(LanFavSyncEvent e) { if (!ctrl.isClosed) ctrl.add(e); }
    Future<void> done() async { if (!ctrl.isClosed) await ctrl.close(); }

    Map<String, dynamic> qr;
    try {
      qr = jsonDecode(qrJson) as Map<String, dynamic>;
    } catch (_) {
      emit(LanFavSyncFatalError('Invalid QR format'));
      await done();
      return;
    }
    if (qr['v'] != 1 || qr['type'] != 'fav_sync') {
      emit(LanFavSyncFatalError('Not an Onyx favorite-sync QR code'));
      await done();
      return;
    }

    final List<String> ips;
    if (qr['ips'] is List) {
      ips = List<String>.from(qr['ips'] as List);
    } else if (qr['ip'] is String) {
      ips = [qr['ip'] as String];
    } else {
      emit(LanFavSyncFatalError('No IP address in QR payload'));
      await done();
      return;
    }

    final port = qr['port'] as int? ?? 0;
    final receiverPubBytes = base64Decode(qr['pub'] as String);
    final nonce = qr['nonce'] as String;

    // Generate an ephemeral X25519 key pair for streaming file transfers.
    // The receiver derives the same AES-256 stream key via ECDH when it sees
    // stream_pub in the /fav/meta payload, then uses it for /fav/file/stream.
    final streamKp = await _x25519.newKeyPair();
    final streamPubBytes = (await streamKp.extractPublicKey()).bytes;
    final streamShared = await _x25519.sharedSecretKey(
      keyPair: streamKp,
      remotePublicKey:
          SimplePublicKey(receiverPubBytes, type: KeyPairType.x25519),
    );
    final streamKey = SecretKey(WardLinkCrypto.hkdf(
      await streamShared.extractBytes(),
      utf8.encode('onyx-fav-stream-v1'),
      32,
    ));

    // Try IPs to find the receiver — up to 3 attempts with 1-second gaps to
    // survive a brief OS-firewall prompt or server-startup race condition.
    String? reachableBase;
    for (var attempt = 0; attempt < 3 && reachableBase == null; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 1));
      for (final ip in ips) {
        try {
          final testSock = await Socket.connect(ip, port,
              timeout: const Duration(seconds: 4));
          testSock.destroy();
          reachableBase = 'http://$ip:$port';
          if (kDebugMode) print('[FavSync] Reached receiver at $ip:$port');
          break;
        } catch (_) {
          if (kDebugMode) {
            print('[FavSync] $ip:$port unreachable (attempt ${attempt + 1})');
          }
        }
      }
    }

    if (reachableBase == null) {
      emit(LanFavSyncFatalError(
          'Cannot reach receiver. Make sure both devices are on the same network.'));
      await done();
      return;
    }

    final root = rootScreenKey.currentState;
    if (root == null) {
      emit(LanFavSyncFatalError('App not ready'));
      await done();
      return;
    }

    // ── Collect data ───────────────────────────────────────────────────────────
    emit(LanFavSyncStatus('Preparing data…'));

    final appDir = (await getOnyxSupportDirectory()).path;
    final favsToSend = root.favorites.where((f) => favIds.contains(f.id)).toList();

    if (favsToSend.isEmpty) {
      emit(LanFavSyncFatalError('No matching favorite chats found'));
      await done();
      return;
    }

    // Build meta payload: for each favorite, gather messages and file manifest
    final favPayloads = <Map<String, dynamic>>[];
    // key → local File path
    final filesToSend = <String, File>{};
    // key → type string
    final fileTypes = <String, String>{};

    for (final fav in favsToSend) {
      final chatId = 'fav:${fav.id}';
      final messages = root.chats[chatId] ?? [];
      final fileManifest = <Map<String, dynamic>>[];
      Map<String, dynamic>? avatarManifest;

      // Avatar
      if (fav.avatarPath != null) {
        final avatarFile = File(fav.avatarPath!);
        if (await avatarFile.exists()) {
          final key = 'avatar_${fav.id}${p.extension(fav.avatarPath!)}';
          final bytes = await avatarFile.readAsBytes();
          filesToSend[key] = avatarFile;
          fileTypes[key] = 'avatar';
          avatarManifest = {
            'key': key,
            'sha256': _sha256hex(bytes),
            'size': bytes.length,
          };
        }
      }

      // Media from messages
      for (final msg in messages) {
        final entries = await _extractFileEntries(msg.content, appDir);
        for (final entry in entries) {
          final entryFile = File(entry.path);
          filesToSend[entry.key] = entryFile;
          fileTypes[entry.key] = entry.type;
          final fileLen = await entryFile.length();
          // Stream sha256 for large files to avoid loading them into RAM twice
          // (once here for the manifest and again during transfer).
          final sha256 = fileLen > _streamThresholdBytes
              ? await _sha256hexStream(entryFile)
              : _sha256hex(await entryFile.readAsBytes());
          fileManifest.add({
            'key': entry.key,
            'sha256': sha256,
            'size': fileLen,
            'type': entry.type,
          });
        }
      }

      favPayloads.add({
        'meta': fav.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'files': fileManifest,
        if (avatarManifest != null) 'avatar': avatarManifest,
      });
    }

    final totalFiles = filesToSend.length;
    emit(LanFavSyncStatus(
        'Sending ${favsToSend.length} chat${favsToSend.length == 1 ? '' : 's'}'
        ' with $totalFiles file${totalFiles == 1 ? '' : 's'}…',
        current: 0, total: totalFiles));

    // ── POST /fav/meta ─────────────────────────────────────────────────────────
    final metaPlain = utf8.encode(jsonEncode({
      'nonce': nonce,
      'favorites': favPayloads,
      // Ephemeral pub for the receiver to derive the streaming AES-256 key.
      'stream_pub': base64Encode(streamPubBytes),
    }));

    final metaError = await _post(
        '$reachableBase/fav/meta', metaPlain, receiverPubBytes);
    if (metaError != null) {
      emit(LanFavSyncFatalError('Metadata transfer failed: $metaError'));
      await done();
      return;
    }

    // ── POST /fav/file or /fav/file/stream for each file ──────────────────────
    // Files ≤ _streamThresholdBytes: legacy base64-in-JSON (fine for small media).
    // Files > _streamThresholdBytes: AES-GCM streaming frames — no OOM on sender.
    int sent = 0;
    for (final entry in filesToSend.entries) {
      final key = entry.key;
      final file = entry.value;

      if (!await file.exists()) {
        emit(LanFavSyncFileResult(key,
            success: false, error: 'Local file not found'));
        continue;
      }

      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        emit(LanFavSyncFileResult(key,
            success: false,
            error: 'File too large (>${_maxFileSizeBytes ~/ 1024 ~/ 1024} MB), skipped'));
        continue;
      }

      emit(LanFavSyncStatus(
          'Sending ${p.basename(key)} (${_humanSize(fileSize)})…',
          current: sent, total: totalFiles));

      String? fileError;
      if (fileSize > _streamThresholdBytes) {
        // Auth blob: tiny ECDH envelope carrying {nonce, key} — sha256 is
        // already in the manifest the receiver has from /fav/meta, and AES-GCM
        // auth tags guarantee per-frame integrity without it.
        final authPayload = utf8.encode(jsonEncode({
          'nonce': nonce,
          'key': key,
          'size': fileSize,
        }));
        fileError = await _postFileStream(
            reachableBase, authPayload, receiverPubBytes, streamKey, file,
            onProgress: (bytesSent, totalBytes) {
              emit(LanFavSyncStatus(
                'Sending ${p.basename(key)} (${_humanSize(fileSize)})…',
                current: sent, total: totalFiles,
                bytesTransferred: bytesSent, fileBytes: totalBytes,
              ));
            });
      } else {
        final bytes = await file.readAsBytes();
        final filePlain = utf8.encode(jsonEncode({
          'nonce': nonce,
          'key': key,
          'sha256': _sha256hex(bytes),
          'data': base64Encode(bytes),
        }));
        fileError =
            await _post('$reachableBase/fav/file', filePlain, receiverPubBytes);
      }

      if (fileError != null) {
        emit(LanFavSyncFileResult(key, success: false, error: fileError));
      } else {
        sent++;
        emit(LanFavSyncFileResult(key, success: true));
        emit(LanFavSyncStatus(
            'Sent ${p.basename(key)} ($sent/$totalFiles)',
            current: sent, total: totalFiles));
      }
    }

    // ── POST /fav/done ─────────────────────────────────────────────────────────
    final donePlain = utf8.encode(jsonEncode({'nonce': nonce, 'ok': true}));
    final doneError = await _post(
        '$reachableBase/fav/done', donePlain, receiverPubBytes);
    if (doneError != null) {
      emit(LanFavSyncFatalError('Failed to confirm transfer: $doneError'));
      await done();
      return;
    }

    emit(LanFavSyncDone(
      favoritesCount: favsToSend.length,
      filesReceived: sent,
      filesSkipped: totalFiles - sent,
      fileErrors: const [],
      favorites: const [],
      chats: const {},
    ));

    // Clean up decrypted prep files
    try {
      final prepDir = Directory('$appDir/fav_sync_prep');
      if (await prepDir.exists()) await prepDir.delete(recursive: true);
    } catch (_) {}

    await done();
  }

  // ── HTTP helper ──────────────────────────────────────────────────────────────

  /// POST encrypted [plain] to [url]. Returns null on success, error string on failure.
  static Future<String?> _post(
      String url, List<int> plain, List<int> peerPub) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
    try {
      final encBody = await _encrypt(Uint8List.fromList(plain), peerPub);
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType = ContentType.json;
      req.contentLength = utf8.encode(encBody).length;
      req.write(encBody);
      final resp = await req.close().timeout(const Duration(minutes: 3));
      final respBody = await resp.transform(utf8.decoder).join();
      client.close();
      if (resp.statusCode == 200) return null;
      try {
        final j = jsonDecode(respBody) as Map<String, dynamic>;
        return j['error']?.toString() ?? 'HTTP ${resp.statusCode}';
      } catch (_) {
        return 'HTTP ${resp.statusCode}: $respBody';
      }
    } on SocketException catch (e) {
      client.close();
      return 'Network error: ${e.message}';
    } on TimeoutException {
      client.close();
      return 'Timed out sending to receiver';
    } catch (e) {
      client.close();
      return e.toString();
    }
  }

  // ── File extraction from message content ─────────────────────────────────────

  static Future<List<_FileEntry>> _extractFileEntries(
      String content, String appDir) async {
    final result = <_FileEntry>[];

    Future<void> tryAdd(String key, String type, String cacheSubdir) async {
      final basename = p.basename(key);

      // 1a. fav:// prefixed files live under applicationDocumentsDirectory
      if (key.startsWith('fav://')) {
        final docDir = (await getOnyxDocumentsDirectory()).path;
        final List<String> favCandidates;
        if (type == 'voice' || type == 'audio') {
          favCandidates = ['$docDir/voice_cache/$basename', '$docDir/fav_media/$basename'];
        } else {
          favCandidates = ['$docDir/fav_media/$basename'];
        }
        for (final fp in favCandidates) {
          if (await File(fp).exists()) {
            result.add(_FileEntry(key, fp, type));
            return;
          }
        }
      }

      // 1b. Plain file in app support cache
      final plainPath = '$appDir/$cacheSubdir/$basename';
      if (await File(plainPath).exists()) {
        result.add(_FileEntry(key, plainPath, type));
        return;
      }

      // 2. Runtime in-memory registries
      if (type == 'image') {
        final cached = imageFileCache[key] ?? imageFileCache[basename];
        if (cached != null && await cached.file.exists()) {
          result.add(_FileEntry(key, cached.file.path, type));
          return;
        }
      }
      final regPath = mediaFilePathRegistry[key] ?? mediaFilePathRegistry[basename];
      if (regPath != null && await File(regPath).exists()) {
        result.add(_FileEntry(key, regPath, type));
        return;
      }

      // 3. Temp display dir — decrypted copies left by MediaCache (volatile)
      final displayTypeName = switch (type) {
        'voice' => 'voice',
        'video' => 'video',
        'image' => 'image',
        'audio' => 'audio',
        _ => 'file',
      };
      final tempDir = await getTemporaryDirectory();
      final displayFile =
          File('${tempDir.path}/onyx_display/$displayTypeName/$basename');
      if (await displayFile.exists()) {
        result.add(_FileEntry(key, displayFile.path, type));
        return;
      }

      // 4. Encrypted .enc files — decrypt to a stable prep dir (not temp,
      //    which the OS can evict while the transfer is still running).
      // Voice messages may live in voice_cache rather than audio_cache.
      final encDirs = [cacheSubdir, if (type == 'voice') 'voice_cache'];
      final prepDir = Directory('$appDir/fav_sync_prep');
      await prepDir.create(recursive: true);
      for (final encDir in encDirs) {
        final encFile = File('$appDir/$encDir/$basename.enc');
        if (await encFile.exists()) {
          try {
            final encBytes = await encFile.readAsBytes();
            final plainBytes = await MediaCache.instance.decrypt(encBytes);
            final prepFile = File('$appDir/fav_sync_prep/$basename');
            await prepFile.writeAsBytes(plainBytes, flush: true);
            result.add(_FileEntry(key, prepFile.path, type));
            return;
          } catch (e) {
            if (kDebugMode) print('[FavSync] decrypt error for $basename: $e');
          }
        }
      }

      if (kDebugMode) print('[FavSync] File not found on sender: $key');
    }

    if (content.startsWith('IMAGEv1:')) {
      try {
        final d = jsonDecode(content.substring('IMAGEv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'image', 'image_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('ALBUMv1:')) {
      try {
        final list = jsonDecode(content.substring('ALBUMv1:'.length)) as List;
        for (final item in list.cast<Map<String, dynamic>>()) {
          final fn = (item['filename'] ?? item['orig'])?.toString() ?? '';
          if (fn.isNotEmpty) await tryAdd(fn, 'image', 'image_cache');
        }
      } catch (_) {}
      return result;
    }

    if (content.toUpperCase().startsWith('VIDEOV1:')) {
      try {
        final d = jsonDecode(content.substring('VIDEOv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'video', 'video_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('VOICEv1:')) {
      try {
        final d = jsonDecode(content.substring('VOICEv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'voice', 'audio_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('AUDIOv1:')) {
      try {
        final d = jsonDecode(content.substring('AUDIOv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'audio', 'audio_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('FILEv1:')) {
      try {
        final d = jsonDecode(content.substring('FILEv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'file', 'data_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('DOCUMENTv1:')) {
      try {
        final d = jsonDecode(content.substring('DOCUMENTv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'document', 'document_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('ARCHIVEv1:')) {
      try {
        final d = jsonDecode(content.substring('ARCHIVEv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'archive', 'archive_cache');
      } catch (_) {}
      return result;
    }

    if (content.startsWith('DATAv1:')) {
      try {
        final d = jsonDecode(content.substring('DATAv1:'.length)) as Map<String, dynamic>;
        final fn = (d['filename'] ?? d['orig'])?.toString() ?? '';
        if (fn.isNotEmpty) await tryAdd(fn, 'file', 'data_cache');
      } catch (_) {}
      return result;
    }

    return result;
  }

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  // Files larger than this are transferred via /fav/file/stream (WardLink-style
  // AES-GCM frames) instead of base64-in-JSON, preventing OOM on the sender.
  static const int _streamThresholdBytes = 5 * 1024 * 1024; // 5 MB

  /// Compute SHA-256 of [file] without loading it fully into memory.
  static Future<String> _sha256hexStream(File file) async {
    dart_crypto.Digest? digest;
    final sink = dart_crypto.sha256.startChunkedConversion(
      ChunkedConversionSink<dart_crypto.Digest>.withCallback(
          (d) => digest = d.single),
    );
    final raf = await file.open();
    try {
      while (true) {
        final chunk = await raf.read(64 * 1024);
        if (chunk.isEmpty) break;
        sink.add(chunk);
      }
    } finally {
      await raf.close();
    }
    sink.close();
    return digest?.toString() ?? '';
  }

  /// Stream [file] to [base]/fav/file/stream as WardLink AES-GCM frames.
  /// The [authPayload] bytes are ECDH-encrypted into the X-Fav-Auth header
  /// so the receiver can validate the session nonce before accepting the body.
  static Future<String?> _postFileStream(
    String base,
    List<int> authPayload,
    List<int> receiverPub,
    SecretKey streamKey,
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      // Encrypt tiny auth blob (nonce + key) with one-off ECDH.
      final authEnc = await _encrypt(Uint8List.fromList(authPayload), receiverPub);
      final authB64 = base64Encode(utf8.encode(authEnc));

      final plainSize = await file.length();
      final req = await client.postUrl(Uri.parse('$base/fav/file/stream'));
      req.headers.set('x-fav-auth', authB64);
      req.headers.set('x-wardlink-size', '$plainSize');
      req.headers.contentType = ContentType.binary;

      // Stream file in 64 KB chunks — each chunk is independently AES-GCM
      // sealed, so memory usage is bounded to ~one chunk at a time.
      int bytesSent = 0;
      int lastPct = -1;
      final raf = await file.open();
      try {
        while (true) {
          final chunk = await raf.read(64 * 1024);
          if (chunk.isEmpty) break;
          req.add(await WardLinkCrypto.sealFrame(chunk, streamKey));
          await req.flush();
          bytesSent += chunk.length;
          // Throttle to 1% increments so we don't spam the UI.
          if (onProgress != null && plainSize > 0) {
            final pct = bytesSent * 100 ~/ plainSize;
            if (pct != lastPct) {
              lastPct = pct;
              onProgress(bytesSent, plainSize);
            }
          }
        }
        req.add(WardLinkCrypto.terminatorFrame());
        await req.flush();
      } finally {
        await raf.close();
      }

      final resp = await req.close().timeout(const Duration(minutes: 30));
      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 200) return null;
      try {
        final j = jsonDecode(respBody) as Map<String, dynamic>;
        return j['error']?.toString() ?? 'HTTP ${resp.statusCode}';
      } catch (_) {
        return 'HTTP ${resp.statusCode}';
      }
    } on SocketException catch (e) {
      return 'Network error: ${e.message}';
    } on TimeoutException {
      return 'Timed out sending file';
    } catch (e) {
      return e.toString();
    } finally {
      client.close();
    }
  }
}

class _FileEntry {
  final String key;
  final String path;
  final String type;
  _FileEntry(this.key, this.path, this.type);
}
