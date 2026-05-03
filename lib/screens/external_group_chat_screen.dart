// lib/screens/external_group_chat_screen.dart
import 'package:ONYX/screens/forward_screen.dart';
import 'package:ONYX/managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/group.dart';
import '../models/external_server.dart';
import '../managers/external_server_manager.dart';
import '../enums/media_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../widgets/avatar_crop_screen.dart';
import '../utils/file_utils.dart';
import '../globals.dart';
import 'chats_tab.dart' show getPreviewText;
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../utils/image_file_cache.dart';
import '../utils/clipboard_image.dart';
import '../utils/upload_task.dart';
import '../widgets/pending_upload_card.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/voice_channel_popup.dart';
import '../voice/voice_channel_manager.dart';
import '../widgets/message_reaction_bar.dart';
import '../widgets/media_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> _randomHints = [
  'Say something!',
  'Type it out!',
  'Write something...',
  'Break the silence!',
];

List<Map<String, dynamic>> _parseJsonInIsolate(String jsonString) {
  final data = jsonDecode(jsonString) as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
}

String _encodeJsonInIsolate(List<Map<String, dynamic>> messages) {
  return jsonEncode(messages);
}

class ExternalGroupChatScreen extends StatefulWidget {
  final Group group;
  final ExternalServer server;
  const ExternalGroupChatScreen(
      {super.key, required this.group, required this.server});

  @override
  State<ExternalGroupChatScreen> createState() =>
      _ExternalGroupChatScreenState();
}

class _ExternalGroupChatScreenState extends State<ExternalGroupChatScreen>
    with SingleTickerProviderStateMixin, ReactionStateMixin {
  static final Set<String> _sessionInputAnimationsShown = {};

  final TextEditingController _textCtrl = TextEditingController();
  late FocusNode _focusNode;
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  final Set<String> _allMessageIds = {};
  final Map<String, String> _pendingMessageIds = {};
  final List<UploadTask> _pendingUploads = [];
  final ValueNotifier<bool> _showScrollDownButton = ValueNotifier<bool>(false);
  late String _inputHint;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isLoadingHistory = false;
  bool _isDisposed = false;

  bool _isCurrentRoute = false;
  int _historyLoadEpoch = 0;

  late String _groupName;
  late int _avatarVersion;
  late String? _myRole;

  Map<String, dynamic>? _replyingToMessage;
  Map<String, dynamic>? _pinnedMessage;
  String? _editingMsgId;
  String? _editingOriginalContent;

  // ── in-chat search ──────────────────────────────────────────────────────────
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentMatchIdx = 0;
  List<int> _cachedSearchMatches = [];
  final _searchStats =
      ValueNotifier<({int current, int total})>((current: 0, total: 0));
  final _searchFocusNode = FocusNode();

  late final _selectionNotifier = ValueNotifier<
      ({
        bool active,
        Map<String, Map<String, dynamic>> selected
      })>((active: false, selected: {}));
  Map<String, Map<String, dynamic>> get _selectedExtMessages =>
      _selectionNotifier.value.selected;

  bool _isExtTextMessage(Map<String, dynamic> msg) {
    final t = msg['content']?.toString() ?? '';
    return !t.startsWith('IMAGEv1:') &&
        !t.startsWith('ALBUMv1:') &&
        !t.toUpperCase().startsWith('VIDEOV1:') &&
        !t.startsWith('VOICEv1:') &&
        !t.startsWith('FILEv1:') &&
        !t.startsWith('FILE:') &&
        !t.toUpperCase().startsWith('MEDIA_PROXYV1:') &&
        !t.startsWith('[cannot-decrypt');
  }

  void _enterExtSelectionMode(Map<String, dynamic> msg, String uniqueKey) {
    HapticFeedback.mediumImpact();
    final cur = _selectionNotifier.value;
    _selectionNotifier.value =
        (active: true, selected: {...cur.selected, uniqueKey: msg});
  }

  void _exitExtSelectionMode() {
    _selectionNotifier.value = (active: false, selected: {});
  }

  void _toggleExtMsgSelection(Map<String, dynamic> msg, String uniqueKey) {
    final cur = _selectionNotifier.value;
    final next = Map<String, Map<String, dynamic>>.from(cur.selected);
    if (next.containsKey(uniqueKey)) {
      next.remove(uniqueKey);
      _selectionNotifier.value = (active: next.isNotEmpty, selected: next);
    } else {
      next[uniqueKey] = msg;
      _selectionNotifier.value = (active: true, selected: next);
    }
  }

  void _copySelectedExtMessages() {
    final texts = _selectedExtMessages.values
        .where(_isExtTextMessage)
        .map((m) => m['content']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).msgCopied);
    }
    _exitExtSelectionMode();
  }

  void _forwardSelectedExtMessages() {
    final contents = _selectedExtMessages.values
        .map((m) => m['content']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    if (contents.isEmpty) return;
    _exitExtSelectionMode();
    ForwardScreen.show(context, contents);
  }

  final List<Map<String, dynamic>> _wsIncomingBuffer = [];
  Timer? _wsFlushTimer;
  Timer? _cacheSaveTimer;
  bool _suppressAutoRefocus = false;
  static const int _wsBatchSize = 50;
  static const int _wsBatchDelayMs = 150;
  static const int _cacheSaveDelayMs = 500;

  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryScaleX;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  final Set<String> _newMessageIds = {};
  final Set<String> _alreadyRenderedMessageIds = {};

  static const int _initialMessageLoadCount = 50;
  static const int _messageLoadIncrement = 30;
  int _displayedMessageCount = _initialMessageLoadCount;
  bool _isLoadingMoreMessages = false;

  bool get _canPost {
    if (!widget.group.isChannel) return true;
    return _myRole == 'owner' || _myRole == 'moderator';
  }

  @override
  void initState() {
    super.initState();

    _groupName = widget.group.name;
    _avatarVersion = widget.group.avatarVersion;
    _myRole = widget.group.myRole;
    _inputHint = _randomHints[Random().nextInt(_randomHints.length)];
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _isConnected = ExternalServerManager.isServerConnected(widget.server.id);

    _loadPinnedMessage();
    _fetchGroupInfo();

    _loadHistoryFromCache();

    if (_isConnected) {
      final voiceActive = VoiceChannelManager.instance.isInChannel.value &&
          VoiceChannelManager.instance.currentServerId.value == widget.server.id;
      if (voiceActive) {
        // Keep the WS alive — _connectToServer will reuse it (just subscribes).
        debugPrint('[ext-chat] Voice call active, reusing existing WS connection');
        _isConnected = false;
      } else {
        debugPrint('[ext-chat] Server connected, disconnecting for fresh reconnection');
        ExternalServerManager.disconnectWebSocket(widget.server.id);
        _isConnected = false;
      }
    }

    _isConnecting = true;

    debugPrint('[ext-chat] Connecting to server for fresh message history');
    _connectToServer();

    ExternalServerManager.connectedServerIds.addListener(_onConnectionChanged);

    _checkBanStatus().then((isBanned) {
      if (isBanned && mounted) {
        setState(() {
          _messages.clear();
          _allMessageIds.clear();
          // Animation status is now tracked directly in message map
        });
      }
    });
    _scroll.addListener(_onScroll);

    _inputEntryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _inputEntryScaleX = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _inputEntryController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _inputEntryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _inputEntryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _checkInputAnimationState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus && isDesktop) {
        _focusNode.requestFocus();
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted && isDesktop) {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (_suppressAutoRefocus) return;
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    ExternalServerManager.connectedServerIds
        .removeListener(_onConnectionChanged);

    ExternalServerManager.unsubscribeFromGroup(
        widget.server.id, widget.group.id);

    // Keep the WS alive if the user is currently in a voice channel on this
    // server — they want to continue talking while browsing other screens.
    final voiceActive = VoiceChannelManager.instance.isInChannel.value &&
        VoiceChannelManager.instance.currentServerId.value == widget.server.id;
    if (!voiceActive) {
      debugPrint('[ext-chat] Disconnecting from server on screen close');
      ExternalServerManager.disconnectWebSocket(widget.server.id);
    } else {
      debugPrint('[ext-chat] Keeping WS alive — voice call in progress');
    }

    _wsFlushTimer?.cancel();
    _cacheSaveTimer?.cancel();
    _wsIncomingBuffer.clear();
    _textCtrl.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    _showScrollDownButton.dispose();
    _inputEntryController.dispose();
    _selectionNotifier.dispose();
    _searchController.dispose();
    _searchStats.dispose();
    _searchFocusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_showSearch) {
        _closeSearch();
      } else {
        _openSearch();
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && _showSearch) {
      _closeSearch();
      return true;
    }
    return false;
  }

  // ── search helpers ───────────────────────────────────────────────────────────

  void _closeSearch() {
    _searchController.clear();
    _searchStats.value = (current: 0, total: 0);
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _currentMatchIdx = 0;
      _cachedSearchMatches = [];
    });
    _suppressAutoRefocus = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
      _currentMatchIdx = 0;
    });
  }

  void _navigateSearchPrev() {
    if (_cachedSearchMatches.isEmpty) return;
    setState(() {
      _currentMatchIdx = (_currentMatchIdx + 1) % _cachedSearchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _navigateSearchNext() {
    if (_cachedSearchMatches.isEmpty) return;
    setState(() {
      _currentMatchIdx = (_currentMatchIdx - 1 + _cachedSearchMatches.length) %
          _cachedSearchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _openSearch() {
    _suppressAutoRefocus = true;
    setState(() {
      _showSearch = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  void _scrollToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _cachedSearchMatches.isEmpty)
        return;
      final matchAdjI = _cachedSearchMatches[_currentMatchIdx];
      final pendingCount = _pendingUploads.length;
      final totalItems = pendingCount + _rebuildExtDisplayItems().length;
      if (totalItems == 0) return;
      final listIdx = pendingCount + matchAdjI;
      final maxExtent = _scroll.position.maxScrollExtent;
      final target = (maxExtent * listIdx / totalItems).clamp(0.0, maxExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _checkInputAnimationState() {
    final groupId = 'external_group_${widget.server.id}_${widget.group.id}';

    if (!_sessionInputAnimationsShown.contains(groupId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _inputEntryController.forward();
        }
      });
      _sessionInputAnimationsShown.add(groupId);
      _hasInputAnimated = true;
    } else {
      _inputEntryController.value = 1.0;
      _hasInputAnimated = true;
    }
  }

  @override
  void reassemble() {
    super.reassemble();

    final connected = ExternalServerManager.isServerConnected(widget.server.id);
    if (connected != _isConnected) {
      setState(() => _isConnected = connected);
    }
    if (_isConnected) {
      _subscribeWebSocket();
      _loadHistoryFromNetwork();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (isCurrent && !_isCurrentRoute) {
      _isCurrentRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyOpenChatAnimationKeys();
      });
    } else if (!isCurrent) {
      _isCurrentRoute = false;
    }
  }

  void _applyOpenChatAnimationKeys() {
    if (_messages.isEmpty) return;

    setState(() {
      _historyLoadEpoch++;
      _alreadyRenderedMessageIds.clear();
      for (final m in _messages) {
        final msgId = m['id']?.toString() ?? '';
        if (msgId.isNotEmpty) {
          m['animationId'] = '$msgId#$_historyLoadEpoch';
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ExternalGroupChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isSameChat = oldWidget.server.id == widget.server.id &&
        oldWidget.group.id == widget.group.id;

    if (isSameChat) {
      return;
    }

    _allMessageIds.clear();
    _pendingMessageIds.clear();
    // Animation status is now tracked directly in message map
    _inputHint = _randomHints[Random().nextInt(_randomHints.length)];
    _isConnected = ExternalServerManager.isServerConnected(widget.server.id);
    _displayedMessageCount = _initialMessageLoadCount;
    _loadHistoryFromCache().then((_) {
      if (_isConnected) _loadHistoryFromNetwork();
    });
    if (_isConnected) {
      _subscribeWebSocket();
    }
  }

  void _onConnectionChanged() {
    final connected = ExternalServerManager.isServerConnected(widget.server.id);
    if (connected != _isConnected && mounted) {
      debugPrint(
          '[ext-chat] Connection state changed: $_isConnected -> $connected');
      setState(() {
        _isConnected = connected;
        _isConnecting = false;
      });
      if (connected) {
        debugPrint('[ext-chat] Now connected, subscribing to WebSocket');
        _subscribeWebSocket();
        _loadHistoryFromNetwork();
      }
    } else if (_isConnecting && connected && mounted) {
      debugPrint('[ext-chat] Was connecting, now connected');
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
      _subscribeWebSocket();
      _loadHistoryFromNetwork();
    }
  }

  Future<void> _connectToServer() async {
    if (ExternalServerManager.isServerConnected(widget.server.id)) {
      debugPrint('[ext-chat] Server already connected, just subscribing');
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
        _subscribeWebSocket();
        _loadHistoryFromNetwork();
      }
      return;
    }

    setState(() => _isConnecting = true);
    try {
      debugPrint(
          '[ext-chat] Connecting to server: ${widget.server.name} (${widget.server.id})');

      final connected =
          await ExternalServerManager.connectWebSocket(widget.server.id);
      debugPrint('[ext-chat] Connection result: $connected');

      if (connected) {
        await ExternalServerManager.refreshAllExternalGroups();
        debugPrint(
            '[ext-chat] Connected successfully to: ${widget.server.name}');

        if (mounted) {
          setState(() {
            _isConnected = true;
            _isConnecting = false;
          });
          _subscribeWebSocket();
          _loadHistoryFromNetwork();
        }
      } else {
        debugPrint('[ext-chat] WARNING: Connection failed');
        if (mounted) {
          setState(() => _isConnecting = false);
        }
      }
    } catch (e) {
      debugPrint('[ext-chat] Connection failed: $e');
      if (mounted) {
        setState(() => _isConnecting = false);
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .failedToConnect(e.toString()));
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;

    final pixels = _scroll.position.pixels;
    if (pixels > 0.0 &&
        pixels <= 1.5 &&
        !_scroll.position.isScrollingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients &&
            _scroll.position.pixels > 0.0 &&
            _scroll.position.pixels <= 1.5) {
          _scroll.jumpTo(0.0);
        }
      });
    }
    final atBottom = pixels <= 1.0;
    if (_showScrollDownButton.value != !atBottom) {
      _showScrollDownButton.value = !atBottom;
    }

    if (!_isLoadingMoreMessages && _messages.length > _displayedMessageCount) {
      final maxScroll = _scroll.position.maxScrollExtent;
      final currentScroll = _scroll.position.pixels;

      final threshold = maxScroll > 0 ? maxScroll * 0.5 : 500;

      if (currentScroll > threshold) {
        _isLoadingMoreMessages = true;

        debugPrint(
            '[lazy-load] Triggering load: scroll=$currentScroll, max=$maxScroll, threshold=$threshold');

        setState(() {
          final oldCount = _displayedMessageCount;
          _displayedMessageCount =
              (_displayedMessageCount + _messageLoadIncrement)
                  .clamp(0, _messages.length);
          _isLoadingMoreMessages = false;

          debugPrint(
              '[lazy-load] Loaded more messages: $oldCount -> $_displayedMessageCount / ${_messages.length}');
        });
      }
    }
  }

  void _subscribeWebSocket() {
    ExternalServerManager.subscribeToGroup(
      widget.server.id,
      widget.group.id,
      _onWsMessage,
    );
  }

  void _onWsMessage(Map<String, dynamic> obj) {
    final type = obj['type']?.toString();

    if (type == 'banned') {
      _handleBanned(obj['reason']?.toString());
      return;
    }

    if (type == 'kicked') {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (type == 'unbanned') {
      _handleUnbanned();
      return;
    }

    if (type == 'role_changed') {
      final newRole = obj['role']?.toString();
      if (newRole != null && mounted) {
        final currentGroups = ExternalServerManager.externalGroups.value;
        final updatedGroups = currentGroups.map((g) {
          if (g.id == widget.group.id &&
              g.externalServerId == widget.server.id) {
            return Group(
              id: g.id,
              name: g.name,
              isChannel: g.isChannel,
              owner: g.owner,
              inviteLink: g.inviteLink,
              avatarVersion: g.avatarVersion,
              externalServerId: g.externalServerId,
              myRole: newRole,
            );
          }
          return g;
        }).toList();
        ExternalServerManager.externalGroups.value = updatedGroups;

        setState(() {
          _myRole = newRole;
        });

        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .roleChanged(newRole));
      }
      return;
    }

    if (type == 'group_updated') {
      final newName = obj['name']?.toString();
      debugPrint('[ws] group_updated: newName=$newName');
      if (newName != null && mounted) {
        setState(() {
          _groupName = newName;
        });
        debugPrint('[ws] Updated _groupName to: $_groupName');

        final currentGroups = ExternalServerManager.externalGroups.value;
        final updatedGroups = currentGroups.map((g) {
          if (g.id == widget.group.id &&
              g.externalServerId == widget.server.id) {
            return Group(
              id: g.id,
              name: newName,
              isChannel: g.isChannel,
              owner: g.owner,
              inviteLink: g.inviteLink,
              avatarVersion: g.avatarVersion,
              externalServerId: g.externalServerId,
              myRole: g.myRole,
            );
          }
          return g;
        }).toList();
        ExternalServerManager.externalGroups.value = updatedGroups;
      }
      return;
    }

    if (type == 'group_msg_edited') {
      final editedId = (obj['message_id'] ?? '').toString();
      final newContent = obj['new_content'] as String?;
      if (editedId.isNotEmpty && newContent != null && mounted) {
        setState(() {
          final idx =
              _messages.indexWhere((m) => m['id']?.toString() == editedId);
          if (idx >= 0) _messages[idx]['content'] = newContent;
        });
        _saveHistoryToCache(_messages);
      }
      return;
    }

    if (type == 'group_msg_deleted') {
      final deletedId = (obj['message_id'] ?? '').toString();
      if (deletedId.isNotEmpty && mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id']?.toString() == deletedId);
          _allMessageIds.remove(deletedId);
        });
        _saveHistoryToCache(_messages);
      }
      return;
    }

    if (type == 'reaction_update') {
      final messageId = (obj['message_id'] ?? '').toString();
      final reactions = obj['reactions'];
      if (messageId.isNotEmpty && reactions is Map && mounted) {
        final reactionsMap = Map<String, dynamic>.from(reactions);
        setState(() {
          final idx = _messages.indexWhere((m) => m['id']?.toString() == messageId);
          if (idx >= 0) _messages[idx]['reactions'] = reactionsMap;
        });
        applyReactionUpdate('ext_$messageId', reactionsMap);
        _debouncedCacheSave();
      }
      return;
    }

    if (type == 'group_avatar_updated') {
      final newVersion = obj['avatar_version'];
      debugPrint('[ws] group_avatar_updated: newVersion=$newVersion');
      if (newVersion != null && mounted) {
        final parsedVersion = newVersion is int
            ? newVersion
            : int.tryParse(newVersion.toString()) ?? _avatarVersion;
        setState(() {
          _avatarVersion = parsedVersion;
        });
        debugPrint('[ws] Updated _avatarVersion to: $_avatarVersion');

        final currentGroups = ExternalServerManager.externalGroups.value;
        final updatedGroups = currentGroups.map((g) {
          if (g.id == widget.group.id &&
              g.externalServerId == widget.server.id) {
            return Group(
              id: g.id,
              name: g.name,
              isChannel: g.isChannel,
              owner: g.owner,
              inviteLink: g.inviteLink,
              avatarVersion: parsedVersion,
              externalServerId: g.externalServerId,
              myRole: g.myRole,
            );
          }
          return g;
        }).toList();
        ExternalServerManager.externalGroups.value = updatedGroups;
      }
      return;
    }

    final msgId = obj['message_id']?.toString() ?? '';

    if (msgId.isEmpty) return;
    if (_allMessageIds.contains(msgId)) {
      debugPrint(
          '[ext-chat] Duplicate blocked in _onWsMessage (in _allMessageIds): $msgId');
      return;
    }
    if (_pendingMessageIds.containsValue(msgId)) {
      debugPrint(
          '[ext-chat] Duplicate blocked in _onWsMessage (in _pendingMessageIds): $msgId');
      return;
    }

    if (_messages.any((m) => m['id']?.toString() == msgId)) {
      debugPrint(
          '[ext-chat] Duplicate blocked in _onWsMessage (in _messages): $msgId');
      return;
    }

    if (_wsIncomingBuffer.any((m) => m['id']?.toString() == msgId)) {
      debugPrint(
          '[ext-chat] Duplicate blocked in _onWsMessage (in _wsIncomingBuffer): $msgId');
      return;
    }

    final sender = obj['sender']?.toString() ?? '';

    if (widget.group.isChannel) {
      if (_pendingMessageIds.containsValue(msgId)) return;
    } else {
      if (sender == widget.server.username) {
        for (final entry in _pendingMessageIds.entries) {
          if (entry.value == msgId) return;
        }
      }
    }

    final newMsg = {
      'id': msgId,
      'animationId': msgId,
      'sender': sender,
      'content': obj['content']?.toString() ?? '',
      'timestamp':
          obj['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      'timestamp_ms':
          obj['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch,
      'reply_to_id': obj['reply_to_id'],
      'reply_to_sender': obj['reply_to_sender'],
      'reply_to_content': obj['reply_to_content'],
    };
    _bufferIncomingMessage(newMsg);
  }

  Future<void> _handleBanned(String? reason) async {
    ExternalServerManager.disconnectWebSocket(widget.server.id);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Theme.of(dialogContext).colorScheme.error),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).youHaveBeenBanned),
          ],
        ),
        content: Text(
          reason != null && reason.isNotEmpty
              ? AppLocalizations.of(context).bannedReason(reason)
              : AppLocalizations.of(context).bannedFromGroup,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isDesktop = !kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
      if (isDesktop) {
        rootScreenKey.currentState?.hideDetailPanel();
      } else {
        try {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        } catch (e) {
          debugPrint('[ExternalGroupChat] Error closing screen after ban: $e');
        }
      }
    });
  }

  Future<void> _handleUnbanned() async {
    if (!mounted) return;

    rootScreenKey.currentState?.showSnack(
        AppLocalizations(SettingsManager.appLocale.value).unbannedReconnecting);

    final isConnected =
        ExternalServerManager.isServerConnected(widget.server.id);
    if (!isConnected) {
      debugPrint('[ext-chat] Reconnecting after unban...');
      final connected =
          await ExternalServerManager.connectWebSocket(widget.server.id);
      if (connected && mounted) {
        _subscribeWebSocket();
        setState(() {
          _isConnected = true;
        });
        _loadHistoryFromNetwork();
      }
    } else {
      setState(() {
        _isConnected = true;
      });
      _loadHistoryFromNetwork();
    }
  }

  Future<bool> _checkBanStatus() async {
    try {
      final url = '${widget.server.baseUrl}/ban-status';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.server.token}'},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isBanned = data['banned'] == true;

        if (isBanned && mounted) {
          final reason = data['reason']?.toString();
          _handleBanned(reason);
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[ban-check] Error checking ban status: $e');
      return false;
    }
  }

  void _bufferIncomingMessage(Map<String, dynamic> msg) {
    _wsIncomingBuffer.add(msg);
    if (_wsIncomingBuffer.length >= _wsBatchSize) {
      _flushIncomingMessages();
    } else {
      _wsFlushTimer?.cancel();
      _wsFlushTimer = Timer(
        const Duration(milliseconds: _wsBatchDelayMs),
        _flushIncomingMessages,
      );
    }
  }

  void _flushIncomingMessages() {
    _wsFlushTimer?.cancel();
    if (_wsIncomingBuffer.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_wsIncomingBuffer);
    _wsIncomingBuffer.clear();

    if (!mounted) return;

    final isInitialWsBatch = _messages.isEmpty;
    final newMessagesToAdd = <Map<String, dynamic>>[];
    final newIdsToAdd = <String>[];

    for (final msg in batch) {
      final id = msg['id']?.toString() ?? '';

      if (id.isNotEmpty && !_allMessageIds.contains(id)) {
        msg['animationId'] = msg['animationId']?.toString() ?? id;
        newMessagesToAdd.add(msg);
        newIdsToAdd.add(id);
      }
    }

    if (newMessagesToAdd.isEmpty) return;

    // Suppress animation for old messages in large batches to improve performance
    // but do not suppress initial websocket history batch on screen open.
    const int animateLimit = 3;
    if (!isInitialWsBatch && newMessagesToAdd.length > animateLimit) {
      for (int i = 0; i < newMessagesToAdd.length - animateLimit; i++) {
        newMessagesToAdd[i]['suppressAnimation'] = true;
      }
      debugPrint(
          '[ExtGroupChat Animation] Batch received: ${newMessagesToAdd.length}, only last $animateLimit will animate');
    }

    setState(() {
      _messages.addAll(newMessagesToAdd);
      _allMessageIds.addAll(newIdsToAdd);
      _newMessageIds.addAll(newIdsToAdd);

      final addedCount = newMessagesToAdd.length;
      if (_displayedMessageCount < _messages.length) {
        _displayedMessageCount =
            (_displayedMessageCount + addedCount).clamp(0, _messages.length);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottomIfNeeded();
    });
    _debouncedCacheSave();
  }

  void _debouncedCacheSave() {
    _cacheSaveTimer?.cancel();
    _cacheSaveTimer = Timer(
      const Duration(milliseconds: _cacheSaveDelayMs),
      () => _saveHistoryToCache(_messages),
    );
  }

  Future<void> _loadHistoryFromCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/ext_group_${widget.server.id}_${widget.group.id}_history.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final msgs = await compute(_parseJsonInIsolate, jsonString);

        final newIds = <String>{};
        for (final m in msgs) {
          final id = m['id']?.toString() ?? '';
          if (id.isNotEmpty) newIds.add(id);
        }

        if (mounted && !_isDisposed) {
          final preservedAnimIds = <String, String>{
            for (final m in _messages)
              if ((m['id']?.toString() ?? '').isNotEmpty)
                m['id'].toString(): m['animationId']?.toString() ?? m['id'].toString(),
          };
          setState(() {
            _messages = msgs;
            for (final m in _messages) {
              final msgId = m['id']?.toString() ?? '';
              if (msgId.isNotEmpty) {
                m['animationId'] = preservedAnimIds[msgId] ?? msgId;
              }
            }
            _allMessageIds.clear();
            _allMessageIds.addAll(newIds);
            _displayedMessageCount =
                _initialMessageLoadCount.clamp(0, _messages.length);
          });
          final cachedReactions = <String, Map<String, dynamic>>{};
          for (final m in msgs) {
            final id = m['id']?.toString() ?? '';
            final r = m['reactions'];
            if (id.isNotEmpty && r is Map && r.isNotEmpty) {
              cachedReactions['ext_$id'] = Map<String, dynamic>.from(r);
            }
          }
          if (cachedReactions.isNotEmpty) applyReactionBatch(cachedReactions);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  Future<void> _fetchGroupInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.server.baseUrl}/group'),
        headers: {'authorization': 'Bearer ${widget.server.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final name = data['name']?.toString();
          final avatarVersion = data['avatar_version'];
          if (mounted && name != null) {
            setState(() {
              _groupName = name;
              if (avatarVersion != null) {
                _avatarVersion = avatarVersion is int
                    ? avatarVersion
                    : int.tryParse(avatarVersion.toString()) ?? _avatarVersion;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[fetch-group-info] Error: $e');
    }
  }

  Future<void> _loadHistoryFromNetwork() async {
    if (mounted && !_isDisposed) {
      setState(() => _isLoadingHistory = true);
    }

    try {
      final messages = await ExternalServerManager.fetchHistory(
        widget.server.id,
        widget.group.id,
      );
      if (!mounted || _isDisposed) return;

      final newMessages = <Map<String, dynamic>>[];
      final reactionBatch = <String, Map<String, dynamic>>{};
      for (final m in messages) {
        final id = m['id']?.toString() ??
            '${m['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch}';
        final sender = (m['sender'] ?? '').toString();
        final content = (m['content'] ?? '').toString();
        final ts = (m['timestamp'] ?? DateTime.now().toIso8601String()).toString();
        final reactionsRaw = m['reactions'];
        final reactionsMap = (reactionsRaw is Map && reactionsRaw.isNotEmpty)
            ? Map<String, dynamic>.from(reactionsRaw)
            : null;
        newMessages.add({
          'id': id,
          'sender': sender,
          'content': content,
          'timestamp': ts,
          'timestamp_ms': m['timestamp_ms'] ?? 0,
          'reply_to_id': m['reply_to_id'],
          'reply_to_sender': m['reply_to_sender'],
          'reply_to_content': m['reply_to_content'],
          if (reactionsMap != null) 'reactions': reactionsMap,
        });
        if (reactionsMap != null) {
          reactionBatch['ext_$id'] = reactionsMap;
        }
      }

      final pendingMessages = _messages.where((msg) {
        final id = msg['id']?.toString() ?? '';
        return id.startsWith('temp_') || msg['isPending'] == true;
      }).toList();

      final mergedMessages = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final m in newMessages) {
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          mergedMessages.add(m);
          seenIds.add(id);
        }
      }

      for (final m in pendingMessages) {
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          mergedMessages.add(m);
          seenIds.add(id);
        }
      }

      mergedMessages.sort((a, b) {
        final aTime = a['timestamp_ms'] as int? ?? 0;
        final bTime = b['timestamp_ms'] as int? ?? 0;
        return aTime.compareTo(bTime);
      });

      final newAllMessageIds = <String>{};
      for (final m in mergedMessages) {
        final id = m['id']?.toString() ?? '';
        if (id.isNotEmpty) newAllMessageIds.add(id);
      }

      final preservedAnimIds = <String, String>{
        for (final m in _messages)
          if ((m['id']?.toString() ?? '').isNotEmpty)
            m['id'].toString(): m['animationId']?.toString() ?? m['id'].toString(),
      };
      setState(() {
        _messages = mergedMessages;
        for (final m in _messages) {
          final msgId = m['id']?.toString() ?? '';
          if (msgId.isNotEmpty) {
            m['animationId'] = preservedAnimIds[msgId] ?? msgId;
          }
        }
        _allMessageIds.clear();
        _allMessageIds.addAll(newAllMessageIds);
        _displayedMessageCount =
            _initialMessageLoadCount.clamp(0, _messages.length);
        _isLoadingHistory = false;
      });

      if (reactionBatch.isNotEmpty) applyReactionBatch(reactionBatch);
      _debouncedCacheSave();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('[ext-chat] Failed to load history: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _saveHistoryToCache(List<Map<String, dynamic>> messages) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/ext_group_${widget.server.id}_${widget.group.id}_history.json');

      final jsonString = await compute(_encodeJsonInIsolate, messages);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    if (_editingMsgId != null) {
      final editId = _editingMsgId!;
      _cancelEditingExtMessage();
      await _submitExtMessageEdit(editId, text.trim());
      return;
    }

    if (!_canPost) {
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).onlyModsCanPost);
      return;
    }

    final replyInfo = _replyingToMessage;
    _textCtrl.clear();
    setState(() => _replyingToMessage = null);

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final now = DateTime.now();

    final sender = widget.group.isChannel ? _groupName : widget.server.username;

    setState(() {
      _messages.add({
        'id': tempId,
        'animationId': tempId,
        'sender': sender,
        'content': text.trim(),
        'timestamp': now.toIso8601String(),
        'timestamp_ms': now.millisecondsSinceEpoch,
        'isPending': true,
        'reply_to_id': replyInfo?['id'],
        'reply_to_sender': replyInfo?['sender'],
        'reply_to_content': replyInfo?['content'],
      });
      _allMessageIds.add(tempId);
      _newMessageIds.add(tempId);

      if (_displayedMessageCount < _messages.length) {
        _displayedMessageCount = _messages.length;
      }
    });

    _saveHistoryToCache(_messages);
    _scrollToBottomAfterSend();

    if (!isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }

    try {
      final result = await ExternalServerManager.sendMessage(
        widget.server.id,
        widget.group.id,
        text.trim(),
        replyToId: replyInfo != null
            ? int.tryParse(replyInfo['id']?.toString() ?? '')
            : null,
        replyToSender: replyInfo?['sender']?.toString(),
        replyToContent: replyInfo?['content']?.toString(),
      );

      if (result != null && mounted) {
        final serverId = result['message_id']?.toString() ?? '';
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx >= 0) {
            _messages[idx] = {
              ..._messages[idx],
              'id': serverId,
              'isPending': false
            };
            _allMessageIds.add(serverId);
            _pendingMessageIds[tempId] = serverId;
          }
        });
        _saveHistoryToCache(_messages);
      } else if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _allMessageIds.remove(tempId);
        });
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .failedSendMessage);
      }
    } catch (e) {
      debugPrint('[ext-chat] send error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _allMessageIds.remove(tempId);
        });
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).sendFailed);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    if (SettingsManager.smoothScrollEnabled.value) {
      _scroll.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      final distance = _scroll.position.pixels.abs();
      if (distance > 200 || distance <= 1.5) {
        _scroll.jumpTo(0.0);
      } else {
        _scroll.animateTo(0.0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  void _scrollToBottomAfterSend() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pixels = _scroll.position.pixels;
      if (pixels <= 4.0) {
        _scroll.jumpTo(56.0);
      }
      _scroll.animateTo(
        0.0,
        duration: const Duration(milliseconds: 310),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollToBottomIfNeeded() {
    if (!_scroll.hasClients) return;
    final current = _scroll.position.pixels;
    if (current <= 1.5) {
      _scroll.jumpTo(0.0);
    } else if (current <= 120) {
      _scroll.animateTo(0.0,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  void _startReply(Map<String, dynamic> msg) {
    setState(() => _replyingToMessage = msg);
    _focusNode.requestFocus();
  }

  void _cancelReplying() {
    if (_replyingToMessage == null) return;
    setState(() => _replyingToMessage = null);
  }

  void _cancelEditingExtMessage() {
    setState(() {
      _editingMsgId = null;
      _editingOriginalContent = null;
    });
    _textCtrl.clear();
    _focusNode.requestFocus();
  }

  Future<void> _serverToggleReaction(
      int messageId, String emoji, bool wasReacted) async {
    try {
      final base = widget.server.baseUrl;
      final token = widget.server.token;
      final gid = widget.group.id;
      final http.Response resp;
      if (wasReacted) {
        final url = '$base/groups/$gid/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}';
        debugPrint('[ext-reaction] DELETE $url');
        resp = await http.delete(
          Uri.parse(url),
          headers: {'authorization': 'Bearer $token'},
        );
      } else {
        final url = '$base/groups/$gid/messages/$messageId/reactions';
        debugPrint('[ext-reaction] POST $url emoji=$emoji');
        resp = await http.post(
          Uri.parse(url),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'emoji': emoji}),
        );
      }
      debugPrint('[ext-reaction] status=${resp.statusCode} body=${resp.body}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        final reactions = data?['reactions'];
        if (reactions is Map && mounted) {
          final reactionsMap = Map<String, dynamic>.from(reactions);
          setState(() {
            final idx = _messages.indexWhere((m) => m['id']?.toString() == messageId.toString());
            if (idx >= 0) _messages[idx]['reactions'] = reactionsMap;
          });
          applyReactionUpdate('ext_$messageId', reactionsMap);
          _debouncedCacheSave();
        }
      }
    } catch (e) {
      debugPrint('[ext-reaction] error: $e');
    }
  }

  Future<void> _submitExtMessageEdit(String msgId, String newContent) async {
    try {
      final resp = await http.patch(
        Uri.parse('${widget.server.baseUrl}/groups/${widget.group.id}/messages/$msgId'),
        headers: {
          'authorization': 'Bearer ${widget.server.token}',
          'content-type': 'application/json',
        },
        body: jsonEncode({'content': newContent}),
      );
      if (resp.statusCode == 200 && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId);
          if (idx >= 0) _messages[idx]['content'] = newContent;
        });
        _saveHistoryToCache(_messages);
      } else if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedEdit);
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedEdit);
      }
    }
  }



  bool _isExtMsgPinned(Map<String, dynamic> msg) {
    final pinId = _pinnedMessage?['id']?.toString();
    if (pinId == null) return false;
    return pinId == msg['id']?.toString();
  }

  String get _pinPrefsKey =>
      'pinned_ext_group_${widget.group.id}_${widget.server.id}';

  Future<void> _loadPinnedMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pinPrefsKey);
    if (raw != null && mounted) {
      try {
        setState(() =>
            _pinnedMessage = Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
  }

  Future<void> _savePinnedMessage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pinnedMessage == null) {
      await prefs.remove(_pinPrefsKey);
    } else {
      await prefs.setString(_pinPrefsKey, jsonEncode(_pinnedMessage));
    }
  }

  void _toggleExtPin(Map<String, dynamic> msg) {
    if (_isExtMsgPinned(msg)) {
      setState(() => _pinnedMessage = null);
    } else {
      setState(() {
        _pinnedMessage = {
          'id': msg['id']?.toString() ?? '',
          'content': msg['content']?.toString() ?? '',
          'sender': msg['senderDisplayName']?.toString() ??
              msg['sender']?.toString() ??
              '',
        };
      });
    }
    _savePinnedMessage();
  }

  String? _scrollHighlightId;
  Timer? _highlightTimer;
  final GlobalKey _scrollTargetKey = GlobalKey();
  String? _scrollTargetId;

  // ── Day-separator display items ─────────────────────────────────────────
  List<Object> _extDisplayItems =
      []; // elements: Map<String,dynamic> | DateTime
  int _extDisplayHash = -1;

  DateTime _getExtMsgTime(Map<String, dynamic> msg) {
    final tsMs = msg['timestamp_ms'];
    if (tsMs is int && tsMs > 0)
      return DateTime.fromMillisecondsSinceEpoch(tsMs);
    return DateTime.tryParse(msg['timestamp']?.toString() ?? '') ??
        DateTime.now();
  }

  List<Object> _rebuildExtDisplayItems() {
    final visibleCount = _displayedMessageCount.clamp(0, _messages.length);
    final hash = visibleCount ^
        (_messages.isNotEmpty ? (_messages.last['id']?.hashCode ?? 0) : 0);
    if (hash == _extDisplayHash && _extDisplayItems.isNotEmpty)
      return _extDisplayItems;
    final visibleMessages = visibleCount > 0
        ? _messages.sublist(_messages.length - visibleCount)
        : <Map<String, dynamic>>[];
    final List<Object> items = [];
    DateTime? currentDay;
    for (final msg in visibleMessages) {
      final t = _getExtMsgTime(msg);
      final day = DateTime(t.year, t.month, t.day);
      if (currentDay == null || currentDay != day) {
        items.add(day);
        currentDay = day;
      }
      items.add(msg);
    }
    _extDisplayItems = items.reversed.toList();
    _extDisplayHash = hash;
    return _extDisplayItems;
  }

  Widget _buildExtDaySeparator(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final l = AppLocalizations.of(context);
    final String dayText;
    if (date == today) {
      dayText = l.today;
    } else if (date == yesterday) {
      dayText = l.yesterday;
    } else {
      dayText = '${date.day}.${date.month}.${date.year}';
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child: Container(
                height: 1, color: cs.outlineVariant.withValues(alpha: 0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(dayText,
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
            child: Container(
                height: 1, color: cs.outlineVariant.withValues(alpha: 0.3))),
      ]),
    );
  }

  void _flashHighlight(String id) {
    _highlightTimer?.cancel();
    setState(() => _scrollHighlightId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scrollHighlightId = null);
    });
  }

  void _scrollToExtMessageById(String? msgId) {
    if (msgId == null || !_scroll.hasClients) return;
    final displayItems = _rebuildExtDisplayItems();
    int? listviewIdx;
    for (int j = 0; j < displayItems.length; j++) {
      final item = displayItems[j];
      if (item is Map<String, dynamic> && item['id']?.toString() == msgId) {
        listviewIdx = j + _pendingUploads.length;
        break;
      }
    }
    if (listviewIdx == null) return;

    setState(() => _scrollTargetId = msgId);

    final maxExt = _scroll.position.maxScrollExtent;
    final totalItems = _pendingUploads.length + displayItems.length;
    final approxOffset = totalItems > 0
        ? ((listviewIdx / totalItems) * maxExt).clamp(0.0, maxExt)
        : 0.0;
    _scroll.jumpTo(approxOffset);

    void tryEnsureVisible([int retries = 2]) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _scrollTargetKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut)
              .then((_) {
            if (mounted) {
              setState(() => _scrollTargetId = null);
              _flashHighlight(msgId);
            }
          });
        } else if (retries > 0) {
          tryEnsureVisible(retries - 1);
        } else {
          _flashHighlight(msgId);
        }
      });
    }

    tryEnsureVisible();
  }

  Widget _buildExtPinnedBanner(BuildContext context) {
    final msg = _pinnedMessage!;
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) {
          final bgColor = SettingsManager.getElementColor(
            colorScheme.surfaceContainerHighest,
            brightness,
          );
          return GestureDetector(
            onTap: () =>
                _scrollToExtMessageById(_pinnedMessage?['id']?.toString()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.push_pin_rounded,
                      size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pinned Message',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          getPreviewText(msg['content']?.toString() ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      setState(() => _pinnedMessage = null);
                      _savePinnedMessage();
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExternalMessageMenu(Map<String, dynamic> msg) {
    _focusNode.unfocus();
    final content = msg['content']?.toString() ?? '';
    final isImage = content.startsWith('IMAGEv1:');
    final isAlbum = content.startsWith('ALBUMv1:');
    final isVideo = content.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = content.startsWith('VOICEv1:');
    final isFile = content.startsWith('FILEv1:') || content.startsWith('FILE:');
    final isProxy = content.toUpperCase().startsWith('MEDIA_PROXYV1:');
    bool isProxySaveableMobile = false;
    if (isProxy) {
      try {
        final data = jsonDecode(content.substring('MEDIA_PROXYv1:'.length))
            as Map<String, dynamic>;
        final type = data['type'] as String?;
        final url = (data['url'] as String?)?.trim() ?? '';
        if (type == 'album' || url.isNotEmpty) isProxySaveableMobile = true;
      } catch (_) {}
    }
    final isSaveable = isImage ||
        isAlbum ||
        isVideo ||
        isVoice ||
        isFile ||
        isProxySaveableMobile;
    final isMedia = isSaveable ||
        isProxy ||
        (content.startsWith('http') &&
            (content.contains('/uploads/') ||
                content.contains('file.io') ||
                content.contains('cdn.')));
    final colorScheme = Theme.of(context).colorScheme;

    Widget actionTile(IconData icon, String label, VoidCallback? onTap,
        {Color? color}) {
      final effective = color ?? colorScheme.onSurface;
      return ListTile(
        leading: Icon(icon,
            color: onTap != null
                ? effective
                : colorScheme.onSurface.withValues(alpha: 0.3)),
        title: Text(label,
            style: TextStyle(
                color: onTap != null
                    ? effective
                    : colorScheme.onSurface.withValues(alpha: 0.3))),
        onTap: onTap,
        dense: true,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) {
          final sheetColor = SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest, brightness);
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  actionTile(Icons.reply_rounded, 'Reply', () {
                    Navigator.pop(ctx);
                    _startReply(msg);
                  }),
                  actionTile(Icons.add_reaction_outlined, 'React', () {
                    Navigator.pop(ctx);
                    final extMsgId = msg['id']?.toString() ?? '';
                    final msgIdInt = int.tryParse(extMsgId);
                    openEmojiPicker(context, 'ext_$extMsgId', widget.server.username,
                        onAfterToggle: (emoji, wasReacted) {
                      if (msgIdInt != null) {
                        _serverToggleReaction(msgIdInt, emoji, wasReacted);
                      }
                    });
                  }),
                  actionTile(
                    _isExtMsgPinned(msg)
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    _isExtMsgPinned(msg) ? 'Unpin' : 'Pin',
                    () {
                      Navigator.pop(ctx);
                      _toggleExtPin(msg);
                    },
                  ),
                  if (isSaveable)
                    actionTile(Icons.save_alt_rounded, 'Save', () {
                      Navigator.pop(ctx);
                      _saveMediaFromMessage(content);
                    }),
                  if (!isMedia)
                    actionTile(Icons.copy_rounded, 'Copy', () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: content));
                      rootScreenKey.currentState?.showSnack(
                          AppLocalizations(SettingsManager.appLocale.value)
                              .msgCopied);
                    }),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveMediaFromMessage(String content) async {
    if (kIsWeb) {
      rootScreenKey.currentState?.showSnack('Save not supported on web');
      return;
    }
    try {
      if (content.startsWith('IMAGEv1:')) {
        final data = jsonDecode(content.substring('IMAGEv1:'.length))
            as Map<String, dynamic>;
        final filename =
            data['url'] as String? ?? data['filename'] as String? ?? '';
        if (filename.isEmpty) return;
        final cached = imageFileCache[filename];
        if (cached == null) {
          rootScreenKey.currentState?.showSnack('Image not loaded yet');
          return;
        }
        await _saveFileToDevice(cached.file, p.basename(filename));
        return;
      }
      if (content.startsWith('VOICEv1:')) {
        final meta = jsonDecode(content.substring('VOICEv1:'.length))
            as Map<String, dynamic>;
        final filename =
            meta['url'] as String? ?? meta['filename'] as String? ?? '';
        final orig = meta['orig'] as String? ?? p.basename(filename);
        if (filename.isEmpty) return;
        final localPath = mediaFilePathRegistry[filename];
        if (localPath == null) {
          rootScreenKey.currentState?.showSnack('Voice not loaded yet');
          return;
        }
        String saveName = orig.isNotEmpty ? orig : p.basename(localPath);
        if (p.extension(saveName).isEmpty)
          saveName = saveName + p.extension(localPath);
        await _saveFileToDevice(File(localPath), saveName);
        return;
      }
      if (content.toUpperCase().startsWith('VIDEOV1:')) {
        final meta = jsonDecode(content.substring('VIDEOv1:'.length))
            as Map<String, dynamic>;
        final filename =
            meta['url'] as String? ?? meta['filename'] as String? ?? '';
        final orig = meta['orig'] as String? ?? p.basename(filename);
        if (filename.isEmpty) return;
        final localPath = mediaFilePathRegistry[filename];
        if (localPath == null) {
          rootScreenKey.currentState?.showSnack('Video not loaded yet');
          return;
        }
        await _saveFileToDevice(
            File(localPath), orig.isNotEmpty ? orig : p.basename(localPath));
        return;
      }
      if (content.startsWith('FILEv1:') || content.startsWith('FILE:')) {
        final String filename;
        final String orig;
        if (content.startsWith('FILEv1:')) {
          final meta = jsonDecode(content.substring('FILEv1:'.length))
              as Map<String, dynamic>;
          filename = meta['filename'] as String? ?? '';
          orig = meta['orig'] as String? ?? p.basename(filename);
        } else {
          filename = content.substring('FILE:'.length).trim();
          orig = p.basename(filename);
        }
        if (filename.isEmpty) return;
        final localPath = mediaFilePathRegistry[filename];
        if (localPath == null) {
          rootScreenKey.currentState?.showSnack('File not loaded yet');
          return;
        }
        await _saveFileToDevice(
            File(localPath), orig.isNotEmpty ? orig : p.basename(localPath));
        return;
      }
      if (content.startsWith('ALBUMv1:')) {
        final list =
            jsonDecode(content.substring('ALBUMv1:'.length)) as List<dynamic>;
        final items = list.whereType<Map<String, dynamic>>().toList();
        if (items.isEmpty) return;
        int saved = 0, failed = 0;
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          for (final item in items) {
            final filename = item['filename'] as String? ?? '';
            final cached = imageFileCache[filename];
            if (cached == null) {
              failed++;
              continue;
            }
            try {
              final ok = await GallerySaver.saveImage(cached.file.path,
                  albumName: 'ONYX');
              if (ok == true)
                saved++;
              else
                failed++;
            } catch (_) {
              failed++;
            }
          }
          rootScreenKey.currentState?.showSnack(failed == 0
              ? 'All $saved images saved to gallery'
              : '$saved saved, $failed failed');
          return;
        }
        if (!kIsWeb &&
            (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          final dirPath = await FilePicker.platform.getDirectoryPath(
              dialogTitle: 'Choose folder to save all images');
          if (dirPath == null || dirPath.isEmpty) {
            rootScreenKey.currentState?.showSnack('Save cancelled');
            return;
          }
          for (final item in items) {
            final filename = item['filename'] as String? ?? '';
            final orig = (item['orig'] as String?)?.isNotEmpty == true
                ? item['orig'] as String
                : p.basename(filename);
            final cached = imageFileCache[filename];
            if (cached == null) {
              failed++;
              continue;
            }
            try {
              await cached.file.copy(p.join(dirPath, orig));
              saved++;
            } catch (_) {
              failed++;
            }
          }
          rootScreenKey.currentState?.showSnack(failed == 0
              ? 'All $saved images saved to: $dirPath'
              : '$saved saved, $failed failed');
        }
      }
      if (content.toUpperCase().startsWith('MEDIA_PROXYV1:')) {
        final data = jsonDecode(content.substring('MEDIA_PROXYv1:'.length))
            as Map<String, dynamic>;
        final type = data['type'] as String?;
        if (type == 'album') {
          final rawItems = data['items'];
          final items = (rawItems is List)
              ? rawItems.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];
          if (items.isEmpty) return;
          int saved = 0, failed = 0;
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            for (final item in items) {
              final url = (item['url'] as String?)?.trim() ?? '';
              if (url.isEmpty) {
                failed++;
                continue;
              }
              final authUrl = ExternalServerManager.addTokenToUrl(url);
              final cached = imageFileCache[authUrl];
              if (cached == null) {
                failed++;
                continue;
              }
              try {
                final ok = await GallerySaver.saveImage(cached.file.path,
                    albumName: 'ONYX');
                if (ok == true) {
                  saved++;
                } else {
                  failed++;
                }
              } catch (_) {
                failed++;
              }
            }
            rootScreenKey.currentState?.showSnack(failed == 0
                ? 'All $saved images saved to gallery'
                : '$saved saved, $failed failed');
            return;
          }
          if (!kIsWeb &&
              (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
            final dirPath = await FilePicker.platform.getDirectoryPath(
                dialogTitle: 'Choose folder to save all images');
            if (dirPath == null || dirPath.isEmpty) {
              rootScreenKey.currentState?.showSnack('Save cancelled');
              return;
            }
            for (final item in items) {
              final url = (item['url'] as String?)?.trim() ?? '';
              final orig = (item['orig'] as String?)?.isNotEmpty == true
                  ? item['orig'] as String
                  : p.basename(url);
              if (url.isEmpty) {
                failed++;
                continue;
              }
              final authUrl = ExternalServerManager.addTokenToUrl(url);
              final cached = imageFileCache[authUrl];
              if (cached == null) {
                failed++;
                continue;
              }
              try {
                await cached.file.copy(p.join(dirPath, orig));
                saved++;
              } catch (_) {
                failed++;
              }
            }
            rootScreenKey.currentState?.showSnack(failed == 0
                ? 'All $saved images saved to: $dirPath'
                : '$saved saved, $failed failed');
          }
          return;
        }
        final url = (data['url'] as String?)?.trim() ?? '';
        final orig = data['orig'] as String? ?? '';
        if (url.isEmpty) return;
        final authUrl = ExternalServerManager.addTokenToUrl(url);
        final isImg = type == 'image' ||
            (['.jpg', '.jpeg', '.png', '.gif', '.webp']
                    .any(orig.toLowerCase().endsWith) ||
                ['.jpg', '.jpeg', '.png', '.gif', '.webp']
                    .any(url.toLowerCase().endsWith));
        if (isImg) {
          final cached = imageFileCache[authUrl];
          if (cached == null) {
            rootScreenKey.currentState?.showSnack('Image not loaded yet');
            return;
          }
          await _saveFileToDevice(
              cached.file, orig.isNotEmpty ? orig : p.basename(url));
          return;
        }
        final localPath = mediaFilePathRegistry[authUrl];
        if (localPath == null) {
          rootScreenKey.currentState?.showSnack('Media not loaded yet');
          return;
        }
        await _saveFileToDevice(
            File(localPath), orig.isNotEmpty ? orig : p.basename(localPath));
        return;
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  Future<void> _saveFileToDevice(File file, String originalName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final ext = p.extension(originalName).toLowerCase();
        final isImage = [
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
          '.heic'
        ].contains(ext);
        final isVideo =
            ['.mp4', '.mov', '.avi', '.webm', '.m4v', '.mkv'].contains(ext);
        if (isImage) {
          final saved =
              await GallerySaver.saveImage(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(
              saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        } else if (isVideo) {
          final saved =
              await GallerySaver.saveVideo(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(
              saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        } else {
          final dl = await getDownloadsDirectory();
          if (dl == null) {
            rootScreenKey.currentState
                ?.showSnack('Cannot access Downloads directory');
            return;
          }
          final onyxDir = Directory('${dl.path}/ONYX');
          await onyxDir.create(recursive: true);
          final destPath = '${onyxDir.path}/$originalName';
          await file.copy(destPath);
          rootScreenKey.currentState?.showSnack('Saved to: $destPath');
        }
        return;
      }
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final ext = p.extension(originalName).replaceFirst('.', '');
        String? destPath;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save as',
            fileName: originalName,
            type: FileType.custom,
            allowedExtensions: ext.isNotEmpty ? [ext] : ['bin'],
          );
        } catch (_) {
          final dirPath = await FilePicker.platform
              .getDirectoryPath(dialogTitle: 'Choose folder to save');
          if (dirPath == null) {
            rootScreenKey.currentState?.showSnack('Save cancelled');
            return;
          }
          destPath = p.join(dirPath, originalName);
        }
        if (destPath == null || destPath.isEmpty) {
          rootScreenKey.currentState?.showSnack('Save cancelled');
          return;
        }
        await file.copy(destPath);
        rootScreenKey.currentState?.showSnack('Saved to: $destPath');
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  List<ContextMenuButtonItem> _buildExternalDesktopMenuItems(
      Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    final rawSender = msg['sender']?.toString() ?? '';
    final isImage = content.startsWith('IMAGEv1:');
    final isAlbum = content.startsWith('ALBUMv1:');
    final isVideo = content.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = content.startsWith('VOICEv1:');
    final isFile = content.startsWith('FILEv1:') || content.startsWith('FILE:');

    bool isProxyImage = false;
    bool isProxySaveable = false;
    if (content.toUpperCase().startsWith('MEDIA_PROXYV1:')) {
      try {
        final data = jsonDecode(content.substring('MEDIA_PROXYv1:'.length))
            as Map<String, dynamic>;
        final url = (data['url'] as String?)?.trim() ?? '';
        final orig = (data['orig'] as String? ?? '').toLowerCase();
        final type = data['type'] as String?;
        if (type == 'album') {
          isProxySaveable = true;
        } else if (url.isNotEmpty) {
          isProxySaveable = true;
          if (type == 'image') {
            isProxyImage = true;
          } else if (type == null || type.isEmpty) {
            final lower = url.toLowerCase();
            isProxyImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
                    .any(orig.endsWith) ||
                ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any(lower.endsWith);
          }
        }
      } catch (_) {}
    }

    final isSaveable =
        isImage || isAlbum || isVideo || isVoice || isFile || isProxySaveable;
    final isMedia = isSaveable ||
        content.toUpperCase().startsWith('MEDIA_PROXYV1:') ||
        (content.startsWith('http') &&
            (content.contains('/uploads/') ||
                content.contains('file.io') ||
                content.contains('cdn.')));
    return [
      ContextMenuButtonItem(
        label: 'Reply',
        onPressed: () => _startReply({
          'id': msg['id']?.toString(),
          'sender': rawSender,
          'content': content,
        }),
      ),
      ContextMenuButtonItem(
        label: 'React',
        onPressed: () {
          final extMsgId = msg['id']?.toString() ?? '';
          final msgIdInt = int.tryParse(extMsgId);
          openEmojiPicker(context, 'ext_$extMsgId', widget.server.username,
              onAfterToggle: (emoji, wasReacted) {
            if (msgIdInt != null) {
              _serverToggleReaction(msgIdInt, emoji, wasReacted);
            }
          });
        },
      ),
      if (isSaveable)
        ContextMenuButtonItem(
          label: 'Save',
          onPressed: () => _saveMediaFromMessage(content),
        ),
      if (isImage || isProxyImage)
        ContextMenuButtonItem(
          label: 'Copy Image',
          onPressed: isImage
              ? () => copyMessageImageToClipboard(
                  content, (m) => rootScreenKey.currentState?.showSnack(m))
              : () => _copyExternalProxyImage(content),
        ),
      if (!isMedia)
        ContextMenuButtonItem(
          label: 'Copy',
          type: ContextMenuButtonType.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            rootScreenKey.currentState?.showSnack(
                AppLocalizations(SettingsManager.appLocale.value).msgCopied);
          },
        ),
      if (isFile)
        ContextMenuButtonItem(
          label: 'Show in file system',
          onPressed: () {
            String filename = '';
            try {
              if (content.startsWith('FILEv1:')) {
                final meta = jsonDecode(content.substring('FILEv1:'.length))
                    as Map<String, dynamic>;
                filename = meta['filename'] as String? ?? '';
              } else {
                filename = content.substring('FILE:'.length).trim();
              }
            } catch (_) {}
            final localPath =
                filename.isNotEmpty ? mediaFilePathRegistry[filename] : null;
            if (localPath == null) {
              rootScreenKey.currentState
                  ?.showSnack('File not loaded yet — open it first');
              return;
            }
            revealInFileSystem(localPath);
          },
        ),
    ];
  }

  void _copyExternalProxyImage(String content) {
    try {
      final data = jsonDecode(content.substring('MEDIA_PROXYv1:'.length))
          as Map<String, dynamic>;
      final url = (data['url'] as String?)?.trim() ?? '';
      if (url.isEmpty) return;
      final authUrl = ExternalServerManager.addTokenToUrl(url);
      final cached = imageFileCache[authUrl];
      if (cached == null) {
        rootScreenKey.currentState
            ?.showSnack('Image not loaded yet — open it first');
        return;
      }
      copyFileImageToClipboard(
          cached.file, (m) => rootScreenKey.currentState?.showSnack(m));
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Copy failed: $e');
    }
  }

  bool get _isReadOnlyChannel => !_canPost;

  Future<String?> _uploadToProvider(
      Uint8List bytes, String filename, MediaProvider provider,
      {UploadTask? task}) async {
    try {
      switch (provider) {
        case MediaProvider.catbox:
          final req = http.MultipartRequest(
              'POST', Uri.parse('https://catbox.moe/user/api.php'));
          req.fields['reqtype'] = 'fileupload';
          req.files.add(http.MultipartFile.fromBytes('fileToUpload', bytes,
              filename: filename));
          final client = http.Client();
          if (task != null) task.activeClient = client;
          try {
            final resp = await http.Response.fromStream(await client.send(req));
            if (resp.statusCode == 200) {
              final body = resp.body.trim();
              if (body.startsWith('http')) return body;
            }
            debugPrint(
                '[upload:catbox] status=${resp.statusCode} body=${resp.body.trim()}');
            return null;
          } finally {
            client.close();
            if (task != null) task.activeClient = null;
          }
      }
    } catch (e, st) {
      debugPrint('[upload:${provider.name}] exception: $e\n$st');
      return null;
    }
  }

  bool get _serverHasLocalMedia => widget.server.mediaProvider == 'local';

  Future<String?> _uploadToServer(Uint8List bytes, String filename,
      {UploadTask? task}) async {
    try {
      final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      debugPrint('[ext-media] Uploading $filename, size: $fileSizeMB MB');

      String getCurrentToken() {
        final server = ExternalServerManager.servers.value
            .cast<ExternalServer?>()
            .firstWhere((s) => s?.id == widget.server.id, orElse: () => null);
        return server?.token ?? widget.server.token;
      }

      Future<http.Response> doUpload(String token) async {
        final client = http.Client();
        if (task != null) task.activeClient = client;
        try {
          final uri = Uri.parse('${widget.server.baseUrl}/data/media/upload');
          final req = http.MultipartRequest('POST', uri);
          req.headers['authorization'] = 'Bearer $token';
          req.files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename));

          debugPrint('[ext-media] Sending request to $uri');

          final streamedResponse = await client.send(req).timeout(
            const Duration(minutes: 10),
            onTimeout: () {
              throw TimeoutException('Upload timed out after 10 minutes');
            },
          );

          debugPrint(
              '[ext-media] Got response status: ${streamedResponse.statusCode}');

          final response = await http.Response.fromStream(streamedResponse);
          return response;
        } finally {
          client.close();
          if (task != null) task.activeClient = null;
        }
      }

      var resp = await doUpload(getCurrentToken());

      if (resp.statusCode == 401) {
        debugPrint('[ext-media] got 401, re-authenticating...');
        final newToken =
            await ExternalServerManager.reAuthenticate(widget.server.id);
        if (newToken != null) {
          resp = await doUpload(newToken);
        }
      }
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true) {
          final url = json['url']?.toString() ?? '';
          String fullUrl;
          if (url.startsWith('/')) {
            fullUrl = '${widget.server.baseUrl}$url';
          } else {
            fullUrl = url;
          }
          debugPrint(
              '[ext-media] upload OK, server url=$url -> fullUrl=$fullUrl');
          return fullUrl;
        }
      }
      debugPrint(
          '[ext-media] server upload failed ${resp.statusCode}: ${resp.body}');
      return null;
    } catch (e) {
      debugPrint('[ext-media] server upload error: $e');
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .uploadFailedConnectionAborted);
      }
      return null;
    }
  }

  Future<void> _sendMediaMessage(String content) async {
    if (_isReadOnlyChannel) return;

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final now = DateTime.now();
    final sender = widget.group.isChannel ? _groupName : widget.server.username;

    setState(() {
      _messages.add({
        'id': tempId,
        'sender': sender,
        'content': content,
        'timestamp': now.toIso8601String(),
        'timestamp_ms': now.millisecondsSinceEpoch,
        'isPending': true,
      });
      _allMessageIds.add(tempId);
      _newMessageIds.add(tempId);

      if (_displayedMessageCount < _messages.length) {
        _displayedMessageCount = _messages.length;
      }
    });

    _scrollToBottomAfterSend();

    try {
      final result = await ExternalServerManager.sendMessage(
        widget.server.id,
        widget.group.id,
        content,
      );

      if (result != null && mounted) {
        final serverId = result['message_id']?.toString() ?? '';
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx >= 0) {
            _messages[idx] = {
              ..._messages[idx],
              'id': serverId,
              'isPending': false
            };
            _allMessageIds.add(serverId);
            _pendingMessageIds[tempId] = serverId;
          }
        });
        _saveHistoryToCache(_messages);
      } else if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _allMessageIds.remove(tempId);
        });
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedSendMedia);
      }
    } catch (e) {
      debugPrint('[ext-chat] media send error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _allMessageIds.remove(tempId);
        });
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).sendFailed);
      }
    }
  }

  Future<void> _joinGroup() async {
    try {
      final res = await http.post(
        Uri.parse(
            '${widget.server.baseUrl}/group/join/${widget.group.inviteLink}'),
        headers: {
          'authorization': 'Bearer ${widget.server.token}',
        },
      );
      if (res.statusCode == 200) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).joinedGroup);

          setState(() {
            _myRole = 'member';
          });
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .failedJoinGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).networkError);
      }
    }
  }

  Future<void> _processAndUploadFile(String filePath) async {
    if (_isReadOnlyChannel) return;
    final bytes = await File(filePath).readAsBytes();
    final basename = p.basename(filePath);
    final fileType = FileTypeDetector.getFileType(filePath);

    final uploadType = fileType == 'IMAGE'
        ? 'image'
        : fileType == 'VIDEO'
            ? 'video'
            : fileType == 'AUDIO'
                ? 'voice'
                : 'file';

    // Show pending card immediately
    final task = UploadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: uploadType,
      localPath: filePath,
      basename: basename,
    );
    if (uploadType == 'image') task.previewBytes = bytes;
    task.status = UploadStatus.uploading;
    if (mounted)
      setState(() {
        _pendingUploads.add(task);
      });

    Future<void> doUpload() async {
      String? link;
      String providerName;
      if (_serverHasLocalMedia) {
        link = await _uploadToServer(bytes, basename, task: task);
        providerName = 'server';
      } else {
        const provider = MediaProvider.catbox;
        link = await _uploadToProvider(bytes, basename, provider, task: task);
        providerName = provider.name;
      }

      if (link == null) {
        if (task.status != UploadStatus.paused && mounted) {
          setState(() {
            _pendingUploads.remove(task);
          });
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).uploadFailed);
        }
        return;
      }

      final typeMapping = {
        'IMAGE': 'image',
        'VIDEO': 'video',
        'AUDIO': 'audio',
        'DOCUMENT': 'document',
        'COMPRESS': 'archive',
        'DATA': 'data',
        'FILE': 'file',
      };
      final type = typeMapping[fileType]?.toLowerCase();
      final payload = jsonEncode({
        'url': link,
        'orig': basename,
        'provider': providerName,
        if (type != null) 'type': type,
      });
      debugPrint('[ext-media] sending media: MEDIA_PROXYv1:$payload');
      unawaited(_sendMediaMessage('MEDIA_PROXYv1:$payload'));
      if (mounted)
        setState(() {
          _pendingUploads.remove(task);
        });
    }

    task.onRetry = () async {
      task.status = UploadStatus.uploading;
      if (mounted) setState(() {});
      await doUpload();
    };

    await doUpload();
  }

  void _cancelUpload(UploadTask task) {
    task.status = UploadStatus.failed;
    task.activeClient?.close();
    task.activeClient = null;
    if (mounted)
      setState(() {
        _pendingUploads.remove(task);
      });
  }

  Widget _buildPendingUploadWidget(UploadTask task) {
    return PendingUploadCard(
      task: task,
      showProgress: false, // server/catbox multipart — no byte-level progress
      onCancel: () => _cancelUpload(task),
    );
  }

  Future<void> _pickAndUploadMedia() async {
    if (_isReadOnlyChannel) return;
    if (kIsWeb) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .mediaUploadNotSupportedWeb);
      }
      return;
    }

    List<String>? paths;
    if (Platform.isAndroid || Platform.isIOS) {
      paths = await showMediaPickerSheet(context);
    } else {
      try {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.any, allowMultiple: true);
        paths = result?.files.map((f) => f.path).whereType<String>().toList();
      } catch (e) {
        debugPrint('[Attach] FilePicker error: $e');
        if (mounted) {
          rootScreenKey.currentState?.showSnack('File picker error: $e');
        }
        return;
      }
    }
    if (paths == null || paths.isEmpty) return;

    if (paths.length > 1 && paths.every(FileTypeDetector.isImage)) {
      if (SettingsManager.confirmFileUpload.value) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlbumPreviewDialog(
            filePaths: paths!,
            onSend: () => _processAndUploadAlbum(paths!),
            onCancel: () {},
          ),
        );
        return;
      }
      await _processAndUploadAlbum(paths);
      return;
    }

    final path = paths.first;
    if (!FileTypeDetector.isAllowed(path)) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .unsupportedFileType(p.extension(path)));
      }
      return;
    }
    if (SettingsManager.confirmFileUpload.value) {
      if (!mounted) return;
      final isImage = FileTypeDetector.isImage(path);
      showDialog(
        context: context,
        builder: (_) => FilePreviewDialog(
          filePath: path,
          onSend: () => _processAndUploadFile(path),
          onCancel: () {
            rootScreenKey.currentState?.showSnack(
                AppLocalizations(SettingsManager.appLocale.value).cancelled);
          },
          onPasteExtra: isImage ? _pasteImageForAlbum : null,
          onSendAlbum: isImage ? (ps) => _processAndUploadAlbum(ps) : null,
        ),
      );
      return;
    }
    await _processAndUploadFile(path);
  }

  Future<void> _processAndUploadAlbum(List<String> filePaths) async {
    if (_isReadOnlyChannel) return;
    final limited = filePaths.take(10).toList();
    if (limited.isEmpty) return;

    final items = <Map<String, String>>[];

    if (_serverHasLocalMedia) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .uploadingImages(limited.length));
      }
      for (final filePath in limited) {
        final basename = p.basename(filePath);
        final bytes = await File(filePath).readAsBytes();
        final link = await _uploadToServer(bytes, basename);
        if (link == null) {
          debugPrint('[ext-album] server upload failed for $basename');
          continue;
        }
        items.add({'url': link, 'orig': basename, 'provider': 'server'});
      }
    } else {
      const provider = MediaProvider.catbox;
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .uploadingImages(limited.length));
      }
      for (final filePath in limited) {
        final basename = p.basename(filePath);
        final bytes = await File(filePath).readAsBytes();
        final link = await _uploadToProvider(bytes, basename, provider);
        if (link == null) {
          debugPrint('[ext-album] upload failed for $basename');
          continue;
        }
        items.add({'url': link, 'orig': basename, 'provider': provider.name});
      }
    }

    if (items.isEmpty) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .albumUploadFailed);
      return;
    }

    final payload = jsonEncode({'type': 'album', 'items': items});
    final content = 'MEDIA_PROXYv1:$payload';
    debugPrint('[ext-album] sending album: $content');
    unawaited(_sendMediaMessage(content));
  }

  Future<void> _startRecording() async {
    if (_isReadOnlyChannel) return;
    rootScreenKey.currentState?.startRecording();
  }

  Future<void> _uploadVoiceBytes(Uint8List bytes) async {
    final recordedPath = rootScreenKey.currentState?.lastRecordedPathForUpload;
    final ext = recordedPath != null ? p.extension(recordedPath) : '.wav';
    final basename = 'voice_${DateTime.now().millisecondsSinceEpoch}$ext';

    final task = UploadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: 'voice',
      localPath: recordedPath ?? '',
      basename: basename,
    );
    task.status = UploadStatus.uploading;
    if (mounted) setState(() => _pendingUploads.add(task));

    String? link;
    String providerName;

    if (_serverHasLocalMedia) {
      link = await _uploadToServer(bytes, basename, task: task);
      providerName = 'server';
    } else {
      const provider = MediaProvider.catbox;
      link = await _uploadToProvider(bytes, basename, provider, task: task);
      providerName = provider.name;
    }

    if (mounted) setState(() => _pendingUploads.remove(task));

    if (link == null) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .voiceUploadFailed);
      }
      return;
    }
    final payload = jsonEncode({
      'url': link,
      'orig': basename,
      'provider': providerName,
      'type': 'voice',
    });
    unawaited(_sendMediaMessage('MEDIA_PROXYv1:$payload'));
  }

  Future<void> _stopRecordingAndUpload() async {
    if (_isReadOnlyChannel) return;

    await rootScreenKey.currentState?.stopRecordingOnly();

    final path = rootScreenKey.currentState?.lastRecordedPathForUpload;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();

    if (SettingsManager.confirmVoiceUpload.value) {
      final durationSeconds = (bytes.length / 16000).ceil();
      final duration = Duration(seconds: durationSeconds);

      if (mounted) {
        await showDialog<bool>(
              context: context,
              builder: (_) => VoiceConfirmDialog(
                duration: duration,
                onSend: () async {
                  await _uploadVoiceBytes(bytes);
                },
                onCancel: () {
                  if (mounted) {
                    rootScreenKey.currentState?.showSnack(
                        AppLocalizations(SettingsManager.appLocale.value)
                            .voiceCancelled);
                  }
                },
              ),
            ) ??
            false;
      }
    } else {
      await _uploadVoiceBytes(bytes);
    }
  }

  Future<void> _handleDroppedFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    final existing = <String>[];
    for (final fp in filePaths) {
      if (await File(fp).exists()) {
        existing.add(fp);
      } else {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
      }
    }
    if (existing.isEmpty) return;

    if (existing.length > 1 && existing.every(FileTypeDetector.isImage)) {
      if (SettingsManager.confirmFileUpload.value) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlbumPreviewDialog(
            filePaths: existing,
            onSend: () => _processAndUploadAlbum(existing),
            onCancel: () {},
          ),
        );
        return;
      }
      await _processAndUploadAlbum(existing);
      return;
    }

    for (final filePath in existing) {
      if (SettingsManager.confirmFileUpload.value) {
        final isImage = FileTypeDetector.isImage(filePath);
        showDialog(
          context: context,
          builder: (_) => FilePreviewDialog(
            filePath: filePath,
            onSend: () => _processAndUploadFile(filePath),
            onCancel: () {
              rootScreenKey.currentState?.showSnack(
                  AppLocalizations(SettingsManager.appLocale.value)
                      .fileCancelled);
            },
            onPasteExtra: isImage ? _pasteImageForAlbum : null,
            onSendAlbum: isImage ? (ps) => _processAndUploadAlbum(ps) : null,
          ),
        );
      } else {
        _processAndUploadFile(filePath);
      }
    }
  }

  static const _clipboardChannel = MethodChannel('onyx/clipboard');

  Future<String?> _pasteImageForAlbum() async {
    try {
      List<Object?>? rawPaths;
      try {
        rawPaths = await _clipboardChannel
            .invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (_) {}
      final filePaths =
          rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        final imgPath =
            filePaths.firstWhere(FileTypeDetector.isImage, orElse: () => '');
        if (imgPath.isNotEmpty) return imgPath;
      }
      Uint8List? imageBytes;
      try {
        imageBytes = await _clipboardChannel
            .invokeMethod<Uint8List>('getClipboardImage');
      } catch (_) {}
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(imageBytes);
        return tempFile.path;
      }
    } catch (e) {
      debugPrint('[clipboard album paste] $e');
    }
    return null;
  }

  Future<void> _handlePasteFromClipboard() async {
    try {
      List<Object?>? rawPaths;
      try {
        rawPaths = await _clipboardChannel
            .invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (e) {
        debugPrint('[err] $e');
      }
      final filePaths =
          rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        debugPrint('[clipboard] File paths from clipboard: $filePaths');
        _handleDroppedFiles(filePaths);
        return;
      }

      Uint8List? imageBytes;
      try {
        imageBytes = await _clipboardChannel
            .invokeMethod<Uint8List>('getClipboardImage');
      } catch (e) {
        debugPrint('[err] $e');
      }
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(imageBytes);
        debugPrint(
            '[clipboard] Image pasted from native clipboard: ${tempFile.path}');
        _handleDroppedFiles([tempFile.path]);
        return;
      }

      final data = await Clipboard.getData('text/plain');
      if (data == null || data.text == null) {
        debugPrint('[clipboard] No content in clipboard');
        return;
      }
      final text = data.text!.trim();
      final uri = Uri.tryParse(text);
      if (uri != null && uri.scheme == 'file') {
        final filePath = uri.toFilePath();
        if (await File(filePath).exists()) {
          debugPrint('[clipboard] File URI pasted: $filePath');
          if (!mounted) return;

          if (SettingsManager.confirmFileUpload.value) {
            final isImage = FileTypeDetector.isImage(filePath);
            showDialog(
              context: context,
              builder: (_) => FilePreviewDialog(
                filePath: filePath,
                onSend: () => _processAndUploadFile(filePath),
                onCancel: () {
                  rootScreenKey.currentState?.showSnack(
                      AppLocalizations(SettingsManager.appLocale.value)
                          .fileCancelled);
                },
                onPasteExtra: isImage ? _pasteImageForAlbum : null,
                onSendAlbum:
                    isImage ? (ps) => _processAndUploadAlbum(ps) : null,
              ),
            );
          } else {
            _processAndUploadFile(filePath);
          }
          return;
        }
      }

      debugPrint('[clipboard] No supported format found in clipboard');
    } catch (e, stackTrace) {
      debugPrint('[clipboard] Error pasting from clipboard: $e');
      debugPrint('[clipboard] Stack trace: $stackTrace');
    }
  }

  Widget _buildInputBar(BuildContext context, ColorScheme colorScheme) {
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementOpacity,
      builder: (_, opacity, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _editingMsgId != null
                  ? ValueListenableBuilder<double>(
                      valueListenable: SettingsManager.elementBrightness,
                      builder: (_, brightness, ___) {
                        final baseColor = SettingsManager.getElementColor(
                          colorScheme.surfaceContainerHighest,
                          brightness,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.edit,
                                  size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Edit message',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _editingOriginalContent ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _cancelEditingExtMessage,
                                visualDensity: VisualDensity.compact,
                                splashRadius: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _replyingToMessage != null
                  ? ValueListenableBuilder<double>(
                      valueListenable: SettingsManager.elementBrightness,
                      builder: (_, brightness, ___) {
                        final baseColor = SettingsManager.getElementColor(
                          colorScheme.surfaceContainerHighest,
                          brightness,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: opacity),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _replyingToMessage!['senderDisplayName']
                                              ?.toString() ??
                                          _replyingToMessage!['sender']
                                              ?.toString() ??
                                          'Unknown',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      getPreviewText(
                                        (_replyingToMessage!['content'] ?? '')
                                            .toString(),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: _cancelReplying,
                                visualDensity: VisualDensity.compact,
                                splashRadius: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            ValueListenableBuilder<double>(
              valueListenable: SettingsManager.elementBrightness,
              builder: (_, brightness, ___) {
                final baseColor = SettingsManager.getElementColor(
                  colorScheme.surfaceContainerHighest,
                  brightness,
                );
                return Container(
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ValueListenableBuilder<bool>(
                        valueListenable: recordingNotifier,
                        builder: (context, isRecording, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: isRecording ? 1.0 : 0.0,
                                child: isRecording
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6.0),
                                        child: Material(
                                          shape: const CircleBorder(),
                                          color: colorScheme.errorContainer,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color:
                                                  colorScheme.onErrorContainer,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              rootScreenKey.currentState
                                                  ?.cancelRecording();
                                            },
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            splashRadius: 20,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Material(
                                shape: const CircleBorder(),
                                color: isRecording
                                    ? colorScheme.error.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                child: IconButton(
                                  icon: Icon(
                                    isRecording ? Icons.stop : Icons.mic,
                                    color: isRecording
                                        ? colorScheme.error
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    if (isRecording) {
                                      _stopRecordingAndUpload();
                                    } else {
                                      _startRecording();
                                    }
                                  },
                                  visualDensity: VisualDensity.compact,
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          );
                        },
                        ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: IconButton(
                            icon: Icon(
                              Icons.attach_file,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 20,
                            ),
                            onPressed: _pickAndUploadMedia,
                            visualDensity: VisualDensity.compact,
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      Expanded(
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (event) {
                            if (event is KeyDownEvent) {
                              if (HardwareKeyboard.instance.isLogicalKeyPressed(
                                      LogicalKeyboardKey.keyV) &&
                                  (HardwareKeyboard.instance.isControlPressed ||
                                      HardwareKeyboard
                                          .instance.isMetaPressed)) {
                                _handlePasteFromClipboard();
                                return;
                              }

                              if (HardwareKeyboard.instance.isLogicalKeyPressed(
                                  LogicalKeyboardKey.enter)) {
                                if (!HardwareKeyboard.instance.isShiftPressed) {
                                  if (_textCtrl.text.trim().isNotEmpty) {
                                    _sendMessage(_textCtrl.text);
                                  }
                                  return;
                                }
                                if (HardwareKeyboard.instance.isShiftPressed &&
                                    _textCtrl.text.isNotEmpty) {
                                  final text = _textCtrl.text;
                                  final selection = _textCtrl.selection;
                                  _textCtrl.text =
                                      '${text.substring(0, selection.start)}\n${text.substring(selection.start)}';
                                  _textCtrl.selection =
                                      TextSelection.fromPosition(TextPosition(
                                          offset: selection.start + 1));
                                }
                              }
                            }
                          },
                          child: TextField(
                            focusNode: _focusNode,
                            controller: _textCtrl,
                            onTap: () => _suppressAutoRefocus = false,
                            minLines: 1,
                            maxLines: 5,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)
                                  .localizeHint(_inputHint),
                              hintStyle: TextStyle(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                            ),
                            textInputAction: TextInputAction.none,
                            contentInsertionConfiguration:
                                ContentInsertionConfiguration(
                              allowedMimeTypes: const [
                                'image/png',
                                'image/jpeg',
                                'image/gif',
                                'image/webp',
                              ],
                              onContentInserted: (data) async {
                                try {
                                  Uint8List? bytes = data.data;
                                  if (bytes == null && data.uri.isNotEmpty) {
                                    try {
                                      bytes = await _clipboardChannel
                                          .invokeMethod<Uint8List>(
                                              'readContentUri',
                                              {'uri': data.uri});
                                    } catch (e) {
                                      debugPrint('[err] $e');
                                    }
                                  }
                                  if (bytes != null &&
                                      bytes.isNotEmpty &&
                                      mounted) {
                                    final ext = data.mimeType.contains('/')
                                        ? data.mimeType.split('/').last
                                        : 'png';
                                    final tempDir =
                                        await getTemporaryDirectory();
                                    final tempFile = File(
                                        '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                    await tempFile.writeAsBytes(bytes);
                                    _handleDroppedFiles([tempFile.path]);
                                  }
                                } catch (e) {
                                  debugPrint('[ContentInsert] Error: $e');
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          onPressed: () => _sendMessage(_textCtrl.text),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _groupName);
    Uint8List? newAvatarBytes;
    bool removeAvatar = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: SettingsManager.elementOpacity.value),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(widget.group.isChannel ? 'Edit Channel' : 'Edit Group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (result == null ||
                        result.files.first.bytes == null ||
                        !mounted) {
                      return;
                    }
                    final bytes = result.files.first.bytes!;

                    final croppedBytes =
                        await showAvatarCropScreen(this.context, bytes);
                    if (croppedBytes != null && mounted) {
                      setState(() {
                        newAvatarBytes = croppedBytes;
                        removeAvatar = false;
                      });
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      newAvatarBytes = null;
                      removeAvatar = true;
                    });
                    rootScreenKey.currentState?.showSnack(
                        AppLocalizations(SettingsManager.appLocale.value)
                            .avatarWillBeDeleted);
                  },
                  child: CircleAvatar(
                    key: ValueKey(
                        'edit_avatar_${widget.server.id}_${widget.group.id}_${_groupName}_$_avatarVersion'),
                    radius: 60,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: newAvatarBytes != null
                        ? MemoryImage(newAvatarBytes!)
                        : (!removeAvatar && _avatarVersion > 0
                            ? NetworkImage(
                                '${widget.server.baseUrl}/groups/${widget.group.id}/avatar?v=$_avatarVersion&sid=${widget.server.id}')
                            : null) as ImageProvider?,
                    child: (newAvatarBytes == null &&
                            (removeAvatar || _avatarVersion == 0))
                        ? Icon(Icons.group,
                            size: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to change • Hold to remove',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: '${widget.server.host}:${widget.server.port}'));
                    rootScreenKey.currentState?.showSnack(
                        AppLocalizations(SettingsManager.appLocale.value)
                            .ipCopied);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dns_outlined,
                            size: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.server.host}:${widget.server.port}',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy,
                            size: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText:
                        widget.group.isChannel ? 'Channel name' : 'Group name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    counterText: '',
                  ),
                  maxLength: 64,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  rootScreenKey.currentState?.showSnack(
                      AppLocalizations(SettingsManager.appLocale.value)
                          .nameCannotBeEmpty);
                  return;
                }
                Navigator.pop(context);

                if (newName != _groupName) {
                  await _renameGroup(newName);
                }

                if (newAvatarBytes != null) {
                  await _uploadGroupAvatar(newAvatarBytes!);
                } else if (removeAvatar) {
                  await _deleteGroupAvatar();
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _groupName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: SettingsManager.elementOpacity.value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(AppLocalizations.of(context).renameGroupTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).groupNameLabel,
            border: const OutlineInputBorder(),
          ),
          maxLength: 100,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                rootScreenKey.currentState?.showSnack(
                    AppLocalizations(SettingsManager.appLocale.value)
                        .nameCannotBeEmpty);
                return;
              }
              Navigator.pop(context);
              await _renameGroup(newName);
            },
            child: Text(AppLocalizations.of(context).rename),
          ),
        ],
      ),
    );
  }

  Future<void> _renameGroup(String newName) async {
    try {
      final url = '${widget.server.baseUrl}/groups/${widget.group.id}/rename';
      debugPrint('[rename] POST $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.server.token}',
            },
            body: jsonEncode({'name': newName}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '[rename] Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).groupRenamed);

        if (mounted) {
          setState(() {
            _groupName = newName;
          });
          debugPrint('[rename] Local _groupName updated to: $_groupName');
        } else {
          debugPrint(
              '[rename] WARNING: Widget not mounted, cannot update state');
        }

        final currentGroups = ExternalServerManager.externalGroups.value;
        final updatedGroups = currentGroups.map((g) {
          if (g.id == widget.group.id &&
              g.externalServerId == widget.server.id) {
            return Group(
              id: g.id,
              name: newName,
              isChannel: g.isChannel,
              owner: g.owner,
              inviteLink: g.inviteLink,
              avatarVersion: g.avatarVersion,
              externalServerId: g.externalServerId,
              myRole: g.myRole,
            );
          }
          return g;
        }).toList();
        ExternalServerManager.externalGroups.value = updatedGroups;
        debugPrint('[rename] Updated externalGroups list for Groups tab');
      } else {
        try {
          final error =
              jsonDecode(response.body)['error'] ?? 'Failed to rename';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(response.body));
        }
      }
    } catch (e) {
      debugPrint('[rename] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedRename);
    }
  }

  Future<void> _changeGroupAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedReadFile);
        return;
      }

      if (file.bytes!.length > 5 * 1024 * 1024) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).imageTooLarge);
        return;
      }

      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).uploadingAvatar);

      final url = '${widget.server.baseUrl}/groups/${widget.group.id}/avatar';
      debugPrint('[avatar] POST $url');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer ${widget.server.token}';

      String? contentType;
      final fileName = file.name.toLowerCase();
      if (fileName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        contentType = 'image/jpeg';
      } else if (fileName.endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (fileName.endsWith('.webp')) {
        contentType = 'image/webp';
      } else {
        contentType = 'image/png';
      }

      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        file.bytes!,
        filename: file.name,
        contentType: MediaType.parse(contentType),
      ));

      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      debugPrint(
          '[avatar] Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(responseBody);
          final newVersion = responseData['avatar_version'];
          if (newVersion != null && mounted) {
            setState(() {
              _avatarVersion = newVersion is int
                  ? newVersion
                  : int.tryParse(newVersion.toString()) ?? _avatarVersion + 1;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _avatarVersion++;
            });
          }
        }
        debugPrint('[avatar] Local _avatarVersion updated to: $_avatarVersion');
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .avatarUpdatedSuccessfully);
      } else {
        try {
          final error = jsonDecode(responseBody)['error'] ?? 'Failed to upload';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(responseBody));
        }
      }
    } catch (e) {
      debugPrint('[avatar] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedUploadAvatar);
    }
  }

  Future<void> _uploadGroupAvatar(Uint8List bytes) async {
    try {
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).uploadingAvatar);

      final url = '${widget.server.baseUrl}/groups/${widget.group.id}/avatar';
      debugPrint('[avatar] POST $url');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer ${widget.server.token}';

      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: 'avatar.jpg',
        contentType: MediaType.parse('image/jpeg'),
      ));

      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      debugPrint(
          '[avatar] Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(responseBody);
          final newVersion = responseData['avatar_version'];
          if (newVersion != null && mounted) {
            setState(() {
              _avatarVersion = newVersion is int
                  ? newVersion
                  : int.tryParse(newVersion.toString()) ?? _avatarVersion + 1;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _avatarVersion++;
            });
          }
        }
        debugPrint('[avatar] Local _avatarVersion updated to: $_avatarVersion');
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .avatarUpdatedSuccessfully);

        final currentGroups = ExternalServerManager.externalGroups.value;
        final updatedGroups = currentGroups.map((g) {
          if (g.id == widget.group.id &&
              g.externalServerId == widget.server.id) {
            return Group(
              id: g.id,
              name: g.name,
              isChannel: g.isChannel,
              owner: g.owner,
              inviteLink: g.inviteLink,
              avatarVersion: _avatarVersion,
              externalServerId: g.externalServerId,
              myRole: g.myRole,
            );
          }
          return g;
        }).toList();
        ExternalServerManager.externalGroups.value = updatedGroups;
        debugPrint('[avatar] Updated externalGroups list for Groups tab');
      } else {
        try {
          final error = jsonDecode(responseBody)['error'] ?? 'Failed to upload';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(responseBody));
        }
      }
    } catch (e) {
      debugPrint('[avatar] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedUploadAvatar);
    }
  }

  Future<void> _deleteGroupAvatar() async {
    try {
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).deletingAvatar);

      final url = '${widget.server.baseUrl}/groups/${widget.group.id}/avatar';
      debugPrint('[avatar] DELETE $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.server.token}',
        },
      ).timeout(const Duration(seconds: 30));

      debugPrint(
          '[avatar] Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          final newVersion = responseData['avatar_version'];
          if (newVersion != null && mounted) {
            setState(() {
              _avatarVersion = newVersion is int
                  ? newVersion
                  : int.tryParse(newVersion.toString()) ?? _avatarVersion + 1;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _avatarVersion++;
            });
          }
        }
        debugPrint(
            '[avatar] Local _avatarVersion updated to: $_avatarVersion (deleted)');
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .avatarDeletedSuccessfully);

        final currentGroups = ExternalServerManager.externalGroups.value;
        final updatedGroups = currentGroups.map((g) {
          if (g.id == widget.group.id &&
              g.externalServerId == widget.server.id) {
            return Group(
              id: g.id,
              name: g.name,
              isChannel: g.isChannel,
              owner: g.owner,
              inviteLink: g.inviteLink,
              avatarVersion: _avatarVersion,
              externalServerId: g.externalServerId,
              myRole: g.myRole,
            );
          }
          return g;
        }).toList();
        ExternalServerManager.externalGroups.value = updatedGroups;
        debugPrint(
            '[avatar] Updated externalGroups list for Groups tab (deleted)');
      } else {
        try {
          final error =
              jsonDecode(response.body)['error'] ?? 'Failed to delete';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(response.body));
        }
      }
    } catch (e) {
      debugPrint('[avatar] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedDeleteAvatar);
    }
  }

  void _showMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => _MembersManagementDialog(
        server: widget.server,
        group: widget.group,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: colorScheme.surface,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: false,
                leading: isDesktop
                    ? null
                    : ValueListenableBuilder(
                        valueListenable: _selectionNotifier,
                        builder: (_, sel, __) => sel.active
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _exitExtSelectionMode,
                              )
                            : const BackButton(),
                      ),
                flexibleSpace: ValueListenableBuilder<double>(
                  valueListenable: SettingsManager.elementOpacity,
                  builder: (_, opacity, __) {
                    return ClipRect(
                      child: Container(
                        color: colorScheme.surface.withValues(alpha: opacity),
                      ),
                    );
                  },
                ),
                title: ValueListenableBuilder(
                  valueListenable: _selectionNotifier,
                  builder: (_, sel, __) => sel.active
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDesktop)
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _exitExtSelectionMode,
                              ),
                            Text(
                              '${sel.selected.length} selected',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: _showEditProfileDialog,
                          child: Row(
                            children: [
                              CircleAvatar(
                                key: ValueKey(
                                    'avatar_${widget.server.id}_${widget.group.id}_${_groupName}_$_avatarVersion'),
                                radius: 20,
                                backgroundColor: colorScheme.primaryContainer,
                                backgroundImage: _avatarVersion > 0
                                    ? NetworkImage(
                                        '${widget.server.baseUrl}/groups/${widget.group.id}/avatar?v=$_avatarVersion&sid=${widget.server.id}',
                                      )
                                    : null,
                                child: _avatarVersion == 0
                                    ? Icon(Icons.dns_outlined,
                                        size: 20,
                                        color: colorScheme.onPrimaryContainer)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _groupName,
                                            key: ValueKey(
                                                'group_name_$_groupName'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _isConnected
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${widget.server.host}:${widget.server.port}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                actions: [
                  ValueListenableBuilder(
                    valueListenable: _selectionNotifier,
                    builder: (_, sel, __) => sel.active
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel.selected.values.any(_isExtTextMessage))
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded),
                                  tooltip: 'Copy',
                                  onPressed: _copySelectedExtMessages,
                                ),
                              if (sel.selected.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.forward_rounded),
                                  tooltip: 'Forward',
                                  onPressed: _forwardSelectedExtMessages,
                                ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.headset_mic_rounded),
                                tooltip: 'Voice channels',
                                onPressed: () => showVoiceChannelPopup(
                                    context, widget.server.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.search),
                                tooltip: 'Search (Ctrl+F)',
                                onPressed: () {
                                  if (_showSearch) {
                                    _closeSearch();
                                  } else {
                                    _openSearch();
                                  }
                                },
                              ),
                              if (_myRole == null)
                                FilledButton.tonal(
                                  onPressed: _joinGroup,
                                  child:
                                      Text(AppLocalizations.of(context).join),
                                ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert,
                                    color: colorScheme.onSurface),
                                onSelected: (value) async {
                                  if (value == 'disconnect') {
                                    ExternalServerManager.disconnectWebSocket(
                                        widget.server.id);
                                    if (mounted) {
                                      setState(() {
                                        _isConnected = false;
                                        _isConnecting = false;
                                      });
                                    }
                                  } else if (value == 'edit_profile') {
                                    _showEditProfileDialog();
                                  } else if (value == 'members') {
                                    _showMembersDialog();
                                  }
                                },
                                itemBuilder: (context) {
                                  final isOwner = _myRole == 'owner';
                                  return [
                                    if (isOwner) ...[
                                      PopupMenuItem<String>(
                                        value: 'edit_profile',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit,
                                                size: 18,
                                                color: colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Text(AppLocalizations.of(context)
                                                .editProfile),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'members',
                                        child: Row(
                                          children: [
                                            Icon(Icons.people,
                                                size: 18,
                                                color: colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Text(AppLocalizations.of(context)
                                                .manageMembers),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                    ],
                                    PopupMenuItem<String>(
                                      value: 'disconnect',
                                      enabled: _isConnected,
                                      child: Row(
                                        children: [
                                          Icon(Icons.power_settings_new,
                                              size: 18,
                                              color: _isConnected
                                                  ? colorScheme.error
                                                  : colorScheme.onSurface
                                                      .withValues(alpha: 0.3)),
                                          const SizedBox(width: 8),
                                          Text(_isConnected
                                              ? 'Disconnect'
                                              : 'Not connected'),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                  ),
                ],
              ),
              body: DragDropZone(
                onFilesDropped: _handleDroppedFiles,
                enabled: !_isReadOnlyChannel && _isConnected,
                child: Stack(
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: SettingsManager.chatBackground,
                      builder: (_, path, __) {
                        if (path == null) return const SizedBox.shrink();
                        final f = File(path);
                        return ValueListenableBuilder<bool>(
                          valueListenable: SettingsManager.blurBackground,
                          builder: (_, blur, __) {
                            return ValueListenableBuilder<double>(
                              valueListenable: SettingsManager.blurSigma,
                              builder: (_, sigma, __) {
                                final image = Image.file(
                                  f,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                );
                                return ValueListenableBuilder<bool>(
                                  valueListenable: SettingsManager
                                      .enablePerformanceOptimizations,
                                  builder: (_, perfOptim, __) {
                                    final child = (blur && !perfOptim)
                                        ? ImageFiltered(
                                            imageFilter: ui.ImageFilter.blur(
                                                sigmaX: sigma, sigmaY: sigma),
                                            child: image,
                                          )
                                        : image;
                                    return Positioned.fill(
                                      child: IgnorePointer(
                                        child: Opacity(
                                            opacity: 0.95, child: child),
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
                    Builder(
                      builder: (context) {
                        final swapped =
                            SettingsManager.swapMessageAlignment.value;
                        final alignRight =
                            SettingsManager.alignAllMessagesRight.value;

                        // Compute search matches (indices into display items)
                        final displayItems = _rebuildExtDisplayItems();
                        if (_showSearch && _searchQuery.isNotEmpty) {
                          final newMatches = <int>[];
                          for (int j = 0; j < displayItems.length; j++) {
                            final item = displayItems[j];
                            if (item is Map<String, dynamic>) {
                              final c = item['content']?.toString() ?? '';
                              if (c.toLowerCase().contains(_searchQuery)) {
                                newMatches.add(j);
                              }
                            }
                          }
                          newMatches.sort();
                          _cachedSearchMatches = newMatches;
                          final clampedIdx = newMatches.isEmpty
                              ? 0
                              : _currentMatchIdx.clamp(
                                  0, newMatches.length - 1);
                          final stats = (
                            current: newMatches.isEmpty ? 0 : clampedIdx + 1,
                            total: newMatches.length,
                          );
                          if (_searchStats.value != stats) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _searchStats.value = stats;
                            });
                          }
                        } else {
                          _cachedSearchMatches = [];
                          if (_searchStats.value.total != 0) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted)
                                _searchStats.value = (current: 0, total: 0);
                            });
                          }
                        }

                        return Listener(
                          onPointerDown: (_) {
                            if (!isDesktop) return;
                            _suppressAutoRefocus = true;
                            _focusNode.unfocus();
                          },
                          child: ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            itemCount:
                                _pendingUploads.length + displayItems.length,
                            cacheExtent: 400,
                            addRepaintBoundaries: true,
                            addAutomaticKeepAlives: true,
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top +
                                  kToolbarHeight +
                                  (_showSearch ? 64 : 12),
                              bottom:
                                  72 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemBuilder: (ctx, i) {
                              if (i < _pendingUploads.length) {
                                final task = _pendingUploads[
                                    _pendingUploads.length - 1 - i];
                                return _buildPendingUploadWidget(task);
                              }
                              final adjustedI = i - _pendingUploads.length;
                              final item = displayItems[adjustedI];

                              if (item is DateTime) {
                                return _buildExtDaySeparator(ctx, item);
                              }

                              final msg = item as Map<String, dynamic>;
                              final rawSender =
                                  msg['sender']?.toString() ?? '?';

                              final isMe = widget.group.isChannel
                                  ? false
                                  : (rawSender == widget.server.username);
                              final content = msg['content']?.toString() ?? '';
                              final isSearchMatch = _searchQuery.isNotEmpty &&
                                  content.toLowerCase().contains(_searchQuery);
                              final isCurrentSearchMatch = isSearchMatch &&
                                  _cachedSearchMatches.isNotEmpty &&
                                  _cachedSearchMatches[_currentMatchIdx] ==
                                      adjustedI;

                              final bubble = Container(
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.7),
                                child: GestureDetector(
                                  onHorizontalDragEnd: isDesktop
                                      ? null
                                      : (details) {
                                          final v = details.primaryVelocity;
                                          if (v != null && v > 300) {
                                            HapticFeedback.selectionClick();
                                            _showExternalMessageMenu(msg);
                                          } else if (v != null && v < -300) {
                                            _startReply({
                                              'id': msg['id']?.toString(),
                                              'sender': rawSender,
                                              'content': content,
                                            });
                                            HapticFeedback.selectionClick();
                                          }
                                        },
                                  child: MessageBubble(
                                    key: ValueKey<String>(
                                        'mb_${msg['timestamp']}_${rawSender}_${content.hashCode}'),
                                    text: content,
                                    outgoing: isMe,
                                    rawPreview: null,
                                    serverMessageId: null,
                                    time: (msg['timestamp_ms'] != null &&
                                            msg['timestamp_ms'] is int &&
                                            (msg['timestamp_ms'] as int) > 0)
                                        ? DateTime.fromMillisecondsSinceEpoch(
                                            msg['timestamp_ms'] as int)
                                        : (DateTime.tryParse(
                                                msg['timestamp']?.toString() ??
                                                    '') ??
                                            DateTime.now()),
                                    onRequestResend: (_) {},
                                    desktopMenuItems: isDesktop
                                        ? _buildExternalDesktopMenuItems(msg)
                                        : null,
                                    peerUsername: rawSender,
                                    replyToId: msg['reply_to_id'] is int
                                        ? msg['reply_to_id'] as int
                                        : (msg['reply_to_id'] != null
                                            ? int.tryParse(
                                                msg['reply_to_id'].toString())
                                            : null),
                                    replyToUsername:
                                        msg['reply_to_sender']?.toString(),
                                    replyToContent:
                                        msg['reply_to_content']?.toString(),
                                    highlighted: (_replyingToMessage != null &&
                                        _replyingToMessage!['id']?.toString() ==
                                            msg['id']?.toString()),
                                    onReplyTap: msg['reply_to_id'] != null
                                        ? () => _scrollToExtMessageById(
                                            msg['reply_to_id'].toString())
                                        : null,
                                  ),
                                ),
                              );

                              final shouldAlignRight = alignRight
                                  ? !swapped
                                  : (swapped ? !isMe : isMe);

                              Widget contentWithSender;
                              if (!isMe) {
                                contentWithSender = Column(
                                  crossAxisAlignment: shouldAlignRight
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4.0),
                                      child: Text(
                                        rawSender,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    bubble,
                                  ],
                                );
                              } else {
                                contentWithSender = bubble;
                              }

                              final msgId = msg['id']?.toString() ?? '';
                              final timestamp =
                                  msg['timestamp']?.toString() ?? '';
                              final uniqueKey =
                                  '${msgId}_${timestamp}_${rawSender}_${content.hashCode}';
                              final animKey =
                                  msg['animationId']?.toString() ?? msgId;

                              final bool isFirstAppearance =
                                  !_alreadyRenderedMessageIds.contains(animKey);
                              if (isFirstAppearance) {
                                _alreadyRenderedMessageIds.add(animKey);
                              }

                              final animatedBubble = AnimatedMessageBubble(
                                key: ValueKey<String>(animKey),
                                outgoing: isMe,
                                animate: isFirstAppearance &&
                                    SettingsManager.messageAnimationsEnabled.value,
                                child: RepaintBoundary(
                                    child: contentWithSender),
                              );

                              final expensiveChild = Align(
                                alignment: shouldAlignRight
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: shouldAlignRight
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    animatedBubble,
                                    MessageReactionBar(
                                      reactions: reactionsFor('ext_$msgId'),
                                      myUsername: widget.server.username,
                                      outgoing: isMe,
                                      onToggle: (emoji) {
                                        final msgIdInt = int.tryParse(msgId);
                                        final wasReacted = hasReaction('ext_$msgId', emoji, widget.server.username);
                                        toggleReaction('ext_$msgId', emoji, widget.server.username);
                                        if (msgIdInt != null) _serverToggleReaction(msgIdInt, emoji, wasReacted);
                                      },
                                      onAddReaction: (ctx2) {
                                        final msgIdInt = int.tryParse(msgId);
                                        openEmojiPicker(ctx2, 'ext_$msgId', widget.server.username,
                                            onAfterToggle: (emoji, wasReacted) {
                                          if (msgIdInt != null) _serverToggleReaction(msgIdInt, emoji, wasReacted);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );

                              return ValueListenableBuilder<
                                  ({
                                    bool active,
                                    Map<String, Map<String, dynamic>> selected
                                  })>(
                                valueListenable: _selectionNotifier,
                                child: expensiveChild,
                                builder: (_, sel, contentChild) {
                                  final isExtSelected =
                                      sel.selected.containsKey(uniqueKey);
                                  final ecs = Theme.of(context).colorScheme;
                                  final extCheckmark = GestureDetector(
                                    onTap: () =>
                                        _toggleExtMsgSelection(msg, uniqueKey),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isExtSelected
                                              ? ecs.primary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isExtSelected
                                                ? ecs.primary
                                                : ecs.onSurface
                                                    .withValues(alpha: 0.35),
                                            width: 2,
                                          ),
                                        ),
                                        child: isExtSelected
                                            ? Icon(Icons.check,
                                                size: 14, color: ecs.onPrimary)
                                            : null,
                                      ),
                                    ),
                                  );

                                  return RawGestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    gestures: {
                                      LongPressGestureRecognizer:
                                          GestureRecognizerFactoryWithHandlers<
                                              LongPressGestureRecognizer>(
                                        () => LongPressGestureRecognizer(
                                            duration: const Duration(
                                                milliseconds: 250)),
                                        (instance) {
                                          instance.onLongPress = sel.active
                                              ? () => _toggleExtMsgSelection(
                                                  msg, uniqueKey)
                                              : () => _enterExtSelectionMode(
                                                  msg, uniqueKey);
                                        },
                                      ),
                                    },
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: sel.active
                                          ? () => _toggleExtMsgSelection(
                                              msg, uniqueKey)
                                          : null,
                                      onDoubleTap: sel.active
                                          ? null
                                          : () => _enterExtSelectionMode(
                                              msg, uniqueKey),
                                      child: AnimatedContainer(
                                        key: (_scrollTargetId != null &&
                                                _scrollTargetId ==
                                                    msg['id']?.toString())
                                            ? _scrollTargetKey
                                            : null,
                                        duration:
                                            const Duration(milliseconds: 150),
                                        color: isCurrentSearchMatch
                                            ? ecs.primary
                                                .withValues(alpha: 0.28)
                                            : isSearchMatch
                                                ? ecs.primary
                                                    .withValues(alpha: 0.12)
                                                : isExtSelected
                                                    ? ecs.primaryContainer
                                                        .withValues(alpha: 0.45)
                                                    : (_scrollHighlightId !=
                                                                null &&
                                                            _scrollHighlightId ==
                                                                msg['id']
                                                                    ?.toString())
                                                        ? ecs.primary
                                                            .withValues(
                                                                alpha: 0.18)
                                                        : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        child: Row(
                                          children: [
                                            if (sel.active && !shouldAlignRight)
                                              extCheckmark,
                                            Expanded(child: contentChild!),
                                            if (sel.active && shouldAlignRight)
                                              extCheckmark,
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (_pinnedMessage != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            8,
                        left: 16,
                        right: 16,
                        child: _buildExtPinnedBanner(context),
                      ),
                    if (_showSearch)
                      Positioned(
                        top: MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            (_pinnedMessage != null ? 68.0 : 8.0),
                        left: 16,
                        right: 16,
                        child: ChatSearchBar(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          statsNotifier: _searchStats,
                          onChanged: _onSearchChanged,
                          onPrevious: _navigateSearchPrev,
                          onNext: _navigateSearchNext,
                          onClose: _closeSearch,
                        ),
                      ),
                    Positioned(
                      bottom: 12 + MediaQuery.of(context).padding.bottom,
                      left: 16,
                      right: 16,
                      child: AnimatedBuilder(
                        animation: _inputEntryController,
                        builder: (context, child) {
                          return Transform.scale(
                            scaleX: _inputEntryScaleX.value,
                            alignment: Alignment.center,
                            child: Opacity(
                              opacity: _inputEntryOpacity.value,
                              child: child,
                            ),
                          );
                        },
                        child: Center(
                          child: _isReadOnlyChannel
                              ? ValueListenableBuilder<double>(
                                  valueListenable:
                                      SettingsManager.elementOpacity,
                                  builder: (_, opacity, __) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable:
                                          SettingsManager.inputBarMaxWidth,
                                      builder: (_, width, __) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable:
                                              SettingsManager.elementBrightness,
                                          builder: (_, brightness, ___) {
                                            final baseColor =
                                                SettingsManager.getElementColor(
                                              colorScheme
                                                  .surfaceContainerHighest,
                                              brightness,
                                            );
                                            return Container(
                                              constraints: BoxConstraints(
                                                  maxWidth: width),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16),
                                              decoration: BoxDecoration(
                                                color: baseColor.withValues(
                                                    alpha: opacity),
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                                border: Border.all(
                                                  color: colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.15),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'This is a channel. Only owner and moderators can post.',
                                                style: TextStyle(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 14,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                )
                              : !_isConnected
                                  ? ValueListenableBuilder<double>(
                                      valueListenable:
                                          SettingsManager.elementOpacity,
                                      builder: (_, opacity, __) {
                                        return ValueListenableBuilder<double>(
                                          valueListenable:
                                              SettingsManager.inputBarMaxWidth,
                                          builder: (_, width, __) {
                                            return ValueListenableBuilder<
                                                double>(
                                              valueListenable: SettingsManager
                                                  .elementBrightness,
                                              builder: (_, brightness, ___) {
                                                final baseColor =
                                                    SettingsManager
                                                        .getElementColor(
                                                  colorScheme
                                                      .surfaceContainerHighest,
                                                  brightness,
                                                );
                                                return Container(
                                                  constraints: BoxConstraints(
                                                      maxWidth: width),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: _isConnecting
                                                          ? null
                                                          : _connectToServer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              28),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12,
                                                                horizontal: 16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: baseColor
                                                              .withValues(
                                                                  alpha:
                                                                      opacity),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(28),
                                                          border: Border.all(
                                                            color: colorScheme
                                                                .outlineVariant
                                                                .withValues(
                                                                    alpha:
                                                                        0.15),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            if (_isConnecting)
                                                              SizedBox(
                                                                width: 16,
                                                                height: 16,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: colorScheme
                                                                      .primary,
                                                                ),
                                                              )
                                                            else
                                                              Icon(
                                                                Icons
                                                                    .power_settings_new,
                                                                size: 20,
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                              ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Text(
                                                              _isConnecting
                                                                  ? 'Connecting...'
                                                                  : 'Connect to Server',
                                                              style: TextStyle(
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
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
                                    )
                                  : _isLoadingHistory
                                      ? ValueListenableBuilder<double>(
                                          valueListenable:
                                              SettingsManager.elementOpacity,
                                          builder: (_, opacity, __) {
                                            return ValueListenableBuilder<
                                                double>(
                                              valueListenable: SettingsManager
                                                  .inputBarMaxWidth,
                                              builder: (_, width, __) {
                                                return ValueListenableBuilder<
                                                    double>(
                                                  valueListenable:
                                                      SettingsManager
                                                          .elementBrightness,
                                                  builder:
                                                      (_, brightness, ___) {
                                                    final baseColor =
                                                        SettingsManager
                                                            .getElementColor(
                                                      colorScheme
                                                          .surfaceContainerHighest,
                                                      brightness,
                                                    );
                                                    return Container(
                                                      constraints:
                                                          BoxConstraints(
                                                              maxWidth: width),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12,
                                                          horizontal: 16),
                                                      decoration: BoxDecoration(
                                                        color: baseColor
                                                            .withValues(
                                                                alpha: opacity),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(28),
                                                        border: Border.all(
                                                          color: colorScheme
                                                              .outlineVariant
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: colorScheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Text(
                                                            'Loading messages...',
                                                            style: TextStyle(
                                                              color: colorScheme
                                                                  .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        )
                                      : ValueListenableBuilder<double>(
                                          valueListenable:
                                              SettingsManager.inputBarMaxWidth,
                                          builder: (_, width, __) {
                                            return Container(
                                              constraints: BoxConstraints(
                                                  maxWidth: width),
                                              child: _buildInputBar(
                                                  context, colorScheme),
                                            );
                                          },
                                        ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _showScrollDownButton,
                      builder: (_, show, __) => AnimatedOpacity(
                        opacity: show ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !show,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Material(
                                color: Colors.transparent,
                                child: ValueListenableBuilder<double>(
                                  valueListenable:
                                      SettingsManager.elementBrightness,
                                  builder: (_, brightness, ___) {
                                    final baseColor =
                                        SettingsManager.getElementColor(
                                      colorScheme.surfaceContainerHighest,
                                      brightness,
                                    );
                                    return IconButton(
                                      splashRadius: 20,
                                      padding: EdgeInsets.zero,
                                      icon: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color:
                                              baseColor.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: 18,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                      onPressed: _scrollToBottom,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
  }
}

class _MembersManagementDialog extends StatefulWidget {
  final ExternalServer server;
  final Group group;

  const _MembersManagementDialog({
    required this.server,
    required this.group,
  });

  @override
  State<_MembersManagementDialog> createState() =>
      _MembersManagementDialogState();
}

class _MembersManagementDialogState extends State<_MembersManagementDialog> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final url = '${widget.server.baseUrl}/members';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.server.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _members = List<Map<String, dynamic>>.from(data);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _banMember(String username) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).banMemberTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).banConfirm(username)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).banReason,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).ban),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final url =
          '${widget.server.baseUrl}/members/${Uri.encodeComponent(username)}/ban';
      debugPrint('[ban] POST $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${widget.server.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'reason': reasonController.text.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '[ban] Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .userBanned(username));
        _loadMembers();
      } else {
        try {
          final error = jsonDecode(response.body)['error'] ?? 'Failed to ban';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(response.body));
        }
      }
    } catch (e) {
      debugPrint('[ban] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedBan);
    }
  }

  Future<void> _changeRole(String username, String currentRole) async {
    final ownerCount = _members.where((m) => m['role'] == 'owner').length;
    final canPromoteToOwner = currentRole != 'owner' && ownerCount < 3;
    final canDemoteOwner = currentRole == 'owner' && ownerCount > 1;

    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).changeRoleTitle(username)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppLocalizations.of(context).currentRoleLabel(currentRole),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).ownerCount(ownerCount),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).selectNewRole),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (currentRole == 'owner' && !canDemoteOwner) ||
                      (!canPromoteToOwner && currentRole != 'owner')
                  ? null
                  : () => Navigator.pop(context, 'owner'),
              icon: const Icon(Icons.admin_panel_settings),
              label: Text(currentRole == 'owner'
                  ? AppLocalizations.of(context).ownerCurrent
                  : ownerCount >= 3
                      ? AppLocalizations.of(context).ownerLimitReached
                      : AppLocalizations.of(context).owner),
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, 'moderator'),
              icon: const Icon(Icons.shield),
              label: Text(AppLocalizations.of(context).moderator),
              style: FilledButton.styleFrom(
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'member'),
              icon: const Icon(Icons.person),
              label: Text(AppLocalizations.of(context).memberRole),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
              ),
            ),
            if (currentRole == 'owner' && !canDemoteOwner) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).cannotDemoteLastOwner,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
        ],
      ),
    );

    if (newRole == null || newRole == currentRole) return;

    try {
      final url =
          '${widget.server.baseUrl}/members/${Uri.encodeComponent(username)}/role';
      debugPrint('[role] POST $url with role=$newRole');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${widget.server.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'role': newRole}),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '[role] Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .roleUpdated(newRole));
        _loadMembers();
      } else {
        try {
          final error =
              jsonDecode(response.body)['error'] ?? 'Failed to change role';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(response.body));
        }
      }
    } catch (e) {
      debugPrint('[role] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedChangeRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).manageMembersTitle),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _members.isEmpty
                ? Center(child: Text(AppLocalizations.of(context).noMembersYet))
                : ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final username = member['username'] ?? '';
                      final displayName = member['display_name'] ?? username;
                      final role = member['role'] ?? 'member';
                      final isOwner = role == 'owner';
                      final canModerate = widget.group.myRole == 'owner';

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text('$username • $role'),
                        trailing: !isOwner && canModerate
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.admin_panel_settings,
                                        size: 20),
                                    tooltip:
                                        AppLocalizations.of(context).changeRole,
                                    onPressed: () =>
                                        _changeRole(username, role),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.block,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    tooltip: AppLocalizations.of(context).ban,
                                    onPressed: () => _banMember(username),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
      ),
      actions: [
        if (widget.group.myRole == 'owner' ||
            widget.group.myRole == 'moderator')
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);

              showDialog(
                context: context,
                builder: (context) => _BannedUsersDialog(
                  server: widget.server,
                  group: widget.group,
                ),
              );
            },
            icon: const Icon(Icons.block),
            label: Text(AppLocalizations.of(context).viewBans),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    );
  }
}

class _BannedUsersDialog extends StatefulWidget {
  final ExternalServer server;
  final Group group;

  const _BannedUsersDialog({
    required this.server,
    required this.group,
  });

  @override
  State<_BannedUsersDialog> createState() => _BannedUsersDialogState();
}

class _BannedUsersDialogState extends State<_BannedUsersDialog> {
  List<Map<String, dynamic>> _bans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBans();
  }

  Future<void> _loadBans() async {
    try {
      final url = '${widget.server.baseUrl}/bans';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.server.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _bans = List<Map<String, dynamic>>.from(data);
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unbanUser(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).unbanUserTitle),
        content: Text(AppLocalizations.of(context).unbanConfirm(username)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context).unban),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final url =
          '${widget.server.baseUrl}/members/${Uri.encodeComponent(username)}/unban';
      debugPrint('[unban] POST $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer ${widget.server.token}'},
      ).timeout(const Duration(seconds: 10));

      debugPrint(
          '[unban] Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .userUnbanned(username));
        _loadBans();
      } else {
        try {
          final error = jsonDecode(response.body)['error'] ?? 'Failed to unban';
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(error.toString()));
        } catch (e) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .errorMsg(response.body));
        }
      }
    } catch (e) {
      debugPrint('[unban] Exception: $e');
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).failedUnban);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).bannedUsersTitle),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _bans.isEmpty
                ? Center(
                    child: Text(AppLocalizations.of(context).noBannedUsers))
                : ListView.builder(
                    itemCount: _bans.length,
                    itemBuilder: (context, index) {
                      final ban = _bans[index];
                      final username = ban['username'] ?? '';
                      final bannedBy = ban['banned_by'] ?? 'Unknown';
                      final reason = ban['reason']?.toString();
                      final bannedAt = ban['banned_at'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.block,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        title: Text(username),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)
                                .bannedBy(bannedBy)),
                            if (reason != null && reason.isNotEmpty)
                              Text(
                                  AppLocalizations.of(context)
                                      .bannedReason(reason),
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                            Text(
                                AppLocalizations.of(context)
                                    .bannedDate(_formatDate(bannedAt)),
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          tooltip: AppLocalizations.of(context).unban,
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () => _unbanUser(username),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).close),
        ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }
}
