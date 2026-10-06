// lib/services/onion/onion_send_queue.dart
//
// Local retry queue for onion-mode sends that failed because the peer
// wasn't reachable *right now* -- not a real mailbox/relay (there is no
// server to hand it off to), just "keep this device's own retry loop
// going until the peer's hidden service answers, or the app is closed".
// If the peer's app stays closed for a long time, this queue is useless
// to them -- that gap can only be closed by a real server-side relay
// (see the onion-mode plan's deferred Phase 4), which this deliberately
// is not. Persisted so a queued send survives an app restart on *this*
// device, scoped per local account like OnionPairedPeers.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QueuedOnionSend {
  final String id;
  final String peerUsername;

  /// The specific paired device (by identity pubkey) this retry targets.
  /// A contact can have more than one device paired under the same
  /// username (onion identity is per-device), so a failed send is queued
  /// per-device -- retrying must redial that exact device, not "whichever
  /// of their devices happens to be first in the list" (which could
  /// resend to a device that already received it fine). Null only for
  /// entries persisted by an older build, before this field existed; those
  /// fall back to the single-device behavior that was in place then.
  final String? targetPub;

  /// 'text' (a chat message pointer, including IMAGEv1/VOICEv1 pointer
  /// strings -- those are just text as far as the transport is concerned),
  /// 'media' (the raw bytes behind such a pointer), 'sent_copy' / 'own'
  /// (for another of our own devices: [text] holds the copy / the JSON
  /// event, [localId] its id).
  final String kind;

  // 'text' fields.
  final String? text;
  // A chat-message id for [OnionTransportService.onDeliveryUpdate] to
  // report back against once this is finally delivered, so the UI can flip
  // its tick from pending to delivered. Only text entries carry one --
  // media entries have no UI element of their own (the sender already sees
  // their own image/voice note immediately from the local cache; the
  // pointer text is what carries the user-visible delivery state).
  final String? localId;

  // 'media' fields. The bytes themselves are NOT stored here -- they're
  // read fresh from [mediaFilePath] on every retry, since that file (in
  // onion_media/) already persists independently and duplicating
  // potentially-large bytes into SharedPreferences would be wasteful.
  final String? mediaKind;
  final String? mediaFilePath;
  final String? mediaFilename;
  final Map<String, dynamic>? mediaExtra;

  /// 'media_chunked' only: the transfer id the first attempt used. Retries
  /// reuse it so the receiver, if it still holds the partial file, reports
  /// what it already has and only the missing chunks are resent.
  final String? transferId;

  /// 'text' sent on behalf of another of OUR devices (by its onion device
  /// pub) that couldn't reach the contact itself -- it gets a 'relay_ok'
  /// own event once this is delivered (see OnionTransportService's
  /// own-device events).
  final String? relayFor;

  final DateTime enqueuedAt;
  int attempts;

  QueuedOnionSend({
    this.transferId,
    this.relayFor,
    required this.id,
    required this.peerUsername,
    this.targetPub,
    required this.kind,
    this.text,
    this.localId,
    this.mediaKind,
    this.mediaFilePath,
    this.mediaFilename,
    this.mediaExtra,
    required this.enqueuedAt,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'peerUsername': peerUsername,
        'targetPub': targetPub,
        'kind': kind,
        'text': text,
        'localId': localId,
        'mediaKind': mediaKind,
        'mediaFilePath': mediaFilePath,
        'mediaFilename': mediaFilename,
        'mediaExtra': mediaExtra,
        'transferId': transferId,
        if (relayFor != null) 'relayFor': relayFor,
        'enqueuedAt': enqueuedAt.toIso8601String(),
        'attempts': attempts,
      };

  static QueuedOnionSend fromJson(Map<String, dynamic> j) => QueuedOnionSend(
        id: j['id'] as String,
        peerUsername: j['peerUsername'] as String,
        targetPub: j['targetPub'] as String?,
        kind: j['kind'] as String,
        text: j['text'] as String?,
        localId: j['localId'] as String?,
        mediaKind: j['mediaKind'] as String?,
        mediaFilePath: j['mediaFilePath'] as String?,
        mediaFilename: j['mediaFilename'] as String?,
        mediaExtra: (j['mediaExtra'] as Map?)?.cast<String, dynamic>(),
        transferId: j['transferId'] as String?,
        relayFor: j['relayFor'] as String?,
        enqueuedAt: DateTime.parse(j['enqueuedAt'] as String),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

class OnionSendQueue {
  OnionSendQueue._();

  static String _key(String account) => 'onion_send_queue_$account';

  static final ValueNotifier<List<QueuedOnionSend>> items =
      ValueNotifier<List<QueuedOnionSend>>([]);

  static String? _account;

  static Future<void> load(String username) async {
    _account = username;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(username)) ?? [];
    items.value = raw
        .map((s) {
          try {
            return QueuedOnionSend.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<QueuedOnionSend>()
        .toList();
  }

  static Future<void> _persist() async {
    final account = _account;
    if (account == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(account),
      items.value.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  static Future<void> add(QueuedOnionSend item) async {
    items.value = [...items.value, item];
    await _persist();
  }

  static Future<void> remove(String id) async {
    items.value = items.value.where((i) => i.id != id).toList();
    await _persist();
  }

  static Future<void> removeWhere(bool Function(QueuedOnionSend) test) async {
    final kept = items.value.where((i) => !test(i)).toList();
    if (kept.length == items.value.length) return;
    items.value = kept;
    await _persist();
  }

  static Future<void> bumpAttempts(String id) async {
    items.value = [
      for (final i in items.value)
        if (i.id == id) (i..attempts += 1) else i,
    ];
    await _persist();
  }

  /// Drops everything queued for a peer, e.g. if their last remaining
  /// paired device gets unpaired -- there's no point retrying delivery to
  /// someone no longer trusted at all.
  static Future<void> removeAllFor(String peerUsername) async {
    items.value =
        items.value.where((i) => i.peerUsername != peerUsername).toList();
    await _persist();
  }

  /// Drops everything queued for one specific device (by pubkey), e.g. when
  /// that device gets unpaired but the same contact still has another
  /// device paired -- unlike [removeAllFor] this leaves anything still
  /// queued for their other device(s) alone.
  static Future<void> removeAllForDevice(String identityPubB64) async {
    items.value =
        items.value.where((i) => i.targetPub != identityPubB64).toList();
    await _persist();
  }
}
