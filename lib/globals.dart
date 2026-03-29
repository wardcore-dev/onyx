// lib/globals.dart
import 'package:ONYX/screens/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'models/chat_message.dart';
import 'managers/account_manager.dart';
import 'screens/root_screen.dart'; 

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Maps message filename/key → local cached file path for video/voice/file messages.
final Map<String, String> mediaFilePathRegistry = {};

final GlobalKey<RootScreenState> rootScreenKey = GlobalKey<RootScreenState>();
final ValueNotifier<int> chatsVersion = ValueNotifier<int>(0);
Map<int, List<Map<String, dynamic>>> _groupChats = {};
Map<int, List<Map<String, dynamic>>> get groupChats => _groupChats;

final ValueNotifier<Map<int, int>> groupChatsVersion = ValueNotifier<Map<int, int>>({});

final ValueNotifier<bool> recordingNotifier = ValueNotifier<bool>(false);
final ValueNotifier<bool> wsConnectedNotifier = ValueNotifier<bool>(false);

final ValueNotifier<bool> proxyActiveNotifier = ValueNotifier<bool>(false);
final ValueNotifier<Set<String>> onlineUsersNotifier = ValueNotifier(
  <String>{},
);
final ValueNotifier<Set<String>> typingUsersNotifier = ValueNotifier(
  <String>{},
);

final ValueNotifier<Map<String, String>> userStatusNotifier = ValueNotifier(
  <String, String>{},
);

final ValueNotifier<Map<String, String>> userStatusVisibilityNotifier = ValueNotifier(
  <String, String>{},
);

final ValueNotifier<int> avatarVersion = ValueNotifier(0);

final ValueNotifier<Map<int, int>> groupAvatarVersion = ValueNotifier({});

final ValueNotifier<int> favoritesVersion = ValueNotifier<int>(0);

final ValueNotifier<int> groupsVersion = ValueNotifier<int>(0);

final ValueNotifier<int> accountSwitchVersion = ValueNotifier<int>(0);

final ValueNotifier<Map<String, bool>> lanModePerChat = ValueNotifier<Map<String, bool>>({});

/// ChatIds whose summaries changed since the last chatsVersion bump.
/// ChatsTab reads this in _onChatsVersion to decide whether to do an incremental
/// or full rebuild. Set is consumed (cleared) by ChatsTab after reading.
final Set<String> _pendingChatListHints = {};

void addChatListHint(String chatId) => _pendingChatListHints.add(chatId);

/// Returns the pending hints and clears them atomically (called from the main isolate).
Set<String> consumeChatListHints() {
  if (_pendingChatListHints.isEmpty) return const {};
  final copy = Set<String>.from(_pendingChatListHints);
  _pendingChatListHints.clear();
  return copy;
}

// Per-chat message version notifiers — each ChatScreen listens only to its own chat.
final Map<String, ValueNotifier<int>> _chatMessageVersions = {};

ValueNotifier<int> getChatMessageVersion(String chatId) {
  return _chatMessageVersions.putIfAbsent(chatId, () => ValueNotifier<int>(0));
}

void bumpChatMessageVersion(String chatId) {
  getChatMessageVersion(chatId).value++;
}

final Map<String, Widget> _favoritesScreenCache = {};

Widget getFavoritesScreen(String id, String title) {
  return _favoritesScreenCache.putIfAbsent(
    id,
    () => FavoritesScreen(favoriteId: id, title: title),
  );
}

Map<String, List<ChatMessage>> _chats = {};
double _chatsPanelWidth = 300.0;

const String serverBase = 'https://api-onyx.wardcore.com';
const String wsUrl = 'wss://api-onyx.wardcore.com/ws';
const String publicIpApi = 'https://api.ipify.org';


const String kAppVersion = 'v1.2-beta';

bool get isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

Future<String?> avatarTokenProvider() async {
  final current = await AccountManager.getCurrentAccount();
  if (current == null) return null;
  return await AccountManager.getToken(current);
}

Map<String, List<ChatMessage>> get chats => _chats;
set chats(Map<String, List<ChatMessage>> value) => _chats = value;
double get chatsPanelWidth => _chatsPanelWidth;
set chatsPanelWidth(double value) => _chatsPanelWidth = value;

void unawaited(Future<dynamic> future) {
  
  future.catchError((_) {});
}