// lib/globals.dart
import 'dart:async';
import 'package:ONYX/screens/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'models/chat_message.dart';
import 'managers/account_manager.dart';
import 'screens/root_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// Root navigator key — used by widgets that live above the Navigator in the
/// widget tree (e.g. VinylPlayerButton in MaterialApp.builder) to open modals.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Maps message filename/key → local cached file path for video/voice/file messages.
final Map<String, String> mediaFilePathRegistry = {};

// Monotonic counter appended to locally-generated message ids. On some
// platforms `DateTime.now().microsecondsSinceEpoch` doesn't actually have
// microsecond resolution (it can repeat within the same millisecond), so a
// tight loop — e.g. forwarding several messages back-to-back — could hand out
// the same id to more than one message. Duplicate ids become duplicate
// ValueKeys in the message ListView, which crashes the Sliver rendering code
// and makes every message but one disappear from the list. Appending a
// process-local counter guarantees every call returns a unique id.
int _localMessageIdCounter = 0;

/// Generates a locally-unique message id, safe to call any number of times
/// in the same event-loop tick (e.g. a batch-forward loop) without collision.
String generateLocalMessageId() {
  _localMessageIdCounter = (_localMessageIdCounter + 1) & 0x7fffffff;
  return '${DateTime.now().microsecondsSinceEpoch}_$_localMessageIdCounter';
}

final GlobalKey<RootScreenState> rootScreenKey = GlobalKey<RootScreenState>();
final ValueNotifier<int> chatsVersion = ValueNotifier<int>(0);
Map<int, List<Map<String, dynamic>>> _groupChats = {};
Map<int, List<Map<String, dynamic>>> get groupChats => _groupChats;

final ValueNotifier<Map<int, int>> groupChatsVersion =
    ValueNotifier<Map<int, int>>({});

final ValueNotifier<bool> recordingNotifier = ValueNotifier<bool>(false);

/// Normalized (0..1) live mic input level while `recordingNotifier` is true —
/// polled from the active AudioRecorder in RootScreenState.startRecording()
/// so voice UI (e.g. the recording glow/waveform on ChatInputBar) can react
/// to actual loudness instead of a fixed timer. Always 0 while not recording.
final ValueNotifier<double> recordingLevelNotifier = ValueNotifier<double>(0.0);
final ValueNotifier<bool> wsConnectedNotifier = ValueNotifier<bool>(false);
final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier<bool>(false);

final ValueNotifier<bool> proxyActiveNotifier = ValueNotifier<bool>(false);

/// True while the PIN/biometric lock gate is blocking the UI — either the
/// initial app-launch lock screen, or the resume-lock screen main.dart pushes
/// onto [navigatorKey] after the app comes back from the background with
/// "lock on resume" enabled. Notification-driven navigation (RootScreen's
/// openChatStream/openReminderStream listeners) awaits [waitForAppUnlock]
/// before pushing a chat route, since both routes share the same Navigator
/// and pushing the chat first just gets it buried under the lock screen
/// pushed moments later by the independent app-lifecycle callback.
final ValueNotifier<bool> appLockActive = ValueNotifier<bool>(false);

/// Resolves immediately if the app isn't currently lock-gated, otherwise
/// waits for [appLockActive] to clear (bounded so a stuck/unexpected lock
/// state can't strand a notification tap forever).
Future<void> waitForAppUnlock() {
  if (!appLockActive.value) return Future.value();
  final completer = Completer<void>();
  void listener() {
    if (!appLockActive.value) {
      appLockActive.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    }
  }
  appLockActive.addListener(listener);
  return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
    appLockActive.removeListener(listener);
  });
}

/// A notification-tap navigation stashed by RootScreen because the app was
/// (or was about to be) PIN-locked when the tap arrived. main.dart's PinGate
/// runs and clears this the instant the user successfully unlocks — so the
/// chat opens right after PIN entry instead of depending on [waitForAppUnlock]
/// alone to win its race against the lock screen being pushed.
Future<void> Function()? pendingUnlockNavigation;

/// Username of the DM a notification tap most recently targeted. Set the
/// instant the tap is observed (regardless of lock state) so ChatsTab can
/// surface that conversation with a highlight — a fallback that still lands
/// the user somewhere useful if the forced auto-navigation into ChatScreen
/// (via [pendingUnlockNavigation]) loses its race with the PIN lock screen
/// or an unreliable OS-level notification-tap delivery. Cleared once the
/// target chat is actually opened, by whichever path got there first.
final ValueNotifier<String?> pendingHighlightChat = ValueNotifier<String?>(null);

/// Runs and clears [pendingUnlockNavigation], if one was stashed. Safe to
/// call unconditionally after every successful unlock.
Future<void> runPendingUnlockNavigation() async {
  final action = pendingUnlockNavigation;
  pendingUnlockNavigation = null;
  debugPrint('[lock] runPendingUnlockNavigation: '
      '${action != null ? "firing stashed navigation" : "nothing stashed"}');
  if (action != null) await action();
}

/// True while a tab's "pull to search" panel (TabPullSearchOverlay) is open
/// and focused — used to hide the floating bottom nav bar so it doesn't end
/// up overlapping the panel/keyboard once the Scaffold resizes for the IME.
final ValueNotifier<bool> tabPullSearchOpen = ValueNotifier<bool>(false);
final ValueNotifier<Set<String>> onlineUsersNotifier = ValueNotifier(
  <String>{},
);
final ValueNotifier<Set<String>> typingUsersNotifier = ValueNotifier(
  <String>{},
);

final ValueNotifier<Map<String, String>> userStatusNotifier = ValueNotifier(
  <String, String>{},
);

final ValueNotifier<Map<String, String>> userStatusVisibilityNotifier =
    ValueNotifier(
  <String, String>{},
);

final ValueNotifier<int> avatarVersion = ValueNotifier(0);

final ValueNotifier<Map<int, int>> groupAvatarVersion = ValueNotifier({});

final ValueNotifier<int> favoritesVersion = ValueNotifier<int>(0);

final ValueNotifier<int> groupsVersion = ValueNotifier<int>(0);

// Incremented by groups_tab after a successful network sync (cache updated).
// The graph listens to this; groups_tab does NOT — avoids infinite reload loop.
final ValueNotifier<int> groupsCacheVersion = ValueNotifier<int>(0);

final ValueNotifier<int> accountSwitchVersion = ValueNotifier<int>(0);

final ValueNotifier<Map<String, bool>> lanModePerChat =
    ValueNotifier<Map<String, bool>>({});

/// Chat key + message id that the next opened chat screen should scroll to
/// and highlight — set right before navigating from a content-match search
/// result so the chat opens scrolled to the matched message instead of the
/// bottom. Each chat screen consumes (and clears) this in initState by
/// matching its own chat key (e.g. `_chatId`, `'fav:<id>'`, `'native:<id>'`).
String? _pendingScrollChatKey;
String? _pendingScrollMessageId;

void setPendingMessageScrollTarget(String chatKey, String messageId) {
  _pendingScrollChatKey = chatKey;
  _pendingScrollMessageId = messageId;
}

/// Returns and clears the pending scroll target if it belongs to [chatKey].
String? consumePendingMessageScrollTarget(String chatKey) {
  if (_pendingScrollChatKey != chatKey) return null;
  final id = _pendingScrollMessageId;
  _pendingScrollChatKey = null;
  _pendingScrollMessageId = null;
  return id;
}

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

const String kAppVersion = 'v1.10-beta';

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
