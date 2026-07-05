// lib/services/wardlink/wardlink_sync_service.dart
//
// WardLink — passive local-network synchronisation between manually-paired
// devices. When enabled, each device runs a small encrypted HTTP daemon and
// broadcasts its presence over UDP. When it spots a *paired* device (one whose
// identity public key the user confirmed via QR) belonging to the same account
// on the LAN, it pulls whatever messages and media it is missing.
//
// Convergence model: both sides pull. A pulls what it lacks from B, and B
// independently pulls what it lacks from A, so the two states converge without
// any central coordinator. Everything is deduplicated by message id.
//
// Transport: HTTP over the LAN, application-layer E2EE (static-static X25519
// ECDH between the two identity keys → AES-256-GCM). Large media is streamed in
// independently-sealed frames so a multi-gigabyte file is never fully buffered
// or base64-expanded in memory. See [WardLinkCrypto].
//
// Background note: a listening socket + UDP discovery only run reliably while
// the app is foregrounded on iOS/Android; desktop runs it continuously. Sync is
// therefore "passive while the app is active" on mobile, continuous on desktop.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../globals.dart';
import 'wardlink_media.dart';
import '../../managers/decoy_manager.dart';
import '../../managers/settings_manager.dart';
import '../../models/chat_message.dart';
import '../../models/favorite_chat.dart';
import '../lan_fav_sync_service.dart';
import 'wardlink_crypto.dart';
import 'wardlink_identity.dart';
import 'wardlink_paired_devices.dart';
import 'wardlink_tombstones.dart';
import 'wardlink_pending_deletions.dart';

class WardLinkStatus {
  final bool running;
  final bool syncing;
  final String message;
  final DateTime? lastSyncAt;

  /// Name of the device we're currently syncing with (for display).
  final String? peerName;

  /// The media file currently transferring, and its byte progress.
  final String? currentFile;
  final int bytesReceived;
  final int bytesTotal;

  /// Files transferred so far this session, and the per-file log (newest last).
  final int filesDone;
  final List<WardLinkFileEntry> files;

  /// Per-chat breakdown: which chats were synced and which files they needed.
  final List<WardLinkChatSyncEntry> chatEntries;

  /// True when the most recent completed sync ended with an error.
  final bool lastSyncFailed;

  const WardLinkStatus({
    this.running = false,
    this.syncing = false,
    this.message = '',
    this.lastSyncAt,
    this.peerName,
    this.currentFile,
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.filesDone = 0,
    this.files = const [],
    this.chatEntries = const [],
    this.lastSyncFailed = false,
  });

  /// 0..1 progress of the current file, or null when size is unknown.
  double? get fileProgress =>
      bytesTotal > 0 ? (bytesReceived / bytesTotal).clamp(0.0, 1.0) : null;
}

class WardLinkFileEntry {
  final String name;
  final bool done;
  final bool error;
  const WardLinkFileEntry(this.name, {this.done = false, this.error = false});
}

/// Tracks sync state for one favourite chat.
class WardLinkChatSyncEntry {
  final String chatId;
  final String title;
  final int newMessages;
  final List<WardLinkFileEntry> files;
  const WardLinkChatSyncEntry({
    required this.chatId,
    required this.title,
    required this.newMessages,
    required this.files,
  });

  WardLinkChatSyncEntry withFile(WardLinkFileEntry f) =>
      WardLinkChatSyncEntry(
        chatId: chatId,
        title: title,
        newMessages: newMessages,
        files: [...files, f],
      );

  WardLinkChatSyncEntry updateFile(String name, {bool done = false, bool error = false}) {
    final updated = files.map((f) {
      if (f.name == name && !f.done && !f.error) {
        return WardLinkFileEntry(name, done: done, error: error);
      }
      return f;
    }).toList();
    return WardLinkChatSyncEntry(
      chatId: chatId, title: title, newMessages: newMessages, files: updated,
    );
  }
}

enum WardLinkLogLevel { info, warn, error }

class WardLinkLogEntry {
  final DateTime time;
  final WardLinkLogLevel level;
  final String message;
  WardLinkLogEntry(this.level, this.message) : time = DateTime.now();
}

/// Thrown by [_post] when the peer responds with HTTP 403 — meaning it no
/// longer considers this device trusted (it removed us from its list).
class _WardLinkRejectedException implements Exception {}

class WardLinkSyncService {
  WardLinkSyncService._();
  static final WardLinkSyncService instance = WardLinkSyncService._();

  static String? _cachedDeviceName;
  static Future<String> _getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        _cachedDeviceName = '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        _cachedDeviceName = info.utsname.machine;
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        _cachedDeviceName = info.computerName;
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        _cachedDeviceName = info.computerName;
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        _cachedDeviceName = info.prettyName;
      }
    } catch (_) {}
    return _cachedDeviceName ?? Platform.localHostname;
  }

  static const int discoveryPort = 45680;
  // Fixed TCP port for the sync HTTP server — a stable port lets OS firewalls
  // create a permanent rule (and lets us auto-create one on Windows).
  static const int syncPort = 47832;
  static const int _protocolVersion = 1;

  /// Don't re-sync with the same peer more often than this.
  static const Duration _syncDebounce = Duration(seconds: 30);

  final ValueNotifier<WardLinkStatus> status =
      ValueNotifier<WardLinkStatus>(const WardLinkStatus());

  /// Rolling diagnostic log (info + errors), surfaced by long-pressing the
  /// sync bubble. Kept across sessions so a past failure can still be inspected.
  final ValueNotifier<List<WardLinkLogEntry>> log =
      ValueNotifier<List<WardLinkLogEntry>>(const []);

  // Reason of the most recent failed file download, for the log.
  String? _lastDownloadError;

  void _log(WardLinkLogLevel level, String message) {
    final list = List<WardLinkLogEntry>.from(log.value)
      ..add(WardLinkLogEntry(level, message));
    if (list.length > 200) list.removeRange(0, list.length - 200);
    log.value = list;
    if (kDebugMode) print('[WardLink] $message');
  }

  HttpServer? _server;
  int _syncPort = 0;
  RawDatagramSocket? _discoverySocket;
  Timer? _broadcastTimer;
  String? _username;
  bool _starting = false;

  final Set<String> _activeSyncs = {};            // peer pub → in-flight
  // Peers that sent a poke while we were already syncing with them — resync
  // as soon as the current sync finishes so the new message isn't skipped.
  final Set<String> _pendingResync = {};
  // Files that returned 404 from a specific peer in this session.
  // Key format: "$peerPub\x00$fileKey". Prevents infinite retry of files
  // the peer simply doesn't have — cleared when the service restarts.
  final Set<String> _peerMissingFiles = {};

  // A single sync that would newly delete more than this many favourites is
  // treated as a bulk-delete event: it's quarantined for user review instead
  // of being applied automatically (safe-by-default mass-delete guard).
  static const int _bulkDeleteThreshold = 5;
  final Map<String, DateTime> _lastSyncByPeer = {}; // peer pub → last attempt
  final Set<String> _seenThisSession = {};          // peers pulled since start
  // Last known LAN address for each peer, keyed by identity pub (base64).
  final Map<String, ({InternetAddress ip, int port})> _peerAddresses = {};
  DateTime _lastSolicitResponse = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pokeDebounce;

  bool get isRunning => _server != null;

  // ─────────────────────────── lifecycle ────────────────────────────────────

  /// Start the daemon + discovery for [username]. Safe to call repeatedly.
  ///
  /// Refuses to start while a decoy session is active: WardLink would
  /// otherwise broadcast and sync the real account's identity/data on the
  /// LAN while the UI shows the decoy account, leaking the real account to
  /// any paired device.
  Future<void> start(String username) async {
    if (DecoyManager.isActive.value) {
      if (kDebugMode) print('[WardLink] start refused: decoy mode active');
      return;
    }
    if (_starting) return;
    if (isRunning && _username == username) return;
    _starting = true;
    try {
      await stop();
      _username = username;

      await WardLinkIdentity.ensureLoaded();
      await WardLinkPairedDevices.load(username);
      await WardLinkPendingDeletions.load(username);

      _server = await HttpServer.bind(InternetAddress.anyIPv4, syncPort);
      _syncPort = _server!.port;
      _server!.listen(_handleRequest, onError: (e) {
        if (kDebugMode) print('[WardLink] server error: $e');
      });

      // On Windows, auto-add an inbound firewall rule for the sync port so the
      // phone can reach us without the user having to configure the firewall.
      if (!kIsWeb && Platform.isWindows) {
        unawaited(_ensureWindowsFirewallRule());
      }

      await _startDiscovery();

      _seenThisSession.clear();
      _broadcastTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _broadcast());

      // On joining the network, solicit a few times in the first seconds so we
      // and every paired peer discover each other and sync right away, instead
      // of waiting for the next periodic announce.
      for (final ms in const [0, 400, 1200, 3000]) {
        Timer(Duration(milliseconds: ms), () => _broadcast(solicit: true));
      }

      // Push: nudge paired devices the moment local data changes.
      chatsVersion.addListener(_onLocalChange);
      favoritesVersion.addListener(_onLocalChange);

      _setStatus(running: true, message: 'WardLink active');
      if (kDebugMode) {
        print('[WardLink] started on port $_syncPort for $username');
      }
    } catch (e) {
      if (kDebugMode) print('[WardLink] start failed: $e');
      await stop();
    } finally {
      _starting = false;
    }
  }

  Future<void> stop() async {
    chatsVersion.removeListener(_onLocalChange);
    favoritesVersion.removeListener(_onLocalChange);
    _pokeDebounce?.cancel();
    _pokeDebounce = null;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _activeSyncs.clear();
    _pendingResync.clear();
    _lastSyncByPeer.clear();
    _seenThisSession.clear();
    _peerMissingFiles.clear();
    _setStatus(running: false, message: '');
  }

  void _setStatus({
    bool? running,
    bool? syncing,
    String? message,
    DateTime? lastSyncAt,
    String? peerName,
    Object? currentFile = _unset,
    int? bytesReceived,
    int? bytesTotal,
    int? filesDone,
    List<WardLinkFileEntry>? files,
    List<WardLinkChatSyncEntry>? chatEntries,
    bool? lastSyncFailed,
  }) {
    final cur = status.value;
    status.value = WardLinkStatus(
      running: running ?? cur.running,
      syncing: syncing ?? cur.syncing,
      message: message ?? cur.message,
      lastSyncAt: lastSyncAt ?? cur.lastSyncAt,
      peerName: peerName ?? cur.peerName,
      currentFile:
          currentFile == _unset ? cur.currentFile : currentFile as String?,
      bytesReceived: bytesReceived ?? cur.bytesReceived,
      bytesTotal: bytesTotal ?? cur.bytesTotal,
      filesDone: filesDone ?? cur.filesDone,
      files: files ?? cur.files,
      chatEntries: chatEntries ?? cur.chatEntries,
      lastSyncFailed: lastSyncFailed ?? cur.lastSyncFailed,
    );
  }

  // Sentinel so callers can explicitly clear currentFile (pass null) vs leave it.
  static const Object _unset = Object();

  // Throttle for per-chunk transfer progress: status updates drive setState()
  // in the floating sync bubble (and any open detail dialog), so emitting one
  // per 64 KB chunk forces far more rebuilds than the UI can usefully show,
  // competing with file I/O and crypto for the same isolate. Emitting at most
  // a few times a second is plenty for a progress bar.
  static const Duration _progressEmitInterval = Duration(milliseconds: 120);
  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);

  void _setProgressStatus(String? name, int received, int total) {
    final now = DateTime.now();
    final isFinal = total > 0 && received >= total;
    if (!isFinal &&
        now.difference(_lastProgressEmit) < _progressEmitInterval) {
      return;
    }
    _lastProgressEmit = now;
    _setStatus(currentFile: name, bytesReceived: received, bytesTotal: total);
  }

  // Per-session file transfer log, surfaced to the bubble UI.
  final List<WardLinkFileEntry> _fileLog = [];
  int _filesDone = 0;

  void _resetFileLog() {
    _fileLog.clear();
    _filesDone = 0;
    _chatEntries.clear();
    _setStatus(files: const [], filesDone: 0, chatEntries: const []);
  }

  // Per-session chat-level tracking.
  final List<WardLinkChatSyncEntry> _chatEntries = [];

  void _chatBegin(String chatId, String title, int newMessages) {
    _chatEntries.removeWhere((e) => e.chatId == chatId);
    _chatEntries.add(WardLinkChatSyncEntry(
        chatId: chatId, title: title, newMessages: newMessages, files: []));
    _setStatus(chatEntries: List.of(_chatEntries));
  }

  void _chatAddFile(String chatId, WardLinkFileEntry f) {
    for (int i = 0; i < _chatEntries.length; i++) {
      if (_chatEntries[i].chatId == chatId) {
        _chatEntries[i] = _chatEntries[i].withFile(f);
        break;
      }
    }
    _setStatus(chatEntries: List.of(_chatEntries));
  }

  void _chatUpdateFile(String chatId, String name,
      {bool done = false, bool error = false}) {
    for (int i = 0; i < _chatEntries.length; i++) {
      if (_chatEntries[i].chatId == chatId) {
        _chatEntries[i] =
            _chatEntries[i].updateFile(name, done: done, error: error);
        break;
      }
    }
    _setStatus(chatEntries: List.of(_chatEntries));
  }

  void _fileStart(String name) {
    _fileLog.add(WardLinkFileEntry(name));
    _setStatus(files: List.of(_fileLog), filesDone: _filesDone);
  }

  void _fileDone(String name, {bool ok = true}) {
    for (int i = _fileLog.length - 1; i >= 0; i--) {
      if (_fileLog[i].name == name && !_fileLog[i].done) {
        _fileLog[i] = WardLinkFileEntry(name, done: true);
        break;
      }
    }
    if (ok) _filesDone++;
    _setStatus(files: List.of(_fileLog), filesDone: _filesDone);
  }

  // ─────────────────────────── discovery ────────────────────────────────────

  Future<void> _startDiscovery() async {
    try {
      _discoverySocket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _discoverySocket!.broadcastEnabled = true;
      _discoverySocket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = _discoverySocket!.receive();
        if (dg == null) return;
        _onDiscovery(dg.address, dg.data);
      });
    } catch (e) {
      if (kDebugMode) print('[WardLink] discovery bind failed: $e');
    }
  }

  Future<void> _broadcast({bool poke = false, bool solicit = false}) async {
    if (!isRunning || _username == null) return;
    if (DecoyManager.isActive.value) return;
    final msg = utf8.encode(jsonEncode({
      'type': 'wardlink',
      'v': _protocolVersion,
      'pub': WardLinkIdentity.publicKeyB64,
      'username': _username,
      'syncPort': _syncPort,
      'name': await _getDeviceName(),
      'os': Platform.operatingSystem,
      // A poke means "I just changed something — pull now, skip the debounce".
      if (poke) 'poke': true,
      // A solicit means "I just joined — everyone announce yourselves now".
      if (solicit) 'solicit': true,
    }));

    List<NetworkInterface> ifaces = [];
    try {
      ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
    } catch (_) {}
    final addrs = ifaces.expand((i) => i.addresses).toList();
    if (addrs.isEmpty) addrs.add(InternetAddress.anyIPv4);

    for (final addr in addrs) {
      try {
        final s = await RawDatagramSocket.bind(addr, 0);
        s.broadcastEnabled = true;
        s.send(msg, InternetAddress('255.255.255.255'), discoveryPort);
        await Future.delayed(const Duration(milliseconds: 30));
        s.close();
      } catch (_) {}
    }
  }

  void _onDiscovery(InternetAddress from, Uint8List data) {
    if (!SettingsManager.wardLinkEnabled.value) return;
    if (DecoyManager.isActive.value) return;
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (j['type'] != 'wardlink') return;

    final peerPub = j['pub'] as String?;
    final peerUser = j['username'] as String?;
    final peerPort = j['syncPort'] as int?;
    if (peerPub == null || peerPort == null) return;

    // Ignore ourselves and other accounts.
    if (peerPub == WardLinkIdentity.publicKeyB64) return;
    if (peerUser != _username) return;

    // Only ever sync with devices the user explicitly paired.
    if (!WardLinkPairedDevices.isTrusted(peerPub)) return;

    // Always refresh the cached address so sendUnpair can reach this peer.
    _peerAddresses[peerPub] = (ip: from, port: peerPort);

    // A peer that just joined asks everyone to announce — reply with our own
    // presence (rate-limited) so it discovers us immediately, not in 5s.
    final isSolicit = j['solicit'] == true;
    if (isSolicit) {
      if (DateTime.now().difference(_lastSolicitResponse) >
          const Duration(milliseconds: 800)) {
        _lastSolicitResponse = DateTime.now();
        unawaited(_broadcast());
      }
    }

    final isPoke = j['poke'] == true;

    if (_activeSyncs.contains(peerPub)) {
      // A poke that arrives while we're already syncing with this peer means a
      // new message was sent during the in-flight sync. Queue a follow-up so
      // we don't miss it.
      if (isPoke) _pendingResync.add(peerPub);
      return;
    }

    // Pull immediately on first contact this session (just came online), on a
    // poke ("I just changed something"), or on a solicit (peer just joined —
    // it may carry data for us); otherwise fall back to the periodic, debounced
    // presence-driven sync.
    final firstContact = !_seenThisSession.contains(peerPub);
    if (!isPoke && !isSolicit && !firstContact) {
      final last = _lastSyncByPeer[peerPub];
      if (last != null && DateTime.now().difference(last) < _syncDebounce) {
        return;
      }
    }

    _seenThisSession.add(peerPub);
    _lastSyncByPeer[peerPub] = DateTime.now();
    unawaited(_syncWithPeer(from.address, peerPort, peerPub));
  }

  /// Public entry so the UI can force an immediate broadcast/sync attempt.
  Future<void> refresh() => _broadcast();

  /// Immediately tell paired devices to pull — used right after a deletion so
  /// the removal propagates without waiting for the debounced change-poke.
  Future<void> pokeNow() async {
    if (!isRunning) return;
    await _broadcast(poke: true);
  }

  /// Notifies [peerPubB64] over LAN to remove us from its paired-devices list,
  /// then removes [peerPubB64] locally. Works silently if the peer is offline.
  Future<void> sendUnpair(String peerPubB64) async {
    final addr = _peerAddresses[peerPubB64];
    if (addr != null && isRunning) {
      try {
        final key = await WardLinkCrypto.deriveSessionKey(
            WardLinkIdentity.keyPair, base64Decode(peerPubB64));
        await _post(
          'http://${addr.ip.address}:${addr.port}',
          '/wardlink/unpair',
          key,
          {'pub': WardLinkIdentity.publicKeyB64},
        ).timeout(const Duration(seconds: 4));
      } catch (_) {
        // Peer offline or unreachable — proceed with local removal only.
      }
    }
    _peerAddresses.remove(peerPubB64);
    _seenThisSession.remove(peerPubB64);
    await WardLinkPairedDevices.remove(peerPubB64);
  }

  /// Triggers an immediate re-sync with a peer using the new watermark.
  /// If the peer's address is cached, syncs right away; otherwise broadcasts
  /// a solicit so the peer announces itself and we sync on its reply.
  Future<void> triggerResync(String identityPubB64) async {
    _seenThisSession.remove(identityPubB64);
    final addr = _peerAddresses[identityPubB64];
    if (addr != null) {
      _seenThisSession.add(identityPubB64);
      _lastSyncByPeer[identityPubB64] = DateTime.now();
      unawaited(_syncWithPeer(addr.ip.address, addr.port, identityPubB64));
    } else {
      unawaited(_broadcast(solicit: true));
    }
  }

  // Local Favorites changed → poke paired devices so they pull right away.
  // Debounced so a burst of changes (e.g. an import) collapses into one poke.
  void _onLocalChange() {
    if (!isRunning) return;
    _pokeDebounce?.cancel();
    _pokeDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_broadcast(poke: true));
    });
  }

  // ─────────────────────────── pairing ──────────────────────────────────────

  // A fresh nonce backing the QR currently shown by the "add device" screen.
  // A peer proves it scanned our QR by echoing this nonce to /wardlink/pair.
  String? _pairingNonce;

  static Future<List<String>> localIps() async {
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

  /// Build the QR payload shown by the device that wants to be paired. The
  /// daemon must already be running (call [start] first).
  Future<String> pairingQrJson(String username) async {
    final nonce = base64Encode(
        List.generate(16, (_) => DateTime.now().microsecond % 256));
    _pairingNonce = nonce;
    return jsonEncode({
      'type': 'wardlink_pair',
      'v': _protocolVersion,
      'pub': WardLinkIdentity.publicKeyB64,
      'deviceId': WardLinkIdentity.deviceId,
      'name': await _getDeviceName(),
      'os': Platform.operatingSystem,
      'username': username,
      'ips': await localIps(),
      'port': _syncPort,
      'nonce': nonce,
    });
  }

  /// Called on the scanning device after it reads a `wardlink_pair` QR. Pins the
  /// shown device as trusted, then notifies it over LAN so it trusts us back —
  /// establishing mutual trust from a single scan. Returns null on success or an
  /// error string.
  Future<String?> completePairingFromQr(String qrJson, String username) async {
    Map<String, dynamic> qr;
    try {
      qr = jsonDecode(qrJson) as Map<String, dynamic>;
    } catch (_) {
      return 'Invalid QR code';
    }
    if (qr['type'] != 'wardlink_pair') return 'Not a WardLink pairing code';
    if (qr['username'] != username) {
      return 'That code belongs to a different account';
    }
    final peerPub = qr['pub'] as String?;
    final nonce = qr['nonce'] as String?;
    final port = qr['port'] as int?;
    if (peerPub == null || nonce == null || port == null) {
      return 'Malformed pairing code';
    }
    if (peerPub == WardLinkIdentity.publicKeyB64) {
      return 'Cannot pair a device with itself';
    }

    final ips = (qr['ips'] as List?)?.cast<String>() ?? const [];

    // Pin the shown device locally first.
    // syncFromBeginning=true so the first sync pulls full history; markSynced
    // resets it to false afterwards so only new messages are synced going forward.
    await WardLinkPairedDevices.add(PairedDevice(
      deviceId: (qr['deviceId'] as String?) ?? '',
      identityPubB64: peerPub,
      name: (qr['name'] as String?) ?? 'Device',
      os: (qr['os'] as String?) ?? 'unknown',
      pairedAt: DateTime.now(),
      syncFromBeginning: true,
    ));

    // Tell the shown device about us so it trusts us back.
    final key = await WardLinkCrypto.deriveSessionKey(
        WardLinkIdentity.keyPair, base64Decode(peerPub));
    String? lastError = 'Could not reach the other device';
    for (final ip in ips) {
      try {
        final res = await _post('http://$ip:$port', '/wardlink/pair', key, {
          'nonce': nonce,
          'pub': WardLinkIdentity.publicKeyB64,
          'deviceId': WardLinkIdentity.deviceId,
          'name': await _getDeviceName(),
          'os': Platform.operatingSystem,
        });
        if (res != null && res['ok'] == true) {
          unawaited(refresh());
          return null;
        }
      } on _WardLinkRejectedException {
        // The other device rejected the nonce (QR may be stale or already used).
        lastError = 'Pairing rejected — try scanning a fresh QR code';
      }
    }
    // Pairing failed — roll back the optimistic add so no stale entry remains.
    await WardLinkPairedDevices.remove(peerPub);
    return lastError;
  }

  Future<void> _handlePair(
      HttpRequest req, String callerPub, SecretKey key) async {
    final body = await utf8.decoder.bind(req).join();
    final payload = await WardLinkCrypto.decryptJson(body, key);
    final nonce = _pairingNonce;
    if (payload == null || nonce == null || payload['nonce'] != nonce) {
      req.response.statusCode = 403;
      await req.response.close();
      return;
    }
    await WardLinkPairedDevices.add(PairedDevice(
      deviceId: (payload['deviceId'] as String?) ?? '',
      identityPubB64: callerPub,
      name: (payload['name'] as String?) ?? 'Device',
      os: (payload['os'] as String?) ?? 'unknown',
      pairedAt: DateTime.now(),
      syncFromBeginning: true,
    ));
    _pairingNonce = null; // single-use
    final enc = await WardLinkCrypto.encryptJson({'ok': true}, key);
    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.json;
    req.response.write(enc);
    await req.response.close();
  }

  Future<void> _handleUnpair(HttpRequest req, String callerPub) async {
    final paired = WardLinkPairedDevices.byPub(callerPub);
    final key = paired != null
        ? await WardLinkCrypto.deriveSessionKey(
            WardLinkIdentity.keyPair, paired.identityPub)
        : null;
    await WardLinkPairedDevices.remove(callerPub);
    _peerAddresses.remove(callerPub);
    _seenThisSession.remove(callerPub);
    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.json;
    if (key != null) {
      req.response.write(await WardLinkCrypto.encryptJson({'ok': true}, key));
    } else {
      req.response.write('{}');
    }
    await req.response.close();
  }

  // ─────────────────────────── initiator (pull) ─────────────────────────────

  static int _msgMillis(dynamic t) =>
      t is int ? t : (int.tryParse('$t') ?? 0);

  Future<void> _syncWithPeer(String host, int port, String peerPubB64) async {
    if (_activeSyncs.contains(peerPubB64)) return;
    final paired = WardLinkPairedDevices.byPub(peerPubB64);
    if (paired == null) return;
    _activeSyncs.add(peerPubB64);
    _resetFileLog();
    _log(WardLinkLogLevel.info, 'Sync started with ${paired.name}');
    _setStatus(
        syncing: true,
        peerName: paired.name,
        currentFile: null,
        message: 'Syncing with ${paired.name}…');

    // Raised inside the try block when new data was imported; read after the
    // finally block so pokeNow() fires AFTER _activeSyncs removes this peer.
    // Calling pokeNow() while the peer is still in _activeSyncs would make
    // their response land in _pendingResync → immediate re-sync → infinite loop.
    bool pokeAfterSync = false;

    try {
      final key = await WardLinkCrypto.deriveSessionKey(
          WardLinkIdentity.keyPair, paired.identityPub);
      final base = 'http://$host:$port';

      // 1. Pull the peer's Favorites manifest.
      final manifestResp =
          await _post(base, '/wardlink/manifest', key, const {});
      if (manifestResp == null) {
        _log(WardLinkLogLevel.error,
            'No manifest from ${paired.name} (unreachable?)');
        return;
      }
      final chatsManifest =
          (manifestResp['chats'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final root = rootScreenKey.currentState;
      if (root == null) return;

      // Auto-mesh: adopt trusted peers the hub introduced us to so we form a
      // full mesh without requiring additional QR scans.
      final meshPeers =
          (manifestResp['meshPeers'] as List?)?.cast<Map<String, dynamic>>();
      if (meshPeers != null) {
        for (final p in meshPeers) {
          final pub = p['pub'] as String?;
          if (pub == null || pub == WardLinkIdentity.publicKeyB64) continue;
          if (WardLinkPairedDevices.isTrusted(pub)) continue;
          final newPeer = PairedDevice(
            deviceId: (p['deviceId'] as String?) ?? pub.substring(0, 8),
            identityPubB64: pub,
            name: (p['name'] as String?) ?? 'Device',
            os: (p['os'] as String?) ?? 'unknown',
            pairedAt: DateTime.now(),
            syncFromBeginning: true,
          );
          await WardLinkPairedDevices.add(newPeer);
          _log(WardLinkLogLevel.info,
              'Auto-meshed with ${newPeer.name} via ${paired.name}');
          final ip = p['ip'] as String?;
          final port = p['port'] as int?;
          if (ip != null && port != null) {
            _peerAddresses[pub] =
                (ip: InternetAddress(ip), port: port);
            // Kick off an immediate sync so we get their data right away.
            unawaited(_syncWithPeer(ip, port, pub));
          }
        }
      }

      // Apply the peer's deletions — but guarded. Two safety layers:
      //  1) Time gate: ignore tombstones created BEFORE we paired with this
      //     peer. A device's own pre-pairing deletions are its history, not an
      //     instruction to wipe data we independently kept. (This is exactly
      //     what caused the mass loss: a freshly-paired device carried old
      //     "delete" records that flooded the established fleet.)
      //  2) Bulk guard: if a single sync would still newly delete more than
      //     [_bulkDeleteThreshold] favourites, quarantine them for user review
      //     instead of applying. Non-destructive message deletions are still
      //     absorbed so surviving chats stay in sync.
      final remoteTomb = manifestResp['tombstones'];
      if (remoteTomb is Map<String, dynamic>) {
        final minTs = paired.pairedAt.millisecondsSinceEpoch;
        final kept = WardLinkPendingDeletions.keptFavs;
        final newFavCount = WardLinkTombstones.countNewFavs(remoteTomb,
            minTs: minTs, keptFavs: kept);

        if (newFavCount > _bulkDeleteThreshold) {
          final applicable = WardLinkTombstones.applicableNewFavs(remoteTomb,
              minTs: minTs, keptFavs: kept);
          final learned = WardLinkTombstones.merge(remoteTomb,
              skipFavs: true, minTs: minTs);
          if (learned.msgsByChat.isNotEmpty) {
            root.applyRemoteDeletions(const <String>{}, learned.msgsByChat);
          }
          await WardLinkPendingDeletions.record(
              peerPubB64, paired.name, applicable);
          _log(
              WardLinkLogLevel.warn,
              'Held a bulk delete from ${paired.name} '
              '($newFavCount favourites) for your review in Recycle bin');
        } else {
          final learned = WardLinkTombstones.merge(remoteTomb,
              minTs: minTs, keptFavs: kept);
          if (learned.favIds.isNotEmpty || learned.msgsByChat.isNotEmpty) {
            root.applyRemoteDeletions(learned.favIds, learned.msgsByChat);
          }
        }

        // Zombie healing: merge() only reports *newly* learned tombstones, so
        // previously-known msg tombstones are never re-applied — even when the
        // deleted message reappeared as a zombie (e.g. stale SQLite rows
        // reloaded on restart). Scan all remote msg tombstones that pass the
        // minTs gate and re-apply any whose target message still exists locally.
        final remoteMsg = remoteTomb['msg'];
        if (remoteMsg is Map) {
          final zombieMsgs = <String, Set<String>>{};
          remoteMsg.forEach((k, v) {
            final compound = '$k';
            final ts = (v as num).toInt();
            if (ts < minTs) return;
            final sep = compound.indexOf(' ');
            if (sep <= 0) return;
            final chatId = compound.substring(0, sep);
            final msgId = compound.substring(sep + 1);
            // Only interested in already-known tombstones (new ones were already
            // handled above by merge + applyRemoteDeletions).
            if (!WardLinkTombstones.isMsgDeleted(chatId, msgId)) return;
            final local = root.chats[chatId];
            if (local == null || !local.any((m) => m.id == msgId)) return;
            (zombieMsgs[chatId] ??= <String>{}).add(msgId);
          });
          if (zombieMsgs.isNotEmpty) {
            _log(WardLinkLogLevel.info,
                'Zombie heal: re-applying ${zombieMsgs.values.fold(0, (s, v) => s + v.length)} '
                'previously-deleted message(s) that reappeared locally');
            root.applyRemoteDeletions(const <String>{}, zombieMsgs);
          }
        }
      }

      int importedMsgs = 0;
      int importedFiles = 0;
      int importedFavs = 0;
      int importedEdits = 0;
      // Snapshot taken before the import loop so iAmEstablished reflects the
      // device's state before receiving anything from this peer.
      final favCountBefore = root.favorites.length;

      for (final cm in chatsManifest) {
        final chatId = cm['chatId'] as String?;
        // WardLink only ever syncs Favorites.
        if (chatId == null || !chatId.startsWith('fav:')) continue;
        final favId = chatId.replaceFirst('fav:', '');
        // Skip favourites we've deleted — don't let a peer resurrect them.
        // Exception: when syncFromBeginning is true the user explicitly requested
        // a full-history pull (e.g. after re-pairing), so we clear local
        // tombstones for those chats and allow them back in.
        if (WardLinkTombstones.isFavDeleted(favId)) {
          if (paired.syncFromBeginning) {
            unawaited(WardLinkTombstones.clearFav(favId));
          } else {
            continue;
          }
        }
        final favMetaJson = cm['fav'] as Map<String, dynamic>?;
        if (favMetaJson == null) continue; // can't import a fav without meta

        // Watermark: 0 means full history; otherwise only messages after pairing.
        final watermarkMs = paired.syncFromBeginning
            ? 0
            : paired.pairedAt.millisecondsSinceEpoch;
        final localMsgs = root.chats[chatId] ?? const <ChatMessage>[];
        final localIds = localMsgs.map((m) => m.id).toSet();
        final localMsgById = {for (final m in localMsgs) m.id: m};
        final manifestMsgs =
            (cm['msgs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final missingIds = <String>[
          for (final m in manifestMsgs)
            if (m['id'] != null &&
                !localIds.contains(m['id'].toString()) &&
                _msgMillis(m['t']) >= watermarkMs &&
                !WardLinkTombstones.isMsgDeleted(chatId, m['id'].toString()))
              m['id'].toString(),
        ];

        // Detect messages the peer has edited that are newer than our local copy.
        final editedIds = <String>[];
        for (final m in manifestMsgs) {
          final id = m['id']?.toString();
          if (id == null || missingIds.contains(id)) continue;
          final remoteEtMs = (m['et'] as num?)?.toInt() ?? 0;
          if (remoteEtMs == 0) continue;
          final localMsg = localMsgById[id];
          if (localMsg == null) continue;
          final localEtMs = localMsg.editedAt?.millisecondsSinceEpoch ?? 0;
          if (remoteEtMs > localEtMs) editedIds.add(id);
        }

        // 2. Pull missing message bodies (if any).
        List<ChatMessage> newMsgs = const [];
        if (missingIds.isNotEmpty) {
          final chatTitle = (favMetaJson['title'] as String?) ?? chatId;
          _chatBegin(chatId, chatTitle, missingIds.length);

          final msgsResp = await _post(base, '/wardlink/messages', key, {
            'chatId': chatId,
            'ids': missingIds,
          });
          final rawList =
              (msgsResp?['messages'] as List?)?.cast<Map<String, dynamic>>() ??
                  [];
          newMsgs = rawList.map(ChatMessage.fromJson).toList();

          // 3. Fetch media referenced by the new messages.
          for (final msg in newMsgs) {
            for (final ref in LanFavSyncService.referencedKeys(msg.content)) {
              final localPath = await WardLinkMedia.resolveLocal(ref.key);
              if (localPath != null) continue;
              // Skip files this peer couldn't serve in this session (404 etc.)
              // — prevents hammering the peer with retries it can never fulfil.
              final missingKey = '$peerPubB64\x00${ref.key}';
              if (_peerMissingFiles.contains(missingKey)) continue;
              final fname = p.basename(ref.key);
              _chatAddFile(chatId, WardLinkFileEntry(fname));
              final ok = await _fetchFile(
                  base, key, chatId, msg.id, ref.key, ref.type);
              _chatUpdateFile(chatId, fname, done: ok, error: !ok);
              if (ok) {
                importedFiles++;
              } else {
                _peerMissingFiles.add(missingKey);
              }
            }
          }
        }

        // 2b. Pull updated bodies for edited messages.
        List<ChatMessage> editedMsgs = const [];
        if (editedIds.isNotEmpty) {
          final editResp = await _post(base, '/wardlink/messages', key, {
            'chatId': chatId,
            'ids': editedIds,
          });
          final rawEdited =
              (editResp?['messages'] as List?)?.cast<Map<String, dynamic>>() ??
                  [];
          editedMsgs = rawEdited.map(ChatMessage.fromJson).toList();
        }

        // 4. Resolve the favourite avatar (if any) before importing.
        // Only count a file as imported when it was actually downloaded —
        // _fetchAvatar returns null when the file already exists locally.
        String? avatarPath;
        final avatarKey = cm['avatarKey'] as String?;
        if (avatarKey != null) {
          final targetPath = await WardLinkMedia.saveTarget(avatarKey, 'avatar');
          if (await File(targetPath).exists()) {
            avatarPath = targetPath; // already present, no download needed
          } else {
            final fetched = await _fetchAvatar(base, key, chatId, avatarKey);
            if (fetched != null) {
              avatarPath = fetched;
              importedFiles++;
            }
          }
        }

        // 5. Always import the FavoriteChat entry so the chat is visible in
        //    the list even when all its messages predate the sync watermark.
        //    Messages are only added when newMsgs is non-empty.
        final fav = FavoriteChat(
          id: (favMetaJson['id'] ?? chatId.replaceFirst('fav:', '')) as String,
          title: (favMetaJson['title'] ?? 'Favorite') as String,
          avatarPath: avatarPath,
          createdAt:
              DateTime.tryParse(favMetaJson['createdAt'] as String? ?? '') ??
                  DateTime.now(),
        );
        // Progressive import: add this chat to the UI as soon as it arrives
        // so the user sees chats appear one by one rather than all at once.
        // cascade:false suppresses the per-chat pokeNow(); we fire a single
        // poke after the full loop, but only when something actually changed —
        // otherwise a no-op sync would poke peers and cause an infinite loop.
        final chatChanged = root.importFavorites(
          [fav],
          newMsgs.isNotEmpty ? {chatId: newMsgs} : {},
          cascade: false,
        );
        if (chatChanged) importedFavs++;
        if (newMsgs.isNotEmpty) importedMsgs += newMsgs.length;

        // Apply content updates for edited messages.
        if (editedMsgs.isNotEmpty) {
          root.applyMessageEdits(chatId, editedMsgs);
          importedEdits += editedMsgs.length;
        }
      }

      // Signal that a cascade poke is needed — fired after finally so the peer
      // is no longer in _activeSyncs, preventing the poke response from landing
      // in _pendingResync and triggering an immediate re-sync loop.
      pokeAfterSync = importedFavs > 0;

      // Merge the peer's folder layout: adds new folders and chat assignments
      // from the peer without removing anything that exists locally.
      //
      // Structure merge: newcomer force-adopts the peer's layout so a freshly
      // paired device immediately gets the fleet's folder arrangement. Established
      // devices use the timestamp-guarded additive merge (never destructive).
      final favStruct = manifestResp['favStructure'];
      if (favStruct is Map<String, dynamic>) {
        final firstSyncWithPeer = paired.lastSyncAt == null;
        // Use favCountBefore (snapshot before the import loop) so that a device
        // receiving its first batch of chats is still treated as a newcomer here,
        // not as established just because it now holds the just-imported chats.
        final iAmEstablished = WardLinkPairedDevices.devices.value.any(
                (d) => d.identityPubB64 != peerPubB64 && d.lastSyncAt != null) ||
            favCountBefore > 0;
        // Force-apply when:
        // (a) first sync with a peer and we had no data before it started, OR
        // (b) we received new favourites — the sender is the authority on the
        //     order of chats they own, so their structure must win regardless of
        //     local timestamp.
        root.applyFavStructure(favStruct,
            force: (firstSyncWithPeer && !iAmEstablished) || importedFavs > 0);
      }

      await WardLinkPairedDevices.markSynced(peerPubB64);
      final nothingNew = importedMsgs == 0 && importedFiles == 0 && importedEdits == 0;
      final editSuffix = importedEdits > 0 ? ', $importedEdits edit(s)' : '';
      _log(
          WardLinkLogLevel.info,
          nothingNew
              ? 'Up to date with ${paired.name}'
              : 'Received $importedMsgs message(s), $importedFiles file(s)$editSuffix from ${paired.name}');
      _setStatus(
        lastSyncAt: DateTime.now(),
        lastSyncFailed: false,
        message: nothingNew
            ? 'Up to date with ${paired.name}'
            : 'Received $importedMsgs message(s), $importedFiles file(s)$editSuffix',
      );
    } on _WardLinkRejectedException {
      // The peer returned 403. This can be a transient state (e.g. the app
      // just restarted and its paired-devices list hasn't loaded yet) — do NOT
      // auto-remove, which was causing false-positive removals on re-entry.
      // Log it and stop syncing with this peer this session so we don't spam.
      _log(WardLinkLogLevel.warn,
          '${paired.name} rejected sync (403) — skipping until next session');
      _peerAddresses.remove(peerPubB64);
      _setStatus(lastSyncFailed: true);
    } catch (e) {
      _log(WardLinkLogLevel.error, 'Sync with ${paired.name} failed: $e');
      _setStatus(lastSyncFailed: true);
    } finally {
      _activeSyncs.remove(peerPubB64);
      _setStatus(syncing: false, currentFile: null);
      // If a poke arrived while we were busy, resync immediately to pick up
      // any messages that were sent during the previous sync.
      if (_pendingResync.remove(peerPubB64)) {
        final addr = _peerAddresses[peerPubB64];
        if (addr != null) {
          _lastSyncByPeer[peerPubB64] = DateTime.now();
          unawaited(_syncWithPeer(addr.ip.address, addr.port, peerPubB64));
        }
      }
    }
    // Poke AFTER finally — peer is out of _activeSyncs now, so their response
    // won't land in _pendingResync and won't cause an immediate re-sync loop.
    if (pokeAfterSync) unawaited(pokeNow());
  }

  /// Stream a media file from the peer to local disk, enforcing the size limit.
  Future<bool> _fetchFile(String base, SecretKey key, String chatId,
      String msgId, String fileKey, String type) async {
    try {
      final path = await WardLinkMedia.saveTarget(fileKey, type);
      final name = p.basename(fileKey);
      _fileStart(name);
      _log(WardLinkLogLevel.info, 'Downloading $name');
      _setStatus(currentFile: name, bytesReceived: 0, bytesTotal: 0);
      final size = await _download(base, '/wardlink/file', key, {
        'chatId': chatId,
        'msgId': msgId,
        'key': fileKey,
        'type': type,
      }, path, onProgress: (recv, total) {
        _setProgressStatus(name, recv, total);
      });
      _setStatus(currentFile: null, bytesReceived: 0, bytesTotal: 0);
      _fileDone(name, ok: size >= 0);
      if (size < 0) {
        _log(WardLinkLogLevel.error,
            'Download failed: $name${_lastDownloadError != null ? ' — $_lastDownloadError' : ''}');
        return false;
      }
      _log(WardLinkLogLevel.info, 'Saved $name (${_human(size)})');
      WardLinkMedia.register(fileKey, type, path, size);
      return true;
    } catch (e) {
      _log(WardLinkLogLevel.error, 'Download error $fileKey: $e');
      return false;
    }
  }

  String _human(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }

  Future<String?> _fetchAvatar(
      String base, SecretKey key, String chatId, String avatarKey) async {
    try {
      final path = await WardLinkMedia.saveTarget(avatarKey, 'avatar');
      final size = await _download(base, '/wardlink/file', key, {
        'chatId': chatId,
        'key': avatarKey,
        'type': 'avatar',
      }, path);
      return size < 0 ? null : path;
    } catch (e) {
      if (kDebugMode) print('[WardLink] fetchAvatar failed: $e');
      return null;
    }
  }

  // ─────────────────────────── responder (serve) ────────────────────────────

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      if (DecoyManager.isActive.value) {
        req.response.statusCode = 503;
        await req.response.close();
        return;
      }
      if (req.method != 'POST') {
        req.response.statusCode = 405;
        await req.response.close();
        return;
      }

      final callerPub = req.headers.value('x-wardlink-pub');
      if (callerPub == null) {
        req.response.statusCode = 400;
        await req.response.close();
        return;
      }

      // Pairing is the one endpoint reachable before trust is established; it is
      // instead authenticated by the single-use nonce from our QR code.
      if (req.uri.path == '/wardlink/pair') {
        final pairKey = await WardLinkCrypto.deriveSessionKey(
            WardLinkIdentity.keyPair, base64Decode(callerPub));
        await _handlePair(req, callerPub, pairKey);
        return;
      }

      // Every other endpoint requires a device the user explicitly paired.
      if (!WardLinkPairedDevices.isTrusted(callerPub)) {
        req.response.statusCode = 403;
        await req.response.close();
        return;
      }
      if (req.uri.path == '/wardlink/unpair') {
        await _handleUnpair(req, callerPub);
        return;
      }

      final paired = WardLinkPairedDevices.byPub(callerPub)!;
      final key = await WardLinkCrypto.deriveSessionKey(
          WardLinkIdentity.keyPair, paired.identityPub);

      final body = await utf8.decoder.bind(req).join();
      final payload = await WardLinkCrypto.decryptJson(body, key);
      if (payload == null) {
        req.response.statusCode = 400;
        await req.response.close();
        return;
      }

      switch (req.uri.path) {
        case '/wardlink/manifest':
          await _serveManifest(req, key, payload);
        case '/wardlink/messages':
          await _serveMessages(req, key, payload);
        case '/wardlink/file':
          await _serveFile(req, key, payload, paired.name);
        default:
          req.response.statusCode = 404;
          await req.response.close();
      }
    } catch (e) {
      if (kDebugMode) print('[WardLink] handleRequest error: $e');
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _reply(
      HttpRequest req, SecretKey key, Map<String, dynamic> payload) async {
    final enc = await WardLinkCrypto.encryptJson(payload, key);
    req.response.statusCode = 200;
    req.response.headers.contentType = ContentType.json;
    req.response.write(enc);
    await req.response.close();
  }

  Future<void> _serveManifest(
      HttpRequest req, SecretKey key, Map<String, dynamic> payload) async {
    final root = rootScreenKey.currentState;
    final chats = <Map<String, dynamic>>[];
    if (root != null) {
      // Build an ordered id list that matches the actual display order:
      // top-level items in favTopOrder sequence, then folder items in folder order.
      // Orphaned entries (in _favorites but not in topOrder / any folder) are
      // excluded — peers never receive stale / deleted / cache-only chats.
      // Serving in display order lets the receiver's progressive import preserve
      // the correct order as chats appear one by one.
      final favById = {for (final f in root.favorites) f.id: f};
      final orderedFavIds = [
        ...root.favTopOrder,
        for (final folder in root.favFolders) ...folder.chatIds,
      ];
      // WardLink only shares Favorites. Each favourite carries its meta so the
      // peer can recreate it, plus the list of message ids it holds.
      for (final favId in orderedFavIds) {
        final fav = favById[favId];
        if (fav == null) continue;
        final chatId = 'fav:${fav.id}';
        final msgs = root.chats[chatId] ?? const <ChatMessage>[];
        final entry = <String, dynamic>{
          'kind': 'fav',
          'chatId': chatId,
          'fav': fav.toJson(),
          'msgs': [
            for (final m in msgs)
              {
                'id': m.id,
                't': m.time.millisecondsSinceEpoch,
                if (m.editedAt != null) 'et': m.editedAt!.millisecondsSinceEpoch,
              },
          ],
        };
        if (fav.avatarPath != null && File(fav.avatarPath!).existsSync()) {
          entry['avatarKey'] = 'avatar_${fav.id}${p.extension(fav.avatarPath!)}';
        }
        chats.add(entry);
      }
    }
    // Share our trusted-peer list so the requester can auto-mesh with devices
    // it doesn't yet know about (hub-and-spoke → full mesh without extra QR).
    final meshPeers = WardLinkPairedDevices.devices.value.map((d) {
      final addr = _peerAddresses[d.identityPubB64];
      return <String, dynamic>{
        'pub': d.identityPubB64,
        'deviceId': d.deviceId,
        'name': d.name,
        'os': d.os,
        if (addr != null) 'ip': addr.ip.address,
        if (addr != null) 'port': addr.port,
      };
    }).toList();

    await _reply(req, key, {
      'v': _protocolVersion,
      'chats': chats,
      // The favourites arrangement (order + folders) travels with the manifest
      // so the peer can mirror it, newest-layout-wins.
      if (root != null) 'favStructure': root.exportFavStructure(),
      // Deletion records so the peer removes what we deleted (and never re-adds).
      'tombstones': WardLinkTombstones.export(),
      // Trusted peer list for automatic full-mesh formation.
      'meshPeers': meshPeers,
    });
  }

  Future<void> _serveMessages(
      HttpRequest req, SecretKey key, Map<String, dynamic> payload) async {
    final root = rootScreenKey.currentState;
    final chatId = payload['chatId'] as String?;
    final ids = (payload['ids'] as List?)?.map((e) => e.toString()).toSet() ??
        <String>{};
    final out = <Map<String, dynamic>>[];
    if (root != null && chatId != null) {
      for (final m in root.chats[chatId] ?? const <ChatMessage>[]) {
        if (ids.contains(m.id)) out.add(m.toJson());
      }
    }
    await _reply(req, key, {'messages': out});
  }

  Future<void> _serveFile(
      HttpRequest req, SecretKey key, Map<String, dynamic> payload,
      String peerName) async {
    final root = rootScreenKey.currentState;
    final chatId = payload['chatId'] as String?;
    final fileKey = payload['key'] as String?;
    final type = payload['type'] as String? ?? 'file';
    if (fileKey == null) {
      req.response.statusCode = 400;
      await req.response.close();
      return;
    }

    String? path;

    // Favourite avatars are referenced by FavoriteChat.avatarPath, not message
    // content — resolve them directly.
    if (type == 'avatar' && chatId != null && chatId.startsWith('fav:')) {
      final favId = chatId.replaceFirst('fav:', '');
      final fav = root?.favorites
          .cast<FavoriteChat?>()
          .firstWhere((f) => f?.id == favId, orElse: () => null);
      if (fav?.avatarPath != null && File(fav!.avatarPath!).existsSync()) {
        path = fav.avatarPath;
      }
    } else {
      // Find the requested file wherever favourites media actually lives.
      path = await WardLinkMedia.resolveLocal(fileKey);
    }

    if (path == null || !File(path).existsSync()) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }

    // Stream the file as independently-sealed frames. Read 64 KB → seal →
    // write → AWAIT FLUSH before the next read. The explicit flush forces each
    // piece out to the socket (true backpressure), so the sender never buffers
    // more than ~one chunk and can't OOM-crash on a 320 MB / multi-GB file.
    // Progress is surfaced so the *sender's* bubble shows the upload %.
    final name = p.basename(fileKey);
    final plainSize = await File(path).length();
    _serveStart(peerName, name);
    RandomAccessFile? raf;
    try {
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.binary;
      req.response.headers.add('x-wardlink-size', '$plainSize');

      raf = await File(path).open();
      int sent = 0;
      while (true) {
        final chunk = await raf.read(64 * 1024);
        if (chunk.isEmpty) break;
        req.response.add(await WardLinkCrypto.sealFrame(chunk, key));
        await req.response.flush();
        sent += chunk.length;
        _setProgressStatus(name, sent, plainSize);
      }
      req.response.add(WardLinkCrypto.terminatorFrame());
      await req.response.flush();
      await req.response.close();
      _serveEnd(name, ok: true);
    } catch (e) {
      _log(WardLinkLogLevel.error, 'Send error $name: $e');
      _serveEnd(name, ok: false);
      try {
        await req.response.close();
      } catch (_) {}
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  // Tracks concurrent outbound file serves so the bubble stays visible while
  // this device is uploading to a peer, and hides once the last one finishes.
  int _activeServes = 0;

  void _serveStart(String peerName, String name) {
    _activeServes++;
    _log(WardLinkLogLevel.info, 'Sending $name → $peerName');
    _setStatus(
        syncing: true,
        peerName: peerName,
        currentFile: name,
        bytesReceived: 0,
        bytesTotal: 0);
    _fileStart(name);
  }

  void _serveEnd(String name, {required bool ok}) {
    _log(ok ? WardLinkLogLevel.info : WardLinkLogLevel.error,
        ok ? 'Sent $name' : 'Send failed: $name');
    _fileDone(name, ok: ok);
    _activeServes = (_activeServes - 1).clamp(0, 1 << 30);
    if (_activeServes == 0 && _activeSyncs.isEmpty) {
      _setStatus(syncing: false, currentFile: null);
    } else {
      _setStatus(currentFile: null);
    }
  }

  // ─────────────────────────── firewall helper (Windows) ───────────────────

  /// Tries to add an inbound Windows Firewall rule for [syncPort] so the phone
  /// can reach the sync server without the user having to do it manually.
  /// Runs netsh in the background; silently ignored on failure (e.g. no rights).
  static Future<void> _ensureWindowsFirewallRule() async {
    const ruleName = 'ONYX WardLink Sync';
    try {
      // First check if a rule already exists — avoids duplicate warnings.
      final check = await Process.run('netsh', [
        'advfirewall', 'firewall', 'show', 'rule', 'name=$ruleName',
      ]);
      if ((check.stdout as String).contains(ruleName)) return;

      await Process.run('netsh', [
        'advfirewall', 'firewall', 'add', 'rule',
        'name=$ruleName',
        'dir=in',
        'action=allow',
        'protocol=TCP',
        'localport=$syncPort',
        'profile=private,domain',
        'description=WardLink LAN sync port for ONYX messenger',
      ]);
    } catch (_) {
      // No admin rights or netsh unavailable — the UI shows the manual hint.
    }
  }

  // ─────────────────────────── HTTP helpers ─────────────────────────────────

  Future<Map<String, dynamic>?> _post(
    String base,
    String path,
    SecretKey key,
    Map<String, dynamic> payload,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final enc = await WardLinkCrypto.encryptJson(payload, key);
      final req = await client.postUrl(Uri.parse('$base$path'));
      req.headers.contentType = ContentType.json;
      req.headers.add('x-wardlink-pub', WardLinkIdentity.publicKeyB64);
      req.write(enc);
      final resp = await req.close().timeout(const Duration(seconds: 60));
      if (resp.statusCode == 403) {
        await resp.drain<void>();
        throw _WardLinkRejectedException();
      }
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        return null;
      }
      final respBody = await utf8.decoder.bind(resp).join();
      return WardLinkCrypto.decryptJson(respBody, key);
    } on _WardLinkRejectedException {
      rethrow;
    } catch (e) {
      // Log the real exception so it shows up in the WardLink sync log.
      _log(WardLinkLogLevel.error, '_post $path: $e');
      if (kDebugMode) print('[WardLink] _post $path failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Download a framed encrypted file into [destPath]. Returns plaintext bytes
  /// written, or -1 on failure / when it exceeds the configured size limit.
  ///
  /// Frames are read with a backpressured reader (it pauses the socket when its
  /// buffer fills) and decrypted per frame on the main isolate (fast; each await
  /// yields), then written straight to the destination — bounded memory, no UI
  /// freeze, no temp files.
  Future<int> _download(
    String base,
    String path,
    SecretKey key,
    Map<String, dynamic> payload,
    String destPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    _lastDownloadError = null;
    final maxBytes = SettingsManager.wardLinkMaxFileSizeMb.value * 1024 * 1024;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    IOSink? sink;
    WardLinkFrameReader? reader;
    try {
      final enc = await WardLinkCrypto.encryptJson(payload, key);
      final req = await client.postUrl(Uri.parse('$base$path'));
      req.headers.contentType = ContentType.json;
      req.headers.add('x-wardlink-pub', WardLinkIdentity.publicKeyB64);
      req.write(enc);
      final resp = await req.close().timeout(const Duration(minutes: 30));
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        _lastDownloadError = 'HTTP ${resp.statusCode}';
        return -1;
      }

      final total =
          int.tryParse(resp.headers.value('x-wardlink-size') ?? '') ?? 0;
      sink = File(destPath).openWrite();
      reader = WardLinkFrameReader(resp);
      int written = 0;

      while (true) {
        final lenBytes = await reader.readExact(4);
        if (lenBytes == null) break; // stream ended
        final len = ByteData.sublistView(lenBytes).getUint32(0, Endian.big);
        if (len == 0) break; // terminator
        final sealed = await reader.readExact(len);
        if (sealed == null) throw const FormatException('truncated frame');
        final plain = await WardLinkCrypto.openFrame(sealed, key);
        written += plain.length;
        if (written > maxBytes) {
          throw StateError('file exceeds WardLink size limit');
        }
        sink.add(plain);
        onProgress?.call(written, total);
      }

      await sink.flush();
      await sink.close();
      sink = null;
      return written;
    } catch (e) {
      _lastDownloadError = '$e';
      if (kDebugMode) print('[WardLink] _download failed: $e');
      try {
        await sink?.close();
      } catch (_) {}
      try {
        final d = File(destPath);
        if (await d.exists()) await d.delete();
      } catch (_) {}
      return -1;
    } finally {
      await reader?.cancel();
      client.close();
    }
  }
}

