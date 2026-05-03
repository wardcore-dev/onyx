// lib/screens/root_screen.dart
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ONYX/background/background_worker.dart';
import 'package:ONYX/background/notification_service.dart';
import 'package:ONYX/background/register_sync.dart';
import 'package:ONYX/models/favorite_chat.dart';
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
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:convert/convert.dart';
import 'package:window_manager/window_manager.dart';
import '../managers/external_server_manager.dart';
import '../models/external_server.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../background/foreground_task_handler.dart';

import '../globals.dart';
import '../utils/upload_task.dart';
import '../widgets/adaptive_blur.dart';
import '../voice/voice_channel_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/unread_manager.dart';
import '../models/group.dart';
import '../models/app_themes.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/auth_dialog.dart';
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
import '../widgets/message_bubble.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/cute_bottom_nav.dart';
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
import '../utils/media_cache.dart';
import '../managers/windows_notification_popup.dart';
import '../l10n/app_localizations.dart';
import '../utils/update_checker.dart';
import '../widgets/update_banner.dart';
import '../widgets/about_onyx_dialog.dart';
import '../screens/pin_code_screen.dart';
import 'package:local_auth/local_auth.dart';

final Map<String, List<int>> _pubkeyCache = {};

final Map<String, List<Map<String, dynamic>>> _devicePubkeysCache = {};
DateTime? _lastPubkeyUploadTime;
final X25519 _x25519 = X25519();
final Cipher _xchacha = Xchacha20.poly1305Aead();
final ValueNotifier<double> _chatsPanelWidthNotifier = ValueNotifier<double>(300.0);

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
  String? _selectedFavoriteId;
  
  final Set<String> _favoritesMediaPrefetched = {};
  
  final Set<String> _chatsMediaPrefetched = {};

  Stream<dynamic>? wsStream;
  
  List<FavoriteChat> get favorites => List.unmodifiable(_favorites);

  bool _isSwitchingAccount = false;
  String? _pendingAccountSwitch;

  bool _manualWsDisconnect =
      false; 
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
    
    if (newIndex == 5 && !_isPrimaryDevice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(4);
        }
      });
      return;
    }

    _pendingPageIndex = newIndex;
    _pageChangeDebounce?.cancel();
    _pageChangeDebounce = Timer(const Duration(milliseconds: 50), () {
      if (mounted && _index != _pendingPageIndex) {
        setState(() => _index = _pendingPageIndex);
      }
    });
  }

  void showSnack(String text) {
    if (!mounted) return;
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
    persistChats();
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

      rootScreenKey.currentState?.showSnack('Record canceled');
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

      if (path != null && !kIsWeb && Platform.isWindows && path.endsWith('.wav')) {
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

  void updateFavorite(FavoriteChat updated) {
    final index = _favorites.indexWhere((f) => f.id == updated.id);
    if (index != -1) {
      setState(() {
        _favorites[index] = updated;
      });
      _saveFavorites();
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
  }

  Future<void> _requestStatusSnapshotForKnownUsers() async {
    try {
      final username = await AccountManager.getCurrentAccount();
      if (username == null) return;
      final token = await AccountManager.getToken(username);
      if (token == null) return;

      final res = await http.get(Uri.parse('$serverBase/conversations'), headers: {
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
          _ws!.sink.add(jsonEncode({'type': 'request_status_snapshot', 'users': users.toList()}));
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
        encoder =
            AudioEncoder.aacLc; 
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

      rootScreenKey.currentState?.showSnack('Record started');
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
      
      final appSupport = await getApplicationSupportDirectory();
      final voiceDir = Directory('${appSupport.path}/voice_cache');

      final imageCacheDir = Directory('${appSupport.path}/image_cache');

      int totalBytes = 0;

      if (await voiceDir.exists()) {
        await for (final f in voiceDir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            try { totalBytes += await f.length(); } catch (_) {}
          }
        }
      }

      if (includeImageCache && await imageCacheDir.exists()) {
        await for (final f in imageCacheDir.list(recursive: true, followLinks: false)) {
          if (f is File) {
            try { totalBytes += await f.length(); } catch (_) {}
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
        
        final duration = recordedDuration ?? Duration(seconds: (bytes.length / 16000).ceil());

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
                      rootScreenKey.currentState
                          ?.showSnack('Voice message cancelled');
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
        return await _performVoiceUploadFavorite(to, path, replyTo, onTaskCreated);
      }

      final token = await AccountManager.getToken(currentUsername ?? '');
      if (token == null) {
        _appendLog('[voice.upload] no token');
        rootScreenKey.currentState?.showSnack('Not logged in');
        return;
      }

      final bool isPersonalChat = !to.startsWith('fav:');
      final String noNotifyParam = isPersonalChat ? '&no_notify=1' : '';
      final String uriStr = '$serverBase/voice/upload?to=${Uri.encodeComponent(to)}$noNotifyParam';
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
        final (enc, keyB64) = await encryptMediaRandom(plainBytes, kind: 'voice');
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
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'voice', 'ext': ext, 'size': bytesToUpload.length, 'contentType': 'application/octet-stream'}),
      );
      if (presignResp.statusCode == 413) {
        dynamic body;
        try { body = jsonDecode(presignResp.body); } catch (_) {}
        rootScreenKey.currentState?.showSnack(
          body is Map ? (body['detail'] ?? 'Storage quota exceeded') : 'Storage quota exceeded',
        );
        return;
      }
      if (presignResp.statusCode != 200) {
        debugPrint('<<_performVoiceUpload>> presign failed: ${presignResp.statusCode}');
        rootScreenKey.currentState?.showSnack('Upload failed: ${presignResp.statusCode}');
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
        final putRequest =
            http.StreamedRequest('PUT', Uri.parse(presignedUrl));
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
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'voice', 'filename': filename, 'to': to, 'no_notify': isPersonalChat}),
      );
      int? serverMsgId;
      if (confirmResp.statusCode == 200) {
        try {
          final json = jsonDecode(confirmResp.body) as Map<String, dynamic>;
          serverMsgId = json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '');
        } catch (_) {}
      } else {
        debugPrint('<<_performVoiceUpload>> confirm failed: ${confirmResp.statusCode}');
        rootScreenKey.currentState?.showSnack('Upload failed: ${confirmResp.statusCode}');
        return;
      }

      debugPrint('<<_performVoiceUpload>> upload confirmed, filename=$filename');

      final voiceCacheDir = await getApplicationSupportDirectory();
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
          replyToId: replyTo != null && replyTo['id'] != null ? int.tryParse(replyTo['id'].toString()) : null,
          replyToSender: replyTo != null ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString() : null,
          replyToContent: replyTo != null ? replyTo['content']?.toString() : null,
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

  Future<void> _performVoiceUploadLAN(String to, String path, [Map<String, dynamic>? replyTo]) async {
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

      final appDocuments = await getApplicationDocumentsDirectory();
      final lanMediaDir = Directory('${appDocuments.path}/lan_media');
      if (!await lanMediaDir.exists()) {
        await lanMediaDir.create(recursive: true);
        debugPrint('[LAN VOICE] Created lan_media directory');
      }

      final localLanFile = File('${lanMediaDir.path}/$filename');
      await localLanFile.writeAsBytes(voiceBytes, flush: true);
      debugPrint('[LAN VOICE] Saved locally to: ${localLanFile.path} (exists: ${await localLanFile.exists()})');

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
        replyToSender: replyTo != null ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString() : null,
        replyToContent: replyTo != null ? (replyTo['content'])?.toString() : null,
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
      final appDocuments = await getApplicationDocumentsDirectory();
      final cacheDir = '${appDocuments.path}/voice_cache';
      await Directory(cacheDir).create(recursive: true);
      final cachedPath = '$cacheDir/$filename';
      await file.copy(cachedPath);

      // Use fav:// prefix so VoiceMessagePlayer reads from local cache
      // instead of trying to fetch from the server.
      final voiceContent = jsonEncode({'filename': 'fav://$filename', 'orig': filename});
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
      
      final appSupport = await getApplicationDocumentsDirectory();

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
        final tryName =
            actualFilename.endsWith(ext) || ext.isEmpty ? actualFilename : '$actualFilename$ext';
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
    final appSupport = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appSupport.path}/image_cache');
    await cacheDir.create(recursive: true);
    final displayDir = await MediaCache.instance.displayDirFor('image');

    final existing = await MediaCache.instance.findCachedDisplay(
        cacheDir, [filename], displayDir);
    if (existing != null) return existing;

    final token = await AccountManager.getToken(currentUsername ?? '');
    if (token == null) throw Exception('Not logged in');

    final urlPath = (owner != null && owner.isNotEmpty)
        ? '$serverBase/image/$owner/$filename'
        : '$serverBase/image/$filename';
    final res = await http.get(
      Uri.parse(urlPath),
      headers: {'authorization': 'Bearer $token'},
    );
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
    final displayFile = File('${displayDir.path}/$filename');
    await displayFile.writeAsBytes(plainBytes, flush: true);
    return displayFile;
  }

  Future<File?> downloadVoiceToCache(String filename,
      {required String peerUsername, String? mediaKeyB64}) async {
    final appSupport = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appSupport.path}/voice_cache');
    await cacheDir.create(recursive: true);
    final displayDir = await MediaCache.instance.displayDirFor('voice');

    final possibleExts = ['', '.ogg', '.opus', '.m4a', '.mp3', '.wav'];
    final candidateNames = possibleExts
        .map((ext) =>
            filename.endsWith(ext) || ext.isEmpty ? filename : '$filename$ext')
        .toList();
    final existing = await MediaCache.instance.findCachedDisplay(
        cacheDir, candidateNames, displayDir);
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

    final bytes =
        await decryptMediaFromPeer(peerUsername, cipherBytes, kind: 'voice', mediaKeyB64: mediaKeyB64);

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
    final displayFile = File('${displayDir.path}/$safeName');
    await displayFile.writeAsBytes(bytes, flush: true);
    return displayFile;
  }

  Future<File?> downloadVideoToCache(String filename,
      {required String peerUsername, String? mediaKeyB64}) async {
    final appSupport = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appSupport.path}/video_cache');
    await cacheDir.create(recursive: true);
    final displayDir = await MediaCache.instance.displayDirFor('video');

    final existing = await MediaCache.instance.findCachedDisplay(
        cacheDir, [filename], displayDir);
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

    final bytes =
        await decryptMediaFromPeer(peerUsername, cipherBytes, kind: 'video', mediaKeyB64: mediaKeyB64);

    await MediaCache.instance.writeEncrypted(cacheDir, filename, bytes);
    final displayFile = File('${displayDir.path}/$filename');
    await displayFile.writeAsBytes(bytes, flush: true);
    return displayFile;
  }

  Future<File?> downloadFileToCache(String filename,
      {required String peerUsername, String? owner, String? mediaKeyB64, void Function(double)? onProgress}) async {
    final appSupport = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appSupport.path}/file_cache');
    await cacheDir.create(recursive: true);
    final displayDir = await MediaCache.instance.displayDirFor('file');

    final existing = await MediaCache.instance.findCachedDisplay(
        cacheDir, [filename], displayDir);
    if (existing != null) return existing;

    final legacyCacheNames = [
      'file_cache', 'document_cache', 'data_cache',
      'archive_cache', 'image_cache', 'video_cache',
      'voice_cache', 'audio_cache',
    ];
    for (final name in legacyCacheNames) {
      final f = File('${appSupport.path}/$name/$filename');
      if (await f.exists()) {
        debugPrint('[downloadFileToCache] found local cached file in $name: ${f.path}');
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
        debugPrint('[downloadFileToCache] file not found on server: $filename (404)');
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

      final bytes =
          await decryptMediaFromPeer(peerUsername, cipherBytes, kind: 'file', mediaKeyB64: mediaKeyB64);

      await MediaCache.instance.writeEncrypted(cacheDir, filename, bytes);
      final displayFile = File('${displayDir.path}/$filename');
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
    for (final m in msgs) {
      try {
        final text = m.content;
        if (text.startsWith('IMAGEv1:')) {
          final data = jsonDecode(text.substring('IMAGEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(
                downloadImageToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
              _appendLog('[fav.prefetch] image cached: $filename');
            }).catchError((e) {
              _appendLog('[fav.prefetch] image $filename failed: $e');
            }));
          }
        } else if (text.toUpperCase().startsWith('VIDEOV1:')) {
          final prefixLen = 'VIDEOv1:'.length;
          final meta =
              jsonDecode(text.substring(prefixLen)) as Map<String, dynamic>;
          final filename = (meta['filename'] as String?)?.trim();
          final keyB64 = meta['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(
                downloadVideoToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
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
            tasks.add(
                downloadVoiceToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
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
          try {
            final data = jsonDecode(text.substring('FILEv1:'.length))
                as Map<String, dynamic>;
            final filename = (data['filename'] as String?)?.trim();
            final keyB64 = data['key'] as String?;
            if (filename != null && filename.isNotEmpty) {
              tasks.add(
                  downloadFileToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
                _appendLog('[fav.prefetch] file cached: $filename');
              }).catchError((e) {
                _appendLog('[fav.prefetch] file $filename failed: $e');
              }));
            }
          } catch (e) {}
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
                    final appSupport = await getApplicationSupportDirectory();
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
                    final appSupport = await getApplicationSupportDirectory();
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

      if (tasks.length >= 6) {
        await Future.wait(tasks);
        tasks.clear();
      }
    }

    if (tasks.isNotEmpty) await Future.wait(tasks);
    _appendLog('[fav.prefetch] completed for $favId');
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
    for (final m in msgs) {
      try {
        final text = m.content;
        if (text.startsWith('IMAGEv1:')) {
          final data = jsonDecode(text.substring('IMAGEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(
                downloadImageToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
              _appendLog('[chat.prefetch] image cached: $filename');
            }).catchError((e) {
              _appendLog('[chat.prefetch] image $filename failed: $e');
            }));
          }
        } else if (text.toUpperCase().startsWith('VIDEOV1:')) {
          final prefixLen = 'VIDEOv1:'.length;
          final meta =
              jsonDecode(text.substring(prefixLen)) as Map<String, dynamic>;
          final filename = (meta['filename'] as String?)?.trim();
          final keyB64 = meta['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(
                downloadVideoToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
              _appendLog('[chat.prefetch] video cached: $filename');
            }).catchError((e) {
              _appendLog('[chat.prefetch] video $filename failed: $e');
            }));
          }
        } else if (text.startsWith('VOICEv1:')) {
          final data = jsonDecode(text.substring('VOICEv1:'.length))
              as Map<String, dynamic>;
          final filename = (data['filename'] as String?)?.trim();
          final keyB64 = data['key'] as String?;
          if (filename != null && filename.isNotEmpty) {
            tasks.add(
                downloadVoiceToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
              _appendLog('[chat.prefetch] voice cached: $filename');
            }).catchError((e) {
              _appendLog('[chat.prefetch] voice $filename failed: $e');
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
              _appendLog('[chat.prefetch] audio cached: $filename');
            }).catchError((e) {
              _appendLog('[chat.prefetch] audio $filename failed: $e');
            }));
          }
        } else if (text.startsWith('FILEv1:')) {
          try {
            final data = jsonDecode(text.substring('FILEv1:'.length))
                as Map<String, dynamic>;
            final filename = (data['filename'] as String?)?.trim();
            final keyB64 = data['key'] as String?;
            if (filename != null && filename.isNotEmpty) {
              tasks.add(
                  downloadFileToCache(filename, peerUsername: m.from, mediaKeyB64: keyB64).then((_) {
                _appendLog('[chat.prefetch] file cached: $filename');
              }).catchError((e) {
                _appendLog('[chat.prefetch] file $filename failed: $e');
              }));
            }
          } catch (e) {}
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
                    final appSupport = await getApplicationSupportDirectory();
                    final cacheDir =
                        Directory('${appSupport.path}/voice_cache');
                    await cacheDir.create(recursive: true);
                    final name =
                        _sanitizeFilename(Uri.parse(url).pathSegments.last);
                    final f = File('${cacheDir.path}/$name');
                    await f.writeAsBytes(res.bodyBytes, flush: true);
                    _appendLog('[chat.prefetch] external voice cached: $url');
                  }
                }).catchError((e) {
                  _appendLog('[chat.prefetch] external voice $url failed: $e');
                }));
              } else {
                tasks.add(http.get(Uri.parse(url)).then((res) async {
                  if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                    final appSupport = await getApplicationSupportDirectory();
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

      if (tasks.length >= 6) {
        await Future.wait(tasks);
        tasks.clear();
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
        Future.microtask(() => ensureMediaCachedForChat(id));
      }
    } catch (e) {
      debugPrint('[chat.prefetch] error: $e');
    }
  }

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
        unawaited(_preloadUserProfiles());
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _prefetchTopChatsMedia(3);
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
    });
    _saveFavorites();
    
    Future.microtask(() => ensureMediaCachedForFavorite(fav.id));
  }

  void _deleteFavorite(String id) {
    setState(() {
      _favorites.removeWhere((f) => f.id == id);
      if (_selectedFavoriteId == id) _selectedFavoriteId = null;
    });
    _saveFavorites();

    final chatId = 'fav:$id';
    chats.remove(chatId);
    persistChats();
    chatsVersion.value++;
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
      _pageController.jumpToPage(i);
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
        WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
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
          Navigator.of(context).push(
            _chatRoute((_) => ChatScreen(
                myUsername: currentUsername ?? 'me',
                otherUsername: username,
                onSend: (t, replyTo) => _sendChatMessage(username, t, replyTo),
                onTyping: () => _handleSendTyping(username),
                onRequestResend: (id) {
                  if (id != null) _requestResend(id);
                },
                onEditMessage: (id, text) => _editChatMessage(username, id, text),
                onDeleteMessage: (id) => _deleteChatMessage(id),
              )),
          ).then((_) {
            if (mounted) setState(() { selectedChatOther = null; });
          });
        }
      });
    }

    _initBackground();

    _configureAudioSession();

    _initializeAccountAndConnect();

    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);

    _pageController = PageController(initialPage: _index);
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
        if (mounted) setState(() { selectedChatOther = null; });
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
        _appendLog('[lifecycle] Foreground service started (background keep-alive)');
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
    
    unawaited(AccountManager.loadStatusSettings());
    _loadCurrentAccount();
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
        LANMessageManager().onMediaReceived = (mediaType, filename, data, from, to, replyTo) {
          _handleIncomingLANMedia(mediaType, filename, data, from, to, replyTo);
        };
        LANMessageManager().onKeyMismatch = (username, fingerprint) {
          // Key rotation is expected (ephemeral keys change on every launch).
          // No user-visible notification needed.
          if (kDebugMode) {
            debugPrint('[LAN] Key rotated for $username: $fingerprint');
          }
        };
      }

      final wsReadyFuture = _ensurePubkeyAndWsReady(
        maxRetries: 10,
        retryDelay: const Duration(milliseconds: 100),
      );

      unawaited(_loadFavorites());

      if (currentUsername != null) {
        final uname = currentUsername!;
        unawaited(LANMessageManager().initialize(uname).catchError((e) {
          _appendLog('[LAN] Failed to initialize: $e');
        }));
      }

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
      
      _appendLog('[startup] no saved account, checking for available accounts...');
      
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

    final uinPrefs = await SharedPreferences.getInstance();
    final cachedUin = uinPrefs.getString('uin_$username');
    if (cachedUin != null) currentUin = cachedUin;

    final cachedIsPrimary = await SecureStore.read('is_primary_device_$username');
    if (mounted) setState(() => _isPrimaryDevice = cachedIsPrimary == 'true');

    Future(() async {
      try {
        final tok = await AccountManager.getToken(username);
        if (tok == null || !mounted) return;
        final isPrimaryRes = await http
            .get(
              Uri.parse('$serverBase/me/is-primary'),
              headers: {'authorization': 'Bearer $tok'},
            )
            .timeout(const Duration(seconds: 5));
        if (isPrimaryRes.statusCode == 200 && mounted) {
          final data = jsonDecode(isPrimaryRes.body);
          final serverIsPrimary = data['is_primary'] == true;
          await SecureStore.write(
            'is_primary_device_$username',
            serverIsPrimary ? 'true' : 'false',
          );
          if (mounted) setState(() => _isPrimaryDevice = serverIsPrimary);
        }
      } catch (_) {
        
      }
    });

    _normalizeChatsForCurrentUser();

    currentDisplayName = username;
    Future(() async {
      try {
        final token = await AccountManager.getToken(username);
        if (token == null || !mounted) return;
        final res = await http
            .get(
              Uri.parse('$serverBase/profile/$username'),
              headers: {'authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 5));
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

    unawaited(_preloadUserProfiles());
    chatsVersion.value++; 
    setState(
        () {}); 
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
      
      await _disconnectWs(manual: true, suppressPresence: true);

      ExternalServerManager.disconnectAll();
      _appendLog('[ext-servers] Disconnected all external servers for account switch');

      await Future.delayed(const Duration(milliseconds: 100));

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
        _appendLog('[session] _chatScreenCache cleared on account switch to $username');
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

      await AccountManager.loadStatusSettings();

      _chatsLoadCompleter = Completer<void>();
      await _loadAccountData(username);
      await _loadChatsFromCacheNow(username);
      _appendLog('[account] switched to $username');

      accountSwitchVersion.value++;

      await _loadFavorites();

      try {
        await ExternalServerManager.loadServers();
        await ExternalServerManager.refreshAllExternalGroups();
        _appendLog('[ext-servers] Loaded ${ExternalServerManager.servers.value.length} external servers for $username');
      } catch (e) {
        _appendLog('[ext-servers] Failed to load for new account: $e');
      }

      final ready = await _ensurePubkeyAndWsReady(
        maxRetries: 10,
        retryDelay: const Duration(milliseconds: 100),
      );
      if (!ready) {
        showSnack('Failed to connect after account switch');
      }

      _appendLog('[account] switch complete, ws ready=$ready');
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
        
        _appendLog('[account] switching to ${remaining.first} after deleting current');
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
      _appendLog('[persist] full save ${chats.length} chats for $currentUsername');
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
      _appendLog('[persist] incremental save ${dirty.length} chats for $currentUsername');
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
      final senderDisplayName = UserCache.getSync(sender)?.displayName ?? sender;
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
            final avatarBytes = hideContent ? null : await getAvatarCachedBytes(sender);
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
    _log.insert(0, t);
    if (_log.length > 500) _log.removeRange(500, _log.length);
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
    } catch (e) {
      
    }
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
    _lastPubkeyUploadTime  = null;
    _pubkeyCache.clear();             
    _devicePubkeysCache.clear();      
    await _uploadPubkeyToServer();    

    if (_ws != null) {
      try {
        _ws!.sink.add(jsonEncode({'type': 'pubkey_updated', 'username': currentUsername}));
        _appendLog('[key-rotation] pubkey_updated broadcast sent via WS');
      } catch (e) {
        _appendLog('[key-rotation] pubkey_updated WS send failed: $e');
      }
    }

    _appendLog('[key-rotation] E2EE identity key rotated and uploaded ');
  }

  Future<void> fullSessionReset() async {
    final username = currentUsername;
    final token = username != null ? await AccountManager.getToken(username) : null;

    await rotateIdentityKey();

    if (token != null) {
      try {
        final res = await http.delete(
          Uri.parse('$serverBase/me/sessions'),
          headers: {'authorization': 'Bearer $token'},
        );
        final revoked = res.statusCode == 200
            ? (jsonDecode(res.body)['revoked'] ?? 0)
            : 0;
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
        return ('${info.brand} ${info.model}', 'Android ${info.version.release}');
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
          _appendLog('[ext-servers] Loaded ${ExternalServerManager.servers.value.length} external servers for $username');
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
      showSnack(AppLocalizations(SettingsManager.appLocale.value).passphraseNotFound);
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
              child: Text(AppLocalizations.of(ctx).yourPassphraseTitle, style: const TextStyle(fontSize: 16)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Future<void> _logout() async {
    _disconnectWs();
    ExternalServerManager.disconnectAll();
    
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
    unawaited(_preloadUserProfiles());
    
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

      try {
        _ws = WebSocketChannel.connect(Uri.parse(wsUri));
        
        _ws!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
        _appendLog('[ws.connect] Auth frame sent');
      } catch (e) {
        _appendLog('[ws] connect error: $e');
        wsConnectedNotifier.value = false;
        return;
      }

      _wsSub = _ws!.stream.listen(
        (event) async {
          try {
            if (event is String) {
              final obj = jsonDecode(event) as Map<String, dynamic>;
              final typ = obj['type'] as String?;
              
              if (typ == 'init_complete') {
                wsConnectedNotifier.value = true;
                _appendLog('[ws] server init complete — WS tunnel established (proxy=${SettingsManager.proxyEnabled.value ? "${SettingsManager.proxyType.value.toUpperCase()} ${SettingsManager.proxyHost.value}:${SettingsManager.proxyPort.value}" : "none"})');
                _appendLog('[ws] sending presence...');
                _sendPresence('online');
                _drainPendingMsgQueue();

                try {
                  
                  unawaited(_requestStatusSnapshotForKnownUsers());
                  unawaited(_syncBlocklistFromServer());

                  final known = Set<String>.from(chats.keys);
                  if (selectedChatOther != null) known.add(selectedChatOther!);
                  if (known.isNotEmpty && _ws != null) {
                    _ws!.sink.add(jsonEncode({'type': 'request_status_snapshot', 'users': known.toList()}));
                  }

                  Future.delayed(const Duration(seconds: 2), () {
                    try {
                      final known2 = Set<String>.from(chats.keys);
                      if (selectedChatOther != null) known2.add(selectedChatOther!);
                      if (known2.isNotEmpty && _ws != null) {
                        _ws!.sink.add(jsonEncode({'type': 'request_status_snapshot', 'users': known2.toList()}));
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
                  _appendLog('[proxy] Deferred proxy applied — reconnecting via ${SettingsManager.proxyType.value.toUpperCase()} ${SettingsManager.proxyHost.value}:${SettingsManager.proxyPort.value}');
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _disconnectWs();
                    Future.delayed(const Duration(milliseconds: 300), _connectWs);
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

                  final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);
                  if (vis[userFrom] != 'hide') {
                    vis[userFrom] = 'show';
                    userStatusVisibilityNotifier.value = vis;
                  }

                  final statuses = Map<String, String>.from(userStatusNotifier.value);
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

                    final statuses = Map<String, String>.from(userStatusNotifier.value);
                    statuses.remove(username);
                    userStatusNotifier.value = statuses;

                    final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);
                    vis[username] = 'hide';
                    userStatusVisibilityNotifier.value = vis;

                    return;
                  }

                  final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);
                  vis[username] = 'show';
                  userStatusVisibilityNotifier.value = vis;

                  if (isOnline)
                    s.add(username);
                  else
                    s.remove(username);
                  onlineUsersNotifier.value = s;

                  final statuses = Map<String, String>.from(userStatusNotifier.value);
                  if (displayState != null && displayState.isNotEmpty)
                    statuses[username] = displayState;
                  else
                    statuses.remove(username);
                  userStatusNotifier.value = statuses;

                  try {
                    final msgId = obj['message_id'] as String?;
                    if (msgId != null && _ws != null) {
                      _ws!.sink.add(jsonEncode({'type': 'status_ack', 'message_id': msgId}));
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
                      final statusVisibility = (u['status_visibility'] as String?) ?? 'show';
                      final displayState = (u['state'] as String?);
                      final isOnline = u['is_online'] == true;

                      final s = Set<String>.from(onlineUsersNotifier.value);
                      final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);

                      if (statusVisibility == 'hide') {
                        s.remove(username);
                        onlineUsersNotifier.value = s;

                        final statuses = Map<String, String>.from(userStatusNotifier.value);
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

                      final statuses = Map<String, String>.from(userStatusNotifier.value);
                      if (displayState != null && displayState.isNotEmpty)
                        statuses[username] = displayState;
                      else
                        statuses.remove(username);
                      userStatusNotifier.value = statuses;
                    } catch (e) {
                      
                    }
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
                  _appendLog('[ws] pubkey_updated: cleared cache for $u');
                  _showKeyChangedWarning(u);
                }
                return;
              }

              if (typ == 'device_approval_needed') {
                final deviceName = (obj['device_name'] as String?) ?? 'Unknown device';
                final deviceOs = obj['device_os'] as String?;
                final label = deviceOs != null ? '$deviceName ($deviceOs)' : deviceName;
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                      elevation: 4,
                      duration: const Duration(seconds: 8),
                      action: SnackBarAction(
                        label: 'Review',
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
                final deviceName = (obj['device_name'] as String?) ?? 'Unknown device';
                _appendLog('[ws] device_approved: $deviceName');
                
                _devicePubkeysCache.clear();
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
                  isRead: selectedChatOther ==
                      from, 
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
                if (msg.serverMessageId != null) _serverMsgIndex[msg.serverMessageId!] = chatId;

                if (!msg.isRead) {
                  unreadManager.incrementUnread(chatId);
                }

                _scheduleUiUpdate(chatId: chatId);

                schedulePersistChats(chatId: chatId);

                if (!msg.outgoing && !MuteManager.isMuted(from)) {
                  _scheduleNotificationSound();
                }

                if (SettingsManager.notificationsEnabled.value && mounted && !MuteManager.isMuted(from)) {
                  final rawPrev = msg.rawEnvelopePreview ??
                      (msg.content.length > 120
                          ? '${msg.content.substring(0, 120)}...'
                          : msg.content);
                  final messagePreview = getPreviewText(rawPrev);
                  const mediaLabels = {
                    'Voice message', 'Image', 'Video file', 'Music', 'Video',
                    'Document', 'Spreadsheet', 'Presentation', 'Archive',
                    'Artifact', 'File',
                  };
                  final isMedia = mediaLabels.contains(messagePreview) ||
                      messagePreview.startsWith('[Message not decrypted]') ||
                      messagePreview == 'Album' ||
                      messagePreview.startsWith('Album ·');
                  final displayName = UserCache.getSync(from)?.displayName ?? from;
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
                  final targetServerId = (serverId is int) ? serverId : int.tryParse(serverId.toString());
                  if (targetServerId != null) {
                    for (final entry in chats.entries) {
                      bool matched = false;
                      for (final m in entry.value) {
                        if (m.id == localId && m.outgoing && m.serverMessageId == null) {
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
                  AppLocalizations(SettingsManager.appLocale.value).blockedByUserMessage,
                );
                return;
              }

              if (typ == 'msg_delivered') {
                final serverId = obj['id'];
                final delivered = obj['delivered'] == true;
                _appendLog('[ws.msg_delivered] id=$serverId delivered=$delivered');
                if (delivered && serverId != null) {
                  final targetId = (serverId is int) ? serverId : int.tryParse(serverId.toString());
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
                  final mid = (midRaw is int) ? midRaw : int.tryParse(midRaw?.toString() ?? '');
                  final encContent = obj['new_content'] as String?;
                  final from = obj['from'] as String?;
                  if (mid != null && encContent != null && from != null) {
                    final plain = await _tryDecryptIncoming(encContent, from) ?? encContent;
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
                  final mid = (midRaw is int) ? midRaw : int.tryParse(midRaw?.toString() ?? '');
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
                  final mid = (midRaw is int) ? midRaw : int.tryParse(midRaw?.toString() ?? '');
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
                          _appendLog('[ws.msg_delete] removed server id=$mid from local store');
                        }
                      }
                    } else {
                      _appendLog('[ws.msg_delete] server id=$mid not found locally');
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
                if (msgType == 'group' && groupId != null &&
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
          _appendLog('[ws] closed (onDone)');
          _handleWsClosed(manual: false, reason: 'onDone');
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
    } else {
      
    }
  }

  void connectWs() {
    _connectWs();
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
      throw Exception('Cannot send $kind: identity key not loaded. Please reconnect.');
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
          throw Exception('Cannot encrypt $kind: no public key for $peerUsername');
        }
        final obj = jsonDecode(r.body);
        final pkB64 = obj['pubkey'] as String?;
        if (pkB64 == null) {
          throw Exception('Cannot encrypt $kind: null public key for $peerUsername');
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
      _appendLog('[media.encrypt.$kind] random-key ok ${plaintext.length} → ${cipher.length}');
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
      final offset = prefixBytes.length;
      final nonce = data.sublist(offset, offset + 24);
      final ctAndTag = data.sublist(offset + 24);

      if (ctAndTag.length < 16) {
        _appendLog('[media.decrypt.$kind] ctAndTag too short');
        return data;
      }

      final cipherText = ctAndTag.sublist(0, ctAndTag.length - 16);
      final tag = ctAndTag.sublist(ctAndTag.length - 16);

      final Uint8List aeadKeyBytes;
      if (mediaKeyB64 != null) {
        aeadKeyBytes = base64Decode(mediaKeyB64);
      } else {
        
        List<int> peerPubBytes;
        if (_pubkeyCache.containsKey(peerUsername)) {
          peerPubBytes = _pubkeyCache[peerUsername]!;
        } else {
          final tok = await AccountManager.getToken(currentUsername ?? '');
          final r = await http.get(Uri.parse('$serverBase/pubkey/$peerUsername'),
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

      final secretKey = SecretKey(aeadKeyBytes);

      final box = SecretBox(
        Uint8List.fromList(cipherText),
        nonce: Uint8List.fromList(nonce),
        mac: Mac(Uint8List.fromList(tag)),
      );

      final plain = await _xchacha.decrypt(
        box,
        secretKey: secretKey,
        aad: <int>[],
      );

      _appendLog('[media.decrypt.$kind] ok ${data.length} → ${plain.length}');
      return Uint8List.fromList(plain);
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
        throw Exception('Recipient has no public key — cannot send encrypted message.');
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
        final r = await http
            .get(Uri.parse('$serverBase/pubkey/$peer'),
                headers: {'authorization': 'Bearer $tok'})
            .timeout(const Duration(seconds: 5));
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
        final r = await http
            .get(Uri.parse('$serverBase/pubkey/$peer'),
                headers: {'authorization': 'Bearer $tok'})
            .timeout(const Duration(seconds: 5));
        if (r.statusCode != 200) return;
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final freshPubkey = body['pubkey'] as String?;
        if (freshPubkey == null || freshPubkey.isEmpty) return;

        final stored = await AccountManager.getKnownPubkey(currentUsername!, peer);
        
        unawaited(AccountManager.saveKnownPubkey(currentUsername!, peer, freshPubkey));

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

  Future<List<Map<String, dynamic>>> _fetchAllDevicePubkeys(String recipient) async {
    if (_devicePubkeysCache.containsKey(recipient)) {
      return _devicePubkeysCache[recipient]!;
    }
    try {
      final tok = await AccountManager.getToken(currentUsername ?? '');
      final r = await http
          .get(Uri.parse('$serverBase/pubkeys/$recipient'),
              headers: {'authorization': 'Bearer $tok'})
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final obj = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = obj['devices'] as List<dynamic>? ?? [];
        final devices = raw
            .whereType<Map<String, dynamic>>()
            .where((d) => d['pubkey'] != null && d['fp'] != null)
            .toList();
        _devicePubkeysCache[recipient] = devices;
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
    final fullCt = Uint8List.fromList(secretBox.cipherText + secretBox.mac.bytes);
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
      final encrypted = await _encryptWithPubkeyBytes(recipient, plaintext, pubkeyBytes);
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

  Future<void> _sendChatMessage(String to, String text, Map<String, dynamic>? replyTo) async {
    if (currentUsername == null) return;
    if (_isSwitchingAccount) {
      _appendLog('[msg] blocked: account switch in progress');
      return;
    }

    try {
      unawaited(_updateRecipientStatus(to));
    } catch (e) {
      _appendLog('[send] failed to update recipient status: $e');
    }

    final localId = DateTime.now().microsecondsSinceEpoch.toString();
    final chatId = chatIdForUser(to);

    final isLANMode = replyTo != null && replyTo['_deliveryMode'] == 'lan';

    final int? replyId = replyTo != null && replyTo['id'] != null ? int.tryParse(replyTo['id'].toString()) : null;
    final msgLocal = ChatMessage(
      id: localId,
      from: currentUsername!,
      to: to,
      content: text, 
      outgoing: true,
      delivered: isLANMode ? true : false, 
      time: DateTime.now(), 
      replyToId: replyId,
      replyToSender: replyTo != null ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString() : null,
      replyToContent: replyTo != null ? (replyTo['content'])?.toString() : null,
      deliveryMode: isLANMode ? DeliveryMode.lan : DeliveryMode.internet,
    );

    chats.putIfAbsent(chatId, () => []).add(msgLocal);
    if (msgLocal.serverMessageId != null) _serverMsgIndex[msgLocal.serverMessageId!] = chatId;
    debugPrint('[RootScreen] Added message to chatId=$chatId, total messages: ${chats[chatId]!.length}');

    messageListNotifier.addMessageOptimized(chatId, msgLocal);

    final oldVersion = chatsVersion.value;
    _bumpForChat(chatId);
    debugPrint('[RootScreen] Updated chatsVersion: $oldVersion -> ${chatsVersion.value}');

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
    if (incomingMessage.serverMessageId != null) _serverMsgIndex[incomingMessage.serverMessageId!] = chatId;

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
      
      final dir = await getApplicationDocumentsDirectory();
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
        replyToSender: replyTo != null ? (replyTo['senderDisplayName'] ?? replyTo['sender'])?.toString() : null,
        replyToContent: replyTo != null ? (replyTo['content'])?.toString() : null,
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

        _appendLog('[recipient-status] updated $username: visibility=$statusVisibility online=$isOnline state=$displayState');

        if (statusVisibility == 'hide') {
          
          final s = Set<String>.from(onlineUsersNotifier.value)..remove(username);
          onlineUsersNotifier.value = s;
          
          final statuses = Map<String, String>.from(userStatusNotifier.value);
          statuses.remove(username);
          userStatusNotifier.value = statuses;
          
          final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);
          vis[username] = 'hide';
          userStatusVisibilityNotifier.value = vis;
        } else {
          
          final vis = Map<String, String>.from(userStatusVisibilityNotifier.value);
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

  void _sendChatMessageInBackground(String to, String text, String localId, Map<String, dynamic>? replyTo) {
    unawaited(Future.microtask(() async {
      
      Map<String, String>? payloads;   
      String? fallbackEnvelope;        

      const retryDelays = [1, 2, 4, 8, 15];
      for (int attempt = 0; attempt <= retryDelays.length; attempt++) {
        if (attempt > 0) {
          
          _devicePubkeysCache.remove(to);
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
        text.startsWith('FILEv1:')  ||
        text.startsWith('AUDIOv1:') ||
        text.startsWith('ALBUMv1:');

    final packet = <String, dynamic>{
      'type': 'msg',
      'to': to,
      'local_id': localId,
      if (isMedia) 'is_media': true,
      if (replyTo != null && replyTo['id'] != null)
        'reply_to_id': replyTo['id'].toString(),
      if (replyTo != null && (replyTo['senderDisplayName'] ?? replyTo['sender']) != null)
        'reply_to_sender': (replyTo['senderDisplayName'] ?? replyTo['sender']).toString(),
      if (replyTo != null && replyTo['content'] != null)
        'reply_to_content': replyTo['content'].toString(),
    };

    if (payloads != null && payloads.isNotEmpty) {
      
      packet['payloads'] = payloads;
      _appendLog('[send] MD msg sent localId=$localId devices=${payloads.length}');
    } else if (fallbackEnvelope != null) {
      
      packet['content'] = fallbackEnvelope;
      _appendLog('[send] legacy msg sent localId=$localId len=${fallbackEnvelope.length}');
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

  void _handleSendTyping(String to) {

  }

  Future<void> _editChatMessage(String to, int messageId, String newText) async {
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
          msgs.removeWhere((m) => m.serverMessageId == messageId);
          if (msgs.length != before) {
            _serverMsgIndex.remove(messageId);
            removed = true;
          }
        }
      } else {
        // Fallback: index miss, scan all chats
        for (final entry in chats.entries) {
          final before = entry.value.length;
          entry.value.removeWhere((m) => m.serverMessageId == messageId);
          if (entry.value.length != before) {
            _serverMsgIndex.remove(messageId);
            removed = true;
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
    _appendLog(
        '[auto] ws ready=$ok (pubkey_cached=$_pubkeyUploadedToServer)');
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
    
    _appendLog('[pubkey] WARNING: upload failed after 3 attempts — will retry on next connect');
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

  void _deleteChat(String chatId) {
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black54, 
      
      transitionDuration: const Duration(milliseconds: 200),
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
                child: Container(
                  width: isDesktop ? 640 : double.infinity,
                  constraints: const BoxConstraints(maxHeight: 520),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 36,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Builder(builder: (context) {
                      final Widget inner = Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: isDesktop ? 0.90 : 1.0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.10),
                            width: 1,
                          ),
                        ),
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
                                Navigator.of(context).push(
                                  _chatRoute((_) => ChatScreen(
                                      myUsername: currentUsername ?? 'me',
                                      otherUsername: username,
                                      onSend: (t, replyTo) => _sendChatMessage(username, t, replyTo),
                                      onTyping: () => _handleSendTyping(username),
                                      onRequestResend: (id) {
                                        if (id != null) _requestResend(id);
                                      },
                                      onEditMessage: (id, text) => _editChatMessage(username, id, text),
                                      onDeleteMessage: (id) => _deleteChatMessage(id),
                                    )),
                                ).then((_) {
                                  if (mounted) setState(() { selectedChatOther = null; });
                                });
                              }
                            }
                          },
                        ),
                      );
                      if (isDesktop) {
                        return BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: inner,
                        );
                      }
                      return inner;
                    }),
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
    );
  }

  Widget _buildMobileAppBar(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.applyGlobally,
      builder: (_, apply, __) {
        return ValueListenableBuilder<String?>(
          valueListenable: SettingsManager.chatBackground,
          builder: (_, path, __) {
            final makeTransparent =
                apply && path != null && File(path).existsSync();
            return AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: wsConnectedNotifier,
                    builder: (_, connected, __) {
                      final baseStyle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
                      final targetScale = (baseStyle.fontSize ?? 20) * 1.2 / 24.0;
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.0, end: connected ? targetScale : 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                        child: GestureDetector(
                          onTap: () => showAboutOnyxDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Image.asset('assets/onyx-512.png', width: 25, height: 25, fit: BoxFit.contain),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => showAboutOnyxDialog(context),
                    child: ConnectionTitle(
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const ProxyShieldBadge(),
                ],
              ),
              centerTitle: true,
              leading: currentUsername != null
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
              leadingWidth: 100,
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
                                  opacity: (1.0 + (offset / 80.0)).clamp(0.0, 1.0),
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
                                    color: Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 0,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 300,
                                  ),
                                  label: Text(AppLocalizations.of(context).navChats),
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
                                    color: Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 1,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 400,
                                  ),
                                  label: Text(AppLocalizations.of(context).navGroups),
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
                                    color: Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 2,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 500,
                                  ),
                                  label: Text(AppLocalizations.of(context).navFavorites),
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
                                    color: Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 3,
                                    animationType: NavIconAnimationType.bounce,
                                    entryDelay: 600,
                                  ),
                                  label: Text(AppLocalizations.of(context).navAccounts),
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
                                    color: Theme.of(context).colorScheme.primary,
                                    isSelected: _index == 4,
                                    animationType: NavIconAnimationType.spin,
                                    entryDelay: 700,
                                  ),
                                  label: Text(AppLocalizations.of(context).navSettings),
                                ),
                              ],
                            ),
                          ),
                        ValueListenableBuilder<double>(
                          valueListenable: _chatsPanelWidthNotifier,
                          builder: (_, width, child) => SizedBox(width: width, child: child),
                          child: Column(
                        children: [
                          AppBar(
                            automaticallyImplyLeading: false,
                            centerTitle: isNavBottom,
                            leadingWidth: isNavBottom ? 80 : null,
                            leading: isNavBottom && currentUsername != null
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentDisplayName ?? currentUsername!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '@$currentUsername',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  )
                                : isNavBottom ? const SizedBox(width: 48) : null,
                            title: isNavBottom 
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ValueListenableBuilder<bool>(
                                      valueListenable: wsConnectedNotifier,
                                      builder: (_, connected, __) {
                                        final baseStyle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
                                        final targetScale = (baseStyle.fontSize ?? 20) * 1.2 / 24.0;
                                        return TweenAnimationBuilder<double>(
                                          tween: Tween<double>(begin: 1.0, end: connected ? targetScale : 1.0),
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                                          child: GestureDetector(
                                            onTap: () => showAboutOnyxDialog(context),
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Image.asset('assets/onyx-512.png', width: 25, height: 25, fit: BoxFit.contain),
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
                                        valueListenable: wsConnectedNotifier,
                                        builder: (_, connected, __) {
                                          final baseStyle = const TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
                                          final targetScale = (baseStyle.fontSize ?? 20) * 1.2 / 24.0;
                                          return TweenAnimationBuilder<double>(
                                            tween: Tween<double>(begin: 1.0, end: connected ? targetScale : 1.0),
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                                            child: GestureDetector(
                                              onTap: () => showAboutOnyxDialog(context),
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Image.asset('assets/onyx-512.png', width: 25, height: 25, fit: BoxFit.contain),
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
                              valueListenable: SettingsManager.desktopNavPosition,
                              builder: (context, navPos, _) {
                                final tabChild = <Widget>[
                                  
                                  ChatsTab(
                                    chats: chats,
                                    username: currentUsername,
                                    onOpenChat: (other) async {
                                      if (_chatsLoadCompleter != null && !_chatsLoadCompleter!.isCompleted) {
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

                                      if (!isDesktop) FocusScope.of(context).requestFocus(FocusNode());
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
                                    identityPubFp: _identityPublicKey != null
                                        ? _computePubkeyFpHex(_identityPublicKey!.bytes)
                                        : null,
                                    onLogin: _login,
                                    onRegister: _register,
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
                                ][_index];

                                if (navPos != 'bottom') return tabChild;
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    padding: MediaQuery.of(context).padding +
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
                          _chatsPanelWidthNotifier.value =
                              (_chatsPanelWidthNotifier.value + details.delta.dx)
                                  .clamp(200.0, MediaQuery.of(context).size.width * 0.6);
                        },
                        child: Container(
                          width: 6,
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.3),
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
                                      .firstWhere(
                                          (f) => f.id == _selectedFavoriteId!)
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
                                        onSend: (t, replyTo) => _sendChatMessage(selectedChatOther!, t, replyTo),
                                        onTyping: () => _handleSendTyping(
                                            selectedChatOther!),
                                        onRequestResend: (id) {
                                          if (id != null) _requestResend(id);
                                        },
                                        onEditMessage: (id, text) => _editChatMessage(selectedChatOther!, id, text),
                                        onDeleteMessage: (id) => _deleteChatMessage(id),
                                      ),
                                    )
                                  : (selectedChatOther != null)
                                      ? Center(
                                          child: CircularProgressIndicator())
                                      : (selectedGroup != null)
                                          ? _groupChatScreenCache.putIfAbsent(
                                              selectedGroup!.id,
                                              () => GroupChatScreen(
                                                key: ValueKey<int>(
                                                    selectedGroup!.id),
                                                group: selectedGroup!,
                                              ),
                                            )
                                          : (selectedExternalGroup != null && selectedExternalServer != null)
                                              ? _externalGroupChatScreenCache.putIfAbsent(
                                                  'ext_${selectedExternalServer!.id}_${selectedExternalGroup!.id}',
                                                  () => ExternalGroupChatScreen(
                                                    key: ValueKey<String>(
                                                        'ext_${selectedExternalServer!.id}_${selectedExternalGroup!.id}'),
                                                    group: selectedExternalGroup!,
                                                    server: selectedExternalServer!,
                                                  ),
                                                )
                                          : Center(
                                              child: glassCard(
                                                context: context,
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24,
                                                      vertical: 32),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Image.asset(
                                                        'assets/onyx_icon.png',
                                                        width: 56,
                                                        height: 56,
                                                        opacity: const AlwaysStoppedAnimation(0.85),
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      ValueListenableBuilder<Locale>(
                                                        valueListenable: SettingsManager.appLocale,
                                                        builder: (_, locale, __) => Text(
                                                          AppLocalizations(locale).localizeMotivationalHint(_motivationalHints[_motivationalHintIndex]),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                Theme.of(context)
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

                          if (isDesktop && apply) {
                            return Stack(
                              children: [
                                ValueListenableBuilder<String?>(
                                  valueListenable:
                                      SettingsManager.chatBackground,
                                  builder: (_, path, __) {
                                    if (path == null)
                                      return const SizedBox.shrink();
                                    final f = File(path);
                                    if (!f.existsSync())
                                      return const SizedBox.shrink();
                                    return ValueListenableBuilder<bool>(
                                      valueListenable:
                                          SettingsManager.blurBackground,
                                      builder: (_, blur, __) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable:
                                              SettingsManager.blurSigma,
                                          builder: (_, sigma, __) {
                                            final provider = FileImage(f);
                                            final child = blur
                                                ? AdaptiveBlur(
                                                    imageProvider: provider,
                                                    sigma: sigma,
                                                    fit: BoxFit.cover)
                                                : Image(
                                                    image: provider,
                                                    fit: BoxFit.cover);
                                            return Positioned.fill(
                                              child: IgnorePointer(
                                                child: Opacity(
                                                    opacity: 0.95,
                                                    child: child),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
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
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
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
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
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
                padding: EdgeInsets.fromLTRB(16, isDesktop ? 16 + 42 : 16, 16, 16),
                child: AccountsTab(
                  currentUsername: null,
                  currentUin: null,
                  identityPubFp: null,
                  onLogin: _login,
                  onRegister: _register,
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
          if (_chatsLoadCompleter != null && !_chatsLoadCompleter!.isCompleted) {
            await _chatsLoadCompleter!.future;
          }
          if (!mounted) return;

          final chatId = chatIdForUser(other);
          chats.putIfAbsent(chatId, () => []);
          if (!isDesktop) {
            if (mounted) setState(() { selectedChatOther = other; });
            await Navigator.of(context).push(
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
            );
            if (mounted) setState(() { selectedChatOther = null; });
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
                _chatRoute((_) => ExternalGroupChatScreen(group: group, server: server)),
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
            child: Column(
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
          );

    return Scaffold(
      body: Stack(
        children: [
          
          ValueListenableBuilder<bool>(
            valueListenable: SettingsManager.applyGlobally,
            builder: (ctx, apply, _) {
              if (!apply || isDesktop) return const SizedBox.shrink();
              return ValueListenableBuilder<String?>(
                valueListenable: SettingsManager.chatBackground,
                builder: (_, path, __) {
                  if (path == null) return const SizedBox.shrink();
                  final f = File(path);
                  if (!f.existsSync()) return const SizedBox.shrink();
                  return ValueListenableBuilder<bool>(
                    valueListenable: SettingsManager.blurBackground,
                    builder: (_, blur, __) {
                      return ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.blurSigma,
                        builder: (_, sigma, __) {
                          final provider = FileImage(f);
                          final child = blur
                              ? AdaptiveBlur(
                                  imageProvider: provider,
                                  sigma: sigma,
                                  fit: BoxFit.cover)
                              : Image(image: provider, fit: BoxFit.cover);
                          return Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(opacity: 0.95, child: child),
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
                      
                      final panelW = _chatsPanelWidthNotifier.value;
                      final navWidth = isDesktop
                          ? min(panelW - 24.0, 420.0)
                          : MediaQuery.of(context).size.width / 1.8;
                      final leftPad = isDesktop
                          ? max(12.0, (panelW - navWidth) / 2)
                          : 70.0;

                      final scheme = Theme.of(context).colorScheme;
                      final navBackground = SettingsManager.getElementColor(
                        scheme.surfaceContainerHighest,
                        brightness
                      ).withValues(alpha: opacity);

                  return Positioned.fill(
                    child: Align(
                      alignment: isDesktop ? Alignment.bottomLeft : Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 100.0, end: 0.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, offset, child) {
                          return Transform.translate(
                            offset: Offset(0, offset),
                            child: Opacity(
                              opacity: (1.0 - (offset / 100.0)).clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: SafeArea(
                          bottom: true,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: 18.0,
                              left: leftPad,
                              right: isDesktop ? 0 : 70,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                              height: 58,
                              width: isDesktop ? navWidth : navWidth + 20,
                              
                              decoration: BoxDecoration(
                                color: navBackground,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 0 : 10,
                                  ),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onHorizontalDragUpdate: isDesktop ? null : (details) {
                                      final tabWidth = navWidth / 5;
                                      final newIndex = (details.localPosition.dx / tabWidth)
                                          .floor()
                                          .clamp(0, 4);
                                      if (newIndex != _index) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _index = newIndex);
                                        if (_pageController.hasClients) {
                                          
                                          _pageController.jumpToPage(newIndex);
                                        }
                                      }
                                    },
                                    child: SizedBox(
                                    width: navWidth,
                                    height: 58,
                                    child: NavigationBar(
                                    selectedIndex: _index < 5 ? _index : 4,
                                    onDestinationSelected: _onTabSelected,
                                    height: 58,
                                    labelBehavior:
                                        NavigationDestinationLabelBehavior
                                            .alwaysHide,
                                    destinations: [
                                      NavigationDestination(
                                        icon: AnimatedNavIcon(
                                          icon: Icons.chat_bubble,
                                          size: 22,
                                          isSelected: _index == 0,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 300,
                                        ),
                                        selectedIcon: AnimatedNavIcon(
                                          icon: Icons.chat_bubble,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.primary,
                                          isSelected: _index == 0,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 300,
                                        ),
                                        label: '',
                                      ),
                                      NavigationDestination(
                                        icon: AnimatedNavIcon(
                                          icon: Icons.group,
                                          size: 22,
                                          isSelected: _index == 1,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 400,
                                        ),
                                        selectedIcon: AnimatedNavIcon(
                                          icon: Icons.group,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.primary,
                                          isSelected: _index == 1,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 400,
                                        ),
                                        label: '',
                                      ),
                                      NavigationDestination(
                                        icon: AnimatedNavIcon(
                                          icon: Icons.bookmark_outlined,
                                          size: 22,
                                          isSelected: _index == 2,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 500,
                                        ),
                                        selectedIcon: AnimatedNavIcon(
                                          icon: Icons.bookmark,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.primary,
                                          isSelected: _index == 2,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 500,
                                        ),
                                        label: '',
                                      ),
                                      NavigationDestination(
                                        icon: AnimatedNavIcon(
                                          icon: Icons.person,
                                          size: 22,
                                          isSelected: _index == 3,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 600,
                                        ),
                                        selectedIcon: AnimatedNavIcon(
                                          icon: Icons.person,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.primary,
                                          isSelected: _index == 3,
                                          animationType: NavIconAnimationType.bounce,
                                          entryDelay: 600,
                                        ),
                                        label: '',
                                      ),
                                      NavigationDestination(
                                        icon: AnimatedNavIcon(
                                          icon: Icons.settings,
                                          size: 22,
                                          isSelected: _index == 4,
                                          animationType: NavIconAnimationType.spin,
                                          entryDelay: 700,
                                        ),
                                        selectedIcon: AnimatedNavIcon(
                                          icon: Icons.settings,
                                          size: 24,
                                          color: Theme.of(context).colorScheme.primary,
                                          isSelected: _index == 4,
                                          animationType: NavIconAnimationType.spin,
                                          entryDelay: 700,
                                        ),
                                        label: '',
                                      ),
                                    ],
                                    backgroundColor: Colors.transparent,
                                    indicatorColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.15),
                                  ),
                                  ), 
                                ), 
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                      ),
                    ),
                    );
                  },
                );
                },
              );
            },
          ),

        ],
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

