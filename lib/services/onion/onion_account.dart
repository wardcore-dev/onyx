// lib/services/onion/onion_account.dart
//
// Multi-device accounts. Every device has its OWN onion address and its own
// X25519 key (OnionAccountKey) -- two devices sharing one address/key made
// Tor publish two competing descriptors and made contacts' channels to the
// two devices evict each other, so nothing got through while both were on.
//
// What ties a user's devices together is the ACCOUNT key: an Ed25519 key
// shared by all of them (handed over when a device is linked). It signs the
// account's device list, the "roster":
//
//   body = {"v":1, "acct":<ed25519 pub b64>, "ver":<int>,
//           "dev":[{"p":<device x25519 pub>, "o":<onion>, "n":<name>,
//                   "s":<os>, "t":<added ms>}...],
//           "rm":[<device pub>...]}
//   wire = {"b": <body as a JSON string>, "s": <ed25519 sig over b, b64>}
//
// The roster rides every 'hello' (and a 'roster' frame when it changes).
// A contact binds the account key the first time a device it already
// trusts presents a roster listing itself (trust-on-first-use over an
// authenticated channel), and from then on adds every device that key
// lists -- so writing to one address reaches all of the user's devices.
//
// Rosters merge as a two-phase set: devices = union minus every removed
// pub, removed = union. A removed device never comes back (a re-linked
// device gets a fresh key anyway), so merges never conflict.

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../../managers/secure_store.dart';
import '../wardlink/wardlink_crypto.dart';
import 'onion_account_key.dart';
import 'onion_paired_peers.dart';

class RosterDevice {
  final String pub;
  final String onion;
  final String name;
  final String os;
  final int addedAt;

  /// Stable id of the app install (see OnionAccount.installId): a device
  /// that comes back with a new key -- linked again, say -- is recognised
  /// as the same device and its old entry dropped. Null on older entries.
  final String? did;

  const RosterDevice({
    required this.pub,
    required this.onion,
    required this.name,
    required this.os,
    required this.addedAt,
    this.did,
  });

  Map<String, dynamic> toJson() => {
        'p': pub,
        'o': onion,
        'n': name,
        's': os,
        't': addedAt,
        if (did != null) 'd': did,
      };

  /// What a CONTACT (or a stranger who dialed us) gets to see of this
  /// device: its key and address -- needed to reach it -- and nothing else.
  /// No device name, no OS, no "added at", no install id: those say what you
  /// own, and only your own devices have a use for them.
  Map<String, dynamic> toPublicJson() => {'p': pub, 'o': onion};

  static RosterDevice? fromJson(Object? j) {
    if (j is! Map) return null;
    final pub = j['p'], onion = j['o'];
    if (pub is! String || onion is! String) return null;
    return RosterDevice(
      pub: pub,
      onion: onion,
      name: (j['n'] as String?) ?? '',
      os: (j['s'] as String?) ?? 'unknown',
      addedAt: (j['t'] as num?)?.toInt() ?? 0,
      did: j['d'] as String?,
    );
  }
}

class Roster {
  final String acct;
  final int ver;
  final List<RosterDevice> devices;
  final Set<String> removed;

  const Roster({
    required this.acct,
    required this.ver,
    required this.devices,
    required this.removed,
  });

  RosterDevice? device(String pub) {
    for (final d in devices) {
      if (d.pub == pub) return d;
    }
    return null;
  }

  bool lists(String pub) => device(pub) != null && !removed.contains(pub);

  String encodeBody() => jsonEncode({
        'v': 1,
        'acct': acct,
        'ver': ver,
        'dev': [for (final d in devices) d.toJson()],
        'rm': removed.toList()..sort(),
      });

  /// The roster as shown to contacts: same account, version, devices and
  /// removals, but each device reduced to [RosterDevice.toPublicJson]. It is
  /// signed separately (see [OnionAccount.signedPublicRoster]); the missing
  /// fields read back as their defaults, so older builds parse it fine.
  String encodePublicBody() => jsonEncode({
        'v': 1,
        'acct': acct,
        'ver': ver,
        'dev': [for (final d in devices) d.toPublicJson()],
        'rm': removed.toList()..sort(),
      });

  static Roster? decodeBody(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final acct = j['acct'] as String?;
      if (acct == null) return null;
      final dev = (j['dev'] as List? ?? const [])
          .map(RosterDevice.fromJson)
          .whereType<RosterDevice>()
          .toList();
      final rm = (j['rm'] as List? ?? const []).whereType<String>().toSet();
      if (dev.length > 32 || rm.length > 256) return null;
      return Roster(
        acct: acct,
        ver: (j['ver'] as num?)?.toInt() ?? 0,
        devices: dev,
        removed: rm,
      );
    } catch (_) {
      return null;
    }
  }

  /// Two-phase-set union of [a] and [b] (same account). For a device listed
  /// by both, the entry from the newer roster wins (e.g. a changed name).
  static Roster merge(Roster a, Roster b) {
    final newer = a.ver >= b.ver ? a : b, older = identical(newer, a) ? b : a;
    final removed = {...a.removed, ...b.removed};
    final byPub = <String, RosterDevice>{};
    for (final d in older.devices) {
      byPub[d.pub] = d;
    }
    for (final d in newer.devices) {
      byPub[d.pub] = d;
    }
    byPub.removeWhere((pub, _) => removed.contains(pub));
    return Roster(
      acct: a.acct,
      ver: newer.ver,
      devices: byPub.values.toList()
        ..sort((x, y) => x.addedAt.compareTo(y.addedAt)),
      removed: removed,
    );
  }

  /// Same devices and removals (ignoring ver).
  bool sameContent(Roster other) => _contentKey() == other._contentKey();

  String _contentKey() => jsonEncode({
        'd': [
          for (final d in (List.of(devices)
            ..sort((x, y) => x.pub.compareTo(y.pub))))
            [d.pub, d.onion, d.name, d.os, d.did],
        ],
        'r': removed.toList()..sort(),
      });
}

class OnionAccount {
  OnionAccount._();

  static final Ed25519 _ed = Ed25519();

  static SimpleKeyPair? _signKp;
  static String? _acctPub;
  static String? _user;
  static Roster? _roster;
  static Map<String, dynamic>? _signedWire;

  /// Our account's devices other than this one (from the roster). The
  /// transport keeps a channel to each, like to a contact's device.
  static final ValueNotifier<List<RosterDevice>> otherDevices =
      ValueNotifier<List<RosterDevice>>(const []);

  static String _seedSlot(String username) => 'onion_acct_sign_v1_$username';
  static String _rosterKey(String username) => 'onion_roster_v1_$username';
  static String _contactRmKey(String username) =>
      'onion_contact_rm_v1_$username';

  /// Removed device pubs of contacts' accounts (acct -> pubs), so an older
  /// roster from a device that hasn't heard of the removal yet can't bring
  /// one back.
  static Map<String, Set<String>> _contactRemoved = {};

  static String? get accountPubB64 => _acctPub;
  static Roster? get roster => _roster;
  static bool get isLoaded => _signKp != null && _user != null;

  /// Loads (or creates) the account signing key and our roster. A missing key
  /// is DERIVED from this device's X25519 seed rather than random: accounts
  /// that were "linked" by an older build share that seed on both devices,
  /// so both derive the same account key and their rosters agree.
  static Future<void> load(String username) async {
    if (_user == username && _signKp != null) return;
    _signKp = null;
    _acctPub = null;
    _roster = null;
    _signedWire = null;
    _user = null;
    otherDevices.value = const [];

    var seedB64 = await SecureStore.read(_seedSlot(username));
    if (seedB64 == null) {
      final deviceSeed = base64Decode(
          await OnionAccountKey.exportSeedB64(username));
      final seed = WardLinkCrypto.hkdf(
          deviceSeed, utf8.encode('onyx-account-sign-v1'), 32);
      seedB64 = base64Encode(seed);
      await SecureStore.write(_seedSlot(username), seedB64);
    }
    final kp = await _ed.newKeyPairFromSeed(base64Decode(seedB64));
    _signKp = kp;
    _acctPub = base64Encode((await kp.extractPublicKey()).bytes);
    _user = username;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rosterKey(username));
    if (raw != null) {
      final r = Roster.decodeBody(raw);
      if (r != null && r.acct == _acctPub) _roster = r;
    }
    final rmRaw = prefs.getString(_contactRmKey(username));
    _contactRemoved = {};
    if (rmRaw != null) {
      try {
        final m = jsonDecode(rmRaw) as Map<String, dynamic>;
        m.forEach((k, v) {
          _contactRemoved[k] = (v as List).whereType<String>().toSet();
        });
      } catch (_) {}
    }
    _refreshOthers();
  }

  static void reset() {
    _signKp = null;
    _acctPub = null;
    _roster = null;
    _signedWire = null;
    _user = null;
    otherDevices.value = const [];
  }

  static void _refreshOthers() {
    final me = OnionAccountKey.publicKeyB64OrNull;
    final r = _roster;
    otherDevices.value = r == null
        ? const []
        : [
            for (final d in r.devices)
              if (d.pub != me && !r.removed.contains(d.pub)) d,
          ];
  }

  static RosterDevice? ownDevice(String pub) {
    for (final d in otherDevices.value) {
      if (d.pub == pub) return d;
    }
    return null;
  }

  /// One of our other devices, shaped like a contact's device record so the
  /// transport's channel code can dial/track it the same way.
  static OnionPeer? ownPeer(String pub) {
    final d = ownDevice(pub);
    final me = _user;
    if (d == null || me == null) return null;
    return OnionPeer(
      username: me,
      identityPubB64: d.pub,
      onionAddress: d.onion,
      name: d.name,
      os: d.os,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(d.addedAt),
      accountPubB64: _acctPub,
    );
  }

  static List<OnionPeer> ownPeers() => [
        for (final d in otherDevices.value) ownPeer(d.pub),
      ].whereType<OnionPeer>().toList();

  static Future<void> _save() async {
    final me = _user, r = _roster;
    if (me == null || r == null) return;
    _signedWire = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rosterKey(me), r.encodeBody());
    _refreshOthers();
  }

  /// Makes sure this device is on the roster with its current address.
  /// Returns true if the roster changed.
  static Future<bool> ensureSelf({
    required String devicePub,
    required String onion,
    required String name,
    required String os,
  }) async {
    final acct = _acctPub;
    if (acct == null) return false;
    final did = await installId();
    final cur = _roster;
    final mine = cur?.device(devicePub);
    if (cur != null &&
        cur.removed.contains(devicePub)) {
      // We were unlinked from this account earlier and still have the old
      // device key -- there's nothing sane to do but stay off the list.
      return false;
    }
    // Earlier entries of THIS device under another key (it was linked
    // again and got a new one): same install id -- or, for entries from
    // before install ids, the same name and OS (as WardLink does for its
    // paired devices). They'd show up as a second, forever-offline device.
    final stale = <String>{
      for (final d in cur?.devices ?? const <RosterDevice>[])
        if (d.pub != devicePub &&
            (d.did == did ||
                (d.did == null && d.name == name && d.os == os)))
          d.pub,
    };
    if (stale.isEmpty &&
        mine != null &&
        mine.onion == onion &&
        mine.name == name &&
        mine.os == os &&
        mine.did == did) {
      return false;
    }
    final self = RosterDevice(
      pub: devicePub,
      onion: onion,
      name: name,
      os: os,
      addedAt: mine?.addedAt ?? DateTime.now().millisecondsSinceEpoch,
      did: did,
    );
    final base = cur ??
        Roster(acct: acct, ver: 0, devices: const [], removed: const {});
    _roster = Roster(
      acct: acct,
      ver: _nextVer(base.ver),
      devices: [
        for (final d in base.devices)
          if (d.pub != devicePub && !stale.contains(d.pub)) d,
        self,
      ],
      removed: {...base.removed, ...stale},
    );
    await _save();
    return true;
  }

  static const _installIdKey = 'onyx_install_id_v1';
  static String? _installId;

  /// Random id of this app install, the same for every account on it.
  static Future<String> installId() async {
    final cached = _installId;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installIdKey);
    if (id == null) {
      final rand = Random.secure();
      id = base64UrlEncode(List<int>.generate(12, (_) => rand.nextInt(256)));
      await prefs.setString(_installIdKey, id);
    }
    return _installId = id;
  }

  static int _nextVer(int prev) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > prev ? now : prev + 1;
  }

  static Roster? _publicFor;
  static Map<String, dynamic>? _publicWire;

  /// The roster to give CONTACTS and strangers: signed like [signedRoster],
  /// but without device names, OS, install ids or timestamps. Our own
  /// devices keep getting the full one. Null before [load].
  static Future<Map<String, dynamic>?> signedPublicRoster() async {
    final kp = _signKp, r = _roster;
    if (kp == null || r == null) return null;
    // Rosters are immutable and replaced on every change, so identity is a
    // sufficient cache key.
    if (identical(_publicFor, r) && _publicWire != null) return _publicWire;
    final body = r.encodePublicBody();
    final sig = await _ed.sign(utf8.encode(body), keyPair: kp);
    _publicFor = r;
    return _publicWire = {'b': body, 's': base64Encode(sig.bytes)};
  }

  /// Signed roster for the wire, or null before [load].
  static Future<Map<String, dynamic>?> signedRoster() async {
    final cached = _signedWire;
    if (cached != null) return cached;
    final kp = _signKp, r = _roster;
    if (kp == null || r == null) return null;
    final body = r.encodeBody();
    final sig = await _ed.sign(utf8.encode(body), keyPair: kp);
    return _signedWire = {'b': body, 's': base64Encode(sig.bytes)};
  }

  /// Parses a wire roster and checks its signature against the account key
  /// it names. Null if malformed or forged.
  static Future<Roster?> verify(Object? wire) async {
    if (wire is! Map) return null;
    final body = wire['b'], sig = wire['s'];
    if (body is! String || sig is! String || body.length > 16 * 1024) {
      return null;
    }
    final r = Roster.decodeBody(body);
    if (r == null) return null;
    try {
      final acctBytes = base64Decode(r.acct);
      if (acctBytes.length != 32) return null;
      final ok = await _ed.verify(
        utf8.encode(body),
        signature: Signature(base64Decode(sig),
            publicKey:
                SimplePublicKey(acctBytes, type: KeyPairType.ed25519)),
      );
      return ok ? r : null;
    } catch (_) {
      return null;
    }
  }

  /// Merges a verified roster of OUR account into ours. Returns true if our
  /// roster changed (the caller then re-announces it).
  static Future<bool> mergeOwn(Roster incoming) async {
    final acct = _acctPub;
    if (acct == null || incoming.acct != acct) return false;
    final cur = _roster;
    final merged = cur == null ? incoming : Roster.merge(cur, incoming);
    if (cur != null && merged.sameContent(cur)) return false;
    _roster = Roster(
      acct: acct,
      ver: _nextVer(merged.ver),
      devices: merged.devices,
      removed: merged.removed,
    );
    await _save();
    return true;
  }

  /// Unlinks one of our devices: it stays on the roster's removed list, so
  /// every other device and every contact drops it.
  static Future<bool> removeDevice(String pub) async {
    final cur = _roster;
    if (cur == null || cur.removed.contains(pub)) return false;
    _roster = Roster(
      acct: cur.acct,
      ver: _nextVer(cur.ver),
      devices: [
        for (final d in cur.devices)
          if (d.pub != pub) d,
      ],
      removed: {...cur.removed, pub},
    );
    await _save();
    return true;
  }

  // ── contacts' accounts ────────────────────────────────────────────────────

  static bool isContactDeviceRemoved(String acct, String pub) =>
      _contactRemoved[acct]?.contains(pub) ?? false;

  static Future<void> noteContactRemoved(String acct, Set<String> pubs) async {
    final me = _user;
    if (me == null || pubs.isEmpty) return;
    final set = _contactRemoved.putIfAbsent(acct, () => <String>{});
    final before = set.length;
    set.addAll(pubs);
    if (set.length == before) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contactRmKey(me),
        jsonEncode(_contactRemoved.map((k, v) => MapEntry(k, v.toList()))));
  }

  // ── linking ───────────────────────────────────────────────────────────────

  /// The account key seed, for handing the account to a new device.
  static Future<String?> exportSeedB64() async {
    final kp = _signKp;
    if (kp == null) return null;
    return base64Encode(await kp.extractPrivateKeyBytes());
  }

  /// Stores a linked account's key + roster on the device being linked,
  /// before it starts under that account (it adds itself to the roster on
  /// start, see [ensureSelf]). Merged with a roster this device already has
  /// for the account (it's being linked again). Returns the roster, or null
  /// if the bundle doesn't check out.
  static Future<Roster?> importFromLink(
      String username, String seedB64, Object? rosterWire) async {
    List<int> seed;
    try {
      seed = base64Decode(seedB64);
    } catch (_) {
      return null;
    }
    if (seed.length != 32) return null;
    final r = await verify(rosterWire);
    final kp = await _ed.newKeyPairFromSeed(seed);
    final acct = base64Encode((await kp.extractPublicKey()).bytes);
    if (r == null || r.acct != acct) return null;
    await SecureStore.write(_seedSlot(username), seedB64);
    final prefs = await SharedPreferences.getInstance();
    var merged = r;
    final stored = prefs.getString(_rosterKey(username));
    final old = stored == null ? null : Roster.decodeBody(stored);
    if (old != null && old.acct == acct) merged = Roster.merge(old, r);
    await prefs.setString(_rosterKey(username), merged.encodeBody());
    if (_user == username) reset();
    return merged;
  }
}
