// lib/managers/decoy_data_manager.dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/group.dart';
import '../models/favorite_chat.dart';

class DecoyMsg {
  final String text;
  final bool outgoing;
  final DateTime time;

  const DecoyMsg({required this.text, required this.outgoing, required this.time});

  Map<String, dynamic> toJson() => {
    'text': text, 'outgoing': outgoing, 'time': time.toIso8601String(),
  };

  factory DecoyMsg.fromJson(Map<String, dynamic> j) => DecoyMsg(
    text: j['text'] as String? ?? '',
    outgoing: j['outgoing'] as bool? ?? false,
    time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
  );
}

class DecoyContact {
  final String username;
  final String displayName;
  final List<DecoyMsg> messages;

  const DecoyContact({required this.username, required this.displayName, required this.messages});

  DecoyContact copyWith({String? username, String? displayName, List<DecoyMsg>? messages}) =>
    DecoyContact(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      messages: messages ?? this.messages,
    );

  Map<String, dynamic> toJson() => {
    'username': username,
    'displayName': displayName,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory DecoyContact.fromJson(Map<String, dynamic> j) => DecoyContact(
    username: j['username'] as String? ?? '',
    displayName: j['displayName'] as String? ?? '',
    messages: (j['messages'] as List<dynamic>? ?? [])
        .map((m) => DecoyMsg.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class DecoyDataManager {
  DecoyDataManager._();

  static const _contactsKey  = 'decoy_contacts_v1';
  static const _groupsKey    = 'decoy_groups_v1';
  static const _favoritesKey = 'decoy_favorites_v1';
  static const _autoGenKey   = 'decoy_auto_gen';

  static final _rng = Random();

  static List<DecoyContact>  contacts  = [];
  static List<Group>         fakeGroups = [];
  static List<FavoriteChat>  fakeFavorites = [];

  // ── name pools ────────────────────────────────────────────────────────────
  static const _contactPool = [
    ('throwaway_2891',   'throwaway'),
    ('pixel_wizard42',   'PixelWizard'),
    ('dark_matter_x',    'DarkMatterX'),
    ('quantum_lurker',   'QuantumLurker'),
    ('void_walker99',    'VoidWalker'),
    ('neon_phoenix_',    'NeonPhoenix'),
    ('cyber_fox_7',      'CyberFox'),
    ('ghost_protocol_',  'GhostProtocol'),
    ('night_owl_dev',    'NightOwlDev'),
    ('just_a_person_',   'justaperson'),
    ('anon_7829',        'anon7829'),
    ('blue_sky_panda',   'BlueSkyPanda'),
    ('idk_lol_42',       'idk_lol'),
    ('lurker_mode_on',   'LurkerMode'),
    ('not_a_bot_trust',  'NotABot'),
    ('chaotic_neutral_', 'ChaoticNeutral'),
    ('ok_boomer_reply',  'OkBoomerReply'),
    ('based_department', 'BasedDept'),
    ('rando_acc_9921',   'rando9921'),
    ('deleted_user__',   '[deleted]'),
  ];

  static const _groupPool = [
    'Gaming Crew',     'The Squad',       'Work Chat',
    'Family Group',    'Meme Dump',       'Movie Night',
    'Book Club',       'Dev Team',        'Weekend Plans',
    'Roommates',       'Study Group',     'Random',
    'Project Alpha',   'Foodies',         'Gym Bros',
    'Travel Planning', 'Crypto Talk',     'Side Hustle',
    'College Friends', 'Old Friends',
  ];

  static const _channelPool = [
    'Daily News',      'Tech Updates',    'Crypto Signals',
    'Weather Bot',     'Memes',           'Sports Live',
    'Movie Releases',  'Game Updates',    'Tips & Tricks',
    'Music Drops',
  ];

  static const _favPool = [
    'Important',   'Notes',       'Recipes',
    'Plans',       'Passwords',   'Books',
    'Movies',      'Ideas',       'Work',
    'Personal',
  ];

  static const _msgPool = [
    'lmao same',
    'wait what',
    'ok but fr though',
    'ngl that\'s kinda wild',
    'no way that actually happened',
    'sent',
    'ok',
    'bro stop',
    'yeah totally',
    'lol did you see that',
    'anyway what\'s up',
    'omg fr??',
    'that\'s so real',
    'facts',
    'can you send me the link?',
    'i\'ll be there in like 20',
    'just checked, looks good',
    'haha yeah',
    'wait really?',
    'mood',
    'no bc same',
    'ok this is actually funny',
    'nvm figured it out',
    'ty!',
    'on my way',
    'brb',
    'lmk',
    'based',
    'sounds good',
    'k',
  ];

  // ── persistence ───────────────────────────────────────────────────────────
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // contacts
    try {
      final raw = prefs.getString(_contactsKey);
      contacts = raw == null ? [] :
          (jsonDecode(raw) as List<dynamic>)
              .map((e) => DecoyContact.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) { contacts = []; }

    // groups
    try {
      final raw = prefs.getString(_groupsKey);
      fakeGroups = raw == null ? [] :
          (jsonDecode(raw) as List<dynamic>)
              .map((e) => Group.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) { fakeGroups = []; }

    // favorites
    try {
      final raw = prefs.getString(_favoritesKey);
      fakeFavorites = raw == null ? [] :
          (jsonDecode(raw) as List<dynamic>)
              .map((e) => FavoriteChat.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) { fakeFavorites = []; }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contactsKey,  jsonEncode(contacts.map((c) => c.toJson()).toList()));
    await prefs.setString(_groupsKey,    jsonEncode(fakeGroups.map((g) => g.toJson()).toList()));
    await prefs.setString(_favoritesKey, jsonEncode(fakeFavorites.map((f) => f.toJson()).toList()));
  }

  static Future<bool> isAutoGenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoGenKey) ?? false;
  }

  static Future<void> setAutoGenEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoGenKey, val);
  }

  // ── builders ──────────────────────────────────────────────────────────────
  static Map<String, List<ChatMessage>> buildChatMap(String myUsername) {
    final map = <String, List<ChatMessage>>{};
    for (final contact in contacts) {
      final ids = [myUsername, contact.username]..sort();
      final chatId = ids.join(':');
      map[chatId] = contact.messages.map((m) => ChatMessage(
        id: 'decoy_${contact.username}_${m.time.millisecondsSinceEpoch}',
        from: m.outgoing ? myUsername : contact.username,
        to: m.outgoing ? contact.username : myUsername,
        content: m.text,
        outgoing: m.outgoing,
        delivered: true,
        isRead: true,
        time: m.time,
      )).toList();
    }
    return map;
  }

  // ── generation ────────────────────────────────────────────────────────────
  static Future<void> generateAll({String ownerUsername = 'user'}) async {
    contacts = [];
    fakeGroups = [];
    fakeFavorites = [];

    // Chats: 8..18
    final chatCount = 8 + _rng.nextInt(11);
    final shuffledContacts = List.of(_contactPool)..shuffle(_rng);
    final now = DateTime.now();

    for (int i = 0; i < chatCount && i < shuffledContacts.length; i++) {
      final (username, displayName) = shuffledContacts[i];
      final msgCount = 4 + _rng.nextInt(10);
      final msgs = <DecoyMsg>[];
      for (int j = 0; j < msgCount; j++) {
        msgs.add(DecoyMsg(
          text: _msgPool[_rng.nextInt(_msgPool.length)],
          outgoing: _rng.nextBool(),
          time: now.subtract(Duration(minutes: (msgCount - j) * (2 + _rng.nextInt(12)))),
        ));
      }
      contacts.add(DecoyContact(username: username, displayName: displayName, messages: msgs));
    }

    // Groups: 3..8
    final groupCount = 3 + _rng.nextInt(6);
    final shuffledGroups = List.of(_groupPool)..shuffle(_rng);
    for (int i = 0; i < groupCount && i < shuffledGroups.length; i++) {
      fakeGroups.add(Group(
        id: -(i + 1),
        name: shuffledGroups[i],
        isChannel: false,
        owner: ownerUsername,
        inviteLink: '',
        avatarVersion: 0,
        myRole: _rng.nextBool() ? 'owner' : 'member',
      ));
    }
    // Channels: 1..4
    final channelCount = 1 + _rng.nextInt(4);
    final shuffledChannels = List.of(_channelPool)..shuffle(_rng);
    for (int i = 0; i < channelCount && i < shuffledChannels.length; i++) {
      fakeGroups.add(Group(
        id: -(groupCount + i + 1),
        name: shuffledChannels[i],
        isChannel: true,
        owner: 'admin',
        inviteLink: '',
        avatarVersion: 0,
        myRole: 'member',
      ));
    }

    // Favorites: 2..7
    final favCount = 2 + _rng.nextInt(6);
    final shuffledFavs = List.of(_favPool)..shuffle(_rng);
    for (int i = 0; i < favCount && i < shuffledFavs.length; i++) {
      fakeFavorites.add(FavoriteChat(
        id: 'decoy_fav_$i',
        title: shuffledFavs[i],
        createdAt: now.subtract(Duration(days: _rng.nextInt(90))),
      ));
    }

    await save();
  }

  static Future<void> clearAll() async {
    contacts = [];
    fakeGroups = [];
    fakeFavorites = [];
    await save();
  }

  // ── manual CRUD ──────────────────────────────────────────────────────────────
  static Future<void> addContact({
    required String username,
    required String displayName,
  }) async {
    if (contacts.any((c) => c.username == username)) return;
    final now = DateTime.now();
    final msgCount = 3 + _rng.nextInt(8);
    final msgs = <DecoyMsg>[];
    for (int j = 0; j < msgCount; j++) {
      msgs.add(DecoyMsg(
        text: _msgPool[_rng.nextInt(_msgPool.length)],
        outgoing: _rng.nextBool(),
        time: now.subtract(Duration(minutes: (msgCount - j) * (3 + _rng.nextInt(8)))),
      ));
    }
    contacts.add(DecoyContact(username: username, displayName: displayName, messages: msgs));
    await save();
  }

  static Future<void> removeContact(String username) async {
    contacts.removeWhere((c) => c.username == username);
    await save();
  }

  static Future<void> addGroup({required String name, required bool isChannel}) async {
    final minId = fakeGroups.isEmpty
        ? -1
        : fakeGroups.map((g) => g.id).reduce((a, b) => a < b ? a : b) - 1;
    fakeGroups.add(Group(
      id: minId,
      name: name,
      isChannel: isChannel,
      owner: 'user',
      inviteLink: '',
      avatarVersion: 0,
      myRole: 'owner',
    ));
    await save();
  }

  static Future<void> removeGroup(int id) async {
    fakeGroups.removeWhere((g) => g.id == id);
    await save();
  }

  static Future<void> addFavorite({required String title}) async {
    fakeFavorites.add(FavoriteChat(
      id: 'decoy_fav_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAt: DateTime.now(),
    ));
    await save();
  }

  static Future<void> removeFavorite(String id) async {
    fakeFavorites.removeWhere((f) => f.id == id);
    await save();
  }

  // ── chat message persistence ───────────────────────────────────────────────
  static Future<void> addMessageToContact(
    String contactUsername, String myUsername, String text, bool outgoing,
  ) async {
    final idx = contacts.indexWhere((c) => c.username == contactUsername);
    final newMsg = DecoyMsg(text: text, outgoing: outgoing, time: DateTime.now());
    if (idx < 0) {
      contacts.add(DecoyContact(
        username: contactUsername,
        displayName: contactUsername,
        messages: [newMsg],
      ));
    } else {
      final c = contacts[idx];
      contacts[idx] = c.copyWith(messages: [...c.messages, newMsg]);
    }
    await save();
  }
}
