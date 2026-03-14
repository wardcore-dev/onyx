// lib/managers/external_server_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart' as cry;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/external_server.dart';
import '../models/group.dart';
import '../managers/account_manager.dart';
import '../managers/secure_store.dart';

List<Group> _parseGroupsJson(String json) {
  final list = jsonDecode(json) as List<dynamic>;
  return list.map((j) => Group.fromJson(j as Map<String, dynamic>)).toList();
}

class ExternalServerManager {
  static const _serversKey = 'external_servers';
  static const _groupsKey = 'external_groups';

  static final ValueNotifier<List<ExternalServer>> servers = ValueNotifier([]);

  static final Map<String, WebSocketChannel> _wsConnections = {};
  static final Map<String, StreamSubscription> _wsSubscriptions = {};

  static final Map<String, void Function(Map<String, dynamic>)> _groupListeners = {};

  static final ValueNotifier<List<Group>> externalGroups = ValueNotifier([]);

  static final ValueNotifier<Set<String>> connectedServerIds = ValueNotifier({});

  static bool isServerConnected(String serverId) {
    final connected = _wsConnections.containsKey(serverId);
    debugPrint('[ext-ws] isServerConnected($serverId): $connected (total connections: ${_wsConnections.length})');
    return connected;
  }

  static Future<void> loadServers() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) return;
    final key = '${_serversKey}_$username';
    String? json;
    try {
      json = await SecureStore.read(key);
    } catch (e) {
      debugPrint('[ext-servers] read failed: $e');
    }
    if (json != null && json.isNotEmpty) {
      final loadedServers = ExternalServer.decodeList(json);
      servers.value = loadedServers;
    } else {
      servers.value = [];
    }
    
    await _loadGroups();
  }

  static Future<void> _loadGroups() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) return;
    final key = '${_groupsKey}_$username';
    String? json;
    try {
      json = await SecureStore.read(key);
    } catch (e) {
      debugPrint('[ext-groups] read failed: $e');
    }
    if (json != null && json.isNotEmpty) {
      try {
        
        final loadedGroups = await compute(_parseGroupsJson, json);
        externalGroups.value = loadedGroups;
        debugPrint('[ext-groups] Loaded ${loadedGroups.length} cached groups');
      } catch (e) {
        debugPrint('[ext-groups] Failed to load cached groups: $e');
        externalGroups.value = [];
      }
    } else {
      externalGroups.value = [];
    }
  }

  static Future<void> _saveGroups() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) return;
    final key = '${_groupsKey}_$username';
    try {
      final list = externalGroups.value.map((g) => g.toJson()).toList();
      final json = jsonEncode(list);
      await SecureStore.write(key, json);
      debugPrint('[ext-groups] Saved ${externalGroups.value.length} groups to cache');
    } catch (e) {
      debugPrint('[ext-groups] Failed to save groups: $e');
    }
  }

  static Future<void> _saveServers() async {
    final username = await AccountManager.getCurrentAccount();
    if (username == null) return;
    final key = '${_serversKey}_$username';
    final json = ExternalServer.encodeList(servers.value);
    try {
      await SecureStore.write(key, json);
    } catch (e) {
      debugPrint('[ext-servers] write failed: $e');
    }
  }

  static Future<void> saveServers() async {
    await _saveServers();
  }

  static Future<String> _derivePasswordHash(
    String password,
    String host,
    int port,
    String username,
  ) async {
    final pbkdf2 = cry.Pbkdf2(
      macAlgorithm: cry.Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    final salt = utf8.encode('ext:$host:$port:$username');
    final secretKey = await pbkdf2.deriveKey(
      secretKey: cry.SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final bytes = await secretKey.extractBytes();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<Map<String, dynamic>> fetchServerInfo(String host, int port) async {
    final url = Uri.parse('http://$host:$port/info');
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Server returned ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<ExternalServer> registerOnServer({
    required String host,
    required int port,
    required String username,
    required String displayName,
    String password = '',
    required Map<String, dynamic> serverInfo,
  }) async {
    
    final random = Random.secure();
    final pubKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final privKeyBytes = List<int>.generate(64, (_) => random.nextInt(256));
    final publicKey = base64Encode(pubKeyBytes);
    final privateKey = base64Encode(privKeyBytes);

    final existingServer = servers.value.firstWhere(
      (s) => s.host == host && s.port == port,
      orElse: () => ExternalServer(
        id: '',
        host: '',
        port: 0,
        name: '',
        description: '',
        username: '',
        displayName: '',
        publicKey: '',
        privateKey: '',
        token: '',
        passwordHash: '',
        mediaProvider: 'local',
        maxFileSizeMb: 50,
        maxMembersPerGroup: 500,
        features: [],
        joinedAt: DateTime.now(),
      ),
    );

    final passwordHash = existingServer.id.isNotEmpty && existingServer.passwordHash.isNotEmpty
        ? existingServer.passwordHash  
        : (password.isNotEmpty
            ? await _derivePasswordHash(password, host, port, username)
            : '');

    final baseUrl = 'http://$host:$port';

    final resp = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'display_name': displayName,
        'public_key': publicKey,
        'password_hash': passwordHash,  
      }),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['error'] ?? 'Registration failed (${resp.statusCode})');
    }

    final result = jsonDecode(resp.body);
    final token = result['token'] as String;

    final serverId = existingServer.id.isNotEmpty ? existingServer.id : _generateId();

    final server = ExternalServer(
      id: serverId,
      host: host,
      port: port,
      name: serverInfo['group_name'] ?? serverInfo['name'] ?? 'Unknown',
      description: serverInfo['group_description'] ?? serverInfo['description'] ?? '',
      username: username,
      displayName: displayName,
      publicKey: publicKey,
      privateKey: privateKey,
      token: token,
      passwordHash: passwordHash,
      mediaProvider: serverInfo['media_provider'] ?? 'local',
      maxFileSizeMb: serverInfo['max_file_size_mb'] ?? 50,
      maxMembersPerGroup: serverInfo['max_members_per_group'] ?? 500,
      features: (serverInfo['features'] as List<dynamic>?)?.cast<String>() ?? [],
      joinedAt: existingServer.id.isNotEmpty ? existingServer.joinedAt : DateTime.now(),
    );

    if (existingServer.id.isNotEmpty) {
      
      servers.value = servers.value.map((s) => s.id == serverId ? server : s).toList();
      debugPrint('[ext-register] Updated existing server: ${server.name} (${server.id})');
    } else {
      
      servers.value = [...servers.value, server];
      debugPrint('[ext-register] Added new server: ${server.name} (${server.id})');
    }

    await _saveServers();
    return server;
  }

  static Future<String?> reAuthenticate(String serverId) async {
    final server = _getServer(serverId);
    if (server == null) return null;

    if (server.username.isEmpty || server.publicKey.isEmpty) {
      debugPrint('[ext-reauth] skipped - no credentials stored');
      return null;
    }

    try {
      final resp = await http.post(
        Uri.parse('${server.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': server.username,
          'display_name': server.displayName,
          'public_key': server.publicKey,
          'password_hash': server.passwordHash,  
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        debugPrint('[ext-reauth] failed ${resp.statusCode}: ${resp.body}');
        return null;
      }

      final result = jsonDecode(resp.body);
      final newToken = result['token'] as String;

      final updated = server.copyWith(token: newToken);
      servers.value = servers.value.map((s) => s.id == serverId ? updated : s).toList();
      await _saveServers();

      disconnectWebSocket(serverId);
      await connectWebSocket(serverId);

      debugPrint('[ext-reauth] success for ${server.username}@${server.host}');
      return newToken;
    } catch (e) {
      debugPrint('[ext-reauth] error: $e');
      return null;
    }
  }

  static Future<http.Response> _authRequest(
    String serverId,
    Future<http.Response> Function(String token) request,
  ) async {
    final server = _getServer(serverId);
    if (server == null) throw Exception('Server not found');

    var resp = await request(server.token);
    if (resp.statusCode == 401) {
      debugPrint('[ext-auth] got 401, re-authenticating...');
      final newToken = await reAuthenticate(serverId);
      if (newToken != null) {
        resp = await request(newToken);
      }
    }
    return resp;
  }

  static String addTokenToUrl(String url) {
    try {
      final uri = Uri.parse(url);
      for (final server in servers.value) {
        if (server.host == uri.host && server.port == uri.port) {
          final sep = url.contains('?') ? '&' : '?';
          return '$url${sep}token=${Uri.encodeComponent(server.token)}';
        }
      }
    } catch (e) { debugPrint('[err] $e'); }
    return url;
  }

  static Future<void> removeServer(String serverId) async {
    disconnectWebSocket(serverId);
    servers.value = servers.value.where((s) => s.id != serverId).toList();
    externalGroups.value = externalGroups.value.where((g) => g.externalServerId != serverId).toList();
    await _saveServers();
    await _saveGroups();
  }

  static Future<List<Group>> fetchGroups(String serverId) async {
    final server = _getServer(serverId);
    if (server == null) return [];

    debugPrint('[ext-groups] Fetching groups for server: ${server.name}');

    if (server.token.startsWith('public:')) {
      final publicToken = server.token.substring('public:'.length);
      final url = '${server.baseUrl}/channels/$publicToken';

      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) {
          debugPrint('[ext-groups] Public channel fetch failed: ${resp.statusCode}');
          return [];
        }

        final channelInfo = jsonDecode(resp.body) as Map<String, dynamic>;

        final group = Group(
          id: 1, 
          name: channelInfo['name'] ?? 'Public Channel',
          isChannel: true,
          owner: channelInfo['owner'] ?? '',
          inviteLink: '',
          avatarVersion: channelInfo['avatar_version'] ?? 0,
          externalServerId: serverId,
          myRole: null, 
        );

        debugPrint('[ext-groups] Public channel: ${group.name}');
        return [group];
      } catch (e) {
        debugPrint('[ext-groups] Public channel error: $e');
        return [];
      }
    }

    final resp = await _authRequest(serverId, (token) =>
      http.get(
        Uri.parse('${server.baseUrl}/groups'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10)),
    );

    if (resp.statusCode != 200) {
      debugPrint('[ext-groups] Failed to fetch groups: ${resp.statusCode}');
      return [];
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    debugPrint('[ext-groups] Received ${list.length} groups from server');
    return list.map((j) {
      final map = j as Map<String, dynamic>;
      map['external_server_id'] = serverId;
      final group = Group.fromJson(map);
      debugPrint('[ext-groups] Group: ${group.name}, isChannel: ${group.isChannel}, myRole: ${group.myRole}');
      return group;
    }).toList();
  }

  static Future<void> refreshAllExternalGroups() async {
    final allGroups = <Group>[];
    final seen = <String>{};
    for (final server in servers.value) {
      try {
        final groups = await fetchGroups(server.id);
        for (final g in groups) {
          final key = '${g.externalServerId}:${g.id}';
          if (seen.add(key)) {
            allGroups.add(g);
          }
        }
      } catch (e) {
        
        for (final g in externalGroups.value) {
          if (g.externalServerId == server.id) {
            final key = '${g.externalServerId}:${g.id}';
            if (seen.add(key)) {
              allGroups.add(g);
            }
          }
        }
      }
    }
    externalGroups.value = allGroups;
    
    await _saveGroups();
  }

  static Future<List<Map<String, dynamic>>> fetchHistory(
    String serverId, int groupId, {int? beforeId, int limit = 50}
  ) async {
    final server = _getServer(serverId);
    if (server == null) return [];

    if (server.token.startsWith('public:')) {
      final publicToken = server.token.substring('public:'.length);
      final beforeParam = beforeId != null ? '&before_id=$beforeId' : '';
      final url = '${server.baseUrl}/channels/$publicToken/history?limit=$limit$beforeParam';

      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) {
          debugPrint('[ext-history] public channel fetch failed ${resp.statusCode}');
          return [];
        }
        return (jsonDecode(resp.body) as List<dynamic>).cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('[ext-history] public channel error: $e');
        return [];
      }
    }

    var url = '${server.baseUrl}/history?limit=$limit';
    if (beforeId != null) url += '&before_id=$beforeId';

    final resp = await _authRequest(serverId, (token) =>
      http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10)),
    );

    if (resp.statusCode != 200) return [];
    return (jsonDecode(resp.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>?> sendMessage(
    String serverId, int groupId, String content, {
    int? replyToId, String? replyToSender, String? replyToContent,
  }) async {
    final server = _getServer(serverId);
    if (server == null) {
      debugPrint('[ext-send] server not found: $serverId');
      return null;
    }

    if (server.token.startsWith('public:')) {
      debugPrint('[ext-send] Cannot send to public channel (read-only)');
      return null;
    }

    final url = '${server.baseUrl}/send';
    debugPrint('[ext-send] POST $url (token=${server.token.substring(0, min(8, server.token.length))}...)');

    final resp = await _authRequest(serverId, (token) =>
      http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
          if (replyToId != null) 'reply_to_id': replyToId,
          if (replyToSender != null) 'reply_to_sender': replyToSender,
          if (replyToContent != null) 'reply_to_content': replyToContent,
        }),
      ).timeout(const Duration(seconds: 10)),
    );

    if (resp.statusCode != 200) {
      debugPrint('[ext-send] FAILED ${resp.statusCode}: ${resp.body}');
      return null;
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<bool> joinGroup(String serverId, String inviteToken) async {
    final server = _getServer(serverId);
    if (server == null) return false;

    final resp = await _authRequest(serverId, (token) =>
      http.post(
        Uri.parse('${server.baseUrl}/groups/join/$inviteToken'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10)),
    );

    return resp.statusCode == 200;
  }

  static Future<bool> leaveGroup(String serverId, int groupId) async {
    final server = _getServer(serverId);
    if (server == null) return false;

    final resp = await _authRequest(serverId, (token) =>
      http.post(
        Uri.parse('${server.baseUrl}/groups/$groupId/leave'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10)),
    );

    return resp.statusCode == 200;
  }

  static Future<bool> connectWebSocket(String serverId) async {
    final server = _getServer(serverId);
    if (server == null) {
      debugPrint('[ext-ws] Server not found: $serverId');
      return false;
    }

    if (_wsConnections.containsKey(serverId)) {
      debugPrint('[ext-ws] Already connected to: $serverId');
      return true; 
    }

    try {
      final wsUri = Uri.parse(server.wsUrl);
      debugPrint('[ext-ws] Connecting to WebSocket: ${server.wsUrl}');

      final ws = WebSocketChannel.connect(wsUri);
      _wsConnections[serverId] = ws;

      final connectionEstablished = Completer<bool>();
      bool completed = false;

      _wsSubscriptions[serverId] = ws.stream.listen(
        (event) {
          if (!completed) {
            completed = true;
            debugPrint('[ext-ws] $serverId connection confirmed via first message');
            connectedServerIds.value = {...connectedServerIds.value, serverId};
            connectionEstablished.complete(true);
          }
          debugPrint('[ext-ws] $serverId received message');
          _handleWsMessage(serverId, event);
        },
        onError: (e) {
          debugPrint('[ext-ws] $serverId error: $e');
          if (!completed) {
            completed = true;
            connectionEstablished.complete(false);
          }
          _cleanupWs(serverId);
        },
        onDone: () {
          debugPrint('[ext-ws] $serverId disconnected');
          if (!completed) {
            completed = true;
            connectionEstablished.complete(false);
          }
          _cleanupWs(serverId);
        },
      );

      final result = await connectionEstablished.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          debugPrint('[ext-ws] $serverId connection timeout');
          
          if (!completed) {
            completed = true;
            connectedServerIds.value = {...connectedServerIds.value, serverId};
            debugPrint('[ext-ws] $serverId assumed connected after timeout (no errors)');
            return true;
          }
          return false;
        },
      );

      debugPrint('[ext-ws] $serverId connection result: $result');
      return result;
    } catch (e) {
      debugPrint('[ext-ws] $serverId connect failed: $e');
      _cleanupWs(serverId);
      return false;
    }
  }

  static void disconnectWebSocket(String serverId) {
    debugPrint('[ext-ws] Disconnecting WebSocket for $serverId');

    final keysToRemove = _groupListeners.keys.where((key) => key.startsWith('$serverId:')).toList();
    for (final key in keysToRemove) {
      _groupListeners.remove(key);
      debugPrint('[ext-ws] Removed group listener on disconnect: $key');
    }

    _wsSubscriptions[serverId]?.cancel();
    _wsSubscriptions.remove(serverId);
    try {
      _wsConnections[serverId]?.sink.close();
    } catch (e) { debugPrint('[err] $e'); }
    _wsConnections.remove(serverId);
    connectedServerIds.value = connectedServerIds.value.where((id) => id != serverId).toSet();
    debugPrint('[ext-ws] Disconnected from $serverId');
  }

  static Future<void> connectAll() async {
    for (final server in servers.value) {
      await connectWebSocket(server.id);
    }
  }

  static void disconnectAll() {
    for (final id in _wsConnections.keys.toList()) {
      disconnectWebSocket(id);
    }
  }

  static Future<void> reconnectIfNeeded() async {
    final previouslyConnected = connectedServerIds.value.toSet();
    
    for (final serverId in previouslyConnected) {
      if (!_wsConnections.containsKey(serverId)) {
        debugPrint('[ext-ws] reconnecting $serverId after rebuild');
        
        connectedServerIds.value = connectedServerIds.value.where((id) => id != serverId).toSet();
        await connectWebSocket(serverId);
      }
    }
  }

  static void subscribeToGroup(String serverId, int groupId, void Function(Map<String, dynamic>) listener) {
    final key = '$serverId:$groupId';
    _groupListeners[key] = listener;
    debugPrint('[ext-ws] Subscribing to group: $key');
    
    final ws = _wsConnections[serverId];
    if (ws != null) {
      final msg = jsonEncode({'type': 'subscribe_group', 'group_id': groupId});
      ws.sink.add(msg);
      debugPrint('[ext-ws] Sent subscribe_group message for $key');
    } else {
      debugPrint('[ext-ws] WARNING: No WebSocket connection for $serverId, cannot subscribe to group $groupId');
    }
  }

  static void unsubscribeFromGroup(String serverId, int groupId) {
    final key = '$serverId:$groupId';
    _groupListeners.remove(key);
    debugPrint('[ext-ws] Unsubscribed from group: $key');
    final ws = _wsConnections[serverId];
    if (ws != null) {
      ws.sink.add(jsonEncode({'type': 'unsubscribe_group', 'group_id': groupId}));
      debugPrint('[ext-ws] Sent unsubscribe_group message for $key');
    } else {
      debugPrint('[ext-ws] WARNING: No WebSocket connection for $serverId, cannot send unsubscribe message');
    }
  }

  static void _handleWsMessage(String serverId, dynamic event) {
    try {
      final obj = jsonDecode(event as String) as Map<String, dynamic>;
      final type = obj['type'] as String?;
      debugPrint('[ext-ws] Message type: $type');

      if (type == 'init_complete') {
        debugPrint('[ext-ws] $serverId: WebSocket initialized');
        final isReadonly = obj['readonly'] == true;
        if (isReadonly) {
          debugPrint('[ext-ws] $serverId: Connected in read-only mode (public channel)');
        }
      } else if (type == 'group_msg' ||
                 type == 'group_msg_edited' ||
                 type == 'group_msg_deleted') {
        final groupId = obj['group_id'] as int;
        final key = '$serverId:$groupId';
        debugPrint('[ext-ws] Received $type for $key');
        final listener = _groupListeners[key];
        if (listener != null) {
          listener(obj);
        } else {
          debugPrint('[ext-ws] WARNING: No listener for $key');
        }
      } else if (type == 'group_joined' || type == 'group_member_left') {
        debugPrint('[ext-ws] Group membership changed: $type');
        refreshAllExternalGroups();
      } else if (type == 'group_updated') {
        debugPrint('[ext-ws] Group name updated');
        final groupId = obj['group_id'];
        final newName = obj['name']?.toString();
        if (groupId != null && newName != null) {
          _updateGroupInList(serverId, groupId, name: newName);
        }
      } else if (type == 'group_avatar_updated') {
        debugPrint('[ext-ws] Group avatar updated');
        final groupId = obj['group_id'];
        final newVersion = obj['avatar_version'];
        if (groupId != null && newVersion != null) {
          final parsedVersion = newVersion is int ? newVersion : int.tryParse(newVersion.toString()) ?? 0;
          _updateGroupInList(serverId, groupId, avatarVersion: parsedVersion);
        }
      } else if (type == 'pong') {
        debugPrint('[ext-ws] $serverId: pong received');
      } else if (type == 'error') {
        debugPrint('[ext-ws] $serverId: Error from server: ${obj['message']}');
      }
    } catch (e) {
      debugPrint('[ext-ws] parse error: $e');
    }
  }

  static void _updateGroupInList(String serverId, int groupId, {String? name, int? avatarVersion}) {
    final currentGroups = externalGroups.value;
    final updatedGroups = currentGroups.map((g) {
      if (g.id == groupId && g.externalServerId == serverId) {
        return Group(
          id: g.id,
          name: name ?? g.name,
          isChannel: g.isChannel,
          owner: g.owner,
          inviteLink: g.inviteLink,
          avatarVersion: avatarVersion ?? g.avatarVersion,
          externalServerId: g.externalServerId,
          myRole: g.myRole,
        );
      }
      return g;
    }).toList();
    externalGroups.value = updatedGroups;
    debugPrint('[ext-ws] Updated group $groupId in list (name: $name, avatarVersion: $avatarVersion)');
  }

  static void _cleanupWs(String serverId) {
    debugPrint('[ext-ws] Cleaning up WebSocket for $serverId');

    final keysToRemove = _groupListeners.keys.where((key) => key.startsWith('$serverId:')).toList();
    for (final key in keysToRemove) {
      _groupListeners.remove(key);
      debugPrint('[ext-ws] Removed group listener: $key');
    }

    _wsSubscriptions.remove(serverId);
    _wsConnections.remove(serverId);
    connectedServerIds.value = connectedServerIds.value.where((id) => id != serverId).toSet();
    debugPrint('[ext-ws] After cleanup: ${connectedServerIds.value.length} connections remaining');
  }

  static ExternalServer? _getServer(String serverId) {
    try {
      return servers.value.firstWhere((s) => s.id == serverId);
    } catch (e) {
      return null;
    }
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}