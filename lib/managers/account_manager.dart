// lib/managers/account_manager.dart
import 'dart:async';
import 'dart:io'; 
import 'dart:convert';

import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http; 
import 'package:path_provider/path_provider.dart';

import '../globals.dart'; 
import '../enums/media_provider.dart';
import '../models/chat_message.dart';
import '../models/group.dart';
import 'settings_manager.dart';
import 'secure_store.dart';

List<dynamic> _parseJsonListInIsolate(String jsonString) {
  return jsonDecode(jsonString) as List;
}

Map<String, dynamic> _parseJsonMapInIsolate(String jsonString) {
  return jsonDecode(jsonString) as Map<String, dynamic>;
}

class UserInfo {
  final String userId;
  final String displayName;
  final String discriminator;
  final String? pubkey;

  UserInfo({
    required this.userId,
    required this.displayName,
    required this.discriminator,
    this.pubkey,
    required String username,
  });

  String get displayTag => '$displayName#$discriminator';

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['user_id'],
      displayName: json['display_name'],
      discriminator: json['discriminator'],
      pubkey: json['pubkey'],
      username: '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'discriminator': discriminator,
        'pubkey': pubkey,
      };
}

class AccountManager {
  static final Map<String, UserInfo> _userCache = {};

  static final ValueNotifier<List<String>> accountsNotifier =
      ValueNotifier<List<String>>([]);

  static Future<void> ensureAccountsLoaded() async {
    final list = await getAccountsList();
    accountsNotifier.value = List<String>.from(list);
  }

  static Future<UserInfo?> getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];

    final username = await getCurrentAccount();
    final token = await getToken(username ?? '');
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('$serverBase/user/$userId'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final info = UserInfo.fromJson(json);
        _userCache[userId] = info;
        return info;
      }
    } catch (e) {
      debugPrint('Failed to fetch user info for $userId: $e');
    }
    return null;
  }

  static void cacheUserInfo(UserInfo info) {
    _userCache[info.userId] = info;
  }

  static const String _currentAccountKey = 'current_account';
  static const String _accountsListKey = 'accounts_list';
  static const String _mediaProviderKey = 'media_provider';

  static Future<void> setMediaProvider(MediaProvider provider) async {
    await SecureStore.write(_mediaProviderKey, provider.name);
  }

  static Future<MediaProvider> getMediaProvider() async {
    final raw = await SecureStore.read(_mediaProviderKey);
    if (raw != null) {
      try {
        return MediaProvider.values.firstWhere((e) => e.name == raw);
      } catch (e) { debugPrint('[err] $e'); }
    }
    return MediaProvider.catbox;
  }

  static Future<void> setCurrentAccount(String? username) async {
    try {
      if (username == null) {
        await SecureStore.delete(_currentAccountKey);
      } else {
        await SecureStore.write(_currentAccountKey, username);
      }
    } catch (e) {
      debugPrint('[AccountManager] setCurrentAccount failed: $e');
    }

    if (username != null) {
      unawaited(touchLastUsed(username));
    }

    try {
      await SettingsManager.setAccountContext(username);
      
      try {
        await loadStatusSettings();
      } catch (e) {
        debugPrint('Failed to load status settings after account switch: $e');
      }
    } catch (e) {
      debugPrint('Failed to set account context in SettingsManager: $e');
    }
  }

  static Future<String?> getCurrentAccount() async {
    try {
      return await SecureStore.read(_currentAccountKey);
    } catch (e) {
      debugPrint('[AccountManager] getCurrentAccount failed: $e');
      return null;
    }
  }

  static Future<bool> get isLoggedIn async {
    final username = await getCurrentAccount();
    if (username == null) return false;
    final token = await getToken(username);
    return token != null;
  }

  static Future<List<String>> getAccountsList() async {
    try {
      final raw = await SecureStore.read(_accountsListKey);
      if (raw == null) return [];
      return raw.split('|').where((e) => e.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[AccountManager] getAccountsList failed: $e');
      return [];
    }
  }

  static Future<String> _metaFilePath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/accounts_meta_${_serverHost()}.json';
  }

  static Future<Map<String, Map<String, dynamic>>> _loadMeta() async {
    try {
      final file = File(await _metaFilePath());
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(k, (v as Map<String, dynamic>)));
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveMeta(
      Map<String, Map<String, dynamic>> meta) async {
    try {
      final path = await _metaFilePath();
      final tmp = File('$path.tmp');
      await tmp.writeAsString(jsonEncode(meta));
      await tmp.rename(path);
    } catch (e) {
      debugPrint('[AccountManager] _saveMeta: $e');
    }
  }

  static Future<void> touchLastUsed(String username) async {
    final meta = await _loadMeta();
    meta[username] = {
      ...?meta[username],
      'lastUsed': DateTime.now().toIso8601String(),
    };
    await _saveMeta(meta);
  }

  static Future<void> cacheDisplayName(
      String username, String displayName) async {
    if (displayName.isEmpty) return;
    final meta = await _loadMeta();
    
    final current = meta[username]?['displayName'] as String?;
    if (current == displayName) return;
    meta[username] = {
      ...?meta[username],
      'displayName': displayName,
    };
    await _saveMeta(meta);
  }

  static Future<Map<String, Map<String, dynamic>>> getAccountsMeta() =>
      _loadMeta();

  static Future<void> addAccount(String username) async {
    try {
      final list = await getAccountsList();
      if (!list.contains(username)) {
        list.add(username);
        await SecureStore.write(_accountsListKey, list.join('|'));
        accountsNotifier.value = List<String>.from(list);
      }
    } catch (e) {
      debugPrint('[AccountManager] addAccount failed: $e');
    }
  }

  static Future<void> removeAccount(String username) async {
    final list = await getAccountsList();
    if (list.contains(username)) {
      list.remove(username);
      await SecureStore.write(_accountsListKey, list.join('|'));

      for (final base in ['token', 'username', 'identity_priv_b64', 'identity_pub_b64', 'chats']) {
        try { await SecureStore.delete(_key(base, username)); } catch (e) { debugPrint('[err] $e'); }
        
        try { await SecureStore.delete('${base}_$username'); } catch (e) { debugPrint('[err] $e'); }
      }

      accountsNotifier.value = List<String>.from(list);
      debugPrint('[AccountManager] Removed all data for account: $username');
    }
  }

  static String _serverHost() {
    try {
      final uri = Uri.parse(serverBase);
      return uri.host.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    } catch (e) {
      return serverBase.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    }
  }

  static String _key(String base, String username) =>
      '${base}_${_serverHost()}_$username';

  static Future<void> saveToken(String username, String token) async {
    await SecureStore.write(_key('token', username), token);
    await SecureStore.write(
      _key('token_created_at', username),
      DateTime.now().toIso8601String(),
    );
  }

  static Future<String?> getToken(String username) async {
    return SecureStore.read(_key('token', username));
  }

  static Future<DateTime?> getTokenCreatedAt(String username) async {
    final raw = await SecureStore.read(_key('token_created_at', username));
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUsername(String username) async {
    await SecureStore.write(_key('username', username), username);
  }

  static Future<String?> getUsername(String username) async {
    return SecureStore.read(_key('username', username));
  }

  static Future<void> saveIdentity(
    String username,
    String privB64,
    String pubB64,
  ) async {
    await SecureStore.write(_key('identity_priv_b64', username), privB64);
    await SecureStore.write(_key('identity_pub_b64', username), pubB64);
  }

  static Future<Map<String, String>?> getIdentity(String username) async {
    final priv = await SecureStore.read(_key('identity_priv_b64', username));
    final pub = await SecureStore.read(_key('identity_pub_b64', username));
    if (priv != null && pub != null) return {'priv': priv, 'pub': pub};
    return null;
  }

  static Future<void> savePinnedDeviceFps(
    String myUsername,
    String peerUsername,
    Set<String> fps,
  ) async {
    final key = _key('pinned_fps_$peerUsername', myUsername);
    await SecureStore.write(key, jsonEncode(fps.toList()));
  }

  static Future<Set<String>?> getPinnedDeviceFps(
    String myUsername,
    String peerUsername,
  ) async {
    final raw = await SecureStore.read(_key('pinned_fps_$peerUsername', myUsername));
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveKnownPubkey(
    String myUsername,
    String peerUsername,
    String pubkey,
  ) async {
    await SecureStore.write(_key('known_pubkey_$peerUsername', myUsername), pubkey);
  }

  static Future<String?> getKnownPubkey(
    String myUsername,
    String peerUsername,
  ) async {
    return SecureStore.read(_key('known_pubkey_$peerUsername', myUsername));
  }

  static String _encodeChatIdFilename(String chatId) =>
      chatId.replaceAll('%', '%25').replaceAll(':', '%3A');

  static String _decodeChatIdFilename(String encoded) =>
      encoded.replaceAll('%3A', ':').replaceAll('%25', '%');

  static Future<Directory> _chatsDirFor(String username) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
        '${base.path}/chats_${_serverHost()}_$username');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _writeChatFile(
      Directory dir, String chatId, List<ChatMessage> messages) async {
    try {
      final filename = _encodeChatIdFilename(chatId);
      final file = File('${dir.path}/$filename.json');
      final tmp = File('${file.path}.tmp');
      final json = jsonEncode(messages.map((m) => m.toJson()).toList());
      await tmp.writeAsString(json);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('[AccountManager] _writeChatFile $chatId: $e');
    }
  }

  static Future<void> saveChats(
    String username,
    Map<String, List<ChatMessage>> chats,
  ) async {
    final dir = await _chatsDirFor(username);
    await Future.wait(chats.entries
        .map((e) => _writeChatFile(dir, e.key, e.value)));
    debugPrint(
        '[AccountManager] saveChats: saved ${chats.length} chat files for $username');
  }

  static Future<void> saveSingleChat(
    String username,
    String chatId,
    List<ChatMessage> messages,
  ) async {
    final dir = await _chatsDirFor(username);
    await _writeChatFile(dir, chatId, messages);
    debugPrint(
        '[AccountManager] saveSingleChat: saved $chatId (${messages.length} msgs) for $username');
  }

  static Future<void> deleteChatFile(
      String username, String chatId) async {
    try {
      final dir = await _chatsDirFor(username);
      final file = File(
          '${dir.path}/${_encodeChatIdFilename(chatId)}.json');
      if (await file.exists()) {
        await file.delete();
        debugPrint(
            '[AccountManager] deleteChatFile: deleted $chatId for $username');
      }
    } catch (e) {
      debugPrint('[AccountManager] deleteChatFile $chatId: $e');
    }
  }

  static Future<Map<String, List<ChatMessage>>> loadChats(
      String username) async {
    try {
      final dir = await _chatsDirFor(username);
      final result = <String, List<ChatMessage>>{};

      final entities = await dir
          .list()
          .where((e) =>
              e is File &&
              e.path.endsWith('.json') &&
              !e.path.endsWith('.tmp'))
          .toList();

      if (entities.isNotEmpty) {
        const batchSize = 8;
        for (var i = 0; i < entities.length; i += batchSize) {
          final batch = entities.skip(i).take(batchSize);
          final results = await Future.wait(batch.map((entity) async {
            final file = entity as File;
            final basename = file.path
                .split(Platform.pathSeparator)
                .last
                .replaceAll('.json', '');
            final chatId = _decodeChatIdFilename(basename);
            try {
              final raw = await file.readAsString();
              final arr = await compute(_parseJsonListInIsolate, raw);
              return MapEntry(chatId, arr
                  .cast<Map<String, dynamic>>()
                  .map(ChatMessage.fromJson)
                  .toList());
            } catch (e) {
              debugPrint(
                  '[AccountManager] loadChats: corrupt file $basename: $e');
              return null;
            }
          }));
          for (final entry in results) {
            if (entry != null) result[entry.key] = entry.value;
          }
        }
        debugPrint(
            '[AccountManager] loadChats: loaded ${result.length} chat files for $username');
        return result;
      }

      debugPrint(
          '[AccountManager] loadChats: no chat files found, trying legacy blob for $username');
      final newKey = _key('chats', username);
      String? raw = await SecureStore.read(newKey);
      raw ??= await SecureStore.read('chats_$username');

      if (raw == null) return {};

      final parsed = await compute(_parseJsonMapInIsolate, raw);
      parsed.forEach((chatId, arr) {
        try {
          result[chatId] = (arr as List)
              .cast<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList();
        } catch (e) { debugPrint('[err] $e'); }
      });

      if (result.isNotEmpty) {
        debugPrint(
            '[AccountManager] loadChats: migrating ${result.length} chats to per-file storage');
        await saveChats(username, result);
        
        try { await SecureStore.delete(newKey); } catch (e) { debugPrint('[err] $e'); }
      }

      debugPrint(
          '[AccountManager] loadChats: migrated ${result.length} chats for $username');
      return result;
    } catch (e) {
      debugPrint('Failed to load chats for $username: $e');
      return {};
    }
  }

  static Future<void> saveGroupsCache(
      String username, List<Group> groups) async {
    final dir = await getApplicationSupportDirectory();
    final file =
        File('${dir.path}/groups_cache_${_serverHost()}_$username.json');
    final jsonList = groups
        .map((g) => {
              'id': g.id,
              'name': g.name,
              'is_channel': g.isChannel,
              'owner': g.owner,
              'invite_link': g.inviteLink,
              'avatar_version': g.avatarVersion,
              'my_role': g.myRole,
            })
        .toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  static Future<List<Group>> loadGroupsCache(String username) async {
    final dir = await getApplicationSupportDirectory();
    final file =
        File('${dir.path}/groups_cache_${_serverHost()}_$username.json');
    
    final legacy = File('${dir.path}/groups_cache_$username.json');
    if (!await file.exists() && await legacy.exists()) {
      try {
        final contents = await legacy.readAsString();
        await file.writeAsString(contents);
        await legacy.delete();
        debugPrint(
            '[AccountManager] migrate: groups_cache migrated for $username');
      } catch (e) {
      debugPrint('[err] $e');
    }
    }
    if (!await file.exists()) return [];
    try {
      final contents = await file.readAsString();

      final jsonList = await compute(_parseJsonListInIsolate, contents);

      return jsonList
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveGroupHistory(
      String username, int groupId, List<Map<String, dynamic>> messages) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
        '${dir.path}/group_history_${_serverHost()}_${username}_$groupId.json');
    await file.writeAsString(jsonEncode(messages));
  }

  static Future<List<Map<String, dynamic>>> loadGroupHistory(
      String username, int groupId) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
        '${dir.path}/group_history_${_serverHost()}_${username}_$groupId.json');
    final legacy = File('${dir.path}/group_history_${username}_$groupId.json');
    if (!await file.exists() && await legacy.exists()) {
      try {
        final contents = await legacy.readAsString();
        await file.writeAsString(contents);
        await legacy.delete();
        debugPrint(
            '[AccountManager] migrate: group_history migrated for $username group=$groupId');
      } catch (e) {
      debugPrint('[err] $e');
    }
    }
    if (!await file.exists()) return [];
    try {
      final contents = await file.readAsString();
      final jsonList = jsonDecode(contents) as List;
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static Future<void> loadStatusSettings() async {
    try {
      final username = await getCurrentAccount();
      if (username == null) return;

      await SettingsManager.setAccountContext(username);

      final token = await getToken(username);
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$serverBase/me/status-settings'),
        headers: {'authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        if (SettingsManager.statusVisibility.value == 'show') {
          await SettingsManager.setStatusVisibility(data['status_visibility'] ?? 'show');
        }
        if (SettingsManager.statusOnline.value == 'online') {
          await SettingsManager.setStatusOnline(data['status_online'] ?? 'online');
        }
        if (SettingsManager.statusOffline.value == 'offline') {
          await SettingsManager.setStatusOffline(data['status_offline'] ?? 'offline');
        }
        debugPrint(' Status settings loaded from server (applied where local defaults existed)');
      }
    } catch (e) {
      debugPrint(' Failed to load status settings: $e');
    }
  }
}