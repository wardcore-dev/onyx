// lib/screens/mesh_chat_screen.dart
//
// Mesh Chat screen — BLE/LAN-only messages between two users.
// Uses the same MessageBubble + ChatInputBar widgets as the regular ChatScreen.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import '../widgets/onyx_dialog.dart';
import '../utils/code_heuristic.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../enums/delivery_mode.dart';
import '../enums/liquid_glass_quality.dart';
import '../enums/mesh_delivery_status.dart';
import '../enums/scroll_down_button_position.dart';
import '../globals.dart';
import '../l10n/app_localizations.dart';
import '../managers/settings_manager.dart';
import '../managers/user_cache.dart';
import '../models/chat_message.dart';
import '../services/mesh/mesh_file_transfer.dart';
import '../services/mesh/mesh_manager.dart';
import '../widgets/animated_message_bubble.dart';
import 'chats_tab.dart' show getPreviewText;
import 'forward_screen.dart';
import 'mesh_graph_screen.dart' show showMeshRadarSheet;
import '../widgets/avatar_widget.dart';
import '../widgets/chat_background_layer.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/adaptive_glass_icon_button.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/empty_chat_placeholder.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/swipeable_message_wrapper.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../widgets/onyx_reminder_picker.dart';
import '../services/reminder_service.dart';

class MeshChatScreen extends StatefulWidget {
  const MeshChatScreen({
    super.key,
    required this.myUsername,
    required this.otherUsername,
  });

  final String myUsername;
  final String otherUsername;

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  final _inputAreaKey = GlobalKey();

  // Scroll-to/flash-highlight state for tapping a quoted reply preview
  // (mirrors ChatScreen's _scrollHighlightId/_scrollTargetId mechanism).
  String? _scrollHighlightId;
  Timer? _highlightTimer;
  final GlobalKey _scrollTargetKey = GlobalKey();
  String? _scrollTargetId;

  // ── Pinned message (mirrors ChatScreen's) ───────────────────────────────────
  Map<String, dynamic>? _pinnedMessage;

  // ── in-chat search (mirrors ChatScreen's) ─────────────────────────────────
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentMatchIdx = 0;
  List<int> _cachedSearchMatches = [];
  final _searchStats =
      ValueNotifier<({int current, int total})>((current: 0, total: 0));
  final _searchFocusNode = FocusNode();

  static const _clipboardChannel = MethodChannel('onyx/clipboard');

  // Entry animation for the input bar — matches ChatScreen's ("joined" pill
  // sliding/fading in), shown once per chat per app session.
  static final Set<String> _sessionInputAnimationsShown = {};
  late final AnimationController _inputEntryController;
  late final Animation<double> _inputEntryTranslateY;
  late final Animation<double> _inputEntryOpacity;
  final ValueNotifier<bool> _scrollDownVisible = ValueNotifier<bool>(false);
  late final _selectionNotifier =
      ValueNotifier<({bool active, Map<String, ChatMessage> selected})>(
          (active: false, selected: {}));

  // Drag-selection state
  static const Duration _longPressDuration = Duration(milliseconds: 375);
  static const double _dragEdgeZone = 80.0;
  static const double _dragMaxSpeed = 14.0;
  final GlobalKey _messageListViewportKey = GlobalKey();
  final Map<String, GlobalKey> _messageItemKeys = {};
  bool _isDragSelecting = false;
  String? _dragAnchorId;
  String? _dragCurrentId;
  Map<String, ChatMessage> _dragBase = {};
  Offset _lastDragPos = Offset.zero;
  List<String> _dragOrder = [];
  Map<String, int> _dragIndices = {};
  Map<String, ChatMessage> _dragLookup = {};
  Timer? _dragAutoScrollTimer;

  // Local ephemeral IDs seen this session — used to gate entry animations
  final _seenIds = <String>{};

  StreamSubscription<ChatMessage>? _incomingSub;
  StreamSubscription<({String messageId, MeshDeliveryStatus status})>?
      _deliverySub;
  late final ValueNotifier<int> _chatVersionNotifier;

  ChatMessage? _replyToMsg;

  String get _chatId {
    final ids = [widget.myUsername, widget.otherUsername]..sort();
    return ids.join(':');
  }

  String get _pinPrefsKey => 'pinned_mesh_$_chatId';

  // Live cache of "chatId|messageId" keys with an active reminder.
  Set<String> _reminderKeys = {};
  StreamSubscription? _reminderKeysSub;

  void _subscribeReminders() {
    if (widget.myUsername.isEmpty) return;
    _reminderKeysSub =
        ReminderService.watchActiveReminders(widget.myUsername).listen((rows) {
      if (!mounted) return;
      setState(() {
        _reminderKeys = rows.map((r) => '${r.chatId}|${r.messageId}').toSet();
      });
    });
  }

  bool _hasReminderSync(ChatMessage msg) {
    final messageId = msg.serverMessageId?.toString() ?? msg.id;
    return _reminderKeys.contains('$_chatId|$messageId');
  }

  /// If a reminder/search tap asked to land on a specific message in this
  /// mesh chat (see [setPendingMessageScrollTarget]), scroll to and
  /// highlight it once the message list is laid out.
  void _consumePendingMeshScrollTarget() {
    final pendingId = consumePendingMessageScrollTarget(_chatId);
    if (pendingId == null) return;
    void attempt([int retries = 6]) {
      if (!mounted) return;
      if (_scrollCtrl.hasClients) {
        _scrollToMessageById(int.tryParse(pendingId), localId: pendingId);
      } else if (retries > 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => attempt(retries - 1));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
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

  bool _isMsgPinned(ChatMessage msg) {
    final pinId = _pinnedMessage?['id']?.toString();
    if (pinId == null) return false;
    return pinId == msg.id;
  }

  void _togglePin(ChatMessage msg) {
    if (_isMsgPinned(msg)) {
      setState(() => _pinnedMessage = null);
    } else {
      setState(() {
        _pinnedMessage = {
          'id': msg.id,
          'content': msg.content,
          'sender': msg.from,
        };
      });
    }
    _savePinnedMessage();
  }

  List<ChatMessage> get _meshMessages {
    final root = rootScreenKey.currentState;
    final all =
        root != null ? (root.chats[_chatId] ?? []) : (chats[_chatId] ?? []);
    return all.where((m) => m.deliveryMode == DeliveryMode.bleMesh).toList();
  }

  @override
  void initState() {
    super.initState();

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
    _loadPinnedMessage();
    _consumePendingMeshScrollTarget();
    _subscribeReminders();

    // Pre-seed seen IDs so existing messages don't animate in on open
    for (final m in _meshMessages) {
      _seenIds.add(m.id);
    }

    // Listen to root_screen's per-chat version notifier so incoming messages
    // saved by root_screen trigger a rebuild here too.
    _chatVersionNotifier = getChatMessageVersion(_chatId);
    _chatVersionNotifier.addListener(_onChatVersionChanged);

    // Also subscribe directly to the mesh stream for instant display while
    // the screen is open — root_screen saves to chats and bumps the version,
    // but this gives us the rebuild signal one tick sooner.
    _incomingSub = MeshManager.instance.incomingMessages.listen(_onIncoming);

    _deliverySub =
        MeshManager.instance.meshDeliveryUpdates.listen(_onDeliveryUpdate);

    rootScreenKey.currentState?.setActiveMeshChat(_chatId);
    rootScreenKey.currentState?.clearBleUnread(_chatId);

    // With reverse:true the list starts at position 0 (visual bottom), but
    // a post-frame call ensures the controller is attached before we rely on it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final pixels = _scrollCtrl.hasClients ? _scrollCtrl.position.pixels : 0.0;
    _scrollDownVisible.value = pixels > 1.0;
  }

  void _checkInputAnimationState() {
    if (!_sessionInputAnimationsShown.contains(_chatId)) {
      _inputEntryController.forward();
      _sessionInputAnimationsShown.add(_chatId);
    } else {
      _inputEntryController.value = 1.0;
    }
  }

  // ── Scroll-to / flash-highlight a message (tap on a quoted reply) ──────────

  /// Chronological messages interleaved with day separators, then reversed —
  /// matches the ListView's reverse:true convention (index 0 = newest).
  List<Object> _reversedDisplayItems([List<ChatMessage>? msgs]) {
    final source = msgs ?? _meshMessages;
    final items = <Object>[];
    DateTime? currentDay;
    for (final msg in source) {
      final msgDate = DateTime(msg.time.year, msg.time.month, msg.time.day);
      if (currentDay == null || currentDay != msgDate) {
        items.add(msgDate);
        currentDay = msgDate;
      }
      items.add(msg);
    }
    return items.reversed.toList();
  }

  void _flashHighlight(String id) {
    _highlightTimer?.cancel();
    setState(() => _scrollHighlightId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scrollHighlightId = null);
    });
  }

  void _scrollToMessageById(int? serverId, {String? localId}) {
    if (serverId == null && localId == null) return;
    final items = _reversedDisplayItems();

    int? foundIdx;
    String? foundId;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is ChatMessage) {
        if (serverId != null && int.tryParse(item.id) == serverId) {
          foundIdx = i;
          foundId = item.id;
          break;
        }
        if (localId != null && item.id == localId) {
          foundIdx = i;
          foundId = item.id;
          break;
        }
      }
    }
    if (foundIdx == null || foundId == null) return;
    if (!_scrollCtrl.hasClients) return;

    final totalItems = items.length;
    final maxExt = _scrollCtrl.position.maxScrollExtent;
    final proportional =
        totalItems > 0 ? (foundIdx / totalItems) * maxExt : 0.0;

    setState(() => _scrollTargetId = foundId);

    _scrollCtrl
        .animateTo(proportional.clamp(0.0, maxExt),
            duration: const Duration(milliseconds: 350), curve: Curves.easeOut)
        .then((_) {
      void tryEnsureVisible([int retries = 2]) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _scrollTargetKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                alignment: 0.5);
            if (mounted) setState(() => _scrollTargetId = null);
          } else if (retries > 0) {
            tryEnsureVisible(retries - 1);
          } else {
            if (mounted) setState(() => _scrollTargetId = null);
          }
        });
      }

      tryEnsureVisible();
    });

    _flashHighlight(foundId);
  }

  // ── In-chat search (mirrors ChatScreen's) ───────────────────────────────────

  void _closeSearch() {
    _searchController.clear();
    _searchStats.value = (current: 0, total: 0);
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _currentMatchIdx = 0;
      _cachedSearchMatches = [];
    });
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
    setState(() {
      _showSearch = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  void _scrollToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients || _cachedSearchMatches.isEmpty) {
        return;
      }
      final items = _reversedDisplayItems();
      final totalItems = items.length;
      if (totalItems == 0) return;
      final matchItemIdx = _cachedSearchMatches[_currentMatchIdx];
      final maxExtent = _scrollCtrl.position.maxScrollExtent;
      final target =
          (maxExtent * matchItemIdx / totalItems).clamp(0.0, maxExtent);
      _scrollCtrl.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  GlobalKey _messageItemKey(String id) =>
      _messageItemKeys.putIfAbsent(id, () => GlobalKey());

  void _exitSelectionMode() {
    _selectionNotifier.value = (active: false, selected: {});
  }

  void _startReplyingToMeshMessage(ChatMessage msg) {
    setState(() => _replyToMsg = msg);
    _focusNode.requestFocus();
  }

  void _cancelMeshReply() {
    setState(() => _replyToMsg = null);
  }

  void _retryMeshMessage(ChatMessage msg) {
    // For file messages re-send the actual file bytes rather than a text packet.
    // Sending the text content would arrive on the recipient with no MIME type
    // and display as a generic file icon instead of an audio/image player.
    if (msg.content.startsWith('MESH_FILE:') && msg.meshFileLocalPath != null) {
      rootScreenKey.currentState?.removeMeshMessages(_chatId, [msg.id]);
      unawaited(() async {
        final file = File(msg.meshFileLocalPath!);
        if (!await file.exists()) return;
        await _sendFile(
          fileBytes: await file.readAsBytes(),
          filename:
              msg.meshFileName ?? msg.content.substring('MESH_FILE:'.length),
          mimeType: msg.meshFileMimeType ?? 'application/octet-stream',
          senderLocalPath: msg.meshFileLocalPath,
        );
      }());
    } else {
      msg.meshDeliveryStatus = MeshDeliveryStatus.sending;
      setState(() {});
      unawaited(MeshManager.instance.sendMessage(msg, widget.otherUsername));
    }
  }

  /// Desktop right-click context menu — mirrors ChatScreen's floating menu
  /// but scoped to what mesh messages actually support: reply and delete.
  /// Delete is local-only (mesh has no server), so it's available on both
  /// our own and the other person's messages — deleting theirs just hides
  /// it on our side.
  List<DesktopMenuItem>? _buildMeshDesktopMenuItems(ChatMessage msg) {
    if (!isDesktop) return null;
    final l = AppLocalizations.of(context);
    return [
      DesktopMenuItem(
        icon: Icons.reply_rounded,
        label: l.reply,
        onPressed: () => _startReplyingToMeshMessage(msg),
      ),
      DesktopMenuItem(
        icon: _isMsgPinned(msg)
            ? Icons.push_pin_outlined
            : Icons.push_pin_rounded,
        label: _isMsgPinned(msg) ? l.unpin : l.pin,
        onPressed: () => _togglePin(msg),
      ),
      DesktopMenuItem(
        icon: Icons.delete_outline_rounded,
        label: l.delete,
        type: ContextMenuButtonType.delete,
        color: Colors.red.shade400,
        onPressed: () =>
            rootScreenKey.currentState?.removeMeshMessages(_chatId, [msg.id]),
      ),
    ];
  }

  void _showMeshMessageMenu(ChatMessage msg) async {
    final reminderChatId = _chatId;
    final reminderMsgId = msg.serverMessageId?.toString() ?? msg.id;
    final hasReminder = await ReminderService.hasActiveReminder(
        widget.myUsername, reminderChatId, reminderMsgId);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MeshMessageActionsSheet(
        msg: msg,
        isPinned: _isMsgPinned(msg),
        hasReminder: hasReminder,
        onReminderToggle: () {
          Navigator.of(ctx).pop();
          _handleMeshReminderToggle(
            msg: msg,
            hasReminder: hasReminder,
            chatId: reminderChatId,
            messageId: reminderMsgId,
          );
        },
        onReply: () {
          Navigator.of(ctx).pop();
          _startReplyingToMeshMessage(msg);
        },
        onPin: () {
          Navigator.of(ctx).pop();
          _togglePin(msg);
        },
        onDelete: () {
          Navigator.of(ctx).pop();
          rootScreenKey.currentState?.removeMeshMessages(_chatId, [msg.id]);
        },
      ),
    );
  }

  Future<void> _handleMeshReminderToggle({
    required ChatMessage msg,
    required bool hasReminder,
    required String chatId,
    required String messageId,
  }) async {
    final l = AppLocalizations.of(context);
    if (hasReminder) {
      await ReminderService.cancelReminder(
          widget.myUsername, chatId, messageId);
      rootScreenKey.currentState?.showSnack(l.reminderCancelled);
      return;
    }
    final accentColorArgb = Theme.of(context).colorScheme.primary.toARGB32();
    final picked = await showOnyxReminderPicker(context);
    if (picked == null) return;
    await ReminderService.scheduleReminder(
      accountId: widget.myUsername,
      messageId: messageId,
      accentColorArgb: accentColorArgb,
      chatType: 'mesh',
      chatId: chatId,
      chatTitle: widget.otherUsername,
      messagePreview: getPreviewText(msg.content),
      otherUsername: widget.otherUsername,
      scheduledAt: picked,
    );
    rootScreenKey.currentState?.showSnack(l.reminderSet);
  }

  void _toggleMessageSelection(ChatMessage msg) {
    final cur = _selectionNotifier.value;
    final next = Map<String, ChatMessage>.from(cur.selected);
    if (next.containsKey(msg.id)) {
      next.remove(msg.id);
      _selectionNotifier.value = (active: next.isNotEmpty, selected: next);
    } else {
      next[msg.id] = msg;
      _selectionNotifier.value = (active: true, selected: next);
    }
  }

  void _startMessageDragSelection(ChatMessage msg) {
    final cur = _selectionNotifier.value;
    if (!cur.active) HapticFeedback.mediumImpact();
    final next = Map<String, ChatMessage>.from(cur.selected)..[msg.id] = msg;
    _selectionNotifier.value = (active: true, selected: next);
    _dragBase = Map<String, ChatMessage>.from(next);
    _dragAnchorId = msg.id;
    _dragCurrentId = msg.id;
    _isDragSelecting = true;
    _selectMessageRangeTo(msg.id);
  }

  void _updateMessageDragSelection(Offset globalPosition) {
    if (!_isDragSelecting) return;
    _lastDragPos = globalPosition;
    final hoveredId = _messageIdAtGlobal(globalPosition);
    if (hoveredId != null && hoveredId != _dragCurrentId) {
      _selectMessageRangeTo(hoveredId);
    }
    _updateDragAutoScroll();
  }

  void _endMessageDragSelection() {
    _isDragSelecting = false;
    _dragAnchorId = null;
    _dragCurrentId = null;
    _dragBase = {};
    _stopDragAutoScroll();
  }

  void _updateDragAutoScroll() {
    final box = _messageListViewportKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(_lastDragPos);
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
    if (!_isDragSelecting || !_scrollCtrl.hasClients) {
      _stopDragAutoScroll();
      return;
    }
    final box = _messageListViewportKey.currentContext?.findRenderObject()
        as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(_lastDragPos);
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
    final newOffset = (_scrollCtrl.offset + speed)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.jumpTo(newOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDragSelecting) return;
      final hoveredId = _messageIdAtGlobal(_lastDragPos);
      if (hoveredId != null && hoveredId != _dragCurrentId) {
        _selectMessageRangeTo(hoveredId);
      }
    });
  }

  void _stopDragAutoScroll() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
  }

  void _selectMessageRangeTo(String id) {
    final anchorId = _dragAnchorId;
    if (anchorId == null) return;
    final start = _dragIndices[anchorId];
    final end = _dragIndices[id];
    if (start == null || end == null) return;
    final from = start < end ? start : end;
    final to = start < end ? end : start;
    final next = Map<String, ChatMessage>.from(_dragBase);
    for (int i = from; i <= to; i++) {
      final key = _dragOrder[i];
      final m = _dragLookup[key];
      if (m != null) next[key] = m;
    }
    _dragCurrentId = id;
    _selectionNotifier.value = (active: true, selected: next);
  }

  String? _messageIdAtGlobal(Offset globalPosition) {
    String? bestId;
    double bestDist = double.infinity;
    for (final id in _dragOrder) {
      final ctx = _messageItemKeys[id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final local = box.globalToLocal(globalPosition);
      if (local.dy < 0 || local.dy > box.size.height) continue;
      final dist = (local.dy - box.size.height / 2).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestId = id;
      }
    }
    return bestId;
  }

  // Map insertion order (`.values`) reflects selection/drag-recompute order,
  // not chronological order — always re-sort by `time` first.
  List<ChatMessage> get _selectedMessagesChronological =>
      _selectionNotifier.value.selected.values.toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  void _copySelected() {
    final texts =
        _selectedMessagesChronological.map((m) => m.content).join('\n\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value).msgCopied);
    }
    _exitSelectionMode();
  }

  void _forwardSelected() {
    final contents =
        _selectedMessagesChronological.map((m) => m.content).toList();
    if (contents.isEmpty) return;
    _exitSelectionMode();
    ForwardScreen.show(context, contents);
  }

  Future<void> _confirmDeleteSelected() async {
    final toDelete = _selectionNotifier.value.selected.values.toList();
    if (toDelete.isEmpty) return;
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: AppLocalizations.of(context).deleteMessagesQuestion,
      message:
          'Delete ${toDelete.length} message${toDelete.length > 1 ? 's' : ''}?',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed != true) return;
    rootScreenKey.currentState
        ?.removeMeshMessages(_chatId, toDelete.map((m) => m.id).toList());
    _exitSelectionMode();
  }

  void _onChatVersionChanged() {
    if (mounted) setState(() {});
  }

  void _onDeliveryUpdate(
      ({String messageId, MeshDeliveryStatus status}) update) {
    if (!mounted) return;
    final messages = _meshMessages;
    final idx = messages.indexWhere((m) => m.id == update.messageId);
    if (idx == -1) return;
    messages[idx].meshDeliveryStatus = update.status;
    setState(() {});
  }

  void _onIncoming(ChatMessage msg) {
    if (msg.from != widget.otherUsername && msg.to != widget.otherUsername) {
      return;
    }
    // The actual message is persisted by root_screen's _handleIncomingMeshMessage.
    // We only trigger a rebuild; _meshMessages getter reads from global chats.
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  // ── File attachment ────────────────────────────────────────────────────────

  Future<void> _onAttachPressed() async {
    if (kIsWeb) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            AppLocalizations.of(context).meshErrorAttachmentsUnsupported);
      return;
    }

    List<String>? paths;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      paths = await showMediaPickerSheet(context);
    } else {
      try {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.any, allowMultiple: true);
        paths = result?.files.map((f) => f.path).whereType<String>().toList();
      } catch (e) {
        if (mounted)
          rootScreenKey.currentState?.showSnack(
              '${AppLocalizations.of(context).meshErrorPickFileFailed}: $e');
      }
    }
    if (paths == null || paths.isEmpty) return;

    for (final path in paths) {
      await _confirmAndSendFilePath(path);
    }
  }

  // ── Clipboard paste (mirrors ChatScreen._handlePasteFromClipboard) ─────────

  Future<void> _handlePasteFromClipboard() async {
    try {
      List<Object?>? rawPaths;
      try {
        rawPaths = await _clipboardChannel
            .invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (_) {}
      final filePaths =
          rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        debugPrint('[clipboard] File paths from clipboard: $filePaths');
        if (!mounted) return;
        for (final path in filePaths) {
          await _confirmAndSendFilePath(path);
        }
        return;
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
        debugPrint(
            '[clipboard] Image pasted from native clipboard: ${tempFile.path}');
        if (!mounted) return;
        await _confirmAndSendFilePath(tempFile.path);
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
          await _confirmAndSendFilePath(filePath);
          return;
        }
      }

      debugPrint('[clipboard] No supported format found in clipboard');
    } catch (e, stackTrace) {
      debugPrint('[clipboard] Error pasting from clipboard: $e');
      debugPrint('[clipboard] Stack trace: $stackTrace');
    }
  }

  Future<void> _handleContentInsertion(KeyboardInsertedContent data) async {
    try {
      Uint8List? bytes = data.data;
      if (bytes == null && data.uri.isNotEmpty) {
        try {
          bytes = await _clipboardChannel.invokeMethod<Uint8List>(
            'readContentUri',
            {'uri': data.uri},
          );
        } catch (_) {}
      }
      if (bytes != null && bytes.isNotEmpty && mounted) {
        final ext =
            data.mimeType.contains('/') ? data.mimeType.split('/').last : 'png';
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await tempFile.writeAsBytes(bytes);
        await _confirmAndSendFilePath(tempFile.path);
      }
    } catch (e) {
      debugPrint('[ContentInsert] Error: $e');
    }
  }

  Future<void> _confirmAndSendFilePath(String path) async {
    if (!mounted) return;
    if (SettingsManager.confirmFileUpload.value) {
      await showDialog<void>(
        context: context,
        builder: (_) => FilePreviewDialog(
          filePath: path,
          onSend: () => _sendFilePath(path),
          onCancel: () {},
        ),
      );
    } else {
      await _sendFilePath(path);
    }
  }

  Future<void> _sendFilePath(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final ext = path.contains('.') ? path.split('.').last : '';
      final mime = _mimeFromExtension(ext);
      await _sendFile(
          fileBytes: bytes,
          filename: file.uri.pathSegments.last,
          mimeType: mime,
          senderLocalPath: path);
    } catch (e) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            '${AppLocalizations.of(context).meshErrorSendFileFailed}: $e');
    }
  }

  Future<void> _sendFile({
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
    String? senderLocalPath,
  }) async {
    final neighbor =
        MeshManager.instance.neighbors.neighborByUsername(widget.otherUsername);
    if (neighbor == null) {
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value)
              .meshErrorOutOfRange(widget.otherUsername));
      return;
    }

    final validationError = MeshFileTransferService.instance.validateTransfer(
      mimeType: mimeType,
      fileSize: fileBytes.length,
      hasUdp: neighbor.hasUdpAddress,
    );
    if (validationError != null) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        final msg = switch (validationError) {
          MeshTransferValidationError.videoRequiresWifi =>
            l.meshErrorVideoWifiOnly,
          MeshTransferValidationError.fileTooLargeForBle =>
            l.meshErrorFileTooLargeForBle,
          MeshTransferValidationError.fileTooLarge => l.meshErrorFileTooLarge,
        };
        rootScreenKey.currentState?.showSnack(msg);
      }
      return;
    }

    final msg = await MeshFileTransferService.instance.sendFile(
      fileBytes: fileBytes,
      filename: filename,
      mimeType: mimeType,
      recipient: neighbor,
      myUsername: widget.myUsername,
      transport: neighbor.hasUdpAddress ? 'wifi' : 'ble',
    );
    if (msg == null) return;

    if (senderLocalPath != null) msg.meshFileLocalPath = senderLocalPath;
    rootScreenKey.currentState?.addMeshMessage(_chatId, msg);
    _scrollToBottom();
  }

  static String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/avi';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/m4a';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _stopRecordingAndSendVoice() async {
    final path = await rootScreenKey.currentState?.stopRecordingForMesh();
    if (path == null) return;
    if (!mounted) return;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final filename = path.split('/').last.split('\\').last;
      final mime = filename.endsWith('.m4a') ? 'audio/m4a' : 'audio/wav';

      Future<void> doSend() async {
        await _sendFile(
            fileBytes: bytes,
            filename: filename,
            mimeType: mime,
            senderLocalPath: path);
      }

      if (SettingsManager.confirmVoiceUpload.value) {
        final duration = Duration(
          milliseconds: (bytes.length / 16.0).round(),
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => VoiceConfirmDialog(
            duration: duration,
            onSend: () => unawaited(doSend()),
            onCancel: () {
              try {
                file.deleteSync();
              } catch (_) {}
            },
          ),
        );
      } else {
        await doSend();
      }
    } catch (e) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            '${AppLocalizations.of(context).meshErrorSendVoiceFailed}: $e');
    }
  }

  // ── Send text ──────────────────────────────────────────────────────────────

  Future<void> _send() async {
    var text = _ctrl.text.trim();
    if (text.isEmpty) return;

    if (looksLikeCode(text)) {
      final l = AppLocalizations.of(context);
      final sendAsCode = await showOnyxConfirmDialog(
        context: context,
        title: l.sendAsCodeTitle,
        message: l.sendAsCodeContent,
        confirmLabel: l.sendAsCode,
        cancelLabel: l.sendAsPlainText,
        icon: Icons.code_rounded,
      );
      if (!mounted) return;
      if (sendAsCode == null) return;
      if (sendAsCode) {
        text = '```${detectCodeLanguage(text)}\n$text\n```';
      }
    }

    _ctrl.clear();

    final replyTo = _replyToMsg;
    if (replyTo != null) setState(() => _replyToMsg = null);

    // Determine transport before adding to UI so the badge shows immediately.
    final neighbor =
        MeshManager.instance.neighbors.neighborByUsername(widget.otherUsername);
    final String? transport =
        neighbor == null ? null : (neighbor.hasUdpAddress ? 'wifi' : 'ble');

    final msg = ChatMessage(
      id: generateLocalMessageId(),
      from: widget.myUsername,
      to: widget.otherUsername,
      content: text,
      outgoing: true,
      delivered: false,
      time: DateTime.now(),
      deliveryMode: DeliveryMode.bleMesh,
      meshDeliveryStatus: MeshDeliveryStatus.sending,
      meshTransportUsed: transport,
      replyToId: replyTo != null ? int.tryParse(replyTo.id) : null,
      replyToSender: replyTo?.from,
      replyToContent: replyTo?.content,
    );

    rootScreenKey.currentState?.addMeshMessage(_chatId, msg);
    _scrollToBottom();
    unawaited(MeshManager.instance.sendMessage(msg, widget.otherUsername));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (SettingsManager.smoothScrollEnabled.value) {
        _scrollCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        final distance = _scrollCtrl.position.pixels.abs();
        if (distance > 200 || distance <= 1.5) {
          _scrollCtrl.jumpTo(0.0);
        } else {
          _scrollCtrl.animateTo(
            0.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    rootScreenKey.currentState?.setActiveMeshChat(null);
    _reminderKeysSub?.cancel();
    _chatVersionNotifier.removeListener(_onChatVersionChanged);
    _incomingSub?.cancel();
    _deliverySub?.cancel();
    _dragAutoScrollTimer?.cancel();
    _highlightTimer?.cancel();
    _inputEntryController.dispose();
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _scrollDownVisible.dispose();
    _selectionNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchStats.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDesktop,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            const ChatBackgroundLayer(),
            _buildMessageList(context),
            if (_pinnedMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70 + 8,
                left: 16,
                right: 16,
                child: _buildPinnedBanner(context),
              ),
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  70 +
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
                        key: const ValueKey('mesh_csb'),
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
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildInputBar(context),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _scrollDownVisible,
              builder: (_, visible, child) => AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(ignoring: !visible, child: child),
              ),
              child: ValueListenableBuilder<ScrollDownButtonPosition>(
                valueListenable: SettingsManager.scrollDownButtonPosition,
                builder: (_, position, __) => ValueListenableBuilder<double>(
                  valueListenable: SettingsManager.scrollDownButtonSize,
                  builder: (_, btnSize, __) {
                    final alignment = switch (position) {
                      ScrollDownButtonPosition.left => Alignment.bottomLeft,
                      ScrollDownButtonPosition.center => Alignment.bottomCenter,
                      ScrollDownButtonPosition.right => Alignment.bottomRight,
                    };
                    return Align(
                      alignment: alignment,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: 72 +
                              12.0 +
                              MediaQuery.of(context).padding.bottom +
                              16,
                          left: position == ScrollDownButtonPosition.left
                              ? 16
                              : 0,
                          right: position == ScrollDownButtonPosition.right
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
                              final cs = Theme.of(context).colorScheme;
                              final baseColor = SettingsManager.getElementColor(
                                cs.surfaceContainerHighest,
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
                                      color: cs.outlineVariant
                                          .withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_downward,
                                    size: btnSize * 0.56,
                                    color: cs.onSurface.withValues(alpha: 0.7),
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
          ],
        ),
      ), // Scaffold
    ); // PopScope
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      toolbarHeight: 70,
      leadingWidth: isDesktop ? 162 : 66,
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: [
        ValueListenableBuilder<
            ({bool active, Map<String, ChatMessage> selected})>(
          valueListenable: _selectionNotifier,
          builder: (ctx, sel, _) {
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
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
                child: child,
              ),
              child: sel.active
                  ? AnimatedBuilder(
                      key: const ValueKey('mesh-sel-actions'),
                      animation: Listenable.merge([
                        SettingsManager.elementOpacity,
                        SettingsManager.elementBrightness,
                      ]),
                      builder: (ctx2, _) {
                        final op = SettingsManager.elementOpacity.value;
                        final br = SettingsManager.elementBrightness.value;
                        final cs = Theme.of(ctx2).colorScheme;
                        final btnBg = SettingsManager.getElementColor(
                          cs.surfaceContainerHighest,
                          br,
                        ).withValues(alpha: op);
                        final btnBorder =
                            cs.outlineVariant.withValues(alpha: 0.3);

                        Widget selBtn(IconData ic, Color? icColor,
                                VoidCallback onTap) =>
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: onTap,
                                  child: AdaptiveGlassIconButton(
                                    backgroundColor: btnBg,
                                    borderColor: btnBorder,
                                    child: Center(
                                        child: Icon(ic,
                                            size: 20,
                                            color: icColor ??
                                                cs.onSurface
                                                    .withValues(alpha: 0.75))),
                                  ),
                                ),
                              ),
                            );

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            selBtn(Icons.copy_rounded, null, _copySelected),
                            selBtn(
                                Icons.forward_rounded, null, _forwardSelected),
                            selBtn(Icons.delete_outline_rounded, cs.error,
                                _confirmDeleteSelected),
                            const SizedBox(width: 8),
                          ],
                        );
                      },
                    )
                  : AnimatedBuilder(
                      key: const ValueKey('mesh-normal-actions'),
                      animation: Listenable.merge([
                        SettingsManager.elementOpacity,
                        SettingsManager.elementBrightness,
                      ]),
                      builder: (ctx2, _) {
                        final op = SettingsManager.elementOpacity.value;
                        final br = SettingsManager.elementBrightness.value;
                        final cs = Theme.of(ctx2).colorScheme;
                        final btnBg = SettingsManager.getElementColor(
                          cs.surfaceContainerHighest,
                          br,
                        ).withValues(alpha: op);
                        final btnBorder =
                            cs.outlineVariant.withValues(alpha: 0.3);
                        final iconColor = cs.onSurface.withValues(alpha: 0.75);

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message: 'Search (Ctrl+F)',
                                child: GestureDetector(
                                  onTap: () {
                                    if (_showSearch) {
                                      _closeSearch();
                                    } else {
                                      _openSearch();
                                    }
                                  },
                                  child: AdaptiveGlassIconButton(
                                    backgroundColor: btnBg,
                                    borderColor: btnBorder,
                                    child: Center(
                                      child: Icon(Icons.search,
                                          size: 20, color: iconColor),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            AdaptiveGlassIconButton(
                              backgroundColor: btnBg,
                              borderColor: btnBorder,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert,
                                    size: 20, color: iconColor),
                                itemBuilder: (_) {
                                  final mode =
                                      SettingsManager.meshTransportMode.value;
                                  Widget modeItem(
                                      String value, IconData ic, String label) {
                                    final selected = mode == value;
                                    return Row(children: [
                                      Icon(ic,
                                          size: 18,
                                          color: selected ? cs.primary : null),
                                      const SizedBox(width: 10),
                                      Text(label,
                                          style: selected
                                              ? TextStyle(
                                                  color: cs.primary,
                                                  fontWeight: FontWeight.w600)
                                              : null),
                                      if (selected) ...[
                                        const Spacer(),
                                        Icon(Icons.check,
                                            size: 16, color: cs.primary),
                                      ],
                                    ]);
                                  }

                                  final l = AppLocalizations.of(context);
                                  return [
                                    PopupMenuItem<String>(
                                      value: 'radar',
                                      child: Row(children: [
                                        const Icon(Icons.radar_rounded,
                                            size: 18),
                                        const SizedBox(width: 10),
                                        Text(l.meshMenuRadar),
                                      ]),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'diag',
                                      child: Row(children: [
                                        const Icon(Icons.bug_report_outlined,
                                            size: 18),
                                        const SizedBox(width: 10),
                                        Text(l.meshMenuDiagnostics),
                                      ]),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'mode_auto',
                                      child: modeItem(
                                          'auto',
                                          Icons.auto_mode_rounded,
                                          l.meshMenuModeAuto),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'mode_wifi',
                                      child: modeItem(
                                          'wifi',
                                          Icons.wifi_rounded,
                                          l.meshMenuModeWifi),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'mode_ble',
                                      child: modeItem(
                                          'ble',
                                          Icons.bluetooth_rounded,
                                          l.meshMenuModeBluetooth),
                                    ),
                                  ];
                                },
                                onSelected: (v) {
                                  if (v == 'radar') {
                                    showMeshRadarSheet(context);
                                  } else if (v == 'diag') {
                                    _showDiagnostics(context);
                                  } else if (v == 'mode_auto') {
                                    SettingsManager.setMeshTransportMode(
                                        'auto');
                                  } else if (v == 'mode_wifi') {
                                    SettingsManager.setMeshTransportMode(
                                        'wifi');
                                  } else if (v == 'mode_ble') {
                                    _selectBleTransportMode();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        );
                      },
                    ),
            );

            // Mirror ChatScreen's AppBar exactly: on desktop the actions
            // column is pinned to the same fixed width as leadingWidth so
            // the title lands dead-center; on mobile it just animates size
            // changes instead (no fixed width available there).
            if (isDesktop) {
              return SizedBox(
                width: 162,
                child: Align(alignment: Alignment.centerRight, child: switcher),
              );
            }
            return AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.centerRight,
              child: switcher,
            );
          },
        ),
      ],
      leading: ValueListenableBuilder<
          ({bool active, Map<String, ChatMessage> selected})>(
        valueListenable: _selectionNotifier,
        builder: (ctx, sel, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: child,
          ),
          child: AnimatedBuilder(
            key: ValueKey(sel.active),
            animation: Listenable.merge([
              SettingsManager.elementOpacity,
              SettingsManager.elementBrightness,
            ]),
            builder: (ctx2, __) {
              final op = SettingsManager.elementOpacity.value;
              final br = SettingsManager.elementBrightness.value;
              final cs = Theme.of(ctx2).colorScheme;
              final bgColor = SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                br,
              ).withValues(alpha: op);
              final borderColor = cs.outlineVariant.withValues(alpha: 0.3);
              final button = AdaptiveGlassIconButton(
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
                      ? _exitSelectionMode
                      : () => _goBackToChatScreen(ctx2),
                ),
              );
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: isDesktop
                    ? Align(alignment: Alignment.centerLeft, child: button)
                    : Center(child: button),
              );
            },
          ),
        ),
      ),
      title: ValueListenableBuilder<
          ({bool active, Map<String, ChatMessage> selected})>(
        valueListenable: _selectionNotifier,
        builder: (ctx, sel, _) => ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
                      builder: (ctx2, __) {
                        final op = SettingsManager.elementOpacity.value;
                        final br = SettingsManager.elementBrightness.value;
                        final cs = Theme.of(ctx2).colorScheme;
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
                      // Only rare, discrete settings changes drive this outer
                      // builder — NOT MeshManager.instance.neighbors, which
                      // notifies on every UDP/BLE discovery tick (far more
                      // often than the displayed status actually changes).
                      // Rebuilding the whole pill (including the avatar) on
                      // every one of those ticks was what caused the header
                      // to visibly jitter; the status text below is now
                      // isolated in its own inner AnimatedBuilder so only
                      // that small Row reacts to neighbor-table churn,
                      // mirroring how ChatScreen isolates its online/typing
                      // status from the outer title builder.
                      animation: Listenable.merge([
                        SettingsManager.elementOpacity,
                        SettingsManager.elementBrightness,
                      ]),
                      builder: (ctx2, __) {
                        final op = SettingsManager.elementOpacity.value;
                        final br = SettingsManager.elementBrightness.value;
                        final cs = Theme.of(ctx2).colorScheme;
                        final bgColor = SettingsManager.getElementColor(
                          cs.surfaceContainerHighest,
                          br,
                        ).withValues(alpha: op);
                        final borderColor =
                            cs.outlineVariant.withValues(alpha: 0.3);

                        final userInfo =
                            UserCache.getSync(widget.otherUsername);
                        final displayName =
                            userInfo?.displayName ?? widget.otherUsername;
                        final isWide = MediaQuery.sizeOf(ctx2).width > 700;

                        final textContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            AnimatedBuilder(
                              animation: MeshManager.instance.neighbors,
                              builder: (ctx3, _) {
                                final neighbor = MeshManager.instance.neighbors
                                    .neighborByUsername(widget.otherUsername);
                                final inRange = neighbor != null;

                                final String statusText;
                                final Color statusColor;
                                final IconData statusIcon;
                                if (!inRange) {
                                  statusText = AppLocalizations.of(ctx3)
                                      .meshChatOutOfRange;
                                  statusColor =
                                      cs.onSurface.withValues(alpha: 0.45);
                                  statusIcon = Icons.wifi_off_rounded;
                                } else if (neighbor.isLan) {
                                  statusText = 'Wi-Fi';
                                  statusColor =
                                      const Color(0xFF34C759); // зелёный
                                  statusIcon = Icons.wifi_rounded;
                                } else {
                                  statusText = 'Bluetooth';
                                  statusColor =
                                      const Color(0xFF2196F3); // синий
                                  statusIcon = Icons.bluetooth_rounded;
                                }

                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon,
                                        size: 11, color: statusColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                          fontSize: 12, color: statusColor),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                        final pill = AdaptiveGlassPill(
                          backgroundColor: bgColor,
                          borderColor: borderColor,
                          child: Row(
                            mainAxisSize:
                                isWide ? MainAxisSize.min : MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AvatarWidget(
                                key: ValueKey(
                                    'mesh-avatar-${widget.otherUsername}'),
                                username: widget.otherUsername,
                                tokenProvider: avatarTokenProvider,
                                avatarBaseUrl: serverBase,
                                size: 40.0,
                                editable: false,
                              ),
                              const SizedBox(width: 12),
                              if (isWide)
                                textContent
                              else
                                Expanded(child: textContent),
                            ],
                          ),
                        );
                        return isWide
                            ? Align(alignment: Alignment.center, child: pill)
                            : pill;
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pinned message banner (mirrors ChatScreen's) ────────────────────────────

  Widget _buildPinnedBanner(BuildContext context) {
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
          final pinId = msg['id']?.toString();
          return GestureDetector(
            onTap: () => _scrollToMessageById(null, localId: pinId),
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

  // ── Message list ───────────────────────────────────────────────────────────

  static bool _isMeshImageReady(ChatMessage m) =>
      m.meshFileId != null &&
      m.meshFileLocalPath != null &&
      MeshFileTransferService.isImage(m.meshFileMimeType ?? '');

  Widget _buildDaySeparator(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    final l = AppLocalizations.of(context);
    String dayText;
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
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dayText,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msgs = _meshMessages;

    if (msgs.isEmpty) {
      final emptyText = AppLocalizations.of(context).meshChatEmpty;
      final parts = emptyText.split('\n');
      return EmptyChatPlaceholder(
        label: parts.first,
        hint: parts.length > 1 ? parts.sublist(1).join(' ') : null,
      );
    }

    // Reversed so newest messages are at visual bottom (index 0 = last message).
    final reversed = msgs.reversed.toList();

    // Interleave day separators (built oldest→newest, like chat_screen does,
    // then reversed together with the messages so they land above the first
    // message of each day once ListView's reverse:true flips the render
    // order back to normal reading order).
    final reversedDisplay = _reversedDisplayItems(msgs);

    // Update search matches (side-effect during build is safe here because
    // we only assign fields, no setState).
    if (_showSearch && _searchQuery.isNotEmpty) {
      _cachedSearchMatches = reversedDisplay
          .asMap()
          .entries
          .where((e) =>
              e.value is ChatMessage &&
              (e.value as ChatMessage)
                  .content
                  .toLowerCase()
                  .contains(_searchQuery))
          .map((e) => e.key)
          .toList();
      final clampedIdx = _cachedSearchMatches.isEmpty
          ? 0
          : _currentMatchIdx.clamp(0, _cachedSearchMatches.length - 1);
      final stats = (
        current: _cachedSearchMatches.isEmpty ? 0 : clampedIdx + 1,
        total: _cachedSearchMatches.length,
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
          if (mounted) _searchStats.value = (current: 0, total: 0);
        });
      }
    }

    // Rebuild drag-selection index maps each time the list changes.
    _dragOrder = reversed.map((m) => m.id).toList();
    _dragIndices = {
      for (int i = 0; i < _dragOrder.length; i++) _dragOrder[i]: i
    };
    _dragLookup = {for (final m in reversed) m.id: m};

    // Pre-compute album groups: consecutive image-mesh messages from the same
    // sender within 60 s are grouped into one AlbumMessageWidget.
    // reversed[i] = newest, reversed[i+k] = older → anchor is the OLDEST
    // (highest index) so the album appears at the top of the group visually.
    final albumAnchors = <String, List<ChatMessage>>{};
    final albumSuppressed = <String>{};
    int gi = 0;
    while (gi < reversed.length) {
      final m = reversed[gi];
      if (_isMeshImageReady(m)) {
        int gj = gi + 1;
        while (gj < reversed.length) {
          final next = reversed[gj];
          if (_isMeshImageReady(next) &&
              next.outgoing == m.outgoing &&
              m.time.difference(next.time).abs() < const Duration(seconds: 3)) {
            gj++;
          } else {
            break;
          }
        }
        if (gj - gi > 1) {
          // group is reversed[gi..gj-1]; anchor = oldest = reversed[gj-1]
          final group =
              reversed.sublist(gi, gj).reversed.toList(); // oldest first
          albumAnchors[reversed[gj - 1].id] = group;
          for (int k = gi; k < gj - 1; k++) {
            albumSuppressed.add(reversed[k].id);
          }
        }
        gi = gj;
      } else {
        gi++;
      }
    }

    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.swapMessageAlignment,
      builder: (_, swapped, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.alignAllMessagesRight,
          builder: (_, alignRight, __) {
            return Listener(
              key: _messageListViewportKey,
              onPointerUp: (_) {
                if (_isDragSelecting) _endMessageDragSelection();
              },
              onPointerCancel: (_) {
                if (_isDragSelecting) _endMessageDragSelection();
              },
              child: ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top +
                      70 +
                      (_showSearch ? 64 : 12),
                  bottom: 72 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: reversedDisplay.length,
                itemBuilder: (_, i) {
                  final entry = reversedDisplay[i];
                  if (entry is DateTime) {
                    return KeyedSubtree(
                      key: ValueKey('mesh_day_${entry.toIso8601String()}'),
                      child: _buildDaySeparator(context, entry),
                    );
                  }
                  final msg = entry as ChatMessage;
                  final isNew = !_seenIds.contains(msg.id);
                  if (isNew) _seenIds.add(msg.id);
                  final isIncoming = !msg.outgoing;
                  final shouldShowRight = alignRight
                      ? !swapped
                      : (swapped ? isIncoming : msg.outgoing);
                  final isSearchMatch = _searchQuery.isNotEmpty &&
                      msg.content.toLowerCase().contains(_searchQuery);
                  final isCurrentSearchMatch = isSearchMatch &&
                      _cachedSearchMatches.isNotEmpty &&
                      _cachedSearchMatches[_currentMatchIdx] == i;

                  // Images that are part of an album but not the anchor are hidden —
                  // they are rendered inside the anchor's AlbumMessageWidget.
                  if (albumSuppressed.contains(msg.id)) {
                    return KeyedSubtree(
                      key: _messageItemKey(msg.id),
                      child: const SizedBox.shrink(),
                    );
                  }

                  // For album anchor: synthesise ALBUMv1 content so MessageBubble renders
                  // it identically to a regular album (AlbumMessageWidget with border, etc.)
                  String bubbleText = msg.content;
                  final albumGroup = albumAnchors[msg.id];
                  if (albumGroup != null && albumGroup.length > 1) {
                    final items = albumGroup
                        .where((m) => m.meshFileLocalPath != null)
                        .map((m) => {
                              'filename': 'file://${m.meshFileLocalPath}',
                              'orig': m.meshFileName ?? 'image',
                            })
                        .toList();
                    if (items.length > 1) {
                      bubbleText = 'ALBUMv1:${jsonEncode(items)}';
                    }
                  }

                  final bubble = MessageBubble(
                    key: ValueKey('mesh_mb_${msg.id}'),
                    text: bubbleText,
                    outgoing: msg.outgoing,
                    time: msg.time,
                    peerUsername: widget.otherUsername,
                    chatMessage: msg,
                    replyToId: msg.replyToId,
                    replyToUsername: msg.replyToSender,
                    replyToContent: msg.replyToContent,
                    hasReminder: _hasReminderSync(msg),
                    onReplyTap: msg.replyToId != null
                        ? () => _scrollToMessageById(msg.replyToId)
                        : null,
                    highlighted:
                        _replyToMsg != null && _replyToMsg!.id == msg.id,
                    onRightClick: isDesktop
                        ? (offset) {
                            final items = _buildMeshDesktopMenuItems(msg);
                            if (items != null && items.isNotEmpty) {
                              showMessageDesktopMenu(context, offset, items);
                            }
                          }
                        : null,
                  );

                  final statusBadge = msg.outgoing &&
                          msg.deliveryMode == DeliveryMode.bleMesh &&
                          msg.meshDeliveryStatus != null
                      ? _MeshStatusBadge(
                          status: msg.meshDeliveryStatus!,
                          transportUsed: msg.meshTransportUsed,
                          onRetry: msg.meshDeliveryStatus ==
                                  MeshDeliveryStatus.failed
                              ? () => _retryMeshMessage(msg)
                              : null,
                        )
                      : null;

                  const transportBadge =
                      null; // transport is shown via time colour in bubble

                  return ValueListenableBuilder<
                      ({bool active, Map<String, ChatMessage> selected})>(
                    valueListenable: _selectionNotifier,
                    builder: (_, sel, __) {
                      final isSelected = sel.selected.containsKey(msg.id);
                      final checkmark = AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, size: 14, color: cs.onPrimary)
                            : null,
                      );

                      return KeyedSubtree(
                        key: _messageItemKey(msg.id),
                        child: SwipeableMessageWrapper(
                          disabled: sel.active,
                          onSwipeRight: () => _showMeshMessageMenu(msg),
                          onSwipeLeft: () => _startReplyingToMeshMessage(msg),
                          child: RawGestureDetector(
                            behavior: HitTestBehavior.translucent,
                            gestures: {
                              LongPressGestureRecognizer:
                                  GestureRecognizerFactoryWithHandlers<
                                      LongPressGestureRecognizer>(
                                () => LongPressGestureRecognizer(
                                    duration: _longPressDuration),
                                (instance) {
                                  instance.onLongPressStart =
                                      (_) => _startMessageDragSelection(msg);
                                  instance.onLongPressMoveUpdate = (details) =>
                                      _updateMessageDragSelection(
                                          details.globalPosition);
                                  instance.onLongPressEnd =
                                      (_) => _endMessageDragSelection();
                                },
                              ),
                            },
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: sel.active
                                  ? () => _toggleMessageSelection(msg)
                                  : null,
                              onDoubleTap: sel.active
                                  ? null
                                  : () => _startMessageDragSelection(msg),
                              child: AnimatedContainer(
                                key: (_scrollTargetId != null &&
                                        _scrollTargetId == msg.id)
                                    ? _scrollTargetKey
                                    : null,
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOut,
                                color: isCurrentSearchMatch
                                    ? cs.primary.withValues(alpha: 0.28)
                                    : isSearchMatch
                                        ? cs.primary.withValues(alpha: 0.12)
                                        : isSelected
                                            ? cs.primaryContainer
                                                .withValues(alpha: 0.45)
                                            : (_scrollHighlightId != null &&
                                                    _scrollHighlightId ==
                                                        msg.id)
                                                ? cs.primary
                                                    .withValues(alpha: 0.18)
                                                : Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 12),
                                  child: Row(
                                    mainAxisAlignment: shouldShowRight
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      if (sel.active) checkmark,
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: shouldShowRight
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            AnimatedMessageBubble(
                                              key: ValueKey(
                                                  'mesh_amb_${msg.id}'),
                                              outgoing: msg.outgoing,
                                              animate: isNew &&
                                                  SettingsManager
                                                      .messageAnimationsEnabled
                                                      .value,
                                              alignRight: shouldShowRight,
                                              flightOriginKey:
                                                  msg.outgoing && isNew
                                                      ? _inputAreaKey
                                                      : null,
                                              flightFromEdge:
                                                  !msg.outgoing && isNew,
                                              child: RepaintBoundary(
                                                  child: bubble),
                                            ),
                                            if (statusBadge != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2, right: 4, left: 4),
                                                child: statusBadge,
                                              ),
                                            if (msg.outgoing &&
                                                msg.meshDeliveryStatus ==
                                                    MeshDeliveryStatus
                                                        .sending &&
                                                msg.meshFileId != null)
                                              ValueListenableBuilder<
                                                  Map<String, double>>(
                                                valueListenable:
                                                    MeshFileTransferService
                                                        .instance.progress,
                                                builder: (_, progressMap, __) {
                                                  final p = progressMap[
                                                      msg.meshFileId];
                                                  if (p == null || p >= 1.0) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 2,
                                                            left: 4,
                                                            right: 4),
                                                    child: SizedBox(
                                                      width: 160,
                                                      child:
                                                          LinearProgressIndicator(
                                                        value: p,
                                                        minHeight: 2,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(1),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            if (transportBadge != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 2, left: 4),
                                                child: transportBadge,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ), // RawGestureDetector
                        ), // SwipeableMessageWrapper
                      );
                    },
                  );
                },
              ), // ListView.builder
            ); // Listener
          },
        );
      },
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.inputBarMaxWidth,
      builder: (_, maxWidth, __) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            SettingsManager.elementOpacity,
            SettingsManager.elementBrightness,
            MeshManager.instance.neighbors,
          ]),
          builder: (ctx, _) {
            final op = SettingsManager.elementOpacity.value;
            final br = SettingsManager.elementBrightness.value;
            final bgColor = SettingsManager.getElementColor(
              cs.surfaceContainerHighest,
              br,
            );
            final borderColor = cs.outlineVariant.withValues(alpha: 0.3);
            final inputBorderColor = cs.outlineVariant.withValues(alpha: 0.15);

            return Padding(
              padding: EdgeInsets.only(
                bottom: 12.0 + MediaQuery.of(context).padding.bottom,
                left: 16,
                right: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: _replyToMsg != null
                          ? _buildReplyPreview(context, bgColor, borderColor)
                          : const SizedBox.shrink(),
                    ),
                    AnimatedBuilder(
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
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
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
                          // Liquid glass на Android, iOS и macOS; на Windows/Linux — стандартный рендер.
                          final glassAllowed =
                              !Platform.isWindows && !Platform.isLinux;
                          final useGlass = glassAllowed &&
                              SettingsManager.liquidGlassOnInput.value;
                          final bar = ChatInputBar(
                            inputAreaKey: _inputAreaKey,
                            controller: _ctrl,
                            textFocusNode: _focusNode,
                            recordingListenable: recordingNotifier,
                            recordingLevelListenable: recordingLevelNotifier,
                            onCancelRecording: () {
                              rootScreenKey.currentState?.cancelRecording();
                            },
                            onMicPressed: (isRecording) {
                              if (isRecording) {
                                _stopRecordingAndSendVoice();
                              } else {
                                rootScreenKey.currentState?.startRecording();
                              }
                            },
                            onAttachPressed: _onAttachPressed,
                            onSendPressed: _send,
                            onPaste: _handlePasteFromClipboard,
                            hintText:
                                AppLocalizations.of(ctx).meshChatInputHint,
                            backgroundColor: useGlass ? Colors.white : bgColor,
                            opacity: useGlass ? 0.0 : op,
                            borderColor: useGlass
                                ? Colors.transparent
                                : inputBorderColor,
                            glassMode: useGlass,
                            readOnly: false,
                            sendColor: cs.primary,
                            contentInsertionConfiguration:
                                ContentInsertionConfiguration(
                              allowedMimeTypes: const [
                                'image/png',
                                'image/jpeg',
                                'image/gif',
                                'image/webp',
                              ],
                              onContentInserted: _handleContentInsertion,
                            ),
                          );
                          if (!useGlass) return bar;
                          final quality =
                              SettingsManager.liquidGlassInputQuality.value;
                          final blur =
                              SettingsManager.liquidGlassInputBlur.value;
                          final tint =
                              SettingsManager.liquidGlassInputTint.value;
                          final saturation =
                              SettingsManager.liquidGlassInputSaturation.value;
                          final chromatic =
                              SettingsManager.liquidGlassInputChromatic.value;
                          final refractive =
                              SettingsManager.liquidGlassInputRefractive.value;
                          final lightIntensity = SettingsManager
                              .liquidGlassInputLightIntensity.value;
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
                          final glassSettings = LiquidGlassSettings(
                            thickness: thickness,
                            blur: blur,
                            chromaticAberration: chromatic,
                            lightIntensity: lightIntensity,
                            refractiveIndex: refractive,
                            saturation: saturation,
                            ambientStrength: 0.8,
                            lightAngle: 0.75 * math.pi,
                            glassColor: tintColor,
                          );
                          return GlassCard(
                            useOwnLayer: true,
                            settings: glassSettings,
                            quality: glassQuality,
                            padding: EdgeInsets.zero,
                            shape: LiquidRoundedRectangle(borderRadius: 28),
                            clipBehavior: Clip.antiAlias,
                            child: bar,
                          );
                        },
                      ),
                    ),
                  ], // Column children
                ), // Column
              ), // ConstrainedBox
            );
          },
        );
      },
    );
  }

  Widget _buildReplyPreview(
      BuildContext context, Color bgColor, Color borderColor) {
    final reply = _replyToMsg!;
    final cs = Theme.of(context).colorScheme;
    final senderName = reply.from;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).replyingTo(senderName),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  getPreviewText(reply.content),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelMeshReply,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// On desktop MeshChat is embedded in the right panel, not pushed on the
  /// Navigator — so "back" means switching the panel back to the regular
  /// ChatScreen for the same user. On mobile it's a pushed route, so a plain
  /// pop takes us back to whichever screen opened it (usually ChatScreen).
  void _goBackToChatScreen(BuildContext ctx) {
    if (isDesktop) {
      rootScreenKey.currentState
          ?.returnToChatScreenFromMesh(widget.otherUsername);
    } else {
      Navigator.of(ctx).maybePop();
    }
  }

  // ── Transport mode ────────────────────────────────────────────────────────

  Future<void> _selectBleTransportMode() async {
    await SettingsManager.setMeshTransportMode('ble');
    if (MeshManager.instance.isAvailable) return;

    final enabled = await MeshManager.instance.requestEnableBluetooth();
    if (enabled || !mounted) return;

    // Couldn't prompt the OS directly (iOS/macOS/desktop, or the Android
    // prompt failed) — send the user to system settings instead.
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.meshBluetoothOffTitle,
      message: l.meshBluetoothOffContent,
      confirmLabel: l.meshOpenSystemSettings,
      icon: Icons.bluetooth_disabled_rounded,
    );
    if (confirmed == true) openAppSettings();
  }

  // ── Diagnostics ────────────────────────────────────────────────────────────

  void _showDiagnostics(BuildContext context) {
    final mesh = MeshManager.instance;
    final neighbor = mesh.neighbors.neighborByUsername(widget.otherUsername);
    final cs = Theme.of(context).colorScheme;

    String ago(DateTime t) {
      final s = DateTime.now().difference(t).inSeconds;
      if (s < 60) return '${s}s ago';
      return '${(s / 60).floor()}m ${s % 60}s ago';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).connectionDiagnostics),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _diagRow('Peer', widget.otherUsername),
              _diagRow('My username', mesh.myUsername ?? '—'),
              _diagRow('Mesh running', mesh.isRunning ? 'Yes' : 'No'),
              _diagRow('BLE available', mesh.isAvailable ? 'Yes' : 'No'),
              _diagRow('Outbox queue', '${mesh.outboxCount} messages'),
              const Divider(height: 20),
              if (neighbor == null)
                Text(
                  '${widget.otherUsername} is NOT in range',
                  style:
                      TextStyle(color: cs.error, fontWeight: FontWeight.bold),
                )
              else ...[
                _diagRow('Status', 'In range'),
                _diagRow(
                    'Transport', neighbor.isLan ? 'LAN (WiFi/USB)' : 'BLE'),
                _diagRow('RSSI', '${neighbor.rssi} dBm'),
                _diagRow('Device ID', neighbor.deviceId),
                _diagRow(
                    'Key hash', '${neighbor.keyHashHex.substring(0, 16)}…'),
                _diagRow('Last seen', ago(neighbor.lastSeen)),
              ],
              const Divider(height: 20),
              Text(
                'Neighbors: ${mesh.neighbors.neighbors.length}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
              ...mesh.neighbors.neighbors.map((n) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${n.username ?? n.deviceId.substring(0, 8)} — '
                      '${n.isLan ? 'LAN' : 'BLE'} ${n.rssi} dBm',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                '$label:',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}

// ── Mesh delivery status badge ─────────────────────────────────────────────

class _MeshStatusBadge extends StatelessWidget {
  const _MeshStatusBadge({
    required this.status,
    this.onRetry,
    this.transportUsed,
  });

  final MeshDeliveryStatus status;
  final VoidCallback? onRetry;
  final String? transportUsed; // 'wifi' | 'ble' | null

  static const _wifiColor = Color(0xFF34C759);
  static const _bleColor = Color(0xFF2196F3);

  IconData _transportIcon() {
    if (transportUsed == 'wifi') return Icons.wifi_rounded;
    if (transportUsed == 'ble') return Icons.bluetooth_rounded;
    return Icons.wifi_tethering_rounded;
  }

  Color _transportColor(Color fallback) {
    if (transportUsed == 'wifi') return _wifiColor;
    if (transportUsed == 'ble') return _bleColor;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    switch (status) {
      case MeshDeliveryStatus.sending:
        final sendingLabel = transportUsed == 'wifi'
            ? l.meshStatusSendingWifi
            : transportUsed == 'ble'
                ? l.meshStatusSendingBle
                : l.meshStatusSending;
        final sendingColor =
            _transportColor(cs.onSurface.withValues(alpha: 0.45));
        return _badge(
          icon: _transportIcon(),
          label: sendingLabel,
          color: sendingColor,
          spin: true,
        );
      case MeshDeliveryStatus.relayed:
        return _badge(
          icon: Icons.cell_tower_rounded,
          label: l.meshStatusRelayed,
          color: Colors.amber.shade600,
          suffix: _suffixIcon(),
        );
      case MeshDeliveryStatus.delivered:
        return _badge(
          icon: Icons.check_rounded,
          label: l.meshStatusDelivered,
          color: _transportColor(Colors.green.shade400),
        );
      case MeshDeliveryStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: _badge(
            icon: Icons.error_outline_rounded,
            label: onRetry != null
                ? '${l.meshStatusFailed} · ${l.meshStatusRetry}'
                : l.meshStatusFailed,
            color: Colors.red.shade400,
          ),
        );
    }
  }

  Widget? _suffixIcon() {
    if (transportUsed == 'wifi') {
      return const Icon(Icons.wifi_rounded, size: 10, color: _wifiColor);
    }
    if (transportUsed == 'ble') {
      return const Icon(Icons.bluetooth_rounded, size: 10, color: _bleColor);
    }
    return null;
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
    bool spin = false,
    Widget? suffix,
  }) {
    final iconWidget = Icon(icon, size: 11, color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        spin ? _SpinningIcon(child: iconWidget) : iconWidget,
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        if (suffix != null) ...[
          const SizedBox(width: 3),
          suffix,
        ],
      ],
    );
  }
}

// ── Mesh incoming transport badge ──────────────────────────────────────────

class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({required this.child});
  final Widget child;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _ctrl,
        child: widget.child,
      );
}

// ── Mesh message actions sheet ─────────────────────────────────────────────

class _MeshMessageActionsSheet extends StatelessWidget {
  const _MeshMessageActionsSheet({
    required this.msg,
    required this.onReply,
    this.onPin,
    this.isPinned = false,
    this.onDelete,
    this.onReminderToggle,
    this.hasReminder = false,
  });

  final ChatMessage msg;
  final VoidCallback onReply;
  final VoidCallback? onPin;
  final bool isPinned;
  final VoidCallback? onDelete;
  final VoidCallback? onReminderToggle;
  final bool hasReminder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    Widget tile(IconData icon, String label, VoidCallback? onTap,
        {Color? color}) {
      final effective = color ?? cs.onSurface;
      return ListTile(
        leading: Icon(icon,
            color: onTap != null
                ? effective
                : cs.onSurface.withValues(alpha: 0.3)),
        title: Text(
          label,
          style: TextStyle(
            color:
                onTap != null ? effective : cs.onSurface.withValues(alpha: 0.3),
          ),
        ),
        onTap: onTap,
        dense: true,
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        final sheetColor = SettingsManager.getElementColor(
          cs.surfaceContainerHighest,
          brightness,
        );
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.circular(27),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                tile(Icons.reply_rounded, l.reply, onReply),
                tile(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  isPinned ? l.unpin : l.pin,
                  onPin,
                ),
                tile(
                  hasReminder
                      ? Icons.alarm_off_rounded
                      : Icons.alarm_add_rounded,
                  hasReminder ? l.cancelReminder : l.setReminder,
                  onReminderToggle,
                ),
                if (onDelete != null)
                  tile(Icons.delete_outline_rounded, l.delete, onDelete,
                      color: Colors.red.shade400),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
