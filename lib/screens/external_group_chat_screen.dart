// lib/screens/external_group_chat_screen.dart
import '../widgets/marquee_text.dart';
import '../widgets/empty_chat_placeholder.dart';
import '../utils/chat_image_preloader.dart';
import '../utils/gallery_extractor.dart';
import 'media_gallery_screen.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../enums/liquid_glass_quality.dart';
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
import '../widgets/chat_background_layer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxDocumentsDirectory;
import '../models/group.dart';
import '../models/external_server.dart';
import '../managers/external_server_manager.dart';
import '../enums/media_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_images_scope.dart';
import '../widgets/album_message_widget.dart' show AlbumItem;
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../widgets/avatar_crop_screen.dart';
import '../utils/clipboard_image.dart';
import '../utils/file_utils.dart';
import '../globals.dart';
import 'chats_tab.dart' show getPreviewText;
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../utils/image_file_cache.dart';
import '../utils/upload_task.dart';
import '../widgets/upload_progress_bar.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/voice_channel_popup.dart';
import '../voice/voice_channel_manager.dart';
import '../widgets/message_reaction_bar.dart';
import '../widgets/swipeable_message_wrapper.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/adaptive_glass_icon_button.dart';
import '../widgets/measure_size.dart';
import '../enums/scroll_down_button_position.dart';
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
  final GlobalKey _inputAreaKey = GlobalKey();
  late FocusNode _focusNode;
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  // Fingerprint of the message list last handed to the image preloader.
  int _preloadStampCount = -1;
  String _preloadStampLast = '';
  final Set<String> _allMessageIds = {};
  final Map<String, String> _pendingMessageIds = {};
  final List<UploadTask> _pendingUploads = [];
  final ValueNotifier<bool> _showScrollDownButton = ValueNotifier<bool>(false);
  final ValueNotifier<double> _bottomBarHeight = ValueNotifier<double>(76.0);
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
  final GlobalKey _messageListViewportKey = GlobalKey();
  final Map<String, GlobalKey> _messageItemKeys = {};
  List<String> _dragSelectionOrder = const [];
  Map<String, Map<String, dynamic>> _dragSelectionLookup = const {};
  Map<String, int> _dragSelectionIndices = const {};
  bool _isDragSelectingMessages = false;
  String? _dragSelectionAnchorKey;
  String? _dragSelectionCurrentKey;
  Map<String, Map<String, dynamic>> _dragSelectionBase = const {};
  Offset _lastDragPointerGlobal = Offset.zero;
  Timer? _dragAutoScrollTimer;
  static const Duration _messageLongPressDuration = Duration(milliseconds: 375);
  static const double _dragEdgeZone = 80.0;
  static const double _dragMaxSpeed = 14.0;

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

  String _selectionKeyForExtMessage(Map<String, dynamic> msg) {
    final rawSender = msg['sender']?.toString() ?? '?';
    final msgId = msg['id']?.toString() ?? '';
    final timestamp = msg['timestamp']?.toString() ?? '';
    final content = msg['content']?.toString() ?? '';
    return '${msgId}_${timestamp}_${rawSender}_${content.hashCode}';
  }

  // Keyed by the message's STABLE animation id (animationId/id, not the
  // uniqueKey which embeds timestamp/content and can shift), so a server
  // sync doesn't mint a new GlobalKey and tear down the in-flight
  // AnimatedMessageBubble under it (see ChatScreen for the full story).
  GlobalKey _messageItemKey(String stableId) =>
      _messageItemKeys.putIfAbsent(stableId, () => GlobalKey());

  void _startExtDragSelection(Map<String, dynamic> msg, String uniqueKey) {
    final cur = _selectionNotifier.value;
    final next = Map<String, Map<String, dynamic>>.from(cur.selected);
    if (!cur.active) {
      HapticFeedback.mediumImpact();
    }
    next[uniqueKey] = msg;
    _selectionNotifier.value = (active: true, selected: next);
    _dragSelectionBase = Map<String, Map<String, dynamic>>.from(cur.selected)
      ..[uniqueKey] = msg;
    _dragSelectionAnchorKey = uniqueKey;
    _dragSelectionCurrentKey = uniqueKey;
    _isDragSelectingMessages = true;
    _selectExtMessageRangeTo(uniqueKey);
  }

  void _updateExtDragSelection(Offset globalPosition) {
    if (!_isDragSelectingMessages) return;
    _lastDragPointerGlobal = globalPosition;
    final hoveredKey = _messageKeyAtGlobal(globalPosition);
    if (hoveredKey != null && hoveredKey != _dragSelectionCurrentKey) {
      _selectExtMessageRangeTo(hoveredKey);
    }
    _updateDragAutoScroll();
  }

  void _endExtDragSelection() {
    _isDragSelectingMessages = false;
    _dragSelectionAnchorKey = null;
    _dragSelectionCurrentKey = null;
    _dragSelectionBase = const {};
    _stopDragAutoScroll();
  }

  void _selectExtMessageRangeTo(String uniqueKey) {
    final anchorKey = _dragSelectionAnchorKey;
    if (anchorKey == null) return;
    final start = _dragSelectionIndices[anchorKey];
    final end = _dragSelectionIndices[uniqueKey];
    if (start == null || end == null) return;
    final from = min(start, end);
    final to = max(start, end);
    final next = Map<String, Map<String, dynamic>>.from(_dragSelectionBase);
    for (int i = from; i <= to; i++) {
      final key = _dragSelectionOrder[i];
      final msg = _dragSelectionLookup[key];
      if (msg != null) next[key] = msg;
    }
    _dragSelectionCurrentKey = uniqueKey;
    _selectionNotifier.value = (active: true, selected: next);
  }

  String? _messageKeyAtGlobal(Offset globalPosition) {
    String? bestKey;
    double bestCenterDist = double.infinity;
    for (final uniqueKey in _dragSelectionOrder) {
      final dMsg = _dragSelectionLookup[uniqueKey];
      final stableId = dMsg == null
          ? null
          : (dMsg['animationId']?.toString() ??
              dMsg['id']?.toString() ??
              uniqueKey);
      final context =
          stableId == null ? null : _messageItemKeys[stableId]?.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final local = box.globalToLocal(globalPosition);
      if (local.dy < 0 || local.dy > box.size.height) continue;
      final dist = (local.dy - box.size.height / 2).abs();
      if (dist < bestCenterDist) {
        bestCenterDist = dist;
        bestKey = uniqueKey;
      }
    }
    return bestKey;
  }

  void _updateDragAutoScroll() {
    final box = _messageListViewportKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(_lastDragPointerGlobal);
    final height = box.size.height;
    final nearTop = local.dy < _dragEdgeZone;
    final nearBottom = local.dy > height - _dragEdgeZone;
    if (nearTop || nearBottom) {
      _dragAutoScrollTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _handleDragAutoScrollTick(),
      );
    } else {
      _stopDragAutoScroll();
    }
  }

  void _handleDragAutoScrollTick() {
    if (!_isDragSelectingMessages || !_scroll.hasClients) {
      _stopDragAutoScroll();
      return;
    }
    final box = _messageListViewportKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(_lastDragPointerGlobal);
    final height = box.size.height;
    double speed = 0;
    if (local.dy < _dragEdgeZone) {
      final depth =
          ((_dragEdgeZone - local.dy) / _dragEdgeZone).clamp(0.0, 1.0);
      speed = depth * _dragMaxSpeed;
    } else if (local.dy > height - _dragEdgeZone) {
      final depth = ((local.dy - (height - _dragEdgeZone)) / _dragEdgeZone)
          .clamp(0.0, 1.0);
      speed = -(depth * _dragMaxSpeed);
    } else {
      _stopDragAutoScroll();
      return;
    }
    final newOffset =
        (_scroll.offset + speed).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(newOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDragSelectingMessages) return;
      final hoveredKey = _messageKeyAtGlobal(_lastDragPointerGlobal);
      if (hoveredKey != null && hoveredKey != _dragSelectionCurrentKey) {
        _selectExtMessageRangeTo(hoveredKey);
      }
    });
  }

  void _stopDragAutoScroll() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
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
  late Animation<double> _inputEntryTranslateY;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  final Set<String> _newMessageIds = {};
  final Set<String> _alreadyRenderedMessageIds = {};
  // True once the message list has painted at least one frame. Entry
  // animations are suppressed until then — closes a race where the network
  // history fetch resolves after _applyOpenChatAnimationKeys already ran,
  // which would otherwise make the whole history "appear new" and animate
  // in on open.
  bool _hasBuiltMessageListOnce = false;

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
    _maybeShowE2eeWarning();
    _fetchGroupInfo();

    _loadHistoryFromCache();

    if (_isConnected) {
      final voiceActive = VoiceChannelManager.instance.isInChannel.value &&
          VoiceChannelManager.instance.currentServerId.value ==
              widget.server.id;
      if (voiceActive) {
        // Keep the WS alive — _connectToServer will reuse it (just subscribes).
        debugPrint(
            '[ext-chat] Voice call active, reusing existing WS connection');
        _isConnected = false;
      } else {
        debugPrint(
            '[ext-chat] Server connected, disconnecting for fresh reconnection');
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
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _inputEntryTranslateY = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _inputEntryController,
        curve: Curves.easeOutCubic,
      ),
    );

    _inputEntryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _inputEntryController,
        curve: Curves.easeOut,
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
    _stopDragAutoScroll();
    _scroll.dispose();
    _showScrollDownButton.dispose();
    _bottomBarHeight.dispose();
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
      final totalItems = _rebuildExtDisplayItems().length;
      if (totalItems == 0) return;
      final listIdx = matchAdjI;
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
          final newAnimId = '$msgId#$_historyLoadEpoch';
          m['animationId'] = newAnimId;
          _alreadyRenderedMessageIds.add(newAnimId);
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
    _alreadyRenderedMessageIds.clear();
    _hasBuiltMessageListOnce = false;
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
          final idx =
              _messages.indexWhere((m) => m['id']?.toString() == messageId);
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
      final dir = await getOnyxDocumentsDirectory();
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
                m['id'].toString():
                    m['animationId']?.toString() ?? m['id'].toString(),
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
        final ts =
            (m['timestamp'] ?? DateTime.now().toIso8601String()).toString();
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
            m['id'].toString():
                m['animationId']?.toString() ?? m['id'].toString(),
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
      final dir = await getOnyxDocumentsDirectory();
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
        final url =
            '$base/groups/$gid/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}';
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
            final idx = _messages
                .indexWhere((m) => m['id']?.toString() == messageId.toString());
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
        Uri.parse(
            '${widget.server.baseUrl}/groups/${widget.group.id}/messages/$msgId'),
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

  // Scoped per account (current ONYX username) so every account that opens the
  // group sees the notice once — switching accounts re-shows it.
  String get _e2eeWarnPrefsKey =>
      'e2ee_warn_shown_ext_group_'
      '${rootScreenKey.currentState?.currentUsername ?? ''}_'
      '${widget.group.id}_${widget.server.id}';

  // Show the "no E2EE in groups" dialog only the first time this group is
  // opened. Groups only — channels don't get this notice. Persisted per group.
  Future<void> _maybeShowE2eeWarning() async {
    if (widget.group.isChannel) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_e2eeWarnPrefsKey) ?? false;
    if (alreadyShown || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showE2eeWarningDialog();
    });
  }

  // One-time dialog for EXTERNAL (self-hosted) groups: content is NOT
  // end-to-end encrypted and media is uploaded to and stored on the owner's
  // server. ONYX has nothing to do with this group.
  Future<void> _showE2eeWarningDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        final t = AppLocalizations.of(dialogContext);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  color: cs.errorContainer,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_open_rounded,
                            size: 30, color: cs.onErrorContainer),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t.e2eeWarnTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.e2eeWarnExtBody,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _e2eeWarnRow(
                        cs,
                        Icons.dns_rounded,
                        t.e2eeWarnExtMedia,
                      ),
                      const SizedBox(height: 10),
                      _e2eeWarnRow(
                        cs,
                        Icons.info_outline_rounded,
                        t.e2eeWarnExtOnyxUnrelated,
                      ),
                      const SizedBox(height: 10),
                      _e2eeWarnRow(
                        cs,
                        Icons.visibility_off_rounded,
                        t.e2eeWarnDoNotShare,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool(_e2eeWarnPrefsKey, true);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: Text(t.e2eeWarnUnderstand),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Small icon + text row used inside the E2EE warning dialog body.
  Widget _e2eeWarnRow(ColorScheme cs, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

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
  List<AlbumItem>? _cachedAllImages;
  int _cachedAllImagesHash = 0;
  int _cachedDragHash = 0;

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
        listviewIdx = j;
        break;
      }
    }
    if (listviewIdx == null) return;

    setState(() => _scrollTargetId = msgId);

    final maxExt = _scroll.position.maxScrollExtent;
    final totalItems = displayItems.length;
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
            child: AdaptiveGlassPill(
              backgroundColor: bgColor.withValues(alpha: opacity),
              borderColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
              height: null,
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          AppLocalizations.of(context).pinnedMessage,
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
                    openEmojiPicker(
                        context, 'ext_$extMsgId', widget.server.username,
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
              final ok = await saveImageToGallery(cached.file.path);
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
                final ok = await saveImageToGallery(cached.file.path);
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
          '.jfif',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
          '.heic'
        ].contains(ext);
        final isVideo =
            ['.mp4', '.mov', '.avi', '.webm', '.m4v', '.mkv'].contains(ext);
        if (isImage) {
          final saved = await saveImageToGallery(file.path);
          rootScreenKey.currentState?.showSnack(
              saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        } else if (isVideo) {
          final saved =
              await GallerySaver.saveVideo(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(
              saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        } else {
          final onyxDir = await getOnyxSaveDirectory();
          if (onyxDir == null) {
            rootScreenKey.currentState
                ?.showSnack('Cannot access Downloads directory');
            return;
          }
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

  List<DesktopMenuItem> _buildExternalDesktopMenuItems(
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
    final l = AppLocalizations.of(context);
    return [
      DesktopMenuItem(
        icon: Icons.reply_rounded,
        label: l.reply,
        onPressed: () => _startReply({
          'id': msg['id']?.toString(),
          'sender': rawSender,
          'content': content,
        }),
      ),
      DesktopMenuItem(
        icon: Icons.add_reaction_outlined,
        label: l.react,
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
        DesktopMenuItem(
          icon: Icons.save_alt_rounded,
          label: l.save,
          onPressed: () => _saveMediaFromMessage(content),
        ),
      if (isImage || isProxyImage)
        DesktopMenuItem(
          icon: Icons.copy_all_rounded,
          label: l.copyImage,
          onPressed: isImage
              ? () => copyMessageImageToClipboard(
                  content, (m) => rootScreenKey.currentState?.showSnack(m))
              : () => _copyExternalProxyImage(content),
        ),
      if (!isMedia)
        DesktopMenuItem(
          icon: Icons.content_copy_rounded,
          label: l.copy,
          type: ContextMenuButtonType.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            rootScreenKey.currentState?.showSnack(l.msgCopied);
          },
        ),
      if (isFile)
        DesktopMenuItem(
          icon: Icons.folder_open_rounded,
          label: l.showInFileSystem,
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
              rootScreenKey.currentState?.showSnack(l.fileNotLoadedOpenFirst);
              return;
            }
            revealInFileSystem(localPath);
          },
        ),
    ];
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

    // Capture widget-bound values before any async gap so the message is
    // delivered to the correct server/group even if the widget is updated.
    final serverId = widget.server.id;
    final groupId = widget.group.id;
    final sender = widget.group.isChannel ? _groupName : widget.server.username;

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final now = DateTime.now();

    if (mounted) {
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
    }

    try {
      final result = await ExternalServerManager.sendMessage(
        serverId,
        groupId,
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
                ? 'audio'
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

  void _cancelAllUploads() {
    for (final task in List<UploadTask>.from(_pendingUploads)) {
      _cancelUpload(task);
    }
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

    if (paths.length > 1) {
      final imagePaths = paths.where(FileTypeDetector.isImage).toList();
      if (imagePaths.length > 10) {
        final albumCount = (imagePaths.length / 10).ceil();
        var proceed = false;
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => BulkAlbumConfirmDialog(
            imageCount: imagePaths.length,
            albumCount: albumCount,
            onSend: () => proceed = true,
            onCancel: () {},
          ),
        );
        if (!proceed) return;
        await _handleDroppedFiles(paths, skipBulkConfirm: true);
      } else {
        await _handleDroppedFiles(paths);
      }
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
    if (filePaths.isEmpty) return;

    final albumTask = UploadTask(
      id: 'album_${DateTime.now().millisecondsSinceEpoch}',
      type: 'album',
      localPath: '',
      basename: '',
    );
    albumTask.albumTotal = filePaths.length;
    albumTask.status = UploadStatus.uploading;
    if (mounted) setState(() => _pendingUploads.add(albumTask));

    // Upload every image in the batch concurrently instead of one-by-one —
    // sequential network round-trips per image were the source of
    // multi-second delays between albums on large sends.
    List<Map<String, String>?> results;
    try {
      if (_serverHasLocalMedia) {
        results = await Future.wait(filePaths.map((filePath) async {
          final basename = p.basename(filePath);
          final bytes = await File(filePath).readAsBytes();
          final link = await _uploadToServer(bytes, basename);
          if (link == null) {
            debugPrint('[ext-album] server upload failed for $basename');
            return null;
          }
          albumTask.albumDone++;
          albumTask.progress = albumTask.albumDone / albumTask.albumTotal;
          return {'url': link, 'orig': basename, 'provider': 'server'};
        }));
      } else {
        const provider = MediaProvider.catbox;
        results = await Future.wait(filePaths.map((filePath) async {
          final basename = p.basename(filePath);
          final bytes = await File(filePath).readAsBytes();
          final link = await _uploadToProvider(bytes, basename, provider);
          if (link == null) {
            debugPrint('[ext-album] upload failed for $basename');
            return null;
          }
          albumTask.albumDone++;
          albumTask.progress = albumTask.albumDone / albumTask.albumTotal;
          return {'url': link, 'orig': basename, 'provider': provider.name};
        }));
      }
    } finally {
      if (mounted) setState(() => _pendingUploads.remove(albumTask));
    }

    final items = results.whereType<Map<String, String>>().toList();

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

  Future<void> _handleDroppedFiles(List<String> filePaths,
      {bool skipBulkConfirm = false}) async {
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

    // Single file — always confirm
    if (existing.length == 1) {
      final filePath = existing.first;
      final isImage = FileTypeDetector.isImage(filePath);
      if (!mounted) return;
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
      return;
    }

    // Batch consecutive images (≤10 per album); non-image files are sent
    // individually. Split into ordered segments first so we know up front
    // how many albums this drop will produce.
    final segments = <Object>[]; // List<String> album batch, or String path
    int i = 0;
    while (i < existing.length) {
      final fp = existing[i];
      if (FileTypeDetector.isImage(fp)) {
        final batch = <String>[];
        while (i < existing.length &&
            FileTypeDetector.isImage(existing[i]) &&
            batch.length < 10) {
          batch.add(existing[i]);
          i++;
        }
        segments.add(batch);
      } else {
        segments.add(fp);
        i++;
      }
    }

    final albumBatches = segments.whereType<List<String>>().toList();
    // For a drop that produces multiple albums, ask once up front instead
    // of showing one dialog per album — hundreds of dialog transitions and
    // full-res thumbnail decodes were the source of heavy lag on large
    // sends.
    // skipBulkConfirm = true when caller already showed the dialog.
    final useBulkConfirm = albumBatches.length > 1 && !skipBulkConfirm;
    var albumsAllowed = true;
    if (useBulkConfirm) {
      if (!mounted) return;
      final totalImages = albumBatches.fold<int>(0, (sum, b) => sum + b.length);
      var proceed = false;
      await showDialog<void>(
        context: context,
        builder: (_) => BulkAlbumConfirmDialog(
          imageCount: totalImages,
          albumCount: albumBatches.length,
          onSend: () => proceed = true,
          onCancel: () {},
        ),
      );
      albumsAllowed = proceed;
    }

    for (final segment in segments) {
      if (segment is List<String>) {
        if (useBulkConfirm || skipBulkConfirm) {
          if (!albumsAllowed) continue;
          await _processAndUploadAlbum(segment);
        } else {
          if (!mounted)
            continue; // skip per-album dialog; don't stop remaining sends
          var proceed = false;
          await showDialog<void>(
            context: context,
            builder: (_) => AlbumPreviewDialog(
              filePaths: segment,
              onSend: () => proceed = true,
              onCancel: () {},
            ),
          );
          if (proceed) await _processAndUploadAlbum(segment);
        }
      } else {
        final fp = segment as String;
        if (!mounted)
          continue; // skip per-file dialog; don't stop remaining sends
        var proceed = false;
        await showDialog<void>(
          context: context,
          builder: (_) => FilePreviewDialog(
            filePath: fp,
            onSend: () => proceed = true,
            onCancel: () {},
            onPasteExtra: null,
            onSendAlbum: null,
          ),
        );
        if (proceed) await _processAndUploadFile(fp);
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
        return MeasureSize(
          onChange: (size) {
            if ((_bottomBarHeight.value - size.height).abs() > 0.5) {
              _bottomBarHeight.value = size.height;
            }
          },
          child: Column(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
              // Below the reply preview, above the input bar — plain Column
              // children, so they stack instead of overlapping.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _pendingUploads.isNotEmpty
                    ? UploadProgressBar(
                        tasks: _pendingUploads,
                        maxWidth: double.infinity,
                        showProgress:
                            false, // server/catbox multipart — no byte-level progress
                        onCancelAll: _cancelAllUploads,
                      )
                    : const SizedBox.shrink(),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  SettingsManager.elementBrightness,
                  SettingsManager.liquidGlassOnInput,
                  SettingsManager.liquidGlassInputQuality,
                  SettingsManager.liquidGlassInputBlur,
                  SettingsManager.liquidGlassInputTint,
                  SettingsManager.liquidGlassInputSaturation,
                  SettingsManager.liquidGlassInputChromatic,
                  SettingsManager.liquidGlassInputRefractive,
                  SettingsManager.liquidGlassInputLightIntensity,
                  SettingsManager.liquidGlassInputThickness,
                ]),
                builder: (_, __) {
                  final brightness = SettingsManager.elementBrightness.value;
                  final baseColor = SettingsManager.getElementColor(
                    colorScheme.surfaceContainerHighest,
                    brightness,
                  );
                  final isMobile = !Platform.isWindows && !Platform.isLinux;
                  final useGlass =
                      isMobile && SettingsManager.liquidGlassOnInput.value;
                  final bar = ChatInputBar(
                    inputAreaKey: _inputAreaKey,
                    controller: _textCtrl,
                    textFocusNode: _focusNode,
                    recordingListenable: recordingNotifier,
                    recordingLevelListenable: recordingLevelNotifier,
                    onCancelRecording: () {
                      rootScreenKey.currentState?.cancelRecording();
                    },
                    onMicPressed: (isRecording) {
                      if (isRecording) {
                        _stopRecordingAndUpload();
                      } else {
                        _startRecording();
                      }
                    },
                    onAttachPressed: _pickAndUploadMedia,
                    onSendPressed: () => _sendMessage(_textCtrl.text),
                    onPaste: _handlePasteFromClipboard,
                    hintText:
                        AppLocalizations.of(context).localizeHint(_inputHint),
                    backgroundColor: useGlass ? Colors.white : baseColor,
                    opacity: useGlass ? 0.0 : opacity,
                    borderColor: useGlass
                        ? Colors.transparent
                        : colorScheme.outlineVariant.withValues(alpha: 0.15),
                    glassMode: useGlass,
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
                                      'readContentUri', {'uri': data.uri});
                            } catch (e) {
                              debugPrint('[err] $e');
                            }
                          }
                          if (bytes != null && bytes.isNotEmpty && mounted) {
                            final ext = data.mimeType.contains('/')
                                ? data.mimeType.split('/').last
                                : 'png';
                            final tempDir = await getTemporaryDirectory();
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
                  );
                  if (!useGlass) return bar;
                  final quality = SettingsManager.liquidGlassInputQuality.value;
                  final blur = SettingsManager.liquidGlassInputBlur.value;
                  final tint = SettingsManager.liquidGlassInputTint.value;
                  final saturation =
                      SettingsManager.liquidGlassInputSaturation.value;
                  final chromatic =
                      SettingsManager.liquidGlassInputChromatic.value;
                  final refractive =
                      SettingsManager.liquidGlassInputRefractive.value;
                  final lightIntensity =
                      SettingsManager.liquidGlassInputLightIntensity.value;
                  final thickness =
                      SettingsManager.liquidGlassInputThickness.value;
                  final glassQuality = switch (quality) {
                    LiquidGlassQuality.fast => GlassQuality.standard,
                    LiquidGlassQuality.medium => GlassQuality.minimal,
                    LiquidGlassQuality.quality => GlassQuality.premium,
                  };
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final tintColor = isDark
                      ? Colors.white.withValues(alpha: tint)
                      : Colors.black.withValues(alpha: tint);
                  final settings = LiquidGlassSettings(
                    thickness: thickness,
                    blur: blur,
                    chromaticAberration: chromatic,
                    lightIntensity: lightIntensity,
                    refractiveIndex: refractive,
                    saturation: saturation,
                    ambientStrength: 0.8,
                    lightAngle: 0.75 * pi,
                    glassColor: tintColor,
                  );
                  return GlassCard(
                    useOwnLayer: true,
                    settings: settings,
                    quality: glassQuality,
                    padding: EdgeInsets.zero,
                    shape: LiquidRoundedRectangle(borderRadius: 24),
                    clipBehavior: Clip.antiAlias,
                    child: bar,
                  );
                },
              ),
            ],
          ),
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        toolbarHeight: 70,
        leadingWidth: isDesktop ? 162 : 66,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: isDesktop
            ? ValueListenableBuilder(
                valueListenable: _selectionNotifier,
                builder: (_, sel, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity:
                        CurvedAnimation(parent: anim, curve: Curves.easeInOut),
                    child: child,
                  ),
                  child: sel.active
                      ? AnimatedBuilder(
                          key: const ValueKey(true),
                          animation: Listenable.merge([
                            SettingsManager.elementOpacity,
                            SettingsManager.elementBrightness,
                          ]),
                          builder: (ctx, _) {
                            final op = SettingsManager.elementOpacity.value;
                            final br = SettingsManager.elementBrightness.value;
                            final cs = Theme.of(ctx).colorScheme;
                            final bgColor = SettingsManager.getElementColor(
                              cs.surfaceContainerHighest,
                              br,
                            ).withValues(alpha: op);
                            final borderColor =
                                cs.outlineVariant.withValues(alpha: 0.3);
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AdaptiveGlassIconButton(
                                  backgroundColor: bgColor,
                                  borderColor: borderColor,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.close_rounded,
                                        size: 18,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.7)),
                                    onPressed: _exitExtSelectionMode,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : const SizedBox.shrink(key: ValueKey(false)),
                ),
              )
            : ValueListenableBuilder(
                valueListenable: _selectionNotifier,
                builder: (_, sel, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity:
                        CurvedAnimation(parent: anim, curve: Curves.easeInOut),
                    child: child,
                  ),
                  child: AnimatedBuilder(
                    key: ValueKey(sel.active),
                    animation: Listenable.merge([
                      SettingsManager.elementOpacity,
                      SettingsManager.elementBrightness,
                    ]),
                    builder: (ctx, _) {
                      final op = SettingsManager.elementOpacity.value;
                      final br = SettingsManager.elementBrightness.value;
                      final cs = Theme.of(ctx).colorScheme;
                      final bgColor = SettingsManager.getElementColor(
                        cs.surfaceContainerHighest,
                        br,
                      ).withValues(alpha: op);
                      final borderColor =
                          cs.outlineVariant.withValues(alpha: 0.3);
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Center(
                          child: AdaptiveGlassIconButton(
                            backgroundColor: bgColor,
                            borderColor: borderColor,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                sel.active
                                    ? Icons.close_rounded
                                    : Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                              onPressed: sel.active
                                  ? _exitExtSelectionMode
                                  : () => Navigator.of(ctx).maybePop(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
        title: ValueListenableBuilder(
          valueListenable: _selectionNotifier,
          builder: (_, sel, __) => AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut));
                return FadeTransition(
                  opacity: CurvedAnimation(
                      parent: animation, curve: Curves.easeInOut),
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: sel.active
                  ? AnimatedBuilder(
                      key: const ValueKey(true),
                      animation: Listenable.merge([
                        SettingsManager.elementOpacity,
                        SettingsManager.elementBrightness,
                      ]),
                      builder: (titleCtx, _) {
                        final op = SettingsManager.elementOpacity.value;
                        final br = SettingsManager.elementBrightness.value;
                        final cs = Theme.of(titleCtx).colorScheme;
                        final bgColor = SettingsManager.getElementColor(
                          cs.surfaceContainerHighest,
                          br,
                        ).withValues(alpha: op);
                        final borderColor =
                            cs.outlineVariant.withValues(alpha: 0.3);
                        return Align(
                          alignment: Alignment.center,
                          child: AdaptiveGlassPill(
                            backgroundColor: bgColor,
                            borderColor: borderColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${sel.selected.length} selected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : AnimatedBuilder(
                      key: const ValueKey(false),
                      animation: Listenable.merge([
                        SettingsManager.elementOpacity,
                        SettingsManager.elementBrightness,
                      ]),
                      builder: (titleCtx, _) {
                        final op = SettingsManager.elementOpacity.value;
                        final br = SettingsManager.elementBrightness.value;
                        final cs = Theme.of(titleCtx).colorScheme;
                        final bgColor = SettingsManager.getElementColor(
                          cs.surfaceContainerHighest,
                          br,
                        ).withValues(alpha: op);
                        final borderColor =
                            cs.outlineVariant.withValues(alpha: 0.3);
                        final isWide = MediaQuery.sizeOf(titleCtx).width > 700;
                        final textContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: MarqueeText(
                                    key: ValueKey('group_name_$_groupName'),
                                    text: _groupName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
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
                        );
                        final pill = GestureDetector(
                          onTap: _showEditProfileDialog,
                          child: AdaptiveGlassPill(
                            backgroundColor: bgColor,
                            borderColor: borderColor,
                            child: Row(
                              mainAxisSize:
                                  isWide ? MainAxisSize.min : MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  key: ValueKey(
                                      'avatar_${widget.server.id}_${widget.group.id}_${_groupName}_$_avatarVersion'),
                                  radius: 20,
                                  backgroundColor: colorScheme.primaryContainer,
                                  backgroundImage: _avatarVersion > 0
                                      ? NetworkImage(
                                          '${widget.server.baseUrl}/groups/${widget.group.id}/avatar?v=$_avatarVersion&sid=${widget.server.id}')
                                      : null,
                                  child: _avatarVersion == 0
                                      ? Icon(Icons.dns_outlined,
                                          size: 20,
                                          color: colorScheme.onPrimaryContainer)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                if (isWide)
                                  textContent
                                else
                                  Expanded(child: textContent),
                              ],
                            ),
                          ),
                        );
                        final wrappedPill = MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: pill,
                        );
                        return isWide
                            ? Align(
                                alignment: Alignment.center, child: wrappedPill)
                            : wrappedPill;
                      },
                    ),
            ),
          ),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: _selectionNotifier,
            builder: (_, sel, __) {
              final switcher = AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity:
                      CurvedAnimation(parent: anim, curve: Curves.easeInOut),
                  child: child,
                ),
                child: sel.active
                    ? AnimatedBuilder(
                        key: const ValueKey('sel-actions'),
                        animation: Listenable.merge([
                          SettingsManager.elementOpacity,
                          SettingsManager.elementBrightness,
                        ]),
                        builder: (ctx, _) {
                          final op = SettingsManager.elementOpacity.value;
                          final br = SettingsManager.elementBrightness.value;
                          final cs = Theme.of(ctx).colorScheme;
                          final btnBg = SettingsManager.getElementColor(
                            cs.surfaceContainerHighest,
                            br,
                          ).withValues(alpha: op);
                          final border =
                              cs.outlineVariant.withValues(alpha: 0.3);
                          final iconColor =
                              cs.onSurface.withValues(alpha: 0.75);
                          Widget selBtn(IconData ic, Color? icColor, String tip,
                                  VoidCallback? onTap) =>
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Tooltip(
                                  message: tip,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: onTap,
                                      child: AdaptiveGlassIconButton(
                                        backgroundColor: btnBg,
                                        borderColor: border,
                                        child: Center(
                                            child: Icon(ic,
                                                size: 20,
                                                color: icColor ?? iconColor)),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                          return Row(mainAxisSize: MainAxisSize.min, children: [
                            if (sel.selected.values.any(_isExtTextMessage))
                              selBtn(Icons.copy_rounded, null, 'Copy',
                                  _copySelectedExtMessages),
                            if (sel.selected.isNotEmpty)
                              selBtn(Icons.forward_rounded, null, 'Forward',
                                  _forwardSelectedExtMessages),
                          ]);
                        },
                      )
                    : AnimatedBuilder(
                        key: const ValueKey('normal-actions'),
                        animation: Listenable.merge([
                          SettingsManager.elementOpacity,
                          SettingsManager.elementBrightness,
                        ]),
                        builder: (actCtx, _) {
                          final op = SettingsManager.elementOpacity.value;
                          final br = SettingsManager.elementBrightness.value;
                          final csA = Theme.of(actCtx).colorScheme;
                          final btnBg = SettingsManager.getElementColor(
                            csA.surfaceContainerHighest,
                            br,
                          ).withValues(alpha: op);
                          final btnBorder =
                              csA.outlineVariant.withValues(alpha: 0.3);
                          final iconColor =
                              csA.onSurface.withValues(alpha: 0.75);
                          return Row(mainAxisSize: MainAxisSize.min, children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message: 'Search (Ctrl+F)',
                                child: GestureDetector(
                                  onTap: () {
                                    if (_showSearch)
                                      _closeSearch();
                                    else
                                      _openSearch();
                                  },
                                  child: AdaptiveGlassIconButton(
                                    backgroundColor: btnBg,
                                    borderColor: btnBorder,
                                    child: Center(
                                        child: Icon(Icons.search,
                                            size: 20, color: iconColor)),
                                  ),
                                ),
                              ),
                            ),
                            if (_myRole == null) ...[
                              const SizedBox(width: 4),
                              FilledButton.tonal(
                                onPressed: _joinGroup,
                                child: Text(AppLocalizations.of(context).join),
                              ),
                            ],
                            const SizedBox(width: 4),
                            AdaptiveGlassIconButton(
                              backgroundColor: btnBg,
                              borderColor: btnBorder,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert,
                                    size: 20, color: iconColor),
                                onSelected: (value) async {
                                  if (value == 'voice') {
                                    showVoiceChannelPopup(
                                        context, widget.server.id);
                                  } else if (value == 'gallery') {
                                    showMediaGalleryDialog(
                                      context,
                                      items: extractGalleryItemsFromMaps(
                                          _messages),
                                      peerUsername: widget.group.name,
                                      onJumpToMessage: (id) =>
                                          _scrollToExtMessageById(id),
                                    );
                                  } else if (value == 'disconnect') {
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
                                  final liveServer = ExternalServerManager
                                      .servers.value
                                      .firstWhere(
                                    (s) => s.id == widget.server.id,
                                    orElse: () => widget.server,
                                  );
                                  final hasVoice =
                                      liveServer.features.contains('voice');
                                  return [
                                    if (hasVoice)
                                      PopupMenuItem<String>(
                                        value: 'voice',
                                        child: Row(children: [
                                          Icon(Icons.headset_mic_rounded,
                                              size: 18, color: csA.primary),
                                          const SizedBox(width: 10),
                                          const Text('Voice channels'),
                                        ]),
                                      ),
                                    PopupMenuItem<String>(
                                      value: 'gallery',
                                      child: Row(children: [
                                        Icon(Icons.photo_library_outlined,
                                            size: 18, color: csA.primary),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)
                                            .galleryMenuLabel),
                                      ]),
                                    ),
                                    const PopupMenuDivider(),
                                    if (isOwner) ...[
                                      PopupMenuItem<String>(
                                        value: 'edit_profile',
                                        child: Row(children: [
                                          Icon(Icons.edit,
                                              size: 18, color: csA.primary),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)
                                              .editProfile),
                                        ]),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'members',
                                        child: Row(children: [
                                          Icon(Icons.people,
                                              size: 18, color: csA.primary),
                                          const SizedBox(width: 8),
                                          Text(AppLocalizations.of(context)
                                              .manageMembers),
                                        ]),
                                      ),
                                      const PopupMenuDivider(),
                                    ],
                                    PopupMenuItem<String>(
                                      value: 'disconnect',
                                      enabled: _isConnected,
                                      child: Row(children: [
                                        Icon(Icons.power_settings_new,
                                            size: 18,
                                            color: _isConnected
                                                ? csA.error
                                                : csA.onSurface
                                                    .withValues(alpha: 0.3)),
                                        const SizedBox(width: 8),
                                        Text(_isConnected
                                            ? 'Disconnect'
                                            : 'Not connected'),
                                      ]),
                                    ),
                                  ];
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                          ]);
                        },
                      ),
              );
              if (isDesktop)
                return SizedBox(
                  width: 162,
                  child:
                      Align(alignment: Alignment.centerRight, child: switcher),
                );
              return AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.centerRight,
                child: switcher,
              );
            },
          ),
        ],
      ),
      body: DragDropZone(
        onFilesDropped: _handleDroppedFiles,
        enabled: !_isReadOnlyChannel && _isConnected,
        child: Stack(
          children: [
            const ChatBackgroundLayer(),
            Builder(
              builder: (context) {
                if (_messages.isEmpty) {
                  return EmptyChatPlaceholder(
                      label: AppLocalizations.of(context).noMessagesYet);
                }
                // Only flip this after a frame that actually had
                // history loaded — see group_chat_screen.dart for
                // why flipping it on an empty/placeholder frame
                // breaks the chat-open-doesn't-animate gating.
                if (!_hasBuiltMessageListOnce) {
                  if (_alreadyRenderedMessageIds.isEmpty) {
                    // No pre-seeded history → first message in a
                    // new chat. Set immediately so the bubble mounts
                    // with animate:true (AnimatedMessageBubble
                    // .didUpdateWidget is a no-op — must be true
                    // at widget mount, not one frame later).
                    _hasBuiltMessageListOnce = true;
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _hasBuiltMessageListOnce = true;
                    });
                  }
                }

                final swapped = SettingsManager.swapMessageAlignment.value;
                final alignRight = SettingsManager.alignAllMessagesRight.value;

                // Compute search matches (indices into display items)
                final displayItems = _rebuildExtDisplayItems();

                final stampLast =
                    _messages.isEmpty ? '' : '${_messages.last['id']}';
                if (_messages.length != _preloadStampCount ||
                    stampLast != _preloadStampLast) {
                  _preloadStampCount = _messages.length;
                  _preloadStampLast = stampLast;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ChatImagePreloader.preloadGroupMessages(_messages);
                  });
                }

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
                      : _currentMatchIdx.clamp(0, newMatches.length - 1);
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
                      if (mounted) {
                        _searchStats.value = (current: 0, total: 0);
                      }
                    });
                  }
                }

                // Deferred for the same reason as ChatScreen: both
                // caches go stale on every send, and the full-history
                // recompute is expensive enough in heavy chats to
                // block the frame the new bubble's entrance
                // animation starts on.
                if (_cachedDragHash != _extDisplayHash) {
                  final targetHash = _extDisplayHash;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _cachedDragHash == targetHash) return;
                    final dragMessages = displayItems
                        .whereType<Map<String, dynamic>>()
                        .toList(growable: false);
                    setState(() {
                      _cachedDragHash = targetHash;
                      _dragSelectionOrder = dragMessages
                          .map(_selectionKeyForExtMessage)
                          .toList(growable: false);
                      _dragSelectionLookup = {
                        for (final msg in dragMessages)
                          _selectionKeyForExtMessage(msg): msg,
                      };
                      _dragSelectionIndices = {
                        for (int idx = 0;
                            idx < _dragSelectionOrder.length;
                            idx++)
                          _dragSelectionOrder[idx]: idx,
                      };
                    });
                  });
                }
                if (_cachedAllImages == null) {
                  _cachedAllImages =
                      ChatImagesScope.computeFromGroupMessages(_messages);
                  _cachedAllImagesHash = _extDisplayHash;
                } else if (_cachedAllImagesHash != _extDisplayHash) {
                  final targetHash = _extDisplayHash;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _cachedAllImagesHash == targetHash) return;
                    final recomputed =
                        ChatImagesScope.computeFromGroupMessages(_messages);
                    if (!mounted) return;
                    setState(() {
                      _cachedAllImages = recomputed;
                      _cachedAllImagesHash = targetHash;
                    });
                  });
                }

                // Maps each item's stable String key to its current
                // flat ListView index — see the matching
                // findChildIndexCallback below for why this exists
                // (without it, every visible bubble gets destroyed +
                // rebuilt from scratch on every single send).
                final Map<String, int> itemKeyToFlatIndex = {};
                for (int idx = 0; idx < displayItems.length; idx++) {
                  final flatIndex = idx;
                  final item = displayItems[idx];
                  if (item is DateTime) {
                    itemKeyToFlatIndex['day_${item.toIso8601String()}'] =
                        flatIndex;
                  } else if (item is Map<String, dynamic>) {
                    // Must match the animKey computed below exactly
                    // (animationId ?? id, never the longer
                    // composite fallback used in GroupChatScreen).
                    final itemMsgId = item['id']?.toString() ?? '';
                    final itemAnimKey =
                        item['animationId']?.toString() ?? itemMsgId;
                    itemKeyToFlatIndex['msg_$itemAnimKey'] = flatIndex;
                  }
                }

                return ChatImagesScope(
                  allImages: _cachedAllImages!,
                  child: Listener(
                    key: _messageListViewportKey,
                    onPointerDown: (_) {
                      if (!isDesktop) return;
                      _suppressAutoRefocus = true;
                      _focusNode.unfocus();
                    },
                    onPointerUp: (_) {
                      if (_isDragSelectingMessages) _endExtDragSelection();
                    },
                    onPointerCancel: (_) {
                      if (_isDragSelectingMessages) _endExtDragSelection();
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      itemCount: displayItems.length,
                      cacheExtent: SettingsManager.chatCacheExtent.value,
                      addRepaintBoundaries: true,
                      addAutomaticKeepAlives: true,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            (_showSearch ? 64 : 12),
                        bottom: 72 + MediaQuery.of(context).padding.bottom,
                      ),
                      findChildIndexCallback: (Key key) {
                        if (key is! ValueKey<String>) return null;
                        return itemKeyToFlatIndex[key.value];
                      },
                      itemBuilder: (ctx, i) {
                        final adjustedI = i;
                        final item = displayItems[adjustedI];

                        if (item is DateTime) {
                          return KeyedSubtree(
                            key: ValueKey<String>(
                                'day_${item.toIso8601String()}'),
                            child: _buildExtDaySeparator(ctx, item),
                          );
                        }

                        final msg = item as Map<String, dynamic>;
                        final rawSender = msg['sender']?.toString() ?? '?';

                        final isMe = widget.group.isChannel
                            ? false
                            : (rawSender == widget.server.username);
                        final content = msg['content']?.toString() ?? '';
                        final isSearchMatch = _searchQuery.isNotEmpty &&
                            content.toLowerCase().contains(_searchQuery);
                        final isCurrentSearchMatch = isSearchMatch &&
                            _cachedSearchMatches.isNotEmpty &&
                            _cachedSearchMatches[_currentMatchIdx] == adjustedI;

                        final bubble = Container(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.7),
                          child: SwipeableMessageWrapper(
                            onSwipeRight: () => _showExternalMessageMenu(msg),
                            onSwipeLeft: () => _startReply({
                              'id': msg['id']?.toString(),
                              'sender': rawSender,
                              'content': content,
                            }),
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
                                          msg['timestamp']?.toString() ?? '') ??
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
                              onRightClick: isDesktop
                                  ? (offset) {
                                      debugPrint(
                                          '[RightClickMenu] external_group onRightClick invoked, msgId=${msg['id']}');
                                      final items =
                                          _buildExternalDesktopMenuItems(msg);
                                      debugPrint(
                                          '[RightClickMenu] external_group items=${items.length}');
                                      if (items.isNotEmpty) {
                                        showMessageDesktopMenu(
                                            context, offset, items);
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        );

                        final shouldAlignRight =
                            alignRight ? !swapped : (swapped ? !isMe : isMe);

                        Widget contentWithSender;
                        if (!isMe) {
                          contentWithSender = Column(
                            crossAxisAlignment: shouldAlignRight
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
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
                        final timestamp = msg['timestamp']?.toString() ?? '';
                        final uniqueKey =
                            '${msgId}_${timestamp}_${rawSender}_${content.hashCode}';
                        final animKey = msg['animationId']?.toString() ?? msgId;

                        final bool isFirstAppearance =
                            !_alreadyRenderedMessageIds.contains(animKey);
                        if (isFirstAppearance) {
                          _alreadyRenderedMessageIds.add(animKey);
                        }

                        final animatedBubble = AnimatedMessageBubble(
                          key: ValueKey<String>(animKey),
                          outgoing: isMe,
                          animate: _hasBuiltMessageListOnce &&
                              isFirstAppearance &&
                              SettingsManager.messageAnimationsEnabled.value,
                          flightOriginKey: isMe ? _inputAreaKey : null,
                          flightFromEdge: !isMe,
                          alignRight: shouldAlignRight,
                          child: RepaintBoundary(child: contentWithSender),
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
                                  final wasReacted = hasReaction('ext_$msgId',
                                      emoji, widget.server.username);
                                  toggleReaction('ext_$msgId', emoji,
                                      widget.server.username);
                                  if (msgIdInt != null)
                                    _serverToggleReaction(
                                        msgIdInt, emoji, wasReacted);
                                },
                                onAddReaction: (ctx2) {
                                  final msgIdInt = int.tryParse(msgId);
                                  openEmojiPicker(ctx2, 'ext_$msgId',
                                      widget.server.username,
                                      onAfterToggle: (emoji, wasReacted) {
                                    if (msgIdInt != null)
                                      _serverToggleReaction(
                                          msgIdInt, emoji, wasReacted);
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
                          key: ValueKey<String>('msg_$animKey'),
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
                                padding: const EdgeInsets.only(right: 8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
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

                            return KeyedSubtree(
                              key: _messageItemKey(animKey),
                              child: RawGestureDetector(
                                behavior: HitTestBehavior.translucent,
                                gestures: {
                                  LongPressGestureRecognizer:
                                      GestureRecognizerFactoryWithHandlers<
                                          LongPressGestureRecognizer>(
                                    () => LongPressGestureRecognizer(
                                        duration: _messageLongPressDuration),
                                    (instance) {
                                      instance.onLongPressStart = (_) =>
                                          _startExtDragSelection(
                                              msg, uniqueKey);
                                      instance.onLongPressMoveUpdate =
                                          (details) => _updateExtDragSelection(
                                              details.globalPosition);
                                      instance.onLongPressEnd =
                                          (_) => _endExtDragSelection();
                                    },
                                  ),
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: sel.active
                                      ? () =>
                                          _toggleExtMsgSelection(msg, uniqueKey)
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
                                    duration: const Duration(milliseconds: 150),
                                    color: isCurrentSearchMatch
                                        ? ecs.primary.withValues(alpha: 0.28)
                                        : isSearchMatch
                                            ? ecs.primary
                                                .withValues(alpha: 0.12)
                                            : isExtSelected
                                                ? ecs.primaryContainer
                                                    .withValues(alpha: 0.45)
                                                : (_scrollHighlightId != null &&
                                                        _scrollHighlightId ==
                                                            msg['id']
                                                                ?.toString())
                                                    ? ecs.primary
                                                        .withValues(alpha: 0.18)
                                                    : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: Row(
                                      children: [
                                        if (sel.active) extCheckmark,
                                        Expanded(
                                          child: AbsorbPointer(
                                            absorbing: sel.active,
                                            child: contentChild!,
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
                    ),
                  ),
                );
              },
            ),
            if (_pinnedMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                left: 16,
                right: 16,
                child: _buildExtPinnedBanner(context),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  (_pinnedMessage != null ? 68.0 : 8.0),
              left: 16,
              right: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                reverseDuration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity:
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.4),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                child: _showSearch
                    ? ChatSearchBar(
                        key: const ValueKey('csb'),
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        statsNotifier: _searchStats,
                        onChanged: _onSearchChanged,
                        onPrevious: _navigateSearchPrev,
                        onNext: _navigateSearchNext,
                        onClose: _closeSearch,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              bottom: 12 + MediaQuery.of(context).padding.bottom,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _inputEntryController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _inputEntryTranslateY.value),
                    child: Opacity(
                      opacity: _inputEntryOpacity.value,
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: _isReadOnlyChannel
                      ? ListenableBuilder(
                          listenable: Listenable.merge([
                            SettingsManager.elementOpacity,
                            SettingsManager.inputBarMaxWidth,
                            SettingsManager.elementBrightness,
                            SettingsManager.liquidGlassOnInput,
                            SettingsManager.liquidGlassInputQuality,
                            SettingsManager.liquidGlassInputBlur,
                            SettingsManager.liquidGlassInputTint,
                            SettingsManager.liquidGlassInputSaturation,
                            SettingsManager.liquidGlassInputChromatic,
                            SettingsManager.liquidGlassInputRefractive,
                            SettingsManager.liquidGlassInputLightIntensity,
                            SettingsManager.liquidGlassInputThickness,
                          ]),
                          builder: (_, __) {
                            final opacity =
                                SettingsManager.elementOpacity.value;
                            final width =
                                SettingsManager.inputBarMaxWidth.value;
                            final brightness =
                                SettingsManager.elementBrightness.value;
                            final isMobile =
                                !Platform.isWindows && !Platform.isLinux;
                            final useGlass = isMobile &&
                                SettingsManager.liquidGlassOnInput.value;
                            final baseColor = SettingsManager.getElementColor(
                              colorScheme.surfaceContainerHighest,
                              brightness,
                            );
                            final label = Container(
                              constraints: BoxConstraints(maxWidth: width),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: useGlass
                                  ? null
                                  : BoxDecoration(
                                      color:
                                          baseColor.withValues(alpha: opacity),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant
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
                            if (!useGlass) return label;
                            final quality =
                                SettingsManager.liquidGlassInputQuality.value;
                            final blur =
                                SettingsManager.liquidGlassInputBlur.value;
                            final tint =
                                SettingsManager.liquidGlassInputTint.value;
                            final saturation = SettingsManager
                                .liquidGlassInputSaturation.value;
                            final chromatic =
                                SettingsManager.liquidGlassInputChromatic.value;
                            final refractive = SettingsManager
                                .liquidGlassInputRefractive.value;
                            final lightIntensity = SettingsManager
                                .liquidGlassInputLightIntensity.value;
                            final thickness =
                                SettingsManager.liquidGlassInputThickness.value;
                            final glassQuality = switch (quality) {
                              LiquidGlassQuality.fast => GlassQuality.standard,
                              LiquidGlassQuality.medium => GlassQuality.minimal,
                              LiquidGlassQuality.quality =>
                                GlassQuality.premium,
                            };
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final tintColor = isDark
                                ? Colors.white.withValues(alpha: tint)
                                : Colors.black.withValues(alpha: tint);
                            final settings = LiquidGlassSettings(
                              thickness: thickness,
                              blur: blur,
                              chromaticAberration: chromatic,
                              lightIntensity: lightIntensity,
                              refractiveIndex: refractive,
                              saturation: saturation,
                              ambientStrength: 0.8,
                              lightAngle: 0.75 * pi,
                              glassColor: tintColor,
                            );
                            return GlassCard(
                              useOwnLayer: true,
                              settings: settings,
                              quality: glassQuality,
                              padding: EdgeInsets.zero,
                              shape: LiquidRoundedRectangle(borderRadius: 28),
                              clipBehavior: Clip.antiAlias,
                              child: label,
                            );
                          },
                        )
                      : !_isConnected
                          ? ValueListenableBuilder<double>(
                              valueListenable: SettingsManager.elementOpacity,
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
                                          colorScheme.surfaceContainerHighest,
                                          brightness,
                                        );
                                        return Container(
                                          constraints:
                                              BoxConstraints(maxWidth: width),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _isConnecting
                                                  ? null
                                                  : _connectToServer,
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                              child: Container(
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
                                                        .withValues(
                                                            alpha: 0.15),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (_isConnecting)
                                                      SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
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
                                                            colorScheme.primary,
                                                      ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _isConnecting
                                                          ? 'Connecting...'
                                                          : 'Connect to Server',
                                                      style: TextStyle(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Loading messages...',
                                                    style: TextStyle(
                                                      color:
                                                          colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                      constraints:
                                          BoxConstraints(maxWidth: width),
                                      child:
                                          _buildInputBar(context, colorScheme),
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
                  child: ValueListenableBuilder<double>(
                    valueListenable: _bottomBarHeight,
                    builder: (_, barHeight, __) =>
                        ValueListenableBuilder<ScrollDownButtonPosition>(
                      valueListenable: SettingsManager.scrollDownButtonPosition,
                      builder: (_, position, __) =>
                          ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.scrollDownButtonSize,
                        builder: (_, btnSize, __) {
                          final alignment = switch (position) {
                            ScrollDownButtonPosition.left =>
                              Alignment.bottomLeft,
                            ScrollDownButtonPosition.center =>
                              Alignment.bottomCenter,
                            ScrollDownButtonPosition.right =>
                              Alignment.bottomRight,
                          };
                          return Align(
                            alignment: alignment,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: barHeight +
                                    12 +
                                    MediaQuery.of(context).padding.bottom +
                                    16,
                                left: position == ScrollDownButtonPosition.left
                                    ? 16
                                    : 0,
                                right:
                                    position == ScrollDownButtonPosition.right
                                        ? 16
                                        : 0,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    SettingsManager.elementBrightness,
                                    SettingsManager.elementOpacity,
                                  ]),
                                  builder: (_, ___) {
                                    final baseColor =
                                        SettingsManager.getElementColor(
                                      colorScheme.surfaceContainerHighest,
                                      SettingsManager.elementBrightness.value,
                                    );
                                    return IconButton(
                                      splashRadius: btnSize / 2 + 4,
                                      padding: EdgeInsets.zero,
                                      icon: Container(
                                        width: btnSize,
                                        height: btnSize,
                                        decoration: BoxDecoration(
                                          color: baseColor.withValues(
                                              alpha: SettingsManager
                                                  .elementOpacity.value),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.outlineVariant
                                                .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: btnSize * 0.56,
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
                          );
                        },
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
