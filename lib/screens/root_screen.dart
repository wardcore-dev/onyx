// lib/screens/root_screen.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ONYX/background/background_worker.dart';
import 'package:ONYX/background/notification_service.dart';
import 'package:ONYX/background/register_sync.dart';
import 'package:ONYX/models/favorite_chat.dart';
import 'package:ONYX/models/fav_folder.dart';
import 'package:ONYX/services/backup/backup_service.dart';
import 'package:ONYX/screens/favorites_tab.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../managers/secure_store.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxDocumentsDirectory, getOnyxSupportDirectory;
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:convert/convert.dart';
import 'package:window_manager/window_manager.dart';
import '../managers/external_server_manager.dart';
import '../models/external_server.dart';
import 'package:path/path.dart' as p;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../background/foreground_task_handler.dart';

import '../globals.dart';
import '../utils/upload_task.dart';
import '../widgets/chat_background_layer.dart';
import '../voice/voice_channel_manager.dart';
import '../managers/settings_manager.dart';
import '../utils/settings_backup.dart';
import '../managers/unread_manager.dart';
import '../models/group.dart';
import '../models/app_themes.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../widgets/search_dialog_content.dart';
import '../screens/chats_tab.dart';
import '../managers/blocklist_manager.dart';
import '../managers/mute_manager.dart';
import '../screens/accounts_tab.dart';
import '../screens/active_sessions_screen.dart';
import '../utils/optimized_state_manager.dart';
import '../screens/settings_tab.dart';
import '../screens/chat_screen.dart';
import '../managers/account_manager.dart';
import '../models/chat_message.dart';
import '../enums/delivery_mode.dart';
import '../managers/lan_message_manager.dart';
import '../services/wardlink/wardlink_sync_service.dart';
import '../services/wardlink/wardlink_tombstones.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/adaptive_nav_bar.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../widgets/connection_title.dart';
import '../widgets/proxy_shield_badge.dart';
import '../utils/proxy_manager.dart';
import '../utils/cert_pinning.dart';
import '../widgets/animated_nav_icon.dart';
import '../call/call_manager.dart';
import '../screens/groups_tab.dart';
import '../screens/group_chat_screen.dart';
import '../screens/external_group_chat_screen.dart';
import '../managers/user_cache.dart';
import '../utils/optimized_message_sender.dart';
import '../utils/app_paths.dart';
import '../utils/decrypt_worker.dart';
import '../utils/media_cache.dart';
import '../utils/image_file_cache.dart';
import '../utils/image_loader.dart';
import '../managers/windows_notification_popup.dart';
import '../l10n/app_localizations.dart';
import '../utils/update_checker.dart';
import '../widgets/update_banner.dart';
import '../widgets/about_onyx_dialog.dart';
import '../widgets/account_graph_view.dart';
import '../screens/pin_code_screen.dart';
import '../managers/decoy_manager.dart';
import '../managers/decoy_data_manager.dart';
import '../managers/trash_manager.dart';
import 'package:local_auth/local_auth.dart';

final Map<String, List<int>> _pubkeyCache = {};

final Map<String, List<Map<String, dynamic>>> _devicePubkeysCache = {};
final Map<String, DateTime> _devicePubkeysCacheAge = {};
const Duration _kDeviceCacheTTL = Duration(minutes: 5);
DateTime? _lastPubkeyUploadTime;
final X25519 _x25519 = X25519();
final Cipher _xchacha = Xchacha20.poly1305Aead();
final ValueNotifier<double> _chatsPanelWidthNotifier =
    ValueNotifier<double>(300.0);

bool _pubkeyUploadedToServer = false;
DateTime? _lastPubkeyUploadAttempt;
final Duration _pubkeyUploadRetryDelay = const Duration(minutes: 30);

Route<T> _chatRoute<T>(Widget Function(BuildContext) builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

// Media decryption now runs on a reusable pool of isolates — see
// [DecryptWorker] in lib/utils/decrypt_worker.dart.

class RootScreen extends StatefulWidget {
  final AppTheme currentTheme;
  final bool isDarkMode;
  final Future<void> Function(AppTheme theme, bool isDark) onThemeChanged;

  const RootScreen({
    Key? key,
    required this.currentTheme,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  RootScreenState createState() => RootScreenState();
}

class RootScreenState extends State<RootScreen>
    with SingleTickerProviderStateMixin, OptimizedStateMixin<RootScreen> {
  Map<String, List<ChatMessage>> chats = {};

  Completer<void>? _chatsLoadCompleter;

  Timer? _persistChatsTimer;
  bool _hasPendingPersist = false;

  final Set<String> _dirtyChatIds = {};
  bool _fullSaveRequested = false;

  static const List<String> _motivationalHints = [
    'Never be silenced',
    'Nothing unnecessary.',
    "Don't know. Don't want to.",
    "Be yourself — or someone else. I don’t check.",
    'Privacy is on. Extra questions are off.',
    "I don’t collect data. I’ve got enough on my plate.",
  ];
  late int _motivationalHintIndex;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  final _chatScreenCache = _LruCache<String, Widget>(20);
  final _groupChatScreenCache = _LruCache<int, Widget>(20);
  final _externalGroupChatScreenCache = _LruCache<String, Widget>(20);

  List<FavoriteChat> _favorites = [];
  List<FavFolder> _favFolders = [];
  List<String> _favTopOrder = [];
  // When the favourites layout (order + folders) last changed locally. Used by
  // WardLink to decide whose layout is newer when syncing the arrangement.
  DateTime _favStructureUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _selectedFavoriteId;

  final Set<String> _favoritesMediaPrefetched = {};

  final Set<String> _chatsMediaPrefetched = {};
  final Set<String> _missingPrefetchMedia = {};
  bool _isPreloadingUserProfiles = false;

  Stream<dynamic>? wsStream;

  List<FavoriteChat> get favorites => List.unmodifiable(_favorites);
  List<FavFolder> get favFolders => List.unmodifiable(_favFolders);
  List<String> get favTopOrder => List.unmodifiable(_favTopOrder);

  bool _isSwitchingAccount = false;
  String? _pendingAccountSwitch;

  bool _manualWsDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final Duration _baseReconnectDelay = const Duration(seconds: 3);
  final Duration _maxReconnectDelay = const Duration(seconds: 60);

  int _index = 0;
  late final PageController _pageController;

  Timer? _pageChangeDebounce;
  int _pendingPageIndex = 0;
  String? currentUsername;
  String? currentDisplayName;
  String? currentUin;
  bool _isPrimaryDevice = false;

  bool get _mobileGraphEnabled =>
      !isDesktop && SettingsManager.showAccountGraph.value;
  int get _graphTabOffset => 0;
  bool _graphOverlayVisible = false;
  bool _graphOverlayMounted = false;
  bool _isSearchOpen = false;
  Timer? _graphUnmountTimer;
  double _handleY = 100.0;
  bool _handleYInitialized = false;
  SimpleKeyPair? _identityKeyPair;
  SimplePublicKey? _identityPublicKey;
  String? identityPubKeyBase64;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  // Messages queued when WS was offline — drained on reconnect
  final List<Map<String, dynamic>> _pendingMsgQueue = [];
  StreamSubscription<String>? _notificationSubscription;

  final Set<int> _activeGroupChatIds = {};
  final Map<int, void Function(Map<String, dynamic>)> _groupMessageListeners =
      {};

  // Private (1:1) reaction updates — one active chat at a time
  void Function(Map<String, dynamic>)? _privateReactionCallback;
  // Buffered reaction updates for DMs that arrive when the chat screen is closed.
  // Keyed by the other user's username; flushed when that chat opens.
  final Map<String, List<Map<String, dynamic>>> _pendingPrivateReactions = {};

  final List<String> _log = [];
  Timer? _wsHeartbeat;
  final Duration _heartbeatInterval = const Duration(seconds: 20);

  bool _pendingUiFlush = false;
  Timer? _uiFlushTimer;
  final Set<String> _pendingChatUpdates = {};

  /// serverMessageId → chatId index for O(1) WS event lookups.
  /// Eliminates nested O(chats × messages) loops in every WS handler.
  final Map<int, String> _serverMsgIndex = {};

  bool _pendingSoundFlush = false;
  Timer? _soundFlushTimer;

  final Map<String, String> _pendingNotifications = {};
  Timer? _notifFlushTimer;


  String? selectedChatOther;
  Group? selectedGroup;
  Group? selectedExternalGroup;
  ExternalServer? selectedExternalServer;
  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  bool _onGlobalKeyEvent(KeyEvent event) {
    if (!isDesktop) return false;
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      // If a fullscreen page route (album gallery, video fullscreen, etc.)
      // is on top of our route, skip — it handles its own Escape via
      // Focus.onKeyEvent. We only act when dialogs (PopupRoutes) or
      // nothing extra is on top.
      final myRoute = ModalRoute.of(context);
      if (myRoute != null && !myRoute.isCurrent) {
        Route? topRoute;
        Navigator.of(context).popUntil((route) {
          topRoute ??= route;
          return true; // peek only, don't pop
        });
        if (topRoute is! PopupRoute) {
          return false; // page route on top — let it handle Escape
        }
      }
      _handleKeyOrMouseBack();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab &&
        HardwareKeyboard.instance.isControlPressed) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      const visibleTabs = 5;
      final base = _index < visibleTabs ? _index : 4;
      final next = shift
          ? (base - 1 + visibleTabs) % visibleTabs
          : (base + 1) % visibleTabs;
      _onTabSelected(next);
      return true;
    }

    return false;
  }

  final AudioPlayer _audioPlayer = AudioPlayer();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  DateTime? _recordingStartTime;
  String? _lastRecordedPathForUpload;

  String? get lastRecordedPathForUpload => _lastRecordedPathForUpload;

  void _handlePageChanged(int newIndex) {
    if (mounted) FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    if (newIndex == 5 + _graphTabOffset && !_isPrimaryDevice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(4 + _graphTabOffset);
        }
      });
      return;
    }

    final tabIndex = newIndex;

    _pendingPageIndex = tabIndex;
    _pageChangeDebounce?.cancel();
    _pageChangeDebounce = Timer(const Duration(milliseconds: 50), () {
      if (mounted && _index != _pendingPageIndex) {
        setState(() => _index = _pendingPageIndex);
      }
    });
  }

  void showSnack(String text) {
    if (!mounted) return;
    if (!SettingsManager.snackbarEnabled.value) return;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = SettingsManager.elementBrightness.value;
    final opacity = SettingsManager.elementOpacity.value;
    final backgroundColor = SettingsManager.getElementColor(
      colorScheme.surfaceContainerHighest,
      brightness,
    ).withValues(alpha: opacity);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> openAppSettings() async {
    await launchUrl(Uri.parse('app-settings:'));
  }

  Future<void> sendChatMessage(String to, String text) async {
    await _sendChatMessage(to, text, null);
  }

  void sendMessageToFavorite(String favId, String text) {
    final chatId = 'fav:$favId';
    final msg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      from: 'me',
      to: chatId,
      content: text,
      outgoing: true,
      delivered: true,
      time: DateTime.now(),
    );
    chats.putIfAbsent(chatId, () => []).add(msg);
    schedulePersistChats(chatId: chatId);
    chatsVersion.value++;
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    debugPrint('<<cancelRecording>> entry');

    String? path;
    try {
      try {
        path = await _recorder.stop();
        debugPrint('<<cancelRecording>> recorder.stop() -> $path');
      } catch (e) {
        debugPrint('<<cancelRecording>> recorder.stop() threw: $e');
      }

      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}

      try {
        final candidate = path ?? _lastRecordedPathForUpload;
        if (candidate != null) {
          final f = File(candidate);
          if (await f.exists()) {
            await f.delete();
            debugPrint('<<cancelRecording>> deleted temp file: $candidate');
          }
        }
      } catch (e) {
        debugPrint('<<cancelRecording>> failed to delete temp file: $e');
      }

      _lastRecordedPathForUpload = null;


      _appendLog('[record] canceled');
    } catch (e, st) {
      debugPrint('<<cancelRecording>> unexpected: $e\n$st');

      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}
    }
  }

  static Future<void> _fixWavHeader(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      if (bytes.length < 44) return;
      final bd = ByteData.sublistView(bytes);

      int dataOffset = -1;
      int pos = 12;
      while (pos + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        final chunkSize = bd.getUint32(pos + 4, Endian.little);
        if (id == 'data') {
          dataOffset = pos + 4;
          break;
        }
        if (chunkSize == 0) break;
        pos += 8 + chunkSize + (chunkSize & 1);
      }

      if (dataOffset < 0) return;
      final currentDataSize = bd.getUint32(dataOffset, Endian.little);
      if (currentDataSize != 0) return;

      final actualDataSize = bytes.length - (dataOffset + 4);
      bd.setUint32(4, bytes.length - 8, Endian.little);
      bd.setUint32(dataOffset, actualDataSize, Endian.little);
      await file.writeAsBytes(bytes);
      debugPrint('<<_fixWavHeader>> patched $path: dataSize=$actualDataSize');
    } catch (e) {
      debugPrint('<<_fixWavHeader>> error: $e');
    }
  }

  Future<void> stopRecordingOnly() async {
    if (!_isRecording) return;
    debugPrint('<<stopRecordingOnly>> entry');

    String? path;
    try {
      path = await _recorder.stop();
      debugPrint('<<stopRecordingOnly>> recorder.stop() -> $path');

      if (path != null &&
          !kIsWeb &&
          Platform.isWindows &&
          path.endsWith('.wav')) {
        await _fixWavHeader(path);
      }

      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}

      _lastRecordedPathForUpload = path;
      debugPrint('<<stopRecordingOnly>> saved path: $path');
    } catch (e, st) {
      debugPrint('<<stopRecordingOnly>> error: $e\n$st');
      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}
    }
  }

  void saveFavorites() {
    _saveFavorites();
  }

  void deleteFavoriteById(String id) => _deleteFavorite(id);

  void updateFavorite(FavoriteChat updated) {
    final index = _favorites.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      setState(() {
        _favorites[index] = updated;
      });
      _saveFavorites();
    }
  }

  /// Merge favourites received via LAN sync into the app state.
  /// New favourites are inserted at the top of the order list.
  /// Existing favourites with the same id get their messages merged.
  /// Returns true if any new favourites or messages were actually added.
  bool importFavorites(
    List<FavoriteChat> incoming,
    Map<String, List<ChatMessage>> incomingChats, {
    bool cascade = true,
  }) {
    bool changed = false;
    final Set<String> bumpedFavIds = {};
    setState(() {
      for (final fav in incoming) {
        final existingIdx = _favorites.indexWhere((f) => f.id == fav.id);
        if (existingIdx < 0) {
          _favorites.add(fav);
          // Don't surface it at the top level if a synced folder layout already
          // places this chat inside a folder — that would duplicate it.
          final inAnyFolder =
              _favFolders.any((fo) => fo.chatIds.contains(fav.id));
          if (!inAnyFolder && !_favTopOrder.contains(fav.id)) {
            if (cascade) {
              // Local change (e.g. manual forward): new chat goes to top.
              _favTopOrder.insert(0, fav.id);
            } else {
              // WardLink per-chat import: append so manifest order is preserved.
              // applyFavStructure (called after the full sync loop) sets the
              // canonical order, so we just need to avoid reversing it here.
              _favTopOrder.add(fav.id);
            }
          }
          changed = true;
        } else {
          // Existing favourite — sync title and avatar from peer if changed.
          final existing = _favorites[existingIdx];
          final newTitle = fav.title.isNotEmpty && fav.title != existing.title
              ? fav.title
              : null;
          final newAvatar = fav.avatarPath != null &&
                  fav.avatarPath != existing.avatarPath
              ? fav.avatarPath
              : null;
          if (newTitle != null || newAvatar != null) {
            _favorites[existingIdx] = existing.copyWith(
              title: newTitle,
              avatarPath: newAvatar,
            );
            changed = true;
          }
        }
      }
    });

    for (final entry in incomingChats.entries) {
      if (!chats.containsKey(entry.key)) {
        chats[entry.key] = entry.value;
        changed = true;
        bumpChatMessageVersion(entry.key);
        if (entry.key.startsWith('fav:')) {
          bumpedFavIds.add(entry.key.substring('fav:'.length));
        }
      } else {
        // Merge incoming messages that are not yet present locally.
        final existing = chats[entry.key]!;
        final existingIds = existing.map((m) => m.id).toSet();
        final newMessages =
            entry.value.where((m) => !existingIds.contains(m.id)).toList();
        if (newMessages.isNotEmpty) {
          existing.addAll(newMessages);
          existing.sort((a, b) => a.time.compareTo(b.time));
          changed = true;
          // Open chat screens rebuild off this per-chat notifier, not
          // chatsVersion — without it, a chat synced in via WardLink while
          // open stays stale until the user re-enters it.
          bumpChatMessageVersion(entry.key);
          if (entry.key.startsWith('fav:')) {
            bumpedFavIds.add(entry.key.substring('fav:'.length));
          }
        }
      }
    }

    if (changed) {
      _saveFavorites();
      // Touch the structure timestamp only for local changes (cascade=true).
      // WardLink per-chat imports (cascade=false) must NOT advance the timestamp
      // — otherwise applyFavStructure sees our timestamp as newer than the peer's
      // and refuses to apply the correct order.
      _saveFavStructure(touch: cascade);
      schedulePersistChats();
      favoritesVersion.value++;
      chatsVersion.value++;
      // Cascade: poke all other paired devices immediately so they pull
      // the new data — this is what propagates A→B→C without manual action.
      // Suppressed when cascade==false because the caller will poke once
      // after a multi-chat batch, avoiding N pokes for N imported chats.
      if (cascade) unawaited(WardLinkSyncService.instance.pokeNow());
    }

    // New messages synced into a favourite should bring it to the top of the
    // list, same as sending/forwarding a message locally does.
    // During a WardLink pull (cascade=false) we skip this: bumpFavToTop would
    // update _favStructureUpdatedAt to DateTime.now(), making our in-progress
    // (scrambled) layout appear newer than peers' correct layout, causing A and
    // B to adopt our broken order. The canonical order is set by applyFavStructure
    // immediately after importFavorites returns.
    if (cascade) {
      for (final favId in bumpedFavIds) {
        bumpFavToTop(favId);
      }
    }

    return changed;
  }

  /// Apply content updates received via WardLink for already-present messages.
  /// Only updates a message when the incoming editedAt is newer than the local one.
  void applyMessageEdits(String chatId, List<ChatMessage> updatedMsgs) {
    final msgs = chats[chatId];
    if (msgs == null || updatedMsgs.isEmpty) return;
    final byId = {for (final m in msgs) m.id: m};
    bool changed = false;
    for (final updated in updatedMsgs) {
      final local = byId[updated.id];
      if (local == null) continue;
      final remoteEt = updated.editedAt;
      if (remoteEt == null) continue;
      final localEt = local.editedAt;
      if (localEt != null && !remoteEt.isAfter(localEt)) continue;
      local.updateContent(updated.content);
      local.editedAt = remoteEt;
      changed = true;
    }
    if (changed) {
      bumpChatMessageVersion(chatId);
      schedulePersistChats(chatId: chatId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadFavorites() async {
    if (currentUsername == null) return;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('favorites_${currentUsername}');
    if (str != null) {
      final list = (jsonDecode(str) as List)
          .map((e) => FavoriteChat.fromJson(e))
          .toList();
      setState(() => _favorites = list);
    } else {
      setState(() => _favorites = []);
    }
    await _loadFavStructure();
  }

  Future<void> _requestStatusSnapshotForKnownUsers() async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return;
      final token = await AccountManager.getToken(username);
      if (token == null) return;

      final res =
          await http.get(Uri.parse('$serverBase/conversations'), headers: {
        'authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final users = <String>{};
        for (final e in list) {
          try {
            final u = (e['username'] as String?).toString();
            if (u != null && u.isNotEmpty) users.add(u);
          } catch (_) {}
        }

        for (final f in _favorites) users.add(f.title);
        if (selectedChatOther != null) users.add(selectedChatOther!);

        if (users.isNotEmpty && _ws != null) {
          _ws!.sink.add(jsonEncode(
              {'type': 'request_status_snapshot', 'users': users.toList()}));
          _appendLog('[status_snapshot] requested for ${users.length} users');
        }
      }
    } catch (e) {
      _appendLog('[status_snapshot] failed to fetch convos: $e');
    }
  }

  Future<void> _saveFavorites() async {
    if (currentUsername == null) return;
    final prefs = await SharedPreferences.getInstance();
    final list = _favorites.map((f) => f.toJson()).toList();
    await prefs.setString('favorites_${currentUsername}', jsonEncode(list));
    unawaited(SettingsBackup.save(prefs));
  }

  // ── Folder structure load / save ─────────────────────────────────────────

  Future<void> _loadFavStructure() async {
    if (currentUsername == null) return;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('fav_structure_$currentUsername');
    List<FavFolder> folders = [];
    List<String> topOrder = [];
    DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (str != null) {
      try {
        final j = jsonDecode(str) as Map<String, dynamic>;
        folders = (j['folders'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map(FavFolder.fromJson)
            .toList();
        topOrder = (j['topOrder'] as List? ?? []).cast<String>();
        updatedAt = DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            updatedAt;
      } catch (_) {}
    }
    setState(() {
      _favFolders = folders;
      _favTopOrder = topOrder;
      _favStructureUpdatedAt = updatedAt;
      _ensureFavTopOrder();
    });
  }

  // Ensures _favTopOrder is consistent with _favorites and _favFolders.
  // Call inside setState.
  void _ensureFavTopOrder() {
    // A chat may belong to at most one folder. Merging a peer's layout can
    // leave the same id in two folders (e.g. moved to folder A here, folder B
    // there) — keep the first membership, drop the rest.
    final inFolders = <String>{};
    for (final folder in _favFolders) {
      folder.chatIds.removeWhere((id) => !inFolders.add(id));
    }
    // Invariant: a chat inside a folder must never also sit at the top level.
    // Folder membership wins — otherwise the chat renders twice (once in the
    // folder, once outside) and deleting either copy nukes the one favourite.
    _favTopOrder.removeWhere((id) => inFolders.contains(id));
    final inTop = _favTopOrder.toSet();
    // Collect missing favorites (not yet in top order and not in a folder)
    final missing = _favorites
        .where((f) => !inFolders.contains(f.id) && !inTop.contains(f.id))
        .toList();
    // On first migration (topOrder was empty), sort newest-added first
    // (id is millisecondsSinceEpoch) to approximate the previous display order.
    if (inTop.isEmpty && missing.isNotEmpty) {
      missing.sort((a, b) => b.id.compareTo(a.id));
    }
    for (final fav in missing) {
      _favTopOrder.add(fav.id);
    }
    // Remove stale IDs
    final allFavIds = _favorites.map((f) => f.id).toSet();
    final allFolderIds = _favFolders.map((f) => f.id).toSet();
    _favTopOrder.removeWhere(
        (id) => !allFavIds.contains(id) && !allFolderIds.contains(id));
    for (final folder in _favFolders) {
      folder.chatIds.removeWhere((id) => !allFavIds.contains(id));
    }
  }

  Future<void> _saveFavStructure({bool touch = true}) async {
    if (currentUsername == null) return;
    // A local edit (reorder, folder change…) marks the layout as freshly
    // changed so WardLink propagates it; syncing in a peer's layout passes
    // touch:false to preserve the originating timestamp.
    if (touch) _favStructureUpdatedAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'fav_structure_$currentUsername',
        jsonEncode({
          'folders': _favFolders.map((f) => f.toJson()).toList(),
          'topOrder': _favTopOrder,
          'updatedAt': _favStructureUpdatedAt.toIso8601String(),
        }));
  }

  // ── WardLink: favourites layout sync ──────────────────────────────────────

  /// Snapshot of the favourites arrangement (order + folders) for WardLink.
  Map<String, dynamic> exportFavStructure() => {
        'folders': _favFolders.map((f) => f.toJson()).toList(),
        'topOrder': _favTopOrder,
        'updatedAt': _favStructureUpdatedAt.toIso8601String(),
      };

  /// Merge a peer's favourites layout into ours.
  ///
  /// Rules:
  /// - Folders that exist on peer but not locally → added.
  /// - Folders that exist on both sides → chatIds are unioned (no removal).
  /// - Local folders the peer doesn't know about → kept as-is.
  /// - topOrder: peer's order is used as the base; local-only items are
  ///   appended at the end so nothing disappears.
  /// - Only applies when the peer's timestamp is newer than ours, unless
  ///   [force] is set (a freshly-paired device adopting an established fleet's
  ///   arrangement regardless of local timestamp).
  ///
  /// Returns true if anything changed.
  bool applyFavStructure(Map<String, dynamic> data, {bool force = false}) {
    final ts = DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (!force && !ts.isAfter(_favStructureUpdatedAt)) return false;

    final peerFolders = (data['folders'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(FavFolder.fromJson)
        .toList();
    final peerTopOrder = (data['topOrder'] as List? ?? []).cast<String>();

    // Build merged folder list: start from local, apply peer additions.
    final mergedFolders = [..._favFolders];
    for (final pf in peerFolders) {
      final localIdx = mergedFolders.indexWhere((f) => f.id == pf.id);
      if (localIdx >= 0) {
        // Folder exists locally — union the chatIds, keep local name/avatar.
        final lf = mergedFolders[localIdx];
        final union = {...lf.chatIds, ...pf.chatIds}.toList();
        // Preserve peer's chatId order for items that appear in peer's list,
        // then append local-only items at the end.
        final ordered = [
          for (final id in pf.chatIds) if (union.contains(id)) id,
          for (final id in lf.chatIds) if (!pf.chatIds.contains(id)) id,
        ];
        lf.chatIds
          ..clear()
          ..addAll(ordered);
      } else {
        // New folder from peer — add it.
        mergedFolders.add(pf);
      }
    }

    // Merge topOrder: peer's order as base, local-only items appended.
    final peerTopSet = peerTopOrder.toSet();
    final mergedTopOrder = [...peerTopOrder];
    for (final id in _favTopOrder) {
      if (!peerTopSet.contains(id)) mergedTopOrder.add(id);
    }

    // Skip the write if nothing actually changed (same folders, same order,
    // same timestamp). This prevents a false favoritesVersion bump that would
    // poke peers and re-trigger the sync loop.
    final foldersUnchanged = mergedFolders.length == _favFolders.length &&
        mergedFolders.asMap().entries.every((e) {
          final lf = _favFolders[e.key];
          return e.value.id == lf.id &&
              e.value.chatIds.length == lf.chatIds.length &&
              e.value.chatIds.asMap().entries
                  .every((ce) => ce.value == lf.chatIds[ce.key]);
        });
    final orderUnchanged = mergedTopOrder.length == _favTopOrder.length &&
        mergedTopOrder.asMap().entries
            .every((e) => e.value == _favTopOrder[e.key]);

    if (foldersUnchanged && orderUnchanged && ts == _favStructureUpdatedAt) {
      return false;
    }

    setState(() {
      _favFolders = mergedFolders;
      _favTopOrder = mergedTopOrder;
      _favStructureUpdatedAt = ts;
      _ensureFavTopOrder();
    });
    _saveFavStructure(touch: false);
    favoritesVersion.value++;
    return true;
  }

  // ── Public folder API ────────────────────────────────────────────────────

  String createFavFolder(String name, {String? avatarPath}) {
    final folder = FavFolder.create(name)..avatarPath = avatarPath;
    setState(() {
      _favFolders.add(folder);
      _favTopOrder.insert(0, folder.id);
    });
    _saveFavStructure();
    favoritesVersion.value++;
    return folder.id;
  }

  void renameFavFolder(String id, String newName) {
    final idx = _favFolders.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    setState(() => _favFolders[idx].name = newName);
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void setFavFolderAvatar(String id, String? path) {
    final idx = _favFolders.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    setState(() => _favFolders[idx].avatarPath = path);
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void deleteFavFolder(String id) {
    final idx = _favFolders.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    final folder = _favFolders[idx];
    final folderPos = _favTopOrder.indexOf(id);
    setState(() {
      _favFolders.removeAt(idx);
      _favTopOrder.remove(id);
      // Move folder's chats back to top level at the old folder position
      if (folderPos >= 0) {
        _favTopOrder.insertAll(folderPos, folder.chatIds);
      } else {
        _favTopOrder.addAll(folder.chatIds);
      }
    });
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void moveChatToFolder(String chatId, String folderId) {
    final fIdx = _favFolders.indexWhere((f) => f.id == folderId);
    if (fIdx == -1) return;
    setState(() {
      for (final f in _favFolders) f.chatIds.remove(chatId);
      _favTopOrder.remove(chatId);
      _favFolders[fIdx].chatIds.add(chatId);
    });
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void moveChatOutOfFolder(String chatId) {
    setState(() {
      for (final f in _favFolders) {
        if (f.chatIds.contains(chatId)) {
          f.chatIds.remove(chatId);
          if (!_favTopOrder.contains(chatId)) _favTopOrder.add(chatId);
          break;
        }
      }
    });
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void reorderFavTop(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _favTopOrder.removeAt(oldIndex);
      _favTopOrder.insert(newIndex, item);
    });
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void reorderFavInFolder(String folderId, int oldIndex, int newIndex) {
    final idx = _favFolders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _favFolders[idx].chatIds.removeAt(oldIndex);
      _favFolders[idx].chatIds.insert(newIndex, item);
    });
    _saveFavStructure();
    favoritesVersion.value++;
  }

  void setFavTopOrder(List<String> orderedIds) {
    setState(() {
      _favTopOrder
        ..clear()
        ..addAll(orderedIds);
    });
    favoritesVersion.value++;
    _saveFavStructure();
  }

  void bumpFavToTop(String favId) {
    bool changed = false;

    // Check top-level order
    final topIdx = _favTopOrder.indexOf(favId);
    if (topIdx > 0) {
      setState(() {
        _favTopOrder.removeAt(topIdx);
        _favTopOrder.insert(0, favId);
      });
      changed = true;
    }

    // Check inside folders
    for (int i = 0; i < _favFolders.length; i++) {
      final folderIdx = _favFolders[i].chatIds.indexOf(favId);
      if (folderIdx > 0) {
        setState(() {
          _favFolders[i].chatIds.removeAt(folderIdx);
          _favFolders[i].chatIds.insert(0, favId);
        });
        changed = true;
        break;
      }
    }

    if (changed) {
      favoritesVersion.value++;
      _saveFavStructure();
    }
  }

  void setFolderChatOrder(String folderId, List<String> orderedIds) {
    final idx = _favFolders.indexWhere((f) => f.id == folderId);
    if (idx == -1) return;
    setState(() {
      _favFolders[idx].chatIds
        ..clear()
        ..addAll(orderedIds);
    });
    favoritesVersion.value++;
    _saveFavStructure();
  }

  Future<void> startRecording() async {
    debugPrint('<<_startRecording>> entry');
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final micStatus = await Permission.microphone.request();
        debugPrint('<<_startRecording>> microphone permission: $micStatus');
        if (!micStatus.isGranted) {
          if (micStatus.isPermanentlyDenied) openAppSettings();
          showSnack('Microphone access required');
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      String filename;
      AudioEncoder encoder;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        encoder = AudioEncoder.aacLc;
      } else {
        filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
        encoder = AudioEncoder.wav;
      }

      final path = '${dir.path}/$filename';
      _lastRecordedPathForUpload = path;

      debugPrint(
        '<<_startRecording>> starting recorder at path=$path encoder=$encoder',
      );

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      try {
        final bool nowRecording = await _recorder.isRecording();
        debugPrint(
          '<<_startRecording>> _recorder.isRecording() => $nowRecording',
        );
      } catch (e) {
        debugPrint('<<_startRecording>> error checking isRecording: $e');
      }

      setState(() => _isRecording = true);
      _recordingStartTime = DateTime.now();
      recordingNotifier.value = true;

      _appendLog('[record] started -> $path');
      debugPrint('<<_startRecording>> started OK');

      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final f = File(path);
        if (await f.exists()) {
          final len = await f.length();
          debugPrint(
            '<<_startRecording>> file exists after start, length=$len bytes',
          );

          if (len == 0) {
            rootScreenKey.currentState?.showSnack(
              'Recording started but file size is 0 — testing different codec',
            );
          }
        } else {
          debugPrint(
            '<<_startRecording>> file does NOT exist after start: $path',
          );
        }
      } catch (e) {
        debugPrint('<<_startRecording>> file check error: $e');
      }

    } catch (e, st) {
      _appendLog('[record] start failed: $e');
      debugPrint('<<_startRecording>> start failed: $e\n$st');
      showSnack('Recording failed: $e');
      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}
    }
  }

  Future<bool> checkQuotaAndPrompt({
    double limitMb = 10.0,
    bool includeImageCache = true,
  }) async {
    try {
      final appSupport = await getOnyxSupportDirectory();
      final voiceDir = Directory('${appSupport.path}/voice_cache');

      final imageCacheDir = Directory('${appSupport.path}/image_cache');

      int totalBytes = 0;

      if (await voiceDir.exists()) {
        await for (final f
            in voiceDir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            try {
              totalBytes += await f.length();
            } catch (_) {}
          }
        }
      }

      if (includeImageCache && await imageCacheDir.exists()) {
        await for (final f
            in imageCacheDir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            try {
              totalBytes += await f.length();
            } catch (_) {}
          }
        }
      }

      final usedMb = totalBytes / (1024 * 1024);

      if (usedMb >= limitMb) {
        if (!mounted) return false;
        final opened = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quota exceeded'),
            content: Text(
              'Quota limit is full. Free up space in settings (Settings → Cache).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (opened == true) {
          try {
            _onTabSelected(2);
          } catch (_) {}
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[checkQuotaAndPrompt] error: $e');
      return true;
    }
  }

  Future<void> stopRecordingAndUpload(
    String to, [
    Map<String, dynamic>? replyTo,
    void Function(UploadTask)? onTaskCreated,
  ]) async {
    debugPrint(
        '<<stopRecordingAndUpload>> entry (to=$to) _isRecording=$_isRecording replyTo=${replyTo != null}');
    if (!_isRecording) {
      debugPrint(
          '<<stopRecordingAndUpload>> called but _isRecording=false → returning');
      return;
    }

    final recordedDuration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : null;

    String? path;
    try {
      path = await _recorder.stop();
      debugPrint(
          '<<stopRecordingAndUpload>> recorder.stop() returned path=$path');
      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}

      if (path == null) {
        _appendLog('[record] stop returned null path');
        rootScreenKey.currentState?.showSnack('No file recorded');
        return;
      }

      if (!kIsWeb && Platform.isWindows && path.endsWith('.wav')) {
        await _fixWavHeader(path);
      }

      await Future.delayed(const Duration(milliseconds: 150));
      final f = File(path);
      if (!await f.exists()) {
        _appendLog('[record] file not found after stop: $path');
        rootScreenKey.currentState?.showSnack('File not found');
        return;
      }

      final bytes = await f.readAsBytes();

      if (SettingsManager.confirmVoiceUpload.value) {
        final duration = recordedDuration ??
            Duration(seconds: (bytes.length / 16000).ceil());

        if (mounted) {
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => VoiceConfirmDialog(
                  duration: duration,
                  onSend: () {
                    _performVoiceUpload(to, path!, replyTo, onTaskCreated);
                  },
                  onCancel: () {
                    if (mounted) {

                    }

                    try {
                      if (File(path!).existsSync()) {
                        File(path!).deleteSync();
                      }
                    } catch (_) {}
                  },
                ),
              ) ??
              false;
        }
      } else {
        await _performVoiceUpload(to, path, replyTo, onTaskCreated);
      }
    } catch (e, st) {
      _appendLog('[record/upload] error: $e\n$st');
      debugPrint('<<stopRecordingAndUpload>> error: $e\n$st');
      setState(() => _isRecording = false);
      try {
        recordingNotifier.value = false;
      } catch (_) {}
      rootScreenKey.currentState?.showSnack('Upload error: $e');

      if (path != null) {
        try {
          final tmp = File(path);
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _performVoiceUpload(
    String to,
    String path, [
    Map<String, dynamic>? replyTo,
    void Function(UploadTask)? onTaskCreated,
  ]) async {
    UploadTask? voiceTask;
    try {
      final isLANMode = lanModePerChat.value[to] ?? false;
      if (isLANMode) {
        return await _performVoiceUploadLAN(to, path, replyTo);
      }

      // Favorites are local-only — no server upload.
      if (to.startsWith('fav:')) {
        return await _performVoiceUploadFavorite(
            to, path, replyTo, onTaskCreated);
      }

      final token = await AccountManager.getToken(currentUsername ?? '');
      if (token == null) {
        _appendLog('[voice.upload] no token');
        rootScreenKey.currentState?.showSnack('Not logged in');
        return;
      }

      final bool isPersonalChat = !to.startsWith('fav:');
      final String noNotifyParam = isPersonalChat ? '&no_notify=1' : '';
      final String uriStr =
          '$serverBase/voice/upload?to=${Uri.encodeComponent(to)}$noNotifyParam';
      final uri = Uri.parse(uriStr);
      final req = http.MultipartRequest('POST', uri);
      req.headers['authorization'] = 'Bearer $token';

      final f = File(path);
      final plainBytes = await f.readAsBytes();

      Uint8List bytesToUpload;
      String? voiceMediaKeyB64;
      if (to.startsWith('fav:')) {
        bytesToUpload = plainBytes;
      } else {
        final (enc, keyB64) =
            await encryptMediaRandom(plainBytes, kind: 'voice');
        bytesToUpload = enc;
        voiceMediaKeyB64 = keyB64;
      }

      final filenameInReq = _sanitizeFilename(p.basename(path));
      final ext = p.extension(filenameInReq).toLowerCase();

      // Create upload task and hand it to the chat screen for display.
      voiceTask = UploadTask(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: 'voice',
        localPath: path,
        basename: filenameInReq,
      );
      voiceTask.status = UploadStatus.uploading;
      onTaskCreated?.call(voiceTask);

      final presignResp = await http.post(
        Uri.parse('$serverBase/media/presign/upload'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'type': 'voice',
          'ext': ext,
          'size': bytesToUpload.length,
          'contentType': 'application/octet-stream'
        }),
      );
      if (presignResp.statusCode == 413) {
        dynamic body;
        try {
          body = jsonDecode(presignResp.body);
        } catch (_) {}
        rootScreenKey.currentState?.showSnack(
          body is Map
              ? (body['detail'] ?? 'Storage quota exceeded')
              : 'Storage quota exceeded',
        );
        return;
      }
      if (presignResp.statusCode != 200) {
        debugPrint(
            '<<_performVoiceUpload>> presign failed: ${presignResp.statusCode}');
        rootScreenKey.currentState
            ?.showSnack('Upload failed: ${presignResp.statusCode}');
        return;
      }
      final presignData = jsonDecode(presignResp.body) as Map<String, dynamic>;
      final presignedUrl = presignData['presignedUrl'] as String;
      String filename = _sanitizeFilename(presignData['filename'] as String);
      if (filename.isEmpty) {
        rootScreenKey.currentState?.showSnack('Empty filename from server');
        return;
      }

      final putClient = http.Client();
      voiceTask.activeClient = putClient;
      try {
        final putRequest = http.StreamedRequest('PUT', Uri.parse(presignedUrl));
        putRequest.headers['Content-Type'] = 'application/octet-stream';
        putRequest.contentLength = bytesToUpload.length;
        final responseFuture = putClient.send(putRequest);
        const chunkSize = 65536; // 64 KB
        int offset = 0;
        while (offset < bytesToUpload.length) {
          final end = (offset + chunkSize).clamp(0, bytesToUpload.length);
          putRequest.sink.add(bytesToUpload.sublist(offset, end));
          offset = end;
          voiceTask.progress = offset / bytesToUpload.length;
          await Future.delayed(Duration.zero);
        }
        await putRequest.sink.close();
        final putStreamed = await responseFuture;
        await putStreamed.stream.drain();
        if (putStreamed.statusCode != 200) {
          debugPrint(
              '<<_performVoiceUpload>> S3 PUT failed: ${putStreamed.statusCode}');
          voiceTask.status = UploadStatus.failed;
          rootScreenKey.currentState?.showSnack('Upload failed');
          return;
        }
      } finally {
        putClient.close();
        voiceTask.activeClient = null;
      }

      final confirmResp = await http.post(
        Uri.parse('$serverBase/media/presign/confirm'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'type': 'voice',
          'filename': filename,
          'to': to,
          'no_notify': isPersonalChat
        }),
      );
      int? serverMsgId;
      if (confirmResp.statusCode == 200) {
        try {
          final json = jsonDecode(confirmResp.body) as Map<String, dynamic>;
          serverMsgId = json['id'] is int
              ? json['id'] as int
              : int.tryParse(json['id']?.toString() ?? '');
        } catch (_) {}
      } else {
        debugPrint(
            '<<_performVoiceUpload>> confirm failed: ${confirmResp.statusCode}');
        rootScreenKey.currentState
            ?.showSnack('Upload failed: ${confirmResp.statusCode}');
        return;
      }

      debugPrint(
          '<<_performVoiceUpload>> upload confirmed, filename=$filename');

      final voiceCacheDir = await getOnyxSupportDirectory();
      final cachePath = '${voiceCacheDir.path}/voice_cache';
      await Directory(cachePath).create(recursive: true);
      final cachedPath = '$cachePath/$filename';
      await f.copy(cachedPath);

      final voiceContent = jsonEncode({
        'filename': filename,
        'owner': currentUsername ?? '',
        'orig': 'Voice message',
        if (voiceMediaKeyB64 != null) 'key': voiceMediaKeyB64,
      });
      final content = 'VOICEv1:$voiceContent';

      if (isPersonalChat) {
        await _sendChatMessage(to, content, replyTo);
      } else {
        final localId = DateTime.now().microsecondsSinceEpoch.toString();
        final msg = ChatMessage(
          id: localId,
          from: currentUsername ?? 'me',
          to: to,
          content: content,
          outgoing: true,
          delivered: false,
          time: DateTime.now(),
          serverMessageId: serverMsgId,
          replyToId: replyTo != null && replyTo['id'] != null
              ? int.tryParse(replyTo['id'].toString())
              : null,
          replyToSender: replyTo != null
              ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString()
              : null,
          replyToContent:
              replyTo != null ? replyTo['content']?.toString() : null,
        );
        chats.putIfAbsent(to, () => []).add(msg);
        await persistChats();
        _bumpForChat(to);
      }

      _appendLog('[voice.upload] success, filename=$filename, to=$to');
      voiceTask.status = UploadStatus.done;
      await voiceTask.onComplete?.call(filename);
      rootScreenKey.currentState?.showSnack('Voice sent');

      try {
        if (await File(path).exists()) await File(path).delete();
      } catch (_) {}
    } catch (e, st) {
      _appendLog('[voice.upload] error: $e\n$st');
      debugPrint('<<_performVoiceUpload>> error: $e\n$st');
      voiceTask?.status = UploadStatus.failed;
      rootScreenKey.currentState?.showSnack('Upload error: $e');

      try {
        final tmp = File(path);
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  Future<void> _performVoiceUploadLAN(String to, String path,
      [Map<String, dynamic>? replyTo]) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        showSnack('Voice file not found');
        return;
      }

      final voiceBytes = await file.readAsBytes();

      String format = 'ogg';
      if (_isM4A(voiceBytes)) {
        format = 'm4a';
      } else if (_isOgg(voiceBytes)) {
        format = 'ogg';
      }

      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.$format';

      final appDocuments = await getOnyxDocumentsDirectory();
      final lanMediaDir = Directory('${appDocuments.path}/lan_media');
      if (!await lanMediaDir.exists()) {
        await lanMediaDir.create(recursive: true);
        debugPrint('[LAN VOICE] Created lan_media directory');
      }

      final localLanFile = File('${lanMediaDir.path}/$filename');
      await localLanFile.writeAsBytes(voiceBytes, flush: true);
      debugPrint(
          '[LAN VOICE] Saved locally to: ${localLanFile.path} (exists: ${await localLanFile.exists()})');

      final sent = await LANMessageManager().sendMediaMessage(
        from: currentUsername!,
        to: to,
        mediaType: 'voice',
        mediaData: Uint8List.fromList(voiceBytes),
        filename: filename,
        replyTo: replyTo,
      );

      if (!sent) {
        showSnack('Failed to send voice via LAN');
        return;
      }

      final duration = voiceBytes.length ~/ (16000 * 2);
      final voiceContent = jsonEncode({
        'url': 'lan://$filename',
        'duration': duration,
        'format': format,
      });

      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      final chatId = chatIdForUser(to);

      final int? replyId = replyTo != null && replyTo['id'] != null
          ? int.tryParse(replyTo['id'].toString())
          : null;

      final msgLocal = ChatMessage(
        id: localId,
        from: currentUsername!,
        to: to,
        content: 'VOICEv1:$voiceContent',
        outgoing: true,
        delivered: true,
        time: DateTime.now(),
        replyToId: replyId,
        replyToSender: replyTo != null
            ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString()
            : null,
        replyToContent:
            replyTo != null ? (replyTo['content'])?.toString() : null,
        deliveryMode: DeliveryMode.lan,
      );

      chats.putIfAbsent(chatId, () => []).add(msgLocal);
      messageListNotifier.addMessageOptimized(chatId, msgLocal);
      _bumpForChat(chatId);

      schedulePersistChats(chatId: chatId);

      showSnack('Voice sent via LAN');

      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e, st) {
      _appendLog('[voice.lan] error: $e\n$st');
      showSnack('Failed to send voice via LAN: $e');
    }
  }

  Future<void> _performVoiceUploadFavorite(
    String to,
    String path, [
    Map<String, dynamic>? replyTo,
    void Function(UploadTask)? onTaskCreated,
  ]) async {
    UploadTask? voiceTask;
    try {
      final file = File(path);
      if (!await file.exists()) {
        showSnack('Voice file not found');
        return;
      }

      final voiceBytes = await file.readAsBytes();
      String format = 'ogg';
      if (_isM4A(voiceBytes)) {
        format = 'm4a';
      } else if (_isOgg(voiceBytes)) {
        format = 'ogg';
      }

      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.$format';
      final basename = filename;

      voiceTask = UploadTask(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        type: 'voice',
        localPath: path,
        basename: basename,
      );
      voiceTask.status = UploadStatus.uploading;
      onTaskCreated?.call(voiceTask);

      // Copy to local voice cache — no server involved.
      final appDocuments = await getOnyxDocumentsDirectory();
      final cacheDir = '${appDocuments.path}/voice_cache';
      await Directory(cacheDir).create(recursive: true);
      final cachedPath = '$cacheDir/$filename';
      await file.copy(cachedPath);

      // Use fav:// prefix so VoiceMessagePlayer reads from local cache
      // instead of trying to fetch from the server.
      final voiceContent =
          jsonEncode({'filename': 'fav://$filename', 'orig': filename});
      final content = 'VOICEv1:$voiceContent';

      final localId = voiceTask.id;
      final msg = ChatMessage(
        id: localId,
        from: currentUsername ?? 'me',
        to: to,
        content: content,
        outgoing: true,
        delivered: true,
        time: DateTime.now(),
        replyToId: replyTo != null && replyTo['id'] != null
            ? int.tryParse(replyTo['id'].toString())
            : null,
        replyToSender: replyTo != null
            ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString()
            : null,
        replyToContent: replyTo != null ? replyTo['content']?.toString() : null,
      );
      chats.putIfAbsent(to, () => []).add(msg);
      await persistChats();
      _bumpForChat(to);

      voiceTask.status = UploadStatus.done;
      await voiceTask.onComplete?.call(filename);

      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (e, st) {
      _appendLog('[voice.fav] error: $e\n$st');
      voiceTask?.status = UploadStatus.failed;
      showSnack('Failed to save voice: $e');
    }
  }

  bool _isOgg(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
  }

  bool _isM4A(List<int> bytes) {
    if (bytes.length < 8) return false;
    return String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp';
  }

  bool _isWav(List<int> bytes) {
    if (bytes.length < 12) return false;
    return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WAVE';
  }

  bool _isMp3(List<int> bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
  }

  bool _isRawOpus(List<int> bytes) {
    if (bytes.length < 8) return false;
    return String.fromCharCodes(bytes.sublist(0, 8)) == 'OpusHead';
  }

  Future<void> _downloadAndPlayVoice(String filename) async {
    _appendLog('[voice.play] entry -> $filename');
    debugPrint('[_downloadAndPlayVoice] entry -> $filename');

    try {
      final appSupport = await getOnyxDocumentsDirectory();

      Directory cacheDir;
      String actualFilename;

      if (filename.startsWith('lan://')) {
        actualFilename = filename.substring(6);
        cacheDir = Directory('${appSupport.path}/lan_media');
        debugPrint('[_downloadAndPlayVoice] LAN mode: $actualFilename');
      } else {
        actualFilename = filename;
        cacheDir = Directory('${appSupport.path}/voice_cache');
      }

      await cacheDir.create(recursive: true);

      final possibleExts = <String>[
        '',
        '.ogg',
        '.opus',
        '.m4a',
        '.mp3',
        '.wav',
      ];
      File? cachedFile;
      for (final ext in possibleExts) {
        final tryName = actualFilename.endsWith(ext) || ext.isEmpty
            ? actualFilename
            : '$actualFilename$ext';
        final f = File('${cacheDir.path}/$tryName');
        if (await f.exists()) {
          cachedFile = f;
          debugPrint('[_downloadAndPlayVoice] found cached file: ${f.path}');
          _appendLog('[voice.play] found cached ${f.path}');
          break;
        }
      }

      Future<void> _playFile(File file) async {
        debugPrint('[_downloadAndPlayVoice] playFile -> ${file.path}');
        _appendLog('[voice.play] playing ${file.path}');

        final session = await AudioSession.instance;
        try {
          await session.setActive(true);
          debugPrint('[_downloadAndPlayVoice] session.setActive(true) OK');
        } catch (e) {
          debugPrint('[_downloadAndPlayVoice] session.setActive error: $e');
        }

        if (Platform.isAndroid) {
          try {
            const ch = MethodChannel('onyx/audio');
            await ch.invokeMethod('setSpeakerOn', true);
            debugPrint(
              '[_downloadAndPlayVoice] MethodChannel setSpeakerOn(true) called',
            );
          } catch (e) {
            debugPrint(
              '[_downloadAndPlayVoice] MethodChannel setSpeakerOn failed: $e',
            );
          }
        }

        try {
          await _audioPlayer.stop();
          await _audioPlayer.play(DeviceFileSource(file.path));
          debugPrint('[_downloadAndPlayVoice] play() called for ${file.path}');

          _audioPlayer.onPlayerStateChanged.listen((state) {
            debugPrint('[_downloadAndPlayVoice] player state -> $state');
          });

          _audioPlayer.onPlayerComplete.listen((_) async {
            debugPrint('[_downloadAndPlayVoice] playback complete');
            try {
              await session.setActive(false);
            } catch (_) {}
          });
        } catch (e, st) {
          debugPrint('[_downloadAndPlayVoice] player.play failed: $e\n$st');
          rethrow;
        }
      }

      if (cachedFile != null) {
        try {
          await _playFile(cachedFile);
          return;
        } catch (e) {
          debugPrint(
            '[_downloadAndPlayVoice] playback from cache failed, deleting and retrying: $e',
          );
          try {
            if (await cachedFile.exists()) await cachedFile.delete();
          } catch (_) {}
        }
      }

      final token = await AccountManager.getToken(currentUsername ?? '');
      if (token == null) {
        _appendLog('[voice.play] no token');
        showSnack('Not logged in');
        return;
      }

      final uri = Uri.parse('$serverBase/voice/$filename');
      debugPrint('[_downloadAndPlayVoice] download url=$uri');
      final res = await http.get(
        uri,
        headers: {'authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        _appendLog('[voice.play] download failed ${res.statusCode}');
        rootScreenKey.currentState?.showSnack(
          'Download failed ${res.statusCode}',
        );
        return;
      }

      final bytes = res.bodyBytes;
      if (bytes.isEmpty) {
        _appendLog('[voice.play] empty bodyBytes');
        rootScreenKey.currentState?.showSnack('Downloaded file is empty');
        return;
      }

      final firstBytes = bytes.length > 16 ? bytes.sublist(0, 16) : bytes;
      debugPrint('[_downloadAndPlayVoice] first bytes: $firstBytes');
      _appendLog('[voice.play] first bytes: $firstBytes');

      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      debugPrint(
        '[_downloadAndPlayVoice] content-type=$contentType, bytes=${bytes.length}',
      );
      _appendLog(
        '[voice.play] content-type=$contentType bytes=${bytes.length}',
      );

      String outName = filename;
      String lowerFilename = filename.toLowerCase();
      bool chosen = false;

      if (lowerFilename.endsWith('.mp3') || contentType.contains('mpeg')) {
        outName = filename.endsWith('.mp3') ? filename : '$filename.mp3';
        chosen = true;
      } else if (lowerFilename.endsWith('.m4a') ||
          contentType.contains('audio/mp4') ||
          contentType.contains('mp4')) {
        outName = filename.endsWith('.m4a') ? filename : '$filename.m4a';
        chosen = true;
      } else if (lowerFilename.endsWith('.wav') ||
          contentType.contains('wav')) {
        outName = filename.endsWith('.wav') ? filename : '$filename.wav';
        chosen = true;
      } else if (contentType.contains('ogg') ||
          contentType.contains('vorbis')) {
        outName = filename.endsWith('.ogg') ? filename : '$filename.ogg';
        chosen = true;
      } else if (contentType.contains('opus') ||
          lowerFilename.endsWith('.opus')) {
        if (_isOgg(bytes)) {
          outName = filename.endsWith('.ogg') ? filename : '$filename.ogg';
        } else {
          outName = filename.endsWith('.opus') ? filename : '$filename.opus';
          _appendLog(
            '[voice.play] raw opus detected by content-type — playing as .opus',
          );
        }
        chosen = true;
      }

      if (!chosen) {
        if (_isOgg(bytes)) {
          outName = filename.endsWith('.ogg') ? filename : '$filename.ogg';
        } else if (_isM4A(bytes)) {
          outName = filename.endsWith('.m4a') ? filename : '$filename.m4a';
        } else if (_isWav(bytes)) {
          outName = filename.endsWith('.wav') ? filename : '$filename.wav';
        } else if (_isMp3(bytes)) {
          outName = filename.endsWith('.mp3') ? filename : '$filename.mp3';
        } else if (_isRawOpus(bytes)) {
          outName = filename.endsWith('.opus') ? filename : '$filename.opus';
          _appendLog(
            '[voice.play] raw Opus by magic — attempting to play as .opus (may fail)',
          );
        } else {
          outName = filename.endsWith('.m4a') ? filename : '$filename.m4a';
          _appendLog('[voice.play] fallback to .m4a');
        }
      }

      final safeName = _sanitizeFilename(outName);
      final finalCachedFile = File('${cacheDir.path}/$safeName');
      await finalCachedFile.writeAsBytes(bytes, flush: true);

      final len = await finalCachedFile.length();
      debugPrint(
        '[_downloadAndPlayVoice] saved -> ${finalCachedFile.path} len=$len',
      );
      _appendLog('[voice.play] saved ${finalCachedFile.path} len=$len');

      if (len == 0) {
        rootScreenKey.currentState?.showSnack('Downloaded file is empty');
        return;
      }

      try {
        await _playFile(finalCachedFile);
      } catch (e, st) {
        debugPrint('[_downloadAndPlayVoice] playback failed: $e\n$st');
        _appendLog('[voice.play] playback failed: $e');
        showSnack('Play error: $e');
      }
    } catch (e, st) {
      debugPrint('[_downloadAndPlayVoice] unexpected error: $e\n$st');
      _appendLog('[voice.play] unexpected error: $e');
      showSnack('Play error: $e');
    }
  }

  Future<File?> downloadImageToCache(
    String filename, {
    required String peerUsername,
    String? owner,
    String? mediaKeyB64,
  }) async {
    await AppPaths.ensureInit();
    final cacheDir = Directory(AppPaths.imageCache);
    final displayDir = Directory(AppPaths.imageDisplay);

    final existing = await MediaCache.instance
        .findCachedDisplay(cacheDir, [filename], displayDir);
    if (existing != null) return existing;

    final token = await AccountManager.getToken(currentUsername ?? '');
    if (token == null) throw Exception('Not logged in');

    final urlPath = (owner != null && owner.isNotEmpty)
        ? '$serverBase/image/$owner/$filename'
        : '$serverBase/image/$filename';
    final res = await http.get(
      Uri.parse(urlPath),
      headers: {'authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30), onTimeout: () {
      throw Exception('Image download timed out');
    });
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final cipherBytes = res.bodyBytes;
    if (cipherBytes.isEmpty) throw Exception('Empty response');

    final plainBytes = await decryptMediaFromPeer(
      peerUsername,
      cipherBytes,
      kind: 'image',
      mediaKeyB64: mediaKeyB64,
    );

    await MediaCache.instance.writeEncrypted(cacheDir, filename, plainBytes);
    final displayFile = File('${AppPaths.imageDisplay}/$filename');
    await displayFile.writeAsBytes(plainBytes, flush: true);
    return displayFile;
  }

  Future<File?> downloadVoiceToCache(String filename,
      {required String peerUsername, String? mediaKeyB64}) async {
    await AppPaths.ensureInit();
    final cacheDir = Directory('${AppPaths.support}/voice_cache');
    final displayDir = Directory(AppPaths.voiceDisplay);

    final possibleExts = ['', '.ogg', '.opus', '.m4a', '.mp3', '.wav'];
    final candidateNames = possibleExts
        .map((ext) =>
            filename.endsWith(ext) || ext.isEmpty ? filename : '$filename$ext')
        .toList();
    final existing = await MediaCache.instance
        .findCachedDisplay(cacheDir, candidateNames, displayDir);
    if (existing != null) return existing;

    final token = await AccountManager.getToken(currentUsername ?? '');
    if (token == null) throw Exception('Not logged in');
    final res = await http.get(
      Uri.parse('$serverBase/voice/$filename'),
      headers: {'authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final cipherBytes = res.bodyBytes;
    if (cipherBytes.isEmpty) throw Exception('Empty response');

    final bytes = await decryptMediaFromPeer(peerUsername, cipherBytes,
        kind: 'voice', mediaKeyB64: mediaKeyB64);

    String outName = filename;
    if (!_isOgg(bytes) &&
        !_isM4A(bytes) &&
        !_isWav(bytes) &&
        !_isMp3(bytes) &&
        !_isRawOpus(bytes)) {
      outName = filename.endsWith('.m4a') ? filename : '$filename.m4a';
    }
    final safeName = _sanitizeFilename(outName);

    await MediaCache.instance.writeEncrypted(cacheDir, safeName, bytes);
    final displayFile = File('${AppPaths.voiceDisplay}/$safeName');
    await displayFile.writeAsBytes(bytes, flush: true);
    return displayFile;
  }

  Future<File?> downloadVideoToCache(String filename,
      {required String peerUsername, String? mediaKeyB64}) async {
    await AppPaths.ensureInit();
    final cacheDir = Directory('${AppPaths.support}/video_cache');
    final displayDir = Directory(AppPaths.videoDisplay);

    final existing = await MediaCache.instance
        .findCachedDisplay(cacheDir, [filename], displayDir);
    if (existing != null) return existing;

    final token = await AccountManager.getToken(currentUsername ?? '');
    if (token == null) throw Exception('Not logged in');

    final res = await http.get(
      Uri.parse('$serverBase/video/$filename'),
      headers: {'authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final cipherBytes = res.bodyBytes;
    if (cipherBytes.isEmpty) throw Exception('Empty response');

    final bytes = await decryptMediaFromPeer(peerUsername, cipherBytes,
        kind: 'video', mediaKeyB64: mediaKeyB64);

    await MediaCache.instance.writeEncrypted(cacheDir, filename, bytes);
    final displayFile = File('${AppPaths.videoDisplay}/$filename');
    await displayFile.writeAsBytes(bytes, flush: true);
    return displayFile;
  }

  Future<File?> downloadFileToCache(String filename,
      {required String peerUsername,
      String? owner,
      String? mediaKeyB64,
      void Function(double)? onProgress}) async {
    await AppPaths.ensureInit();
    final cacheDir = Directory('${AppPaths.support}/file_cache');
    final displayDir = Directory(AppPaths.fileDisplay);

    final existing = await MediaCache.instance
        .findCachedDisplay(cacheDir, [filename], displayDir);
    if (existing != null) return existing;

    final legacyCacheNames = [
      'file_cache',
      'document_cache',
      'data_cache',
      'archive_cache',
      'image_cache',
      'video_cache',
      'voice_cache',
      'audio_cache',
    ];
    for (final name in legacyCacheNames) {
      final f = File('${AppPaths.support}/$name/$filename');
      if (await f.exists()) {
        debugPrint(
            '[downloadFileToCache] found local cached file in $name: ${f.path}');
        return f;
      }
    }

    final token = await AccountManager.getToken(currentUsername ?? '');
    if (token == null) throw Exception('Not logged in');

    final client = http.Client();
    try {
      final fileUrlPath = (owner != null && owner.isNotEmpty)
          ? '$serverBase/file/$owner/$filename'
          : '$serverBase/file/$filename';
      final request = http.Request('GET', Uri.parse(fileUrlPath));
      request.headers['authorization'] = 'Bearer $token';
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode == 404) {
        debugPrint(
            '[downloadFileToCache] file not found on server: $filename (404)');
        return null;
      }
      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength;
      final chunks = <List<int>>[];
      int received = 0;

      await for (final chunk in streamedResponse.stream) {
        chunks.add(chunk);
        received += chunk.length;
        if (contentLength != null && contentLength > 0 && onProgress != null) {
          onProgress((received / contentLength).clamp(0.0, 1.0));
        }
      }

      final cipherBytes = Uint8List.fromList(chunks.expand((c) => c).toList());
      if (cipherBytes.isEmpty) throw Exception('Empty response');

      final bytes = await decryptMediaFromPeer(peerUsername, cipherBytes,
          kind: 'file', mediaKeyB64: mediaKeyB64);

      await MediaCache.instance.writeEncrypted(cacheDir, filename, bytes);
      final displayFile = File('${AppPaths.fileDisplay}/$filename');
      await displayFile.writeAsBytes(bytes, flush: true);
      return displayFile;
    } finally {
      client.close();
    }
  }

  Future<void> ensureMediaCachedForFavorite(String favId,
      {bool force = false}) async {
    if (!force && _favoritesMediaPrefetched.contains(favId)) return;
    _favoritesMediaPrefetched.add(favId);

    final chatId = 'fav:$favId';
    final msgs = chats[chatId];
    if (msgs == null || msgs.isEmpty) return;

    _appendLog(
        '[fav.prefetch] starting for $favId with ${msgs.length} messages');

    final List<Future<void>> tasks = [];
    for (final m in _recentPrefetchMessages(msgs, limit: 12)) {
      try {
        final text = m.content;
        if (text.startsWith('IMAGEv1:')) {
          final data = jsonDecode(text.substring('IMAGEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            // Skip if ImageLoader already has this file cached or in-flight.
            if (ImageLoader.isKnown(filename)) continue;
            tasks.add(downloadImageToCache(filename,
                    peerUsername: m.from, mediaKeyB64: keyB64)
                .then((_) {
              _appendLog('[fav.prefetch] image cached: $filename');
            }).catchError((e) {
              _appendLog('[fav.prefetch] image $filename failed: $e');
            }));
          }
        } else if (text.toUpperCase().startsWith('VIDEOV1:')) {
          // Respect the auto-load-video setting: when off, don't pull videos in
          // the background — downloading them is a source of jank.
          if (!SettingsManager.autoLoadVideoEnabled.value) continue;
          final prefixLen = 'VIDEOv1:'.length;
          final meta =
              jsonDecode(text.substring(prefixLen)) as Map<String, dynamic>;
          final filename = (meta['filename'] as String?)?.trim();
          final keyB64 = meta['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(downloadVideoToCache(filename,
                    peerUsername: m.from, mediaKeyB64: keyB64)
                .then((_) {
              _appendLog('[fav.prefetch] video cached: $filename');
            }).catchError((e) {
              _appendLog('[fav.prefetch] video $filename failed: $e');
            }));
          }
        } else if (text.startsWith('VOICEv1:')) {
          final data = jsonDecode(text.substring('VOICEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(downloadVoiceToCache(filename,
                    peerUsername: m.from, mediaKeyB64: keyB64)
                .then((_) {
              _appendLog('[fav.prefetch] voice cached: $filename');
            }).catchError((e) {
              _appendLog('[fav.prefetch] voice $filename failed: $e');
            }));
          }
        } else if (text.startsWith('AUDIOv1:')) {
          final data = jsonDecode(text.substring('AUDIOv1:'.length))
              as Map<String, dynamic>;
          final filename =
              (data['filename'] ?? data['orig'] as String?)?.trim();
          if (filename != null && filename.isNotEmpty) {
            tasks.add(
                downloadFileToCache(filename, peerUsername: m.from).then((_) {
              _appendLog('[fav.prefetch] audio cached: $filename');
            }).catchError((e) {
              _appendLog('[fav.prefetch] audio $filename failed: $e');
            }));
          }
        } else if (text.startsWith('FILEv1:')) {
          continue; // skip generic files — see chat prefetch for rationale
        } else if (text.startsWith('MEDIA_PROXYv1:')) {
          try {
            final data = jsonDecode(text.substring('MEDIA_PROXYv1:'.length))
                as Map<String, dynamic>;
            final url = (data['url'] as String?)?.trim();
            final typ = (data['type'] as String?)?.trim();
            if (url != null && url.isNotEmpty) {
              if (typ == 'voice') {
                tasks.add(http.get(Uri.parse(url)).then((res) async {
                  if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                    final appSupport = await getOnyxSupportDirectory();
                    final cacheDir =
                        Directory('${appSupport.path}/voice_cache');
                    await cacheDir.create(recursive: true);
                    final name =
                        _sanitizeFilename(Uri.parse(url).pathSegments.last);
                    final f = File('${cacheDir.path}/$name');
                    await f.writeAsBytes(res.bodyBytes, flush: true);
                    _appendLog('[fav.prefetch] external voice cached: $url');
                  }
                }).catchError((e) {
                  _appendLog('[fav.prefetch] external voice $url failed: $e');
                }));
              } else {
                tasks.add(http.get(Uri.parse(url)).then((res) async {
                  if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                    final appSupport = await getOnyxSupportDirectory();
                    final isImage = (data['orig'] as String? ?? '')
                            .toLowerCase()
                            .contains('jpg') ||
                        url.toLowerCase().contains('.jpg') ||
                        url.toLowerCase().contains('.png');
                    final cacheDir = Directory(
                        '${appSupport.path}/${isImage ? 'image_cache' : 'video_cache'}');
                    await cacheDir.create(recursive: true);
                    final name =
                        _sanitizeFilename(Uri.parse(url).pathSegments.last);
                    final f = File('${cacheDir.path}/$name');
                    await f.writeAsBytes(res.bodyBytes, flush: true);
                  }
                }).catchError((e) {
                  _appendLog('[fav.prefetch] external media $url failed: $e');
                }));
              }
            }
          } catch (e) {
            _appendLog('[fav.prefetch] MEDIA_PROXY parse error: $e');
          }
        }
      } catch (e) {
        _appendLog('[fav.prefetch] message parse error: $e');
      }

      if (tasks.length >= 2) {
        await Future.wait(tasks);
        tasks.clear();
        await Future.delayed(Duration.zero);
      }
    }

    if (tasks.isNotEmpty) await Future.wait(tasks);
    _appendLog('[fav.prefetch] completed for $favId');
  }

  bool _messageHasPrefetchableMedia(String text) {
    return text.startsWith('IMAGEv1:') ||
        text.toUpperCase().startsWith('VIDEOV1:') ||
        text.startsWith('VOICEv1:') ||
        text.startsWith('AUDIOv1:') ||
        text.startsWith('FILEv1:') ||
        text.startsWith('MEDIA_PROXYv1:');
  }

  bool _isHttp404Error(Object error) => error.toString().contains('HTTP 404');

  String _prefetchMediaKey(String kind, String id) => '$kind::$id';

  Iterable<ChatMessage> _recentPrefetchMessages(
    List<ChatMessage> messages, {
    int limit = 8,
  }) sync* {
    final selected = <ChatMessage>[];
    for (final message in messages.reversed) {
      if (_messageHasPrefetchableMedia(message.content)) {
        selected.add(message);
        if (selected.length >= limit) break;
      }
    }
    yield* selected.reversed;
  }

  Future<void> ensureMediaCachedForChat(String chatId,
      {bool force = false}) async {
    if (!force && _chatsMediaPrefetched.contains(chatId)) return;
    _chatsMediaPrefetched.add(chatId);

    final msgs = chats[chatId];
    if (msgs == null || msgs.isEmpty) return;

    _appendLog(
        '[chat.prefetch] starting for $chatId with ${msgs.length} messages');

    final List<Future<void>> tasks = [];
    for (final m in _recentPrefetchMessages(msgs)) {
      try {
        final text = m.content;
        if (text.startsWith('IMAGEv1:')) {
          final data = jsonDecode(text.substring('IMAGEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            final prefetchKey = _prefetchMediaKey('image', filename);
            if (_missingPrefetchMedia.contains(prefetchKey)) continue;
            // Skip if ImageLoader already has this file cached or in-flight.
            if (ImageLoader.isKnown(filename)) continue;
            tasks.add(downloadImageToCache(filename,
                    peerUsername: m.from, mediaKeyB64: keyB64)
                .then((_) {
              _appendLog('[chat.prefetch] image cached: $filename');
            }).catchError((e) {
              if (_isHttp404Error(e)) {
                _missingPrefetchMedia.add(prefetchKey);
                return;
              }
              _appendLog('[chat.prefetch] image $filename failed: $e');
            }));
          }
        } else if (text.toUpperCase().startsWith('VIDEOV1:')) {
          // Respect the auto-load-video setting: skip background video pulls
          // when off (avoids the jank of downloading videos unprompted).
          if (!SettingsManager.autoLoadVideoEnabled.value) continue;
          final prefixLen = 'VIDEOv1:'.length;
          final meta =
              jsonDecode(text.substring(prefixLen)) as Map<String, dynamic>;
          final filename = (meta['filename'] as String?)?.trim();
          final keyB64 = meta['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            final prefetchKey = _prefetchMediaKey('video', filename);
            if (_missingPrefetchMedia.contains(prefetchKey)) continue;
            tasks.add(downloadVideoToCache(filename,
                    peerUsername: m.from, mediaKeyB64: keyB64)
                .then((_) {
              _appendLog('[chat.prefetch] video cached: $filename');
            }).catchError((e) {
              if (_isHttp404Error(e)) {
                _missingPrefetchMedia.add(prefetchKey);
                return;
              }
              _appendLog('[chat.prefetch] video $filename failed: $e');
            }));
          }
        } else if (text.startsWith('VOICEv1:')) {
          final data = jsonDecode(text.substring('VOICEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            final prefetchKey = _prefetchMediaKey('voice', filename);
            if (_missingPrefetchMedia.contains(prefetchKey)) continue;
            tasks.add(downloadVoiceToCache(filename,
                    peerUsername: m.from, mediaKeyB64: keyB64)
                .then((_) {
              _appendLog('[chat.prefetch] voice cached: $filename');
            }).catchError((e) {
              if (_isHttp404Error(e)) {
                _missingPrefetchMedia.add(prefetchKey);
                return;
              }
              _appendLog('[chat.prefetch] voice $filename failed: $e');
            }));
          }
        } else if (text.startsWith('AUDIOv1:')) {
          final data = jsonDecode(text.substring('AUDIOv1:'.length))
              as Map<String, dynamic>;
          final filename =
              (data['filename'] ?? data['orig'] as String?)?.trim();
          if (filename != null && filename.isNotEmpty) {
            final prefetchKey = _prefetchMediaKey('audio', filename);
            if (_missingPrefetchMedia.contains(prefetchKey)) continue;
            tasks.add(downloadFileToCache(filename, peerUsername: m.from)
                .then((file) {
              if (file == null) {
                _missingPrefetchMedia.add(prefetchKey);
                return;
              }
              _appendLog('[chat.prefetch] audio cached: $filename');
            }).catchError((e) {
              if (_isHttp404Error(e)) {
                _missingPrefetchMedia.add(prefetchKey);
                return;
              }
              _appendLog('[chat.prefetch] audio $filename failed: $e');
            }));
          }
        } else if (text.startsWith('FILEv1:')) {
          // Generic file attachments (archives, scripts, documents, etc.) are
          // not displayed inline and are only opened by explicit user action.
          // Pre-downloading them during prefetch blocks the UI isolate during
          // decryption of large files — skip entirely.
          continue;
        } else if (text.startsWith('MEDIA_PROXYv1:')) {
          try {
            final data = jsonDecode(text.substring('MEDIA_PROXYv1:'.length))
                as Map<String, dynamic>;
            final url = (data['url'] as String?)?.trim();
            final typ = (data['type'] as String?)?.trim();
            if (url != null && url.isNotEmpty) {
              final prefetchKey = _prefetchMediaKey(
                typ == 'voice' ? 'external_voice' : 'external_media',
                url,
              );
              if (_missingPrefetchMedia.contains(prefetchKey)) continue;
              if (typ == 'voice') {
                tasks.add(http.get(Uri.parse(url)).then((res) async {
                  if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                    final appSupport = await getOnyxSupportDirectory();
                    final cacheDir =
                        Directory('${appSupport.path}/voice_cache');
                    await cacheDir.create(recursive: true);
                    final name =
                        _sanitizeFilename(Uri.parse(url).pathSegments.last);
                    final f = File('${cacheDir.path}/$name');
                    await f.writeAsBytes(res.bodyBytes, flush: true);
                    _appendLog('[chat.prefetch] external voice cached: $url');
                  } else if (res.statusCode == 404) {
                    _missingPrefetchMedia.add(prefetchKey);
                  }
                }).catchError((e) {
                  if (_isHttp404Error(e)) {
                    _missingPrefetchMedia.add(prefetchKey);
                    return;
                  }
                  _appendLog('[chat.prefetch] external voice $url failed: $e');
                }));
              } else {
                tasks.add(http.get(Uri.parse(url)).then((res) async {
                  if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                    final appSupport = await getOnyxSupportDirectory();
                    final isImage = (data['orig'] as String? ?? '')
                            .toLowerCase()
                            .contains('jpg') ||
                        url.toLowerCase().contains('.jpg') ||
                        url.toLowerCase().contains('.png');
                    final cacheDir = Directory(
                        '${appSupport.path}/${isImage ? 'image_cache' : 'video_cache'}');
                    await cacheDir.create(recursive: true);
                    final name =
                        _sanitizeFilename(Uri.parse(url).pathSegments.last);
                    final f = File('${cacheDir.path}/$name');
                    await f.writeAsBytes(res.bodyBytes, flush: true);
                  } else if (res.statusCode == 404) {
                    _missingPrefetchMedia.add(prefetchKey);
                  }
                }).catchError((e) {
                  if (_isHttp404Error(e)) {
                    _missingPrefetchMedia.add(prefetchKey);
                    return;
                  }
                  _appendLog('[chat.prefetch] external media $url failed: $e');
                }));
              }
            }
          } catch (e) {
            _appendLog('[chat.prefetch] MEDIA_PROXY parse error: $e');
          }
        }
      } catch (e) {
        _appendLog('[chat.prefetch] message parse error: $e');
      }

      if (tasks.length >= 2) {
        await Future.wait(tasks);
        tasks.clear();
        await Future.delayed(Duration.zero);
      }
    }

    if (tasks.isNotEmpty) await Future.wait(tasks);
    _appendLog('[chat.prefetch] completed for $chatId');
  }

  Future<void> _prefetchTopChatsMedia([int limit = 5]) async {
    try {
      final entries = chats.entries
          .where((e) => !e.key.startsWith('fav:') && e.value.isNotEmpty)
          .toList();
      entries.sort((a, b) => b.value.last.time.compareTo(a.value.last.time));
      final toPrefetch = entries.take(limit).map((e) => e.key).toList();
      for (final id in toPrefetch) {
        if (!mounted) break;
        await ensureMediaCachedForChat(id);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('[chat.prefetch] error: $e');
    }
  }

  bool _autoBackupChecked = false;

  Future<void> _loadChatsFromCacheNow([String? username]) async {
    final uname =
        username ?? currentUsername ?? await AccountManager.getCurrentAccount();
    if (uname == null) {
      _chatsLoadCompleter?.complete();
      return;
    }
    try {
      final cached = await AccountManager.loadChats(uname);
      if (mounted) {
        setState(() {
          final merged = Map<String, List<ChatMessage>>.from(cached);
          for (final entry in chats.entries) {
            if (!merged.containsKey(entry.key)) {
              merged[entry.key] = entry.value;
            } else {
              final cachedServerIds = merged[entry.key]!
                  .where((m) => m.serverMessageId != null)
                  .map((m) => m.serverMessageId!)
                  .toSet();
              final cachedLocalIds = merged[entry.key]!
                  .where((m) => m.serverMessageId == null)
                  .map((m) => m.id)
                  .toSet();
              for (final msg in entry.value) {
                final isDup = msg.serverMessageId != null
                    ? cachedServerIds.contains(msg.serverMessageId)
                    : cachedLocalIds.contains(msg.id);
                if (!isDup) {
                  merged[entry.key]!.add(msg);
                }
              }
            }
          }
          chats = merged;
          _buildServerMsgIndex();
        });
        chatsVersion.value++;
        unawaited(_warmRecentUserProfiles());
        // Scheduled local backup — runs at most once per session, only if the
        // configured interval has elapsed (no-op otherwise).
        if (!_autoBackupChecked) {
          _autoBackupChecked = true;
          Future.delayed(const Duration(seconds: 5), () {
            unawaited(BackupService.runScheduledIfDue(
                username: uname, chats: chats));
          });
        }
        Future.delayed(const Duration(seconds: 20), () {
          if (mounted) _prefetchTopChatsMedia(1);
        });
        _appendLog('[chats] quick cache load ${chats.length} chats for $uname');
      }
    } catch (e) {
      debugPrint('[chats] quick cache load failed: $e');
    } finally {
      _chatsLoadCompleter?.complete();
    }
  }

  void _addFavorite(FavoriteChat fav) {
    setState(() {
      _favorites.add(fav);
      _favTopOrder.insert(0, fav.id);
    });
    _saveFavorites();
    _saveFavStructure();
    favoritesVersion.value++;
    Future.microtask(() => ensureMediaCachedForFavorite(fav.id));
  }

  void _deleteFavorite(String id) {
    final chatId = 'fav:$id';

    // Capture before deletion so cleanup can run asynchronously
    String? avatarPath;
    String favTitle = id;
    try {
      final fav = _favorites.firstWhere((f) => f.id == id);
      avatarPath = fav.avatarPath;
      favTitle = fav.title;
    } catch (_) {}
    final deletedMessages = List<ChatMessage>.from(chats[chatId] ?? []);

    TrashManager.instance.addDeletedChat(TrashedChat(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      chatId: chatId,
      displayName: favTitle,
      type: TrashedChatType.favorite,
      messages: deletedMessages,
      deletedAt: DateTime.now(),
    ));

    setState(() {
      _favorites.removeWhere((f) => f.id == id);
      if (_selectedFavoriteId == id) _selectedFavoriteId = null;
      _favTopOrder.remove(id);
      for (final folder in _favFolders) {
        folder.chatIds.remove(id);
      }
    });
    _saveFavorites();
    _saveFavStructure();

    chats.remove(chatId);
    // Remove the on-disk chat file too, otherwise the messages linger as an
    // orphan and reload on next launch (saveChats only writes, never deletes).
    if (currentUsername != null) {
      unawaited(AccountManager.deleteChatFile(currentUsername!, chatId));
    }
    persistChats();
    chatsVersion.value++;

    // Record a tombstone so WardLink propagates this deletion to paired devices,
    // and poke them now so it applies immediately.
    WardLinkTombstones.recordFavDeleted(id);
    WardLinkSyncService.instance.pokeNow();

    _cleanupFavoriteCache(deletedMessages, avatarPath);
  }

  /// Apply favourite/message deletions received via WardLink. The tombstones are
  /// already merged into [WardLinkTombstones] by the sync engine; here we just
  /// remove the items locally. Cache cleanup runs for removed favourites.
  void applyRemoteDeletions(
    Set<String> favIds,
    Map<String, Set<String>> msgsByChat,
  ) {
    bool changed = false;
    final List<ChatMessage> orphanedMessages = [];
    final Set<String> bumpedChatIds = {};

    setState(() {
      for (final favId in favIds) {
        final chatId = 'fav:$favId';
        if (_favorites.any((f) => f.id == favId)) {
          _favorites.removeWhere((f) => f.id == favId);
          if (_selectedFavoriteId == favId) _selectedFavoriteId = null;
          _favTopOrder.remove(favId);
          for (final folder in _favFolders) {
            folder.chatIds.remove(favId);
          }
          changed = true;
        }
        final removed = chats.remove(chatId);
        if (removed != null) {
          orphanedMessages.addAll(removed);
          changed = true;
        }
        if (currentUsername != null) {
          unawaited(AccountManager.deleteChatFile(currentUsername!, chatId));
        }
      }
      for (final entry in msgsByChat.entries) {
        final list = chats[entry.key];
        if (list == null) continue;
        final before = list.length;
        list.removeWhere((m) {
          if (entry.value.contains(m.id)) {
            orphanedMessages.add(m);
            return true;
          }
          return false;
        });
        if (list.length != before) {
          changed = true;
          bumpedChatIds.add(entry.key);
        }
      }
    });

    if (changed) {
      // Notify open chat screens immediately so deleted messages disappear in
      // real-time without requiring the user to leave and re-enter the chat.
      for (final chatId in bumpedChatIds) {
        bumpChatMessageVersion(chatId);
      }
      _saveFavorites();
      _saveFavStructure(touch: false);
      // Force a full save: incremental saves (scheduled by concurrent importFavorites
      // calls) would skip the chat(s) where messages were just removed, leaving the
      // old data on disk and causing deleted messages to reappear after app restart.
      _fullSaveRequested = true;
      unawaited(persistChats());
      favoritesVersion.value++;
      chatsVersion.value++;
      if (orphanedMessages.isNotEmpty) {
        unawaited(_cleanupFavoriteCache(orphanedMessages, null));
      }
    }
  }

  /// Public entry point used by [FavoritesScreen._deleteMessage] to clean up
  /// media for a single deleted message without having a full favourite to drop.
  void cleanupOrphanedMessages(List<ChatMessage> msgs) {
    _cleanupFavoriteCache(msgs, null);
  }

  // Deletes cached media files that are no longer referenced by any chat.
  Future<void> _cleanupFavoriteCache(
      List<ChatMessage> deletedMessages, String? avatarPath) async {
    try {
      if (deletedMessages.isEmpty && avatarPath == null) return;
      final appDir = (await getOnyxSupportDirectory()).path;
      final docDir = (await getOnyxDocumentsDirectory()).path;

      // Files referenced by the deleted chat
      final candidates = <({String basename, List<String> cacheDirs})>[];
      for (final msg in deletedMessages) {
        candidates.addAll(_parseMsgFiles(msg.content));
      }

      // Basenames still in use by any remaining chat
      final stillUsed = <String>{};
      for (final msgs in chats.values) {
        for (final msg in msgs) {
          for (final f in _parseMsgFiles(msg.content)) {
            stillUsed.add(f.basename);
          }
        }
      }

      // Delete orphaned files from disk and runtime caches.
      // Search both applicationSupport and applicationDocuments because:
      //   • regular cached files live in appSupport/<type>_cache
      //   • fav:// files written by WardLink/LanFavSync live in
      //     appDocuments/fav_media  (non-voice) or appDocuments/voice_cache
      for (final f in candidates) {
        if (stillUsed.contains(f.basename)) continue;
        imageFileCache.remove(f.basename);
        mediaFilePathRegistry.remove(f.basename);
        mediaFilePathRegistry.remove('fav://${f.basename}');
        // All candidate directories across both storage roots.
        final searchPaths = [
          for (final dir in f.cacheDirs) ...[
            '$appDir/$dir',
            '$docDir/$dir',
          ],
          // fav_media holds fav:// assets regardless of media type.
          '$docDir/fav_media',
        ];
        for (final dir in searchPaths) {
          for (final name in [f.basename, '${f.basename}.enc']) {
            try {
              final file = File('$dir/$name');
              if (await file.exists()) await file.delete();
            } catch (_) {}
          }
        }
      }

      // Avatar
      if (avatarPath != null) {
        try {
          final f = File(avatarPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('[FavCleanup] error: $e');
    }
  }

  static Iterable<({String basename, List<String> cacheDirs})> _parseMsgFiles(
      String content) sync* {
    String fn(Map<String, dynamic> d) =>
        p.basename((d['filename'] ?? d['orig'])?.toString() ?? '');

    if (content.startsWith('IMAGEv1:')) {
      try {
        final n = fn(jsonDecode(content.substring(8)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['image_cache']);
      } catch (_) {}
      return;
    }
    if (content.startsWith('ALBUMv1:')) {
      try {
        for (final item
            in (jsonDecode(content.substring(8)) as List).cast<Map<String, dynamic>>()) {
          final n = fn(item);
          if (n.isNotEmpty) yield (basename: n, cacheDirs: ['image_cache']);
        }
      } catch (_) {}
      return;
    }
    if (content.toUpperCase().startsWith('VIDEOV1:')) {
      try {
        final n = fn(jsonDecode(content.substring(8)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['video_cache']);
      } catch (_) {}
      return;
    }
    if (content.startsWith('VOICEv1:')) {
      try {
        final n = fn(jsonDecode(content.substring(8)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['voice_cache', 'audio_cache']);
      } catch (_) {}
      return;
    }
    if (content.startsWith('AUDIOv1:')) {
      try {
        final n = fn(jsonDecode(content.substring(8)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['audio_cache']);
      } catch (_) {}
      return;
    }
    if (content.startsWith('FILEv1:') || content.startsWith('DATAv1:')) {
      try {
        final n = fn(jsonDecode(content.substring(7)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['data_cache']);
      } catch (_) {}
      return;
    }
    if (content.startsWith('DOCUMENTv1:')) {
      try {
        final n = fn(jsonDecode(content.substring(11)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['document_cache']);
      } catch (_) {}
      return;
    }
    if (content.startsWith('ARCHIVEv1:')) {
      try {
        final n = fn(jsonDecode(content.substring(10)) as Map<String, dynamic>);
        if (n.isNotEmpty) yield (basename: n, cacheDirs: ['archive_cache']);
      } catch (_) {}
      return;
    }
  }

  /// Scans all cache directories and deletes files not referenced by any chat.
  /// Returns the number of deleted files and total freed bytes.
  Future<int> scanOrphanedCacheBytes() async {
    final appDir = (await getOnyxSupportDirectory()).path;
    final kept = <String>{};
    for (final msgs in chats.values) {
      for (final msg in msgs) {
        for (final f in _parseMsgFiles(msg.content)) {
          kept.add(f.basename);
        }
      }
    }
    for (final fav in _favorites) {
      if (fav.avatarPath != null) kept.add(p.basename(fav.avatarPath!));
    }
    const dirs = ['image_cache', 'video_cache', 'audio_cache', 'voice_cache', 'document_cache', 'archive_cache', 'data_cache', 'fav_avatars'];
    int totalBytes = 0;
    for (final dirName in dirs) {
      final dir = Directory('$appDir/$dirName');
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        var base = p.basename(entity.path);
        if (base.endsWith('.enc')) base = base.substring(0, base.length - 4);
        if (kept.contains(base)) continue;
        try { totalBytes += await entity.length(); } catch (_) {}
      }
    }
    return totalBytes;
  }

  Future<({int files, int bytes})> purgeOrphanedCache() async {
    final appDir = (await getOnyxSupportDirectory()).path;

    // Collect every basename referenced by any chat message
    final kept = <String>{};
    for (final msgs in chats.values) {
      for (final msg in msgs) {
        for (final f in _parseMsgFiles(msg.content)) {
          kept.add(f.basename);
        }
      }
    }
    // Keep avatar files of current favorites
    for (final fav in _favorites) {
      if (fav.avatarPath != null) kept.add(p.basename(fav.avatarPath!));
    }

    const dirs = [
      'image_cache', 'video_cache', 'audio_cache', 'voice_cache',
      'document_cache', 'archive_cache', 'data_cache', 'fav_avatars',
    ];

    int deletedFiles = 0;
    int deletedBytes = 0;

    for (final dirName in dirs) {
      final dir = Directory('$appDir/$dirName');
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        var base = p.basename(entity.path);
        if (base.endsWith('.enc')) base = base.substring(0, base.length - 4);
        if (kept.contains(base)) continue;
        try {
          final size = await entity.length();
          await entity.delete();
          deletedFiles++;
          deletedBytes += size;
          imageFileCache.remove(base);
          mediaFilePathRegistry.remove(base);
        } catch (_) {}
      }
    }

    return (files: deletedFiles, bytes: deletedBytes);
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.speech());
      print('<<_configureAudioSession>> configured as speech (speaker on)');
    } catch (e, st) {
      print('<<_configureAudioSession>> configure error: $e\n$st');
    }
  }

  void _onTabSelected(int i) {
    if (!mounted) return;
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);

    if (i == 0 || i == 1 || i == 2 || i == 3) {
      if (isDesktop) {
        setState(() {
          selectedChatOther = null;
          selectedGroup = null;
          selectedExternalGroup = null;
          selectedExternalServer = null;
          _selectedFavoriteId = null;
          _index = i;
        });
      } else {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
        setState(() => _index = i);
      }
    } else {
      setState(() => _index = i);
    }

    if (_pageController.hasClients) {
      _pageController.jumpToPage(i + _graphTabOffset);
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onGlobalKeyEvent);
    _motivationalHintIndex = Random().nextInt(_motivationalHints.length);

    if (!kIsWeb && Platform.isWindows) {
      WindowsNotificationPopup.onNotificationTapped((username) async {
        // Defer to next event loop turn to avoid Win32 re-entrancy:
        // ShowWindow (called by windowManager.show) can dispatch synchronous
        // Win32 messages that trigger a Flutter frame build; calling setState
        // while a build is in progress causes an assertion crash.
        await Future.delayed(Duration.zero);
        if (!mounted) return;

        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (e) {
          debugPrint('[WindowNotification] Error focusing window: $e');
        }

        // Ensure any frame triggered by window restoration has completed
        // before we call setState, to prevent "setState during build" crashes.
        if (!mounted) return;
        final completer = Completer<void>();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => completer.complete());
        await completer.future;
        if (!mounted) return;

        final chatId = chatIdForUser(username);
        chats.putIfAbsent(chatId, () => []);
        if (isDesktop) {
          NotificationService.clearMessagesForUser(username);
          setState(() {
            selectedChatOther = username;
            selectedGroup = null;
            selectedExternalGroup = null;
            selectedExternalServer = null;
          });
          _checkKeyChangeOnChatOpen(username);
        } else {
          NotificationService.clearMessagesForUser(username);
          // Direct assignment — no setState needed before push on mobile
          // (selectedChatOther is only read by message-handlers, not build).
          // Calling setState here would force a full RootScreen rebuild right
          // before the navigation animation starts, causing jitter.
          selectedChatOther = username;
          _checkKeyChangeOnChatOpen(username);
          Navigator.of(context)
              .push(
            _chatRoute((_) => ChatScreen(
                  myUsername: currentUsername ?? 'me',
                  otherUsername: username,
                  onSend: (t, replyTo) =>
                      _sendChatMessage(username, t, replyTo),
                  onTyping: () => _handleSendTyping(username),
                  onRequestResend: (id) {
                    if (id != null) _requestResend(id);
                  },
                  onEditMessage: (id, text) =>
                      _editChatMessage(username, id, text),
                  onDeleteMessage: (id) => _deleteChatMessage(id),
                )),
          )
              .then((_) {
            if (mounted)
              setState(() {
                selectedChatOther = null;
              });
          });
        }
      });
    }

    _initBackground();

    _configureAudioSession();

    // Set decoy identity before the first build so currentUsername is non-null
    // and the "no account" screen never flashes.
    if (DecoyManager.isActive.value) {
      currentUsername = DecoyManager.username;
      currentDisplayName = DecoyManager.displayName;
    }

    _initializeAccountAndConnect();

    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

    _pageController = PageController(initialPage: _index + _graphTabOffset);
    SettingsManager.showAccountGraph.addListener(_onShowGraphChanged);
    callManager.init(getWs: () => _ws);

    // Route voice channel signaling to VoiceChannelManager
    ExternalServerManager.setVoiceListener((msg, serverId) async {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return;
      await VoiceChannelManager.instance.handleMessage(msg, username, serverId);
    });

    callManager.isIncomingCall.addListener(_onCallStateChanged);
    callManager.isInCall.addListener(_onCallStateChanged);
    callManager.isConnecting.addListener(_onCallStateChanged);
    callManager.isRemoteVideoEnabled.addListener(_onCallStateChanged);

    Future.delayed(const Duration(seconds: 5), _scheduleUpdateCheck);

    _notificationSubscription =
        NotificationService.openChatStream.listen((other) {
      if (!mounted) return;
      NotificationService.clearMessagesForUser(other);

      if (isDesktop) {
        setState(() {
          selectedChatOther = other;
          selectedGroup = null;
          selectedExternalGroup = null;
          selectedExternalServer = null;
          _selectedFavoriteId = null;
        });
        _checkKeyChangeOnChatOpen(other);

        _markChatAsRead(other);
        return;
      }

      // Same: no setState before push on mobile (avoids ChatsTab rebuild during animation).
      selectedChatOther = other;
      _checkKeyChangeOnChatOpen(other);
      Navigator.of(context)
          .push(
        _chatRoute((_) => ChatScreen(
              myUsername: currentUsername ?? 'me',
              otherUsername: other,
              onSend: (t, replyTo) => _sendChatMessage(other, t, replyTo),
              onTyping: () => _handleSendTyping(other),
              onRequestResend: (id) {
                if (id != null) _requestResend(id);
              },
              onEditMessage: (id, text) => _editChatMessage(other, id, text),
              onDeleteMessage: (id) => _deleteChatMessage(id),
            )),
      )
          .then((_) {
        if (mounted)
          setState(() {
            selectedChatOther = null;
          });
        _sendPresence('online');

        _markChatAsRead(other);
      });
    });
  }

  Future<void> _scheduleUpdateCheck() async {
    final info = await UpdateChecker.checkForUpdates(kAppVersion);
    if (info != null && mounted) {
      updateInfoNotifier.value = info;
    }
  }

  Future<void> _initBackground() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
    } else {
      debugPrint('[background] workmanager skipped on this platform');
    }

    await NotificationService.init();

    if (await AccountManager.isLoggedIn) {
      await registerAdaptiveSync();
    }
  }

  void _handleKeyOrMouseBack() {
    if (!isDesktop) return;

    // Check if there are any popup routes (dialogs/image viewers) open.
    // If yes — close only them, don't close the chat.
    bool hadPopup = false;
    try {
      Navigator.of(context).popUntil((route) {
        if (route is PopupRoute) {
          hadPopup = true;
          return false; // keep popping
        }
        return true; // stop at non-popup
      });
    } catch (_) {}

    if (hadPopup) return; // closed a dialog — stay in chat

    if (selectedChatOther != null ||
        selectedGroup != null ||
        selectedExternalGroup != null ||
        _selectedFavoriteId != null) {
      setState(() {
        selectedChatOther = null;
        selectedGroup = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
        _selectedFavoriteId = null;
      });
    }
  }

  void hideDetailPanel() {
    try {
      Navigator.of(context).popUntil((route) => route is! PopupRoute);
    } catch (_) {}

    setState(() {
      selectedChatOther = null;
      selectedGroup = null;
      selectedExternalGroup = null;
      selectedExternalServer = null;
      _selectedFavoriteId = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (callManager.isInCall.value) {
        callManager.hangup();
      }
    }

    // ── Background keep-alive (Android / iOS) ────────────────────────────────
    // When the app is backgrounded, start a Foreground Service so the OS does
    // not kill the process.  The WebSocket lives in this same process and
    // continues to receive messages and fire local notifications.
    if (!kIsWeb && !isDesktop) {
      if (state == AppLifecycleState.paused) {
        FlutterForegroundTask.startService(
          serviceId: 1001,
          notificationTitle: 'Onyx',
          notificationText: 'Connected — receiving messages',
          callback: onyxForegroundTaskEntryPoint,
        );
        _appendLog(
            '[lifecycle] Foreground service started (background keep-alive)');
      } else if (state == AppLifecycleState.resumed) {
        FlutterForegroundTask.stopService();
        _appendLog('[lifecycle] Foreground service stopped (app foregrounded)');
      }
    }

    if (state == AppLifecycleState.resumed) {
      // Cancel any running reconnect loop so we don't wait for its backoff.
      // Then connect immediately with a short delay for the OS to settle.
      _stopReconnectLoop();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (_ws == null || _ws!.closeCode != null) {
          _appendLog('[lifecycle] App resumed — reconnecting immediately');
          _connectWs();
        } else {
          _sendPresence('online');
        }
        ExternalServerManager.reconnectIfNeeded();
      });
    }

    if (state == AppLifecycleState.detached && isDesktop) {
      try {
        _sendPresence('offline');
      } catch (e) {
        _appendLog('[lifecycle] failed to send offline presence: $e');
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    ExternalServerManager.reconnectIfNeeded();
  }

  void _onCallStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    callManager.isIncomingCall.removeListener(_onCallStateChanged);
    callManager.isInCall.removeListener(_onCallStateChanged);
    callManager.isConnecting.removeListener(_onCallStateChanged);
    callManager.isRemoteVideoEnabled.removeListener(_onCallStateChanged);

    callManager.cleanup();

    ExternalServerManager.clearVoiceListener();
    VoiceChannelManager.instance.leaveChannel();

    _persistChatsTimer?.cancel();
    if (_hasPendingPersist) {
      unawaited(persistChats());
    }

    _pageChangeDebounce?.cancel();
    _graphUnmountTimer?.cancel();

    try {
      _notificationSubscription?.cancel();
    } catch (_) {}
    try {
      _wsSub?.cancel();
    } catch (_) {}

    _audioPlayer.dispose();

    _recorder.dispose();

    try {
      _pulseController.dispose();
    } catch (_) {}

    _disconnectWs();
    HardwareKeyboard.instance.removeHandler(_onGlobalKeyEvent);
    SettingsManager.showAccountGraph.removeListener(_onShowGraphChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    if (!isDesktop) return;
    if (!SettingsManager.notifSoundEnabled.value) return;
    try {
      final sound = SettingsManager.notifSound.value;
      if (sound.startsWith('custom:')) {
        final path = sound.substring(7);
        await _audioPlayer.play(DeviceFileSource(path));
      } else {
        await _audioPlayer.play(AssetSource('$sound.wav'));
      }
    } catch (e) {
      debugPrint('[sound] error playing notification: $e');
    }
  }

  void _initializeAccountAndConnect() {
    if (DecoyManager.isActive.value) {
      _initDecoyMode();
      return;
    }
    unawaited(AccountManager.loadStatusSettings());
    unawaited(AccountManager.loadPrivacySettings());
    _loadCurrentAccount();
  }

  Future<void> _initDecoyMode() async {
    await DecoyDataManager.load();
    if (!mounted) return;

    for (final contact in DecoyDataManager.contacts) {
      UserCache.seed(contact.username, contact.displayName);
    }

    // Mutate chats in-place so widget.chats in ChatsTab keeps the same reference.
    // Replacing chats = newMap causes _rebuildSummaries to read the old empty map
    // because ValueNotifier listeners fire synchronously before setState renders.
    final fakeChats = DecoyDataManager.buildChatMap(currentUsername!);
    chats.clear();
    chats.addAll(fakeChats);
    setState(() {
      _favorites = List.from(DecoyDataManager.fakeFavorites);
      // FavoritesTab renders from _favTopOrder, not _favorites directly —
      // without this the fake favorites would never actually appear.
      _ensureFavTopOrder();
    });

    // Now safe to bump — ChatsTab's widget.chats already has the data.
    chatsVersion.value++;
    groupsVersion.value++;

    // Simulate connecting → connected after short delay
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted && DecoyManager.isActive.value) {
      wsConnectedNotifier.value = true;
    }

    _appendLog('[decoy] Decoy mode active');
  }

  Future<void> _loadCurrentAccount() async {
    final username = await AccountManager.getCurrentAccount();

    if (username != null) {
      unawaited(AccountManager.touchLastUsed(username));

      _chatsLoadCompleter = Completer<void>();

      Future.microtask(() => _loadChatsFromCacheNow(username));

      await _loadAccountData(username);

      if (_identityPublicKey == null) {
        _appendLog('[startup] identity missing — generating...');
        await _generateIdentity();
        if (currentUsername != null) {
          chats = await AccountManager.loadChats(username);
          final extracted = await _identityKeyPair!.extract();
          List<int> privBytes;
          if (extracted is SimpleKeyPairData) {
            privBytes = extracted.bytes;
          } else {
            privBytes = (extracted as dynamic).bytes as List<int>;
          }
          await AccountManager.saveIdentity(
            currentUsername!,
            base64Encode(privBytes),
            identityPubKeyBase64!,
          );
        }
      }

      if (currentUsername != null) {
        LANMessageManager().onMessageReceived = (message) {
          _handleIncomingLANMessage(message);
        };
        LANMessageManager().onMediaReceived =
            (mediaType, filename, data, from, to, replyTo) {
          _handleIncomingLANMedia(mediaType, filename, data, from, to, replyTo);
        };
        LANMessageManager().onKeyMismatch = (username, fingerprint) {
          // Key rotation is expected (ephemeral keys change on every launch).
          // No user-visible notification needed.
          if (kDebugMode) {
            debugPrint('[LAN] Key rotated for $username: $fingerprint');
          }
        };

        // Load deletion tombstones so removals are recorded even before any
        // sync, then start WardLink passive sync if the user enabled it.
        unawaited(WardLinkTombstones.load(currentUsername!));
        if (SettingsManager.wardLinkEnabled.value) {
          unawaited(WardLinkSyncService.instance.start(currentUsername!));
        }
      }

      final wsReadyFuture = _ensurePubkeyAndWsReady(
        maxRetries: 10,
        retryDelay: const Duration(milliseconds: 100),
      );

      unawaited(_loadFavorites());


      unawaited(ExternalServerManager.loadServers().then((_) {
        return ExternalServerManager.refreshAllExternalGroups();
      }).catchError((e) {
        _appendLog('[ext-servers] init failed: $e');
      }));

      final ready = await wsReadyFuture;
      if (!ready) {
        showSnack('Account loaded, but connection failed. Retrying...');
      }
    } else {
      _appendLog(
          '[startup] no saved account, checking for available accounts...');

      final accounts = await AccountManager.getAccountsList();
      if (accounts.isNotEmpty) {
        _appendLog('[startup] auto-logging in to ${accounts.first}');
        await _switchToAccount(accounts.first);
      } else {
        _appendLog('[startup] no accounts available, show login screen');
        currentUsername = null;
      }
    }

    setState(() {});
  }

  Future<void> _loadAccountData(String username) async {
    _identityKeyPair = null;
    _identityPublicKey = null;
    identityPubKeyBase64 = null;
    currentUsername = username;
    currentUin = null;
    unawaited(TrashManager.instance.load(username));

    final uinPrefs = await SharedPreferences.getInstance();
    final cachedUin = uinPrefs.getString('uin_$username');
    if (cachedUin != null) currentUin = cachedUin;

    final cachedIsPrimary =
        await SecureStore.read('is_primary_device_$username');
    if (mounted) setState(() => _isPrimaryDevice = cachedIsPrimary == 'true');

    Future(() async {
      try {
        final tok = await AccountManager.getToken(username);
        if (tok == null || !mounted) return;
        final isPrimaryRes = await http.get(
          Uri.parse('$serverBase/me/is-primary'),
          headers: {'authorization': 'Bearer $tok'},
        ).timeout(const Duration(seconds: 5));
        if (isPrimaryRes.statusCode == 200 && mounted) {
          final data = jsonDecode(isPrimaryRes.body);
          final serverIsPrimary = data['is_primary'] == true;
          await SecureStore.write(
            'is_primary_device_$username',
            serverIsPrimary ? 'true' : 'false',
          );
          if (mounted) setState(() => _isPrimaryDevice = serverIsPrimary);
        }
      } catch (_) {}
    });

    _normalizeChatsForCurrentUser();

    currentDisplayName = username;
    Future(() async {
      try {
        final token = await AccountManager.getToken(username);
        if (token == null || !mounted) return;
        final res = await http.get(
          Uri.parse('$serverBase/profile/$username'),
          headers: {'authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && mounted) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final dn = (data['display_name'] as String?) ?? username;
          currentDisplayName = dn;
          if (data['uin'] != null) {
            final uinStr = data['uin'].toString();
            currentUin = uinStr;

            final prefs = await SharedPreferences.getInstance();
            unawaited(prefs.setString('uin_$username', uinStr));
          }
          setState(() {});

          unawaited(AccountManager.cacheDisplayName(username, dn));
        }
      } catch (e) {
        _appendLog('[profile] failed to load display_name: $e');
      }
    });

    final identity = await AccountManager.getIdentity(username);
    if (identity != null) {
      try {
        final keyPairData = await compute(_decodeIdentity, identity);
        _identityKeyPair = keyPairData.keyPair;
        _identityPublicKey = keyPairData.publicKey;
        identityPubKeyBase64 = identity['pub'];
        _appendLog('[identity] loaded for $username');
      } catch (e) {
        _appendLog('[identity] load failed: $e');
      }
    }

    chats = await AccountManager.loadChats(username);
    _buildServerMsgIndex();

    _initializeUnreadCounts();

    unawaited(_warmRecentUserProfiles());
    chatsVersion.value++;
    setState(() {});
    _appendLog('[chats] loaded ${chats.length} chats for $username');
  }

  Future<void> _switchToAccountWithAuth(String username) async {
    if (!SettingsManager.pinEnabled.value) {
      _switchToAccount(username);
      return;
    }
    if (!mounted) return;

    final localAuth = LocalAuthentication();

    // Сначала пробуем биометрию если включена
    if (SettingsManager.biometricEnabled.value) {
      try {
        final supported = await localAuth.isDeviceSupported();
        if (supported) {
          final didAuth = await localAuth.authenticate(
            localizedReason: 'Confirm account switch',
            options: const AuthenticationOptions(biometricOnly: false),
          );
          if (didAuth) {
            _switchToAccount(username);
            return;
          }
        }
      } catch (e) {
        debugPrint('[biometric] account switch auth error: $e');
      }
    }

    // Если биометрия не прошла или не включена — показываем PIN-экран
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (routeCtx) => PinCodeScreen.verify(
        onSuccess: () {
          Navigator.of(routeCtx).pop();
          _switchToAccount(username);
        },
        onBiometric: SettingsManager.biometricEnabled.value
            ? () async {
                try {
                  final supported = await localAuth.isDeviceSupported();
                  if (!supported) return;
                  final didAuth = await localAuth.authenticate(
                    localizedReason: 'Confirm account switch',
                    options: const AuthenticationOptions(biometricOnly: false),
                  );
                  if (didAuth && routeCtx.mounted) {
                    Navigator.of(routeCtx).pop();
                    _switchToAccount(username);
                  }
                } catch (e) {
                  debugPrint('[biometric] account switch auth error: $e');
                }
              }
            : null,
      ),
    ));
  }

  Future<void> _switchToAccount(String username) async {
    if (_isSwitchingAccount) {
      _appendLog('[account] switch to $username queued (switch in progress)');
      _pendingAccountSwitch = username;
      return;
    }

    if (currentUsername == username) {
      _appendLog('[account] already on $username, skipping switch');
      return;
    }

    _isSwitchingAccount = true;
    _pendingAccountSwitch = null;
    setState(() {});

    try {
      // Tell the server the OLD account is going offline before tearing the
      // socket down — suppressing this left "Fixedcode"-style ghosts online
      // (server only learned of the disconnect via its own timeout) and let
      // messages sent to the old account arrive back on its still-registered
      // session, undecryptable with the new account's identity keys.
      await _disconnectWs(manual: true, suppressPresence: false);

      // Stop WardLink before swapping account state — otherwise it keeps
      // broadcasting/serving under the old username while root_screen's
      // favorites/chats already reflect the new account, letting a still-
      // trusted peer pull the new account's data under the old identity.
      await WardLinkSyncService.instance.stop();

      ExternalServerManager.disconnectAll();
      _appendLog(
          '[ext-servers] Disconnected all external servers for account switch');

      _persistChatsTimer?.cancel();
      if (_hasPendingPersist && currentUsername != null) {
        await persistChats();
      }

      setState(() {
        _favorites.clear();
        _selectedFavoriteId = null;
        chats.clear();
        _serverMsgIndex.clear();
        selectedChatOther = null;
        _chatScreenCache.clear();
        _groupChatScreenCache.clear();
        _externalGroupChatScreenCache.clear();
        _appendLog(
            '[session] _chatScreenCache cleared on account switch to $username');
        selectedGroup = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
      });
      _pubkeyCache.clear();
      _pubkeyUploadedToServer = false;

      _lastPubkeyUploadAttempt = null;
      _lastPubkeyUploadTime = null;
      chatsVersion.value++;

      await AccountManager.setCurrentAccount(username);

      // These HTTP calls don't affect WS connection — run in background
      unawaited(AccountManager.loadStatusSettings());
      unawaited(AccountManager.loadPrivacySettings());

      _chatsLoadCompleter = Completer<void>();
      await _loadAccountData(
          username); // identity loaded here — WS can connect after this
      await _loadChatsFromCacheNow(username);
      _appendLog('[account] switched to $username');

      // Restart WardLink scoped to the new account (reloads its trusted-
      // device list and starts broadcasting the new username), mirroring
      // the startup path in _loadCurrentAccount.
      unawaited(WardLinkTombstones.load(username));
      if (SettingsManager.wardLinkEnabled.value) {
        unawaited(WardLinkSyncService.instance.start(username));
      }

      accountSwitchVersion.value++;

      // Connect WS immediately after identity is ready
      final ready = await _ensurePubkeyAndWsReady(
        maxRetries: 10,
        retryDelay: const Duration(milliseconds: 100),
      );
      if (!ready) {
        showSnack('Failed to connect after account switch');
      }
      _appendLog('[account] switch complete, ws ready=$ready');

      // Load the rest after WS is up — these don't block connection
      unawaited(_loadFavorites());
      unawaited(() async {
        try {
          await ExternalServerManager.loadServers();
          unawaited(ExternalServerManager.refreshAllExternalGroups());
          _appendLog(
              '[ext-servers] Loaded ${ExternalServerManager.servers.value.length} external servers for $username');
        } catch (e) {
          _appendLog('[ext-servers] Failed to load for new account: $e');
        }
      }());
    } finally {
      _isSwitchingAccount = false;
      setState(() {});

      final pending = _pendingAccountSwitch;
      if (pending != null) {
        _pendingAccountSwitch = null;
        _appendLog('[account] executing queued switch to $pending');
        unawaited(_switchToAccount(pending));
      }
    }
  }

  Future<void> _deleteAccount(String username) async {
    final isCurrent = username == currentUsername;

    _appendLog('[account] deleting $username (is current: $isCurrent)');

    await AccountManager.removeAccount(username);
    _appendLog('[account] removed $username from storage');

    if (isCurrent) {
      final remaining = await AccountManager.getAccountsList();
      _appendLog('[account] accounts remaining after delete: $remaining');

      if (remaining.isNotEmpty) {
        _appendLog(
            '[account] switching to ${remaining.first} after deleting current');
        await _switchToAccount(remaining.first);
      } else {
        _appendLog('[account] no accounts remaining after delete, logging out');
        await _logout();

        if (mounted) setState(() {});
      }
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> persistChats() async {
    if (currentUsername == null) {
      _hasPendingPersist = false;
      _dirtyChatIds.clear();
      _fullSaveRequested = false;
      return;
    }

    if (_fullSaveRequested || _dirtyChatIds.isEmpty) {
      await AccountManager.saveChats(currentUsername!, chats);
      _appendLog(
          '[persist] full save ${chats.length} chats for $currentUsername');
    } else {
      final dirty = Set<String>.from(_dirtyChatIds);
      for (final chatId in dirty) {
        final msgs = chats[chatId];
        if (msgs != null) {
          await AccountManager.saveSingleChat(currentUsername!, chatId, msgs);
        } else {
          await AccountManager.deleteChatFile(currentUsername!, chatId);
        }
      }
      _appendLog(
          '[persist] incremental save ${dirty.length} chats for $currentUsername');
    }

    _dirtyChatIds.clear();
    _fullSaveRequested = false;
    _hasPendingPersist = false;
  }

  void schedulePersistChats({String? chatId}) {
    _hasPendingPersist = true;
    if (chatId != null) {
      _dirtyChatIds.add(chatId);
    } else {
      _fullSaveRequested = true;
    }
    _persistChatsTimer?.cancel();
    _persistChatsTimer = Timer(const Duration(seconds: 2), () {
      if (_hasPendingPersist) {
        unawaited(persistChats());
      }
    });
  }

  /// Bumps all three version signals for a single chat change:
  ///   1. Adds a hint so ChatsTab can do an incremental (not full) rebuild.
  ///   2. Increments the global chatsVersion (triggers ChatsTab listener).
  ///   3. Increments the per-chat message version (triggers that ChatScreen only).
  void _bumpForChat(String chatId) {
    addChatListHint(chatId);
    chatsVersion.value++;
    bumpChatMessageVersion(chatId);
    if (chatId.startsWith('fav:')) {
      final favId = chatId.substring(4);
      bumpFavToTop(favId);
    }
  }

  /// Rebuilds the serverMessageId → chatId index from scratch.
  /// Call after loading or replacing the full chats map.
  void _buildServerMsgIndex() {
    _serverMsgIndex.clear();
    for (final entry in chats.entries) {
      for (final m in entry.value) {
        if (m.serverMessageId != null) {
          _serverMsgIndex[m.serverMessageId!] = entry.key;
        }
      }
    }
  }

  void _scheduleUiUpdate({String? chatId}) {
    if (chatId != null) _pendingChatUpdates.add(chatId);
    if (_pendingUiFlush) return;
    _pendingUiFlush = true;
    _uiFlushTimer?.cancel();
    _uiFlushTimer = Timer(const Duration(milliseconds: 50), () {
      _pendingUiFlush = false;
      if (mounted) {
        // Load hints for ChatsTab incremental update BEFORE bumping chatsVersion,
        // because ValueNotifier listeners fire synchronously.
        for (final id in _pendingChatUpdates) {
          addChatListHint(id);
        }
        chatsVersion.value++;
        // Bump per-chat versions so only the affected ChatScreen rebuilds.
        for (final id in _pendingChatUpdates) {
          bumpChatMessageVersion(id);
        }
        _pendingChatUpdates.clear();
      }
    });
  }

  void _scheduleNotificationSound() {
    if (_pendingSoundFlush) return;
    _pendingSoundFlush = true;
    _soundFlushTimer?.cancel();
    _soundFlushTimer = Timer(const Duration(milliseconds: 100), () {
      _pendingSoundFlush = false;
      _playNotificationSound();
    });
  }

  void _schedulePopupNotification({
    required String from,
    required String displayName,
    required String messagePreview,
    required bool isMedia,
  }) {
    _pendingNotifications[from] = messagePreview;
    _notifFlushTimer?.cancel();
    _notifFlushTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        _pendingNotifications.clear();
        return;
      }

      final entry = _pendingNotifications.entries.last;
      final sender = entry.key;
      final preview = entry.value;
      final count = _pendingNotifications.length;
      _pendingNotifications.clear();

      final colorScheme = Theme.of(context).colorScheme;
      String hex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0');
      final position = SettingsManager.notificationPosition.value;
      final senderDisplayName =
          UserCache.getSync(sender)?.displayName ?? sender;
      final finalPreview = count > 1 ? '$count new messages' : preview;
      final previewIsMedia = count == 1 && isMedia;

      if (!kIsWeb && Platform.isWindows && !MuteManager.isMuted(sender)) {
        unawaited(() async {
          final isMinimized = await windowManager.isMinimized();
          final isVisible = await windowManager.isVisible();
          final chatIsOpen = selectedChatOther == sender && count == 1;
          if (!chatIsOpen || isMinimized || !isVisible) {
            await WindowsNotificationPopup.showNotification(
              username: sender,
              displayName: senderDisplayName,
              message: finalPreview,
              displayDuration: const Duration(seconds: 10),
              surfaceColor: hex(colorScheme.surface),
              onSurfaceColor: hex(colorScheme.onSurface),
              onSurfaceVariantColor: hex(colorScheme.onSurfaceVariant),
              avatarColor: hex(colorScheme.primaryContainer),
              avatarLetterColor: hex(colorScheme.onPrimaryContainer),
              primaryColor: hex(colorScheme.primary),
              messageColor: hex(previewIsMedia
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant),
              position: position,
            );
            try {
              final bytes = await getAvatarCachedBytes(sender);
              if (bytes != null && bytes.isNotEmpty) {
                await WindowsNotificationPopup.updateAvatar(bytes);
              }
            } catch (_) {}
          }
        }());
      }

      if (!kIsWeb && Platform.isAndroid) {
        final chatIsOpen = selectedChatOther == sender && count == 1;
        if (!chatIsOpen && !MuteManager.isMuted(sender)) {
          unawaited(() async {
            final hideContent = SettingsManager.notifHideContent.value;
            final notifTitle = hideContent ? 'ONYX' : senderDisplayName;
            final notifBody = hideContent ? 'New message' : finalPreview;
            final avatarBytes =
                hideContent ? null : await getAvatarCachedBytes(sender);
            await NotificationService.showMessageNotification(
              title: notifTitle,
              body: notifBody,
              username: sender,
              avatarBytes: avatarBytes,
              accentColor: colorScheme.primary,
              avatarBgColor: colorScheme.primaryContainer,
              avatarLetterColor: colorScheme.onPrimaryContainer,
              timestamp: DateTime.now(),
              conversationTitle: notifTitle,
            );
          }());
        }
      }
    });
  }

  void _appendLog(String s) {
    final t = '${DateTime.now().toIso8601String()} $s';
    debugPrint(t);
    _log.add(t);
    if (_log.length > 500) _log.removeAt(0);
  }

  String _computePubkeyFpHex(List<int> raw) {
    final d = dart_crypto.sha256.convert(raw);
    return hex.encode(d.bytes);
  }

  Future<String?> getPeerPubkeyFp(String username) async {
    List<int>? bytes = _pubkeyCache[username];
    if (bytes == null) {
      try {
        final tok = await AccountManager.getToken(currentUsername ?? '');
        final r = await http.get(Uri.parse('$serverBase/pubkey/$username'),
            headers: {'authorization': 'Bearer $tok'});
        if (r.statusCode == 200) {
          final obj = jsonDecode(r.body) as Map<String, dynamic>;
          final pkB64 = obj['pubkey'] as String?;
          if (pkB64 != null) {
            bytes = base64Decode(pkB64);
            _pubkeyCache[username] = bytes;
          }
        }
      } catch (_) {}
    }
    if (bytes == null) return null;
    return _computePubkeyFpHex(bytes);
  }

  Uint8List _randomBytes(int len) {
    final rnd = Random.secure();
    final b = Uint8List(len);
    for (int i = 0; i < len; i++) b[i] = rnd.nextInt(256);
    return b;
  }

  Future<void> _generateIdentity() async {
    final kp = await _x25519.newKeyPair();
    final pub = await kp.extractPublicKey();
    _identityKeyPair = kp;
    _identityPublicKey = pub as SimplePublicKey;
    identityPubKeyBase64 = base64Encode(_identityPublicKey!.bytes);
    if (currentUsername != null) {
      final extracted = await kp.extract();
      List<int> privBytes;
      if (extracted is SimpleKeyPairData) {
        privBytes = extracted.bytes;
      } else {
        privBytes = (extracted as dynamic).bytes as List<int>;
      }
      await AccountManager.saveIdentity(
        currentUsername!,
        base64Encode(privBytes),
        identityPubKeyBase64!,
      );
    }
    _appendLog('[identity] generated for $currentUsername');
    setState(() {});
  }

  Future<bool> _uploadPubkeyToServer() async {
    if (currentUsername == null || identityPubKeyBase64 == null) {
      _appendLog('[pubkey] missing identity or account');
      return false;
    }

    try {
      if (_pubkeyUploadedToServer && _lastPubkeyUploadTime != null) {
        final since = DateTime.now().difference(_lastPubkeyUploadTime!);
        if (since.inSeconds < 60) {
          _appendLog(
              '[pubkey] skipped upload (already on server, debounce ${60 - since.inSeconds}s)');
          return true;
        }
      }
    } catch (e) {}
    final token = await AccountManager.getToken(currentUsername!);
    if (token == null) {
      _appendLog('[pubkey] no token');
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse('$serverBase/pubkey'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
        },
        body: jsonEncode({'pubkey': identityPubKeyBase64}),
      );
      if (res.statusCode == 200) {
        _lastPubkeyUploadTime = DateTime.now();
        _pubkeyUploadedToServer = true;
        _appendLog('[pubkey] uploaded ');
        return true;
      } else {
        _appendLog('[pubkey] failed: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      _appendLog('[pubkey] error: $e');
      return false;
    }
  }

  Future<void> rotateIdentityKey() async {
    await _generateIdentity();
    _pubkeyUploadedToServer = false;
    _lastPubkeyUploadTime = null;
    _pubkeyCache.clear();
    _devicePubkeysCache.clear();
    _devicePubkeysCacheAge.clear();
    await _uploadPubkeyToServer();

    if (_ws != null) {
      try {
        _ws!.sink.add(jsonEncode(
            {'type': 'pubkey_updated', 'username': currentUsername}));
        _appendLog('[key-rotation] pubkey_updated broadcast sent via WS');
      } catch (e) {
        _appendLog('[key-rotation] pubkey_updated WS send failed: $e');
      }
    }

    _appendLog('[key-rotation] E2EE identity key rotated and uploaded ');
  }

  Future<void> fullSessionReset() async {
    final username = currentUsername;
    final token =
        username != null ? await AccountManager.getToken(username) : null;

    await rotateIdentityKey();

    if (token != null) {
      try {
        final res = await http.delete(
          Uri.parse('$serverBase/me/sessions'),
          headers: {'authorization': 'Bearer $token'},
        );
        final revoked =
            res.statusCode == 200 ? (jsonDecode(res.body)['revoked'] ?? 0) : 0;
        _appendLog('[session-reset] Revoked $revoked other session(s) ');
        showSnack(' Key rotated — $revoked other session(s) kicked');
      } catch (e) {
        _appendLog('[session-reset] Failed to revoke sessions: $e');
        showSnack(' Key rotated, but failed to kick other sessions');
      }
    } else {
      _appendLog('[session-reset] No token — skipped server revocation');
    }

    _appendLog('[session-reset] Done — this device remains logged in');
  }

  Future<String?> _register(String username, String password) async {
    if (username.trim().isEmpty || password.length < 16) return null;
    try {
      _appendLog('[register] submitting registration');
      final res = await http.post(
        Uri.parse('$serverBase/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (res.statusCode == 200) {
        _appendLog('[register] registration successful!');
        final obj = jsonDecode(res.body);
        return obj['passphrase'] as String?;
      } else {
        _appendLog(
            '[register] registration failed: ${res.statusCode} ${res.body}');
        return null;
      }
    } catch (e) {
      _appendLog('[register] error: $e');
      return null;
    }
  }

  static String _computePoWNonce(Map<String, dynamic> params) {
    String challenge = params['challenge'];
    int difficulty = params['difficulty'];

    int nonce = 0;
    while (true) {
      String proofString = '$challenge$nonce';
      String hash =
          dart_crypto.sha256.convert(utf8.encode(proofString)).toString();

      int leadingZeros = 0;
      for (int i = 0; i < hash.length; i++) {
        if (hash[i] == '0') {
          leadingZeros++;
        } else {
          break;
        }
      }

      if (leadingZeros >= difficulty) {
        return nonce.toString();
      }

      nonce++;
    }
  }

  Future<(String, String)> _getDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return (
          '${info.brand} ${info.model}',
          'Android ${info.version.release}'
        );
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return (info.utsname.machine, 'iOS ${info.systemVersion}');
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return (info.computerName, 'Windows');
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return (info.computerName, 'macOS ${info.osRelease}');
      } else if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        return (info.prettyName, 'Linux');
      }
    } catch (_) {}
    return ('Unknown device', 'Unknown OS');
  }

  Future<bool> loginAccount(String u, String p) => _login(u, p);
  Future<String?> registerAccount(String u, String p) => _register(u, p);

  /// Log in using a token received via QR auth (no password needed).
  Future<bool> loginWithQrToken({
    required String username,
    required String token,
    required String uin,
    required bool isPrimary,
  }) async {
    try {
      await AccountManager.saveToken(username, token);
      await AccountManager.saveUsername(username);
      await AccountManager.addAccount(username);
      await AccountManager.setCurrentAccount(username);
      currentUsername = username;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uin_$username', uin);

      await SecureStore.write(
        'is_primary_device_$username',
        isPrimary ? 'true' : 'false',
      );

      ExternalServerManager.disconnectAll();
      setState(() {
        _favorites.clear();
        _selectedFavoriteId = null;
        selectedChatOther = null;
        selectedGroup = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
        _chatScreenCache.clear();
        _groupChatScreenCache.clear();
        _externalGroupChatScreenCache.clear();
      });

      await _loadAccountData(username);
      await _loadFavorites();
      _appendLog('[qr-login] ok for $username');

      await _disconnectWs();
      _pubkeyCache.clear();
      _pubkeyUploadedToServer = false;
      _lastPubkeyUploadAttempt = null;

      bool ready = false;
      for (int i = 0; i < 5; i++) {
        ready = await _ensurePubkeyAndWsReady(
          maxRetries: 3,
          retryDelay: const Duration(milliseconds: 300),
        );
        if (ready && _ws != null) break;
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!ready || _ws == null) {
        showSnack('QR login ok but connection unstable');
        _appendLog('[qr-login] warning: WS not ready after retries');
      }

      try {
        await ExternalServerManager.loadServers();
        await ExternalServerManager.refreshAllExternalGroups();
      } catch (e) {
        _appendLog('[ext-servers] Failed to load for qr account: $e');
      }

      return true;
    } catch (e) {
      _appendLog('[qr-login] error: $e');
    }
    return false;
  }

  Future<bool> _login(String username, String password) async {
    try {
      final (deviceName, deviceOs) = await _getDeviceInfo();
      final res = await http.post(
        Uri.parse('$serverBase/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'device_name': deviceName,
          'device_os': deviceOs,
        }),
      );
      if (res.statusCode == 200) {
        final obj = jsonDecode(res.body);
        final token = obj['token'];
        await AccountManager.saveToken(username, token);
        await AccountManager.saveUsername(username);
        await AccountManager.addAccount(username);
        await AccountManager.setCurrentAccount(username);
        currentUsername = username;

        if (obj['uin'] != null) {
          final loginPrefs = await SharedPreferences.getInstance();
          await loginPrefs.setString('uin_$username', obj['uin'].toString());
        }

        final serverIsPrimary = obj['is_primary'] == true;
        await SecureStore.write(
          'is_primary_device_$username',
          serverIsPrimary ? 'true' : 'false',
        );

        ExternalServerManager.disconnectAll();
        setState(() {
          _favorites.clear();
          _selectedFavoriteId = null;
          selectedChatOther = null;
          selectedGroup = null;
          selectedExternalGroup = null;
          selectedExternalServer = null;
          _chatScreenCache.clear();
          _groupChatScreenCache.clear();
          _externalGroupChatScreenCache.clear();
        });

        await _loadAccountData(username);
        await _loadFavorites();
        _appendLog('[login] ok for $username');

        await _disconnectWs();
        _pubkeyCache.clear();
        _pubkeyUploadedToServer = false;
        _lastPubkeyUploadAttempt = null;

        bool ready = false;
        for (int i = 0; i < 5; i++) {
          ready = await _ensurePubkeyAndWsReady(
            maxRetries: 3,
            retryDelay: const Duration(milliseconds: 300),
          );
          if (ready && _ws != null) break;
          await Future.delayed(const Duration(milliseconds: 400));
        }

        if (!ready || _ws == null) {
          showSnack('Login successful but connection unstable');
          _appendLog('[login] warning: WS not ready after retries');
        }

        try {
          await ExternalServerManager.loadServers();
          await ExternalServerManager.refreshAllExternalGroups();
          _appendLog(
              '[ext-servers] Loaded ${ExternalServerManager.servers.value.length} external servers for $username');
        } catch (e) {
          _appendLog('[ext-servers] Failed to load for new account: $e');
        }

        return true;
      }
    } catch (e) {
      _appendLog('[login] error: $e');
    }
    return false;
  }

  void _showPassphrase() async {
    final username = currentUsername;
    if (username == null) return;
    final passphrase = await SecureStore.read('passphrase_$username');
    if (!mounted) return;
    if (passphrase == null) {
      showSnack(
          AppLocalizations(SettingsManager.appLocale.value).passphraseNotFound);
      return;
    }
    final words = passphrase.split(' ');
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.key, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(ctx).yourPassphraseTitle,
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(ctx).passphraseWarning,
                style: const TextStyle(fontSize: 13, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: words.asMap().entries.map((e) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: passphrase));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(AppLocalizations.of(ctx).copyLabel),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).done),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(
    String passphrase,
    String oldPassword,
    String newPassword,
  ) async {
    final token = await AccountManager.getToken(currentUsername ?? '');
    if (token == null) throw Exception('Not logged in');
    final res = await http.post(
      Uri.parse('$serverBase/me/change-password'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'passphrase': passphrase,
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) {
      final detail = jsonDecode(res.body)['detail'] ?? 'Unknown error';
      throw Exception(detail);
    }
  }

  void _openSessions() {
    if (!_isPrimaryDevice) return;
    _onTabSelected(5);
  }

  void _openGraphOverlay() {
    _graphUnmountTimer?.cancel();
    setState(() {
      _graphOverlayMounted = true;
      _graphOverlayVisible = true;
    });
  }

  void _closeGraphOverlay() {
    setState(() => _graphOverlayVisible = false);
    _graphUnmountTimer?.cancel();
    _graphUnmountTimer = Timer(const Duration(milliseconds: 320), () {
      if (mounted && !_graphOverlayVisible) {
        setState(() => _graphOverlayMounted = false);
      }
    });
  }

  void _onShowGraphChanged() {
    if (!mounted) return;
    if (!_mobileGraphEnabled) {
      _graphUnmountTimer?.cancel();
      _graphOverlayVisible = false;
      _graphOverlayMounted = false;
    }
    setState(() {});
    // Re-align PageController after the tab list gains/loses the graph page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_index + _graphTabOffset);
      }
    });
  }

  Widget _buildMobileGraphPage() {
    return AccountGraphView(
      onChatTap: (username) {
        final chatId = chatIdForUser(username);
        chats.putIfAbsent(chatId, () => []);
        setState(() {
          selectedChatOther = username;
        });
        Navigator.of(context).push(
          _chatRoute((_) => ChatScreen(
                myUsername: currentUsername ?? 'me',
                otherUsername: username,
                onSend: (t, replyTo) => _sendChatMessage(username, t, replyTo),
                onTyping: () => _handleSendTyping(username),
                onRequestResend: (id) {
                  if (id != null) _requestResend(id);
                },
                onEditMessage: (id, text) =>
                    _editChatMessage(username, id, text),
                onDeleteMessage: (id) => _deleteChatMessage(id),
              )),
        );
      },
      onGroupTap: (group) {
        Navigator.of(context).push(
          _chatRoute((_) => GroupChatScreen(group: group)),
        );
      },
      onExternalGroupTap: (group) {
        final srv = ExternalServerManager.servers.value
            .cast<ExternalServer?>()
            .firstWhere((s) => s?.id == group.externalServerId,
                orElse: () => null);
        if (srv == null) return;
        Navigator.of(context).push(
          _chatRoute((_) => ExternalGroupChatScreen(group: group, server: srv)),
        );
      },
      onFavoriteTap: (favId) {
        try {
          final fav = _favorites.firstWhere((f) => f.id == favId);
          Navigator.of(context).push(
            _chatRoute((_) => getFavoritesScreen(favId, fav.title)),
          );
        } catch (_) {}
      },
    );
  }

  Widget _buildGraphOverlay() {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSlide(
      offset: _graphOverlayVisible ? Offset.zero : const Offset(-1.0, 0.0),
      duration: const Duration(milliseconds: 280),
      curve: _graphOverlayVisible ? Curves.easeOutCubic : Curves.easeInCubic,
      child: IgnorePointer(
        ignoring: !_graphOverlayVisible,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: colors.surface,
              child: _graphOverlayMounted
                  ? _buildMobileGraphPage()
                  : const SizedBox.shrink(),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                minimum: const EdgeInsets.all(8),
                child: Material(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    onPressed: _closeGraphOverlay,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphHandle() {
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, ___) {
          final colors = Theme.of(context).colorScheme;
          final baseColor = SettingsManager.getElementColor(
            colors.surfaceContainerHighest,
            brightness,
          );
          final bg = baseColor.withValues(
            alpha: (opacity * 0.62).clamp(0.0, 0.78),
          );
          final fg = colors.primary.withValues(
            alpha: (_graphOverlayVisible ? 1.0 : 0.88).clamp(0.0, 1.0),
          );

          final screenH = MediaQuery.of(context).size.height;
          if (!_handleYInitialized) {
            // First layout: derive the pixel position from the persisted
            // fraction (defaults near the bottom of the screen) rather than
            // a fixed pixel offset, so it lands in the same relative spot
            // on any screen size.
            _handleY =
                (SettingsManager.graphHandlePositionFraction.value * screenH)
                    .clamp(40.0, screenH - 100.0);
            _handleYInitialized = true;
          }

          return Positioned(
            left: 0,
            top: _handleY,
            child: GestureDetector(
              onTap: () => _graphOverlayVisible
                  ? _closeGraphOverlay()
                  : _openGraphOverlay(),
              onVerticalDragUpdate: (d) {
                setState(() {
                  _handleY =
                      (_handleY + d.delta.dy).clamp(40.0, screenH - 100.0);
                });
              },
              onVerticalDragEnd: (_) {
                if (screenH > 0) {
                  SettingsManager.setGraphHandlePositionFraction(
                      _handleY / screenH);
                }
              },
              child: Container(
                width: 30,
                height: 54,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(2, 1),
                    ),
                  ],
                ),
                child: Icon(
                  _graphOverlayVisible ? Icons.hub : Icons.hub_outlined,
                  size: 19,
                  color: fg,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    _disconnectWs();
    ExternalServerManager.disconnectAll();
    unawaited(WardLinkSyncService.instance.stop());

    currentUsername = null;
    currentDisplayName = null;
    currentUin = null;
    _identityKeyPair = null;
    _identityPublicKey = null;
    identityPubKeyBase64 = null;
    chats.clear();
    _serverMsgIndex.clear();
    _pubkeyCache.clear();
    _favorites.clear();
    _selectedFavoriteId = null;
    _chatScreenCache.clear();
    _groupChatScreenCache.clear();
    _externalGroupChatScreenCache.clear();

    chatsVersion.value++;
    unawaited(_warmRecentUserProfiles());

    await AccountManager.setCurrentAccount(null);

    if (isDesktop) {
      selectedChatOther = null;
      selectedGroup = null;
      selectedExternalGroup = null;
      selectedExternalServer = null;
    }

    setState(() {});
  }

  void _connectWs() async {
    if (_ws != null && _ws!.closeCode == null) {
      _appendLog('[ws.connect] already connected — skipping');
      return;
    }
    if (currentUsername == null) {
      _appendLog('[ws] no account');
      return;
    }
    AccountManager.getToken(currentUsername!).then((token) async {
      if (token == null) {
        _appendLog('[ws] no token');
        wsConnectedNotifier.value = false;
        return;
      }

      String wsUri;
      try {
        if (serverBase.startsWith('https://')) {
          wsUri = '${serverBase.replaceFirst('https://', 'wss://')}/ws';
        } else if (serverBase.startsWith('http://')) {
          wsUri = '${serverBase.replaceFirst('http://', 'ws://')}/ws';
        } else {
          wsUri = 'ws://$serverBase/ws';
        }
      } catch (e) {
        _appendLog('[ws] URI construction failed: $e');
        wsConnectedNotifier.value = false;
        return;
      }

      final proxyEnabled = SettingsManager.proxyEnabled.value;
      final proxyInfo = proxyEnabled
          ? '${SettingsManager.proxyType.value.toUpperCase()} ${SettingsManager.proxyHost.value}:${SettingsManager.proxyPort.value}'
          : 'none (direct)';
      _appendLog('[ws.connect] proxy=$proxyInfo');
      _appendLog('[ws.connect] Connecting to: $wsUri');

      WebSocketChannel boundWs;
      try {
        _ws = WebSocketChannel.connect(Uri.parse(wsUri));
        boundWs = _ws!;

        _ws!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
        _appendLog('[ws.connect] Auth frame sent');
      } catch (e) {
        _appendLog('[ws] connect error: $e');
        wsConnectedNotifier.value = false;
        return;
      }

      // This connection was authenticated for `boundUsername`. If the user
      // switches accounts before it's torn down (or a stale event is already
      // queued when we cancel the old subscription), events from this socket
      // must not be processed against the new account's identity/keys —
      // that produced "online" ghosts and undecryptable self-deliveries.
      final boundUsername = currentUsername;

      _wsSub = _ws!.stream.listen(
        (event) async {
          if (!identical(_ws, boundWs) || currentUsername != boundUsername) {
            _appendLog('[ws] dropping event from stale connection ($boundUsername)');
            return;
          }
          try {
            if (event is String) {
              final obj = jsonDecode(event) as Map<String, dynamic>;
              final typ = obj['type'] as String?;

              if (typ == 'init_complete') {
                wsConnectedNotifier.value = true;
                sessionExpiredNotifier.value = false;
                // Server just accepted our stored token — re-baseline the
                // local expiry heuristic so an account that stays logged in
                // past _tokenLifetime stops showing a false "expired" banner.
                if (currentUsername != null) {
                  unawaited(
                      AccountManager.touchTokenValidated(currentUsername!));
                }
                _appendLog(
                    '[ws] server init complete — WS tunnel established (proxy=${SettingsManager.proxyEnabled.value ? "${SettingsManager.proxyType.value.toUpperCase()} ${SettingsManager.proxyHost.value}:${SettingsManager.proxyPort.value}" : "none"})');
                _appendLog('[ws] sending presence...');
                _sendPresence('online');
                _drainPendingMsgQueue();

                try {
                  unawaited(_requestStatusSnapshotForKnownUsers());
                  unawaited(_syncBlocklistFromServer());

                  final known = Set<String>.from(chats.keys);
                  if (selectedChatOther != null) known.add(selectedChatOther!);
                  if (known.isNotEmpty && _ws != null) {
                    _ws!.sink.add(jsonEncode({
                      'type': 'request_status_snapshot',
                      'users': known.toList()
                    }));
                  }

                  Future.delayed(const Duration(seconds: 2), () {
                    try {
                      final known2 = Set<String>.from(chats.keys);
                      if (selectedChatOther != null)
                        known2.add(selectedChatOther!);
                      if (known2.isNotEmpty && _ws != null) {
                        _ws!.sink.add(jsonEncode({
                          'type': 'request_status_snapshot',
                          'users': known2.toList()
                        }));
                      }
                    } catch (_) {}
                  });
                } catch (e) {
                  _appendLog('[status_snapshot] request failed: $e');
                }

                ExternalServerManager.refreshAllExternalGroups();

                Future.delayed(const Duration(seconds: 2), () {
                  unawaited(_checkAllPeerPubkeysOnConnect());
                });

                if (ProxyManager.pendingApplyOnConnect) {
                  ProxyManager.pendingApplyOnConnect = false;
                  ProxyManager.applyFromSettings();
                  applyCertPinning();
                  _appendLog(
                      '[proxy] Deferred proxy applied — reconnecting via ${SettingsManager.proxyType.value.toUpperCase()} ${SettingsManager.proxyHost.value}:${SettingsManager.proxyPort.value}');
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _disconnectWs();
                    Future.delayed(
                        const Duration(milliseconds: 300), _connectWs);
                  });
                } else if (SettingsManager.proxyEnabled.value &&
                    ProxyManager.lastApplied != null) {
                  proxyActiveNotifier.value = true;
                }

                return;
              }
              if (typ == 'presence') {
                final userFrom = obj['from'] as String?;
                final state = obj['state'] as String?;
                final isOnlineField = obj['is_online'];
                if (userFrom != null && state != null) {
                  final s = Set<String>.from(onlineUsersNotifier.value);

                  if (isOnlineField == null) {
                    if (state.toLowerCase() == 'offline')
                      s.remove(userFrom);
                    else
                      s.add(userFrom);
                  } else {
                    final isOnline = isOnlineField == true;
                    if (isOnline)
                      s.add(userFrom);
                    else
                      s.remove(userFrom);
                  }

                  onlineUsersNotifier.value = s;

                  final vis = Map<String, String>.from(
                      userStatusVisibilityNotifier.value);
                  if (vis[userFrom] != 'hide') {
                    vis[userFrom] = 'show';
                    userStatusVisibilityNotifier.value = vis;
                  }

                  final statuses =
                      Map<String, String>.from(userStatusNotifier.value);
                  statuses[userFrom] = state;
                  userStatusNotifier.value = statuses;
                }
                return;
              }

              if (typ == 'status_change') {
                final username = obj['username'] as String?;
                final statusVisibility = obj['status_visibility'] as String?;
                final displayState = obj['state'] as String?;
                final isOnline = obj['is_online'] == true;
                if (username != null) {
                  _appendLog(
                      '[status_change] $username -> $statusVisibility state=$displayState is_online=$isOnline');

                  final s = Set<String>.from(onlineUsersNotifier.value);

                  if (statusVisibility == 'hide') {
                    s.remove(username);
                    onlineUsersNotifier.value = s;

                    final statuses =
                        Map<String, String>.from(userStatusNotifier.value);
                    statuses.remove(username);
                    userStatusNotifier.value = statuses;

                    final vis = Map<String, String>.from(
                        userStatusVisibilityNotifier.value);
                    vis[username] = 'hide';
                    userStatusVisibilityNotifier.value = vis;

                    return;
                  }

                  final vis = Map<String, String>.from(
                      userStatusVisibilityNotifier.value);
                  vis[username] = 'show';
                  userStatusVisibilityNotifier.value = vis;

                  if (isOnline)
                    s.add(username);
                  else
                    s.remove(username);
                  onlineUsersNotifier.value = s;

                  final statuses =
                      Map<String, String>.from(userStatusNotifier.value);
                  if (displayState != null && displayState.isNotEmpty)
                    statuses[username] = displayState;
                  else
                    statuses.remove(username);
                  userStatusNotifier.value = statuses;

                  try {
                    final msgId = obj['message_id'] as String?;
                    if (msgId != null && _ws != null) {
                      _ws!.sink.add(jsonEncode(
                          {'type': 'status_ack', 'message_id': msgId}));
                    }
                  } catch (e) {
                    _appendLog('[status_ack] send failed: $e');
                  }
                }
                return;
              }

              if (typ == 'status_snapshot') {
                try {
                  final users = (obj['users'] as List?) ?? [];
                  for (final u in users) {
                    try {
                      final username = (u['username'] as String?)?.toString();
                      if (username == null) continue;
                      final statusVisibility =
                          (u['status_visibility'] as String?) ?? 'show';
                      final displayState = (u['state'] as String?);
                      final isOnline = u['is_online'] == true;

                      final s = Set<String>.from(onlineUsersNotifier.value);
                      final vis = Map<String, String>.from(
                          userStatusVisibilityNotifier.value);

                      if (statusVisibility == 'hide') {
                        s.remove(username);
                        onlineUsersNotifier.value = s;

                        final statuses =
                            Map<String, String>.from(userStatusNotifier.value);
                        statuses.remove(username);
                        userStatusNotifier.value = statuses;

                        vis[username] = 'hide';
                        userStatusVisibilityNotifier.value = vis;

                        continue;
                      }

                      vis[username] = 'show';
                      userStatusVisibilityNotifier.value = vis;

                      if (isOnline)
                        s.add(username);
                      else
                        s.remove(username);
                      onlineUsersNotifier.value = s;

                      final statuses =
                          Map<String, String>.from(userStatusNotifier.value);
                      if (displayState != null && displayState.isNotEmpty)
                        statuses[username] = displayState;
                      else
                        statuses.remove(username);
                      userStatusNotifier.value = statuses;
                    } catch (e) {}
                  }
                } catch (e) {
                  _appendLog('[status_snapshot] parse error: $e');
                }

                return;
              }

              if (typ == 'pong') {
                _appendLog('[pong] received from server');
                return;
              }
              if (typ == 'typing') {
                return;
              }

              if (typ == 'avatar_update') {
                try {
                  final from = obj['from'] as String?;
                  final deleted = obj['deleted'] == true;
                  if (from != null) {
                    _appendLog(
                        '[ws.avatar_update] from=$from deleted=$deleted');

                    avatarVersion.value++;
                  }
                } catch (e) {
                  _appendLog('[ws.avatar_update] parse error: $e');
                }
                return;
              }

              if (typ == 'group_avatar_update') {
                try {
                  final gidRaw = obj['group_id'];
                  final groupId = gidRaw is int
                      ? gidRaw
                      : int.tryParse(gidRaw?.toString() ?? '');
                  final versionRaw = obj['avatar_version'];
                  final version = versionRaw is int
                      ? versionRaw
                      : int.tryParse(versionRaw?.toString() ?? '');
                  final deleted = obj['deleted'] == true;
                  if (groupId != null) {
                    final current =
                        Map<int, int>.from(groupAvatarVersion.value);
                    current[groupId] = version ?? ((current[groupId] ?? 0) + 1);
                    groupAvatarVersion.value = current;
                    _appendLog(
                        '[ws.group_avatar_update] group=$groupId v=${current[groupId]} deleted=$deleted');
                  }
                } catch (e) {
                  _appendLog('[ws.group_avatar_update] parse error: $e');
                }
                return;
              }
              if (typ == 'pubkey_updated') {
                final u = obj['username'] as String?;
                if (u != null) {
                  _pubkeyCache.remove(u);
                  _devicePubkeysCache.remove(u);
                  _devicePubkeysCacheAge.remove(u);
                  _appendLog('[ws] pubkey_updated: cleared cache for $u');
                  _showKeyChangedWarning(u);
                }
                return;
              }

              if (typ == 'device_list_stale') {
                final u = obj['username'] as String?;
                if (u != null) {
                  _devicePubkeysCache.remove(u);
                  _devicePubkeysCacheAge.remove(u);
                  _appendLog('[ws] device_list_stale: silently cleared device cache for $u');
                }
                return;
              }

              if (typ == 'device_list_updated') {
                final u = obj['username'] as String?;
                if (u != null) {
                  _devicePubkeysCache.remove(u);
                  _devicePubkeysCacheAge.remove(u);
                  _appendLog('[ws] device_list_updated: contact $u added a trusted device, cache cleared');
                }
                return;
              }

              if (typ == 'device_approval_needed') {
                final deviceName =
                    (obj['device_name'] as String?) ?? 'Unknown device';
                final deviceOs = obj['device_os'] as String?;
                final label =
                    deviceOs != null ? '$deviceName ($deviceOs)' : deviceName;
                _appendLog('[ws] device_approval_needed: $label');
                if (!mounted) return;
                if (_isPrimaryDevice) {
                  final colorScheme = Theme.of(context).colorScheme;
                  final brightness = SettingsManager.elementBrightness.value;
                  final opacity = SettingsManager.elementOpacity.value;
                  final backgroundColor = SettingsManager.getElementColor(
                    colorScheme.surfaceContainerHighest,
                    brightness,
                  ).withValues(alpha: opacity);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'New device wants encryption access: $label',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: backgroundColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(
                          bottom: 16, left: 16, right: 16),
                      elevation: 4,
                      duration: const Duration(seconds: 8),
                      action: SnackBarAction(
                        label: 'Review',
                        textColor: colorScheme.primary,
                        onPressed: _openSessions,
                      ),
                    ),
                  );
                } else {
                  showSnack('A new device is requesting encryption access.');
                }
                return;
              }

              if (typ == 'device_approved') {
                final deviceName =
                    (obj['device_name'] as String?) ?? 'Unknown device';
                _appendLog('[ws] device_approved: $deviceName');

                _devicePubkeysCache.clear();
                _devicePubkeysCacheAge.clear();
                if (!mounted) return;
                showSnack('Device "$deviceName" approved for encryption');
                return;
              }

              if (typ == 'call_offer') {
                callManager.onCallOffer(obj);
                return;
              } else if (typ == 'call_answer') {
                callManager.onCallAnswer(obj);
                return;
              } else if (typ == 'ice_candidate') {
                callManager.onIceCandidate(obj);
                return;
              } else if (typ == 'call_hangup') {
                callManager.onHangup(obj);
                return;
              } else if (typ == 'relay_offer') {
                debugPrint('[call] received relay_offer (fallback mode)');
                return;
              }
              if (typ == 'msg') {
                final from = obj['from'] as String? ?? 'unknown';
                final content = obj['content'] as String? ?? '';
                final envelopePkFp = obj['envelope_pk_fp'] as String?;
                final encryptedForDeviceRaw = obj['encrypted_for_device'];
                final String? encryptedForDevice = encryptedForDeviceRaw is Map
                    ? (encryptedForDeviceRaw['device_name'] as String?)
                    : null;
                final serverId = (obj['id'] is int) ? obj['id'] as int : null;
                String decrypted;
                String? rawPreview;
                bool didAutoRecovery = false;
                try {
                  decrypted = await _tryDecryptIncoming(
                        content,
                        from,
                        envelopePkFpFromServer: envelopePkFp,
                      ) ??
                      '[cannot-decrypt:empty]';
                  if (decrypted.startsWith('[cannot-decrypt')) {
                    _appendLog(
                      '[decrypt] initial failed -> attempting auto-recovery',
                    );
                    didAutoRecovery = true;
                    try {
                      await _uploadPubkeyToServer();
                    } catch (e) {
                      _appendLog('[recover] publish failed: $e');
                    }
                    if (_ws == null) {
                      _appendLog('[recover] ws null -> connecting');
                      _connectWs();
                    }
                    await Future.delayed(const Duration(milliseconds: 300));
                    final red = await _tryDecryptIncoming(
                      content,
                      from,
                      envelopePkFpFromServer: envelopePkFp,
                    );
                    decrypted = red ?? decrypted;
                  }
                  if (decrypted.startsWith('[cannot-decrypt')) {
                    rawPreview = content.length > 120
                        ? content.substring(0, 120) + '...'
                        : content;
                  }
                } catch (e) {
                  decrypted = '[cannot-decrypt:unexpected]';
                  rawPreview = content.length > 120
                      ? content.substring(0, 120) + '...'
                      : content;
                }
                final chatId = chatIdForUser(from);

                if (serverId != null) {
                  final existing = chats[chatId];
                  if (existing != null &&
                      existing.any((m) => m.serverMessageId == serverId)) {
                    _appendLog(
                        '[ws.recv.msg] duplicate server id=$serverId ignored for chat $chatId');
                    return;
                  }
                }

                final msg = ChatMessage(
                  id: serverId?.toString() ?? UniqueKey().toString(),
                  from: from,
                  to: currentUsername ?? 'me',
                  content: decrypted,
                  outgoing: false,
                  isRead: selectedChatOther == from,
                  serverMessageId: serverId,
                  rawEnvelopePreview: rawPreview,
                  encryptedForDevice: encryptedForDevice,
                  replyToId: obj['reply_to_id'] is int
                      ? obj['reply_to_id'] as int
                      : (obj['reply_to_id'] != null
                          ? int.tryParse(obj['reply_to_id'].toString())
                          : null),
                  replyToSender: obj['reply_to_sender']?.toString(),
                  replyToContent: obj['reply_to_content']?.toString(),
                );
                chats.putIfAbsent(chatId, () => []).add(msg);
                if (msg.serverMessageId != null)
                  _serverMsgIndex[msg.serverMessageId!] = chatId;

                if (!msg.isRead) {
                  unreadManager.incrementUnread(chatId);
                }

                _scheduleUiUpdate(chatId: chatId);

                schedulePersistChats(chatId: chatId);

                if (!msg.outgoing && !MuteManager.isMuted(from)) {
                  _scheduleNotificationSound();
                }

                if (SettingsManager.notificationsEnabled.value &&
                    mounted &&
                    !MuteManager.isMuted(from)) {
                  final rawPrev = msg.rawEnvelopePreview ??
                      (msg.content.length > 120
                          ? '${msg.content.substring(0, 120)}...'
                          : msg.content);
                  final messagePreview = getPreviewText(rawPrev);
                  const mediaLabels = {
                    'Voice message',
                    'Image',
                    'Video file',
                    'Music',
                    'Video',
                    'Document',
                    'Spreadsheet',
                    'Presentation',
                    'Archive',
                    'Artifact',
                    'File',
                  };
                  final isMedia = mediaLabels.contains(messagePreview) ||
                      messagePreview.startsWith('[Message not decrypted]') ||
                      messagePreview == 'Album' ||
                      messagePreview.startsWith('Album ·');
                  final displayName =
                      UserCache.getSync(from)?.displayName ?? from;
                  _schedulePopupNotification(
                    from: from,
                    displayName: displayName,
                    messagePreview: messagePreview,
                    isMedia: isMedia,
                  );
                }
                _appendLog(
                  '[ws.recv.msg] from=$from id=${serverId ?? "?"} recovered=${didAutoRecovery}',
                );
                return;
              }
              if (typ == 'ack') {
                final ok = obj['ok'] == true;
                final saved = obj['saved'] == true;
                final delivered = obj['delivered'] == true;
                final serverId = obj['id'];
                final localId = obj['local_id'] as String?;
                final timestamp = obj['timestamp'] as String?;
                _appendLog(
                  '[ws.ack] ok=$ok saved=$saved delivered=$delivered id=$serverId local=$localId ts=$timestamp',
                );

                String? ackChatId;
                if (saved && serverId != null && localId != null) {
                  final targetServerId = (serverId is int)
                      ? serverId
                      : int.tryParse(serverId.toString());
                  if (targetServerId != null) {
                    for (final entry in chats.entries) {
                      bool matched = false;
                      for (final m in entry.value) {
                        if (m.id == localId &&
                            m.outgoing &&
                            m.serverMessageId == null) {
                          m.serverMessageId = targetServerId;
                          _serverMsgIndex[targetServerId] = entry.key;
                          ackChatId = entry.key;
                          matched = true;
                          break;
                        }
                      }
                      if (matched) break;
                    }
                  }
                }
                if (saved && delivered == true) {
                  _tryMarkDeliveredFromAck(obj);
                  if (ackChatId != null) addChatListHint(ackChatId);
                  chatsVersion.value++;
                }
                return;
              }

              if (typ == 'error') {
                final errMsg = (obj['message'] as String?) ?? 'Server error';
                _appendLog('[ws] error: $errMsg');
                if (!mounted) return;
                showSnack(errMsg);
                return;
              }

              if (typ == 'blocked') {
                final localId = obj['local_id'] as String?;
                final blockedTo = obj['to'] as String?;
                _appendLog('[ws] blocked: to=$blockedTo local_id=$localId');
                // Remove the optimistically-added message from the chat
                if (localId != null && blockedTo != null) {
                  final chatId = chatIdForUser(blockedTo);
                  final msgs = chats[chatId];
                  if (msgs != null) {
                    msgs.removeWhere((m) => m.id == localId);
                    addChatListHint(chatId);
                    chatsVersion.value++;
                    schedulePersistChats(chatId: chatId);
                  }
                }
                if (!mounted) return;
                showSnack(
                  AppLocalizations(SettingsManager.appLocale.value)
                      .blockedByUserMessage,
                );
                return;
              }

              if (typ == 'msg_delivered') {
                final serverId = obj['id'];
                final delivered = obj['delivered'] == true;
                _appendLog(
                    '[ws.msg_delivered] id=$serverId delivered=$delivered');
                if (delivered && serverId != null) {
                  final targetId = (serverId is int)
                      ? serverId
                      : int.tryParse(serverId.toString());
                  if (targetId != null) {
                    final foundChatId = _serverMsgIndex[targetId];
                    if (foundChatId != null) {
                      final msgs = chats[foundChatId];
                      if (msgs != null) {
                        for (final m in msgs) {
                          if (m.serverMessageId == targetId && m.outgoing) {
                            m.delivered = true;
                            m.deliveredAt = DateTime.now();
                            _bumpForChat(foundChatId);
                            schedulePersistChats(chatId: foundChatId);
                            break;
                          }
                        }
                      }
                    }
                  }
                }
                return;
              }

              if (typ == 'message_edited') {
                try {
                  final midRaw = obj['message_id'];
                  final mid = (midRaw is int)
                      ? midRaw
                      : int.tryParse(midRaw?.toString() ?? '');
                  final encContent = obj['new_content'] as String?;
                  final from = obj['from'] as String?;
                  if (mid != null && encContent != null && from != null) {
                    final plain = await _tryDecryptIncoming(encContent, from) ??
                        encContent;
                    final updatedChatId = _serverMsgIndex[mid];
                    if (updatedChatId != null) {
                      final msgs = chats[updatedChatId];
                      if (msgs != null) {
                        for (final m in msgs) {
                          if (m.serverMessageId == mid) {
                            m.updateContent(plain);
                            _bumpForChat(updatedChatId);
                            schedulePersistChats(chatId: updatedChatId);
                            break;
                          }
                        }
                      }
                    }
                    _appendLog('[ws.message_edited] id=$mid updated');
                  }
                } catch (e) {
                  _appendLog('[ws.message_edited] error: $e');
                }
                return;
              }

              if (typ == 'message_deleted') {
                try {
                  final midRaw = obj['message_id'];
                  final mid = (midRaw is int)
                      ? midRaw
                      : int.tryParse(midRaw?.toString() ?? '');
                  if (mid != null) {
                    final removedChatId = _serverMsgIndex[mid];
                    if (removedChatId != null) {
                      final msgs = chats[removedChatId];
                      if (msgs != null) {
                        final before = msgs.length;
                        msgs.removeWhere((m) => m.serverMessageId == mid);
                        if (msgs.length != before) {
                          _serverMsgIndex.remove(mid);
                          _bumpForChat(removedChatId);
                          schedulePersistChats(chatId: removedChatId);
                        }
                      }
                    }
                    _appendLog('[ws.message_deleted] id=$mid removed');
                  }
                } catch (e) {
                  _appendLog('[ws.message_deleted] error: $e');
                }
                return;
              }

              if (typ == 'msg_delete') {
                try {
                  final midRaw = obj['id'];
                  final mid = (midRaw is int)
                      ? midRaw
                      : int.tryParse(midRaw?.toString() ?? '');
                  if (mid != null) {
                    final removedChatId = _serverMsgIndex[mid];
                    if (removedChatId != null) {
                      final list = chats[removedChatId];
                      if (list != null) {
                        final before = list.length;
                        list.removeWhere((m) => m.serverMessageId == mid);
                        if (list.length != before) {
                          _serverMsgIndex.remove(mid);
                          _bumpForChat(removedChatId);
                          schedulePersistChats(chatId: removedChatId);
                          _appendLog(
                              '[ws.msg_delete] removed server id=$mid from local store');
                        }
                      }
                    } else {
                      _appendLog(
                          '[ws.msg_delete] server id=$mid not found locally');
                    }
                  }
                } catch (e) {
                  _appendLog('[ws.msg_delete] parse error: $e');
                }
                return;
              }

              if (typ == 'session_revoked') {
                _appendLog('[ws] session_revoked — logging out immediately');
                _disconnectWs(manual: true);
                await _logout();
                return;
              }

              if (typ == 'reaction_update') {
                final msgType = obj['message_type'] as String?;
                final groupId = obj['group_id'] as int?;
                if (msgType == 'group' &&
                    groupId != null &&
                    _groupMessageListeners.containsKey(groupId)) {
                  _groupMessageListeners[groupId]!(obj);
                } else if (msgType == 'private') {
                  if (_privateReactionCallback != null) {
                    _privateReactionCallback!(obj);
                  } else {
                    // Chat screen is closed — buffer for when it opens.
                    final actor = obj['actor'] as String?;
                    final otherInPacket = obj['other_username'] as String?;
                    final me = currentUsername;
                    final partner = (actor != null && actor != me)
                        ? actor
                        : (otherInPacket ?? actor);
                    if (partner != null) {
                      _pendingPrivateReactions
                          .putIfAbsent(partner, () => [])
                          .add(obj);
                    }
                  }
                }
                return;
              }

              if (typ == 'group_msg' ||
                  typ == 'group_msg_edited' ||
                  typ == 'group_msg_deleted') {
                final groupId = obj['group_id'] as int?;
                if (groupId != null &&
                    _groupMessageListeners.containsKey(groupId)) {
                  _groupMessageListeners[groupId]!(obj);
                }
                return;
              }
            }
          } catch (e) {
            _appendLog('[ws] onMessage error: $e');
          }
        },
        onDone: () {
          final closeCode = _ws?.closeCode;
          _appendLog('[ws] closed (onDone) code=$closeCode');
          if (closeCode == 1008) {
            _appendLog(
                '[ws] token rejected by server (1008) — session expired');
            sessionExpiredNotifier.value = true;
            _handleWsClosed(manual: true, reason: 'token_invalid_1008');
          } else {
            _handleWsClosed(manual: false, reason: 'onDone');
          }
        },
        onError: (e) {
          final errStr = e.toString();
          _appendLog('[ws] error (onError): $errStr');

          if (errStr.contains('CERTIFICATE') ||
              errStr.contains('certificate') ||
              errStr.contains('SSL') ||
              errStr.contains('TLS')) {
            _appendLog('[ws]  SSL/Certificate error detected');
          }

          if (errStr.contains('Connection refused') ||
              errStr.contains('ECONNREFUSED')) {
            _appendLog('[ws]  Connection refused - server may be down');
          }

          _handleWsClosed(manual: false, reason: 'onError: $errStr');
        },
      );
      _appendLog('[ws] connected');
      _startHeartbeat();

      setState(() {});
    });
  }

  void _startHeartbeat() {
    _wsHeartbeat?.cancel();
    _wsHeartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        if (_ws != null && _ws!.closeCode == null) {
          _ws!.sink.add(jsonEncode({'type': 'ping'}));
        }
      } catch (e) {
        _appendLog('[heartbeat] ping failed: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _wsHeartbeat?.cancel();
    _wsHeartbeat = null;
  }

  void _handleWsClosed({required bool manual, String? reason}) {
    _appendLog('[ws.handleClosed] manual=$manual reason=${reason ?? "?"}');

    _manualWsDisconnect = manual;

    _disconnectWs(manual: manual);

    if (!manual) {
      _startReconnectLoop();
    } else {
      _stopReconnectLoop();
    }
  }

  void _startReconnectLoop() {
    if (_reconnectTimer != null) return;
    _reconnectAttempts = 0;
    Duration computeDelay() {
      final backoffMs =
          (_baseReconnectDelay.inMilliseconds * (1 << _reconnectAttempts));
      final capped = backoffMs.clamp(0, _maxReconnectDelay.inMilliseconds);
      return Duration(milliseconds: capped);
    }

    _appendLog('[ws.reconnect] scheduling reconnect loop');

    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_ws != null && _ws!.closeCode == null) {
        _appendLog(
            '[ws.reconnect] connection restored, stopping reconnect loop');
        _stopReconnectLoop();
        return;
      }
      final delay = computeDelay();

      if (t.tick % (delay.inSeconds == 0 ? 1 : delay.inSeconds) != 0) return;

      _reconnectAttempts++;
      _appendLog(
        '[ws.reconnect] attempt #${_reconnectAttempts} (delay=${delay.inSeconds}s)',
      );
      try {
        await _ensurePubkeyAndWsReady(
          maxRetries: 1,
          retryDelay: const Duration(milliseconds: 200),
        );

        if (_ws == null) {
          _connectWs();
        } else {
          _appendLog(
            '[ws.reconnect] _ws already exists, stopping reconnect loop',
          );
          _stopReconnectLoop();
        }
      } catch (e) {
        _appendLog('[ws.reconnect] attempt failed: $e');
      }
    });
  }

  void _stopReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _appendLog('[ws.reconnect] stopped');
  }

  void subscribeToGroup(
      int groupId, void Function(Map<String, dynamic>) listener) {
    _groupMessageListeners[groupId] = listener;
    _activeGroupChatIds.add(groupId);
  }

  void unsubscribeFromGroup(int groupId) {
    _groupMessageListeners.remove(groupId);
    _activeGroupChatIds.remove(groupId);
  }

  void subscribeToPrivateReactions(
    String otherUsername,
    void Function(Map<String, dynamic>) cb,
  ) {
    _privateReactionCallback = cb;
    // Flush any buffered updates that arrived while the chat was closed.
    final pending = _pendingPrivateReactions.remove(otherUsername);
    if (pending != null) {
      for (final update in pending) {
        cb(update);
      }
    }
  }

  void unsubscribeFromPrivateReactions() {
    _privateReactionCallback = null;
  }

  Future<void> _preloadUserProfiles() async {
    final usernames = <String>{};
    for (final chatId in chats.keys) {
      final parts = chatId.split(':');
      final other = parts.firstWhere(
        (p) => p != (currentUsername ?? 'me'),
        orElse: () => chatId,
      );
      usernames.add(other);
    }
    // Don't invalidate here — invalidating fires updatedUsers.value per user,
    // which triggers setState(_rebuildSummaries) in ChatsTab n times = O(n²).
    // UserCache.get() already skips cached entries, so this is a no-op for
    // users already loaded.
    await Future.wait(
      usernames.map((u) => UserCache.get(u).catchError((_) => null)).toList(),
    );
  }

  Future<void> _warmRecentUserProfiles() async {
    if (_isPreloadingUserProfiles) return;
    _isPreloadingUserProfiles = true;
    try {
      final usernames = <String>{};
      final recentEntries = chats.entries
          .where((e) => !e.key.startsWith('fav:') && e.value.isNotEmpty)
          .toList()
        ..sort((a, b) => b.value.last.time.compareTo(a.value.last.time));
      for (final entry in recentEntries.take(40)) {
        final chatId = entry.key;
        if (chatId.startsWith('grp:')) continue;
        final parts = chatId.split(':');
        final other = parts.firstWhere(
          (p) => p != (currentUsername ?? 'me'),
          orElse: () => chatId,
        );
        usernames.add(other);
      }
      final list = usernames.toList(growable: false);
      for (int i = 0; i < list.length; i += 8) {
        final batch = list.skip(i).take(8);
        await Future.wait(
          batch.map((u) => UserCache.get(u).catchError((_) => null)).toList(),
        );
        await Future.delayed(Duration.zero);
      }
    } finally {
      _isPreloadingUserProfiles = false;
    }
  }

  Future<void> _disconnectWs(
      {bool manual = false, bool suppressPresence = false}) async {
    _manualWsDisconnect = manual;
    wsConnectedNotifier.value = false;
    try {
      if (_ws != null && !suppressPresence) _sendPresence('offline');
    } catch (_) {}
    _stopHeartbeat();
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.sink.close();
    } catch (_) {}
    _ws = null;
    onlineUsersNotifier.value = <String>{};

    _appendLog(
        '[ws] disconnected (manual=$manual suppressPresence=$suppressPresence)');

    if (mounted) {
      setState(() {});
    }

    if (manual) {
      _stopReconnectLoop();
    } else {}
  }

  void connectWs() {
    _connectWs();
  }

  /// Called after PIN unlock so the account and chats are reloaded
  /// without requiring a full app restart.
  Future<void> reloadAfterUnlock() async {
    await _loadCurrentAccount();
  }

  /// Pops any pushed chat/group/settings screen and returns to the root tab
  /// list, mirroring what a fresh app launch looks like. Used when switching
  /// the running session into/out of decoy mode so the user doesn't end up
  /// stranded on a now-empty chat screen that belonged to the other account.
  void _resetNavigationToRoot() {
    if (!mounted) return;
    if (isDesktop) {
      setState(() {
        selectedChatOther = null;
        selectedGroup = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
        _selectedFavoriteId = null;
        _index = 0;
      });
    } else {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
      setState(() => _index = 0);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0 + _graphTabOffset);
    }
  }

  /// Switches the already-running RootScreen into decoy mode — used when the
  /// app was backgrounded while showing the real account and the user enters
  /// the fake PIN on the resume lock screen. Without this, RootScreen (kept
  /// alive across lock/unlock via its GlobalKey) would just keep displaying
  /// the real account's chats with `DecoyManager.isActive` flipped on
  /// underneath, i.e. the fake PIN would appear to do nothing.
  Future<void> enterDecoyMode() async {
    if (_isSwitchingAccount) return;
    _isSwitchingAccount = true;
    setState(() {});
    try {
      _resetNavigationToRoot();
      await _disconnectWs(manual: true, suppressPresence: false);
      await WardLinkSyncService.instance.stop();
      ExternalServerManager.disconnectAll();

      _persistChatsTimer?.cancel();
      if (_hasPendingPersist && currentUsername != null) {
        await persistChats();
      }

      setState(() {
        _favorites.clear();
        _favFolders = [];
        _favTopOrder = [];
        _selectedFavoriteId = null;
        chats.clear();
        _serverMsgIndex.clear();
        selectedChatOther = null;
        _chatScreenCache.clear();
        _groupChatScreenCache.clear();
        _externalGroupChatScreenCache.clear();
        selectedGroup = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
      });
      chatsVersion.value++;

      currentUsername = DecoyManager.username;
      currentDisplayName = DecoyManager.displayName;

      await _initDecoyMode();
      accountSwitchVersion.value++;
      _appendLog('[decoy] switched running session into decoy mode');
    } finally {
      _isSwitchingAccount = false;
      setState(() {});
    }
  }

  /// Reverses [enterDecoyMode] — used when the app was backgrounded while
  /// showing the decoy account and the user proves their real identity
  /// (real PIN or biometrics) on the resume lock screen.
  Future<void> exitDecoyMode() async {
    if (_isSwitchingAccount) return;
    _isSwitchingAccount = true;
    setState(() {});
    try {
      _resetNavigationToRoot();
      DecoyManager.deactivate();
      wsConnectedNotifier.value = false;

      setState(() {
        _favorites.clear();
        _favFolders = [];
        _favTopOrder = [];
        _selectedFavoriteId = null;
        chats.clear();
        _serverMsgIndex.clear();
        selectedChatOther = null;
        _chatScreenCache.clear();
        _groupChatScreenCache.clear();
        _externalGroupChatScreenCache.clear();
        selectedGroup = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
      });
      chatsVersion.value++;

      await _loadCurrentAccount();
      accountSwitchVersion.value++;
      _appendLog('[decoy] switched running session back to the real account');
    } finally {
      _isSwitchingAccount = false;
      setState(() {});
    }
  }

  Future<void> disconnectWs() async {
    await _disconnectWs(manual: true);
  }

  void sendOnlineStatus() {
    if (_ws != null) {
      _sendPresence('online');
    } else {
      _connectWs();
    }
  }

  void _sendPresence(String state) {
    if (_ws == null) return;

    final statusVisibility = SettingsManager.statusVisibility.value;
    if (statusVisibility == 'hide') {
      _appendLog('[presence] skipped (status_visibility=hide)');
      return;
    }

    try {
      final payload = {
        'type': 'presence',
        'state': state,
        'status_visibility': statusVisibility,
        'status_online': SettingsManager.statusOnline.value,
        'status_offline': SettingsManager.statusOffline.value,
      };
      _ws!.sink.add(jsonEncode(payload));
    } catch (e) {
      _appendLog('[presence] send failed: $e');
    }
  }

  void sendPresence(String state) {
    _sendPresence(state);
  }

  Uint8List _hkdfSha256(List<int> ikm, List<int> info, int length) {
    final salt = List<int>.filled(32, 0);
    final mac1 = dart_crypto.Hmac(dart_crypto.sha256, salt);
    final prk = mac1.convert(ikm).bytes;
    List<int> okm = [];
    List<int> previous = [];
    int counter = 1;
    while (okm.length < length) {
      final data = <int>[...previous, ...info, counter];
      final mac = dart_crypto.Hmac(dart_crypto.sha256, prk);
      final t = mac.convert(data).bytes;
      okm.addAll(t);
      previous = t;
      counter++;
    }
    return Uint8List.fromList(okm.sublist(0, length));
  }

  Future<Uint8List> encryptMediaForPeer(
    String peerUsername,
    Uint8List plaintext, {
    required String kind,
  }) async {
    if (_identityKeyPair == null || _identityPublicKey == null) {
      _appendLog('[media.encrypt.$kind] identity missing – blocking send');
      throw Exception(
          'Cannot send $kind: identity key not loaded. Please reconnect.');
    }

    try {
      List<int> peerPubBytes;
      if (_pubkeyCache.containsKey(peerUsername)) {
        peerPubBytes = _pubkeyCache[peerUsername]!;
      } else {
        final tok = await AccountManager.getToken(currentUsername ?? '');
        final r = await http.get(Uri.parse('$serverBase/pubkey/$peerUsername'),
            headers: {'authorization': 'Bearer $tok'});
        if (r.statusCode != 200) {
          throw Exception(
              'Cannot encrypt $kind: no public key for $peerUsername');
        }
        final obj = jsonDecode(r.body);
        final pkB64 = obj['pubkey'] as String?;
        if (pkB64 == null) {
          throw Exception(
              'Cannot encrypt $kind: null public key for $peerUsername');
        }
        peerPubBytes = base64Decode(pkB64);
        _pubkeyCache[peerUsername] = peerPubBytes;
      }

      final peerPub = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);

      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: _identityKeyPair!,
        remotePublicKey: peerPub,
      );

      Uint8List sharedBytes;
      try {
        sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());
      } catch (e) {
        final dyn = sharedSecret as dynamic;
        final b = dyn.bytes as List<int>;
        sharedBytes = Uint8List.fromList(b);
      }

      final self = currentUsername ?? 'me';
      final pair = [self, peerUsername]..sort();
      final info = utf8.encode('file:$kind:${pair[0]}:${pair[1]}');

      final aeadKeyBytes = _hkdfSha256(sharedBytes, info, 32);
      final secretKey = SecretKey(aeadKeyBytes);

      final nonce = _randomBytes(24);
      final box = await _xchacha.encrypt(
        plaintext,
        secretKey: secretKey,
        nonce: nonce,
        aad: <int>[],
      );

      const prefix = 'E2EEM1:';
      final prefixBytes = utf8.encode(prefix);

      final cipher = Uint8List.fromList([
        ...prefixBytes,
        ...nonce,
        ...box.cipherText,
        ...box.mac.bytes,
      ]);

      _appendLog(
        '[media.encrypt.$kind] ok ${plaintext.length} → ${cipher.length}',
      );
      return cipher;
    } catch (e, st) {
      _appendLog('[media.encrypt.$kind] error: $e\n$st');
      rethrow;
    }
  }

  Future<(Uint8List, String)> encryptMediaRandom(
    Uint8List plaintext, {
    required String kind,
  }) async {
    try {
      final mediaKey = _randomBytes(32);
      final mediaKeyB64 = base64Encode(mediaKey);
      final secretKey = SecretKey(Uint8List.fromList(mediaKey));
      final nonce = _randomBytes(24);
      final box = await _xchacha.encrypt(
        plaintext,
        secretKey: secretKey,
        nonce: nonce,
        aad: <int>[],
      );
      const prefix = 'E2EEM1:';
      final prefixBytes = utf8.encode(prefix);
      final cipher = Uint8List.fromList([
        ...prefixBytes,
        ...nonce,
        ...box.cipherText,
        ...box.mac.bytes,
      ]);
      _appendLog(
          '[media.encrypt.$kind] random-key ok ${plaintext.length} → ${cipher.length}');
      return (cipher, mediaKeyB64);
    } catch (e, st) {
      _appendLog('[media.encrypt.$kind] error: $e\n$st');
      rethrow;
    }
  }

  Future<Uint8List> decryptMediaFromPeer(
    String peerUsername,
    Uint8List data, {
    required String kind,
    String? mediaKeyB64,
  }) async {
    const prefix = 'E2EEM1:';
    final prefixBytes = utf8.encode(prefix);

    if (data.length < prefixBytes.length + 24 + 16) {
      return data;
    }

    bool hasPrefix = true;
    for (int i = 0; i < prefixBytes.length; i++) {
      if (data[i] != prefixBytes[i]) {
        hasPrefix = false;
        break;
      }
    }
    if (!hasPrefix) {
      return data;
    }

    if (_identityKeyPair == null || _identityPublicKey == null) {
      _appendLog('[media.decrypt.$kind] identity missing – return ciphertext');
      return data;
    }

    try {
      // ── Resolve the AEAD key on the main isolate (needs network + key store) ─
      final Uint8List aeadKeyBytes;
      if (mediaKeyB64 != null) {
        aeadKeyBytes = base64Decode(mediaKeyB64);
      } else {
        List<int> peerPubBytes;
        if (_pubkeyCache.containsKey(peerUsername)) {
          peerPubBytes = _pubkeyCache[peerUsername]!;
        } else {
          final tok = await AccountManager.getToken(currentUsername ?? '');
          final r = await http.get(
              Uri.parse('$serverBase/pubkey/$peerUsername'),
              headers: {'authorization': 'Bearer $tok'});
          if (r.statusCode != 200) {
            _appendLog('[media.decrypt.$kind] no pubkey for $peerUsername');
            return data;
          }
          final obj = jsonDecode(r.body);
          final pkB64 = obj['pubkey'] as String?;
          if (pkB64 == null) {
            _appendLog('[media.decrypt.$kind] null pubkey');
            return data;
          }
          peerPubBytes = base64Decode(pkB64);
          _pubkeyCache[peerUsername] = peerPubBytes;
        }

        final peerPub = SimplePublicKey(peerPubBytes, type: KeyPairType.x25519);
        final sharedSecret = await _x25519.sharedSecretKey(
          keyPair: _identityKeyPair!,
          remotePublicKey: peerPub,
        );
        Uint8List sharedBytes;
        try {
          sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());
        } catch (e) {
          final dyn = sharedSecret as dynamic;
          final b = dyn.bytes as List<int>;
          sharedBytes = Uint8List.fromList(b);
        }
        final self = currentUsername ?? 'me';
        final pair = [self, peerUsername]..sort();
        final info = utf8.encode('file:$kind:${pair[0]}:${pair[1]}');
        aeadKeyBytes = _hkdfSha256(sharedBytes, info, 32);
      }

      // ── Offload the actual XChaCha20-Poly1305 decrypt to a POOLED background
      //    isolate. The pool is spawned once and reused, so many images
      //    arriving at once no longer each pay a fresh-isolate spawn cost.    ─
      final plain = await DecryptWorker.instance.decrypt(
        cipherData: data,
        aeadKey: aeadKeyBytes,
        prefixLen: prefixBytes.length,
      );

      if (plain == null) {
        _appendLog('[media.decrypt.$kind] isolate returned null – keeping ciphertext');
        return data;
      }

      _appendLog('[media.decrypt.$kind] ok ${data.length} → ${plain.length}');
      return plain;
    } catch (e, st) {
      _appendLog('[media.decrypt.$kind] error: $e\n$st');
      return data;
    }
  }

  Future<String> _encryptForRecipientEnvelope(
    String recipient,
    String plaintext,
  ) async {
    List<int> recipientPubBytes;
    if (_pubkeyCache.containsKey(recipient)) {
      recipientPubBytes = _pubkeyCache[recipient]!;
    } else {
      final tok = await AccountManager.getToken(currentUsername ?? '');
      final r = await http.get(Uri.parse('$serverBase/pubkey/$recipient'),
          headers: {'authorization': 'Bearer $tok'});
      if (r.statusCode != 200) {
        throw Exception(
          'Recipient has no public key. Cannot send E2EE message.',
        );
      }
      final obj = jsonDecode(r.body);
      final pkB64 = obj['pubkey'] as String?;
      if (pkB64 == null) {
        throw Exception(
            'Recipient has no public key — cannot send encrypted message.');
      }
      recipientPubBytes = base64Decode(pkB64);
      _pubkeyCache[recipient] = recipientPubBytes;
    }
    final recipFp = _computePubkeyFpHex(recipientPubBytes);
    final ephKp = await _x25519.newKeyPair();
    final ephPub = await ephKp.extractPublicKey();
    final ephPubBytes = ephPub.bytes;
    final recipPub = SimplePublicKey(
      recipientPubBytes,
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephKp,
      remotePublicKey: recipPub,
    );
    Uint8List sharedBytes;
    try {
      sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());
    } catch (e) {
      final dyn = sharedSecret as dynamic;
      final b = dyn.bytes as List<int>;
      sharedBytes = Uint8List.fromList(b);
    }
    final info = utf8.encode('chat:${currentUsername ?? "me"}:$recipient');
    final aeadKeyBytes = _hkdfSha256(sharedBytes, info, 32);
    final aeadSecretKey = SecretKey(aeadKeyBytes);
    final nonce = _randomBytes(24);
    final secretBox = await _xchacha.encrypt(
      utf8.encode(plaintext),
      secretKey: aeadSecretKey,
      nonce: nonce,
      aad: <int>[],
    );
    final fullCt = Uint8List.fromList(
      secretBox.cipherText + secretBox.mac.bytes,
    );
    final envelope = {
      'version': 1,
      'alg': 'xchacha20poly1305',
      'eph': base64Encode(ephPubBytes),
      'nonce': base64Encode(nonce),
      'ct': base64Encode(fullCt),
      'pk_fp': recipFp,
    };
    final envJson = jsonEncode(envelope);
    return 'E2EEv1:' + base64Encode(utf8.encode(envJson));
  }

  Future<void> _checkAllPeerPubkeysOnConnect() async {
    if (currentUsername == null) return;
    final me = currentUsername!;

    final peers = chats.keys
        .where((id) => !id.startsWith('fav:') && id.contains(':'))
        .map((id) {
          final parts = id.split(':');
          return parts.firstWhere((p) => p != me, orElse: () => '');
        })
        .where((p) => p.isNotEmpty)
        .toSet();

    if (peers.isEmpty) return;
    _appendLog('[pubkey-check] checking ${peers.length} peer(s) on connect');

    for (final peer in peers) {
      if (!mounted) return;
      try {
        final tok = await AccountManager.getToken(currentUsername ?? '');
        final r = await http.get(Uri.parse('$serverBase/pubkey/$peer'),
            headers: {
              'authorization': 'Bearer $tok'
            }).timeout(const Duration(seconds: 5));
        if (r.statusCode != 200) continue;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final freshPubkey = body['pubkey'] as String?;
        if (freshPubkey == null || freshPubkey.isEmpty) continue;

        final stored = await AccountManager.getKnownPubkey(me, peer);
        unawaited(AccountManager.saveKnownPubkey(me, peer, freshPubkey));

        if (stored == null) continue;
        if (stored != freshPubkey) {
          _appendLog('[pubkey-check] $peer key changed while offline');
          _showKeyChangedWarning(peer);
        }
      } catch (e) {
        _appendLog('[pubkey-check] fetch failed for $peer: $e');
      }
    }
  }

  void _checkKeyChangeOnChatOpen(String peer) {
    if (currentUsername == null) return;
    Future.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      try {
        final tok = await AccountManager.getToken(currentUsername ?? '');
        final r = await http.get(Uri.parse('$serverBase/pubkey/$peer'),
            headers: {
              'authorization': 'Bearer $tok'
            }).timeout(const Duration(seconds: 5));
        if (r.statusCode != 200) return;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final freshPubkey = body['pubkey'] as String?;
        if (freshPubkey == null || freshPubkey.isEmpty) return;

        final stored =
            await AccountManager.getKnownPubkey(currentUsername!, peer);

        unawaited(AccountManager.saveKnownPubkey(
            currentUsername!, peer, freshPubkey));

        if (stored == null) return;
        if (stored != freshPubkey) {
          _appendLog('[pubkey-check] $peer key changed — stored≠fresh');
          _showKeyChangedWarning(peer);
        }
      } catch (e) {
        _appendLog('[pubkey-check] fetch failed for $peer: $e');
      }
    });
  }

  void _showKeyChangedWarning(String peer) {
    if (!mounted) return;
    if (!chats.containsKey(chatIdForUser(peer))) return;
    showSnack(' $peer has a new encryption key.');
  }

  Future<List<Map<String, dynamic>>> _fetchAllDevicePubkeys(
      String recipient) async {
    final age = _devicePubkeysCacheAge[recipient];
    final isFresh = age != null && DateTime.now().difference(age) < _kDeviceCacheTTL;
    if (isFresh && _devicePubkeysCache.containsKey(recipient)) {
      return _devicePubkeysCache[recipient]!;
    }
    try {
      final tok = await AccountManager.getToken(currentUsername ?? '');
      final r = await http.get(Uri.parse('$serverBase/pubkeys/$recipient'),
          headers: {
            'authorization': 'Bearer $tok'
          }).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final obj = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = obj['devices'] as List<dynamic>? ?? [];
        final devices = raw
            .whereType<Map<String, dynamic>>()
            .where((d) => d['pubkey'] != null && d['fp'] != null)
            .toList();
        _devicePubkeysCache[recipient] = devices;
        _devicePubkeysCacheAge[recipient] = DateTime.now();
        return devices;
      }
    } catch (e) {
      _appendLog('[pubkeys] fetch failed for $recipient: $e');
    }
    return [];
  }

  Future<String> _encryptWithPubkeyBytes(
    String recipient,
    String plaintext,
    List<int> pubkeyBytes,
  ) async {
    final recipFp = _computePubkeyFpHex(pubkeyBytes);
    final ephKp = await _x25519.newKeyPair();
    final ephPub = await ephKp.extractPublicKey();
    final ephPubBytes = ephPub.bytes;
    final recipPub = SimplePublicKey(pubkeyBytes, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephKp,
      remotePublicKey: recipPub,
    );
    Uint8List sharedBytes;
    try {
      sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());
    } catch (e) {
      final dyn = sharedSecret as dynamic;
      sharedBytes = Uint8List.fromList(dyn.bytes as List<int>);
    }
    final info = utf8.encode('chat:${currentUsername ?? "me"}:$recipient');
    final aeadKeyBytes = _hkdfSha256(sharedBytes, info, 32);
    final aeadSecretKey = SecretKey(aeadKeyBytes);
    final nonce = _randomBytes(24);
    final secretBox = await _xchacha.encrypt(
      utf8.encode(plaintext),
      secretKey: aeadSecretKey,
      nonce: nonce,
      aad: <int>[],
    );
    final fullCt =
        Uint8List.fromList(secretBox.cipherText + secretBox.mac.bytes);
    final envelope = {
      'version': 1,
      'alg': 'xchacha20poly1305',
      'eph': base64Encode(ephPubBytes),
      'nonce': base64Encode(nonce),
      'ct': base64Encode(fullCt),
      'pk_fp': recipFp,
    };
    return 'E2EEv1:${base64Encode(utf8.encode(jsonEncode(envelope)))}';
  }

  Future<Map<String, String>?> _encryptForAllDevices(
    String recipient,
    String plaintext,
  ) async {
    final devices = await _fetchAllDevicePubkeys(recipient);
    if (devices.isEmpty) return null;

    final payloads = <String, String>{};
    for (final device in devices) {
      final pubkeyB64 = device['pubkey'] as String?;
      final fp = device['fp'] as String?;
      if (pubkeyB64 == null || fp == null) continue;
      final pubkeyBytes = base64Decode(pubkeyB64);
      final encrypted =
          await _encryptWithPubkeyBytes(recipient, plaintext, pubkeyBytes);
      payloads[fp] = encrypted;
    }
    if (payloads.isEmpty) return null;
    return payloads;
  }

  Future<String?> _tryDecryptIncoming(
    String content,
    String from, {
    String? envelopePkFpFromServer,
  }) async {
    if (content.isEmpty || !content.startsWith('E2EEv1:')) return content;
    if (_identityKeyPair == null || _identityPublicKey == null) {
      _appendLog('[decrypt] identity missing');
      return '[cannot-decrypt:identity_missing]';
    }
    Uint8List payload;
    try {
      payload = base64Decode(content.substring('E2EEv1:'.length));
    } catch (e) {
      _appendLog('[decrypt] invalid outer base64');
      return '[cannot-decrypt:invalid_outer_base64]';
    }
    Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(payload));
    } catch (e) {
      _appendLog('[decrypt] invalid envelope json');
      return '[cannot-decrypt:invalid_envelope_json]';
    }
    final ephB64 = env['eph'] as String?;
    final nonceB64 = env['nonce'] as String?;
    final ctB64 = env['ct'] as String?;
    if (ephB64 == null || nonceB64 == null || ctB64 == null) {
      _appendLog('[decrypt] envelope missing fields');
      return '[cannot-decrypt:envelope_missing_fields]';
    }
    final eph = base64Decode(ephB64);
    final nonce = base64Decode(nonceB64);
    final ctAndTag = base64Decode(ctB64);
    final ephPubKey = SimplePublicKey(eph, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: _identityKeyPair!,
      remotePublicKey: ephPubKey,
    );
    Uint8List sharedBytes;
    try {
      sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());
    } catch (e) {
      final dyn = sharedSecret as dynamic;
      final b = dyn.bytes as List<int>;
      sharedBytes = Uint8List.fromList(b);
    }
    final info = utf8.encode('chat:$from:${currentUsername ?? "me"}');
    final aeadKeyBytes = _hkdfSha256(sharedBytes, info, 32);
    final aeadSecretKey = SecretKey(aeadKeyBytes);
    try {
      const tagLen = 16;
      if (ctAndTag.length < tagLen) {
        _appendLog('[decrypt] ct too short');
        return '[cannot-decrypt:ct_too_short]';
      }
      final cipherText = ctAndTag.sublist(0, ctAndTag.length - tagLen);
      final tag = ctAndTag.sublist(ctAndTag.length - tagLen);
      final box = SecretBox(
        Uint8List.fromList(cipherText),
        nonce: Uint8List.fromList(nonce),
        mac: Mac(Uint8List.fromList(tag)),
      );
      final plain = await _xchacha.decrypt(
        box,
        secretKey: aeadSecretKey,
        aad: <int>[],
      );
      final plainText = utf8.decode(plain);
      _appendLog('[decrypt] success from=$from');
      return plainText;
    } catch (e) {
      _appendLog('[decrypt] decrypt failed: $e');
      return '[cannot-decrypt:auth_fail]';
    }
  }

  String chatIdForUser(String other) {
    final me = currentUsername ?? 'me';
    final ids = List<String>.from([me, other])..sort();
    return ids.join(':');
  }

  Future<void> _sendChatMessage(
      String to, String text, Map<String, dynamic>? replyTo) async {
    if (currentUsername == null) return;

    if (DecoyManager.isActive.value) {
      final chatId = chatIdForUser(to);
      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      final msg = ChatMessage(
        id: localId,
        from: currentUsername!,
        to: to,
        content: text,
        outgoing: true,
        delivered: true,
        isRead: true,
        time: DateTime.now(),
      );
      chats.putIfAbsent(chatId, () => []).add(msg);
      messageListNotifier.addMessageOptimized(chatId, msg);
      _bumpForChat(chatId);
      unawaited(DecoyDataManager.addMessageToContact(
          to, currentUsername!, text, true));
      return;
    }

    if (_isSwitchingAccount) {
      _appendLog('[msg] blocked: account switch in progress');
      return;
    }

    // Re-assert "online" on send: with multiple devices on the same account,
    // another device's offline presence (e.g. it switched accounts) can leave
    // the server showing us offline here even while this device is active.
    // Sending refreshes the server's view without waiting on its timeout —
    // purely a client-side nudge, no server changes needed.
    sendOnlineStatus();

    try {
      unawaited(_updateRecipientStatus(to));
    } catch (e) {
      _appendLog('[send] failed to update recipient status: $e');
    }

    final localId = DateTime.now().microsecondsSinceEpoch.toString();
    final chatId = chatIdForUser(to);

    final isLANMode = replyTo != null && replyTo['_deliveryMode'] == 'lan';

    final int? replyId = replyTo != null && replyTo['id'] != null
        ? int.tryParse(replyTo['id'].toString())
        : null;
    final msgLocal = ChatMessage(
      id: localId,
      from: currentUsername!,
      to: to,
      content: text,
      outgoing: true,
      delivered: isLANMode ? true : false,
      time: DateTime.now(),
      replyToId: replyId,
      replyToSender: replyTo != null
          ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString()
          : null,
      replyToContent: replyTo != null ? (replyTo['content'])?.toString() : null,
      deliveryMode: isLANMode ? DeliveryMode.lan : DeliveryMode.internet,
    );

    chats.putIfAbsent(chatId, () => []).add(msgLocal);
    if (msgLocal.serverMessageId != null)
      _serverMsgIndex[msgLocal.serverMessageId!] = chatId;
    debugPrint(
        '[RootScreen] Added message to chatId=$chatId, total messages: ${chats[chatId]!.length}');

    messageListNotifier.addMessageOptimized(chatId, msgLocal);

    final oldVersion = chatsVersion.value;
    _bumpForChat(chatId);
    debugPrint(
        '[RootScreen] Updated chatsVersion: $oldVersion -> ${chatsVersion.value}');

    schedulePersistChats(chatId: chatId);

    if (!isLANMode) {
      _sendChatMessageInBackground(to, text, localId, replyTo);
    }
  }

  void _handleIncomingLANMessage(ChatMessage message) {
    if (currentUsername == null) return;

    final chatId = chatIdForUser(message.from);

    final incomingMessage = ChatMessage(
      id: message.id,
      from: message.from,
      to: message.to,
      content: message.content,
      outgoing: false,
      delivered: true,
      isRead: false,
      time: message.time,
      replyToId: message.replyToId,
      replyToSender: message.replyToSender,
      replyToContent: message.replyToContent,
      deliveryMode: message.deliveryMode,
    );

    chats.putIfAbsent(chatId, () => []).add(incomingMessage);
    if (incomingMessage.serverMessageId != null)
      _serverMsgIndex[incomingMessage.serverMessageId!] = chatId;

    messageListNotifier.addMessageOptimized(chatId, incomingMessage);
    _bumpForChat(chatId);

    schedulePersistChats(chatId: chatId);
    if (!MuteManager.isMuted(message.from)) {
      unawaited(_playNotificationSound());
    }

    if (selectedChatOther != message.from) {
      unreadManager.incrementUnread(chatId);
    }
  }

  Future<void> _handleIncomingLANMedia(
    String mediaType,
    String filename,
    Uint8List data,
    String from,
    String to,
    Map<String, dynamic>? replyTo,
  ) async {
    if (currentUsername == null) return;

    final chatId = chatIdForUser(from);

    try {
      final dir = await getOnyxDocumentsDirectory();
      final mediaDir = Directory('${dir.path}/lan_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final filePath = '${mediaDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(data);

      String content;
      if (mediaType == 'voice') {
        final duration = data.length ~/ (16000 * 2);
        final format = filename.split('.').last;
        final voiceContent = jsonEncode({
          'url': 'lan://$filename',
          'duration': duration,
          'format': format,
        });
        content = 'VOICEv1:$voiceContent';
      } else if (mediaType == 'image') {
        content = 'IMAGEv1:${jsonEncode({'url': 'lan://$filename'})}';
      } else if (mediaType == 'video') {
        content = 'VIDEOv1:${jsonEncode({'url': 'lan://$filename'})}';
      } else if (mediaType == 'file') {
        content = 'FILEv1:${jsonEncode({'filename': 'lan://$filename'})}';
      } else {
        content = 'Unknown media type: $mediaType';
      }

      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      final int? replyId = replyTo != null && replyTo['id'] != null
          ? int.tryParse(replyTo['id'].toString())
          : null;

      final incomingMessage = ChatMessage(
        id: localId,
        from: from,
        to: to,
        content: content,
        outgoing: false,
        delivered: true,
        isRead: false,
        time: DateTime.now(),
        replyToId: replyId,
        replyToSender: replyTo != null
            ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString()
            : null,
        replyToContent:
            replyTo != null ? (replyTo['content'])?.toString() : null,
        deliveryMode: DeliveryMode.lan,
      );

      chats.putIfAbsent(chatId, () => []).add(incomingMessage);

      messageListNotifier.addMessageOptimized(chatId, incomingMessage);
      _bumpForChat(chatId);

      schedulePersistChats(chatId: chatId);
      if (!MuteManager.isMuted(from)) {
        unawaited(_playNotificationSound());
      }

      if (selectedChatOther != from) {
        unreadManager.incrementUnread(chatId);
      }

      _appendLog('[LAN] Received $mediaType from $from, saved to $filePath');
    } catch (e) {
      _appendLog('[LAN] Failed to handle incoming media: $e');
    }
  }

  Future<void> _updateRecipientStatus(String username) async {
    try {
      final currentUser = await AccountManager.getCurrentAccount();
      final token = await AccountManager.getToken(currentUser ?? '');
      if (token == null) return;

      final res = await http.get(
        Uri.parse('$serverBase/profile/$username'),
        headers: {'authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        final isOnline = data['is_online'] == true;
        final displayState = data['display_state'] as String?;
        final statusVisibility = data['status_visibility'] as String? ?? 'show';

        _appendLog(
            '[recipient-status] updated $username: visibility=$statusVisibility online=$isOnline state=$displayState');

        if (statusVisibility == 'hide') {
          final s = Set<String>.from(onlineUsersNotifier.value)
            ..remove(username);
          onlineUsersNotifier.value = s;

          final statuses = Map<String, String>.from(userStatusNotifier.value);
          statuses.remove(username);
          userStatusNotifier.value = statuses;

          final vis =
              Map<String, String>.from(userStatusVisibilityNotifier.value);
          vis[username] = 'hide';
          userStatusVisibilityNotifier.value = vis;
        } else {
          final vis =
              Map<String, String>.from(userStatusVisibilityNotifier.value);
          vis[username] = 'show';
          userStatusVisibilityNotifier.value = vis;

          final s = Set<String>.from(onlineUsersNotifier.value);
          if (isOnline)
            s.add(username);
          else
            s.remove(username);
          onlineUsersNotifier.value = s;

          if (displayState != null && displayState.isNotEmpty) {
            final statuses = Map<String, String>.from(userStatusNotifier.value);
            statuses[username] = displayState;
            userStatusNotifier.value = statuses;
          }
        }
      }
    } catch (e) {
      _appendLog('[recipient-status] error: $e');
    }
  }

  void _sendChatMessageInBackground(
      String to, String text, String localId, Map<String, dynamic>? replyTo) {
    unawaited(Future.microtask(() async {
      Map<String, String>? payloads;
      String? fallbackEnvelope;

      const retryDelays = [1, 2, 4, 8, 15];
      for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
        if (attempt > 0) {
          _devicePubkeysCache.remove(to);
          _devicePubkeysCacheAge.remove(to);
          _pubkeyCache.remove(to);
          await Future.delayed(Duration(seconds: retryDelays[attempt - 1]));
        }
        try {
          payloads = await _encryptForAllDevices(to, text);
          if (payloads == null) {
            fallbackEnvelope = await _encryptForRecipientEnvelope(to, text);
          }
          break;
        } catch (e) {
          _appendLog('[send] encrypt attempt ${attempt + 1} failed: $e');
          if (attempt == retryDelays.length) {
            _appendLog('[send] encrypt failed after all retries — giving up');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot send: recipient has no public key'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
      }

      if (_ws != null) {
        _sendViaWsNow(to, text, payloads, fallbackEnvelope, localId, replyTo);
      } else {
        final wsReady = await _ensurePubkeyAndWsReady();
        if (!wsReady || _ws == null) {
          _appendLog('[send] ws not ready — adding to pending queue');
          _pendingMsgQueue.add({
            'to': to,
            'text': text,
            'localId': localId,
            'replyTo': replyTo,
            'payloads': payloads,
            'fallbackEnvelope': fallbackEnvelope,
          });
          _markMessagePending(to, localId, pending: true);
          return;
        }
        _sendViaWsNow(to, text, payloads, fallbackEnvelope, localId, replyTo);
      }
    }));
  }

  void _sendViaWsNow(
    String to,
    String text,
    Map<String, String>? payloads,
    String? fallbackEnvelope,
    String localId,
    Map<String, dynamic>? replyTo,
  ) {
    if (_ws == null) return;
    final isMedia = text.startsWith('VOICEv1:') ||
        text.startsWith('IMAGEv1:') ||
        text.startsWith('VIDEOv1:') ||
        text.startsWith('FILEv1:') ||
        text.startsWith('AUDIOv1:') ||
        text.startsWith('ALBUMv1:');

    final packet = <String, dynamic>{
      'type': 'msg',
      'to': to,
      'local_id': localId,
      if (isMedia) 'is_media': true,
      if (replyTo != null && replyTo['id'] != null)
        'reply_to_id': replyTo['id'].toString(),
      if (replyTo != null &&
          (replyTo['senderDisplayName'] ?? replyTo['sender']) != null)
        'reply_to_sender':
            (replyTo['senderDisplayName'] ?? replyTo['sender']).toString(),
      if (replyTo != null && replyTo['content'] != null)
        'reply_to_content': replyTo['content'].toString(),
    };

    if (payloads != null && payloads.isNotEmpty) {
      packet['payloads'] = payloads;
      _appendLog(
          '[send] MD msg sent localId=$localId devices=${payloads.length}');
    } else if (fallbackEnvelope != null) {
      packet['content'] = fallbackEnvelope;
      _appendLog(
          '[send] legacy msg sent localId=$localId len=${fallbackEnvelope.length}');
    } else {
      _appendLog('[send] no payload to send — aborting');
      return;
    }

    try {
      _ws!.sink.add(jsonEncode(packet));
    } catch (e) {
      _appendLog('[send] ws.sink.add failed: $e');
    }
  }

  void _markMessagePending(String to, String localId, {required bool pending}) {
    final chatId = chatIdForUser(to);
    final msgs = chats[chatId];
    if (msgs == null) return;
    for (final m in msgs) {
      if (m.id == localId) {
        m.pendingSend = pending;
        break;
      }
    }
    _bumpForChat(chatId);
  }

  void _drainPendingMsgQueue() {
    if (_pendingMsgQueue.isEmpty) return;
    _appendLog('[send] draining ${_pendingMsgQueue.length} pending message(s)');
    final toSend = List<Map<String, dynamic>>.from(_pendingMsgQueue);
    _pendingMsgQueue.clear();
    for (final item in toSend) {
      final to = item['to'] as String;
      final text = item['text'] as String;
      final localId = item['localId'] as String;
      final replyTo = item['replyTo'] as Map<String, dynamic>?;
      final payloads = item['payloads'] as Map<String, String>?;
      final fallbackEnvelope = item['fallbackEnvelope'] as String?;
      _markMessagePending(to, localId, pending: false);
      _sendViaWsNow(to, text, payloads, fallbackEnvelope, localId, replyTo);
    }
  }

  void _handleSendTyping(String to) {}

  Future<void> _editChatMessage(
      String to, int messageId, String newText) async {
    if (_ws == null || currentUsername == null) return;
    try {
      final envelope = await _encryptForRecipientEnvelope(to, newText);
      _ws!.sink.add(jsonEncode({
        'type': 'edit_message',
        'message_id': messageId,
        'new_content': envelope,
      }));

      final chatId = chatIdForUser(to);
      final msgs = chats[chatId];
      if (msgs != null) {
        for (final m in msgs) {
          if (m.serverMessageId == messageId) {
            m.updateContent(newText);
            break;
          }
        }
        _bumpForChat(chatId);
        schedulePersistChats(chatId: chatId);
        if (mounted) setState(() {});
      }
      _appendLog('[edit] message id=$messageId edited');
    } catch (e) {
      _appendLog('[edit] failed: $e');
    }
  }

  Future<void> _deleteChatMessage(int messageId) async {
    if (_ws == null) return;
    try {
      _ws!.sink.add(jsonEncode({
        'type': 'delete_message',
        'message_id': messageId,
      }));

      final removedChatId = _serverMsgIndex[messageId];
      bool removed = false;
      if (removedChatId != null) {
        final msgs = chats[removedChatId];
        if (msgs != null) {
          final before = msgs.length;
          ChatMessage? toTrash;
          for (final m in msgs) {
            if (m.serverMessageId == messageId) { toTrash = m; break; }
          }
          msgs.removeWhere((m) => m.serverMessageId == messageId);
          if (msgs.length != before) {
            _serverMsgIndex.remove(messageId);
            removed = true;
            if (toTrash != null) {
              final me = currentUsername ?? '';
              final parts = removedChatId.split(':');
              final other = parts.length == 2
                  ? parts.firstWhere((p) => p != me, orElse: () => removedChatId)
                  : removedChatId;
              TrashManager.instance.addDeletedMessage(TrashedMessage(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                chatId: removedChatId,
                chatDisplayName: other,
                message: toTrash,
                deletedAt: DateTime.now(),
              ));
            }
          }
        }
      } else {
        // Fallback: index miss, scan all chats
        for (final entry in chats.entries) {
          final before = entry.value.length;
          ChatMessage? toTrash;
          for (final m in entry.value) {
            if (m.serverMessageId == messageId) { toTrash = m; break; }
          }
          entry.value.removeWhere((m) => m.serverMessageId == messageId);
          if (entry.value.length != before) {
            _serverMsgIndex.remove(messageId);
            removed = true;
            if (toTrash != null) {
              final me = currentUsername ?? '';
              final parts = entry.key.split(':');
              final other = parts.length == 2
                  ? parts.firstWhere((p) => p != me, orElse: () => entry.key)
                  : entry.key;
              TrashManager.instance.addDeletedMessage(TrashedMessage(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                chatId: entry.key,
                chatDisplayName: other,
                message: toTrash,
                deletedAt: DateTime.now(),
              ));
            }
          }
        }
      }
      if (removed) {
        if (removedChatId != null) {
          _bumpForChat(removedChatId);
        } else {
          chatsVersion.value++;
        }
        schedulePersistChats(chatId: removedChatId);
        if (mounted) setState(() {});
      }
      _appendLog('[delete] message id=$messageId deleted');
    } catch (e) {
      _appendLog('[delete] failed: $e');
    }
  }

  Future<bool> _ensurePubkeyAndWsReady({
    int maxRetries = 6,
    Duration retryDelay = const Duration(milliseconds: 400),
  }) async {
    if (identityPubKeyBase64 == null) {
      _appendLog('[auto] identity missing -> generating');
      await _generateIdentity();
    }

    final now = DateTime.now();
    final shouldRetryUpload = !_pubkeyUploadedToServer &&
        (_lastPubkeyUploadAttempt == null ||
            now.difference(_lastPubkeyUploadAttempt!) >
                _pubkeyUploadRetryDelay);

    if (shouldRetryUpload) {
      unawaited(_uploadPubkeyInBackground());
    }

    if (_ws == null) {
      _appendLog('[auto] connecting ws...');
      _connectWs();

      int tries = 0;
      while (_ws == null && tries < 10) {
        await Future.delayed(const Duration(milliseconds: 50));
        tries++;
      }
    }

    final ok = _ws != null;
    _appendLog('[auto] ws ready=$ok (pubkey_cached=$_pubkeyUploadedToServer)');
    return ok;
  }

  Future<void> _uploadPubkeyInBackground() async {
    for (int i = 0; i < 3; i++) {
      final ok = await _uploadPubkeyToServer();
      if (ok) {
        _pubkeyUploadedToServer = true;
        _lastPubkeyUploadAttempt = DateTime.now();
        _appendLog('[pubkey] uploaded √ (attempt ${i + 1})');
        return;
      }
      if (i < 2) {
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }

    _appendLog(
        '[pubkey] WARNING: upload failed after 3 attempts — will retry on next connect');
  }

  void _tryMarkDeliveredFromAck(Map<String, dynamic> ack) {
    final deliveredFlag = ack['delivered'] == true;
    final serverId = ack['id'];
    String? ts = ack['timestamp'] as String?;
    DateTime? serverTs;
    if (ts != null) {
      try {
        serverTs = DateTime.parse(ts);
      } catch (_) {}
    }
    ChatMessage? candidate;
    String? candidateChatId;
    Duration? bestDiff;
    for (final entry in chats.entries) {
      for (final m in entry.value.reversed) {
        if (m.outgoing && !m.delivered) {
          if (serverTs != null) {
            final diff = serverTs.difference(m.time).abs();
            if (bestDiff == null || diff < bestDiff) {
              bestDiff = diff;
              candidate = m;
              candidateChatId = entry.key;
            }
          } else {
            if (candidate == null) {
              candidate = m;
              candidateChatId = entry.key;
            }
          }
        }
      }
      if (candidate != null && serverTs == null) break;
    }
    if (candidate != null && deliveredFlag) {
      candidate.delivered = true;
      _appendLog(
        '[deliver-mark] local_id=${candidate.id} marked delivered (server_id=$serverId)',
      );

      if (candidateChatId != null) {
        _bumpForChat(candidateChatId);
      } else {
        chatsVersion.value++;
      }
      schedulePersistChats(chatId: candidateChatId);
    } else {
      _appendLog(
        '[deliver-mark] no matching outgoing found for ack id=$serverId',
      );
    }
  }

  void _markChatAsRead(String otherUsername) {
    final chatId = chatIdForUser(otherUsername);
    final msgs = chats[chatId];
    if (msgs == null || msgs.isEmpty) {
      unreadManager.markAsRead(chatId);
      return;
    }

    bool hasChanges = false;
    for (final msg in msgs) {
      if (!msg.outgoing && !msg.isRead) {
        msg.isRead = true;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      schedulePersistChats(chatId: chatId);
      _bumpForChat(chatId);
    }

    unreadManager.markAsRead(chatId);
  }

  void _initializeUnreadCounts() {
    for (final entry in chats.entries) {
      final chatId = entry.key;
      final msgs = entry.value;

      int unreadCount = 0;
      for (final msg in msgs) {
        if (!msg.outgoing && !msg.isRead) {
          unreadCount++;
        }
      }

      if (unreadCount > 0) {
        unreadManager.setUnreadCount(chatId, unreadCount);
      }
    }
  }

  void _normalizeChatsForCurrentUser() {
    if (currentUsername == null) return;

    final Map<String, List<ChatMessage>> updated = {};
    final Map<String, String> renamed = {};

    for (final entry in chats.entries) {
      final key = entry.key;
      final parts = key.split(':');
      if (parts.contains('me')) {
        final other = parts.firstWhere((p) => p != 'me');
        final ids = [currentUsername!, other]..sort();
        final newKey = ids.join(':');
        renamed[key] = newKey;
      }
    }

    for (final oldKey in renamed.keys) {
      final newKey = renamed[oldKey]!;
      final list = chats.remove(oldKey) ?? [];
      updated.putIfAbsent(newKey, () => []).addAll(list);
    }

    for (final entry in chats.entries) {
      updated.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }

    if (renamed.isNotEmpty) {
      chats = updated;
      chatsVersion.value++;
      schedulePersistChats();
      _initializeUnreadCounts();

      _chatScreenCache.clear();
      _groupChatScreenCache.clear();
      _externalGroupChatScreenCache.clear();
      debugPrint(
          '[chats] normalized and _chatScreenCache cleared for $currentUsername');
    }
  }

  void _requestResend(int serverMessageId) {
    if (_ws == null) {
      _appendLog('[resend] cannot request resend: ws null');
      return;
    }
    try {
      final pkt = jsonEncode({
        'type': 'request_resend',
        'message_id': serverMessageId,
      });
      _ws!.sink.add(pkt);
      _appendLog('[resend] requested for message_id=$serverMessageId');
    } catch (e) {
      _appendLog('[resend] send failed: $e');
    }
  }

  void restoreDeletedChat(TrashedChat chat) {
    if (chat.type == TrashedChatType.dm) {
      final msgs = chats.putIfAbsent(chat.chatId, () => []);
      msgs.addAll(chat.messages);
      msgs.sort((a, b) => a.time.compareTo(b.time));
      chatsVersion.value++;
      setState(() {});
      schedulePersistChats(chatId: chat.chatId);
    }
    TrashManager.instance.permanentlyDeleteChat(chat.id);
  }

  void restoreDeletedMessage(TrashedMessage item) {
    final msgs = chats[item.chatId];
    if (msgs != null) {
      final alreadyExists = msgs.any((m) => m.id == item.message.id);
      if (!alreadyExists) {
        msgs.add(item.message);
        msgs.sort((a, b) => a.time.compareTo(b.time));
        _bumpForChat(item.chatId);
        schedulePersistChats(chatId: item.chatId);
      }
    }
    TrashManager.instance.permanentlyDeleteMessage(item.id);
  }

  void _deleteChat(String chatId, String displayName) {
    final messages = List<ChatMessage>.from(chats[chatId] ?? []);
    TrashManager.instance.addDeletedChat(TrashedChat(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      chatId: chatId,
      displayName: displayName,
      type: TrashedChatType.dm,
      messages: messages,
      deletedAt: DateTime.now(),
    ));

    chats.remove(chatId);

    chatsVersion.value++;
    setState(() {});

    schedulePersistChats(chatId: chatId);
  }

  Future<void> _syncBlocklistFromServer() async {
    try {
      final me = await AccountManager.getCurrentAccount();
      if (me == null) return;
      final token = await AccountManager.getToken(me);
      if (token == null) return;
      final res = await http.get(
        Uri.parse('$serverBase/blocks'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['blocked'] as List?)?.cast<String>() ?? [];
        await BlocklistManager.syncFromServer(list);
        debugPrint('[blocklist] synced from server: $list');
      }
    } catch (e) {
      debugPrint('[blocklist] sync failed: $e');
    }
  }

  Future<void> _blockUser(String username, String displayName) async {
    await BlocklistManager.block(username);
    try {
      final me = await AccountManager.getCurrentAccount();
      if (me == null) return;
      final token = await AccountManager.getToken(me);
      if (token == null) return;
      final res = await http.post(
        Uri.parse('$serverBase/block/$username'),
        headers: {'authorization': 'Bearer $token'},
      );
      debugPrint('[block] server response: ${res.statusCode}');
    } catch (e) {
      debugPrint('[block] server call failed: $e');
    }
  }

  Future<void> _unblockUser(String username) async {
    await BlocklistManager.unblock(username);
    try {
      final me = await AccountManager.getCurrentAccount();
      if (me == null) return;
      final token = await AccountManager.getToken(me);
      if (token == null) return;
      final res = await http.delete(
        Uri.parse('$serverBase/block/$username'),
        headers: {'authorization': 'Bearer $token'},
      );
      debugPrint('[unblock] server response: ${res.statusCode}');
    } catch (e) {
      debugPrint('[unblock] server call failed: $e');
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      return wifiIP;
    } catch (e) {
      debugPrint('Local IP error: $e');
      return null;
    }
  }

  Future<String?> _getPublicIp() async {
    try {
      final res = await http.get(Uri.parse(publicIpApi));
      if (res.statusCode == 200) return res.body.trim();
    } catch (e) {
      debugPrint('Public IP error: $e');
    }
    return null;
  }

  void _onSearchRequested() {
    if (isDesktop) {
      setState(() {
        selectedChatOther = null;
        selectedExternalGroup = null;
        selectedExternalServer = null;
      });
    }

    final double titleBarHeight = 42.0;
    final TextEditingController _dialogSearchCtrl = TextEditingController();
    final bool useGlass = SettingsManager.liquidGlassOnSearch.value;

    setState(() => _isSearchOpen = true);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: useGlass ? Colors.black26 : Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        final bool isDesktop = MediaQuery.of(context).size.width > 700;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: titleBarHeight + 8.0,
              left: 16.0,
              right: 16.0,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: isDesktop ? 640 : double.infinity,
                  child: SearchDialogContent(
                          controller: _dialogSearchCtrl,
                          onSelect: (username) {
                            Navigator.of(context).pop();
                            if (username != null && username.isNotEmpty) {
                              try {
                                final chatId = chatIdForUser(username);
                                chats.putIfAbsent(chatId, () => []);
                                setState(() {
                                  selectedChatOther = username;
                                  selectedExternalGroup = null;
                                  selectedExternalServer = null;
                                });
                              } catch (_) {}
                              if (!isDesktop) {
                                Navigator.of(context)
                                    .push(
                                  _chatRoute((_) => ChatScreen(
                                        myUsername: currentUsername ?? 'me',
                                        otherUsername: username,
                                        onSend: (t, replyTo) =>
                                            _sendChatMessage(
                                                username, t, replyTo),
                                        onTyping: () =>
                                            _handleSendTyping(username),
                                        onRequestResend: (id) {
                                          if (id != null) _requestResend(id);
                                        },
                                        onEditMessage: (id, text) =>
                                            _editChatMessage(
                                                username, id, text),
                                        onDeleteMessage: (id) =>
                                            _deleteChatMessage(id),
                                      )),
                                )
                                    .then((_) {
                                  if (mounted)
                                    setState(() {
                                      selectedChatOther = null;
                                    });
                                });
                              }
                            }
                          },
                        ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _isSearchOpen = false);
    });
  }

  Widget _buildMobileAppBar(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.applyGlobally,
      builder: (_, apply, __) {
        return ValueListenableBuilder<String?>(
          valueListenable: SettingsManager.chatVideoBackground,
          builder: (_, videoPath, __) {
        return ValueListenableBuilder<String?>(
          valueListenable: SettingsManager.chatBackground,
          builder: (_, path, __) {
            final makeTransparent = apply &&
                ((path != null && File(path).existsSync()) ||
                    (videoPath != null && File(videoPath).existsSync()));
            return ValueListenableBuilder<bool>(
              valueListenable: SettingsManager.showAccountIndicator,
              builder: (_, showInd, __) => AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: wsConnectedNotifier,
                      builder: (_, connected, __) {
                        final baseStyle = const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold);
                        final targetScale =
                            (baseStyle.fontSize ?? 20) * 1.2 / 24.0;
                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: 1.0, end: connected ? targetScale : 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: GestureDetector(
                            onTap: () => showAboutOnyxDialog(context),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Image.asset('assets/onyx-512.png',
                                  width: 25, height: 25, fit: BoxFit.contain),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => showAboutOnyxDialog(context),
                      child: ConnectionTitle(
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const ProxyShieldBadge(),
                  ],
                ),
                centerTitle: true,
                leading: (showInd && currentUsername != null)
                    ? Container(
                        padding: const EdgeInsets.only(left: 17, top: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentDisplayName ?? currentUsername!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '@$currentUsername',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                leadingWidth: (showInd && currentUsername != null) ? 100 : null,
                backgroundColor: makeTransparent
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.surface,
                elevation: makeTransparent ? 0 : 0,
                actions: [
                  if (_index == 0 || !isDesktop)
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _onSearchRequested,
                    ),
                ],
              ),
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _buildDesktopLayoutWithAppBar(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsManager.desktopNavPosition,
      builder: (context, navPosition, _) {
        final isNavBottom = navPosition == 'bottom';

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 42.0),
              child: Column(
                children: [
                  const UpdateBanner(),
                  Expanded(
                    child: Row(
                      children: [
                        if (!isNavBottom)
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: -80.0, end: 0.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, offset, child) {
                              return Transform.translate(
                                offset: Offset(offset, 0),
                                child: Opacity(
                                  opacity:
                                      (1.0 + (offset / 80.0)).clamp(0.0, 1.0),
                                  child: child,
                                ),
                              );
                            },
                            child: NavigationRail(
                              selectedIndex: _index < 5 ? _index : 4,
                              onDestinationSelected: (i) => _onTabSelected(i),
                              labelType: NavigationRailLabelType.none,
                              destinations: [
                                NavigationRailDestination(
                                  icon: AnimatedNavIcon(
                                    icon: Icons.chat_bubble,
                                    size: 24,
                                    isSelected: _index == 0,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 300,
                                  ),
                                  selectedIcon: AnimatedNavIcon(
                                    icon: Icons.chat_bubble,
                                    size: 26,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 0,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 300,
                                  ),
                                  label: Text(
                                      AppLocalizations.of(context).navChats),
                                ),
                                NavigationRailDestination(
                                  icon: AnimatedNavIcon(
                                    icon: Icons.group,
                                    size: 24,
                                    isSelected: _index == 1,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 400,
                                  ),
                                  selectedIcon: AnimatedNavIcon(
                                    icon: Icons.group,
                                    size: 26,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 1,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 400,
                                  ),
                                  label: Text(
                                      AppLocalizations.of(context).navGroups),
                                ),
                                NavigationRailDestination(
                                  icon: AnimatedNavIcon(
                                    icon: Icons.bookmark_outlined,
                                    size: 24,
                                    isSelected: _index == 2,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 500,
                                  ),
                                  selectedIcon: AnimatedNavIcon(
                                    icon: Icons.bookmark,
                                    size: 26,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 2,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 500,
                                  ),
                                  label: Text(AppLocalizations.of(context)
                                      .navFavorites),
                                ),
                                NavigationRailDestination(
                                  icon: AnimatedNavIcon(
                                    icon: Icons.person,
                                    size: 24,
                                    isSelected: _index == 3,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 600,
                                  ),
                                  selectedIcon: AnimatedNavIcon(
                                    icon: Icons.person,
                                    size: 26,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 3,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 600,
                                  ),
                                  label: Text(
                                      AppLocalizations.of(context).navAccounts),
                                ),
                                NavigationRailDestination(
                                  icon: AnimatedNavIcon(
                                    icon: Icons.settings,
                                    size: 24,
                                    isSelected: _index == 4,
                                    animationType: NavIconAnimationType.spin,
                                    entryDelay: 700,
                                  ),
                                  selectedIcon: AnimatedNavIcon(
                                    icon: Icons.settings,
                                    size: 26,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 4,
                                    animationType: NavIconAnimationType.spin,
                                    entryDelay: 700,
                                  ),
                                  label: Text(
                                      AppLocalizations.of(context).navSettings),
                                ),
                              ],
                            ),
                          ),
                        ValueListenableBuilder<double>(
                          valueListenable: _chatsPanelWidthNotifier,
                          builder: (_, width, child) =>
                              SizedBox(width: width, child: child),
                          child: Column(
                            children: [
                              AppBar(
                                automaticallyImplyLeading: false,
                                centerTitle: isNavBottom,
                                leadingWidth: isNavBottom ? 80 : null,
                                leading: ValueListenableBuilder<bool>(
                                  valueListenable:
                                      SettingsManager.showAccountIndicator,
                                  builder: (_, showInd, __) {
                                    if (isNavBottom &&
                                        showInd &&
                                        currentUsername != null) {
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentDisplayName ??
                                                  currentUsername!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '@$currentUsername',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return isNavBottom
                                        ? const SizedBox(width: 48)
                                        : const SizedBox.shrink();
                                  },
                                ),
                                title: isNavBottom
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ValueListenableBuilder<bool>(
                                            valueListenable:
                                                wsConnectedNotifier,
                                            builder: (_, connected, __) {
                                              final baseStyle = const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold);
                                              final targetScale =
                                                  (baseStyle.fontSize ?? 20) *
                                                      1.2 /
                                                      24.0;
                                              return TweenAnimationBuilder<
                                                  double>(
                                                tween: Tween<double>(
                                                    begin: 1.0,
                                                    end: connected
                                                        ? targetScale
                                                        : 1.0),
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                                builder: (_, scale, child) =>
                                                    Transform.scale(
                                                        scale: scale,
                                                        child: child),
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      showAboutOnyxDialog(
                                                          context),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 2),
                                                    child: Image.asset(
                                                        'assets/onyx-512.png',
                                                        width: 25,
                                                        height: 25,
                                                        fit: BoxFit.contain),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () =>
                                                showAboutOnyxDialog(context),
                                            child: ConnectionTitle(
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const ProxyShieldBadge(),
                                        ],
                                      )
                                    : Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ValueListenableBuilder<bool>(
                                              valueListenable:
                                                  wsConnectedNotifier,
                                              builder: (_, connected, __) {
                                                final baseStyle =
                                                    const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold);
                                                final targetScale =
                                                    (baseStyle.fontSize ?? 20) *
                                                        1.2 /
                                                        24.0;
                                                return TweenAnimationBuilder<
                                                    double>(
                                                  tween: Tween<double>(
                                                      begin: 1.0,
                                                      end: connected
                                                          ? targetScale
                                                          : 1.0),
                                                  duration: const Duration(
                                                      milliseconds: 300),
                                                  curve: Curves.easeInOut,
                                                  builder: (_, scale, child) =>
                                                      Transform.scale(
                                                          scale: scale,
                                                          child: child),
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        showAboutOnyxDialog(
                                                            context),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 2),
                                                      child: Image.asset(
                                                          'assets/onyx-512.png',
                                                          width: 25,
                                                          height: 25,
                                                          fit: BoxFit.contain),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () =>
                                                  showAboutOnyxDialog(context),
                                              child: ConnectionTitle(
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const ProxyShieldBadge(),
                                          ],
                                        ),
                                      ),
                                actions: [
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: _onSearchRequested,
                                  ),
                                ],
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                                elevation: 0,
                                scrolledUnderElevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              Expanded(
                                child: ValueListenableBuilder<String>(
                                  valueListenable:
                                      SettingsManager.desktopNavPosition,
                                  builder: (context, navPos, _) {
                                    final tabChild = <Widget>[
                                      ChatsTab(
                                        chats: chats,
                                        username: currentUsername,
                                        onOpenChat: (other) async {
                                          if (_chatsLoadCompleter != null &&
                                              !_chatsLoadCompleter!
                                                  .isCompleted) {
                                            await _chatsLoadCompleter!.future;
                                          }
                                          if (!mounted) return;
                                          final chatId = chatIdForUser(other);
                                          chats.putIfAbsent(chatId, () => []);
                                          setState(() {
                                            selectedChatOther = other;
                                            selectedGroup = null;
                                            selectedExternalGroup = null;
                                            selectedExternalServer = null;
                                            _selectedFavoriteId = null;
                                          });

                                          if (!isDesktop)
                                            FocusScope.of(context)
                                                .requestFocus(FocusNode());
                                        },
                                        onDeleteChat: _deleteChat,
                                        onBlockUser: _blockUser,
                                        onUnblockUser: _unblockUser,
                                      ),
                                      GroupsTab(
                                        onOpenGroup: (group) {
                                          if (group.isExternal) {
                                            final server = ExternalServerManager
                                                .servers.value
                                                .where((s) =>
                                                    s.id ==
                                                    group.externalServerId)
                                                .firstOrNull;
                                            if (server == null) return;
                                            setState(() {
                                              selectedChatOther = null;
                                              selectedGroup = null;
                                              selectedExternalGroup = group;
                                              selectedExternalServer = server;
                                              _selectedFavoriteId = null;
                                            });
                                          } else {
                                            setState(() {
                                              selectedChatOther = null;
                                              selectedGroup = group;
                                              selectedExternalGroup = null;
                                              selectedExternalServer = null;
                                              _selectedFavoriteId = null;
                                            });
                                          }
                                        },
                                      ),
                                      FavoritesTab(
                                        favorites: _favorites,
                                        onOpen: (id) {
                                          setState(() {
                                            selectedChatOther = null;
                                            selectedGroup = null;
                                            selectedExternalGroup = null;
                                            selectedExternalServer = null;
                                            _selectedFavoriteId = id;
                                          });
                                        },
                                        onAdd: _addFavorite,
                                        onDelete: _deleteFavorite,
                                      ),
                                      AccountsTab(
                                        currentUsername: currentUsername,
                                        currentUin: currentUin,
                                        identityPubFp:
                                            _identityPublicKey != null
                                                ? _computePubkeyFpHex(
                                                    _identityPublicKey!.bytes)
                                                : null,
                                        onLogin: _login,
                                        onRegister: _register,
                                        onQrLogin: loginWithQrToken,
                                        onSwitchAccount:
                                            _switchToAccountWithAuth,
                                        onDeleteAccount: _deleteAccount,
                                        logs: _log,
                                        currentTheme: widget.currentTheme,
                                      ),
                                      SettingsTab(
                                        currentTheme: widget.currentTheme,
                                        isDarkMode: widget.isDarkMode,
                                        onThemeChanged: widget.onThemeChanged,
                                        onGenerateIdentity: _generateIdentity,
                                        onUploadPubkey: _uploadPubkeyToServer,
                                        onRotateKey: rotateIdentityKey,
                                        onFullSessionReset: fullSessionReset,
                                        onConnectWs: _connectWs,
                                        onDisconnectWs: _disconnectWs,
                                        onLogout: _logout,
                                        logs: _log,
                                        isPrimaryDevice: _isPrimaryDevice,
                                        onShowPassphrase: _showPassphrase,
                                        onChangePassword: _changePassword,
                                        onOpenSessions: _openSessions,
                                        isActive: _index == 4,
                                        onOpenChat: (username) {
                                          _onTabSelected(0);
                                          final chatId =
                                              chatIdForUser(username);
                                          chats.putIfAbsent(chatId, () => []);
                                          setState(() {
                                            selectedChatOther = username;
                                            selectedGroup = null;
                                            selectedExternalGroup = null;
                                            selectedExternalServer = null;
                                            _selectedFavoriteId = null;
                                          });
                                        },
                                      ),
                                      if (_isPrimaryDevice)
                                        ActiveSessionsTab(
                                          serverBase: serverBase,
                                          username: currentUsername,
                                          onBack: () => _onTabSelected(4),
                                        ),
                                    ][_index];

                                    if (navPos != 'bottom') return tabChild;
                                    return MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                        padding: MediaQuery.of(context)
                                                .padding +
                                            const EdgeInsets.only(bottom: 76),
                                      ),
                                      child: tabChild,
                                    );
                                  },
                                ),
                              ),
                              if (false) const SizedBox.shrink(),
                            ],
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              _chatsPanelWidthNotifier
                                  .value = (_chatsPanelWidthNotifier.value +
                                      details.delta.dx)
                                  .clamp(200.0,
                                      MediaQuery.of(context).size.width * 0.6);
                            },
                            child: Container(
                              width: 6,
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.3),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: SettingsManager.applyGlobally,
                            builder: (_, apply, __) {
                              Widget content = (_selectedFavoriteId != null)
                                  ? getFavoritesScreen(
                                      _selectedFavoriteId!,
                                      _favorites
                                          .firstWhere((f) =>
                                              f.id == _selectedFavoriteId!)
                                          .title,
                                    )
                                  : (selectedChatOther != null &&
                                          currentUsername != null)
                                      ? _chatScreenCache.putIfAbsent(
                                          '${selectedChatOther!}:${currentUsername!}',
                                          () => ChatScreen(
                                            key: ValueKey<String>(
                                                '${selectedChatOther!}:${currentUsername!}'),
                                            myUsername: currentUsername!,
                                            otherUsername: selectedChatOther!,
                                            onSend: (t, replyTo) =>
                                                _sendChatMessage(
                                                    selectedChatOther!,
                                                    t,
                                                    replyTo),
                                            onTyping: () => _handleSendTyping(
                                                selectedChatOther!),
                                            onRequestResend: (id) {
                                              if (id != null)
                                                _requestResend(id);
                                            },
                                            onEditMessage: (id, text) =>
                                                _editChatMessage(
                                                    selectedChatOther!,
                                                    id,
                                                    text),
                                            onDeleteMessage: (id) =>
                                                _deleteChatMessage(id),
                                          ),
                                        )
                                      : (selectedChatOther != null)
                                          ? Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : (selectedGroup != null)
                                              ? _groupChatScreenCache
                                                  .putIfAbsent(
                                                  selectedGroup!.id,
                                                  () => GroupChatScreen(
                                                    key: ValueKey<int>(
                                                        selectedGroup!.id),
                                                    group: selectedGroup!,
                                                  ),
                                                )
                                              : (selectedExternalGroup !=
                                                          null &&
                                                      selectedExternalServer !=
                                                          null)
                                                  ? _externalGroupChatScreenCache
                                                      .putIfAbsent(
                                                      'ext_${selectedExternalServer!.id}_${selectedExternalGroup!.id}',
                                                      () =>
                                                          ExternalGroupChatScreen(
                                                        key: ValueKey<String>(
                                                            'ext_${selectedExternalServer!.id}_${selectedExternalGroup!.id}'),
                                                        group:
                                                            selectedExternalGroup!,
                                                        server:
                                                            selectedExternalServer!,
                                                      ),
                                                    )
                                                  : ValueListenableBuilder<
                                                      bool>(
                                                      valueListenable:
                                                          SettingsManager
                                                              .showAccountGraph,
                                                      builder:
                                                          (_, showGraph, __) {
                                                        if (showGraph &&
                                                            isDesktop) {
                                                          return AccountGraphView(
                                                            onChatTap:
                                                                (username) =>
                                                                    setState(
                                                                        () {
                                                              selectedChatOther =
                                                                  username;
                                                            }),
                                                            onGroupTap:
                                                                (group) =>
                                                                    setState(
                                                                        () {
                                                              selectedGroup =
                                                                  group;
                                                              selectedExternalGroup =
                                                                  null;
                                                              selectedExternalServer =
                                                                  null;
                                                            }),
                                                            onExternalGroupTap:
                                                                (group) {
                                                              try {
                                                                final srv = ExternalServerManager
                                                                    .servers
                                                                    .value
                                                                    .firstWhere((s) =>
                                                                        s.id ==
                                                                        group
                                                                            .externalServerId);
                                                                setState(() {
                                                                  selectedExternalGroup =
                                                                      group;
                                                                  selectedExternalServer =
                                                                      srv;
                                                                  selectedGroup =
                                                                      null;
                                                                });
                                                              } catch (_) {}
                                                            },
                                                            onFavoriteTap:
                                                                (favId) =>
                                                                    setState(
                                                                        () {
                                                              _selectedFavoriteId =
                                                                  favId;
                                                            }),
                                                          );
                                                        }
                                                        return Center(
                                                          child: glassCard(
                                                            context: context,
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          24,
                                                                      vertical:
                                                                          32),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Image.asset(
                                                                    'assets/onyx_icon.png',
                                                                    width: 56,
                                                                    height: 56,
                                                                    opacity:
                                                                        const AlwaysStoppedAnimation(
                                                                            0.85),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          16),
                                                                  ValueListenableBuilder<
                                                                      Locale>(
                                                                    valueListenable:
                                                                        SettingsManager
                                                                            .appLocale,
                                                                    builder: (_,
                                                                            locale,
                                                                            __) =>
                                                                        Text(
                                                                      AppLocalizations(
                                                                              locale)
                                                                          .localizeMotivationalHint(
                                                                              _motivationalHints[_motivationalHintIndex]),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color: Theme.of(context)
                                                                            .colorScheme
                                                                            .onSurface,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );

                              if (isDesktop && apply) {
                                return Stack(
                                  children: [
                                    const ChatBackgroundLayer(),
                                    content,
                                  ],
                                );
                              }

                              return content;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(height: 42, child: CustomTitleBar()),
            ),
            if (currentUsername != null && !isNavBottom)
              Positioned(
                left: 8,
                bottom: 8,
                child: ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.showAccountIndicator,
                  builder: (_, showInd, __) {
                    if (!showInd) return const SizedBox.shrink();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentDisplayName ?? currentUsername!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '@$currentUsername',
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNavButton(IconData icon, int index) {
    final isSelected = _index == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(
          icon,
          size: 22,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        onPressed: () => _onTabSelected(index),
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget glassCard({required BuildContext context, required Widget child}) {
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, ___) {
            final baseColor = SettingsManager.getElementColor(
              Theme.of(context).colorScheme.surfaceContainerHighest,
              brightness,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUsername == null) {
      return Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(16, isDesktop ? 16 + 42 : 16, 16, 16),
                child: AccountsTab(
                  currentUsername: null,
                  currentUin: null,
                  identityPubFp: null,
                  onLogin: _login,
                  onRegister: _register,
                  onQrLogin: loginWithQrToken,
                  onSwitchAccount: _switchToAccountWithAuth,
                  onDeleteAccount: _deleteAccount,
                  logs: _log,
                  currentTheme: widget.currentTheme,
                ),
              ),
            ),
            if (isDesktop)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(height: 42, child: CustomTitleBar()),
              ),
          ],
        ),
      );
    }

    final tabs = <Widget>[
      ChatsTab(
        chats: chats,
        username: currentUsername,
        onOpenChat: (other) async {
          if (_chatsLoadCompleter != null &&
              !_chatsLoadCompleter!.isCompleted) {
            await _chatsLoadCompleter!.future;
          }
          if (!mounted) return;

          final chatId = chatIdForUser(other);
          chats.putIfAbsent(chatId, () => []);
          if (!isDesktop) {
            if (mounted)
              setState(() {
                selectedChatOther = other;
              });
            await Navigator.of(context).push(
              _chatRoute((_) => ChatScreen(
                    myUsername: currentUsername ?? 'me',
                    otherUsername: other,
                    onSend: (t, replyTo) => _sendChatMessage(other, t, replyTo),
                    onTyping: () => _handleSendTyping(other),
                    onRequestResend: (id) {
                      if (id != null) _requestResend(id);
                    },
                    onEditMessage: (id, text) =>
                        _editChatMessage(other, id, text),
                    onDeleteMessage: (id) => _deleteChatMessage(id),
                  )),
            );
            if (mounted)
              setState(() {
                selectedChatOther = null;
              });
            _sendPresence('online');
          }
        },
        onDeleteChat: _deleteChat,
        onBlockUser: _blockUser,
        onUnblockUser: _unblockUser,
      ),
      GroupsTab(
        onOpenGroup: (group) {
          if (group.isExternal) {
            final server = ExternalServerManager.servers.value
                .where((s) => s.id == group.externalServerId)
                .firstOrNull;
            if (server == null) return;
            if (isDesktop) {
              setState(() {
                selectedChatOther = null;
                selectedGroup = null;
                selectedExternalGroup = group;
                selectedExternalServer = server;
                _selectedFavoriteId = null;
              });
            } else {
              Navigator.of(context).push(
                _chatRoute((_) =>
                    ExternalGroupChatScreen(group: group, server: server)),
              );
            }
          } else if (!isDesktop) {
            Navigator.of(context).push(
              _chatRoute((_) => GroupChatScreen(group: group)),
            );
          } else {
            setState(() {
              selectedChatOther = null;
              selectedGroup = group;
              selectedExternalGroup = null;
              selectedExternalServer = null;
            });
          }
        },
      ),
      FavoritesTab(
        favorites: _favorites,
        onOpen: (id) {
          final fav = _favorites.firstWhere((f) => f.id == id);
          if (isDesktop) {
            setState(() => _selectedFavoriteId = id);
          } else {
            Navigator.push(
              context,
              _chatRoute((_) => getFavoritesScreen(id, fav.title)),
            );
          }
        },
        onAdd: _addFavorite,
        onDelete: _deleteFavorite,
      ),
      AccountsTab(
        currentUsername: currentUsername,
        currentUin: currentUin,
        identityPubFp: _identityPublicKey != null
            ? _computePubkeyFpHex(_identityPublicKey!.bytes)
            : null,
        onLogin: _login,
        onRegister: _register,
        onQrLogin: loginWithQrToken,
        onSwitchAccount: _switchToAccountWithAuth,
        onDeleteAccount: _deleteAccount,
        logs: _log,
        currentTheme: widget.currentTheme,
      ),
      SettingsTab(
        currentTheme: widget.currentTheme,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        onGenerateIdentity: _generateIdentity,
        onUploadPubkey: _uploadPubkeyToServer,
        onRotateKey: rotateIdentityKey,
        onFullSessionReset: fullSessionReset,
        onConnectWs: _connectWs,
        onDisconnectWs: _disconnectWs,
        onLogout: _logout,
        logs: _log,
        isPrimaryDevice: _isPrimaryDevice,
        onShowPassphrase: _showPassphrase,
        onChangePassword: _changePassword,
        onOpenSessions: _openSessions,
        isActive: _index == 4,
        onOpenChat: (username) {
          _onTabSelected(0);
          final chatId = chatIdForUser(username);
          chats.putIfAbsent(chatId, () => []);
          setState(() {
            selectedChatOther = username;
            selectedGroup = null;
            selectedExternalGroup = null;
            selectedExternalServer = null;
            _selectedFavoriteId = null;
          });
        },
      ),
      if (_isPrimaryDevice)
        ActiveSessionsTab(
          serverBase: serverBase,
          username: currentUsername,
          onBack: () => _onTabSelected(4),
        ),
    ];

    final Widget mainContent = isDesktop
        ? Listener(
            onPointerDown: (event) {
              if (event.buttons == 16) {
                _handleKeyOrMouseBack();
              }
            },
            child: SafeArea(
              bottom: false,
              child: _buildDesktopLayoutWithAppBar(context),
            ),
          )
        : SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildMobileAppBar(context),
                    const UpdateBanner(),
                    Expanded(
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: MediaQuery.of(context).padding +
                              const EdgeInsets.only(bottom: 76),
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: SettingsManager.swipeTabsEnabled,
                          builder: (_, swipeTabs, __) => PageView(
                            controller: _pageController,
                            physics: swipeTabs
                                ? const BouncingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            onPageChanged: _handlePageChanged,
                            children: tabs,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_mobileGraphEnabled) _buildGraphOverlay(),
                if (_mobileGraphEnabled) _buildGraphHandle(),
              ],
            ),
          );

    return GlassBackdropScope(
      child: Scaffold(
        body: Stack(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: SettingsManager.applyGlobally,
            builder: (ctx, apply, _) {
              if (!apply || isDesktop) return const SizedBox.shrink();
              return const ChatBackgroundLayer();
            },
          ),
          SafeArea(
            bottom: false,
            child: mainContent,
          ),
          ValueListenableBuilder<String>(
            valueListenable: SettingsManager.desktopNavPosition,
            builder: (ctx, navPosition, _) {
              final showOnDesktop = navPosition == 'bottom';
              final shouldShow = !isDesktop || (isDesktop && showOnDesktop);
              if (!shouldShow) return const SizedBox.shrink();

              return ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, __) {
                  return ValueListenableBuilder<double>(
                    valueListenable: SettingsManager.elementOpacity,
                    builder: (_, opacity, __) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: tabPullSearchOpen,
                        builder: (_, pullSearchOpen, __) {
                      final panelW = _chatsPanelWidthNotifier.value;
                      final navWidth = isDesktop
                          ? min(panelW - 24.0, 420.0)
                          : MediaQuery.of(context).size.width / 1.8;
                      final leftPad =
                          isDesktop ? max(12.0, (panelW - navWidth) / 2) : 70.0;

                      final scheme = Theme.of(context).colorScheme;
                      final navBackground = SettingsManager.getElementColor(
                              scheme.surfaceContainerHighest, brightness)
                          .withValues(alpha: opacity);
                      final hideBottomNav = !isDesktop && _graphOverlayVisible;
                      final isLiquidGlass = !isDesktop &&
                          SettingsManager.liquidGlassOnNavBar.value;
                      // The Scaffold resizes for the keyboard, which would
                      // otherwise drag this floating bottom nav bar up over
                      // the per-tab pull-search panel — hide it the same way
                      // the global search dialog does.
                      final hideForSearch =
                          !isDesktop && (_isSearchOpen || pullSearchOpen);

                      return Positioned.fill(
                        child: Align(
                          alignment: isDesktop
                              ? Alignment.bottomLeft
                              : Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 100.0, end: 0.0),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, offset, child) {
                              return Transform.translate(
                                offset: Offset(0, offset),
                                child: Opacity(
                                  opacity:
                                      (1.0 - (offset / 100.0)).clamp(0.0, 1.0),
                                  child: AnimatedSlide(
                                    offset: hideBottomNav
                                        ? const Offset(0.0, 1.75)
                                        : (hideForSearch && !isLiquidGlass)
                                            ? const Offset(0.0, 1.75)
                                            : Offset.zero,
                                    duration: const Duration(milliseconds: 320),
                                    curve: (hideBottomNav || hideForSearch)
                                        ? Curves.easeInCubic
                                        : Curves.easeOutCubic,
                                    child: AnimatedOpacity(
                                      opacity: (hideBottomNav ||
                                              (hideForSearch && isLiquidGlass))
                                          ? 0.0
                                          : 1.0,
                                      duration:
                                          const Duration(milliseconds: 260),
                                      curve: (hideBottomNav || hideForSearch)
                                          ? Curves.easeInCubic
                                          : Curves.easeOutCubic,
                                      child: AnimatedScale(
                                        scale: (hideForSearch && isLiquidGlass)
                                            ? 0.88
                                            : 1.0,
                                        duration: const Duration(milliseconds: 280),
                                        curve: Curves.easeInCubic,
                                        child: child,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: AdaptiveNavBar(
                              selectedIndex: _index,
                              onTap: _onTabSelected,
                              isDesktop: isDesktop,
                              navWidth: navWidth,
                              leftPad: leftPad,
                              navBackground: navBackground,
                            ),
                          ),
                        ),
                      );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
    );
  }
}

class _LruCache<K, V> {
  final int maxSize;
  final _map = LinkedHashMap<K, V>();

  _LruCache(this.maxSize);

  V putIfAbsent(K key, V Function() ifAbsent) {
    if (_map.containsKey(key)) {
      final value = _map.remove(key) as V;
      _map[key] = value;
      return value;
    }
    final value = ifAbsent();
    _map[key] = value;
    if (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
    return value;
  }

  void clear() => _map.clear();
  int get length => _map.length;
}

class _KeyPairData {
  final SimpleKeyPairData keyPair;
  final SimplePublicKey publicKey;

  _KeyPairData(this.keyPair, this.publicKey);
}

_KeyPairData _decodeIdentity(Map<String, String> identity) {
  final privBytes = base64Decode(identity['priv']!);
  final pubBytes = base64Decode(identity['pub']!);
  final kp = SimpleKeyPairData(
    Uint8List.fromList(privBytes),
    publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
    type: KeyPairType.x25519,
  );
  final pk = SimplePublicKey(pubBytes, type: KeyPairType.x25519);
  return _KeyPairData(kp, pk);
}
