// lib/services/onion/onion_transport_service.dart
//
// Onion-mode 1:1 chat transport. This is the onion-mode analogue of
// lib/services/wardlink/wardlink_sync_service.dart's pairing/session logic,
// with the LAN transport (UDP discovery + local HTTP daemon) replaced by
// the onyx_tor Rust plugin's Tor hidden-service listener/dial.
//
// Wire format: every frame written to a stream -- a long-lived per-device
// channel (see the "channels" section below), or a one-shot dialed stream
// for pairing/identify and older peers -- is:
//   [1-byte tag][4-byte BE length][payload]
// where tag is:
//   0 = sealed chat/pairing message. payload is:
//       [4-byte BE length][sender's identity pubkey, base64, as UTF-8 bytes]
//       [WardLinkCrypto.sealFrame(payloadJsonBytes, sessionKey)] (already
//        internally length-prefixed by sealFrame itself)
//   1 = plaintext identify request/response (see "search by address" below).
//       payload is a bare JSON object; nothing is encrypted, since this is
//       exactly the message that introduces a pubkey we don't have yet.
//
// The sender's pubkey travels in cleartext (tag 0's inner segment) so the
// receiver -- who may not have this peer pinned yet, e.g. during the QR
// pairing handshake -- knows which session key to derive. This doesn't
// weaken anything: the pubkey is not secret (it's shown in the pairing QR),
// and a successful AES-GCM decrypt against the session key derived from
// *our* key and the claimed pubkey already proves the sender holds the
// matching private key, exactly like WardLink's static-static ECDH
// authenticates a LAN peer.
//
// "Search by address" (connectByAddress) lets one side initiate contact
// knowing only the other's bare onion address, with no prior QR exchange:
// it dials, sends a tag-1 identify_request (necessarily unencrypted -- there
// is no session key yet, that's the whole problem it solves), and the far
// side replies with an identify_response so the caller can pin it (the
// caller dialed that address, so the reply is genuinely from it).
//
// The far side does NOT trust the caller back: everything in the request
// (username, onion address) is self-claimed. It first verifies the claimed
// address -- dials it and makes the device there prove it holds the claimed
// key ('verify' / 'verify_ok') -- and then files a contact request (see
// onion_requests.dart) the user must accept. Until then the caller gets no
// channel, presence, profile or calls; its messages wait in the request.
//
// Both parties must be online simultaneously for delivery to succeed --
// there is no offline mailbox/relay in this phase (see the onion-mode plan).
// "Online" in the UI means exactly that: a channel to them is open now.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show ValueNotifier, VoidCallback, setEquals;

import '../../managers/account_manager.dart';
import '../../managers/blocklist_manager.dart';
import '../../utils/onyx_base_dir.dart' show getOnyxDocumentsDirectory;
import 'package:shared_preferences/shared_preferences.dart';

import '../../managers/settings_manager.dart';
import '../../managers/user_cache.dart';
import '../profile_store.dart';
import '../wardlink/wardlink_sync_service.dart';
import '../../globals.dart'
    show
        avatarVersion,
        onlineUsersNotifier,
        userStatusNotifier,
        userStatusVisibilityNotifier;
import 'onion_account.dart';
import 'onion_account_key.dart';
import 'onion_crypto.dart';
import 'onion_identity.dart';
import 'onion_paired_peers.dart';
import 'onion_requests.dart';
import 'onion_send_queue.dart';

/// Callback signature for a decoded, already-decrypted incoming chat
/// message. Registered by root_screen so it can feed the same
/// persistence/UI/notification pipeline the central-server WS path uses.
typedef OnionMessageHandler = void Function({
  required String from,
  required String decrypted,
  String? mid,
});

/// Callback signature for an incoming "delete for everyone" notice --
/// registered by root_screen alongside [OnionMessageHandler] so it can
/// remove the matching local message (see ChatMessage.onionMid).
typedef OnionDeleteHandler = void Function({
  required String from,
  required String mid,
});

/// A valid Tor v3 onion address: 56 base32 characters + ".onion".
/// Case-insensitive; Tor addresses are conventionally lowercase.
final RegExp onionAddressPattern =
    RegExp(r'^[a-z2-7]{56}\.onion$', caseSensitive: false);

/// Contact code for an account with several devices:
/// `onyx:<addr>,<addr>...` (56-char onion addresses, ".onion" optional).
/// A bare onion address is a code with one address. Returns the normalized
/// addresses (with ".onion"), or null if [input] is neither.
List<String>? parseOnionContactCode(String input) {
  var s = input.trim().toLowerCase();
  if (onionAddressPattern.hasMatch(s)) return [s];
  if (!s.startsWith('onyx:')) return null;
  s = s.substring(5);
  final out = <String>[];
  for (var part in s.split(',')) {
    part = part.trim();
    if (part.isEmpty) continue;
    if (!part.endsWith('.onion')) part = '$part.onion';
    if (!onionAddressPattern.hasMatch(part)) return null;
    if (!out.contains(part)) out.add(part);
  }
  if (out.isEmpty || out.length > 16) return null;
  return out;
}

/// A peer-chosen media filename is only ever used as ONE path component under
/// onion_media. Anything that could climb out of that folder ("../x",
/// "a/b", absolute or drive-qualified names) is refused -- the receiver must
/// not rename it either, because the chat pointer (`onion://NAME`) refers
/// to the exact same name.
bool isSafeOnionMediaFilename(String name) {
  if (name.isEmpty || name.length > 255) return false;
  if (name == '.' || name == '..') return false;
  final windows = Platform.isWindows;
  for (final unit in name.codeUnits) {
    if (unit < 0x20) return false; // control chars incl. NUL
    if (unit == 0x2F || unit == 0x5C) return false; // forward / back slash
    if (windows && unit == 0x3A) return false; // ':' (drive / NTFS stream)
  }
  return true;
}

class OnionTransportService {
  OnionTransportService._();
  static final OnionTransportService instance = OnionTransportService._();

  /// Set by root_screen once, before calling [start].
  OnionMessageHandler? onMessage;

  /// Set by root_screen once, before calling [start]. Fires when a paired
  /// device asks us to delete a message they previously sent us -- see
  /// [sendDeleteNotice].
  OnionDeleteHandler? onDeleteMessage;

  /// Set by root_screen: a new (verified) contact request arrived, or an
  /// existing one got a message -- for a notice/sound.
  void Function(OnionContactRequest req)? onContactRequest;


  /// Set by root_screen once, before calling [start]. Unlike the old
  /// `if (kDebugMode) print(...)` calls this replaces, this always fires
  /// (release builds included) -- a send/receive failure here has no other
  /// visible trace in a release build otherwise, which made "message just
  /// silently never arrives" reports impossible to diagnose from logs.
  void Function(String message)? onLog;

  void _log(String message) => onLog?.call('[onion] $message');

  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  String? _cachedDeviceName;
  String? _username;

  /// Called when a queued send (see OnionSendQueue) is finally delivered,
  /// so the UI can flip that message's tick from pending to delivered --
  /// only fires for text/pointer sends, which carry a localId; queued media
  /// bytes have no UI element of their own to update (see
  /// QueuedOnionSend's doc comment).
  void Function(String peerUsername, String localId)? onDeliveryUpdate;

  Timer? _retryTimer;
  bool _retrying = false;

  // A fresh nonce backing the QR currently shown by "add onion peer". A peer
  // proves it scanned our QR by echoing this nonce in its pair_request.
  String? _pairingNonce;

  bool get isRunning => OnionIdentity.isRunning;

  Future<void> start(String username, String stateDir) async {
    _username = username;
    if (isRunning) {
      if (_retryTimer == null) _startRetryTimer();
      if (_channelTimer == null) _startChannels();
      await _watchConnectivity();
      return;
    }
    // Attached before start(), not after: the hidden service can start
    // accepting inbound connections during startHiddenService itself (as
    // soon as tor's ADD_ONION reply comes back), and OnionIdentity.plugin's
    // events broadcast stream -- like the log stream OnionIdentity itself
    // subscribes to early, see its own comment -- drops anything emitted
    // before a listener is attached. Subscribing only after start() resolves
    // risks silently losing whichever peer happens to dial us first.
    _eventsSub ??= OnionIdentity.plugin.events.listen(_onEvent);
    // Everything that works without Tor comes first: if Tor can't connect
    // here, this device still knows its account's other devices and hands
    // what it sends to them over WardLink (see "own-device events").
    await OnionAccountKey.load(username);
    await OnionAccount.load(username);
    await OnionSendQueue.load(username);
    await _loadSeenIncoming(username);
    WardLinkSyncService.onOnionOwnEvent = _onOwnEventViaWardLink;
    WardLinkSyncService.onPeerReachable = _kickQueue;
    _startRetryTimer();
    SettingsManager.onionRetryIntervalSeconds.removeListener(_startRetryTimer);
    SettingsManager.onionRetryIntervalSeconds.addListener(_startRetryTimer);
    await OnionIdentity.start(stateDir, username);
    await _ensureSelfOnRoster();
    // Give Tor a moment to publish our descriptor, then hand our current
    // profile to any contact that hasn't got the latest version yet.
    Timer(const Duration(seconds: 45), () => unawaited(syncProfileToPeers()));
    _startChannels();
    await _watchConnectivity();
  }

  // ─────────────────────────── network changes ──────────────────────────────
  //
  // Switching Wi-Fi <-> mobile leaves tor's guard connections (and with them
  // every channel and our onion service's intro circuits) bound to the old
  // interface: dead, but nothing tells tor or us so for minutes. Meanwhile
  // our sends sit in the queue and the peer can't reach us either. On any
  // connectivity change we make tor rebuild over the new network and drop
  // our channels right away so they get redialed as soon as it's back.

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Set<ConnectivityResult>? _lastConnectivity;
  Timer? _networkDebounce;

  Future<void> _watchConnectivity() async {
    if (_connectivitySub != null) return;
    try {
      _lastConnectivity = (await Connectivity().checkConnectivity()).toSet();
    } catch (_) {}
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final now = results.toSet();
      if (setEquals(now, _lastConnectivity)) return;
      _lastConnectivity = now;
      // A switch can fire a couple of events back to back (wifi lost ->
      // mobile); coalesce those, but keep it short -- every ms here is
      // reconnect time.
      _networkDebounce?.cancel();
      _networkDebounce = Timer(const Duration(milliseconds: 400),
          () => unawaited(_onNetworkChanged()));
    }, onError: (_) {});
  }

  Future<void> _stopWatchingConnectivity() async {
    _networkDebounce?.cancel();
    _networkDebounce = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _lastConnectivity = null;
  }

  Future<void> _onNetworkChanged() async {
    if (!isRunning) return;
    final nets = _lastConnectivity ?? const <ConnectivityResult>{};
    final offline =
        nets.isEmpty || nets.every((r) => r == ConnectivityResult.none);
    _log('network changed: ${nets.map((r) => r.name).join(',')}'
        '${offline ? ' (offline)' : ''}');
    // Dials still running were made over the old network and are doomed;
    // a new generation makes them not count as failures (no backoff) and
    // redial right away when they give up -- see _dialChannel.
    _netGeneration++;
    // No dialing while tor is mid-reset: such a dial would just hang on the
    // dead network and then block the real one (one dial per device).
    _netResetting = true;
    // Every channel rode the old network; don't wait 60s of silence to find
    // out they're dead.
    for (final ch in List<_PeerChannel>.of(_channelByHandle.values)) {
      _closeChannel(ch, reason: 'network changed');
    }
    // Same for call lanes; their keepers reopen them once tor is back.
    for (final l in List<_CallLane>.of(_callLaneByHandle.values)) {
      _closeCallLane(l);
    }
    if (offline) {
      _netResetting = false;
      return; // the next change (back online) resets tor
    }
    final gen = _netGeneration;
    try {
      // Returns once tor has a circuit on the new network again.
      await OnionIdentity.plugin.resetNetwork();
    } finally {
      if (gen == _netGeneration) _netResetting = false;
    }
    if (!isRunning || gen != _netGeneration) return;
    // Dial everyone now, not on the next 5s tick, with no leftover backoff.
    // We dial (not wait for them): their onion service is still up, while
    // ours needs a fresh descriptor first, and they won't notice their side
    // of the old channel is dead for up to a minute anyway.
    for (final d in _allDevices()) {
      _dialFailures.remove(d.identityPubB64);
      _nextDialAt.remove(d.identityPubB64);
      _maybeDial(d, force: true);
    }
    _refreshConnecting();
  }

  /// Every device we keep a channel to: contacts' devices and our own
  /// other devices.
  List<OnionPeer> _allDevices() => [
        ...OnionPairedPeers.peers.value,
        ...OnionAccount.ownPeers(),
      ];

  /// A contact's device or one of our own, by pubkey.
  OnionPeer? _knownDevice(String pub) =>
      OnionPairedPeers.byPub(pub) ?? OnionAccount.ownPeer(pub);

  int _netGeneration = 0;
  bool _netResetting = false;

  // ─────────────────────────── channels ─────────────────────────────────────
  //
  // Each paired device gets ONE long-lived stream (a "channel") instead of a
  // fresh Tor dial per message. Whichever side manages to dial first opens
  // it, and from then on it carries traffic in BOTH directions -- so if only
  // one side's onion service is reachable right now (e.g. the other just
  // restarted and its new descriptor hasn't propagated yet), both can still
  // talk. The dialer sends 'hello', the far side answers 'hello'; only then
  // is the channel open. Both ends ping every 20s and drop the channel after
  // 60s of silence. "Online" in the UI means exactly "a channel is open
  // right now", i.e. a message sent now will arrive. Chat messages are
  // acknowledged ('ack' by mid), so the delivered tick means the peer
  // actually received it, not just that bytes were written.
  //
  // Peers on an older build never answer 'hello'; they're remembered in
  // [_legacyPubs] and keep getting the old dial-per-message treatment.

  /// How long a legacy (pre-channel) contact stays "online" after its last
  /// dialed presence frame. Their heartbeat is 60s, so two missed beats.
  static const Duration _presenceTtl = Duration(seconds: 150);

  static const Duration _pingInterval = Duration(seconds: 20);
  static const Duration _channelDeadAfter = Duration(seconds: 60);
  static const Duration _helloTimeout = Duration(seconds: 25);
  static const Duration _ackTimeout = Duration(seconds: 30);
  static const List<int> _dialBackoffSeconds = [5, 10, 20, 30, 60];

  final Map<String, _PeerPresence> _presence = {}; // keyed by peer identity pub
  bool _flushAgain = false;

  /// Open channels, keyed by peer identity pub. At most one per device.
  final Map<String, _PeerChannel> _channels = {};

  /// Every stream that is (or is trying to become) a channel, by handle.
  final Map<int, _PeerChannel> _channelByHandle = {};

  /// Devices we're dialing right now / next allowed dial per device.
  final Set<String> _dialing = {};
  final Map<String, DateTime> _nextDialAt = {};
  final Map<String, int> _dialFailures = {};

  /// Devices on an older build that never answer 'hello'.
  final Set<String> _legacyPubs = {};

  /// Pending 'ack's for sent chat messages, keyed by `<pub>|<mid>`.
  final Map<String, _PendingAck> _pendingAcks = {};

  Timer? _channelTimer;

  /// Usernames we're actively (re)connecting to and haven't failed to reach
  /// yet since start / since their channel dropped -- the chat header shows
  /// "connecting..." for these instead of "offline".
  final ValueNotifier<Set<String>> connectingUsers =
      ValueNotifier<Set<String>>(<String>{});

  /// True if a message sent to [username] right now would go out over an
  /// open channel.
  bool isConnected(String username) => OnionPairedPeers.allByUsername(username)
      .any((d) => _channels.containsKey(d.identityPubB64));

  /// Stricter than [isConnected], for calls: an open channel that has
  /// actually heard from the peer recently (pings go every 20s). A channel
  /// to a device that just vanished stays "open" until _channelDeadAfter;
  /// calling into it would only ring into the void.
  bool isLive(String username) {
    final now = DateTime.now();
    return OnionPairedPeers.allByUsername(username).any((d) {
      final ch = _channels[d.identityPubB64];
      return ch != null &&
          !ch.closed &&
          now.difference(ch.lastRx) <= const Duration(seconds: 45);
    });
  }

  void _startChannels() {
    _stopChannels();
    _channelTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _channelTick());
    SettingsManager.statusVisibility.addListener(_onStatusSettingsChanged);
    SettingsManager.statusOnline.addListener(_onStatusSettingsChanged);
    BlocklistManager.blockedUsers.addListener(_onBlocklistChanged);
    OnionRequests.blocked.addListener(_onBlocklistChanged);
    OnionPairedPeers.peers.addListener(_onContactsChanged);
    // Requests to people who were offline: at every start (once Tor has
    // settled a little), then every few minutes.
    _queuedRequestTimer?.cancel();
    _queuedRequestTimer = Timer.periodic(
        _queuedRequestInterval, (_) => unawaited(retryQueuedRequests()));
    Future.delayed(const Duration(seconds: 15),
        () => unawaited(retryQueuedRequests()));
    // First tick right away: dial everyone we don't have a channel with.
    _channelTick();
  }

  void _stopChannels() {
    _channelTimer?.cancel();
    _channelTimer = null;
    SettingsManager.statusVisibility.removeListener(_onStatusSettingsChanged);
    SettingsManager.statusOnline.removeListener(_onStatusSettingsChanged);
    BlocklistManager.blockedUsers.removeListener(_onBlocklistChanged);
    OnionRequests.blocked.removeListener(_onBlocklistChanged);
    OnionPairedPeers.peers.removeListener(_onContactsChanged);
    _contactsSyncDebounce?.cancel();
    _contactsSyncDebounce = null;
    _queuedRequestTimer?.cancel();
    _queuedRequestTimer = null;
    for (final ch in List<_PeerChannel>.of(_channelByHandle.values)) {
      _closeChannel(ch, reason: 'stopping');
    }
    _channels.clear();
    _channelByHandle.clear();
    _dialing.clear();
    _nextDialAt.clear();
    _dialFailures.clear();
    _legacyPubs.clear();
    for (final p in _pendingAcks.values) {
      if (!p.completer.isCompleted) p.completer.complete(false);
    }
    _pendingAcks.clear();
    connectingUsers.value = <String>{};
  }

  void _onStatusSettingsChanged() => unawaited(broadcastPresence());

  /// Runs every 5s: pings open channels, drops dead ones, closes channels to
  /// devices that got unpaired, and dials every paired device we have no
  /// channel with (respecting its backoff).
  void _channelTick() {
    if (!isRunning) return;
    final now = DateTime.now();
    for (final ch in List<_PeerChannel>.of(_channelByHandle.values)) {
      if (_knownDevice(ch.pub) == null) {
        _closeChannel(ch, reason: 'device unpaired');
        continue;
      }
      if (!ch.open) continue;
      if (ch.writing == 0 && now.difference(ch.lastRx) > _channelDeadAfter) {
        _closeChannel(ch, reason: 'no traffic for '
            '${_channelDeadAfter.inSeconds}s');
        continue;
      }
      if (now.difference(ch.lastPing) >= _pingInterval) {
        ch.lastPing = now;
        unawaited(_channelSend(ch, {'type': 'ping'}).catchError((_) {}));
      }
    }
    for (final d in _allDevices()) {
      _maybeDial(d);
    }
    _refreshConnecting();
    _refreshAllPresence(); // expires stale legacy presence
  }

  /// Dials [device] now unless a channel is already open, a dial is already
  /// running, or its backoff hasn't elapsed. [force] skips the backoff (used
  /// when the user is trying to send something right now).
  void _maybeDial(OnionPeer device, {bool force = false}) {
    final pub = device.identityPubB64;
    if (!isRunning || _netResetting) return;
    if (_isBlockedPub(pub)) return;
    if (_channels.containsKey(pub) || _dialing.contains(pub)) return;
    if (OnionRequests.isRemovedBy(pub)) {
      // They said we're not their contact: only an occasional re-check
      // (they dial us themselves when they add us back).
      final at = _removedRecheckAt[pub];
      if (at != null && DateTime.now().isBefore(at)) return;
      _removedRecheckAt[pub] = DateTime.now().add(const Duration(minutes: 5));
      unawaited(_dialChannel(device));
      return;
    }
    final next = _nextDialAt[pub];
    if (!force && next != null && DateTime.now().isBefore(next)) return;
    unawaited(_dialChannel(device));
  }

  Future<void> _dialChannel(OnionPeer device) async {
    final pub = device.identityPubB64;
    final gen = _netGeneration;
    _dialing.add(pub);
    _refreshConnecting();
    var opened = false;
    try {
      final handle = await _dialWithRetry(device.onionAddress, delays: const []);
      if (handle == null) return;
      if (!isRunning || _channels.containsKey(pub)) {
        // The peer dialed us meanwhile -- keep theirs.
        await OnionIdentity.plugin.streamClose(handle);
        opened = _channels.containsKey(pub);
        return;
      }
      final ch = _PeerChannel(handle: handle, pub: pub, outbound: true);
      _channelByHandle[handle] = ch;
      unawaited(_readLoop(handle));
      try {
        await _channelSend(
            ch, _helloPayload(own: OnionAccount.ownDevice(pub) != null));
      } catch (e) {
        _closeChannel(ch, reason: 'hello write failed: $e');
        return;
      }
      opened = await ch.opened.future.timeout(_helloTimeout,
          onTimeout: () => false);
      if (!opened && OnionRequests.isRemovedBy(pub)) {
        // Answered 'not_contact' (see _onRemovedBy): not an old build --
        // no legacy fallback, no presence.
        _closeChannel(ch, reason: 'not in their contacts');
        return;
      }
      if (!opened && !ch.closed) {
        // Reachable, decrypts fine (or it would have closed), but never
        // answered 'hello': an older build. Tell it we're here the old way
        // so it still shows us online, and fall back to dial-per-message.
        if (!_legacyPubs.contains(pub)) {
          _log('${device.username} (${device.onionAddress}) did not answer '
              'hello -- older build, using legacy delivery');
        }
        _legacyPubs.add(pub);
        final visible = SettingsManager.statusVisibility.value != 'hide';
        try {
          await _sendSealedFrame(handle, device.identityPub, {
            'type': 'presence',
            'visible': visible,
            'text': visible ? SettingsManager.statusOnline.value.trim() : '',
          });
        } catch (_) {}
        _closeChannel(ch, reason: 'legacy peer');
        // Legacy peers get re-pinged at their old heartbeat rate.
        _nextDialAt[pub] = DateTime.now().add(const Duration(seconds: 60));
        _dialFailures.remove(pub);
        _refreshPresenceFor(device.username);
        return;
      }
    } catch (e) {
      _log('channel dial to ${device.username} failed: $e');
    } finally {
      _dialing.remove(pub);
      if (gen != _netGeneration) {
        // Started on a network that's gone; its failure says nothing about
        // the peer. Go again on the new one (no-op while tor is resetting
        // -- _onNetworkChanged dials everyone once it's done).
        if (!opened && !_channels.containsKey(pub) &&
            !_legacyPubs.contains(pub)) {
          _maybeDial(device);
        }
      } else if (!opened && !_channels.containsKey(pub) &&
          !_legacyPubs.contains(pub)) {
        final fails = (_dialFailures[pub] ?? 0) + 1;
        _dialFailures[pub] = fails;
        final secs = _dialBackoffSeconds[
            min(fails - 1, _dialBackoffSeconds.length - 1)];
        _nextDialAt[pub] = DateTime.now().add(Duration(seconds: secs));
      }
      _refreshConnecting();
    }
  }

  /// [own]: the peer is another device of OUR account (it gets the full
  /// roster); anyone else gets only keys and addresses.
  Map<String, dynamic> _helloPayload({required bool own}) {
    final visible = SettingsManager.statusVisibility.value != 'hide';
    final roster = own ? _rosterWire : _publicRosterWire;
    return {
      'type': 'hello',
      'v': 1,
      // Who we are -- lets someone whose request we just accepted recognise
      // us even if they never got our identify_response (see
      // _acceptedByAddress). Sealed, and only ever sent to contacts.
      if (_username != null) 'u': _username,
      if (OnionIdentity.isRunning) 'a': OnionIdentity.onionAddress,
      // Call media support: 1 = raw frames (see sendCallMedia), 2 = also
      // extra per-call lanes (see "call paths").
      'cm': 2,
      // Our account's signed device list (see onion_account.dart).
      if (roster != null) 'r': roster,

      'visible': visible,
      'text': visible ? SettingsManager.statusOnline.value.trim() : '',
    };
  }

  /// Handles a 'hello' arriving on [handle] from [peer]: opens the channel
  /// (answering 'hello' if the peer dialed us), resolving a double channel
  /// if both sides dialed at the same time.
  Future<void> _onHello(
      int handle, OnionPeer peer, Map<String, dynamic> obj) async {
    final pub = peer.identityPubB64;
    _legacyPubs.remove(pub);
    var ch = _channelByHandle[handle];
    if (ch == null) {
      ch = _PeerChannel(handle: handle, pub: pub, outbound: false);
      _channelByHandle[handle] = ch;
    }
    if (ch.pub != pub) return; // someone else's stream; ignore
    // One of our own other devices: no presence, requests or contact
    // bookkeeping -- just the channel, and our account's sync over it.
    final own = OnionAccount.ownDevice(pub) != null;
    final cm = (obj['cm'] as num?)?.toInt() ?? 0;
    ch.rawCallMedia = cm >= 1;
    ch.callLanes = cm >= 2;
    if (!own) {
      _presence[pub] = _PeerPresence(DateTime.now(), obj['visible'] != false,
          (obj['text'] as String?)?.trim() ?? '');
    }
    if (ch.open) {
      if (!own) _refreshPresenceFor(peer.username);
      return;
    }
    if (!ch.outbound) {
      try {
        await _channelSend(ch, _helloPayload(own: own));
      } catch (e) {
        _closeChannel(ch, reason: 'hello reply failed: $e');
        return;
      }
    }

    // Both sides dialed each other at once: keep the channel dialed by the
    // side with the smaller pubkey. Both ends compute the same answer.
    //
    // But only for a real race, i.e. while the existing channel is brand
    // new. A peer never dials while it has an open channel to us, so a
    // fresh hello on top of an older open channel means the peer has lost
    // that one (typically: it switched Wi-Fi <-> mobile, and our side of
    // the old channel just hasn't timed out yet) -- it's dead, the new one
    // wins. Applying the pubkey rule there used to reject every redial
    // from the peer until our dead channel's 60s silence timeout.
    final existing = _channels[pub];
    if (existing != null && existing != ch) {
      final myPub = OnionIdentity.publicKeyB64;
      String dialer(_PeerChannel c) => c.outbound ? myPub : pub;
      final dNew = dialer(ch), dOld = dialer(existing);
      final race = DateTime.now().difference(existing.openedAt) <
          const Duration(seconds: 10);
      final keepNew =
          !race || dNew == dOld ? true : dNew.compareTo(dOld) < 0;
      if (!keepNew) {
        _closeChannel(ch, reason: 'duplicate channel');
        return;
      }
      _closeChannel(existing, reason: 'replaced by newer channel');
    }

    ch.open = true;
    ch.openedAt = DateTime.now();
    ch.lastRx = DateTime.now();
    ch.lastPing = DateTime.now();
    if (!ch.opened.isCompleted) ch.opened.complete(true);
    _channels[pub] = ch;
    _dialFailures.remove(pub);
    _nextDialAt.remove(pub);
    _log('channel to ${own ? 'own device ${peer.name}' : peer.username} open '
        '(${ch.outbound ? 'we dialed' : 'they dialed'}, handle=$handle)');
    if (own) {
      _refreshConnecting();
      unawaited(_onOwnChannelOpen(peer));
      return;
    }
    // A channel only opens once they treat us as a contact, so an earlier
    // 'not_contact' from this device (typically: it hadn't yet heard from
    // its sibling device that we were accepted) is out of date. That mark is
    // saved to disk and, left in place, kept refusing every message to this
    // person ("you're no longer in their contacts") for good.
    if (OnionRequests.isRemovedBy(pub)) {
      _log('${peer.username} (${peer.onionAddress}) answers our hello now: '
          'clearing the old "not in their contacts" mark');
      unawaited(OnionRequests.clearRemovedBy(pub));
      _removedRecheckAt.remove(pub);
    }
    // A channel only opens once they treat us as a contact: if we had a
    // request out to them, it's been accepted. (Usually _acceptedByThem has
    // handled it already; this catches a request sent while they were
    // already pinned here -- the chat note must show up on our side too.)
    if (OnionRequests.outgoingByPub(pub) != null ||
        OnionRequests.isOutgoingPending(peer.username)) {
      _log('@${peer.username} accepted our contact request');
      onContactAdded?.call(peer.username, false);
    }
    unawaited(OnionRequests.clearOutgoing(pub));
    _refreshPresenceFor(peer.username);
    _refreshConnecting();
    // Anything queued for them can go now.
    _onPeerSeen(peer);
    unawaited(syncProfileToPeers());
  }

  void _closeChannel(_PeerChannel ch, {required String reason}) {
    if (ch.closed) return;
    ch.closed = true;
    if (!ch.opened.isCompleted) ch.opened.complete(false);
    _channelByHandle.remove(ch.handle);
    final wasCurrent = _channels[ch.pub] == ch;
    if (wasCurrent) _channels.remove(ch.pub);
    for (final entry in _pendingAcks.entries.toList()) {
      if (entry.value.channel == ch && !entry.value.completer.isCompleted) {
        entry.value.completer.complete(false);
      }
    }
    unawaited(OnionIdentity.plugin.streamClose(ch.handle));
    final peer = OnionPairedPeers.byPub(ch.pub);
    if (ch.open) {
      _log('channel to ${peer?.username ?? ch.pub} closed: $reason');
    }
    if (wasCurrent) {
      // Try to get it back quickly; counts as a fresh "connecting" phase.
      _dialFailures.remove(ch.pub);
      _nextDialAt[ch.pub] = DateTime.now().add(const Duration(seconds: 2));
      if (peer != null) _refreshPresenceFor(peer.username);
    }
    _refreshConnecting();
  }

  /// Seals and writes one frame on a channel (writes to one stream are
  /// serialized in [_writeFrame], so concurrent senders never interleave).
  Future<void> _channelSend(
      _PeerChannel ch, Map<String, dynamic> payload) async {
    if (ch.closed) throw StateError('channel closed');
    await _sendSealedFrame(ch.handle, base64Decode(ch.pub), payload);
  }

  /// Runs [fn] against a stream to [device]: its open channel if there is
  /// one, the old dial-and-close path for a legacy peer, otherwise nothing
  /// (returns false and nudges the connector to dial so a queued retry can
  /// go out once the channel opens).
  Future<bool> _withStream(
      OnionPeer device, Future<void> Function(int handle) fn,
      {bool dialIfMissing = true}) async {
    final pub = device.identityPubB64;
    final ch = _channels[pub];
    if (ch != null) {
      ch.writing++;
      try {
        await fn(ch.handle);
        return true;
      } catch (e) {
        _closeChannel(ch, reason: 'write failed: $e');
        return false;
      } finally {
        ch.writing--;
      }
    }
    if (!_legacyPubs.contains(pub)) {
      if (dialIfMissing) _maybeDial(device, force: true);
      return false;
    }
    int? handle;
    try {
      handle = await _dialWithRetry(
        device.onionAddress,
        delays: const [Duration(seconds: 3), Duration(seconds: 6)],
      );
      if (handle == null) return false;
      await fn(handle);
      return true;
    } catch (e) {
      _log('legacy send to ${device.username} failed: $e');
      return false;
    } finally {
      if (handle != null) await OnionIdentity.plugin.streamClose(handle);
    }
  }

  void _refreshConnecting() {
    final set = <String>{};
    for (final pub in _dialing) {
      if (_channels.containsKey(pub) || _legacyPubs.contains(pub)) continue;
      if ((_dialFailures[pub] ?? 0) > 0) continue;
      final peer = OnionPairedPeers.byPub(pub);
      if (peer != null && !isConnected(peer.username)) set.add(peer.username);
    }
    if (!setEquals(set, connectingUsers.value)) connectingUsers.value = set;
  }

  /// Tells every paired device our current online visibility and custom
  /// status text -- over the open channel where there is one, the old
  /// dial-per-frame way for legacy peers.
  Future<void> broadcastPresence() async {
    if (!isRunning) return;
    final visible = SettingsManager.statusVisibility.value != 'hide';
    final text = visible ? SettingsManager.statusOnline.value.trim() : '';
    final frame = {'type': 'presence', 'visible': visible, 'text': text};
    await Future.wait(
        List<OnionPeer>.of(OnionPairedPeers.peers.value).map((d) async {
      final ch = _channels[d.identityPubB64];
      if (ch != null) {
        await _channelSend(ch, frame).catchError((_) {});
      } else if (_legacyPubs.contains(d.identityPubB64)) {
        await _withStream(
            d, (h) => _sendSealedFrame(h, d.identityPub, frame));
      }
    }));
  }

  void _applyPresence(OnionPeer peer, bool visible, String text) {
    _presence[peer.identityPubB64] =
        _PeerPresence(DateTime.now(), visible, text);
    _refreshPresenceFor(peer.username);
  }

  void _refreshAllPresence() {
    final names = <String>{
      for (final d in OnionPairedPeers.peers.value) d.username,
    };
    for (final n in names) {
      _refreshPresenceFor(n);
    }
  }

  /// Recomputes one contact's online/status entries in the app-wide
  /// notifiers. A device counts as online only while its channel is open
  /// (i.e. a message sent now will actually arrive); a legacy device, which
  /// has no channel, by a fresh dialed presence frame as before.
  void _refreshPresenceFor(String username) {
    final now = DateTime.now();
    var online = false;
    var hidden = false;
    var text = '';
    for (final d in OnionPairedPeers.allByUsername(username)) {
      final pub = d.identityPubB64;
      if (OnionRequests.isRemovedBy(pub)) continue; // not our contact there
      final p = _presence[pub];
      if (p == null) continue;
      if (_channels.containsKey(pub)) {
        // open channel: reachable right now
      } else if (!_legacyPubs.contains(pub) ||
          now.difference(p.at) > _presenceTtl) {
        continue;
      }
      if (!p.visible) {
        hidden = true;
        continue;
      }
      online = true;
      if (p.text.isNotEmpty) text = p.text;
    }

    final onlineSet = Set<String>.from(onlineUsersNotifier.value);
    if (online != onlineSet.contains(username)) {
      if (online) {
        onlineSet.add(username);
      } else {
        onlineSet.remove(username);
      }
      onlineUsersNotifier.value = onlineSet;
    }

    final statuses = Map<String, String>.from(userStatusNotifier.value);
    final String? wantText = online && text.isNotEmpty ? text : null;
    if (statuses[username] != wantText) {
      if (wantText == null) {
        statuses.remove(username);
      } else {
        statuses[username] = wantText;
      }
      userStatusNotifier.value = statuses;
    }

    final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);
    final String? wantVis = online ? 'show' : (hidden ? 'hide' : null);
    if (vis[username] != wantVis) {
      if (wantVis == null) {
        vis.remove(username);
      } else {
        vis[username] = wantVis;
      }
      userStatusVisibilityNotifier.value = vis;
    }
  }

  /// Any authenticated frame from a paired device proves it is reachable
  /// right now -- flush its queued messages immediately instead of waiting
  /// for the next retry tick.
  void _onPeerSeen(OnionPeer peer) {
    final queued =
        OnionSendQueue.items.value.any((i) => i.peerUsername == peer.username);
    if (!queued) return;
    if (_retrying) {
      _flushAgain = true;
      return;
    }
    unawaited(_processQueue());
  }

  /// (Re)starts the queue retry loop at the user-configured interval.
  void _startRetryTimer() {
    _retryTimer?.cancel();
    final interval =
        Duration(seconds: SettingsManager.onionRetryIntervalSeconds.value);
    nextRetryAt.value = DateTime.now().add(interval);
    _retryTimer = Timer.periodic(interval, (_) {
      nextRetryAt.value = DateTime.now().add(interval);
      unawaited(_processQueue());
    });
  }

  /// When the queue's next retry tick fires (null while onion mode is
  /// stopped); the UI counts down to this under a waiting message.
  final ValueNotifier<DateTime?> nextRetryAt = ValueNotifier<DateTime?>(null);

  /// True while a retry tick is actively dialing queued peers.
  final ValueNotifier<bool> retryingNow = ValueNotifier<bool>(false);

  /// Fired when a message could not be delivered right now and was queued
  /// for background retry -- i.e. the peer is presumed offline.
  void Function(String peerUsername)? onPeerOffline;

  Future<void> stop() async {
    SettingsManager.onionRetryIntervalSeconds.removeListener(_startRetryTimer);
    _retryTimer?.cancel();
    _retryTimer = null;
    nextRetryAt.value = null;
    await _stopWatchingConnectivity();
    for (final pub in List<String>.of(_callActive)) {
      stopCallPaths(pub);
    }
    _stopChannels();
    _presence.clear();
    _refreshAllPresence(); // everyone offline now
    _sessionKeys.clear(); // derived from this account's key
    for (final p in _pendingDataStreams.values) {
      if (!p.$2.isCompleted) p.$2.complete(null);
    }
    _pendingDataStreams.clear();
    // Abandons (deletes .part files for) any transfers still in flight from
    // the account/identity that's being torn down -- otherwise they'd sit
    // in this map indefinitely (nothing will ever send their remaining
    // chunks again) and, worse, a same-named leftover .part from a
    // just-abandoned transfer could get silently completed and misattributed
    // if a *new* transfer for the new identity happened to reuse the same
    // transferId, however astronomically unlikely that collision is.
    for (final t in List<_IncomingMediaTransfer>.of(_incomingTransfers.values)) {
      t._abandon();
    }
    _incomingTransfers.clear();
    await _eventsSub?.cancel();
    _eventsSub = null;
    await OnionIdentity.stop();
  }

  /// Retries every queued send once, oldest first. A single failed peer
  /// (still offline) shouldn't block a different peer's queued messages
  /// from being attempted the same tick, so failures just leave that one
  /// entry in place and move on -- not a fatal error, just "still offline".
  Future<void> _processQueue() async {
    if (_retrying) return; // don't overlap with a still-running previous tick
    _retrying = true;
    if (OnionSendQueue.items.value.isNotEmpty) retryingNow.value = true;
    try {
      for (final item in List<QueuedOnionSend>.from(OnionSendQueue.items.value)) {
        // Cancelled (see [cancelPendingSend]) while an earlier item in this
        // same tick was still dialing -- don't send it after all.
        if (!OnionSendQueue.items.value.any((i) => i.id == item.id)) continue;
        // Pinned to a specific device (the normal case, see
        // QueuedOnionSend.targetPub) -- must go to that exact device. A
        // null targetPub only happens for an item persisted by an older
        // build before this field existed; fall back to the old
        // single-device lookup for those.
        final device = item.targetPub != null
            ? _knownDevice(item.targetPub!)
            : OnionPairedPeers.byUsername(item.peerUsername);
        if ((item.kind == 'sent_copy' || item.kind == 'own') &&
            device == null) {
          // That own device got unlinked: nobody left to give it to.
          await OnionSendQueue.remove(item.id);
          continue;
        }
        if (item.kind == 'own') {
          // Our Tor channel to it, or WardLink -- works without Tor here.
          if (await _deliverOwnItem(item)) {
            await OnionSendQueue.remove(item.id);
          } else {
            await OnionSendQueue.bumpAttempts(item.id);
          }
          continue;
        }
        if (device != null &&
            !_channels.containsKey(device.identityPubB64) &&
            !_legacyPubs.contains(device.identityPubB64)) {
          // Not connected: nothing to try yet. The connector keeps dialing
          // and the channel opening flushes this (see _onHello).
          _maybeDial(device);
          continue;
        }
        if (item.kind == 'sent_copy') {
          final mid = item.localId;
          final ok = mid != null &&
              !_cancelledMids.contains(mid) &&
              await _sendOwnAcked(
                  device!,
                  _sentCopyPayload(
                      item.peerUsername, item.text ?? '', mid, item.enqueuedAt),
                  mid);
          if (ok || mid == null || _cancelledMids.contains(mid)) {
            await OnionSendQueue.remove(item.id);
          } else {
            await OnionSendQueue.bumpAttempts(item.id);
          }
          continue;
        }
        if (item.kind == 'media_chunked') {
          // A big file can take many minutes -- run it on its own so the
          // rest of the queue (text!) isn't stuck behind it.
          if (_chunkedInFlight.add(item.id)) {
            unawaited(_retryChunkedInBackground(item));
          }
          continue;
        }
        bool ok;
        if (item.kind == 'text') {
          ok = device != null &&
              await _sendTextToDevice(device, item.text ?? '',
                  mid: item.localId);
        } else {
          ok = await _attemptSendMedia(item);
        }
        if (ok) {
          await OnionSendQueue.remove(item.id);
          if (item.localId != null) {
            onDeliveryUpdate?.call(item.peerUsername, item.localId!);
            final origin = item.relayFor;
            if (origin != null) {
              await _sendRelayOk(origin, item.peerUsername, item.localId!);
            }
          }
          _log('queued ${item.kind} to ${item.peerUsername} delivered '
              'after ${item.attempts + 1} attempt(s)');
        } else {
          await OnionSendQueue.bumpAttempts(item.id);
        }
      }
    } finally {
      _retrying = false;
      retryingNow.value = false;
      if (_flushAgain) {
        _flushAgain = false;
        unawaited(_processQueue());
      }
    }
  }

  /// Queued chunked-file retries currently running (by queue item id).
  final Set<String> _chunkedInFlight = {};

  Future<void> _retryChunkedInBackground(QueuedOnionSend item) async {
    try {
      final ok = await _attemptSendMediaChunked(item);
      if (!OnionSendQueue.items.value.any((i) => i.id == item.id)) return;
      if (ok) {
        await OnionSendQueue.remove(item.id);
        _log('queued media_chunked to ${item.peerUsername} delivered '
            'after ${item.attempts + 1} attempt(s)');
      } else {
        await OnionSendQueue.bumpAttempts(item.id);
      }
    } finally {
      _chunkedInFlight.remove(item.id);
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['type'] == 'inbound') {
      final handle = event['handle'];
      if (handle is int) unawaited(_readLoop(handle));
    }
  }

  // ─────────────────────────── pairing (QR) ──────────────────────────────────

  Future<String> pairingQrJson(String username) async {
    final rand = Random.secure();
    final nonce =
        base64Encode(List<int>.generate(16, (_) => rand.nextInt(256)));
    _pairingNonce = nonce;
    return jsonEncode({
      'type': 'onion_pair',
      'v': 1,
      'pub': OnionIdentity.publicKeyB64,
      'username': username,
      'onionAddress': OnionIdentity.onionAddress,
      'name': await _getDisplayName(),
      'os': Platform.operatingSystem,
      'nonce': nonce,
    });
  }

  /// A freshly launched onion service isn't reachable from the wider Tor
  /// network the instant `startHiddenService` returns -- its descriptor
  /// still has to propagate to the network's HSDirs, which can take
  /// anywhere from a few seconds to a couple of minutes. Dialing too early
  /// (e.g. immediately after scanning a QR the other device just generated)
  /// fails with a perfectly healthy address that simply hasn't finished
  /// publishing yet. Retrying with backoff over a generous window turns
  /// that transient failure into an invisible delay instead of a hard error.
  Future<int?> _dialWithRetry(
    String onionAddress, {
    required List<Duration> delays,
    void Function(int attempt, int maxAttempts)? onAttempt,
    String? isolation,
  }) async {
    final maxAttempts = delays.length + 1;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        onAttempt?.call(attempt, maxAttempts);
        await Future.delayed(delays[attempt - 1]);
      }
      try {
        final handle = await OnionIdentity.plugin.dial(
            onionAddress, OnionIdentity.port,
            isolation: isolation);
        if (handle != null && handle >= 1) return handle;
      } catch (_) {
        // fall through and retry
      }
    }
    return null;
  }

  /// Like [_dialWithRetry], but the attempts overlap instead of waiting for
  /// each other: attempt `i` starts at offset `starts[i]` after the first, no
  /// matter whether the earlier ones are still pending, and the first stream
  /// that connects wins (the others are closed as they come in).
  ///
  /// Through Tor a single attempt can sit for tens of seconds before failing
  /// (a guard that drops half its circuits makes that normal), and one that
  /// would have succeeded on a fresh circuit then waits behind it. Staggered
  /// attempts each get their own circuit, so the wait is roughly "time of the
  /// quickest one" rather than "sum of the failures". Each attempt is cut
  /// off after [attemptTimeout]; a late success from a cut-off attempt is
  /// closed, never leaked.
  Future<int?> _dialRace(
    String onionAddress, {
    required List<Duration> starts,
    Duration attemptTimeout = const Duration(seconds: 35),
    void Function(int attempt, int maxAttempts)? onAttempt,
    String? isolation,
  }) {
    final result = Completer<int?>();
    final total = starts.length;
    final timers = <Timer>[];
    var finished = 0;

    void attemptEnded() {
      finished++;
      if (finished == total && !result.isCompleted) result.complete(null);
    }

    void launch(int i) {
      if (result.isCompleted) {
        attemptEnded();
        return;
      }
      if (i > 0) onAttempt?.call(i, total);
      var ended = false;
      void end() {
        if (ended) return;
        ended = true;
        attemptEnded();
      }

      final cutoff = Timer(attemptTimeout, end);
      timers.add(cutoff);
      OnionIdentity.plugin
          .dial(onionAddress, OnionIdentity.port,
              // The first attempt keeps the caller's isolation; the others
              // get their own so they really build separate circuits.
              isolation: i == 0 ? isolation : 'race-$i-${isolation ?? ''}')
          .then((handle) async {
        cutoff.cancel();
        if (handle != null && handle >= 1) {
          if (!ended && !result.isCompleted) {
            result.complete(handle);
          } else {
            await OnionIdentity.plugin.streamClose(handle); // too late
          }
        }
        end();
      }).catchError((Object _) {
        cutoff.cancel();
        end();
      });
    }

    for (var i = 0; i < total; i++) {
      if (starts[i] == Duration.zero) {
        launch(i);
      } else {
        timers.add(Timer(starts[i], () => launch(i)));
      }
    }
    return result.future.whenComplete(() {
      for (final t in timers) {
        t.cancel();
      }
    });
  }

  /// Dials every address in [addresses] at once (each with its own retries)
  /// and returns the first stream that connects, with its address; the
  /// rest are closed as they come in. (null, first address) if none did.
  Future<(int?, String)> _dialFirst(
    List<String> addresses, {
    required List<Duration> starts,
    void Function(int attempt, int maxAttempts)? onAttempt,
  }) async {
    if (addresses.length == 1) {
      final h = await _dialRace(addresses.first,
          starts: starts, onAttempt: onAttempt);
      return (h, addresses.first);
    }
    final winner = Completer<(int?, String)>();
    var pending = addresses.length;
    for (var i = 0; i < addresses.length; i++) {
      final addr = addresses[i];
      unawaited(_dialRace(addr,
              starts: starts, onAttempt: i == 0 ? onAttempt : null)
          .then((h) async {
        if (h != null && !winner.isCompleted) {
          winner.complete((h, addr));
        } else if (h != null) {
          await OnionIdentity.plugin.streamClose(h); // someone was faster
        }
        if (--pending == 0 && !winner.isCompleted) {
          winner.complete((null, addresses.first));
        }
      }));
    }
    return winner.future;
  }

  /// Sending a contact request interactively: when each overlapping attempt
  /// starts (see [_dialRace]). About 50 s at most before it's queued for
  /// later (see [retryQueuedRequests]).
  static const List<Duration> _requestDialStarts = [
    Duration.zero,
    Duration(seconds: 3),
    Duration(seconds: 7),
    Duration(seconds: 12),
    Duration(seconds: 20),
  ];

  // ── Requests to people who were offline ──────────────────────────────────

  /// How often a queued contact request is retried (plus once at every
  /// start). Finding an onion service takes Tor tens of seconds anyway, so
  /// more often buys nothing; much less makes "they came online" feel slow.
  static const Duration _queuedRequestInterval = Duration(minutes: 3);

  Timer? _queuedRequestTimer;
  bool _retryingQueued = false;

  /// Set by root_screen: a queued request finally got through.
  void Function(String username)? onQueuedRequestDelivered;

  /// Tries every queued contact request once (one dial each). Delivered or
  /// failed for good (not an onion address, our own...) -> dequeued; still
  /// unreachable -> stays for the next round.
  Future<void> retryQueuedRequests() async {
    final me = _username;
    if (_retryingQueued || me == null || !isRunning) return;
    final queued = OnionRequests.queuedRequests;
    if (queued.isEmpty) return;
    _retryingQueued = true;
    try {
      for (final e in queued.entries) {
        if (!isRunning) return;
        // Replaced/removed meanwhile (sent again from the search)?
        if (OnionRequests.queuedRequests[e.key] != e.value) continue;
        var unreachable = false;
        final (username, error) = await connectByAddress(e.key, me,
            comment: e.value.isEmpty ? null : e.value,
            quick: true,
            onUnreachable: () => unreachable = true);
        if (username != null) {
          await OnionRequests.dequeueRequest(e.key);
          _log('queued contact request to $username delivered');
          onQueuedRequestDelivered?.call(username);
        } else if (!unreachable) {
          await OnionRequests.dequeueRequest(e.key);
          _log('queued contact request to ${e.key} dropped: $error');
        }
      }
    } finally {
      _retryingQueued = false;
    }
  }

  /// Pairing / address verification: longer, since a freshly started onion
  /// service can need a while to be found (its descriptor has to propagate).
  static const List<Duration> _pairingDialStarts = [
    Duration.zero,
    Duration(seconds: 3),
    Duration(seconds: 7),
    Duration(seconds: 12),
    Duration(seconds: 20),
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(seconds: 65),
    Duration(seconds: 90),
  ];

  /// Progress callback for a retried pairing/connect dial, so the calling UI
  /// can show something better than a frozen spinner while the other side's
  /// onion descriptor is still propagating across Tor.
  void Function(int attempt, int maxAttempts)? onPairingRetry;

  /// Called after the scanning device reads an `onion_pair` QR. Pins the
  /// shown peer locally, then dials them over Tor to prove we scanned their
  /// code -- establishing mutual trust from a single scan, same as
  /// WardLink's `completePairingFromQr`. Returns null on success or an error
  /// string.
  Future<String?> completePairingFromQr(
      String qrJson, String myUsername) async {
    Map<String, dynamic> qr;
    try {
      qr = jsonDecode(qrJson) as Map<String, dynamic>;
    } catch (_) {
      return 'Invalid QR code';
    }
    if (qr['type'] != 'onion_pair') return 'Not an onion pairing code';

    final peerPub = qr['pub'] as String?;
    final peerUsername = qr['username'] as String?;
    final peerOnionAddress = qr['onionAddress'] as String?;
    final nonce = qr['nonce'] as String?;
    if (peerPub == null ||
        peerUsername == null ||
        peerOnionAddress == null ||
        nonce == null) {
      return 'Malformed pairing code';
    }
    if (peerPub == OnionIdentity.publicKeyB64) {
      return 'Cannot pair with yourself';
    }
    if (peerUsername == myUsername) {
      return 'That code belongs to your own account';
    }

    await OnionRequests.unblock(peerPub); // scanned in person: chosen again
    await OnionPairedPeers.add(OnionPeer(
      username: peerUsername,
      identityPubB64: peerPub,
      onionAddress: peerOnionAddress,
      name: (qr['name'] as String?) ?? 'Onyx user',
      os: (qr['os'] as String?) ?? 'unknown',
      pairedAt: DateTime.now(),
    ));

    int? handle;
    try {
      handle = await _dialRace(
        peerOnionAddress,
        starts: _pairingDialStarts,
        onAttempt: onPairingRetry,
      );
      if (handle == null) {
        await OnionPairedPeers.remove(peerPub);
        return 'Could not reach the other device over Tor -- their address may still be publishing. Try again in a minute.';
      }
      await _sendSealedFrame(handle, base64Decode(peerPub), {
        'type': 'pair_request',
        'nonce': nonce,
        'username': myUsername,
        'onionAddress': OnionIdentity.onionAddress,
        'name': await _getDisplayName(),
        'os': Platform.operatingSystem,
      });
      unawaited(syncProfileToPeers());
      return null;
    } catch (e) {
      await OnionPairedPeers.remove(peerPub);
      return 'Pairing failed: $e';
    } finally {
      if (handle != null) await OnionIdentity.plugin.streamClose(handle);
    }
  }

  Future<void> _handlePairRequest(
      String peerPubB64, Map<String, dynamic> payload) async {
    if (payload['nonce'] != _pairingNonce) {
      // Stale/foreign QR (already used, or never ours) -- ignore silently,
      // same as WardLink rejecting an unrecognised nonce.
      return;
    }
    final peerUsername = payload['username'] as String?;
    final peerOnionAddress = payload['onionAddress'] as String?;
    if (peerUsername == null || peerOnionAddress == null) return;
    await OnionRequests.unblock(peerPubB64); // paired in person: chosen again
    await OnionPairedPeers.add(OnionPeer(
      username: peerUsername,
      identityPubB64: peerPubB64,
      onionAddress: peerOnionAddress,
      name: (payload['name'] as String?) ?? 'Onyx user',
      os: (payload['os'] as String?) ?? 'unknown',
      pairedAt: DateTime.now(),
    ));
    _pairingNonce = null; // single-use
    unawaited(syncProfileToPeers());
  }

  // ─────────────────────────── connect by address ────────────────────────────

  /// Initiates contact with a peer known only by their bare onion address
  /// (e.g. pasted into search) -- no prior QR exchange needed. Dials them,
  /// sends an unencrypted identify request carrying our own pubkey, and
  /// pins whatever identity they reply with (trust-on-first-use, like
  /// adding a contact by phone number).
  ///
  /// Returns `(username, null)` on success or `(null, errorMessage)` on
  /// failure -- a record rather than a single nullable String, since both
  /// a peer's username and an error message are themselves plain Strings
  /// and would otherwise be indistinguishable to the caller.
  /// [comment]: what the user wrote in the request modal -- it travels in
  /// the identify_request itself, so the request and its comment arrive as
  /// one (shown on their Requests screen; ignored if we're already their
  /// contact).
  ///
  /// [quick]: one dial attempt, no progress callbacks -- the background
  /// retry of a queued request (see [retryQueuedRequests]).
  /// [onUnreachable]: called when it failed because they couldn't be
  /// reached (offline) -- worth queueing and retrying, unlike other errors.
  ///
  /// [alsoTry]: more addresses of the same person (an onyx: code with all
  /// their devices). All are dialed AT ONCE and the first device to answer
  /// takes the request -- dialing them one after another kept the user
  /// waiting through every retry of an offline device first.
  Future<(String?, String?)> connectByAddress(
      String onionAddress, String myUsername,
      {String? comment,
      bool quick = false,
      void Function()? onUnreachable,
      List<String> alsoTry = const []}) async {
    final own = OnionIdentity.onionAddress.toLowerCase();
    final candidates = <String>[];
    for (final a in [onionAddress, ...alsoTry]) {
      final n = a.trim().toLowerCase();
      if (onionAddressPattern.hasMatch(n) &&
          n != own &&
          !candidates.contains(n)) {
        candidates.add(n);
      }
    }
    if (candidates.isEmpty) {
      final n = onionAddress.trim().toLowerCase();
      return (
        null,
        n == own ? 'That is your own address' : 'Not a valid onion address'
      );
    }

    int? handle;
    try {
      final String normalized;
      // Interactive: a few tries (a fresh descriptor can take a moment),
      // then it's queued rather than keeping the user waiting minutes.
      (handle, normalized) = await _dialFirst(
        candidates,
        starts: quick ? const [Duration.zero] : _requestDialStarts,
        onAttempt: quick ? null : onPairingRetry,
      );
      if (handle == null) {
        onUnreachable?.call();
        return (
          null,
          'Could not reach that address over Tor -- it may be offline, mistyped, or still publishing.'
        );
      }

      await _sendIdentifyFrame(handle, 'identify_request', myUsername,
          comment: comment);

      final assembler = _FrameAssembler();
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(deadline)) {
        final result =
            await OnionIdentity.plugin.streamRead(handle, 65536, 5000);
        if (result.n == 0) {
          onUnreachable?.call();
          return (null, 'Connection closed before they responded');
        }
        if (result.n == -3) continue;
        if (result.n < 0) {
          onUnreachable?.call();
          return (null, 'Read error while waiting for their reply');
        }
        final data = result.data;
        if (data != null) assembler.addChunk(data);
        final frame = assembler.tryTakeFrame();
        if (frame == null) continue;
        if (frame.tag != 1) return (null, 'Unexpected reply from that address');

        Map<String, dynamic> obj;
        try {
          obj = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
        } catch (_) {
          return (null, 'Malformed reply');
        }
        if (obj['type'] != 'identify_response') {
          return (null, 'Unexpected reply type');
        }
        final peerPub = obj['pub'] as String?;
        final peerUsername = obj['username'] as String?;
        if (peerPub == null || peerUsername == null) {
          return (null, 'Malformed reply');
        }
        if (peerPub == OnionIdentity.publicKeyB64 ||
            peerUsername == myUsername) {
          return (null, 'That is your own account');
        }
        // Usernames are self-claimed: a different key under the name of an
        // existing contact would merge into their chat (and receive what we
        // send them). Never silently -- the old contact has to go first.
        final clash = OnionPairedPeers.allByUsername(peerUsername)
            .any((p) => p.identityPubB64 != peerPub);
        if (clash) {
          return (
            null,
            'You already have a contact @$peerUsername with a different key. '
                'If they reinstalled Onyx, unpair the old one in Settings '
                'and add them again.'
          );
        }
        // We added them ourselves: whatever we decided before no longer
        // stands, and a request they sent us is accepted by this.
        await OnionRequests.unblock(peerPub);
        final pending = await OnionRequests.take(peerPub);
        if (pending == null && !obj.containsKey('os')) {
          // They answered us as a stranger (see _handleIdentifyRequest's
          // minimal reply): a request now waits for their approval. They
          // become a contact only when they accept -- their 'hello' (see
          // _acceptedByThem). Older builds always send 'os' and trust us
          // right away, so they're added below as before.
          // Their account key, if the device we dialed vouches for it: then
          // an acceptance from any device of that account counts.
          final roster = await OnionAccount.verify(obj['r']);
          await OnionRequests.markOutgoing(peerPub, peerUsername,
              onionAddress: normalized,
              name: (obj['name'] as String?) ?? '',
              acct: roster != null && roster.lists(peerPub)
                  ? roster.acct
                  : null);
          return (peerUsername, null);
        }
        await OnionPairedPeers.add(OnionPeer(
          username: peerUsername,
          identityPubB64: peerPub,
          // The address we dialed -- the reply is from it; a claimed one
          // could be anybody's.
          onionAddress: normalized,
          name: (obj['name'] as String?) ?? pending?.name ?? 'Onyx user',
          os: (obj['os'] as String?) ?? 'unknown',
          pairedAt: DateTime.now(),
        ));
        // They answered as to a contact: whatever "removed us" we noted
        // before is stale.
        await OnionRequests.clearRemovedBy(peerPub);
        _removedRecheckAt.remove(peerPub);
        if (pending != null) {
          // They had asked us first: adding them back accepts it.
          onContactAdded?.call(peerUsername, true);
        }
        unawaited(syncProfileToPeers());
        return (peerUsername, null);
      }
      onUnreachable?.call();
      return (null, 'Timed out waiting for their reply');
    } catch (e) {
      onUnreachable?.call();
      return (null, 'Connection failed: $e');
    } finally {
      if (handle != null) await OnionIdentity.plugin.streamClose(handle);
    }
  }

  Future<void> _handleIdentifyRequest(
      int handle, Map<String, dynamic> payload) async {
    final peerPub = payload['pub'] as String?;
    final peerUsername = payload['username'] as String?;
    final peerOnionAddress = payload['onionAddress'] as String?;
    if (peerPub == null || peerUsername == null || peerOnionAddress == null) {
      return;
    }
    if (peerPub == OnionIdentity.publicKeyB64) return; // somehow our own key
    if (peerUsername == _username) return;
    final normalized = peerOnionAddress.trim().toLowerCase();
    if (!onionAddressPattern.hasMatch(normalized)) return;
    List<int> pubBytes;
    try {
      pubBytes = base64Decode(peerPub);
    } catch (_) {
      return;
    }
    if (pubBytes.length != 32) return;
    if (_isBlockedPub(peerPub)) return; // blocked: no reply at all

    final myUsername = _username;
    if (myUsername == null) return; // shouldn't happen once start() ran
    final known = OnionPairedPeers.byPub(peerPub) != null;
    try {
      // They dialed our address: like a username lookup anywhere, they see
      // the display name we go by. The OS stays out until accepted; the
      // avatar comes with the profile once there's a channel.
      await _sendIdentifyFrame(handle, 'identify_response', myUsername,
          minimal: !known);
    } catch (e) {
      _log('identify_response send failed: $e');
    }
    if (known) return;

    final comment = (payload['comment'] as String?)?.trim() ?? '';
    unawaited(_verifyRequester(
      pub: peerPub,
      pubBytes: pubBytes,
      username: peerUsername,
      onionAddress: normalized,
      name: (payload['name'] as String?) ?? 'Onyx user',
      comment: comment.isEmpty
          ? null
          : (comment.length > OnionRequests.maxMessageLength
              ? comment.substring(0, OnionRequests.maxMessageLength)
              : comment),
    ));
  }

  /// Requests whose address is being verified right now, with their comment.
  final Map<String, List<OnionRequestMessage>> _verifying = {};

  /// Files a contact request, but only once the device at the claimed
  /// [onionAddress] proves it holds [pubBytes]: we dial that address
  /// ourselves (Tor guarantees we reach whoever owns it) and send a sealed
  /// 'verify' only the holder of that key can answer. A request borrowing
  /// somebody else's address never shows up.
  Future<void> _verifyRequester({
    required String pub,
    required List<int> pubBytes,
    required String username,
    required String onionAddress,
    required String name,
    String? comment,
  }) async {
    if (_verifying.containsKey(pub)) return;
    // Each check is an outgoing Tor dial: a flood of made-up keys must not
    // turn into a flood of dials.
    if (_verifying.length >= 5) {
      _log('too many contact requests being verified, dropping @$username');
      return;
    }
    _verifying[pub] = [
      if (comment != null)
        OnionRequestMessage(text: comment, at: DateTime.now()),
    ];
    try {
      final ok = await _proveAddress(onionAddress, pubBytes);
      if (!ok) {
        _log('contact request from @$username ($onionAddress): address not '
            'verified, dropped');
        return;
      }
      if (OnionPairedPeers.byPub(pub) != null || OnionRequests.isBlocked(pub)) {
        return; // accepted by adding them ourselves / declined meanwhile
      }
      if (OnionRequests.outgoingByPub(pub) != null) {
        // We had asked them too: they're accepting ours by adding us (their
        // 'hello' follows and makes them a contact) -- no request needed.
        return;
      }
      final req = OnionContactRequest(
        pub: pub,
        username: username,
        onionAddress: onionAddress,
        name: name,
        receivedAt: DateTime.now(),
        messages: List.of(_verifying[pub] ?? const []),
      );
      await OnionRequests.upsert(req);
      _log('contact request from @$username ($onionAddress) verified');
      onContactRequest?.call(OnionRequests.byPub(pub) ?? req);
      // Our other devices show it too (verified here -- they trust us).
      unawaited(_queueOwnEvent({
        'k': 'req',
        'id': 'req:$pub:${req.receivedAt.millisecondsSinceEpoch}',
        'r': req.toJson(),
      }, peerUsername: username));
    } finally {
      _verifying.remove(pub);
    }
  }

  /// Dials [onionAddress] and checks the device there answers a sealed
  /// challenge as [pubBytes].
  Future<bool> _proveAddress(String onionAddress, List<int> pubBytes) async {
    int? handle;
    try {
      handle = await _dialRace(onionAddress, starts: _pairingDialStarts);
      if (handle == null) return false;
      final rand = Random.secure();
      final nonce =
          base64Encode(List<int>.generate(16, (_) => rand.nextInt(256)));
      await _sendSealedFrame(handle, pubBytes, {'type': 'verify', 'nonce': nonce});
      final expectPub = base64Encode(pubBytes);
      final assembler = _FrameAssembler();
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (DateTime.now().isBefore(deadline)) {
        final r = await OnionIdentity.plugin.streamRead(handle, 65536, 5000);
        if (r.n == -3) continue;
        if (r.n <= 0) return false;
        final data = r.data;
        if (data != null) assembler.addChunk(data);
        _RawFrame? frame;
        while ((frame = assembler.tryTakeFrame()) != null) {
          final obj = await _openSealedFrom(frame!, expectPub);
          if (obj != null &&
              obj['type'] == 'verify_ok' &&
              obj['nonce'] == nonce) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      _log('address verification of $onionAddress failed: $e');
      return false;
    } finally {
      if (handle != null) await OnionIdentity.plugin.streamClose(handle);
    }
  }

  /// Decrypts a tag-0 JSON frame, but only if it's from [expectPub].
  Future<Map<String, dynamic>?> _openSealedFrom(
      _RawFrame frame, String expectPub) async {
    if (frame.tag != 0 || frame.payload.length < 4) return null;
    final pubLen =
        ByteData.sublistView(frame.payload, 0, 4).getUint32(0, Endian.big);
    if (frame.payload.length < 4 + pubLen) return null;
    try {
      final pubB64 = utf8.decode(frame.payload.sublist(4, 4 + pubLen));
      if (pubB64 != expectPub) return null;
      final (key, keyBytes) = await _sessionKeyFor(base64Decode(pubB64));
      final plain = await OnionCrypto.openFrameFast(
          frame.payload.sublist(4 + pubLen), key, keyBytes);
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Accepts a contact request: they become a contact (channel, presence,
  /// profile, calls). Its comment stays a comment -- not a chat message.
  Future<OnionContactRequest?> acceptRequest(String pub) async {
    final req = await OnionRequests.take(pub);
    if (req == null) return null;
    final peer = OnionPeer(
      username: req.username,
      identityPubB64: req.pub,
      onionAddress: req.onionAddress,
      name: req.name,
      os: 'unknown',
      pairedAt: DateTime.now(),
    );
    await OnionPairedPeers.add(peer);
    // They took us for an old build while we ignored their 'hello'; and a
    // "not in their contacts" left over from before must not stop the dial
    // that tells them we accepted.
    await OnionRequests.clearRemovedBy(pub);
    _removedRecheckAt.remove(pub);
    _legacyPubs.remove(pub);
    _nextDialAt.remove(pub);
    _dialFailures.remove(pub);
    _maybeDial(peer, force: true); // our 'hello' = "accepted" on their side
    onContactAdded?.call(req.username, true);
    unawaited(syncProfileToPeers());
    unawaited(_requestDoneOnOwnDevices(pub, 'accept', peer: peer));
    return req;
  }

  /// Tells our other devices a request was answered here, so it leaves
  /// their Requests screen too (and, if accepted, they have the contact).
  Future<void> _requestDoneOnOwnDevices(String pub, String how,
      {OnionPeer? peer}) =>
      _queueOwnEvent({
        'k': 'req_done',
        'id': 'req_done:$pub:$how:${DateTime.now().millisecondsSinceEpoch}',
        'pub': pub,
        'how': how,
        if (peer != null) 'peer': peer.toJson(),
      });

  /// Set by root_screen: [username] just became a contact -- [byMe]: we
  /// accepted their request; otherwise they accepted ours. The chat with
  /// them shows up then (on both sides).
  void Function(String username, bool byMe)? onContactAdded;

  /// A 'hello' from a key we sent a request to: they accepted it (a channel
  /// only comes from someone who has us as a contact). Only now do they
  /// become our contact -- with the address we dialed when sending it.
  Future<OnionPeer?> _acceptedByThem(String pub) async {
    final out = OnionRequests.outgoingByPub(pub);
    if (out == null) return null;
    final (username, address, name) = out;
    final peer = OnionPeer(
      username: username,
      identityPubB64: pub,
      onionAddress: address,
      name: name.isNotEmpty ? name : 'Onyx user',
      os: 'unknown',
      pairedAt: DateTime.now(),
    );
    await OnionPairedPeers.add(peer);
    await OnionRequests.clearOutgoing(pub);
    await OnionRequests.dequeueRequest(address);
    _log('@$username accepted our contact request');
    onContactAdded?.call(username, false);
    return peer;
  }

  /// Keys being checked by [_acceptedByAddress] right now.
  final Set<String> _checkingAccept = {};

  /// A 'hello' from a key we have no record of, but carrying the address of
  /// someone we sent (or queued) a request to: they accepted it, and we just
  /// never got their identify_response (it timed out over Tor, so the
  /// request got queued without their key). Their claim is checked like a
  /// request's -- we dial that address and the device there must prove it
  /// holds this key -- and only then do they become a contact; we then open
  /// the channel ourselves (this 'hello' has long timed out by then).
  Future<void> _acceptedByAddress(
      String pub, List<int> pubBytes, Map<String, dynamic> hello) async {
    final address = (hello['a'] as String?)?.trim().toLowerCase();
    final username = hello['u'] as String?;
    if (address == null || username == null || username.isEmpty) return;
    if (!onionAddressPattern.hasMatch(address)) return;
    if (!OnionRequests.hasRequestTo(address)) return;
    if (!_checkingAccept.add(pub)) return;
    try {
      if (!await _proveAddress(address, pubBytes)) {
        _log('hello claiming $address: address not verified, ignored');
        return;
      }
      if (OnionPairedPeers.byPub(pub) != null) return;
      final peer = OnionPeer(
        username: username,
        identityPubB64: pub,
        onionAddress: address,
        name: 'Onyx user', // their profile follows once the channel opens
        os: 'unknown',
        pairedAt: DateTime.now(),
      );
      await OnionPairedPeers.add(peer);
      await OnionRequests.clearOutgoing(pub);
      await OnionRequests.dequeueRequest(address);
      _log('@$username accepted our contact request (recognised by address)');
      onContactAdded?.call(username, false);
      _nextDialAt.remove(pub);
      _maybeDial(peer, force: true);
    } finally {
      _checkingAccept.remove(pub);
    }
  }

  /// Declines a request; with [block] that key is ignored from now on.
  Future<void> declineRequest(String pub, {bool block = false}) async {
    await OnionRequests.decline(pub, block: block);
    await _requestDoneOnOwnDevices(pub, block ? 'block' : 'decline');
  }

  /// Blocked: a contact whose username is on the blocklist, or a key blocked
  /// from the Requests screen. Nothing from it is processed (messages,
  /// calls, files, profile, presence), and we never open a channel to it --
  /// so it doesn't see us online either.
  bool _isBlockedPub(String pub) {
    if (OnionRequests.isBlocked(pub)) return true;
    final peer = OnionPairedPeers.byPub(pub);
    return peer != null && BlocklistManager.isBlocked(peer.username);
  }

  /// Someone just got blocked: drop the channels to them right away.
  void _onBlocklistChanged() {
    for (final ch in List<_PeerChannel>.of(_channelByHandle.values)) {
      if (_isBlockedPub(ch.pub)) _closeChannel(ch, reason: 'blocked');
    }
    final online = Set<String>.from(onlineUsersNotifier.value)
      ..removeAll(BlocklistManager.blockedUsers.value);
    if (online.length != onlineUsersNotifier.value.length) {
      onlineUsersNotifier.value = online;
    }
  }

  /// True when every device of [username] told us we're not in its contacts
  /// (they removed us): nothing can be delivered to them.
  bool isRemovedByAll(String username) {
    final devices = OnionPairedPeers.allByUsername(username);
    return devices.isNotEmpty &&
        devices.every((d) => OnionRequests.isRemovedBy(d.identityPubB64));
  }

  /// Re-asks every device of [username] that is marked "removed us" (a fresh
  /// hello, ignoring the 5-minute pause) and waits up to [wait] for one to
  /// accept. True if at least one device no longer has the mark -- i.e. the
  /// message can be sent after all.
  Future<bool> recheckRemovedBy(String username,
      {Duration wait = const Duration(seconds: 8)}) async {
    for (final d in OnionPairedPeers.allByUsername(username)) {
      if (!OnionRequests.isRemovedBy(d.identityPubB64)) continue;
      _removedRecheckAt.remove(d.identityPubB64);
      _maybeDial(d, force: true);
    }
    final end = DateTime.now().add(wait);
    while (DateTime.now().isBefore(end)) {
      if (!isRemovedByAll(username)) return true;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return !isRemovedByAll(username);
  }

  /// Recomputes [username]'s online state now (e.g. right after unpairing
  /// them, so they don't linger as online).
  void refreshPresence(String username) => _refreshPresenceFor(username);

  /// Set by root_screen: [username]'s device told us we're not in its
  /// contacts -- whatever was queued for it won't be delivered.
  void Function(String username, String pub)? onRemovedByPeer;

  /// Next time we may dial a device that removed us, to notice if they add
  /// us back without dialing us themselves (they normally do dial).
  final Map<String, DateTime> _removedRecheckAt = {};

  /// [peer]'s device answered our 'hello' with 'not_contact': we're not in
  /// its contacts (anymore). From now on: nothing is delivered to it, it's
  /// never shown online, and queued sends to it fail -- until it opens a
  /// channel to us again (accepted / re-added, see _onHello).
  Future<void> _onRemovedBy(OnionPeer peer, int handle) async {
    final pub = peer.identityPubB64;
    // A device we know from their account roster, while another device of
    // that account still has us: it just hasn't got us from its sibling
    // yet (contact sync). Temporary -- keep its queue, try again soon.
    final acct = peer.accountPubB64;
    if (acct != null &&
        OnionPairedPeers.allByUsername(peer.username).any((p) =>
            p.identityPubB64 != pub &&
            p.accountPubB64 == acct &&
            !OnionRequests.isRemovedBy(p.identityPubB64))) {
      _log('${peer.username} (${peer.onionAddress}) does not know us yet '
          '(their other device does): retrying later');
      final ch = _channelByHandle[handle];
      if (ch != null) _closeChannel(ch, reason: 'not synced with its account yet');
      _nextDialAt[pub] = DateTime.now().add(const Duration(seconds: 30));
      return;
    }
    if (!OnionRequests.isRemovedBy(pub)) {
      _log('${peer.username} (${peer.onionAddress}) says we are not in '
          'their contacts');
    }
    await OnionRequests.markRemovedBy(pub);
    _legacyPubs.remove(pub);
    _presence.remove(pub);
    final ch = _channelByHandle[handle];
    if (ch != null) _closeChannel(ch, reason: 'not in their contacts');
    final current = _channels[pub];
    if (current != null) _closeChannel(current, reason: 'not in their contacts');
    _removedRecheckAt[pub] = DateTime.now().add(const Duration(minutes: 5));
    _refreshPresenceFor(peer.username);
    _refreshConnecting();
    onRemovedByPeer?.call(peer.username, pub);
  }

  /// [OnionPeer.name] is only ever set at pairing time -- if the peer sets
  /// (or changes) their nickname afterwards, without this it would stay
  /// stuck showing whatever it was at first contact (often the device
  /// name fallback, e.g. "SM-S711B" or a Windows computer name) forever,
  /// since nothing else ever calls OnionPairedPeers.add() again for them.
  /// Every 'msg'/'media' frame now carries the sender's current display
  /// name, so this just needs to notice when it changed and re-upsert.
  Future<void> _refreshPeerNameIfChanged(
      OnionPeer peer, Map<String, dynamic> payload) async {
    final currentName = payload['name'] as String?;
    if (currentName == null ||
        currentName.isEmpty ||
        currentName == peer.name) {
      return;
    }
    await OnionPairedPeers.add(OnionPeer(
      username: peer.username,
      identityPubB64: peer.identityPubB64,
      onionAddress: peer.onionAddress,
      name: currentName,
      os: peer.os,
      pairedAt: peer.pairedAt,
    ));
    UserCache.invalidate(peer.username);
  }

  // ─────────────────────────── multi-device ─────────────────────────────────
  //
  // Each of the user's devices has its own address and key; the signed
  // roster (onion_account.dart) says which devices make up the account.
  // Contacts learn it from 'hello' / 'roster' frames and fan every message
  // out to all listed devices. Our own devices keep channels to each other
  // and keep contacts, sent messages and the profile in sync over them.

  /// Our signed roster, cached for [_helloPayload] (which is synchronous).
  Map<String, dynamic>? _rosterWire;

  /// The same roster without names / OS / timestamps, for contacts and
  /// strangers (see OnionAccount.signedPublicRoster). Only our own devices
  /// get [_rosterWire].
  Map<String, dynamic>? _publicRosterWire;

  /// Set by root_screen: another of our devices sent a message to [to] --
  /// show it in that chat as ours.
  void Function(
          {required String to,
          required String text,
          required String mid,
          required DateTime at})?
      onSentCopy;

  /// Set by root_screen: another of our devices deleted the message [mid]
  /// it sent to [to] (for everyone).
  void Function({required String to, required String mid})? onDeleteCopy;

  Future<void> _ensureSelfOnRoster() async {
    if (!OnionIdentity.isRunning || !OnionAccount.isLoaded) return;
    final changed = await OnionAccount.ensureSelf(
      devicePub: OnionIdentity.publicKeyB64,
      onion: OnionIdentity.onionAddress,
      name: await _getDeviceName(),
      os: Platform.operatingSystem,
    );
    _rosterWire = await OnionAccount.signedRoster();
    _publicRosterWire = await OnionAccount.signedPublicRoster();
    if (changed) await _onOwnRosterChanged();
  }

  /// Our roster changed (a device added itself / got unlinked): re-sign,
  /// tell every open channel, and reach any new own device.
  Future<void> _onOwnRosterChanged() async {
    _rosterWire = await OnionAccount.signedRoster();
    _publicRosterWire = await OnionAccount.signedPublicRoster();
    final wire = _rosterWire;
    final r = OnionAccount.roster;
    if (r != null && OnionIdentity.isRunning &&
        r.removed.contains(OnionIdentity.publicKeyB64)) {
      _log('this device was unlinked from the account by another device');
    }
    if (wire != null) {
      for (final ch in List<_PeerChannel>.of(_channels.values)) {
        // Full roster to our own devices, the stripped one to contacts.
        final w = OnionAccount.ownDevice(ch.pub) != null
            ? wire
            : _publicRosterWire;
        if (w == null) continue;
        unawaited(_channelSend(ch, {'type': 'roster', 'r': w})
            .catchError((_) {}));
      }
    }
    for (final d in OnionAccount.ownPeers()) {
      _maybeDial(d, force: true);
    }
  }

  /// A contact's device sent its account's roster. The first roster from a
  /// device we already trust that lists that very device binds the account
  /// key to the contact; from then on, every device the key lists is theirs.
  Future<void> _applyContactRoster(OnionPeer from, Object? wire) async {
    final r = await OnionAccount.verify(wire);
    if (r == null || r.acct == OnionAccount.accountPubB64) return;
    // Only the listed device itself may vouch for a roster: otherwise anyone
    // could sign a list naming a contact's device plus one of their own.
    if (!r.lists(from.identityPubB64)) return;
    final bound = from.accountPubB64;
    if (bound != null && bound != r.acct) {
      _log('@${from.username}: roster signed by a different account key, '
          'ignored');
      return;
    }
    if (bound == null) {
      await OnionPairedPeers.bindAccount(
          from.username, r.devices.map((d) => d.pub), r.acct);
      _log('@${from.username}: account key bound');
    }
    await OnionAccount.noteContactRemoved(r.acct, r.removed);
    for (final pub in r.removed) {
      final p = OnionPairedPeers.byPub(pub);
      if (p == null || p.username != from.username || p.accountPubB64 != r.acct) {
        continue;
      }
      _log('@${from.username}: device ${p.onionAddress} unlinked by them');
      await OnionPairedPeers.remove(pub);
      await OnionSendQueue.removeAllForDevice(pub);
      final ch = _channels[pub];
      if (ch != null) _closeChannel(ch, reason: 'device unlinked by owner');
    }
    final tombs = OnionPairedPeers.tombstones;
    for (final d in r.devices) {
      if (r.removed.contains(d.pub) ||
          OnionAccount.isContactDeviceRemoved(r.acct, d.pub) ||
          !onionAddressPattern.hasMatch(d.onion) ||
          d.pub == OnionIdentity.publicKeyB64 ||
          OnionAccount.ownDevice(d.pub) != null) {
        continue;
      }
      final existing = OnionPairedPeers.byPub(d.pub);
      if (existing != null) {
        // Same device, new address (it reinstalled tor state, say).
        if (existing.username == from.username &&
            existing.accountPubB64 == r.acct &&
            existing.onionAddress != d.onion) {
          await OnionPairedPeers.add(OnionPeer(
            username: existing.username,
            identityPubB64: existing.identityPubB64,
            onionAddress: d.onion,
            name: existing.name,
            os: existing.os,
            pairedAt: existing.pairedAt,
            accountPubB64: r.acct,
          ));
        }
        continue;
      }
      // Unpaired by hand after we got to know them: stays unpaired.
      final tomb = tombs[d.pub];
      if (tomb != null && tomb > from.pairedAt.millisecondsSinceEpoch) {
        continue;
      }
      final dev = OnionPeer(
        username: from.username,
        identityPubB64: d.pub,
        onionAddress: d.onion,
        name: from.name,
        os: d.os,
        pairedAt: DateTime.now(),
        accountPubB64: r.acct,
      );
      await OnionPairedPeers.add(dev);
      // A request we may have sent to this device too (from a multi-address
      // code) is answered by its account having accepted us.
      await OnionRequests.clearOutgoing(d.pub);
      _log('@${from.username}: new device ${d.onion} from their roster');
      _maybeDial(dev, force: true);
    }
  }

  /// A 'hello' from a key we don't know yet, carrying a roster. If that
  /// roster is ours, it's a device of ours we haven't heard of (it was just
  /// linked); if it's signed by a contact's bound account key and lists the
  /// key, it's that contact's new device. Returns the device, or null.
  Future<OnionPeer?> _peerFromRoster(String pub, Object? wire) async {
    final r = await OnionAccount.verify(wire);
    if (r == null || !r.lists(pub)) return null;
    final d = r.device(pub)!;
    if (!onionAddressPattern.hasMatch(d.onion)) return null;
    if (r.acct == OnionAccount.accountPubB64) {
      if (await OnionAccount.mergeOwn(r)) await _onOwnRosterChanged();
      final own = OnionAccount.ownPeer(pub);
      if (own != null) _log('new own device ${d.name} (${d.onion})');
      return own;
    }
    if (OnionAccount.isContactDeviceRemoved(r.acct, pub)) return null;
    OnionPeer? anchor;
    for (final p in OnionPairedPeers.peers.value) {
      if (p.accountPubB64 == r.acct) {
        anchor = p;
        break;
      }
    }
    if (anchor == null) {
      // Our contact request went to another device of this account (the
      // one we dialed vouched for the account key, see connectByAddress):
      // they accepted it on this device. Both become contacts.
      final reqPub = OnionRequests.outgoingPubByAccount(r.acct);
      if (reqPub != null) {
        final accepted = await _acceptedByThem(reqPub);
        if (accepted != null) {
          await OnionPairedPeers.bindAccount(
              accepted.username, [reqPub], r.acct);
          anchor = OnionPairedPeers.byPub(reqPub);
          _log('@${accepted.username} accepted our request on another '
              'of their devices');
          if (anchor != null) _maybeDial(anchor, force: true);
        }
      }
    }
    if (anchor == null) return null;
    final tomb = OnionPairedPeers.tombstones[pub];
    if (tomb != null && tomb > anchor.pairedAt.millisecondsSinceEpoch) {
      return null;
    }
    final dev = OnionPeer(
      username: anchor.username,
      identityPubB64: pub,
      onionAddress: d.onion,
      name: anchor.name,
      os: d.os,
      pairedAt: DateTime.now(),
      accountPubB64: r.acct,
    );
    await OnionPairedPeers.add(dev);
    _log('@${anchor.username}: new device ${d.onion} introduced itself');
    return dev;
  }

  /// True if [wire] is a valid roster naming a device we have as a contact
  /// -- a new device of a contact whose account key we haven't bound yet
  /// (their other device's hello will bind it and we dial this one then).
  Future<bool> _rosterOfKnownContact(Object? wire) async {
    final r = await OnionAccount.verify(wire);
    if (r == null) return false;
    return r.devices.any((d) => OnionPairedPeers.byPub(d.pub) != null);
  }

  /// What to give people so they can add us: our own address alone, or --
  /// with more than one device -- an `onyx:` code listing all of them, so
  /// whichever is online can take the request (see parseOnionContactCode).
  String get myContactCode {
    final self = OnionIdentity.onionAddress;
    final others = OnionAccount.otherDevices.value;
    if (others.isEmpty) return self;
    String bare(String a) =>
        a.endsWith('.onion') ? a.substring(0, a.length - 6) : a;
    return 'onyx:${[self, ...others.map((d) => d.onion)].map(bare).join(',')}';
  }

  /// Unlinks one of our other devices from the account: every device of
  /// ours and every contact drops it once they get the new roster.
  Future<void> unlinkOwnDevice(String pub) async {
    if (!await OnionAccount.removeDevice(pub)) return;
    await OnionSendQueue.removeAllForDevice(pub);
    _log('own device $pub unlinked');
    await _onOwnRosterChanged();
  }

  /// A channel to one of our own devices just opened: bring it up to date.
  Future<void> _onOwnChannelOpen(OnionPeer own) async {
    await _sendContactsSync(own);
    if (OnionSendQueue.items.value
        .any((i) => i.targetPub == own.identityPubB64)) {
      if (_retrying) {
        _flushAgain = true;
      } else {
        unawaited(_processQueue());
      }
    }
    unawaited(syncProfileToPeers());
  }

  Timer? _contactsSyncDebounce;

  void _onContactsChanged() {
    if (OnionAccount.otherDevices.value.isEmpty) return;
    _contactsSyncDebounce?.cancel();
    _contactsSyncDebounce = Timer(const Duration(seconds: 2), () {
      for (final own in OnionAccount.ownPeers()) {
        unawaited(_sendContactsSync(own));
      }
    });
  }

  Future<void> _sendContactsSync(OnionPeer own) async {
    final ch = _channels[own.identityPubB64];
    if (ch == null) return;
    try {
      await _channelSend(ch, {
        'type': 'contacts_sync',
        'c': [for (final p in OnionPairedPeers.peers.value) p.toJson()],
        't': OnionPairedPeers.tombstones,
      });
    } catch (_) {}
  }

  Future<void> _handleContactsSync(Map<String, dynamic> obj) async {
    final me = _username;
    final myPub = OnionIdentity.publicKeyB64;
    final incoming = <OnionPeer>[];
    for (final c in (obj['c'] as List? ?? const [])) {
      try {
        final p = OnionPeer.fromJson(Map<String, dynamic>.from(c as Map));
        if (p.username == me ||
            p.identityPubB64 == myPub ||
            OnionAccount.ownDevice(p.identityPubB64) != null) {
          continue;
        }
        incoming.add(p);
      } catch (_) {}
    }
    final tombs = <String, int>{};
    final t = obj['t'];
    if (t is Map) {
      t.forEach((k, v) {
        if (k is String && v is num) tombs[k] = v.toInt();
      });
    }
    final added = await OnionPairedPeers.mergeSynced(incoming, tombs);
    for (final p in added) {
      // Accepted on our other device: no request left to answer here.
      await OnionRequests.take(p.identityPubB64);
      await OnionRequests.clearOutgoing(p.identityPubB64);
      _log('contact @${p.username} (${p.onionAddress}) synced from own device');
      _maybeDial(p, force: true);
    }
  }

  static bool _isMediaPointerText(String text) =>
      text.startsWith('IMAGEv1:') ||
      text.startsWith('VOICEv1:') ||
      text.startsWith('VIDEOv1:') ||
      text.startsWith('FILEv1:') ||
      text.startsWith('AUDIOv1:') ||
      text.startsWith('ALBUMv1:');

  /// Hands a message we just sent to [to] to our other devices, so the chat
  /// looks the same everywhere. Text only for now: a media pointer refers to
  /// a file that exists only on this device.
  Future<void> _copyToOwnDevices(String to, String text, String mid) async {
    if (_isMediaPointerText(text)) return;
    // An own event ('out'), so it also goes over WardLink when there's no
    // Tor between our devices.
    await _queueOwnEvent({
      'k': 'out',
      'id': 'out:$mid',
      'to': to,
      'text': text,
      'mid': mid,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, peerUsername: to);
  }

  Map<String, dynamic> _sentCopyPayload(
          String to, String text, String mid, DateTime at) =>
      {
        'type': 'sent_copy',
        'to': to,
        'text': text,
        'mid': mid,
        'at': at.millisecondsSinceEpoch,
      };

  Future<bool> _sendOwnAcked(
      OnionPeer own, Map<String, dynamic> payload, String mid) async {
    final ch = _channels[own.identityPubB64];
    if (ch == null) {
      _maybeDial(own);
      return false;
    }
    return _sendAckedOverChannel(ch, payload, mid);
  }

  // ─────────────────────────── own-device events ────────────────────────────
  //
  // "The account is online if any of its devices is": our devices help each
  // other in both directions.
  //   'in'       a contact's message we received -> every other device of
  //              ours, so a contact only has to reach one of them
  //   'in_del'   that contact deleted it (for everyone)
  //   'relay'    we can't reach the contact (no Tor here, or no channel to
  //              them): another device of ours sends it on our behalf, with
  //              the same mid -- the receiver drops duplicates by mid
  //   'relay_ok' ...and tells us once it's delivered (our tick)
  //   'del_out'  we deleted a message we sent: drop the copy, cancel a
  //              relay still waiting, and tell the contact if relayed
  // Events are queued per own device (OnionSendQueue kind 'own', persisted)
  // and go over our own Tor channel to that device, or -- when there is
  // none -- over WardLink on the LAN. Every event is idempotent.

  /// Contact messages already seen here ('from|mid'), so one that arrives
  /// both directly and forwarded -- or after we deleted it -- isn't shown
  /// (again).
  final LinkedHashSet<String> _seenIncoming = LinkedHashSet<String>();
  static const int _seenIncomingMax = 3000;
  Timer? _seenIncomingSave;

  static String _seenIncomingKey(String me) => 'onion_seen_in_v1_$me';

  Future<void> _loadSeenIncoming(String me) async {
    _seenIncoming.clear();
    final prefs = await SharedPreferences.getInstance();
    _seenIncoming.addAll(prefs.getStringList(_seenIncomingKey(me)) ?? const []);
  }

  /// Records a contact message as seen; false if it already was.
  bool _markSeenIncoming(String from, String mid) {
    if (!_seenIncoming.add('$from|$mid')) return false;
    while (_seenIncoming.length > _seenIncomingMax) {
      _seenIncoming.remove(_seenIncoming.first);
    }
    final me = _username;
    _seenIncomingSave?.cancel();
    if (me != null) {
      _seenIncomingSave = Timer(const Duration(seconds: 2), () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
            _seenIncomingKey(me), _seenIncoming.toList());
      });
    }
    return true;
  }

  /// Queues [event] (with a unique 'id') for each of our other devices --
  /// or only [target] -- and tries to deliver it right away.
  Future<void> _queueOwnEvent(Map<String, dynamic> event,
      {String? target, String peerUsername = ''}) async {
    final targets = target != null
        ? [target]
        : [for (final d in OnionAccount.otherDevices.value) d.pub];
    if (targets.isEmpty) return;
    final id = event['id'] as String;
    final json = jsonEncode(event);
    for (final pub in targets) {
      if (OnionSendQueue.items.value
          .any((i) => i.kind == 'own' && i.targetPub == pub && i.localId == id)) {
        continue;
      }
      await OnionSendQueue.add(QueuedOnionSend(
        id: '${DateTime.now().microsecondsSinceEpoch}_own_${pub.hashCode}',
        peerUsername: peerUsername,
        targetPub: pub,
        kind: 'own',
        text: json,
        localId: id,
        enqueuedAt: DateTime.now(),
      ));
    }
    _kickQueue();
  }

  void _kickQueue() {
    if (_retrying) {
      _flushAgain = true;
    } else {
      unawaited(_processQueue());
    }
  }

  /// One delivery attempt of a queued own event: our Tor channel to that
  /// device, else WardLink. True once that device took it.
  Future<bool> _deliverOwnItem(QueuedOnionSend item) async {
    final pub = item.targetPub;
    final id = item.localId;
    if (pub == null || id == null) return true; // malformed: drop it
    Map<String, dynamic> event;
    try {
      event = jsonDecode(item.text ?? '') as Map<String, dynamic>;
    } catch (_) {
      return true;
    }
    final ch = _channels[pub];
    if (ch != null) {
      return _sendAckedOverChannel(
          ch, {'type': 'own', 'e': event, 'mid': id}, id);
    }
    final own = OnionAccount.ownPeer(pub);
    if (own != null) _maybeDial(own);
    if (!WardLinkSyncService.instance.hasReachablePeer) return false;
    final took = await WardLinkSyncService.instance.sendOnionOwnEvent(event);
    if (took.isNotEmpty) {
      _log('own event ${event['k']} handed over via WardLink');
    }
    // Whoever took it over the LAN has it now -- not only [pub].
    if (took.length > 1 || (took.isNotEmpty && took.first != pub)) {
      await OnionSendQueue.removeWhere((i) =>
          i.kind == 'own' && i.localId == id && took.contains(i.targetPub));
    }
    return took.contains(pub);
  }

  /// WardLink delivered an event from another of our devices.
  Future<String?> _onOwnEventViaWardLink(Map<String, dynamic> e) async {
    final me = _username;
    final myPub = OnionAccountKey.publicKeyB64OrNull;
    if (me == null || myPub == null) return null;
    await _handleOwnEvent(e);
    return myPub;
  }

  /// Handles an event from another of our own devices (Tor or WardLink).
  Future<void> _handleOwnEvent(Map<String, dynamic> e) async {
    final k = e['k'] as String?;
    switch (k) {
      case 'req':
        final rj = e['r'];
        if (rj is! Map) return;
        OnionContactRequest req;
        try {
          req = OnionContactRequest.fromJson(Map<String, dynamic>.from(rj));
        } catch (_) {
          return;
        }
        if (OnionPairedPeers.byPub(req.pub) != null ||
            OnionRequests.isBlocked(req.pub)) {
          return;
        }
        // A request we (or one of our own devices) sent must never show up
        // as an incoming one on ourselves, whichever path it came back by.
        if (req.pub == OnionAccountKey.publicKeyB64OrNull ||
            OnionAccount.ownDevice(req.pub) != null) {
          _log('ignoring contact request from our own key/device');
          return;
        }
        final existing = OnionRequests.byPub(req.pub);
        if (existing != null && !existing.receivedAt.isBefore(req.receivedAt)) {
          return;
        }
        await OnionRequests.upsert(req);
        _log('contact request from @${req.username} synced from own device');
        onContactRequest?.call(req);
      case 'req_done':
        final pub = e['pub'] as String?;
        final how = e['how'] as String?;
        if (pub == null || how == null) return;
        if (how == 'accept') {
          await OnionRequests.take(pub);
          final pj = e['peer'];
          if (pj is Map) {
            try {
              final peer = OnionPeer.fromJson(Map<String, dynamic>.from(pj));
              final added = await OnionPairedPeers.mergeSynced([peer], const {});
              for (final p in added) {
                onContactAdded?.call(p.username, true);
                _maybeDial(p, force: true);
              }
            } catch (_) {}
          }
        } else {
          await OnionRequests.decline(pub, block: how == 'block');
        }
      case 'out':
        final to = e['to'] as String?;
        final text = e['text'] as String?;
        final mid = e['mid'] as String?;
        if (to == null || text == null || mid == null) return;
        if (_cancelledMids.contains(mid)) return;
        final at = (e['at'] as num?)?.toInt();
        onSentCopy?.call(
          to: to,
          text: text,
          mid: mid,
          at: at == null
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(at),
        );
      case 'in':
        final from = e['from'] as String?;
        final text = e['text'] as String?;
        final mid = e['mid'] as String?;
        if (from == null || text == null || mid == null) return;
        if (!_markSeenIncoming(from, mid)) return;
        _log('msg from $from (mid=$mid) forwarded by own device');
        onMessage?.call(from: from, decrypted: text, mid: mid);
      case 'in_del':
        final from = e['from'] as String?;
        final mid = e['mid'] as String?;
        if (from == null || mid == null) return;
        _markSeenIncoming(from, mid); // never show it if it comes later
        onDeleteMessage?.call(from: from, mid: mid);
      case 'relay':
        final to = e['to'] as String?;
        final text = e['text'] as String?;
        final mid = e['mid'] as String?;
        final origin = e['o'] as String?;
        if (to == null || text == null || mid == null || origin == null) {
          return;
        }
        final at = (e['at'] as num?)?.toInt();
        // Ours too: it shows in the chat here like any message we sent.
        onSentCopy?.call(
          to: to,
          text: text,
          mid: mid,
          at: at == null
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(at),
        );
        if (_cancelledMids.contains(mid)) return;
        if (!OnionPairedPeers.isTrusted(to)) {
          _log('relay to $to: not a contact on this device (yet)');
          return;
        }
        // Already taken on (redelivered event)? The queue has it.
        if (OnionSendQueue.items.value
            .any((i) => i.kind == 'text' && i.localId == mid)) {
          return;
        }
        _log('relaying msg to $to for own device (mid=$mid)');
        unawaited(() async {
          final ok =
              await sendMessage(to, text, localId: mid, relayFor: origin);
          if (ok) await _sendRelayOk(origin, to, mid);
        }());
      case 'relay_ok':
        final to = e['to'] as String?;
        final mid = e['mid'] as String?;
        if (to == null || mid == null) return;
        _log('msg to $to (mid=$mid) delivered by own device');
        // Delivered: our own retries (and relay requests to our other
        // devices) for it are done.
        await OnionSendQueue.removeWhere((i) =>
            (i.kind == 'text' && i.localId == mid && i.peerUsername == to) ||
            (i.kind == 'own' && i.localId == 'relay:$mid'));
        onDeliveryUpdate?.call(to, mid);
      case 'del_out':
        final to = e['to'] as String?;
        final mid = e['mid'] as String?;
        if (to == null || mid == null) return;
        final relayed = OnionSendQueue.items.value
                .any((i) => i.kind == 'text' && i.localId == mid) ||
            _relayedMids.contains(mid);
        _cancelledMids.add(mid);
        await OnionSendQueue.removeWhere(
            (i) => i.localId == mid && i.peerUsername == to);
        onDeleteCopy?.call(to: to, mid: mid);
        // We may have delivered it for them: take it back on their behalf.
        if (relayed && OnionPairedPeers.isTrusted(to)) {
          unawaited(_sendDeleteToContact(to, mid));
        }
    }
  }

  /// Mids we sent to a contact on behalf of another own device.
  final Set<String> _relayedMids = {};

  Future<void> _sendRelayOk(String origin, String to, String mid) =>
      _queueOwnEvent({
        'k': 'relay_ok',
        'id': 'relay_ok:$mid',
        'to': to,
        'mid': mid,
      }, target: origin, peerUsername: to);

  /// Our message couldn't reach [to] from here: ask our other devices.
  Future<void> _requestRelay(String to, String text, String mid) async {
    final me = OnionAccountKey.publicKeyB64OrNull;
    if (me == null || OnionAccount.otherDevices.value.isEmpty) return;
    _log('msg to $to (mid=$mid): asking own devices to relay');
    await _queueOwnEvent({
      'k': 'relay',
      'id': 'relay:$mid',
      'to': to,
      'text': text,
      'mid': mid,
      'o': me,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, peerUsername: to);
  }

  // ─────────────────────────── send ─────────────────────────────────────────

  /// Sends [text] to every device [peerUsername] has paired -- onion
  /// identity is per-device, so a contact running Onyx on two machines has
  /// two independent [OnionPeer] entries under the same username, and both
  /// need their own copy for the message to actually reach them wherever
  /// they're active (see [OnionPairedPeers.allByUsername]'s doc comment;
  /// this used to dial only the single most-recently-paired device, which
  /// is why an earlier-paired device could go quiet after a second device
  /// was paired later). Returns true if it reached at least one device
  /// *right now*. Any device it didn't reach gets its own retry entry in
  /// [OnionSendQueue] (if [localId] was given, so the UI can react once it
  /// lands), retried in the background every 20s while onion mode stays
  /// running -- see that file's doc comment for what this is (a local
  /// retry queue) and isn't (a real offline mailbox: if a device's app
  /// stays closed, this queue alone will never reach it).
  ///
  /// [relayFor]: we're sending this for another of our own devices (by its
  /// onion device pub) that couldn't reach them -- no copies, no relaying
  /// on, and a queued retry reports back to it once delivered.
  Future<bool> sendMessage(String peerUsername, String text,
      {String? localId, String? relayFor}) async {
    final devices = OnionPairedPeers.allByUsername(peerUsername);
    if (devices.isEmpty) {
      _log('sendMessage to $peerUsername: not a paired onion peer, dropping');
      return false;
    }
    // Our other devices get a copy, in parallel with the delivery below
    // (which waits for each device's ack).
    if (localId != null && relayFor == null) {
      unawaited(_copyToOwnDevices(peerUsername, text, localId));
    }
    if (localId != null && relayFor != null) _relayedMids.add(localId);
    var anyOk = false;
    for (final device in devices) {
      // Removed us: no send, no retry queue (it would never be accepted).
      if (OnionRequests.isRemovedBy(device.identityPubB64)) continue;
      // localId (our own message id) doubles as the cross-device reference
      // a later "delete for everyone" notice targets -- see
      // ChatMessage.onionMid's doc comment. Retries of this same message
      // reuse the same localId, so the mid stays stable across attempts.
      final ok = await _sendTextToDevice(device, text,
          mid: localId, dialNow: true);
      if (ok) {
        anyOk = true;
      } else if (localId != null && !_cancelledMids.contains(localId)) {
        await OnionSendQueue.add(QueuedOnionSend(
          id: '${DateTime.now().microsecondsSinceEpoch}_${localId}_'
              '${device.identityPubB64.hashCode}',
          peerUsername: peerUsername,
          targetPub: device.identityPubB64,
          kind: 'text',
          text: text,
          localId: localId,
          relayFor: relayFor,
          enqueuedAt: DateTime.now(),
        ));
        _log('sendMessage to $peerUsername (${device.onionAddress}): queued '
            'for retry (localId=$localId)');
        if (relayFor == null) onPeerOffline?.call(peerUsername);
      }
    }
    // Nothing got through from here (no Tor on this device, or no channel
    // to any of theirs): another device of ours may well be able to.
    if (!anyOk &&
        relayFor == null &&
        localId != null &&
        !_cancelledMids.contains(localId)) {
      await _requestRelay(peerUsername, text, localId);
    }
    return anyOk;
  }

  /// One delivery attempt of a chat message to one device: over its open
  /// channel (true only once the peer acks it), the old dial path for a
  /// legacy peer, or -- with no channel yet -- false right away, so it gets
  /// queued and goes out as soon as the channel opens. [dialNow] skips the
  /// connector's backoff, for a message the user just hit send on.
  Future<bool> _sendTextToDevice(OnionPeer device, String text,
      {String? mid, bool dialNow = false}) async {
    if (mid != null && _cancelledMids.contains(mid)) return false;
    // We're not in their contacts: they'd throw it away.
    if (OnionRequests.isRemovedBy(device.identityPubB64)) return false;
    final ch = _channels[device.identityPubB64];
    if (ch != null) return _sendMsgOverChannel(ch, text, mid);
    if (_legacyPubs.contains(device.identityPubB64)) {
      return _attemptSendMessageToDevice(device, text, mid: mid);
    }
    _maybeDial(device, force: dialNow);
    return false;
  }

  Future<bool> _sendMsgOverChannel(
          _PeerChannel ch, String text, String? mid) async =>
      _sendAckedOverChannel(
          ch,
          {
            'type': 'msg',
            'text': text,
            'name': await _getDisplayName(),
            if (mid != null) 'mid': mid,
          },
          mid);

  /// Writes [payload] on [ch] and, with a [mid], waits for the peer's 'ack'
  /// of it.
  Future<bool> _sendAckedOverChannel(
      _PeerChannel ch, Map<String, dynamic> payload, String? mid) async {
    final key = mid == null ? null : '${ch.pub}|$mid';
    final pending = mid == null ? null : _PendingAck(ch);
    if (key != null) _pendingAcks[key] = pending!;
    try {
      try {
        await _channelSend(ch, payload);
      } catch (e) {
        _closeChannel(ch, reason: 'msg write failed: $e');
        return false;
      }
      if (pending == null) return true;
      final ok = await pending.completer.future
          .timeout(_ackTimeout, onTimeout: () => false);
      // A slow ack alone doesn't mean the channel is dead (the peer may be
      // busy with a big incoming file) -- only drop it if it's also gone
      // silent. Either way the message is queued and resent; the receiver
      // drops duplicates by mid.
      if (!ok &&
          !ch.closed &&
          DateTime.now().difference(ch.lastRx) > _channelDeadAfter) {
        _closeChannel(ch,
            reason: 'no ack within ${_ackTimeout.inSeconds}s and silent '
                '(mid=$mid)');
      }
      return ok;
    } finally {
      if (key != null && identical(_pendingAcks[key], pending)) {
        _pendingAcks.remove(key);
      }
    }
  }

  // ─────────────────────────── calls ────────────────────────────────────────
  //
  // Call signaling (offer/answer/candidates/hangup) and, in "don't reveal
  // IP" mode, the call's audio/video packets themselves both ride the
  // chat channel -- see lib/call/call_manager.dart and local_turn_server.dart.

  /// A call signal from a paired device: (their username, their device
  /// pubkey, the signal map).
  void Function(String from, String fromPub, Map<String, dynamic> signal)?
      onCallSignal;

  /// A relayed call packet from a paired device (see LocalTurnServer):
  /// (their device pubkey, from/to virtual addresses, payload).
  void Function(String fromPub, String from, String to, Uint8List data)?
      onCallMedia;

  /// Sends a call signal to [username] -- to one device ([toPub]) or, for
  /// a new call, to every one of their devices that is connected right
  /// now. Returns the pubkeys it went to (empty = nobody reachable).
  Future<List<String>> sendCallSignal(
      String username, Map<String, dynamic> signal,
      {String? toPub}) async {
    final sent = <String>[];
    for (final d in OnionPairedPeers.allByUsername(username)) {
      if (toPub != null && d.identityPubB64 != toPub) continue;
      final ch = _channels[d.identityPubB64];
      if (ch == null) continue;
      try {
        await _channelSend(ch, {'type': 'call_sig', 'p': signal});
        sent.add(d.identityPubB64);
      } catch (_) {}
    }
    return sent;
  }

  /// Sends one relayed call packet to device [toPub]. Fire-and-forget,
  /// UDP-like: dropped if there's no channel or it's backed up, so a slow
  /// moment can't turn into ever-growing delay.
  void sendCallMedia(String toPub, String from, String to, Uint8List data) {
    final ch = _channels[toPub];
    if (ch == null) return;
    final f = _packAddr(from), t = _packAddr(to);
    if (ch.rawCallMedia && f != null && t != null) {
      // Raw frame: [6-byte from][6-byte to][packet], no JSON, no AES-GCM.
      // Sealing every packet was pure overhead: the Tor stream is already
      // end-to-end encrypted to the peer's onion address, the stream was
      // authenticated by a sealed 'hello'/'call_lane', and the packet
      // itself is SRTP/DTLS whose fingerprints went over the sealed
      // signaling. It also cut each packet's size roughly in half (no
      // sender pubkey, header JSON, nonce or tag), i.e. fewer Tor cells.
      final out = Uint8List(12 + data.length)
        ..setRange(0, 6, f)
        ..setRange(6, 12, t)
        ..setRange(12, 12 + data.length, data);
      _sendCallFrameMultipath(ch, out);
      return;
    }
    // ~0.5s of audio. Anything older than that is useless by the time it
    // arrives and only pushes every later packet back too.
    if (ch.queued > 12) return;
    unawaited(() async {
      try {
        final inner = await _sealBinary(
            base64Decode(toPub), {'type': 'call_media', 'f': from, 't': to},
            data);
        if (ch.closed) return;
        await _writeFrame(ch.handle, 0, inner);
      } catch (_) {}
    }());
  }

  // ─────────────────────────── call paths ───────────────────────────────────
  //
  // A single Tor circuit is a terrible voice link: it's TCP over 6 relays,
  // so one slow or lossy relay stalls everything behind it for hundreds of
  // ms (audio drops out, then arrives in a burst). Circuits stall
  // independently of each other though. So during a call every audio
  // packet goes out on several circuits at once -- the chat channel plus
  // [_callLaneCount] extra streams, each on its own circuit -- and the
  // receiver takes whichever copy arrives first and drops the rest (see
  // [_isDuplicateCallPacket]). The latency you hear becomes roughly the
  // *fastest* circuit's at each moment instead of the slowest's. Audio is
  // small (~16 packets/s with ptime 60 + DTX), so the copies are cheap; a
  // big packet (video) still goes on one path only -- the least backed-up.
  //
  // Only the caller opens lanes (either dialing the peer, or asking it to
  // dial back -- same as file lanes, see _openDataStream), and keeps them
  // up for the whole call; both ends send on every lane.

  static const int _callLaneCount = 3;

  /// A path whose write queue is longer than this is stalled right now:
  /// skip it, the other paths carry the audio meanwhile.
  static const int _callPathMaxQueued = 4;

  /// Peers we're in a Tor call with right now (by device pub).
  final Set<String> _callActive = {};
  final Map<int, _CallLane> _callLaneByHandle = {};
  Timer? _callLaneTimer;

  List<_CallLane> _lanesOf(String pub) => [
        for (final l in _callLaneByHandle.values)
          if (l.pub == pub && !l.closed) l
      ];

  /// Called by the call layer once it knows which device it's talking to.
  /// [opener]: this side opens the extra circuits (the caller).
  void startCallPaths(String pub, {required bool opener}) {
    if (!_callActive.add(pub)) return;
    _dedup.clear();
    _callLaneTimer ??=
        Timer.periodic(const Duration(seconds: 2), (_) => _checkCallLanes());
    if (opener) {
      for (var i = 0; i < _callLaneCount; i++) {
        unawaited(_keepCallLane(pub, i));
      }
    }
  }

  void stopCallPaths(String pub) {
    _callActive.remove(pub);
    for (final l in _lanesOf(pub)) {
      _closeCallLane(l);
    }
    if (_callActive.isEmpty) {
      _callLaneTimer?.cancel();
      _callLaneTimer = null;
    }
  }

  /// Keeps lane [i] to [pub] open for as long as the call lasts, reopening
  /// it whenever it dies.
  Future<void> _keepCallLane(String pub, int i) async {
    var backoff = 1;
    while (_callActive.contains(pub) && isRunning) {
      final device = OnionPairedPeers.byPub(pub);
      if (device == null) return;
      final ch = _channels[pub];
      if (ch == null) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      if (!ch.callLanes) return; // older build: the channel alone it is
      final h = await _openDataStream(device, ch, i,
          isolation: 'onyx-call-$i');
      if (h == null) {
        await Future.delayed(Duration(seconds: backoff));
        backoff = min(backoff * 2, 8);
        continue;
      }
      if (!_callActive.contains(pub)) {
        await OnionIdentity.plugin.streamClose(h);
        return;
      }
      backoff = 1;
      final lane = _CallLane(h, pub);
      _callLaneByHandle[h] = lane;
      // Reverse-dialed streams already have a read loop (they arrived as
      // inbound); ones we dialed ourselves need one.
      if (!_reading.contains(h)) unawaited(_readLoop(h));
      try {
        await _sendSealedFrame(h, device.identityPub,
            {'type': 'call_lane', 'lane': i});
      } catch (_) {
        _closeCallLane(lane);
        continue;
      }
      _log('call lane $i to ${device.username} up (handle=$h)');
      await lane.done.future;
    }
  }

  /// The peer marked [handle] as one of its call lanes to us.
  void _onCallLane(int handle, String pub) {
    if (_channelByHandle.containsKey(handle)) return; // that's the channel
    if (_callLaneByHandle.containsKey(handle)) return;
    _callLaneByHandle[handle] = _CallLane(handle, pub);
  }

  void _closeCallLane(_CallLane l) {
    if (l.closed) return;
    l.closed = true;
    _callLaneByHandle.remove(l.handle);
    if (!l.done.isCompleted) l.done.complete();
    unawaited(OnionIdentity.plugin.streamClose(l.handle));
  }

  /// Every 2s: drops lanes that went quiet. During a call the peer sends
  /// on every lane (RTCP at least once a second even while silent), so a
  /// lane with nothing for 8s is a dead or hopelessly stuck circuit; the
  /// opener's keeper replaces it with a fresh one.
  void _checkCallLanes() {
    final now = DateTime.now();
    for (final l in List<_CallLane>.of(_callLaneByHandle.values)) {
      if (!_callActive.contains(l.pub)) {
        _closeCallLane(l);
      } else if (now.difference(l.lastRx) > const Duration(seconds: 8)) {
        _log('call lane handle=${l.handle} silent, replacing');
        _closeCallLane(l);
      }
    }
  }

  void _sendCallFrameMultipath(_PeerChannel ch, Uint8List frame) {
    final paths = <int>[];
    final queued = <int>[];
    if (ch.queued <= _callPathMaxQueued) {
      paths.add(ch.handle);
      queued.add(ch.queued);
    }
    for (final l in _lanesOf(ch.pub)) {
      if (l.queued <= _callPathMaxQueued) {
        paths.add(l.handle);
        queued.add(l.queued);
      }
    }
    if (paths.isEmpty) return; // everything stalled: drop, don't pile up
    if (frame.length > 400) {
      // Video-sized: one copy, on the least backed-up path.
      var best = 0;
      for (var k = 1; k < paths.length; k++) {
        if (queued[k] < queued[best]) best = k;
      }
      unawaited(_writeFrame(paths[best], 2, frame).catchError((_) {}));
      return;
    }
    for (final h in paths) {
      unawaited(_writeFrame(h, 2, frame).catchError((_) {}));
    }
  }

  /// Recently seen call packets (64-bit FNV-1a of the whole frame), so the
  /// copies arriving over the other paths are dropped. Nothing in a call
  /// repeats a packet byte for byte (RTP has sequence numbers, STUN random
  /// transaction ids, DTLS record numbers).
  final LinkedHashSet<int> _dedup = LinkedHashSet<int>();

  bool _isDuplicateCallPacket(Uint8List p) {
    var h = 0xcbf29ce484222325;
    for (var i = 0; i < p.length; i++) {
      h ^= p[i];
      h *= 0x100000001b3;
    }
    if (!_dedup.add(h)) return true;
    if (_dedup.length > 2048) _dedup.remove(_dedup.first);
    return false;
  }

  /// "a.b.c.d:port" -> 6 bytes, or null if it isn't a plain IPv4 address.
  static Uint8List? _packAddr(String addr) {
    final i = addr.lastIndexOf(':');
    if (i <= 0) return null;
    final port = int.tryParse(addr.substring(i + 1));
    final parts = addr.substring(0, i).split('.');
    if (port == null || port < 0 || port > 0xFFFF || parts.length != 4) {
      return null;
    }
    final out = Uint8List(6);
    for (var k = 0; k < 4; k++) {
      final b = int.tryParse(parts[k]);
      if (b == null || b < 0 || b > 255) return null;
      out[k] = b;
    }
    out[4] = port >> 8;
    out[5] = port & 0xFF;
    return out;
  }

  static String _unpackAddr(Uint8List b, int off) =>
      '${b[off]}.${b[off + 1]}.${b[off + 2]}.${b[off + 3]}:'
      '${(b[off + 4] << 8) | b[off + 5]}';

  /// Local message ids the user deleted before they were delivered. Checked
  /// by an attempt that's already mid-dial, so it doesn't write the frame
  /// once the dial finally connects.
  final Set<String> _cancelledMids = <String>{};

  /// Cancels delivery of a not-yet-delivered outgoing message the user just
  /// deleted: drops its queued text retry (by [localId]) and any queued
  /// media retry whose staged file the pointer [content] refers to
  /// (`onion://<filename>`), and stops an in-flight attempt from writing
  /// it. Anything already written to a device can't be recalled this way
  /// -- that's what [sendDeleteNotice] is for.
  Future<void> cancelPendingSend(
      String peerUsername, String localId, String content) async {
    _cancelledMids.add(localId);
    await OnionSendQueue.removeWhere((i) =>
        i.peerUsername == peerUsername &&
        (i.localId == localId ||
            // its copy / relay request to our other devices, not handed
            // over yet
            i.localId == 'out:$localId' ||
            i.localId == 'relay:$localId' ||
            (i.mediaFilename != null &&
                content.contains('onion://${i.mediaFilename}'))));
    _log('cancelPendingSend to $peerUsername (localId=$localId)');
  }

  /// One immediate delivery attempt to one specific device -- no queueing,
  /// used both by [sendMessage]'s first try (fanned out over every paired
  /// device) and by the retry loop for a queued item pinned to one device.
  /// [mid] (when given) is the sender's own local message id, echoed back
  /// verbatim by a later 'delete_msg' frame -- see
  /// ChatMessage.onionMid's doc comment.
  Future<bool> _attemptSendMessageToDevice(OnionPeer device, String text,
      {String? mid}) async {
    int? handle;
    try {
      handle = await _dialWithRetry(
        device.onionAddress,
        delays: const [Duration(seconds: 3), Duration(seconds: 6)],
      );
      if (handle == null) {
        _log('sendMessage to ${device.username}: could not dial '
            '${device.onionAddress}');
        return false;
      }
      // The dial alone can take several seconds -- the user may have
      // deleted this message meanwhile (see [cancelPendingSend]).
      if (mid != null && _cancelledMids.contains(mid)) {
        _log('sendMessage to ${device.username}: cancelled (mid=$mid)');
        return false;
      }
      await _sendSealedFrame(handle, device.identityPub, {
        'type': 'msg',
        'text': text,
        'name': await _getDisplayName(),
        if (mid != null) 'mid': mid,
      });
      _log('sendMessage to ${device.username} (${device.onionAddress}): '
          'wrote frame ok (does not confirm the peer actually '
          'decrypted/displayed it)');
      return true;
    } catch (e) {
      _log('sendMessage to ${device.username} (${device.onionAddress}) '
          'failed: $e');
      return false;
    } finally {
      if (handle != null) await OnionIdentity.plugin.streamClose(handle);
    }
  }

  static String _profileSentKey(String me, String pub) =>
      'profile_sent_${me}_${pub.hashCode}';

  /// Sends our profile (display name + avatar) to every paired device that
  /// hasn't received the current version. The sent-version stamp is kept per
  /// device, so unchanged profiles cost no Tor dials. Best effort.
  Future<void> syncProfileToPeers({bool force = false}) async {
    final me = _username;
    if (me == null || !isRunning) return;
    // Always worth sending: even a never-edited profile has a display name
    // (or at least the username) -- skipping it left new contacts showing
    // the "Onyx user" placeholder until our first message carried the name.
    final updatedAt = await ProfileStore.updatedAt(me);
    final prefs = await SharedPreferences.getInstance();
    // Our own other devices too: they take it as our profile if it's newer
    // than theirs (see the 'profile' handler).
    for (final device in _allDevices()) {
      final key = _profileSentKey(me, device.identityPubB64);
      final sent = prefs.getInt(key) ?? -1;
      if (!force && sent >= updatedAt && sent != -1) continue;
      // No channel yet -> skipped; this runs again when one opens.
      final ok = await _withStream(device, (handle) async {
        final profile = await ProfileStore.exportProfile(me);
        await _sendSealedFrame(handle, device.identityPub, {
          'type': 'profile',
          // No display name set: the name we go by is the one everything
          // else (msg frames, identify) already uses.
          'name': await _getDisplayName(),
          ...profile,
        });
      }, dialIfMissing: false);
      if (ok) {
        await prefs.setInt(key, updatedAt);
        _log('profile sent to ${device.username} (${device.onionAddress})');
      }
    }
  }

  /// Asks every device paired under [peerUsername] to delete the message
  /// they received with this [mid] (see ChatMessage.onionMid) -- Onyx's
  /// onion-mode "delete for everyone". Best-effort and not queued for
  /// retry like [sendMessage]/[sendMedia]: onion mode already has no
  /// offline mailbox for messages themselves, so a delete notice to a
  /// currently-unreachable device would just sit unactionable anyway; the
  /// caller still removes its own local copy regardless of whether this
  /// reaches anyone. Returns true if it reached at least one device.
  Future<bool> sendDeleteNotice(String peerUsername, String mid) async {
    // Our other devices drop their copy of it too -- and if one of them
    // delivered it for us (relay), it takes it back on our behalf.
    await _queueOwnEvent({
      'k': 'del_out',
      'id': 'del_out:$mid',
      'to': peerUsername,
      'mid': mid,
    }, peerUsername: peerUsername);
    return _sendDeleteToContact(peerUsername, mid);
  }

  Future<bool> _sendDeleteToContact(String peerUsername, String mid) async {
    final devices = OnionPairedPeers.allByUsername(peerUsername);
    var anyOk = false;
    for (final device in devices) {
      final ok = await _withStream(
          device,
          (handle) => _sendSealedFrame(handle, device.identityPub, {
                'type': 'delete_msg',
                'mid': mid,
              }),
          dialIfMissing: false);
      _log('sendDeleteNotice to ${device.username} '
          '(${device.onionAddress}): ${ok ? 'sent' : 'not connected'}');
      if (ok) anyOk = true;
    }
    return anyOk;
  }

  /// Largest media payload sendMedia will attempt. Everything here goes
  /// through one AES-GCM encrypt call and one Tor-proxied TCP write with no
  /// chunking/resume -- fine for photos and voice notes, but a multi-hundred-
  /// MB video would tie up the connection for a long time with no progress
  /// feedback and no way to resume after a drop. Video/large-file transfer
  /// needs real chunking, deliberately not built yet -- see onion-mode plan.
  static const int maxMediaBytes = 25 * 1024 * 1024;

  /// Sends a media file (image, voice note) to [peerUsername] directly over
  /// Tor, base64-embedded in one sealed JSON frame alongside its metadata --
  /// no server upload step exists in onion mode, so unlike the central-server
  /// path this carries the actual bytes, not just a URL pointing at them.
  /// [kind] is 'image' or 'voice'. [extra] is merged into the payload for
  /// type-specific fields (e.g. voice's 'duration', image's 'blur'/'ar').
  ///
  /// If the immediate attempt fails and [filePath] is given (the file the
  /// caller already staged locally -- see _sendFileOnion), this queues a
  /// retry that re-reads the bytes from that file each attempt rather than
  /// holding a second copy in memory/prefs. There is no UI element tied to
  /// a media send's own delivery -- the sender already sees their image/
  /// voice note immediately from the local file; the separate pointer text
  /// message (sent right after via the normal chat path) is what carries
  /// the user-visible delivery tick.
  Future<bool> sendMedia(
    String peerUsername, {
    required String kind,
    required String filename,
    required List<int> bytes,
    Map<String, dynamic> extra = const {},
    String? filePath,
  }) async {
    if (bytes.length > maxMediaBytes) {
      _log('sendMedia to $peerUsername: $filename is ${bytes.length} bytes, '
          'over the ${maxMediaBytes ~/ (1024 * 1024)}MB onion-mode limit');
      return false;
    }
    // Fanned out to every paired device for the same reason sendMessage()
    // is -- see its doc comment.
    final devices = OnionPairedPeers.allByUsername(peerUsername);
    if (devices.isEmpty) {
      _log('sendMedia to $peerUsername: not a paired onion peer, dropping');
      return false;
    }
    var anyOk = false;
    for (final device in devices) {
      final ok = await _attemptSendMediaBytesToDevice(device,
          kind: kind, filename: filename, bytes: bytes, extra: extra);
      if (ok) {
        anyOk = true;
      } else if (filePath != null) {
        await OnionSendQueue.add(QueuedOnionSend(
          id: '${DateTime.now().microsecondsSinceEpoch}_media_'
              '${device.identityPubB64.hashCode}',
          peerUsername: peerUsername,
          targetPub: device.identityPubB64,
          kind: 'media',
          mediaKind: kind,
          mediaFilePath: filePath,
          mediaFilename: filename,
          mediaExtra: extra,
          enqueuedAt: DateTime.now(),
        ));
        _log('sendMedia to $peerUsername (${device.onionAddress}): queued '
            'for retry ("$filename")');
      }
    }
    return anyOk;
  }

  Future<bool> _attemptSendMedia(QueuedOnionSend item) async {
    final path = item.mediaFilePath;
    if (path == null) return false;
    List<int> bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (e) {
      _log('retry media to ${item.peerUsername}: local file missing '
          '($path): $e');
      return false;
    }
    // A queued entry pinned to a specific device (the normal case, see
    // QueuedOnionSend.targetPub) must redial that exact device -- not
    // "whichever of the contact's devices happens to be first", which
    // could resend to one that already received it. A null targetPub only
    // happens for an item persisted by an older build before this field
    // existed; fall back to the old single-device lookup for those.
    final device = item.targetPub != null
        ? OnionPairedPeers.byPub(item.targetPub!)
        : OnionPairedPeers.byUsername(item.peerUsername);
    if (device == null) {
      _log('retry media to ${item.peerUsername}: device no longer paired');
      return false;
    }
    return _attemptSendMediaBytesToDevice(
      device,
      kind: item.mediaKind ?? 'image',
      filename: item.mediaFilename ?? 'file',
      bytes: bytes,
      extra: item.mediaExtra ?? const {},
    );
  }

  /// Largest file [sendMediaChunked] will attempt. Generous but not
  /// unbounded -- a multi-GB "file" is almost certainly a mistake, and this
  /// keeps a single runaway send from tying up a device indefinitely.
  static const int maxChunkedMediaBytes = 2 * 1024 * 1024 * 1024;

  /// Bytes per chunk frame, before base64 (which inflates it ~33% on the
  /// wire). Small enough that one chunk's failure/retry doesn't waste much,
  /// large enough that per-frame overhead (JSON, AES-GCM tag, dial-once-
  /// reuse-for-all-chunks below) stays negligible next to the payload.
  static const int chunkSize = 512 * 1024;

  /// Sends a video/document/archive/etc. of any size (up to
  /// [maxChunkedMediaBytes]) to [peerUsername] over Tor, split into
  /// [chunkSize] pieces sent as separate sealed frames over ONE dialed
  /// stream (kept open for the whole transfer, unlike every other send in
  /// this file which dials fresh per message) -- see [_readLoop]'s doc
  /// comment: a stream already happily carries many frames before closing,
  /// this is the first sender to actually keep one open on purpose instead
  /// of one-and-done. [onProgress] (0.0-1.0) is best-effort UI feedback for
  /// the live attempt only; a queued retry (see [sendMedia]'s doc comment
  /// for what the queue is/isn't) re-sends the whole file from scratch --
  /// there is no byteoffset-level resume, only whole-transfer retry.
  Future<bool> sendMediaChunked(
    String peerUsername, {
    required String kind,
    required String filename,
    required File file,
    Map<String, dynamic> extra = const {},
    void Function(double progress)? onProgress,
  }) async {
    final length = await file.length();
    if (length > maxChunkedMediaBytes) {
      _log('sendMediaChunked to $peerUsername: $filename is $length bytes, '
          'over the ${maxChunkedMediaBytes ~/ (1024 * 1024)}MB limit');
      return false;
    }
    final devices = OnionPairedPeers.allByUsername(peerUsername);
    if (devices.isEmpty) {
      _log('sendMediaChunked to $peerUsername: not a paired onion peer, '
          'dropping');
      return false;
    }
    var anyOk = false;
    for (final device in devices) {
      final transferId = '${DateTime.now().microsecondsSinceEpoch}_'
          '${device.identityPubB64.hashCode}';
      final ok = await _attemptSendMediaChunkedToDevice(
        device,
        transferId: transferId,
        kind: kind,
        filename: filename,
        file: file,
        length: length,
        extra: extra,
        onProgress: onProgress,
      );
      if (ok) {
        anyOk = true;
      } else {
        await OnionSendQueue.add(QueuedOnionSend(
          id: '${DateTime.now().microsecondsSinceEpoch}_mediachunked_'
              '${device.identityPubB64.hashCode}',
          peerUsername: peerUsername,
          targetPub: device.identityPubB64,
          kind: 'media_chunked',
          mediaKind: kind,
          mediaFilePath: file.path,
          mediaFilename: filename,
          mediaExtra: extra,
          transferId: transferId,
          enqueuedAt: DateTime.now(),
        ));
        _log('sendMediaChunked to $peerUsername (${device.onionAddress}): '
            'queued for retry ("$filename")');
        onPeerOffline?.call(peerUsername);
      }
    }
    return anyOk;
  }

  Future<bool> _attemptSendMediaChunked(QueuedOnionSend item) async {
    final path = item.mediaFilePath;
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists()) {
      _log('retry media_chunked to ${item.peerUsername}: local file '
          'missing ($path)');
      return false;
    }
    final device = item.targetPub != null
        ? OnionPairedPeers.byPub(item.targetPub!)
        : OnionPairedPeers.byUsername(item.peerUsername);
    if (device == null) {
      _log('retry media_chunked to ${item.peerUsername}: device no longer '
          'paired');
      return false;
    }
    return _attemptSendMediaChunkedToDevice(
      device,
      // Same id as the first attempt -> the receiver resumes it.
      transferId: item.transferId ?? item.id,
      kind: item.mediaKind ?? 'file',
      filename: item.mediaFilename ?? 'file',
      file: file,
      length: await file.length(),
      extra: item.mediaExtra ?? const {},
    );
  }

  /// Sends a file in rounds that survive broken streams. Onion circuits do
  /// die now and then, and over a long transfer on several of them at once
  /// one of them usually will -- which used to fail the whole file (and the
  /// retry started over from zero). Now each round pushes the missing
  /// chunks over up to [maxLanes] streams (a lane that dies is reopened),
  /// then asks the receiver over the chat channel which chunks it actually
  /// has ('media_query' -> 'media_have'), and the next round sends only
  /// the rest. A queued retry reuses [transferId], so if the receiver still
  /// holds the partial file it picks up where it left off.
  Future<bool> _attemptSendMediaChunkedToDevice(
    OnionPeer device, {
    required String transferId,
    required String kind,
    required String filename,
    required File file,
    required int length,
    Map<String, dynamic> extra = const {},
    void Function(double progress)? onProgress,
  }) async {
    final pub = device.identityPubB64;
    final name = await _getDisplayName();
    final totalChunks = length == 0 ? 1 : (length / chunkSize).ceil();
    final start = {
      'type': 'media_start',
      'transferId': transferId,
      'kind': kind,
      'filename': filename,
      'name': name,
      'totalSize': length,
      'totalChunks': totalChunks,
      'chunkSize': chunkSize,
      ...extra,
    };
    void log(String s) => _log('sendMediaChunked to ${device.username} '
        '("$filename", $length bytes): $s');

    if (_channels[pub] == null) {
      if (!_legacyPubs.contains(pub)) {
        // Not connected -- queued; goes out once the channel opens.
        _maybeDial(device, force: true);
        return false;
      }
      // Legacy peer: one dialed stream, base64 frames, all or nothing.
      final ok = await _withStream(device, (h) async {
        final pool = ListQueue<int>.of(List.generate(totalChunks, (i) => i));
        var sent = 0;
        await _pushLane(h, device, start, pool, file,
            binary: false, onChunk: (n) {
          sent += n;
          if (length > 0) onProgress?.call(sent / length);
        });
        if (pool.isNotEmpty) throw StateError('lane ended early');
      });
      log(ok ? 'sent (legacy)' : 'failed (legacy)');
      return ok;
    }

    var missing = List<int>.generate(totalChunks, (i) => i);
    // A retry of a transfer the receiver still half-has: skip what it has.
    final before = await _queryTransfer(device, transferId);
    if (before != null) {
      if (before.done) return true;
      missing = [
        for (final i in missing)
          if (!before.has(i)) i
      ];
      if (missing.length < totalChunks) {
        log('resuming, ${totalChunks - missing.length}/$totalChunks chunks '
            'already there');
      }
    }

    var noProgress = 0;
    for (var round = 0; round < 8; round++) {
      final have = totalChunks - missing.length;
      var sentThisRound = 0;
      final lanesUsed = await _pushRound(device, start, missing, file,
          onChunk: (n) {
        sentThisRound += n;
        if (length > 0) {
          final p = (have * chunkSize + sentThisRound) / length;
          onProgress?.call(p > 1 ? 1 : p);
        }
      });
      if (lanesUsed == 0) {
        log('no stream could be opened (round $round)');
        return false;
      }
      final status = await _queryTransfer(device, transferId);
      if (status == null) {
        log('receiver did not answer the status query (round $round)');
        return false;
      }
      if (status.done) {
        onProgress?.call(1);
        log('delivered in ${round + 1} round(s)');
        return true;
      }
      final next = [
        for (var i = 0; i < totalChunks; i++)
          if (!status.has(i)) i
      ];
      log('round $round: ${totalChunks - next.length}/$totalChunks chunks '
          'received, resending ${next.length}');
      if (next.length >= missing.length) {
        if (++noProgress >= 2) return false;
      } else {
        noProgress = 0;
      }
      missing = next;
    }
    return false;
  }

  /// Most parallel streams ("lanes") one file transfer uses.
  static const int maxLanes = 4;

  /// Like [_withStream], but for bulk data (files, photos): on a
  /// channel-capable peer it runs [fn] on up to [count] streams of their
  /// OWN, separate from the chat channel, each on its own Tor circuit (see
  /// torSocksConnect's isolation). Two wins:
  ///  - chat keeps flowing during an upload, since the channel isn't stuck
  ///    behind megabytes of file on the same stream;
  ///  - speed: one onion-service circuit is capped by its flow-control
  ///    window over a 6-hop round trip (~100-200 KB/s); N circuits in
  ///    parallel give roughly N times that.
  /// Falls back to the channel if no separate stream can be opened at all.
  /// [fn]'s `binary` is whether the peer understands binary frames (see
  /// [_sealBinary]) -- false only for legacy peers.
  Future<bool> _withDataStreams(OnionPeer device, int count,
      Future<void> Function(List<int> handles, bool binary) fn) async {
    final pub = device.identityPubB64;
    final ch = _channels[pub];
    if (ch == null) {
      // Legacy peer: old dial path. Not connected: nudge the connector;
      // the queued retry goes out once the channel opens.
      return _withStream(device, (h) => fn([h], false));
    }
    final opened = await Future.wait(
        List.generate(count, (lane) => _openDataStream(device, ch, lane)));
    final handles = opened.whereType<int>().toList();
    if (handles.isEmpty) {
      _log('no separate stream to ${device.username}, sending over the '
          'chat channel');
      return _withStream(device, (h) => fn([h], true));
    }
    if (handles.length < count) {
      _log('data streams to ${device.username}: ${handles.length}/$count '
          'opened');
    }
    try {
      await fn(handles, true);
      return true;
    } catch (e) {
      _log('data streams to ${device.username} failed: $e');
      return false;
    } finally {
      for (final h in handles) {
        await OnionIdentity.plugin.streamClose(h);
      }
    }
  }

  /// One round of [_attemptSendMediaChunkedToDevice]: pushes [indices]
  /// over up to [maxLanes] parallel streams, each on its own circuit. Every
  /// lane keeps taking the next index from a shared pool, so a faster
  /// circuit simply carries more; a lane whose stream dies is reopened (a
  /// few times) and carries on. Chunks lost with a dead stream are found by
  /// the status query afterwards. Returns how many streams were used (0 =
  /// none could be opened, not even the chat channel as a fallback).
  Future<int> _pushRound(OnionPeer device, Map<String, dynamic> start,
      List<int> indices, File file,
      {required void Function(int bytes) onChunk}) async {
    final pub = device.identityPubB64;
    final pool = ListQueue<int>.of(indices);
    final lanes = max(1,
        min(maxLanes, (indices.length * chunkSize / (2 * 1024 * 1024)).ceil()));
    var used = 0;

    Future<void> worker(int lane) async {
      var failures = 0;
      while (pool.isNotEmpty && failures < 3) {
        final ch = _channels[pub];
        if (ch == null) return;
        final h = await _openDataStream(device, ch, lane);
        if (h == null) {
          failures++;
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        used++;
        try {
          await _pushLane(h, device, start, pool, file,
              binary: true, onChunk: onChunk);
        } catch (e) {
          failures++;
          _log('file lane $lane to ${device.username} dropped: $e');
        } finally {
          await OnionIdentity.plugin.streamClose(h);
        }
      }
    }

    await Future.wait(List.generate(lanes, worker));
    if (used == 0 && pool.isNotEmpty) {
      // No separate stream at all: squeeze it through the chat channel.
      _log('no separate stream to ${device.username}, sending over the '
          'chat channel');
      final ok = await _withStream(
          device,
          (h) => _pushLane(h, device, start, pool, file,
              binary: true, onChunk: onChunk),
          dialIfMissing: false);
      if (ok) used = 1;
    }
    return used;
  }

  /// Writes chunks taken from [pool] to [handle] until the pool is empty,
  /// preceded by [start] (idempotent on the receiver, which may see it on
  /// several lanes). Pipelined: the next chunk is read and encrypted (in a
  /// background isolate) while the current one is being written. Throws if
  /// the stream fails.
  Future<void> _pushLane(int handle, OnionPeer device,
      Map<String, dynamic> start, ListQueue<int> pool, File file,
      {required bool binary, required void Function(int bytes) onChunk}) async {
    await _sendSealedFrame(handle, device.identityPub, start);
    final transferId = start['transferId'];
    final raf = await file.open();
    try {
      Future<(Uint8List, int)> prepare(int i) async {
        await raf.setPosition(i * chunkSize);
        final bytes = await raf.read(chunkSize);
        final header = {
          'type': 'media_chunk',
          'transferId': transferId,
          'index': i,
        };
        final inner = binary
            ? await _sealBinary(device.identityPub, header, bytes)
            : await _sealPlain(
                device.identityPub,
                Uint8List.fromList(utf8.encode(
                    jsonEncode({...header, 'data': base64Encode(bytes)}))));
        return (inner, bytes.length);
      }

      int? take() => pool.isEmpty ? null : pool.removeFirst();
      final first = take();
      if (first == null) return;
      var next = prepare(first);
      while (true) {
        final (inner, n) = await next;
        final j = take();
        if (j != null) next = prepare(j);
        try {
          await _writeFrame(handle, 0, inner);
        } catch (_) {
          if (j != null) next.ignore();
          rethrow;
        }
        onChunk(n);
        if (j == null) break;
      }
    } finally {
      await raf.close();
    }
  }

  /// Pending 'media_query's, by transferId.
  final Map<String, Completer<_TransferStatus?>> _pendingQueries = {};

  /// Asks [device] over the chat channel which chunks of [transferId] it
  /// has. The receiver answers once every stream of that transfer has been
  /// fully read, so chunks still in flight aren't counted as missing. Null
  /// if not connected or no answer.
  Future<_TransferStatus?> _queryTransfer(
      OnionPeer device, String transferId) async {
    final ch = _channels[device.identityPubB64];
    if (ch == null) return null;
    final c = Completer<_TransferStatus?>();
    _pendingQueries[transferId] = c;
    try {
      await _channelSend(
          ch, {'type': 'media_query', 'transferId': transferId});
      return await c.future
          .timeout(const Duration(seconds: 120), onTimeout: () => null);
    } catch (_) {
      return null;
    } finally {
      if (identical(_pendingQueries[transferId], c)) {
        _pendingQueries.remove(transferId);
      }
    }
  }

  /// Reverse-dial requests we're waiting on: token -> (peer pub, handle).
  final Map<String, (String, Completer<int?>)> _pendingDataStreams = {};

  /// Opens one extra stream ("lane" [lane]) to [device] for a transfer,
  /// on the circuit reserved for that lane. Whoever can reach whom: if we
  /// dialed the channel, their onion service is reachable and we dial
  /// again; if they dialed it, we ask them over the channel to dial us
  /// ('open_data') and use the stream they open. Each order falls back to
  /// the other. Null if neither works.
  Future<int?> _openDataStream(OnionPeer device, _PeerChannel ch, int lane,
      {String? isolation}) async {
    final call = isolation != null;
    Future<int?> direct() => _dialWithRetry(device.onionAddress,
        delays: const [], isolation: isolation ?? _laneIsolation(lane));
    Future<int?> reverse() async {
      if (ch.closed) return null;
      final rand = Random.secure();
      final token = List<int>.generate(16, (_) => rand.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final c = Completer<int?>();
      _pendingDataStreams[token] = (device.identityPubB64, c);
      try {
        await _channelSend(ch, {
          'type': 'open_data',
          'token': token,
          'lane': lane,
          if (call) 'call': true,
        });
        return await c.future.timeout(
            Duration(seconds: call ? 20 : 60),
            onTimeout: () => null);
      } catch (_) {
        return null;
      } finally {
        _pendingDataStreams.remove(token);
      }
    }

    if (ch.outbound) return await direct() ?? await reverse();
    return await reverse() ?? await direct();
  }

  /// SOCKS isolation token for a data lane -- one Tor circuit per lane,
  /// all distinct from the chat channel's circuit (dialed without one).
  /// Fixed per lane so the circuits get reused across transfers while
  /// they're still fresh, instead of paying circuit setup every time.
  static String _laneIsolation(int lane) => 'onyx-data-$lane';

  Future<bool> _attemptSendMediaBytesToDevice(
    OnionPeer device, {
    required String kind,
    required String filename,
    required List<int> bytes,
    Map<String, dynamic> extra = const {},
  }) async {
    final name = await _getDisplayName();
    final header = {
      'type': 'media',
      'kind': kind,
      'filename': filename,
      'name': name,
      ...extra,
    };
    Future<void> send(int handle, bool binary) async {
      if (binary) {
        await _writeFrame(handle, 0,
            await _sealBinary(device.identityPub, header, bytes));
      } else {
        await _sendSealedFrame(handle, device.identityPub,
            {...header, 'data': base64Encode(bytes)});
      }
    }

    // A small voice note is fine inline on the channel; anything bigger
    // (photos) gets its own stream so chat isn't stuck behind it.
    final ok = bytes.length > 256 * 1024
        ? await _withDataStreams(
            device, 1, (handles, binary) => send(handles.first, binary))
        : await _withStream(device,
            (h) => send(h, _channels.containsKey(device.identityPubB64)));
    _log('sendMedia to ${device.username} (${device.onionAddress}): '
        '${ok ? 'wrote $kind "$filename" (${bytes.length} bytes)' : 'not connected, will retry'}');
    return ok;
  }

  /// Tail of the write queue per stream handle. A channel is written from
  /// several places at once (pings, acks, messages, media), and a socket
  /// can't take a new write while a previous flush is still pending -- so
  /// every write to one handle waits for the one before it.
  final Map<int, Future<void>> _writeChains = {};

  Future<void> _writeFrame(int handle, int tag, List<int> payload) {
    final prev = _writeChains[handle] ?? Future<void>.value();
    final ch = _channelByHandle[handle];
    final lane = _callLaneByHandle[handle];
    if (ch != null) ch.queued++;
    if (lane != null) lane.queued++;
    final next = prev.then((_) => _writeFrameNow(handle, tag, payload));
    final settled = next.catchError((_) {}).whenComplete(() {
      if (ch != null) ch.queued--;
      if (lane != null) lane.queued--;
    });
    _writeChains[handle] = settled;
    settled.then((_) {
      if (identical(_writeChains[handle], settled)) {
        _writeChains.remove(handle);
      }
    });
    return next;
  }

  Future<void> _writeFrameNow(int handle, int tag, List<int> payload) async {
    final out = BytesBuilder()
      ..addByte(tag)
      ..add(_u32(payload.length))
      ..add(payload);
    final bytes = out.toBytes();
    final ch = _channelByHandle[handle];
    if (ch != null) ch.writing++;
    try {
      final written = await OnionIdentity.plugin.streamWrite(handle, bytes);
      if (written == null || written < bytes.length) {
        throw StateError(
            'onion stream write incomplete ($written/${bytes.length})');
      }
    } finally {
      if (ch != null) ch.writing--;
    }
  }

  /// Session key (and its raw bytes, for background-isolate crypto) per
  /// peer pubkey. X25519 + HKDF gives the same result every frame, and
  /// recomputing it in pure Dart for each of a big file's hundreds of chunks
  /// was pure waste. Cleared on [stop] (the key depends on our account).
  final Map<String, Future<(SecretKey, List<int>)>> _sessionKeys = {};

  Future<(SecretKey, List<int>)> _sessionKeyFor(List<int> peerPub) {
    final id = base64Encode(peerPub);
    // Frames from unknown pubkeys also land here; don't let them grow this
    // without bound.
    if (_sessionKeys.length > 256) _sessionKeys.clear();
    final cached = _sessionKeys[id];
    if (cached != null) return cached;
    final f = () async {
      final k = await OnionCrypto.deriveSessionKey(
          OnionAccountKey.keyPair, peerPub);
      return (k, await k.extractBytes());
    }();
    _sessionKeys[id] = f;
    f.catchError((_) {
      _sessionKeys.remove(id);
      return (SecretKey(const []), const <int>[]);
    });
    return f;
  }

  Future<void> _sendSealedFrame(
      int handle, List<int> peerPub, Map<String, dynamic> payload) async {
    final inner = await _sealPlain(
        peerPub, Uint8List.fromList(utf8.encode(jsonEncode(payload))));
    await _writeFrame(handle, 0, inner);
  }

  /// Seals a binary frame: a small JSON [header] plus raw [data], with no
  /// base64 -- used for file chunks, where base64-in-JSON meant 33% more
  /// bytes over Tor and a lot of string churn on the UI isolate. The
  /// plaintext starts with a 0x00 byte, which a JSON frame (always '{')
  /// never does, so the receiver can tell the two apart. Only sent to peers
  /// on a channel-capable build; legacy peers still get base64 frames.
  Future<Uint8List> _sealBinary(
      List<int> peerPub, Map<String, dynamic> header, List<int> data) {
    final h = utf8.encode(jsonEncode(header));
    final plain = BytesBuilder(copy: false)
      ..addByte(0)
      ..add(_u32(h.length))
      ..add(h)
      ..add(data);
    return _sealPlain(peerPub, plain.toBytes());
  }

  /// Encrypts [plain] for [peerPub] and wraps it as a tag-0 payload
  /// (`[4-byte pubLen][our pub][sealed]`), ready for [_writeFrame].
  Future<Uint8List> _sealPlain(List<int> peerPub, Uint8List plain) async {
    final (key, keyBytes) = await _sessionKeyFor(peerPub);
    // sealFrame() prepends its own 4-byte length header (it's designed to be
    // read straight off a byte stream). That header is redundant here --
    // _writeFrame() already length-prefixes this whole tag-0 payload -- and
    // the receive side's openFrame() call expects the sealed body *without*
    // it (per its own doc comment), so it must be dropped, not forwarded:
    // leaving it in shifts every following byte by 4, which desyncs the
    // nonce/ciphertext/MAC boundaries and makes AES-GCM authentication fail
    // on every single message.
    final sealed = Uint8List.sublistView(
        await OnionCrypto.sealFrameFast(plain, key, keyBytes), 4);
    final myPubBytes = utf8.encode(OnionIdentity.publicKeyB64);
    final inner = BytesBuilder(copy: false)
      ..add(_u32(myPubBytes.length))
      ..add(myPubBytes)
      ..add(sealed);
    return inner.toBytes();
  }

  /// [minimal]: for someone who isn't a contact yet -- no OS.
  /// [comment]: a contact request's comment (identify_request only).
  Future<void> _sendIdentifyFrame(int handle, String type, String myUsername,
      {bool minimal = false, String? comment}) async {
    final c = comment?.trim() ?? '';
    final payload = utf8.encode(jsonEncode({
      'type': type,
      'pub': OnionIdentity.publicKeyB64,
      'username': myUsername,
      'onionAddress': OnionIdentity.onionAddress,
      'name': await _getDisplayName(),
      if (!minimal) 'os': Platform.operatingSystem,
      // Our account's signed device list: whichever of our devices the
      // request ends up accepted on, the requester knows it's us (see
      // _peerFromRoster). The onyx: contact code shows these addresses
      // anyway.
      // The stripped roster: whoever dials us -- a stranger included -- gets
      // no device names or OS, only what's needed to reach our devices.
      if (type == 'identify_response' && _publicRosterWire != null)
        'r': _publicRosterWire,
      if (c.isNotEmpty)
        'comment': c.length > OnionRequests.maxMessageLength
            ? c.substring(0, OnionRequests.maxMessageLength)
            : c,
    }));
    await _writeFrame(handle, 1, payload);
  }

  // ─────────────────────────── receive ──────────────────────────────────────

  /// Handles that have a [_readLoop] running.
  final Set<int> _reading = {};

  Future<void> _readLoop(int handle) async {
    final assembler = _FrameAssembler();
    _reading.add(handle);
    try {
      while (true) {
        final result =
            await OnionIdentity.plugin.streamRead(handle, 1 << 20, 30000);
        if (result.n == 0) break; // peer closed the stream
        if (result.n == -3) continue; // read timed out, keep waiting
        if (result.n < 0) break; // hard error
        final data = result.data;
        if (data == null) continue;
        // Any bytes at all (even part of a big media frame) prove the
        // channel is alive.
        _channelByHandle[handle]?.lastRx = DateTime.now();
        _callLaneByHandle[handle]?.lastRx = DateTime.now();
        assembler.addChunk(data);
        _RawFrame? frame;
        while ((frame = assembler.tryTakeFrame()) != null) {
          await _handleFrame(handle, frame!);
        }
      }
    } catch (e) {
      _log('read loop for handle=$handle failed: $e');
    } finally {
      _reading.remove(handle);
      _laneOf.remove(handle);
      final lane = _callLaneByHandle[handle];
      if (lane != null) _closeCallLane(lane);
      final ch = _channelByHandle[handle];
      if (ch != null) {
        _closeChannel(ch, reason: 'stream closed by peer');
      } else {
        await OnionIdentity.plugin.streamClose(handle);
      }
    }
  }

  Future<void> _handleFrame(int handle, _RawFrame frame) async {
    if (frame.tag == 1) {
      Map<String, dynamic> obj;
      try {
        obj = jsonDecode(utf8.decode(frame.payload)) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
      if (obj['type'] == 'identify_request') {
        await _handleIdentifyRequest(handle, obj);
      }
      // identify_response is only ever expected as a direct reply read by
      // connectByAddress's own loop, never via this generic accept path --
      // if one somehow arrives here, there's nothing to do with it.
      return;
    }

    if (frame.tag == 2) {
      // Raw call media (see sendCallMedia). Only trusted on an open
      // channel or a call lane: what ties the stream to an authenticated
      // device (its sealed 'hello' / 'call_lane').
      final ch = _channelByHandle[handle];
      final String? pub = (ch != null && ch.open)
          ? ch.pub
          : _callLaneByHandle[handle]?.pub;
      final p = frame.payload;
      if (pub == null || p.length < 12) return;
      if (OnionPairedPeers.byPub(pub) == null || _isBlockedPub(pub)) return;
      // The same packet arrives once per path; the first copy wins.
      if (_isDuplicateCallPacket(p)) return;
      onCallMedia?.call(pub, _unpackAddr(p, 0), _unpackAddr(p, 6),
          Uint8List.sublistView(p, 12));
      return;
    }

    // tag == 0: sealed chat/pairing message.
    if (frame.payload.length < 4) return;
    final pubLen =
        ByteData.sublistView(frame.payload, 0, 4).getUint32(0, Endian.big);
    if (frame.payload.length < 4 + pubLen) return;
    final pubBytes = frame.payload.sublist(4, 4 + pubLen);
    final sealedBody = frame.payload.sublist(4 + pubLen);

    final String peerPubB64;
    try {
      peerPubB64 = utf8.decode(pubBytes);
    } catch (_) {
      return;
    }
    List<int> peerPub;
    try {
      peerPub = base64Decode(peerPubB64);
    } catch (_) {
      return;
    }

    Map<String, dynamic> obj;
    try {
      final (key, keyBytes) = await _sessionKeyFor(peerPub);
      final plain =
          await OnionCrypto.openFrameFast(sealedBody, key, keyBytes);
      if (plain.isNotEmpty && plain[0] == 0) {
        // Binary frame (see _sealBinary): [0x00][u32 hLen][header][data].
        final hLen = ByteData.sublistView(plain, 1, 5).getUint32(0, Endian.big);
        obj = jsonDecode(utf8.decode(Uint8List.sublistView(plain, 5, 5 + hLen)))
            as Map<String, dynamic>;
        obj['_bin'] = Uint8List.sublistView(plain, 5 + hLen);
      } else {
        obj = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      }
    } catch (e) {
      // Doesn't decrypt/parse -- not a message we can trust; drop it.
      _log('dropping unreadable frame from pub=$peerPubB64: $e');
      return;
    }

    final type = obj['type'] as String?;
    // Blocked: dropped whole (a QR pairing we showed the code for in person
    // still goes through -- that's us choosing them again).
    if (type != 'pair_request' && _isBlockedPub(peerPubB64)) return;
    if (type != 'pair_request') {
      final seen = OnionPairedPeers.byPub(peerPubB64);
      if (seen != null) _onPeerSeen(seen);
    }
    if (type == 'pair_request') {
      await _handlePairRequest(peerPubB64, obj);
    } else if (type == 'verify') {
      // Someone we sent a contact request to checks we really are at this
      // address with this key (see _proveAddress). Answering only proves
      // what they already know: the key behind the address they dialed.
      final nonce = obj['nonce'];
      if (nonce is! String || nonce.length > 64) return;
      unawaited(_sendSealedFrame(
              handle, peerPub, {'type': 'verify_ok', 'nonce': nonce})
          .catchError((_) {}));
    } else if (type == 'hello') {
      final own = OnionAccount.ownPeer(peerPubB64);
      if (own != null) {
        await _onHello(handle, own, obj);
        final r = await OnionAccount.verify(obj['r']);
        if (r != null && await OnionAccount.mergeOwn(r)) {
          await _onOwnRosterChanged();
        }
        return;
      }
      var peer = OnionPairedPeers.byPub(peerPubB64) ??
          await _acceptedByThem(peerPubB64) ??
          // A device of ours or of a contact that we only know through the
          // account roster it carries (e.g. it was just linked).
          await _peerFromRoster(peerPubB64, obj['r']);
      if (peer != null && OnionAccount.ownDevice(peerPubB64) != null) {
        await _onHello(handle, peer, obj);
        return;
      }
      if (peer == null) {
        final claimed = (obj['a'] as String?)?.trim().toLowerCase();
        if (claimed != null && OnionRequests.hasRequestTo(claimed)) {
          // Probably accepting a request of ours whose reply we missed:
          // checked off the read loop (it dials), no 'not_contact' meanwhile.
          unawaited(_acceptedByAddress(peerPubB64, peerPub, obj));
          return;
        }
        if (await _rosterOfKnownContact(obj['r'])) {
          // A contact's new device, before their account key is bound here:
          // not "not a contact" (that would stop it dialing us for minutes).
          // Their known device's hello binds the key and we dial this one.
          _log('hello from a new device of a contact, not bound yet: '
              'closing for now');
          final ch = _channelByHandle[handle];
          if (ch != null) {
            _closeChannel(ch, reason: 'account not bound yet');
          } else {
            unawaited(OnionIdentity.plugin.streamClose(handle));
          }
          return;
        }
        _log('hello from unknown key $peerPubB64 (no request of ours to it): '
            'not_contact');
        // Someone who still has us as a contact, but we don't have them (we
        // removed them / never accepted): say so, instead of staying silent
        // -- silence made them take us for an old build, show us online and
        // mark messages we then threw away as delivered. (Blocked keys never
        // get here: dropped above without a word.)
        unawaited(_sendSealedFrame(handle, peerPub, {'type': 'not_contact'})
            .catchError((_) {}));
        return;
      }
      await _onHello(handle, peer, obj);
      if (obj['r'] != null) {
        unawaited(_applyContactRoster(peer, obj['r']));
      }
    } else if (type == 'roster') {
      if (OnionAccount.ownDevice(peerPubB64) != null) {
        final r = await OnionAccount.verify(obj['r']);
        if (r != null && await OnionAccount.mergeOwn(r)) {
          await _onOwnRosterChanged();
        }
        return;
      }
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer != null) await _applyContactRoster(peer, obj['r']);
    } else if (type == 'own') {
      if (OnionAccount.ownDevice(peerPubB64) == null) return;
      final e = obj['e'];
      final mid = obj['mid'] as String?;
      if (e is! Map) return;
      await _handleOwnEvent(Map<String, dynamic>.from(e));
      final ch = _channelByHandle[handle];
      if (mid != null && ch != null && ch.pub == peerPubB64) {
        unawaited(_channelSend(ch, {'type': 'ack', 'mid': mid})
            .catchError((_) {}));
      }
    } else if (type == 'contacts_sync') {
      if (OnionAccount.ownDevice(peerPubB64) == null) return;
      await _handleContactsSync(obj);
    } else if (type == 'sent_copy') {
      if (OnionAccount.ownDevice(peerPubB64) == null) return;
      final to = obj['to'] as String?;
      final text = obj['text'] as String?;
      final mid = obj['mid'] as String?;
      if (to == null || text == null || mid == null) return;
      final at = (obj['at'] as num?)?.toInt();
      onSentCopy?.call(
        to: to,
        text: text,
        mid: mid,
        at: at == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(at),
      );
      final ch = _channelByHandle[handle];
      if (ch != null && ch.pub == peerPubB64) {
        unawaited(_channelSend(ch, {'type': 'ack', 'mid': mid})
            .catchError((_) {}));
      }
    } else if (type == 'delete_copy') {
      if (OnionAccount.ownDevice(peerPubB64) == null) return;
      final to = obj['to'] as String?;
      final mid = obj['mid'] as String?;
      if (to == null || mid == null) return;
      // Still queued for the contact here too? Then it's cancelled as well.
      _cancelledMids.add(mid);
      onDeleteCopy?.call(to: to, mid: mid);
    } else if (type == 'not_contact') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer != null) await _onRemovedBy(peer, handle);
    } else if (type == 'ping') {
      final ch = _channelByHandle[handle];
      if (ch != null && ch.pub == peerPubB64) {
        unawaited(_channelSend(ch, {'type': 'pong'}).catchError((_) {}));
      }
    } else if (type == 'pong') {
      // lastRx already bumped by the read loop.
    } else if (type == 'call_media') {
      final bin = obj['_bin'] as Uint8List?;
      final f = obj['f'] as String?, t = obj['t'] as String?;
      if (bin == null || f == null || t == null) return;
      if (OnionPairedPeers.byPub(peerPubB64) == null) return;
      onCallMedia?.call(peerPubB64, f, t, bin);
    } else if (type == 'call_lane') {
      if (OnionPairedPeers.byPub(peerPubB64) == null) return;
      _onCallLane(handle, peerPubB64);
    } else if (type == 'call_sig') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      final p = obj['p'];
      if (peer == null || p is! Map) return;
      onCallSignal?.call(
          peer.username, peerPubB64, Map<String, dynamic>.from(p));
    } else if (type == 'media_query') {
      final transferId = obj['transferId'] as String?;
      final ch = _channelByHandle[handle];
      if (transferId == null || ch == null || ch.pub != peerPubB64) return;
      unawaited(_answerMediaQuery(ch, transferId));
    } else if (type == 'media_have') {
      final transferId = obj['transferId'] as String?;
      final pending =
          transferId == null ? null : _pendingQueries[transferId];
      if (pending == null || pending.isCompleted) return;
      Uint8List bitmap;
      try {
        bitmap = base64Decode((obj['have'] as String?) ?? '');
      } catch (_) {
        bitmap = Uint8List(0);
      }
      pending.complete(_TransferStatus(obj['done'] == true, bitmap));
    } else if (type == 'open_data') {
      // The peer wants to send us a file but can't dial us: open a separate
      // stream to them and read the transfer off it (see _openDataStream).
      final peer = OnionPairedPeers.byPub(peerPubB64);
      final token = obj['token'] as String?;
      if (peer == null || token == null) return;
      final lane = ((obj['lane'] as num?)?.toInt() ?? 0).clamp(0, maxLanes);
      final call = obj['call'] == true;
      unawaited(() async {
        final h = await _dialWithRetry(peer.onionAddress,
            delays: const [Duration(seconds: 3)],
            isolation: call ? 'onyx-call-$lane' : _laneIsolation(lane));
        if (h == null) {
          _log('open_data from ${peer.username}: could not dial back');
          return;
        }
        try {
          await _sendSealedFrame(
              h, peer.identityPub, {'type': 'data_ready', 'token': token});
        } catch (_) {
          await OnionIdentity.plugin.streamClose(h);
          return;
        }
        await _readLoop(h);
      }());
    } else if (type == 'data_ready') {
      final token = obj['token'] as String?;
      final pending = token == null ? null : _pendingDataStreams[token];
      if (pending == null ||
          pending.$1 != peerPubB64 ||
          pending.$2.isCompleted) {
        // Too late or not ours -- nobody will write to it.
        unawaited(OnionIdentity.plugin.streamClose(handle));
        return;
      }
      pending.$2.complete(handle);
    } else if (type == 'ack') {
      final mid = obj['mid'] as String?;
      if (mid == null) return;
      final pending = _pendingAcks['$peerPubB64|$mid'];
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.complete(true);
      }
    } else if (type == 'presence') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer == null) return;
      _applyPresence(peer, obj['visible'] != false,
          (obj['text'] as String?)?.trim() ?? '');
    } else if (type == 'msg') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer == null) {
        // Not a contact (a pending request included): chat messages aren't
        // accepted -- a request carries a comment instead.
        _log('dropping msg from non-contact pub=$peerPubB64');
        return;
      }
      await _refreshPeerNameIfChanged(peer, obj);
      final text = obj['text'] as String?;
      if (text == null) return;
      final mid = obj['mid'] as String?;
      // Already here (forwarded by our other device first, or deleted since)
      // -> not shown again, but still acked below.
      final fresh = mid == null || _markSeenIncoming(peer.username, mid);
      if (fresh) {
        _log('msg from ${peer.username} decrypted ok, delivering to UI');
        onMessage?.call(from: peer.username, decrypted: text, mid: mid);
        // Our other devices get it too, in case it can't reach them itself.
        // Media pointers stay here: the file only exists on this device.
        if (mid != null && !_isMediaPointerText(text)) {
          unawaited(_queueOwnEvent({
            'k': 'in',
            'id': 'in:${peer.username}:$mid',
            'from': peer.username,
            'text': text,
            'mid': mid,
          }, peerUsername: peer.username));
        }
      }
      // Confirm receipt so the sender's tick means "arrived", not just
      // "written". Channels only -- a one-shot legacy stream is already
      // closed by its sender, which never waits for an ack. Not awaited:
      // the read loop must keep reading.
      final ch = _channelByHandle[handle];
      if (mid != null && ch != null && ch.pub == peerPubB64) {
        unawaited(_channelSend(ch, {'type': 'ack', 'mid': mid})
            .catchError((_) {}));
      }
    } else if (type == 'profile') {
      final me = _username;
      if (me != null && OnionAccount.ownDevice(peerPubB64) != null) {
        // Our own profile, edited on another of our devices: newest wins.
        if (await ProfileStore.applyOwnProfile(me, obj)) {
          avatarVersion.value++;
          _log('own profile updated from another device');
        }
        return;
      }
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer == null) {
        _log('dropping profile from unpaired pub=$peerPubB64');
        return;
      }
      // A contact with several devices sends from each: an older copy
      // arriving after a newer one must not win.
      final remoteAt = (obj['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteAt > 0) {
        if (remoteAt < await ProfileStore.updatedAt(peer.username)) return;
        await ProfileStore.setUpdatedAt(peer.username, remoteAt);
      }
      await _refreshPeerNameIfChanged(peer, obj);
      try {
        final avatarB64 = obj['avatar'] as String?;
        if (avatarB64 != null && avatarB64.isNotEmpty) {
          final bytes = base64Decode(avatarB64);
          if (bytes.length <= 4 * 1024 * 1024) {
            await ProfileStore.writeAvatar(peer.username, bytes);
          }
        } else if (((obj['updatedAt'] as num?)?.toInt() ?? 0) > 0) {
          await ProfileStore.deleteAvatar(peer.username);
        }
        avatarVersion.value++;
        _log('profile from ${peer.username} applied');
      } catch (e) {
        _log('profile from ${peer.username} failed: $e');
      }
    } else if (type == 'delete_msg') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer == null) {
        _log('dropping delete_msg from unpaired pub=$peerPubB64');
        return;
      }
      final mid = obj['mid'] as String?;
      if (mid == null) return;
      _log('delete_msg from ${peer.username} for mid=$mid');
      // Never shown later either (e.g. forwarded by our other device).
      _markSeenIncoming(peer.username, mid);
      onDeleteMessage?.call(from: peer.username, mid: mid);
      if (peer.username != _username) {
        unawaited(_queueOwnEvent({
          'k': 'in_del',
          'id': 'in_del:${peer.username}:$mid',
          'from': peer.username,
          'mid': mid,
        }, peerUsername: peer.username));
      }
    } else if (type == 'media') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer == null) {
        _log('dropping media from unpaired pub=$peerPubB64');
        return;
      }
      await _refreshPeerNameIfChanged(peer, obj);
      final kind = obj['kind'] as String?;
      final filename = obj['filename'] as String?;
      final bin = obj['_bin'] as Uint8List?; // binary frame (new peers)
      final dataB64 = obj['data'] as String?; // base64 (legacy peers)
      if (kind == null || filename == null) return;
      if (!isSafeOnionMediaFilename(filename)) {
        _log('dropping media from ${peer.username}: unsafe filename');
        return;
      }
      if (bin == null && dataB64 == null) return;
      List<int> bytes;
      try {
        bytes = bin ?? base64Decode(dataB64!);
      } catch (_) {
        return;
      }
      // Saved under the SAME filename the sender used -- it's already unique
      // (see _sendFileOnion's `uniqueBasename`, timestamp-prefixed before
      // this ever reaches the wire), and it must match exactly: the sender
      // separately sends a plaintext `msg` pointer (IMAGEv1/VOICEv1) whose
      // `onion://<filename>` URL is built from that same name. Renaming the
      // file here (as an earlier version of this code did, generating a
      // fresh timestamped "wire filename") desynced the two -- the pointer
      // kept referencing the sender's original name, which never existed on
      // this device, so it rendered as a broken/missing image. This handler
      // only persists the bytes to disk; the actual chat bubble is created
      // once from the pointer message above (type == 'msg'), not from here,
      // so the two don't race to add duplicate messages either.
      try {
        final docs = await getOnyxDocumentsDirectory();
        final mediaDir = Directory('${docs.path}/onion_media');
        await mediaDir.create(recursive: true);
        await File('${mediaDir.path}/$filename')
            .writeAsBytes(bytes, flush: true);
      } catch (e) {
        _log('media from ${peer.username}: failed to save $filename: $e');
        return;
      }
      _log('media from ${peer.username}: saved $kind "$filename" '
          '(${bytes.length} bytes)');
      if (kind != 'image' && kind != 'voice') {
        _log('media from ${peer.username}: unknown kind "$kind"');
      }
    } else if (type == 'media_start') {
      final peer = OnionPairedPeers.byPub(peerPubB64);
      if (peer == null) {
        _log('dropping media_start from unpaired pub=$peerPubB64');
        return;
      }
      await _refreshPeerNameIfChanged(peer, obj);
      final transferId = obj['transferId'] as String?;
      final kind = obj['kind'] as String?;
      final filename = obj['filename'] as String?;
      final totalChunks = (obj['totalChunks'] as num?)?.toInt();
      // Older senders don't send it; they always used 512 KB.
      final chunkSize = (obj['chunkSize'] as num?)?.toInt() ?? 512 * 1024;
      if (transferId == null ||
          kind == null ||
          filename == null ||
          totalChunks == null ||
          totalChunks < 1 ||
          chunkSize < 1 ||
          chunkSize > 16 * 1024 * 1024) {
        return;
      }
      if (!isSafeOnionMediaFilename(filename)) {
        _log('dropping media_start from ${peer.username}: unsafe filename');
        return;
      }
      // Remember which transfer this stream carries, so a status query can
      // wait until it's been read to the end (see _answerMediaQuery).
      if (!_channelByHandle.containsKey(handle)) _laneOf[handle] = transferId;
      // A multi-lane transfer announces itself on every lane; only the first
      // one creates it. Later lanes wait for that to finish, so their chunks
      // (which follow on the same stream) find the transfer ready.
      if (_incomingTransfers.containsKey(transferId) ||
          _completedTransfers.contains(transferId)) {
        return;
      }
      final starting = _incomingStarts[transferId];
      if (starting != null) {
        await starting;
        return;
      }
      final started = Completer<void>();
      _incomingStarts[transferId] = started.future;
      try {
        final docs = await getOnyxDocumentsDirectory();
        final mediaDir = Directory('${docs.path}/onion_media');
        await mediaDir.create(recursive: true);
        final partFile = File('${mediaDir.path}/$filename.part');
        final raf = await partFile.open(mode: FileMode.write);
        _incomingTransfers[transferId] = _IncomingMediaTransfer(
          raf: raf,
          partFile: partFile,
          finalFile: File('${mediaDir.path}/$filename'),
          totalChunks: totalChunks,
          chunkSize: chunkSize,
          onIdle: () => _incomingTransfers.remove(transferId),
        );
        _log('media_start from ${peer.username}: "$filename" '
            '($totalChunks chunks)');
      } catch (e) {
        _log('media_start from ${peer.username}: failed to open $filename: $e');
      } finally {
        _incomingStarts.remove(transferId);
        started.complete();
      }
    } else if (type == 'media_chunk') {
      final transferId = obj['transferId'] as String?;
      final index = (obj['index'] as num?)?.toInt();
      final bin = obj['_bin'] as Uint8List?; // binary frame (new peers)
      final dataB64 = obj['data'] as String?; // base64 (legacy peers)
      if (transferId == null || index == null) return;
      if (bin == null && dataB64 == null) return;
      final transfer = _incomingTransfers[transferId];
      if (transfer == null) {
        _log('dropping media_chunk for unknown/expired transfer $transferId');
        return;
      }
      List<int> bytes;
      try {
        bytes = bin ?? base64Decode(dataB64!);
      } catch (_) {
        return;
      }
      bool done;
      try {
        done = await transfer.addChunk(index, bytes);
      } catch (e) {
        // A failed disk write loses this one chunk (the status query will
        // ask for it again), not the whole stream.
        _log('media_chunk $index of $transferId: write failed: $e');
        return;
      }
      if (done) {
        _incomingTransfers.remove(transferId);
        _markTransferCompleted(transferId);
        _log('media_chunked: "${transfer.finalFile.path}" complete '
            '(${transfer.receivedChunks}/${transfer.totalChunks} chunks)');
      }
    }
  }

  /// In-flight incoming chunked transfers, keyed by the sender-chosen
  /// transferId -- entries are removed on completion or abandonment (stale
  /// timeout, see [_IncomingMediaTransfer]).
  final Map<String, _IncomingMediaTransfer> _incomingTransfers = {};

  /// Transfers whose 'media_start' is being set up right now (see there).
  final Map<String, Future<void>> _incomingStarts = {};

  /// Which transfer each incoming file stream carries (by handle), until
  /// that stream has been read to the end.
  final Map<int, String> _laneOf = {};

  /// Recently completed incoming transfers, so a late 'media_start' (a lane
  /// that arrives after the file is already done) or 'media_query' is
  /// answered correctly instead of starting an empty transfer.
  final LinkedHashSet<String> _completedTransfers = LinkedHashSet<String>();

  void _markTransferCompleted(String transferId) {
    _completedTransfers.add(transferId);
    while (_completedTransfers.length > 200) {
      _completedTransfers.remove(_completedTransfers.first);
    }
  }

  /// Answers a sender's 'media_query' once every stream of that transfer
  /// has been read to the end -- otherwise chunks still in flight would be
  /// reported missing and sent twice.
  Future<void> _answerMediaQuery(_PeerChannel ch, String transferId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 100));
    while (_laneOf.containsValue(transferId) &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    final t = _incomingTransfers[transferId];
    if (t != null) await t.drain();
    final done = _completedTransfers.contains(transferId);
    final bitmap = (!done && t != null) ? t.bitmap() : Uint8List(0);
    try {
      await _channelSend(ch, {
        'type': 'media_have',
        'transferId': transferId,
        'done': done,
        'have': base64Encode(bitmap),
      });
    } catch (_) {}
  }

  /// Name advertised to onion peers -- the profile display name set on
  /// the "Edit profile" screen, falling back to the account username and
  /// then the device name if neither is available yet.
  Future<String> _getDisplayName() async {
    final username = _username;
    if (username != null) {
      final cached = await AccountManager.getCachedDisplayName(username);
      if (cached != null && cached.trim().isNotEmpty) return cached.trim();
      return username;
    }
    return _getDeviceName();
  }

  Future<String> _getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        _cachedDeviceName = '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        _cachedDeviceName = info.name;
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        _cachedDeviceName = info.computerName;
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        _cachedDeviceName = info.computerName;
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        _cachedDeviceName = info.name;
      } else {
        _cachedDeviceName = Platform.operatingSystem;
      }
    } catch (_) {
      _cachedDeviceName = Platform.operatingSystem;
    }
    return _cachedDeviceName!;
  }

  static Uint8List _u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }
}

class _RawFrame {
  final int tag;
  final Uint8List payload;
  const _RawFrame(this.tag, this.payload);
}

/// One in-progress incoming chunked media transfer (see 'media_start'/
/// 'media_chunk' in [OnionTransportService._handleFrame]). Chunks are
/// written straight to a `.part` file, each at its own offset
/// (index * chunkSize) -- a multi-lane sender delivers them out of order
/// over several streams at once. Self-abandons (deletes the partial file)
/// if no chunk arrives for 60s, so a sender that dies mid-transfer doesn't
/// leave an orphaned map entry + stray `.part` file forever -- there is no
/// resume yet, so a stalled transfer is simply abandoned and the sender's
/// own retry (see [QueuedOnionSend]'s 'media_chunked' kind) starts over.
class _IncomingMediaTransfer {
  final RandomAccessFile raf;
  final File partFile;
  final File finalFile;
  final int totalChunks;
  final int chunkSize;
  final VoidCallback onIdle;
  final Set<int> _got = {};
  // Lanes deliver chunks concurrently, but a RandomAccessFile takes one
  // operation at a time -- writes are chained.
  Future<void> _chain = Future<void>.value();
  Timer? _idleTimer;
  bool _closed = false;

  int get receivedChunks => _got.length;

  _IncomingMediaTransfer({
    required this.raf,
    required this.partFile,
    required this.finalFile,
    required this.totalChunks,
    required this.chunkSize,
    required this.onIdle,
  }) {
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    // Long enough for the sender to reconnect and resume (a queued retry
    // reuses the transfer id) instead of starting over from zero.
    _idleTimer = Timer(const Duration(minutes: 15), _abandon);
  }

  /// Completes once every chunk write queued so far has finished.
  Future<void> drain() => _chain;

  /// Which chunks have been written: bit i set = chunk i.
  Uint8List bitmap() {
    final out = Uint8List((totalChunks + 7) >> 3);
    for (final i in _got) {
      out[i >> 3] |= 1 << (i & 7);
    }
    return out;
  }

  /// Writes chunk [index]; returns true once the transfer is complete (the
  /// `.part` file has been closed and renamed to [finalFile]).
  Future<bool> addChunk(int index, List<int> bytes) {
    final result = _chain.then((_) => _write(index, bytes));
    _chain = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _write(int index, List<int> bytes) async {
    if (_closed) return false;
    _resetIdleTimer();
    if (index < 0 || index >= totalChunks || _got.contains(index)) {
      return false;
    }
    await raf.setPosition(index * chunkSize);
    await raf.writeFrom(bytes);
    _got.add(index);
    if (_got.length < totalChunks) return false;
    _closed = true;
    _idleTimer?.cancel();
    try {
      await raf.close();
      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(finalFile.path);
    } catch (_) {
      // Best effort -- a failed rename just leaves the receiver without
      // this file; the sender's normal per-message queue still has no way
      // to know that, same as a fully-lost 'media' frame today.
    }
    return true;
  }

  void _abandon() {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    onIdle();
    unawaited(() async {
      try {
        await _chain;
      } catch (_) {}
      try {
        await raf.close();
      } catch (_) {}
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
    }());
  }
}

/// Incrementally reassembles the `[1-byte tag][4-byte BE length][payload]`
/// wire format documented at the top of this file from arbitrarily-chunked
/// reads off an onyx_tor stream (which, unlike `WardLinkFrameReader`'s
/// `Stream<List<int>>` source, is polled via streamRead rather than pushed).
class _FrameAssembler {
  // Kept as the received pieces, joined only once per complete frame. (It
  // used to re-copy the whole buffer on every read, which for a 512KB chunk
  // frame arriving in many small reads added up to megabytes of copying.)
  final ListQueue<Uint8List> _chunks = ListQueue<Uint8List>();
  int _len = 0;

  void addChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _chunks.add(chunk);
    _len += chunk.length;
  }

  /// Copies the first [n] buffered bytes out; consumes them if [consume].
  Uint8List _copy(int n, {required bool consume}) {
    final out = Uint8List(n);
    var off = 0;
    if (!consume) {
      for (final c in _chunks) {
        if (off >= n) break;
        final take = min(c.length, n - off);
        out.setRange(off, off + take, c);
        off += take;
      }
      return out;
    }
    while (off < n) {
      final c = _chunks.removeFirst();
      final need = n - off;
      if (c.length <= need) {
        out.setRange(off, off + c.length, c);
        off += c.length;
      } else {
        out.setRange(off, n, c);
        _chunks.addFirst(Uint8List.sublistView(c, need));
        off = n;
      }
    }
    _len -= n;
    return out;
  }

  _RawFrame? tryTakeFrame() {
    if (_len < 5) return null;
    final head = _copy(5, consume: false);
    final len = ByteData.sublistView(head, 1, 5).getUint32(0, Endian.big);
    if (_len < 5 + len) return null;
    _copy(5, consume: true);
    return _RawFrame(head[0], _copy(len, consume: true));
  }
}

class _PeerPresence {
  final DateTime at;
  final bool visible;
  final String text;
  const _PeerPresence(this.at, this.visible, this.text);
}

/// One long-lived stream to a paired device -- see the "channels" section
/// of [OnionTransportService].
class _PeerChannel {
  final int handle;

  /// The peer device's identity pubkey (base64).
  final String pub;

  /// True if we dialed it, false if the peer dialed us.
  final bool outbound;

  /// Set once both sides exchanged 'hello'.
  bool open = false;
  bool closed = false;

  /// Completes true once open, false if it closes/fails before that.
  final Completer<bool> opened = Completer<bool>();

  DateTime openedAt = DateTime.now();
  DateTime lastRx = DateTime.now();
  DateTime lastPing = DateTime.now();

  /// Writes (or long multi-frame sends) in progress -- a channel busy
  /// pushing a big file isn't declared dead just because the peer's pings
  /// are queued behind it.
  int writing = 0;

  /// Frames waiting in this channel's write queue. Call audio/video is
  /// dropped instead of queued once this backs up -- stale media is worse
  /// than lost media.
  int queued = 0;

  /// The peer's hello said it understands raw call-media frames (tag 2).
  bool rawCallMedia = false;

  /// ...and extra per-call lanes (cm >= 2).
  bool callLanes = false;

  _PeerChannel({
    required this.handle,
    required this.pub,
    required this.outbound,
  });
}

/// One extra per-call stream to a peer (see "call paths").
class _CallLane {
  final int handle;
  final String pub;
  bool closed = false;
  int queued = 0;
  DateTime lastRx = DateTime.now();
  final Completer<void> done = Completer<void>();
  _CallLane(this.handle, this.pub);
}

/// A receiver's answer to 'media_query': done, or which chunks it has.
class _TransferStatus {
  final bool done;
  final Uint8List bitmap; // bit i set = chunk i received
  const _TransferStatus(this.done, this.bitmap);

  bool has(int i) {
    if (done) return true;
    final byte = i >> 3;
    return byte < bitmap.length && (bitmap[byte] & (1 << (i & 7))) != 0;
  }
}

class _PendingAck {
  final _PeerChannel channel;
  final Completer<bool> completer = Completer<bool>();
  _PendingAck(this.channel);
}
