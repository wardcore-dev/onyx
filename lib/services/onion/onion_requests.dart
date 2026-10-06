// lib/services/onion/onion_requests.dart
//
// Contact requests: someone who added us by our onion address (the
// 'identify_request' path) is NOT a contact until the user accepts them.
// Until then they get nothing from us -- no channel, no presence, no
// profile, no calls (all of those are gated on OnionPairedPeers) -- and the
// messages they send wait here.
//
// A request only lands here after its claimed onion address was verified
// (see OnionTransportService._verifyRequester): we dial that address
// ourselves and the device there must prove it holds the claimed key. So a
// request can't borrow somebody else's address, and since a contact is a
// key (not a username), accepting someone whose username collides with an
// existing contact is an explicit, warned-about choice in the UI.
//
// Declining just removes the request (they may ask again later); "Decline
// and block" blocks the key: anything from it is dropped silently, forever
// (until unblocked from the blocked list in Settings).
// Scoped per local account like OnionPairedPeers.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnionRequestMessage {
  final String text;
  final DateTime at;
  final String? mid;

  const OnionRequestMessage({required this.text, required this.at, this.mid});

  Map<String, dynamic> toJson() => {
        'text': text,
        'at': at.toIso8601String(),
        if (mid != null) 'mid': mid,
      };

  factory OnionRequestMessage.fromJson(Map<String, dynamic> j) =>
      OnionRequestMessage(
        text: j['text'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        mid: j['mid'] as String?,
      );
}

class OnionContactRequest {
  final String pub;
  final String username;
  final String onionAddress;
  final String name;
  final DateTime receivedAt;
  final List<OnionRequestMessage> messages;

  const OnionContactRequest({
    required this.pub,
    required this.username,
    required this.onionAddress,
    required this.name,
    required this.receivedAt,
    this.messages = const [],
  });

  OnionContactRequest copyWith({
    String? name,
    List<OnionRequestMessage>? messages,
  }) =>
      OnionContactRequest(
        pub: pub,
        username: username,
        onionAddress: onionAddress,
        name: name ?? this.name,
        receivedAt: receivedAt,
        messages: messages ?? this.messages,
      );

  Map<String, dynamic> toJson() => {
        'pub': pub,
        'username': username,
        'onionAddress': onionAddress,
        'name': name,
        'receivedAt': receivedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory OnionContactRequest.fromJson(Map<String, dynamic> j) =>
      OnionContactRequest(
        pub: j['pub'] as String,
        username: j['username'] as String,
        onionAddress: j['onionAddress'] as String,
        name: (j['name'] as String?) ?? 'Onyx user',
        receivedAt: DateTime.tryParse(j['receivedAt'] as String? ?? '') ??
            DateTime.now(),
        messages: ((j['messages'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) =>
                OnionRequestMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// A key blocked from the Requests screen (not a contact, so it isn't in
/// the username blocklist): who it said it was, for the blocked list.
class BlockedRequester {
  final String pub;
  final String username;
  final String name;
  final DateTime at;

  const BlockedRequester({
    required this.pub,
    required this.username,
    required this.name,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'pub': pub,
        'username': username,
        'name': name,
        'at': at.toIso8601String(),
      };

  factory BlockedRequester.fromJson(Map<String, dynamic> j) => BlockedRequester(
        pub: j['pub'] as String,
        username: (j['username'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class OnionRequests {
  OnionRequests._();

  /// Spam limits: a stranger can't fill the disk. A request carries at most
  /// one comment ([OnionContactRequest.messages] holds it); a second one is
  /// dropped, and chat messages from a non-contact aren't kept at all.
  static const int maxRequests = 50;
  static const int maxMessagesPerRequest = 1;
  static const int maxMessageLength = 4000;

  static String _key(String account) => 'onion_requests_$account';
  static String _blockedKey(String account) => 'onion_blocked_v2_$account';

  /// Newest first.
  static final ValueNotifier<List<OnionContactRequest>> requests =
      ValueNotifier<List<OnionContactRequest>>([]);

  /// Keys blocked from the Requests screen, newest first.
  static final ValueNotifier<List<BlockedRequester>> blocked =
      ValueNotifier<List<BlockedRequester>>([]);

  static String? _account;

  // ── Our own outgoing requests ──────────────────────────────────────────
  // We added someone by address and we're a stranger to them: until they
  // accept (their side opens a channel to us) nothing goes to their chat --
  // no messages, no calls. What we wrote in the request modal travels as the
  // request's comment instead ('request_comment'), shown on their Requests
  // screen only.

  static String _outKey(String account) => 'onion_outgoing_v3_$account';
  static String _removedKey(String account) => 'onion_removed_by_$account';

  static final Map<String, String> _outgoingUser = {}; // pub -> username
  // The rest of who they are, to make them a contact once they accept --
  // not before (see OnionTransportService: their 'hello' = accepted).
  static final Map<String, String> _outgoingAddr = {}; // pub -> onion address
  static final Map<String, String> _outgoingName = {}; // pub -> name
  // Their account key, from the signed device roster that came with their
  // identify_response: any device that key lists may accept for them.
  static final Map<String, String> _outgoingAcct = {}; // pub -> account key

  /// The pub our pending request went to, on the account [acct].
  static String? outgoingPubByAccount(String acct) {
    for (final e in _outgoingAcct.entries) {
      if (e.value == acct && _outgoingUser.containsKey(e.key)) return e.key;
    }
    return null;
  }

  /// Who our pending request to [pub] went to: (username, address, name).
  static (String, String, String)? outgoingByPub(String pub) {
    final u = _outgoingUser[pub];
    final a = _outgoingAddr[pub];
    if (u == null || a == null) return null;
    return (u, a, _outgoingName[pub] ?? '');
  }

  /// Contacts (keys) whose device told us we're not in their contacts --
  /// they removed us (or never accepted). Nothing is delivered to them and
  /// they're never shown online, until they open a channel to us again.
  static final Set<String> _removedBy = {};

  /// Bumped on every change of the two above, for UI.
  static final ValueNotifier<int> outgoingVersion = ValueNotifier<int>(0);

  static Future<void> markOutgoing(String pub, String username,
      {required String onionAddress, String name = '', String? acct}) async {
    _outgoingUser[pub] = username;
    _outgoingAddr[pub] = onionAddress;
    _outgoingName[pub] = name;
    if (acct != null) {
      _outgoingAcct[pub] = acct;
    } else {
      _outgoingAcct.remove(pub);
    }
    outgoingVersion.value++;
    await _persist();
  }

  /// Accepted / re-added: they opened a channel to us.
  static Future<void> clearOutgoing(String pub) async {
    _outgoingAddr.remove(pub);
    _outgoingName.remove(pub);
    _outgoingAcct.remove(pub);
    final a = _outgoingUser.remove(pub) != null;
    final b = _removedBy.remove(pub);
    if (!a && !b) return;
    outgoingVersion.value++;
    await _persist();
  }

  /// We already sent (or queued) a request to [onionAddress] and it's still
  /// waiting -- sending again replaces it.
  static bool isOutgoingPendingAddress(String onionAddress) {
    final a = onionAddress.trim().toLowerCase();
    return _outgoingAddr.containsValue(a) || _queued.containsKey(a);
  }

  // ── Requests to people who were offline ─────────────────────────────────
  // Adding someone by address needs them online. If they weren't, the
  // request (with its comment) waits here and OnionTransportService retries
  // it at every start and every few minutes until it gets through.

  static String _queuedKey(String account) => 'onion_queued_requests_$account';

  /// onion address -> comment ('' = none).
  static final Map<String, String> _queued = {};

  static Map<String, String> get queuedRequests => Map.of(_queued);

  static bool isQueuedAddress(String onionAddress) =>
      _queued.containsKey(onionAddress.trim().toLowerCase());

  /// Queues (or replaces) the request to [onionAddress].
  static Future<void> queueRequest(String onionAddress, String comment) async {
    _queued[onionAddress.trim().toLowerCase()] = comment;
    outgoingVersion.value++;
    await _persist();
  }

  static Future<void> dequeueRequest(String onionAddress) async {
    if (_queued.remove(onionAddress.trim().toLowerCase()) == null) return;
    outgoingVersion.value++;
    await _persist();
  }

  /// Our request to [username] is still waiting for their approval.
  static bool isOutgoingPending(String username) =>
      _outgoingUser.containsValue(username);

  static Future<void> markRemovedBy(String pub) async {
    if (!_removedBy.add(pub)) return;
    outgoingVersion.value++;
    await _persist();
  }

  static bool isRemovedBy(String pub) => _removedBy.contains(pub);

  /// We (re)made them a contact ourselves -- an old "they removed us" from
  /// earlier must not keep us from reaching them now.
  static Future<void> clearRemovedBy(String pub) async {
    if (!_removedBy.remove(pub)) return;
    outgoingVersion.value++;
    await _persist();
  }

  /// Our pending or queued request went to [onionAddress].
  static bool hasRequestTo(String onionAddress) {
    final a = onionAddress.trim().toLowerCase();
    return _outgoingAddr.containsValue(a) || _queued.containsKey(a);
  }

  static Future<void> load(String username) async {
    _account = username;
    final prefs = await SharedPreferences.getInstance();
    _outgoingUser.clear();
    _outgoingAddr.clear();
    _outgoingName.clear();
    _outgoingAcct.clear();
    for (final s in prefs.getStringList(_outKey(username)) ?? const []) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        final pub = j['pub'] as String;
        _outgoingUser[pub] = j['username'] as String;
        _outgoingAddr[pub] = j['onionAddress'] as String;
        _outgoingName[pub] = (j['name'] as String?) ?? '';
        final acct = j['acct'] as String?;
        if (acct != null) _outgoingAcct[pub] = acct;
      } catch (_) {}
    }
    _removedBy
      ..clear()
      ..addAll(prefs.getStringList(_removedKey(username)) ?? const []);
    _queued.clear();
    try {
      final raw = prefs.getString(_queuedKey(username));
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>)
            .forEach((k, v) => _queued[k] = v?.toString() ?? '');
      }
    } catch (_) {}
    outgoingVersion.value++;
    final raw = prefs.getStringList(_key(username)) ?? [];
    requests.value = raw
        .map((s) {
          try {
            return OnionContactRequest.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<OnionContactRequest>()
        .toList();
    blocked.value = (prefs.getStringList(_blockedKey(username)) ?? [])
        .map((s) {
          try {
            return BlockedRequester.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<BlockedRequester>()
        .toList();
  }

  static Future<void> _persist() async {
    final account = _account;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(account),
      requests.value.map((r) => jsonEncode(r.toJson())).toList(),
    );
    await prefs.setStringList(_blockedKey(account),
        blocked.value.map((b) => jsonEncode(b.toJson())).toList());
    await prefs.setStringList(_outKey(account), [
      for (final e in _outgoingUser.entries)
        jsonEncode({
          'pub': e.key,
          'username': e.value,
          'onionAddress': _outgoingAddr[e.key],
          'name': _outgoingName[e.key],
          if (_outgoingAcct[e.key] != null) 'acct': _outgoingAcct[e.key],
        }),
    ]);
    await prefs.setStringList(_removedKey(account), _removedBy.toList());
    await prefs.setString(_queuedKey(account), jsonEncode(_queued));
  }

  static OnionContactRequest? byPub(String pub) {
    for (final r in requests.value) {
      if (r.pub == pub) return r;
    }
    return null;
  }

  static bool isBlocked(String pub) => blocked.value.any((b) => b.pub == pub);

  /// Adds a (verified) request. Asked again: the new request replaces the
  /// old one -- its comment (or lack of one), name and time -- and moves to
  /// the top; requests never pile up per sender.
  static Future<void> upsert(OnionContactRequest req) async {
    final list = requests.value.where((r) => r.pub != req.pub).toList();
    list.insert(0, req);
    while (list.length > maxRequests) {
      list.removeLast();
    }
    requests.value = list;
    await _persist();
  }

  static Future<void> addMessage(String pub, OnionRequestMessage msg,
      {String? name}) async {
    final req = byPub(pub);
    if (req == null) return;
    if (req.messages.length >= maxMessagesPerRequest) return; // one, no spam
    if (msg.mid != null && req.messages.any((m) => m.mid == msg.mid)) return;
    final text = msg.text.length > maxMessageLength
        ? msg.text.substring(0, maxMessageLength)
        : msg.text;
    final msgs = [
      ...req.messages,
      OnionRequestMessage(text: text, at: msg.at, mid: msg.mid),
    ];
    while (msgs.length > maxMessagesPerRequest) {
      msgs.removeAt(0);
    }
    requests.value = [
      for (final r in requests.value)
        if (r.pub == pub)
          r.copyWith(
              messages: msgs,
              name: (name != null && name.isNotEmpty) ? name : null)
        else
          r,
    ];
    await _persist();
  }

  /// Takes a request out of the list (accept), returning it.
  static Future<OnionContactRequest?> take(String pub) async {
    final req = byPub(pub);
    if (req == null) return null;
    requests.value = requests.value.where((r) => r.pub != pub).toList();
    await _persist();
    return req;
  }

  /// Declines: drops the request. With [block], the key is ignored from now
  /// on (no new requests, no messages); without, they may ask again.
  static Future<void> decline(String pub, {bool block = false}) async {
    final req = byPub(pub);
    requests.value = requests.value.where((r) => r.pub != pub).toList();
    if (block && !isBlocked(pub)) {
      blocked.value = [
        BlockedRequester(
          pub: pub,
          username: req?.username ?? '',
          name: req?.name ?? '',
          at: DateTime.now(),
        ),
        ...blocked.value,
      ];
    }
    await _persist();
  }

  /// Unblocked from the blocked list, or the user added this key themselves
  /// (by address).
  static Future<void> unblock(String pub) async {
    if (!isBlocked(pub)) return;
    blocked.value = blocked.value.where((b) => b.pub != pub).toList();
    await _persist();
  }
}
