// lib/screens/group_chat_screen.dart
import '../widgets/marquee_text.dart';
import '../widgets/empty_chat_placeholder.dart';
import '../utils/chat_image_preloader.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../enums/liquid_glass_quality.dart';
import 'package:ONYX/screens/forward_screen.dart';
import 'package:ONYX/managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_extra.dart';
import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../widgets/chat_background_layer.dart';
import '../widgets/onyx_dialog.dart';
import '../utils/code_heuristic.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import '../globals.dart';
import '../models/group.dart';
import '../managers/account_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_images_scope.dart';
import '../widgets/album_message_widget.dart' show AlbumItem;
import '../widgets/avatar_widget.dart';
import '../widgets/avatar_crop_screen.dart';
import '../widgets/cached_remote_avatar.dart';
import '../enums/media_provider.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../utils/clipboard_image.dart';
import '../utils/file_utils.dart';
import '../utils/image_file_cache.dart';
import '../utils/upload_task.dart';
import '../widgets/upload_progress_bar.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/message_reaction_bar.dart';
import '../widgets/swipeable_message_wrapper.dart';
import '../widgets/onyx_reminder_picker.dart';
import '../services/reminder_service.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/adaptive_glass_icon_button.dart';
import '../widgets/measure_size.dart';
import '../enums/scroll_down_button_position.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/gallery_extractor.dart';
import 'media_gallery_screen.dart';
import 'post_comments_screen.dart';

const List<String> _randomHints = [
  'Say something!',
  'Don’t be shy...',
  'What’s on your mind?',
  'You are safe.',
  'Type it out!',
  'Your move.',
  'Write something??',
  'Come on?',
  'Break the silence!',
  'Hello? Anyone there?',
  'Drop a line!',
  'Make it count!',
  'Speak your truth.',
];

class GroupChatScreen extends StatefulWidget {
  final Group group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with RouteAware, SingleTickerProviderStateMixin, ReactionStateMixin {
  static final Set<String> _sessionInputAnimationsShown = {};

  late final RouteObserver<Route<void>> _localRouteObserver;
  final TextEditingController _textCtrl = TextEditingController();
  late final FocusNode _focusNode;
  final GlobalKey _inputAreaKey = GlobalKey();
  List<Map<String, dynamic>> _messages = [];
  // Fingerprint of the message list last handed to the image preloader.
  int _preloadStampCount = -1;
  String _preloadStampLast = '';
  final ScrollController _scroll = ScrollController();
  String? _currentUsername;
  // msgId → reaction mixin key ('gm_<id>'), populated during rendering
  final Map<int, String> _msgIdToReactionKey = {};
  String? _currentDisplayName;
  int? _memberCount;
  late final String _inputHint;
  final Set<String> _allMessageIds = {};
  final Set<String> _alreadyRenderedMessageIds = {};
  // True once the message list has painted at least one frame. Entry
  // animations are suppressed until then — closes a race where the initial
  // cache/server load finishes asynchronously after the pre-seed below ran,
  // which would otherwise make the whole history "appear new" and animate
  // in on open.
  bool _hasBuiltMessageListOnce = false;
  final Map<String, String> _pendingMessageIds = {};
  final List<UploadTask> _pendingUploads = [];
  bool _loadedFromCache = false;
  bool _isDisposed = false;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;

  String? _editingMsgId;
  String? _editingOriginalContent;
  final ValueNotifier<bool> _showScrollDownButton = ValueNotifier<bool>(false);
  final ValueNotifier<double> _bottomBarHeight = ValueNotifier<double>(76.0);

  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryTranslateY;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  final List<Map<String, dynamic>> _wsIncomingBuffer = [];
  Timer? _wsFlushTimer;
  static const int _wsBatchSize = 50;
  static const int _wsBatchDelayMs = 50;

  Map<String, dynamic>? _replyingToMessage;
  Map<String, dynamic>? _pinnedMessage;

  // Tracks whichever post's comment thread is currently pushed on top of
  // this screen, so incoming comment_added/comment_deleted/
  // comment_reaction_update WS events can be routed straight into it
  // instead of only updating the badge underneath the post bubble.
  int? _openCommentsPostId;
  GlobalKey<PostCommentsScreenState>? _openCommentsKey;

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
  Map<String, Map<String, dynamic>> get _selectedGroupMessages =>
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

  void _startReplyingToMessage(Map<String, dynamic> msg) {
    setState(() {
      _replyingToMessage = msg;
    });
  }

  void _cancelReplying() {
    if (_replyingToMessage == null) return;
    setState(() {
      debugPrint(
          '[group_chat_screen::_cancelReplying] clearing _replyingToMessage\n${StackTrace.current}');
      _replyingToMessage = null;
    });
  }

  bool _isGroupMsgPinned(Map<String, dynamic> msg) {
    final pinId = _pinnedMessage?['id']?.toString();
    if (pinId == null) return false;
    return pinId == msg['id']?.toString();
  }

  String get _pinPrefsKey => 'pinned_group_${widget.group.id}';

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

  // Scoped per account (currentUsername) so every account that opens the group
  // sees the notice once — switching accounts re-shows it.
  String get _e2eeWarnPrefsKey =>
      'e2ee_warn_shown_group_${_currentUsername ?? ''}_${widget.group.id}';

  // Show the "no E2EE in groups" dialog only the first time this group/channel
  // is opened. Once acknowledged, the flag is persisted per group id.
  Future<void> _maybeShowE2eeWarning() async {
    // Only for groups — channels don't get this notice.
    if (widget.group.isChannel) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_e2eeWarnPrefsKey) ?? false;
    if (alreadyShown || !mounted) return;
    // Defer to after first frame so the dialog opens over a built screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showE2eeWarningDialog();
    });
  }

  Future<void> _savePinnedMessage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pinnedMessage == null) {
      await prefs.remove(_pinPrefsKey);
    } else {
      await prefs.setString(_pinPrefsKey, jsonEncode(_pinnedMessage));
    }
  }

  void _toggleGroupPin(Map<String, dynamic> msg) {
    if (_isGroupMsgPinned(msg)) {
      setState(() => _pinnedMessage = null);
    } else {
      setState(() {
        _pinnedMessage = {
          'id': msg['id']?.toString() ?? '',
          'content': msg['content']?.toString() ?? '',
          'sender': msg['sender_display_name']?.toString() ??
              msg['sender']?.toString() ??
              '',
        };
      });
    }
    _savePinnedMessage();
  }

  // Live cache of "chatId|messageId" keys with an active reminder.
  Set<String> _reminderKeys = {};
  StreamSubscription? _reminderKeysSub;

  void _subscribeReminders() {
    final accountId = _currentUsername;
    if (accountId == null) return;
    _reminderKeysSub =
        ReminderService.watchActiveReminders(accountId).listen((rows) {
      if (!mounted) return;
      setState(() {
        _reminderKeys = rows.map((r) => '${r.chatId}|${r.messageId}').toSet();
      });
    });
  }

  bool _hasReminderSync(String? msgId) {
    if (msgId == null || msgId.isEmpty) return false;
    final chatId = 'group_${widget.group.id}';
    return _reminderKeys.contains('$chatId|$msgId');
  }

  Future<void> _handleGroupReminderToggle({
    required Map<String, dynamic> msg,
    required bool hasReminder,
    required String chatId,
    required String messageId,
  }) async {
    final myAccountId = _currentUsername;
    if (myAccountId == null) return;
    final l = AppLocalizations.of(context);

    if (hasReminder) {
      await ReminderService.cancelReminder(myAccountId, chatId, messageId);
      rootScreenKey.currentState?.showSnack(l.reminderCancelled);
      return;
    }

    final accentColorArgb = Theme.of(context).colorScheme.primary.toARGB32();
    final picked = await showOnyxReminderPicker(context);
    if (picked == null) return;
    await ReminderService.scheduleReminder(
      accountId: myAccountId,
      messageId: messageId,
      accentColorArgb: accentColorArgb,
      chatType: 'group',
      chatId: chatId,
      chatTitle: widget.group.name,
      messagePreview: getPreviewText(msg['content']?.toString() ?? ''),
      scheduledAt: picked,
    );
    rootScreenKey.currentState?.showSnack(l.reminderSet);
  }

  String? _scrollHighlightId;
  Timer? _highlightTimer;
  final GlobalKey _scrollTargetKey = GlobalKey();
  String? _scrollTargetId;

  // ── Day-separator display items ─────────────────────────────────────────
  List<AlbumItem>? _cachedAllImages;
  int _cachedAllImagesHash = 0;
  int _cachedDragHash = 0;

  List<Object> _groupDisplayItems =
      []; // elements: Map<String,dynamic> | DateTime
  int _groupDisplayHash = -1;

  DateTime _getGroupMsgTime(Map<String, dynamic> msg) {
    final tsMs = msg['timestamp_ms'];
    if (tsMs is int && tsMs > 0)
      return DateTime.fromMillisecondsSinceEpoch(tsMs);
    return DateTime.tryParse(msg['timestamp']?.toString() ?? '') ??
        DateTime.now();
  }

  List<Object> _rebuildGroupDisplayItems() {
    // Keyed on animationId (stable for a message's whole lifetime), not id
    // (overwritten with the server id once a locally-sent message is
    // confirmed). Using id here meant every outgoing send invalidated this
    // cache a second time right as the confirmation arrived — forcing a
    // full display-items rebuild (and the drag/image-cache invalidations
    // keyed off it) in the same frame as the entrance animation was still
    // playing, which is what made the list visibly jump on send.
    final hash = _messages.length ^
        (_messages.isNotEmpty
            ? ((_messages.last['animationId'] ?? _messages.last['id'])
                    ?.hashCode ??
                0)
            : 0);
    if (hash == _groupDisplayHash && _groupDisplayItems.isNotEmpty) {
      return _groupDisplayItems;
    }
    final List<Object> items = [];
    DateTime? currentDay;
    for (final msg in _messages) {
      final t = _getGroupMsgTime(msg);
      final day = DateTime(t.year, t.month, t.day);
      if (currentDay == null || currentDay != day) {
        items.add(day);
        currentDay = day;
      }
      items.add(msg);
    }
    _groupDisplayItems = items.reversed.toList();
    _groupDisplayHash = hash;
    return _groupDisplayItems;
  }

  Widget _buildGroupDaySeparator(BuildContext context, DateTime date) {
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

  void _scrollToGroupMessageById(String? msgId) {
    if (msgId == null || !_scroll.hasClients) return;
    final displayItems = _rebuildGroupDisplayItems();
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

  /// If a search-result tap asked to land on a specific message in this group
  /// (see [setPendingMessageScrollTarget]), scroll to and highlight it once
  /// the message list is laid out — instead of opening at the bottom.
  void _consumePendingGroupScrollTarget() {
    final groupKey =
        '${widget.group.isExternal ? (widget.group.externalServerId ?? 'ext') : 'native'}:${widget.group.id}';
    final pendingId = consumePendingMessageScrollTarget(groupKey);
    if (pendingId == null) return;
    void attempt([int retries = 6]) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scrollToGroupMessageById(pendingId);
      } else if (retries > 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => attempt(retries - 1));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  Widget _buildGroupPinnedBanner(BuildContext context) {
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
                _scrollToGroupMessageById(_pinnedMessage?['id']?.toString()),
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

  late int _avatarVersion;

  bool _isGroupTextMessage(Map<String, dynamic> msg) {
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

  bool _isMyGroupMessage(Map<String, dynamic> msg) {
    final rawSender = msg['sender']?.toString() ?? '';
    return rawSender == _currentUsername || rawSender == _currentDisplayName;
  }

  void _enterGroupSelectionMode(Map<String, dynamic> msg, String uniqueKey) {
    HapticFeedback.mediumImpact();
    final cur = _selectionNotifier.value;
    _selectionNotifier.value =
        (active: true, selected: {...cur.selected, uniqueKey: msg});
  }

  void _exitGroupSelectionMode() {
    _selectionNotifier.value = (active: false, selected: {});
  }

  void _toggleGroupMsgSelection(Map<String, dynamic> msg, String uniqueKey) {
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

  String _selectionKeyForGroupMessage(Map<String, dynamic> msg) {
    final sender = widget.group.isChannel
        ? widget.group.name
        : msg['sender']?.toString() ?? '?';
    final content = msg['content']?.toString() ?? '';
    return '${msg['timestamp']}_${sender}_${content.hashCode}';
  }

  // Keyed by the message's STABLE animation id (animationId/id, not the
  // uniqueKey which embeds timestamp/content and can shift), so a server
  // sync doesn't mint a new GlobalKey and tear down the in-flight
  // AnimatedMessageBubble under it (see ChatScreen for the full story).
  GlobalKey _messageItemKey(String stableId) =>
      _messageItemKeys.putIfAbsent(stableId, () => GlobalKey());

  void _startGroupDragSelection(Map<String, dynamic> msg, String uniqueKey) {
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
    _selectGroupMessageRangeTo(uniqueKey);
  }

  void _updateGroupDragSelection(Offset globalPosition) {
    if (!_isDragSelectingMessages) return;
    _lastDragPointerGlobal = globalPosition;
    final hoveredKey = _messageKeyAtGlobal(globalPosition);
    if (hoveredKey != null && hoveredKey != _dragSelectionCurrentKey) {
      _selectGroupMessageRangeTo(hoveredKey);
    }
    _updateDragAutoScroll();
  }

  void _endGroupDragSelection() {
    _isDragSelectingMessages = false;
    _dragSelectionAnchorKey = null;
    _dragSelectionCurrentKey = null;
    _dragSelectionBase = const {};
    _stopDragAutoScroll();
  }

  void _selectGroupMessageRangeTo(String uniqueKey) {
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
        _selectGroupMessageRangeTo(hoveredKey);
      }
    });
  }

  void _stopDragAutoScroll() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
  }

  // Map insertion order (`.values`) reflects selection/drag-recompute order,
  // not chronological order — always re-sort by message time first.
  List<Map<String, dynamic>> get _selectedGroupMessagesChronological =>
      _selectedGroupMessages.values.toList()
        ..sort((a, b) => _getGroupMsgTime(a).compareTo(_getGroupMsgTime(b)));

  void _copySelectedGroupMessages() {
    final texts = _selectedGroupMessagesChronological
        .where(_isGroupTextMessage)
        .map((m) => m['content']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value).msgCopied);
    }
    _exitGroupSelectionMode();
  }

  void _forwardSelectedGroupMessages() {
    final contents = _selectedGroupMessagesChronological
        .map((m) => m['content']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    if (contents.isEmpty) return;
    _exitGroupSelectionMode();
    ForwardScreen.show(context, contents);
  }

  Future<void> _confirmDeleteSelectedGroupMessages() async {
    final toDelete = _selectedGroupMessages.entries
        .where((e) {
          final msgId = e.value['id']?.toString();
          return msgId != null &&
              msgId.isNotEmpty &&
              _isMyGroupMessage(e.value);
        })
        .map((e) => e.value['id']!.toString())
        .toList();
    if (toDelete.isEmpty) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.deleteMessageTitle,
      message: toDelete.length == 1
          ? l.deleteGroupMsgContent
          : 'Delete ${toDelete.length} messages?',
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      _exitGroupSelectionMode();
      for (final msgId in toDelete) {
        await _deleteGroupMessage(msgId);
      }
    }
  }

  bool get _canManageGroup {
    final role = widget.group.myRole;
    return role == 'owner' || role == 'moderator';
  }

  bool get _isOwner {
    return widget.group.myRole == 'owner';
  }

  @override
  void initState() {
    super.initState();
    _avatarVersion = widget.group.avatarVersion;
    final randomIndex = Random().nextInt(_randomHints.length);
    _inputHint = _randomHints[randomIndex];
    _focusNode = FocusNode();
    _localRouteObserver = RouteObserver<Route<void>>();
    _currentUsername = rootScreenKey.currentState?.currentUsername;
    _currentDisplayName = rootScreenKey.currentState?.currentDisplayName;
    _loadPinnedMessage();
    _maybeShowE2eeWarning();
    _consumePendingGroupScrollTarget();
    _subscribeReminders();
    _loadHistoryFromCache().then((_) {
      _loadHistoryFromNetwork();
    });
    _loadMemberCount();
    rootScreenKey.currentState?.subscribeToGroup(widget.group.id, _onGroupMsg);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);

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
      if (!mounted) return;
      if (!_focusNode.hasFocus && isDesktop) _focusNode.requestFocus();

      // Delay read-marking until after navigation animation to avoid jitter.
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _markMessagesAsRead();
      } else {
        void onStatus(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            animation.removeStatusListener(onStatus);
            if (mounted) _markMessagesAsRead();
          }
        }

        animation.addStatusListener(onStatus);
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        if (recordingNotifier.value ||
            _shouldPreserveExternalFocus ||
            _suppressAutoRefocus) return;

        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (isDesktop) {
          _focusNode.requestFocus();
        }
      }
    });
    _scroll.addListener(_onScroll);

    groupAvatarVersion.addListener(_onGroupAvatarUpdate);
  }

  void _checkInputAnimationState() {
    final groupId = 'group_${widget.group.id}';

    if (!_sessionInputAnimationsShown.contains(groupId)) {
      _inputEntryController.forward();
      _sessionInputAnimationsShown.add(groupId);
      _hasInputAnimated = true;
    } else {
      _inputEntryController.value = 1.0;
      _hasInputAnimated = true;
    }
  }

  void _onScroll() {
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
  }

  void _onGroupLongPress(Map<String, dynamic> msg) async {
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
    final isMedia =
        isSaveable || isProxy || content.startsWith('[cannot-decrypt');

    final rawSender = msg['sender']?.toString() ?? '';
    final isMe =
        rawSender == _currentUsername || rawSender == _currentDisplayName;
    final msgId = msg['id']?.toString();

    _shouldPreserveExternalFocus = true;
    final colorScheme = Theme.of(context).colorScheme;

    final reminderChatId = 'group_${widget.group.id}';
    final reminderMsgId = msgId ?? '';
    var hasReminder = false;
    if (_currentUsername != null && reminderMsgId.isNotEmpty) {
      hasReminder = await ReminderService.hasActiveReminder(
          _currentUsername!, reminderChatId, reminderMsgId);
    }
    if (!mounted) return;

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

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ValueListenableBuilder<double>(
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
                    if (widget.group.canPost)
                      actionTile(Icons.reply_rounded,
                          AppLocalizations.of(context).reply, () {
                        Navigator.pop(ctx);
                        _startReplyingToMessage(msg);
                      }),
                    actionTile(Icons.add_reaction_outlined, 'React', () {
                      Navigator.pop(ctx);
                      final rMsgId = int.tryParse(msg['id']?.toString() ?? '');
                      final reactionKey = 'gm_${msg['id']}';
                      openEmojiPicker(
                          context, reactionKey, _currentUsername ?? '',
                          anonymous: true,
                          onAfterToggle: (emoji, wasReacted) {
                        if (rMsgId != null)
                          _serverToggleGroupReaction(rMsgId, emoji, wasReacted);
                      });
                    }),
                    actionTile(
                      _isGroupMsgPinned(msg)
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      _isGroupMsgPinned(msg) ? 'Unpin' : 'Pin',
                      () {
                        Navigator.pop(ctx);
                        _toggleGroupPin(msg);
                      },
                    ),
                    if (reminderMsgId.isNotEmpty)
                      actionTile(
                        hasReminder
                            ? Icons.alarm_off_rounded
                            : Icons.alarm_add_rounded,
                        hasReminder
                            ? AppLocalizations.of(context).cancelReminder
                            : AppLocalizations.of(context).setReminder,
                        () {
                          Navigator.pop(ctx);
                          _handleGroupReminderToggle(
                            msg: msg,
                            hasReminder: hasReminder,
                            chatId: reminderChatId,
                            messageId: reminderMsgId,
                          );
                        },
                      ),
                    if (isSaveable)
                      actionTile(Icons.save_alt_rounded, 'Save', () {
                        Navigator.pop(ctx);
                        _saveMediaFromMessage(content);
                      }),
                    if (!isMedia)
                      actionTile(
                          Icons.copy_rounded, AppLocalizations.of(context).copy,
                          () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: content));
                        rootScreenKey.currentState
                            ?.showSnack(AppLocalizations.of(context).msgCopied);
                      }),
                    if (isMe && !isMedia && msgId != null)
                      actionTile(
                          Icons.edit_rounded, AppLocalizations.of(context).edit,
                          () {
                        Navigator.pop(ctx);
                        _startEditingGroupMessage(msg);
                      }),
                    if (isMe && msgId != null)
                      actionTile(
                        Icons.delete_outline_rounded,
                        AppLocalizations.of(context).delete,
                        () {
                          Navigator.pop(ctx);
                          () async {
                            final confirmed = await showOnyxConfirmDialog(
                              context: context,
                              title: AppLocalizations.of(context)
                                  .deleteMessageTitle,
                              message: AppLocalizations.of(context)
                                  .deleteGroupMsgContent,
                              confirmLabel: AppLocalizations.of(context).delete,
                              isDestructive: true,
                              icon: Icons.delete_outline_rounded,
                            );
                            if (confirmed == true) {
                              _deleteGroupMessage(msgId);
                            }
                          }();
                        },
                        color: Colors.red.shade400,
                      ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _shouldPreserveExternalFocus = false;
      });
    });
  }

  List<DesktopMenuItem> _buildGroupDesktopMenuItems(Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    final rawSender = msg['sender']?.toString() ?? '';
    final isMe =
        rawSender == _currentUsername || rawSender == _currentDisplayName;
    final msgId = msg['id']?.toString();
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
        content.startsWith('[cannot-decrypt');
    final l = AppLocalizations.of(context);
    return [
      if (widget.group.canPost)
        DesktopMenuItem(
          icon: Icons.reply_rounded,
          label: l.reply,
          onPressed: () => _startReplyingToMessage(msg),
        ),
      DesktopMenuItem(
        icon: Icons.add_reaction_outlined,
        label: l.react,
        onPressed: () {
          final rMsgId = int.tryParse(msg['id']?.toString() ?? '');
          final reactionKey = 'gm_${msg['id']}';
          openEmojiPicker(context, reactionKey, _currentUsername ?? '',
              anonymous: true,
              onAfterToggle: (emoji, wasReacted) {
            if (rMsgId != null)
              _serverToggleGroupReaction(rMsgId, emoji, wasReacted);
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
              : () => _copyGroupProxyImage(content),
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
      if (isMe && !isMedia && msgId != null)
        DesktopMenuItem(
          icon: Icons.edit_rounded,
          label: l.edit,
          onPressed: () => _startEditingGroupMessage(msg),
        ),
      DesktopMenuItem(
        icon: _isGroupMsgPinned(msg)
            ? Icons.push_pin_outlined
            : Icons.push_pin_rounded,
        label: _isGroupMsgPinned(msg) ? l.unpin : l.pin,
        onPressed: () => _toggleGroupPin(msg),
      ),
      if (isMe && msgId != null)
        DesktopMenuItem(
          icon: Icons.delete_outline_rounded,
          label: l.delete,
          type: ContextMenuButtonType.delete,
          color: Colors.red.shade400,
          onPressed: () => _desktopDeleteGroupMessage(msg, msgId),
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

  void _copyGroupProxyImage(String content) {
    try {
      final data = jsonDecode(content.substring('MEDIA_PROXYv1:'.length))
          as Map<String, dynamic>;
      final url = (data['url'] as String?)?.trim() ?? '';
      if (url.isEmpty) return;
      final cached = imageFileCache[url];
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
        // "orig" may be a display label without extension (e.g. "Voice message");
        // fall back to the cached file's extension in that case.
        String saveName = orig.isNotEmpty ? orig : p.basename(localPath);
        if (p.extension(saveName).isEmpty) {
          saveName = saveName + p.extension(localPath);
        }
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
      if (content.startsWith('ALBUMv1:')) {
        final list =
            jsonDecode(content.substring('ALBUMv1:'.length)) as List<dynamic>;
        final items = list.whereType<Map<String, dynamic>>().toList();
        if (items.isEmpty) return;
        int saved = 0, failed = 0;
        if (Platform.isAndroid || Platform.isIOS) {
          for (final item in items) {
            final filename = item['filename'] as String? ?? '';
            final cached = imageFileCache[filename];
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
          rootScreenKey.currentState?.showSnack(
            failed == 0
                ? 'All $saved images saved to gallery'
                : '$saved saved, $failed failed',
          );
          return;
        }
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Choose folder to save all images',
          );
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
          rootScreenKey.currentState?.showSnack(
            failed == 0
                ? 'All $saved images saved to: $dirPath'
                : '$saved saved, $failed failed',
          );
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
          if (Platform.isAndroid || Platform.isIOS) {
            for (final item in items) {
              final url = (item['url'] as String?)?.trim() ?? '';
              if (url.isEmpty) {
                failed++;
                continue;
              }
              final cached = imageFileCache[url];
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
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
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
              final cached = imageFileCache[url];
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
        final isImg = type == 'image' ||
            (['.jpg', '.jpeg', '.png', '.gif', '.webp']
                    .any(orig.toLowerCase().endsWith) ||
                ['.jpg', '.jpeg', '.png', '.gif', '.webp']
                    .any(url.toLowerCase().endsWith));
        if (isImg) {
          final cached = imageFileCache[url];
          if (cached == null) {
            rootScreenKey.currentState?.showSnack('Image not loaded yet');
            return;
          }
          await _saveFileToDevice(
              cached.file, orig.isNotEmpty ? orig : p.basename(url));
          return;
        }
        final localPath = mediaFilePathRegistry[url];
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
            saved == true ? 'Saved to gallery' : 'Failed to save to gallery',
          );
        } else if (isVideo) {
          final saved =
              await GallerySaver.saveVideo(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(
            saved == true ? 'Saved to gallery' : 'Failed to save to gallery',
          );
        } else {
          // Audio / documents / archives — copy to configured ONYX folder
          final onyxDir = await getOnyxSaveDirectory();
          if (onyxDir == null) {
            rootScreenKey.currentState
                ?.showSnack('Cannot access Downloads directory');
            return;
          }
          final destPath = '${onyxDir.path}/$originalName';
          await file.copy(destPath);
          showSavedToSnack(destPath);
        }
        return;
      }
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final ext = p.extension(originalName).replaceFirst('.', '');
        String? destPath;
        try {
          destPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save image as',
            fileName: originalName,
            type: FileType.custom,
            allowedExtensions: ext.isNotEmpty ? [ext] : ['jpg'],
          );
        } catch (_) {
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Choose folder to save image',
          );
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
        showSavedToSnack(destPath);
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  Future<void> _desktopDeleteGroupMessage(
      Map<String, dynamic> msg, String msgId) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.deleteMessageTitle,
      message: l.deleteGroupMsgContent,
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) _deleteGroupMessage(msgId);
  }

  void _startEditingGroupMessage(Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    final msgId = msg['id']?.toString();
    if (msgId == null) return;
    setState(() {
      _editingMsgId = msgId;
      _editingOriginalContent = content;
    });
    _textCtrl.text = content;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: content.length),
    );
    _focusNode.requestFocus();
  }

  void _cancelEditingGroupMessage() {
    setState(() {
      _editingMsgId = null;
      _editingOriginalContent = null;
    });
    _textCtrl.clear();
    _focusNode.requestFocus();
  }

  Future<void> _deleteGroupMessage(String msgId) async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    try {
      final resp = await http.delete(
        Uri.parse('$serverBase/group/${widget.group.id}/messages/$msgId'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200 && mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id']?.toString() == msgId);
          _allMessageIds.remove(msgId);
        });
        unawaited(_saveHistoryToCache(_messages));
      } else if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .failedDelete);
      }
    } catch (e) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .failedDelete);
    }
  }

  Future<void> _submitGroupMessageEdit(String msgId, String newContent) async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    try {
      final resp = await http.patch(
        Uri.parse('$serverBase/group/${widget.group.id}/messages/$msgId'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({'content': newContent}),
      );
      if (resp.statusCode == 200 && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id']?.toString() == msgId);
          if (idx >= 0) _messages[idx]['content'] = newContent;
        });
        unawaited(_saveHistoryToCache(_messages));
      } else if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value).failedEdit);
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value).failedEdit);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      _localRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _reminderKeysSub?.cancel();
    _selectionNotifier.dispose();
    _isDisposed = true;
    _localRouteObserver.unsubscribe(this);
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _stopDragAutoScroll();
    _scroll.dispose();
    _focusNode.dispose();
    rootScreenKey.currentState?.unsubscribeFromGroup(widget.group.id);
    _pendingMessageIds.clear();
    groupAvatarVersion.removeListener(_onGroupAvatarUpdate);
    _showScrollDownButton.dispose();
    _bottomBarHeight.dispose();
    _inputEntryController.dispose();
    _wsFlushTimer?.cancel();
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
      final totalItems = _rebuildGroupDisplayItems().length;
      if (totalItems == 0) return;
      final listIdx = matchAdjI;
      final maxExtent = _scroll.position.maxScrollExtent;
      final target = (maxExtent * listIdx / totalItems).clamp(0.0, maxExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void didPopNext() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void didUpdateWidget(covariant GroupChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.id != widget.group.id) {
      rootScreenKey.currentState?.unsubscribeFromGroup(oldWidget.group.id);
      rootScreenKey.currentState
          ?.subscribeToGroup(widget.group.id, _onGroupMsg);

      _allMessageIds.clear();
      _pendingMessageIds.clear();
      _messages.clear();
      _alreadyRenderedMessageIds.clear();
      _hasBuiltMessageListOnce = false;
      _wsIncomingBuffer.clear();
      _wsFlushTimer?.cancel();
      _wsFlushTimer = null;

      _focusNode.dispose();
      _focusNode = FocusNode();
      final randomIndex = Random().nextInt(_randomHints.length);
      setState(() {
        _inputHint = _randomHints[randomIndex];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
      _loadHistoryFromCache().then((_) {
        if (!_isDisposed) _loadHistoryFromNetwork();
      });
    }
  }

  Future<void> _serverToggleGroupReaction(
      int msgId, String emoji, bool remove) async {
    // Prefer root-screen username (always fresh) over cached _currentUsername
    final username =
        rootScreenKey.currentState?.currentUsername ?? _currentUsername ?? '';
    if (username.isEmpty) {
      debugPrint('[reaction.group] username empty, skipping server call');
      return;
    }
    if (_isDisposed) return;
    final token = await AccountManager.getToken(username);
    if (token == null) {
      debugPrint(
          '[reaction.group] token null for $username, skipping server call');
      return;
    }
    try {
      final groupId = widget.group.id;
      debugPrint(
          '[reaction.group] ${remove ? "DELETE" : "POST"} groupId=$groupId msgId=$msgId emoji=$emoji user=$username');
      http.Response resp;
      if (remove) {
        resp = await http.delete(
          Uri.parse(
              '$serverBase/group/$groupId/messages/$msgId/reactions/${Uri.encodeComponent(emoji)}'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        resp = await http.post(
          Uri.parse('$serverBase/group/$groupId/messages/$msgId/reactions'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'emoji': emoji}),
        );
      }
      debugPrint(
          '[reaction.group] server responded ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      debugPrint('[reaction.group] server error: $e');
    }
  }

  Future<void> _loadHistoryFromCache() async {
    final username = _currentUsername ?? '';
    if (username.isEmpty) return;
    try {
      final appDir = await getOnyxSupportDirectory();
      if (_isDisposed) return;
      final file = File(
          '${appDir.path}/group_${username}_${widget.group.id}_history.json');
      if (!await file.exists()) return;
      if (_isDisposed) return;
      final contents = await file.readAsString();
      if (_isDisposed) return;
      final data = jsonDecode(contents) as List;

      final newMessages = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final item in data) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          final tsStr = (item['timestamp'] ?? item['created_at'])?.toString() ??
              DateTime.now().toIso8601String();
          final tsMs = DateTime.tryParse(tsStr)?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch;
          final msg = {
            'id': id,
            'animationId': id,
            'sender': item['sender']?.toString() ?? '?',
            'content': item['content']?.toString() ?? '',
            'timestamp': tsStr,
            'timestamp_ms': tsMs,
            if (item['reply_to_id'] != null) 'reply_to_id': item['reply_to_id'],
            if (item['reply_to_sender'] != null)
              'reply_to_sender': item['reply_to_sender']?.toString(),
            if (item['reply_to_content'] != null)
              'reply_to_content': item['reply_to_content']?.toString(),
            if (item['reactions'] != null) 'reactions': item['reactions'],
            if (item['comment_count'] != null)
              'comment_count': item['comment_count'],
            if (item['last_comment_sender'] != null)
              'last_comment_sender': item['last_comment_sender']?.toString(),
            if (item['last_comment_content'] != null)
              'last_comment_content': item['last_comment_content']?.toString(),
          };
          newMessages.add(msg);
        }
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _messages = newMessages;
          _allMessageIds.addAll(seenIds);
          _loadedFromCache = true;
          if (_alreadyRenderedMessageIds.isEmpty) {
            _alreadyRenderedMessageIds.addAll(newMessages
                .map((m) =>
                    m['animationId']?.toString() ?? m['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty));
          }
        });
        final reactionBatch = <String, Map<String, dynamic>>{};
        for (final m in newMessages) {
          final mid = int.tryParse(m['id']?.toString() ?? '');
          final reactions = m['reactions'];
          if (mid != null && reactions is Map && reactions.isNotEmpty) {
            reactionBatch['gm_$mid'] = Map<String, dynamic>.from(reactions);
          }
        }
        if (reactionBatch.isNotEmpty) applyReactionBatch(reactionBatch);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      debugPrint('[GroupChat] cache load error: $e');
    }
  }

  Future<void> _loadHistoryFromNetwork() async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null || _isDisposed) return;
    try {
      final res = await http.get(
        Uri.parse('$serverBase/group/${widget.group.id}/history'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (_isDisposed) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        final newMessages = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final item in data) {
          final id = (item['id'] ??
                  item['message_id'] ??
                  '${DateTime.now().millisecondsSinceEpoch}')
              .toString();
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            final tsStr =
                (item['timestamp'] ?? item['created_at'])?.toString() ??
                    DateTime.now().toIso8601String();
            final tsMs = DateTime.tryParse(tsStr)?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch;
            newMessages.add({
              'id': id,
              'animationId': id,
              'sender': item['sender']?.toString() ?? '?',
              'content': item['content']?.toString() ?? '',
              'timestamp': tsStr,
              'timestamp_ms': tsMs,
              if (item['reply_to_id'] != null)
                'reply_to_id': item['reply_to_id'],
              if (item['reply_to_sender'] != null)
                'reply_to_sender': item['reply_to_sender']?.toString(),
              if (item['reply_to_content'] != null)
                'reply_to_content': item['reply_to_content']?.toString(),
              if (item['reactions'] != null) 'reactions': item['reactions'],
              if (item['comment_count'] != null)
                'comment_count': item['comment_count'],
              if (item['last_comment_sender'] != null)
                'last_comment_sender': item['last_comment_sender']?.toString(),
              if (item['last_comment_content'] != null)
                'last_comment_content':
                    item['last_comment_content']?.toString(),
            });
          }
        }

        if (_messages.isNotEmpty) {
          final cachedReplies = <String, Map<String, dynamic>>{};
          for (final m in _messages) {
            final mid = (m['id'] ?? '').toString();
            if (mid.isNotEmpty) {
              if (m['reply_to_content'] != null ||
                  m['reply_to_id'] != null ||
                  m['reply_to_sender'] != null) {
                cachedReplies[mid] = {
                  if (m['reply_to_id'] != null) 'reply_to_id': m['reply_to_id'],
                  if (m['reply_to_sender'] != null)
                    'reply_to_sender': m['reply_to_sender'],
                  if (m['reply_to_content'] != null)
                    'reply_to_content': m['reply_to_content'],
                };
              }
            }
          }

          for (final nm in newMessages) {
            final nid = (nm['id'] ?? '').toString();
            if (nid.isNotEmpty && cachedReplies.containsKey(nid)) {
              final cr = cachedReplies[nid]!;
              var copied = false;
              if ((nm['reply_to_content'] == null ||
                      (nm['reply_to_content']?.toString() ?? '').isEmpty) &&
                  cr['reply_to_content'] != null) {
                nm['reply_to_content'] = cr['reply_to_content'];
                copied = true;
              }
              if (nm['reply_to_id'] == null && cr['reply_to_id'] != null) {
                nm['reply_to_id'] = cr['reply_to_id'];
                copied = true;
              }
              if (nm['reply_to_sender'] == null &&
                  cr['reply_to_sender'] != null) {
                nm['reply_to_sender'] = cr['reply_to_sender'];
                copied = true;
              }
              if (copied)
                debugPrint(
                    '[GroupChat] preserved reply metadata for message id=$nid from cache');
            }
          }
        }

        await _saveHistoryToCache(newMessages);

        if (mounted && !_isDisposed) {
          setState(() {
            _messages = newMessages;
            _allMessageIds.clear();
            _allMessageIds.addAll(seenIds);
            if (_alreadyRenderedMessageIds.isEmpty) {
              _alreadyRenderedMessageIds.addAll(newMessages
                  .map((m) =>
                      m['animationId']?.toString() ?? m['id']?.toString() ?? '')
                  .where((id) => id.isNotEmpty));
            }
          });
          // Populate reaction mixin state from server history in one setState
          final reactionBatch = <String, Map<String, dynamic>>{};
          for (final m in newMessages) {
            final mid = int.tryParse(m['id']?.toString() ?? '');
            final reactions = m['reactions'];
            if (mid != null && reactions is Map && reactions.isNotEmpty) {
              reactionBatch['gm_$mid'] = Map<String, dynamic>.from(reactions);
            }
          }
          if (reactionBatch.isNotEmpty) applyReactionBatch(reactionBatch);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      if (mounted && !_loadedFromCache) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .noInternetCached);
      }
    }
  }

  Future<void> _saveHistoryToCache(List<Map<String, dynamic>> messages) async {
    try {
      final username = _currentUsername ?? '';
      if (username.isEmpty) return;
      final appDir = await getOnyxSupportDirectory();
      final file = File(
          '${appDir.path}/group_${username}_${widget.group.id}_history.json');
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(messages));
    } catch (e) {
      debugPrint('[GroupChat] cache save error: $e');
    }
  }

  void _onGroupAvatarUpdate() {
    final updates = groupAvatarVersion.value;
    final updatedVersion = updates[widget.group.id];
    if (updatedVersion != null && updatedVersion != _avatarVersion) {
      if (mounted) {
        setState(() {
          _avatarVersion = updatedVersion;
        });
      } else {
        _avatarVersion = updatedVersion;
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
        _scroll.animateTo(
          0.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _scrollToBottomIfNeeded() {
    if (!_scroll.hasClients) return;
    final current = _scroll.position.pixels;
    if (current <= 1.5) {
      _scroll.jumpTo(0.0);
    } else if (current <= 120) {
      _scroll.animateTo(
        0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _markMessagesAsRead() {
    final unreadIds = _messages
        .where((m) =>
            m['sender'] != _currentUsername &&
            m['sender'] != _currentDisplayName &&
            m['id'] != null)
        .map((m) => m['id'].toString())
        .toList();

    if (unreadIds.isNotEmpty) {
      _markGroupMessagesAsRead(unreadIds);
    }
  }

  void _markGroupMessagesAsRead(List<String> messageIds) async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;

    try {
      await http
          .post(
            Uri.parse('$serverBase/group/${widget.group.id}/mark-read'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode({'message_ids': messageIds}),
          )
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isReadOnlyChannel) return;

    if (_editingMsgId != null) {
      final editId = _editingMsgId!;
      _cancelEditingGroupMessage();
      await _submitGroupMessageEdit(editId, text.trim());
      return;
    }

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

    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;

    // Re-assert "online" presence on send — see root_screen._sendChatMessage
    // for why (multi-device offline-presence races showing us as offline).
    rootScreenKey.currentState?.sendOnlineStatus();

    final replyInfo = _replyingToMessage != null
        ? Map<String, dynamic>.from(_replyingToMessage!)
        : null;

    _textCtrl.clear();

    final tempMessageId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}';
    final now = DateTime.now().toIso8601String();

    if (mounted) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _messages.add({
          'id': tempMessageId,
          'animationId': tempMessageId,
          'sender': SettingsManager.showDisplayNameInGroups.value
              ? (_currentDisplayName ?? _currentUsername ?? '?')
              : 'Anonymous',
          'content': text,
          'timestamp': now,
          'timestamp_ms': nowMs,
          'firstAppearanceMs': nowMs,
          'isPending': true,
          if (replyInfo != null && replyInfo['id'] != null)
            'reply_to_id': replyInfo['id'],
          if (replyInfo != null && replyInfo['sender'] != null)
            'reply_to_sender': replyInfo['sender']?.toString(),
          if (replyInfo != null && replyInfo['content'] != null)
            'reply_to_content': replyInfo['content']?.toString(),
        });
        _allMessageIds.add(tempMessageId);

        _replyingToMessage = null;
      });
    }

    if (!_shouldPreserveExternalFocus && !recordingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }

    try {
      final body = {
        'content': text,
        if (!SettingsManager.showDisplayNameInGroups.value) 'anonymous': true,
        if (replyInfo != null && replyInfo['id'] != null)
          'reply_to_id':
              int.tryParse(replyInfo['id'].toString()) ?? replyInfo['id'],
        if (replyInfo != null &&
            (replyInfo['senderDisplayName'] ?? replyInfo['sender']) != null)
          'reply_to_sender':
              (replyInfo['senderDisplayName'] ?? replyInfo['sender'])
                  .toString(),
        if (replyInfo != null && replyInfo['content'] != null)
          'reply_to_content': replyInfo['content'].toString(),
      };
      debugPrint('[GroupChat] replyInfo=$replyInfo');
      debugPrint('[GroupChat] Sending message with body: $body');
      final response = await http.post(
        Uri.parse('$serverBase/group/${widget.group.id}/send'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        try {
          final respData = jsonDecode(response.body) as Map<String, dynamic>?;
          final serverMessageId =
              (respData?['message_id'] ?? respData?['id'])?.toString();
          if (serverMessageId != null && mounted) {
            _pendingMessageIds[tempMessageId] = serverMessageId;
            _allMessageIds.add(serverMessageId);
            setState(() {
              final msgIndex =
                  _messages.indexWhere((m) => m['id'] == tempMessageId);
              if (msgIndex >= 0) {
                _messages[msgIndex]['id'] = serverMessageId;
                _messages[msgIndex]['isPending'] = false;
                _allMessageIds.remove(tempMessageId);
              }

              _replyingToMessage = null;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              final msgIndex =
                  _messages.indexWhere((m) => m['id'] == tempMessageId);
              if (msgIndex >= 0) {
                _messages[msgIndex]['isPending'] = false;
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempMessageId);
          _allMessageIds.remove(tempMessageId);
        });
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value).sendFailed);
      }
    }
  }

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

  Future<void> _pickAndUploadMedia() async {
    if (_isReadOnlyChannel) return;
    if (kIsWeb) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
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
        await _handleGroupDroppedFiles(paths, skipBulkConfirm: true);
      } else {
        await _handleGroupDroppedFiles(paths);
      }
      return;
    }

    final path = paths.first;
    if (!FileTypeDetector.isAllowed(path)) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .unsupportedFileType(p.extension(path)));
      }
      return;
    }
    final basename = p.basename(path);
    final ext = p.extension(basename).toLowerCase();
    _showGroupFilePreviewAndSend(path, basename, ext);
  }

  Future<void> _processAndUploadFile(String filePath) async {
    if (_isReadOnlyChannel) return;
    final bytes = await File(filePath).readAsBytes();
    final basename = p.basename(filePath);
    const provider = MediaProvider.catbox;

    final fileType = FileTypeDetector.getFileType(filePath);
    final uploadType = fileType == 'IMAGE'
        ? 'image'
        : fileType == 'VIDEO'
            ? 'video'
            : fileType == 'AUDIO'
                ? 'audio'
                : 'file';

    // Create pending card immediately
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
      final link =
          await _uploadToProvider(bytes, basename, provider, task: task);
      if (link == null) {
        if (task.status != UploadStatus.paused && mounted) {
          setState(() {
            _pendingUploads.remove(task);
          });
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .uploadFailed);
        }
        return;
      }
      final typeMapping = {
        'IMAGE': 'image',
        'VIDEO': 'video',
        'AUDIO': 'audio'
      };
      final type = typeMapping[fileType]?.toLowerCase();
      final payload = jsonEncode({
        'url': link,
        'orig': basename,
        'provider': provider.name,
        if (type != null) 'type': type,
      });
      unawaited(_doSendToServer('MEDIA_PROXYv1:$payload'));
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

  Future<void> _processAndUploadAlbum(List<String> filePaths) async {
    if (_isReadOnlyChannel) return;
    if (filePaths.isEmpty) return;

    const provider = MediaProvider.catbox;

    final albumTask = UploadTask(
      id: 'album_${DateTime.now().millisecondsSinceEpoch}',
      type: 'album',
      localPath: '',
      basename: '',
    );
    albumTask.albumTotal = filePaths.length;
    albumTask.status = UploadStatus.uploading;
    if (mounted) setState(() => _pendingUploads.add(albumTask));

    final items = <Map<String, String>>[];
    try {
      for (final filePath in filePaths) {
        final basename = p.basename(filePath);
        final bytes = await File(filePath).readAsBytes();
        final link = await _uploadToProvider(bytes, basename, provider);
        if (link == null) {
          debugPrint('[group-album] upload failed for $basename');
          continue;
        }
        albumTask.albumDone++;
        albumTask.progress = albumTask.albumDone / albumTask.albumTotal;
        items.add({'url': link, 'orig': basename, 'provider': provider.name});
      }
    } finally {
      if (mounted) setState(() => _pendingUploads.remove(albumTask));
    }

    if (items.isEmpty) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .albumUploadFailed);
      return;
    }

    final payload = jsonEncode({'type': 'album', 'items': items});
    final content = 'MEDIA_PROXYv1:$payload';
    unawaited(_doSendToServer(content));
  }

  Future<bool> _showGroupMessagePreview(String text) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context).previewMessageTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).previewYourMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: SettingsManager.elementBrightness,
                    builder: (_, brightness, ___) {
                      final baseColor = SettingsManager.getElementColor(
                        Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        brightness,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(ctx).colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context).send),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed;
  }

  Future<void> _startRecording() async {
    if (_isReadOnlyChannel) return;
    rootScreenKey.currentState?.startRecording();
  }

  Future<void> _stopRecordingAndUpload() async {
    if (_isReadOnlyChannel) return;
    final path = rootScreenKey.currentState?.lastRecordedPathForUpload;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();

    Future<void> doVoiceUpload() async {
      final basename = p.basename(path);
      const provider = MediaProvider.catbox;
      final task = UploadTask(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: 'voice',
        localPath: path,
        basename: basename,
      );
      task.status = UploadStatus.uploading;
      if (mounted) setState(() => _pendingUploads.add(task));

      final link =
          await _uploadToProvider(bytes, basename, provider, task: task);
      if (mounted) setState(() => _pendingUploads.remove(task));

      if (link == null) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .voiceUploadFailed);
        }
        return;
      }
      final payload = jsonEncode({
        'url': link,
        'orig': basename,
        'provider': provider.name,
        'type': 'voice',
      });
      unawaited(_doSendToServer('MEDIA_PROXYv1:$payload'));
    }

    if (SettingsManager.confirmVoiceUpload.value) {
      final durationSeconds = (bytes.length / 16000).ceil();
      final duration = Duration(seconds: durationSeconds);

      if (mounted) {
        await showDialog<bool>(
              context: context,
              builder: (_) => VoiceConfirmDialog(
                duration: duration,
                onSend: () async {
                  await doVoiceUpload();
                },
                onCancel: () {
                  if (mounted) {
                    rootScreenKey.currentState?.showSnack(
                        lookupAppLocalizations(SettingsManager.appLocale.value)
                            .voiceCancelled);
                  }
                },
              ),
            ) ??
            false;
      }
    } else {
      await doVoiceUpload();
    }
  }

  Future<void> _doSendToServer(String content) async {
    if (_isReadOnlyChannel) return;
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$serverBase/group/${widget.group.id}/send'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json'
        },
        body: jsonEncode({
          'content': content,
          if (_replyingToMessage != null && _replyingToMessage!['id'] != null)
            'reply_to_id': _replyingToMessage!['id'].toString(),
          if (_replyingToMessage != null &&
              (_replyingToMessage!['senderDisplayName'] ??
                      _replyingToMessage!['sender']) !=
                  null)
            'reply_to_sender': (_replyingToMessage!['senderDisplayName'] ??
                    _replyingToMessage!['sender'])
                .toString(),
          if (_replyingToMessage != null &&
              _replyingToMessage!['content'] != null)
            'reply_to_content': _replyingToMessage!['content'].toString(),
        }),
      );

      if (_replyingToMessage != null && mounted) {
        setState(() {
          debugPrint(
              '[group_chat_screen::clear] clearing _replyingToMessage\n${StackTrace.current}');
          _replyingToMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  void _onGroupMsg(Map<String, dynamic> msg) {
    if (_isDisposed) return;

    final typ = msg['type'] as String?;

    if (typ == 'reaction_update') {
      final msgIdRaw = msg['message_id'];
      final msgId =
          msgIdRaw is int ? msgIdRaw : int.tryParse(msgIdRaw?.toString() ?? '');
      if (msgId != null && mounted) {
        final reactions = (msg['reactions'] as Map<String, dynamic>?) ?? {};
        // Update stored message data so it's correct when scrolled into view
        setState(() {
          final idx = _messages
              .indexWhere((m) => m['id']?.toString() == msgId.toString());
          if (idx >= 0) _messages[idx]['reactions'] = reactions;
        });
        // Update mixin state if message is currently rendered
        final key = _msgIdToReactionKey[msgId];
        if (key != null) applyReactionCounts(key, reactions);
        unawaited(_saveHistoryToCache(_messages));
      }
      return;
    }

    if (typ == 'group_msg_edited') {
      final editedId = (msg['message_id'] ?? '').toString();
      final newContent = msg['new_content'] as String?;
      if (editedId.isNotEmpty && newContent != null && mounted) {
        setState(() {
          final idx =
              _messages.indexWhere((m) => m['id']?.toString() == editedId);
          if (idx >= 0) _messages[idx]['content'] = newContent;
        });
        unawaited(_saveHistoryToCache(_messages));
      }
      return;
    }
    if (typ == 'group_msg_deleted') {
      final deletedId = (msg['message_id'] ?? '').toString();
      if (deletedId.isNotEmpty && mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id']?.toString() == deletedId);
          _allMessageIds.remove(deletedId);
        });
        unawaited(_saveHistoryToCache(_messages));
      }
      return;
    }

    if (typ == 'comment_added' ||
        typ == 'comment_deleted' ||
        typ == 'comment_reaction_update') {
      final postIdRaw = msg['post_id'];
      final postId =
          postIdRaw is int ? postIdRaw : int.tryParse(postIdRaw?.toString() ?? '');
      if (postId != null) {
        if (typ == 'comment_added') {
          final comment = msg['comment'] as Map<String, dynamic>?;
          _updateCommentCountLocal(postId, 1,
              lastSender: comment?['sender']?.toString(),
              lastContent: comment?['content']?.toString());
        } else if (typ == 'comment_deleted') {
          _updateCommentCountLocal(postId, -1);
        }
        if (_openCommentsPostId == postId) {
          _openCommentsKey?.currentState?.handleWsEvent(msg);
        }
      }
      return;
    }

    final messageId = (msg['message_id'] ?? '').toString();
    if (messageId.isEmpty) return;
    if (_allMessageIds.contains(messageId)) return;

    bool isOurMessage = false;
    String? tempMessageId;
    for (final entry in _pendingMessageIds.entries) {
      if (entry.value == messageId) {
        tempMessageId = entry.key;
        isOurMessage = true;
        break;
      }
    }
    if (!isOurMessage) {
      final msgContent = msg['content'] as String?;
      if (msgContent != null) {
        final pendingIndex = _messages.indexWhere((m) {
          return m['isPending'] == true &&
              m['content'] == msgContent &&
              (m['id'] as String?)?.startsWith('temp_') == true;
        });
        if (pendingIndex >= 0) {
          tempMessageId = _messages[pendingIndex]['id'] as String?;
          isOurMessage = true;
        }
      }
    }
    if (isOurMessage && tempMessageId != null) {
      _pendingMessageIds.remove(tempMessageId);
      if (mounted) {
        setState(() {
          final msgIndex =
              _messages.indexWhere((m) => m['id'] == tempMessageId);
          if (msgIndex >= 0) {
            final existingAnimId =
                _messages[msgIndex]['animationId']?.toString() ?? tempMessageId;
            _messages[msgIndex]['id'] = messageId;
            _messages[msgIndex]['isPending'] = false;
            _messages[msgIndex]['animationId'] = existingAnimId;
            _allMessageIds.remove(tempMessageId);
            _allMessageIds.add(messageId);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottomIfNeeded();
        });
        unawaited(_saveHistoryToCache(_messages));
      }
    } else {
      final replyContent = msg['reply_to_content']?.toString() ?? '';
      final tsStr = (msg['timestamp'] ??
              msg['created_at'] ??
              DateTime.now().toIso8601String())
          .toString();
      final tsMs = DateTime.tryParse(tsStr)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
      final newMsg = {
        'id': messageId,
        'animationId': messageId,
        'sender': (msg['sender'] as String?) ?? 'Anonymous',
        'content': (msg['content'] as String?) ?? '',
        'timestamp': tsStr,
        'timestamp_ms': tsMs,
        'firstAppearanceMs': DateTime.now().millisecondsSinceEpoch,
        if (msg['reply_to_id'] != null) 'reply_to_id': msg['reply_to_id'],
        if (msg['reply_to_sender'] != null)
          'reply_to_sender': msg['reply_to_sender']?.toString(),
        if (replyContent.isNotEmpty) 'reply_to_content': replyContent,
      };
      debugPrint(
          '[GroupChat] Received message from ${msg['sender']}: reply_to_id=${msg['reply_to_id']}, reply_to_sender=${msg['reply_to_sender']}, reply_to_content=${replyContent.length > 50 ? replyContent.substring(0, 50) : replyContent}');
      if (mounted) {
        _allMessageIds.add(messageId);
        _bufferIncomingMessage(newMsg);
      }
    }
  }

  // Mutates the cached comment_count (and, on a new comment, the
  // last-comment preview) on a loaded channel post in-place so the "N
  // comments" badge under its bubble stays live without a full history
  // refetch.
  void _updateCommentCountLocal(int postId, int delta,
      {String? lastSender, String? lastContent}) {
    if (!mounted) return;
    setState(() {
      final idx =
          _messages.indexWhere((m) => m['id']?.toString() == postId.toString());
      if (idx >= 0) {
        final current = (_messages[idx]['comment_count'] as num?)?.toInt() ?? 0;
        _messages[idx]['comment_count'] = (current + delta).clamp(0, 1 << 31);
        if (delta > 0) {
          _messages[idx]['last_comment_sender'] = lastSender;
          _messages[idx]['last_comment_content'] = lastContent;
        }
      }
    });
    unawaited(_saveHistoryToCache(_messages));
  }

  // A Telegram-style "N comments" bar under a channel post bubble — a
  // distinct card (not just an inline label) showing the count plus a
  // one-line preview of the most recent comment, if any. Kept pixel-identical
  // to ExternalGroupChatScreen._buildCommentsAffordance so internal and
  // external channels look the same.
  Widget _buildCommentsAffordance(
      BuildContext context, ColorScheme colorScheme, Map<String, dynamic> msg) {
    final l = AppLocalizations.of(context);
    final count = (msg['comment_count'] as num?)?.toInt() ?? 0;
    final lastSender = msg['last_comment_sender']?.toString();
    final lastContent = msg['last_comment_content']?.toString();
    final hasPreview = count > 0 &&
        lastSender != null &&
        lastSender.isNotEmpty &&
        lastContent != null;

    return GestureDetector(
      onTap: () => _openCommentsThread(msg),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // IntrinsicWidth makes the pill hug its content (ending right after
        // "Comment"/the preview text) instead of stretching to the bubble's
        // full width; the ConstrainedBox below still caps it so a long
        // preview ellipsizes rather than growing the pill unbounded.
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              // Full stadium/pill shape rather than a soft-rounded card.
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mode_comment_rounded,
                    size: 13, color: colorScheme.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        count == 0
                            ? l.addCommentAction
                            : l.commentsCount(count),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      if (hasPreview) ...[
                        const SizedBox(height: 1),
                        Text(
                          '$lastSender: ${getPreviewText(lastContent)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCommentsThread(Map<String, dynamic> msg) async {
    final postIdRaw = msg['id'];
    final postId =
        postIdRaw is int ? postIdRaw : int.tryParse(postIdRaw?.toString() ?? '');
    if (postId == null) return;

    final key = GlobalKey<PostCommentsScreenState>();
    _openCommentsPostId = postId;
    _openCommentsKey = key;
    await showPostCommentsDialog(
      context: context,
      groupId: widget.group.id,
      postId: postId,
      postSender: widget.group.name,
      postContent: msg['content']?.toString() ?? '',
      canDeleteAny: _isOwner,
      onPickAttachment: pickAndUploadCommentAttachment,
      onUploadVoice: uploadCommentVoiceBytes,
      key: key,
    );
    _openCommentsPostId = null;
    _openCommentsKey = null;
  }

  // Pick a single image/video and upload it, returning the encoded
  // MEDIA_PROXYv1 content string ready to post — used by the comment thread
  // dialog's attach button, which posts to a comments endpoint instead of
  // the main chat's /send. Deliberately skips the bulk/album/drag-drop paths
  // _pickAndUploadMedia supports: a comment only ever carries one attachment.
  // Mirrors ExternalGroupChatScreen.pickAndUploadCommentAttachment.
  Future<String?> pickAndUploadCommentAttachment() async {
    if (kIsWeb) {
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value)
              .mediaUploadNotSupportedWeb);
      return null;
    }

    String? path;
    if (Platform.isAndroid || Platform.isIOS) {
      final paths = await showMediaPickerSheet(context);
      path = (paths != null && paths.isNotEmpty) ? paths.first : null;
    } else {
      try {
        final result = await FilePicker.platform.pickFiles(type: FileType.media);
        path = result?.files.first.path;
      } catch (e) {
        debugPrint('[comment-attach] FilePicker error: $e');
        rootScreenKey.currentState?.showSnack('File picker error: $e');
        return null;
      }
    }
    if (path == null) return null;

    final fileType = FileTypeDetector.getFileType(path);
    if (fileType != 'IMAGE' && fileType != 'VIDEO') {
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value)
              .unsupportedFileType(p.extension(path)));
      return null;
    }

    final bytes = await File(path).readAsBytes();
    final basename = p.basename(path);
    const provider = MediaProvider.catbox;
    final link = await _uploadToProvider(bytes, basename, provider);
    if (link == null) {
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value)
              .uploadFailed);
      return null;
    }

    final type = fileType == 'IMAGE' ? 'image' : 'video';
    final payload = jsonEncode({
      'url': link,
      'orig': basename,
      'provider': provider.name,
      'type': type,
    });
    return 'MEDIA_PROXYv1:$payload';
  }

  // Uploads already-recorded voice bytes and returns the encoded
  // MEDIA_PROXYv1 content string — mirrors _stopRecordingAndUpload but
  // returns the content instead of sending it as a main-chat message, so the
  // comment dialog can post it to the comments endpoint itself.
  Future<String?> uploadCommentVoiceBytes(Uint8List bytes) async {
    final recordedPath = rootScreenKey.currentState?.lastRecordedPathForUpload;
    final ext = recordedPath != null ? p.extension(recordedPath) : '.wav';
    final basename = 'voice_${DateTime.now().millisecondsSinceEpoch}$ext';
    const provider = MediaProvider.catbox;

    final link = await _uploadToProvider(bytes, basename, provider);
    if (link == null) {
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value)
              .voiceUploadFailed);
      return null;
    }
    final payload = jsonEncode({
      'url': link,
      'orig': basename,
      'provider': provider.name,
      'type': 'voice',
    });
    return 'MEDIA_PROXYv1:$payload';
  }

  void _bufferIncomingMessage(Map<String, dynamic> msg) {
    _wsIncomingBuffer.add(msg);
    if (_wsIncomingBuffer.length >= _wsBatchSize) {
      _flushIncomingMessages();
      return;
    }
    _wsFlushTimer ??= Timer(Duration(milliseconds: _wsBatchDelayMs), () {
      _flushIncomingMessages();
    });
  }

  void _flushIncomingMessages() {
    _wsFlushTimer?.cancel();
    _wsFlushTimer = null;
    if (_wsIncomingBuffer.isEmpty) return;

    final toAdd = List<Map<String, dynamic>>.from(_wsIncomingBuffer);
    _wsIncomingBuffer.clear();

    // No suppressAnimation cutoff here — ChatScreen (1:1) never gates the
    // entrance animation either, so every message gets the same growing-slot
    // entrance regardless of batch size. Capping it to the last N caused the
    // rest to snap in at full height in a single frame, which is what made
    // group/channel message bursts look like an abrupt jump compared to 1:1.

    final idsToAdd = <String>[];
    for (final m in toAdd) {
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty) {
        m['animationId'] = m['animationId']?.toString() ?? id;
        idsToAdd.add(id);
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _messages.addAll(toAdd);
        _allMessageIds.addAll(idsToAdd);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottomIfNeeded();
      });
      unawaited(_saveHistoryToCache(_messages));
    } else {
      _messages.addAll(toAdd);
      _allMessageIds.addAll(idsToAdd);
    }
  }

  Future<void> _loadMemberCount() async {
    try {
      final token = await AccountManager.getToken(_currentUsername ?? '');
      if (token == null || _isDisposed) return;
      final res = await http.get(
        Uri.parse('$serverBase/group/${widget.group.id}/members'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200 || _isDisposed) return;
      final body = jsonDecode(res.body);
      int? count;
      if (body is Map) {
        if (body.containsKey('member_count')) {
          count = (body['member_count'] as num?)?.toInt();
        } else if (body.containsKey('members') && body['members'] is List) {
          count = (body['members'] as List).length;
        }
      }
      if (count != null && mounted) {
        setState(() => _memberCount = count);
      }
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  Future<void> _leaveGroup() async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    try {
      final res = await http.post(
        Uri.parse('$serverBase/group/${widget.group.id}/leave'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        if (mounted) {
          try {
            final username = _currentUsername ?? '';
            final appDir = await getOnyxSupportDirectory();
            final file = File(
                '${appDir.path}/group_${username}_${widget.group.id}_history.json');
            if (await file.exists()) await file.delete();
          } catch (e) {
            debugPrint('[err] $e');
          }
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .leftGroup);
          final username = _currentUsername ?? '';
          if (username.isNotEmpty) {
            final cached = await AccountManager.loadGroupsCache(username);
            await AccountManager.saveGroupsCache(
              username,
              cached.where((g) => g.id != widget.group.id).toList(),
            );
            groupsVersion.value++;
          }
          if (isDesktop) {
            rootScreenKey.currentState?.hideDetailPanel();
          } else {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .failedLeaveGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .networkError);
      }
    }
  }

  Future<bool?> _showLeaveConfirmation(BuildContext context) {
    final l = AppLocalizations.of(context);
    return showOnyxConfirmDialog(
      context: context,
      title: l.leaveGroupTitle(widget.group.isChannel.toString()),
      message: l.leaveGroupContent(widget.group.name),
      confirmLabel: l.leave,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
  }

  Future<void> _uploadGroupAvatar() async {
    if (!_canManageGroup) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .avatarOnlyOwnerMod);
      }
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.isEmpty ?? true) return;
    final file = result!.files.first;
    final path = file.path;
    Uint8List? bytes;
    String filename;
    if (kIsWeb) {
      if (file.bytes == null) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .failedReadFile);
        }
        return;
      }
      bytes = file.bytes!;
      filename = file.name;
    } else {
      if (path == null) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .localFileRequired);
        }
        return;
      }
      bytes = await File(path).readAsBytes();
      filename = p.basename(path);
    }

    if (!mounted) return;
    final cropped = await showAvatarCropScreen(context, bytes);
    if (cropped == null) return;
    bytes = cropped;

    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    String? mimeType;
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        mimeType = 'image/jpeg';
        break;
      case '.png':
        mimeType = 'image/png';
        break;
      case '.webp':
        mimeType = 'image/webp';
        break;
      case '.gif':
        mimeType = 'image/gif';
        break;
      default:
        mimeType = 'image/jpeg';
    }
    final contentType = MediaType.parse(mimeType);
    if (mounted) {
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value)
              .uploadingAvatar);
    }
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$serverBase/group/${widget.group.id}/avatar'),
      );
      req.headers['authorization'] = 'Bearer $token';
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final newVersion = body['avatar_version'] is int
              ? body['avatar_version'] as int
              : int.tryParse(body['avatar_version']?.toString() ?? '');
          if (newVersion != null) {
            _avatarVersion = newVersion;

            final username = rootScreenKey.currentState?.currentUsername ?? '';
            final cached = await AccountManager.loadGroupsCache(username);
            final updated = cached
                .map((g) => g.id == widget.group.id
                    ? Group(
                        id: g.id,
                        name: g.name,
                        isChannel: g.isChannel,
                        owner: g.owner,
                        inviteLink: g.inviteLink,
                        avatarVersion: newVersion,
                        myRole: g.myRole)
                    : g)
                .toList();
            await AccountManager.saveGroupsCache(username, updated);

            final currentMap = Map<int, int>.from(groupAvatarVersion.value);
            currentMap[widget.group.id] = newVersion;
            groupAvatarVersion.value = currentMap;
          }
        } catch (e) {
          debugPrint('[err] $e');
        }

        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .avatarUpdatedGroup);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .failedUpdateGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .networkError);
      }
    }
  }

  Future<void> _deleteGroupAvatar() async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    try {
      final res = await http.delete(
        Uri.parse('$serverBase/group/${widget.group.id}/avatar'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final newVersion = body['avatar_version'] is int
              ? body['avatar_version'] as int
              : int.tryParse(body['avatar_version']?.toString() ?? '');
          if (newVersion != null) {
            _avatarVersion = newVersion;
          }
        } catch (e) {
          debugPrint('[err] $e');
        }

        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .avatarDeleted);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .failedDeleteAvatar);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .networkError);
      }
    }
  }

  Future<void> _uploadGroupAvatarBytes(Uint8List bytes, String filename) async {
    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;
    String? mimeType;
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        mimeType = 'image/jpeg';
        break;
      case '.png':
        mimeType = 'image/png';
        break;
      case '.webp':
        mimeType = 'image/webp';
        break;
      case '.gif':
        mimeType = 'image/gif';
        break;
      default:
        mimeType = 'image/jpeg';
    }
    final contentType = MediaType.parse(mimeType);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$serverBase/group/${widget.group.id}/avatar'),
      );
      req.headers['authorization'] = 'Bearer $token';
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      );
      final resp = await http.Response.fromStream(await req.send());
      if (resp.statusCode == 200) {
        try {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final newVersion = body['avatar_version'] is int
              ? body['avatar_version'] as int
              : int.tryParse(body['avatar_version']?.toString() ?? '');
          if (newVersion != null) {
            _avatarVersion = newVersion;
            final username = rootScreenKey.currentState?.currentUsername ?? '';
            final cached = await AccountManager.loadGroupsCache(username);
            final updated = cached
                .map((g) => g.id == widget.group.id
                    ? Group(
                        id: g.id,
                        name: g.name,
                        isChannel: g.isChannel,
                        owner: g.owner,
                        inviteLink: g.inviteLink,
                        avatarVersion: newVersion,
                        myRole: g.myRole)
                    : g)
                .toList();
            await AccountManager.saveGroupsCache(username, updated);
            final currentMap = Map<int, int>.from(groupAvatarVersion.value);
            currentMap[widget.group.id] = newVersion;
            groupAvatarVersion.value = currentMap;
          }
        } catch (e) {
          debugPrint('[err] $e');
        }

        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .avatarUpdatedGroup);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              lookupAppLocalizations(SettingsManager.appLocale.value)
                  .failedUpdateGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .networkError);
      }
    }
  }

  Future<void> _showEditGroupDialog() async {
    _shouldPreserveExternalFocus = true;
    _focusNode.unfocus();
    final controller = TextEditingController(text: widget.group.name);
    bool isUploading = false;

    Future<void> changeAvatarInDialog(StateSetter setDialogState) async {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result?.files.isEmpty ?? true) return;
      final file = result!.files.first;
      String filename;
      Uint8List bytes;
      if (kIsWeb) {
        if (file.bytes == null) return;
        bytes = file.bytes!;
        filename = file.name;
      } else {
        if (file.path == null) return;
        bytes = await File(file.path!).readAsBytes();
        filename = p.basename(file.path!);
      }

      setDialogState(() => isUploading = true);
      if (!mounted) return;
      final cropped = await showAvatarCropScreen(context, bytes);
      if (cropped == null) {
        setDialogState(() => isUploading = false);
        return;
      }

      await _uploadGroupAvatarBytes(cropped, filename);
      setDialogState(() => isUploading = false);
    }

    void removeAvatarInDialog(StateSetter setDialogState) async {
      setDialogState(() => isUploading = true);
      await _deleteGroupAvatar();
      setDialogState(() => isUploading = false);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          const btnShape = RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(50)),
          );
          const btnPadding = EdgeInsets.symmetric(vertical: 13);
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.06),
                          border: Border(
                            bottom: BorderSide(
                              color: cs.primary.withValues(alpha: 0.10),
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.group.isChannel
                                    ? Icons.campaign_rounded
                                    : Icons.group_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.group.isChannel
                                    ? AppLocalizations.of(context)
                                        .editChannelTitle
                                    : AppLocalizations.of(context)
                                        .editGroupTitle,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(false),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.close_rounded,
                                    size: 18,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.55)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Content ─────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        changeAvatarInDialog(setDialogState),
                                    onLongPress: () =>
                                        removeAvatarInDialog(setDialogState),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundImage: NetworkImage(
                                          '$serverBase/group/${widget.group.id}/avatar?v=${_avatarVersion}'),
                                    ),
                                  ),
                                  if (isUploading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ValueListenableBuilder<double>(
                              valueListenable:
                                  SettingsManager.elementBrightness,
                              builder: (_, brightness, ___) {
                                final baseColor =
                                    SettingsManager.getElementColor(
                                  cs.surfaceContainerHighest,
                                  brightness,
                                );
                                return TextField(
                                  controller: controller,
                                  maxLength: 50,
                                  decoration: InputDecoration(
                                    labelText: widget.group.isChannel
                                        ? AppLocalizations.of(context)
                                            .channelNameLabel
                                        : AppLocalizations.of(context)
                                            .groupNameLabel,
                                    hintText: widget.group.isChannel
                                        ? AppLocalizations.of(context)
                                            .channelNameHint
                                        : AppLocalizations.of(context)
                                            .groupNameHint,
                                    counterText: '',
                                    filled: true,
                                    fillColor: baseColor.withValues(alpha: 0.3),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(50)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide(
                                          color: cs.outlineVariant
                                              .withValues(alpha: 0.3),
                                          width: 0.8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide(
                                          color: cs.primary, width: 1.4),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label:
                                    Text(AppLocalizations.of(context).copyLink),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: widget.group.inviteLink
                                          .split('/')
                                          .last));
                                  if (mounted) {
                                    rootScreenKey.currentState?.showSnack(
                                        lookupAppLocalizations(
                                                SettingsManager.appLocale.value)
                                            .tokenCopied);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: btnPadding,
                                shape: btnShape,
                              ),
                              onPressed: () async {
                                final newName = controller.text.trim();
                                if (newName.isEmpty || newName.length > 50) {
                                  if (mounted) {
                                    rootScreenKey.currentState?.showSnack(
                                        lookupAppLocalizations(
                                                SettingsManager.appLocale.value)
                                            .groupNameLength);
                                  }
                                  return;
                                }

                                final token = await AccountManager.getToken(
                                    _currentUsername ?? '');
                                if (token == null) return;
                                try {
                                  final res = await http.post(
                                    Uri.parse(
                                        '$serverBase/group/${widget.group.id}/rename'),
                                    headers: {
                                      'authorization': 'Bearer $token',
                                      'content-type': 'application/json'
                                    },
                                    body: jsonEncode({'name': newName}),
                                  );
                                  if (res.statusCode == 200) {
                                    try {
                                      final j = jsonDecode(res.body)
                                          as Map<String, dynamic>;
                                      final updatedName = j['name']?.toString();
                                      if (updatedName != null) {
                                        final username = rootScreenKey
                                                .currentState
                                                ?.currentUsername ??
                                            '';
                                        final cached = await AccountManager
                                            .loadGroupsCache(username);
                                        final updated = cached
                                            .map((g) => g.id == widget.group.id
                                                ? Group(
                                                    id: g.id,
                                                    name: updatedName,
                                                    isChannel: g.isChannel,
                                                    owner: g.owner,
                                                    inviteLink: g.inviteLink,
                                                    avatarVersion:
                                                        g.avatarVersion,
                                                    myRole: g.myRole)
                                                : g)
                                            .toList();
                                        await AccountManager.saveGroupsCache(
                                            username, updated);

                                        groupsVersion.value++;

                                        final root = rootScreenKey.currentState;
                                        if (root != null &&
                                            root.selectedGroup != null &&
                                            root.selectedGroup!.id ==
                                                widget.group.id) {
                                          root.selectedGroup = Group(
                                              id: widget.group.id,
                                              name: updatedName,
                                              isChannel: widget.group.isChannel,
                                              owner: widget.group.owner,
                                              inviteLink:
                                                  widget.group.inviteLink,
                                              avatarVersion:
                                                  widget.group.avatarVersion,
                                              myRole: widget.group.myRole);
                                          root.setState(() {});
                                        }
                                        setState(() {});
                                      }
                                    } catch (e) {
                                      debugPrint('[err] $e');
                                    }

                                    if (mounted) {
                                      rootScreenKey.currentState?.showSnack(
                                          lookupAppLocalizations(SettingsManager
                                                  .appLocale.value)
                                              .groupUpdated);
                                    }
                                    Navigator.of(ctx).pop(true);
                                  } else {
                                    if (mounted) {
                                      rootScreenKey.currentState?.showSnack(
                                          lookupAppLocalizations(SettingsManager
                                                  .appLocale.value)
                                              .failedUpdateGroup);
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    rootScreenKey.currentState?.showSnack(
                                        lookupAppLocalizations(
                                                SettingsManager.appLocale.value)
                                            .networkError);
                                  }
                                }
                              },
                              child: Text(AppLocalizations.of(context).save),
                            ),
                          ], // inner Column children
                        ), // inner Column
                      ), // Padding
                    ], // outer Column children
                  ), // outer Column
                ), // Material
              ), // ConstrainedBox
            ), // ClipRRect
          ); // Dialog return
        }, // StatefulBuilder.builder
      ), // StatefulBuilder
    ); // showDialog

    _shouldPreserveExternalFocus = false;
    if (mounted && isDesktop && !recordingNotifier.value) {
      _focusNode.requestFocus();
    }
    if (result == true) {
      setState(() {});
    }
  }

  bool get _isReadOnlyChannel => !widget.group.canPost;

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
                              borderRadius: BorderRadius.circular(28),
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
                                  onPressed: _cancelEditingGroupMessage,
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
                              borderRadius: BorderRadius.circular(28),
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
                                        widget.group.isChannel
                                            ? widget.group.name
                                            : (_replyingToMessage![
                                                        'senderDisplayName']
                                                    ?.toString() ??
                                                _replyingToMessage!['sender']
                                                    ?.toString() ??
                                                'Unknown'),
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
                                              .withOpacity(0.7),
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
              // Below the reply/edit preview, above the input bar — plain
              // Column children, so they stack instead of overlapping.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: _pendingUploads.isNotEmpty
                    ? UploadProgressBar(
                        tasks: _pendingUploads,
                        maxWidth: double.infinity,
                        showProgress:
                            false, // catbox upload — no byte-level progress
                        onCancelAll: _cancelAllUploads,
                      )
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
                              _handleGroupDroppedFiles([tempFile.path]);
                            }
                          } catch (e) {
                            debugPrint('[ContentInsert] Error: $e');
                          }
                        },
                      ),
                      readOnly: _isReadOnlyChannel,
                    );
                    if (!useGlass) return bar;
                    final quality =
                        SettingsManager.liquidGlassInputQuality.value;
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
                      shape: LiquidRoundedRectangle(borderRadius: 28),
                      clipBehavior: Clip.antiAlias,
                      child: bar,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // One-time dialog explaining that this group/channel is NOT end-to-end
  // encrypted (the server can read content) and that attached media is uploaded
  // to a public host (catbox.moe) reachable by anyone with the link.
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
                // Header with icon on a tinted band.
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
                // Body copy.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.e2eeWarnGroupBody,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _e2eeWarnRow(
                        cs,
                        Icons.public_rounded,
                        t.e2eeWarnGroupMedia,
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
                // Action.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarUrl =
        '$serverBase/group/${widget.group.id}/avatar?v=${_avatarVersion}';
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
                                    onPressed: _exitGroupSelectionMode,
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
                                  ? _exitGroupSelectionMode
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
                        final textContent = GestureDetector(
                          onTap: _canManageGroup ? _showEditGroupDialog : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: MarqueeText(
                                      text: widget.group.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                  if (widget.group.inviteLink ==
                                      '12e01467-c154-447b-84f8-133ae76684a1')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(Icons.verified_rounded,
                                          size: 15,
                                          color: Colors.blue.shade400),
                                    ),
                                ],
                              ),
                              if (_memberCount != null)
                                Text(
                                  AppLocalizations.of(context)
                                      .memberCount(_memberCount!),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.55)),
                                ),
                            ],
                          ),
                        );
                        final pill = AdaptiveGlassPill(
                          backgroundColor: bgColor,
                          borderColor: borderColor,
                          child: Row(
                            mainAxisSize:
                                isWide ? MainAxisSize.min : MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _canManageGroup
                                    ? _showEditGroupDialog
                                    : null,
                                onLongPress: _canManageGroup
                                    ? () async {
                                        final confirmed =
                                            await showOnyxConfirmDialog(
                                          context: context,
                                          title: AppLocalizations.of(context)
                                              .deleteAvatarTitle,
                                          message: AppLocalizations.of(context)
                                              .deleteAvatarContent,
                                          confirmLabel:
                                              AppLocalizations.of(context)
                                                  .delete,
                                          isDestructive: true,
                                          icon: Icons.delete_outline_rounded,
                                        );
                                        if (confirmed == true)
                                          await _deleteGroupAvatar();
                                      }
                                    : null,
                                child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(avatarUrl)),
                              ),
                              const SizedBox(width: 12),
                              if (isWide)
                                textContent
                              else
                                Expanded(child: textContent),
                            ],
                          ),
                        );
                        final wrappedPill = GestureDetector(
                          onTap: _canManageGroup ? _showEditGroupDialog : null,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: pill,
                          ),
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
                            if (sel.selected.values.any(_isGroupTextMessage))
                              selBtn(Icons.copy_rounded, null, 'Copy',
                                  _copySelectedGroupMessages),
                            if (sel.selected.isNotEmpty)
                              selBtn(Icons.forward_rounded, null, 'Forward',
                                  _forwardSelectedGroupMessages),
                            if (sel.selected.values.any(_isMyGroupMessage))
                              selBtn(
                                  Icons.delete_outline_rounded,
                                  cs.error,
                                  'Delete',
                                  _confirmDeleteSelectedGroupMessages),
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
                            const SizedBox(width: 4),
                            AdaptiveGlassIconButton(
                              backgroundColor: btnBg,
                              borderColor: btnBorder,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert,
                                    size: 20, color: iconColor),
                                onSelected: (String value) async {
                                  if (value == 'edit') {
                                    _showEditGroupDialog();
                                  } else if (value == 'gallery') {
                                    showMediaGalleryDialog(
                                      context,
                                      items: extractGalleryItemsFromMaps(
                                          _messages),
                                      peerUsername: widget.group.name,
                                      onJumpToMessage: (id) =>
                                          _scrollToGroupMessageById(id),
                                    );
                                  } else if (value == 'copy_link') {
                                    Clipboard.setData(ClipboardData(
                                        text: widget.group.inviteLink
                                            .split('/')
                                            .last));
                                    if (mounted) {
                                      rootScreenKey.currentState?.showSnack(
                                        lookupAppLocalizations(
                                                SettingsManager.appLocale.value)
                                            .tokenCopied,
                                      );
                                    }
                                  } else if (value == 'leave') {
                                    final confirmed =
                                        await _showLeaveConfirmation(context);
                                    if (confirmed == true) await _leaveGroup();
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (_canManageGroup)
                                    PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 10),
                                        Text(AppLocalizations.of(context)
                                            .editGroupTitle),
                                      ]),
                                    ),
                                  PopupMenuItem<String>(
                                    value: 'gallery',
                                    child: Row(children: [
                                      const Icon(Icons.photo_library_outlined,
                                          size: 18),
                                      const SizedBox(width: 10),
                                      Text(AppLocalizations.of(context)
                                          .galleryMenuLabel),
                                    ]),
                                  ),
                                  if (widget.group.inviteLink.isNotEmpty)
                                    PopupMenuItem<String>(
                                      value: 'copy_link',
                                      child: Row(children: [
                                        Icon(Icons.copy,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                        const SizedBox(width: 10),
                                        Text(
                                            AppLocalizations.of(context).token),
                                      ]),
                                    ),
                                  PopupMenuItem<String>(
                                    value: 'leave',
                                    child: Row(children: [
                                      Icon(Icons.logout_rounded,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error),
                                      const SizedBox(width: 10),
                                      Text(AppLocalizations.of(context)
                                          .leaveGroupAction),
                                    ]),
                                  ),
                                ],
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
        onFilesDropped: _handleGroupDroppedFiles,
        enabled: !_isReadOnlyChannel,
        child: Stack(
          children: [
            const ChatBackgroundLayer(),
            ValueListenableBuilder<bool>(
              valueListenable: SettingsManager.showAvatarInChats,
              builder: (_, showAvatar, __) {
                return ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.swapMessageAlignment,
                  builder: (_, swapped, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.alignAllMessagesRight,
                      builder: (_, alignRight, __) {
                        if (_messages.isEmpty) {
                          return EmptyChatPlaceholder(
                              label:
                                  AppLocalizations.of(context).noMessagesYet);
                        }
                        // Only flip this after a frame that actually
                        // had history loaded — flipping it on an
                        // empty/placeholder frame (history still
                        // loading from cache/network) meant the real
                        // history, once it arrived, looked like
                        // "newly arrived" messages and animated in.
                        if (!_hasBuiltMessageListOnce) {
                          if (_alreadyRenderedMessageIds.isEmpty) {
                            // No pre-seeded history → first message
                            // in a brand-new group. Set immediately
                            // so the bubble mounts with animate:true
                            // (AnimatedMessageBubble.didUpdateWidget
                            // is a no-op — must be true at mount).
                            _hasBuiltMessageListOnce = true;
                          } else {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _hasBuiltMessageListOnce = true;
                            });
                          }
                        }

                        // Compute search matches (indices into display items)
                        final displayItems = _rebuildGroupDisplayItems();

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
                        // Deferred for the same reason as ChatScreen:
                        // both caches go stale on every send (hash
                        // derived from message count), and the
                        // full-history recompute is expensive enough
                        // in heavy chats to block the frame the new
                        // bubble's entrance animation starts on.
                        if (_cachedDragHash != _groupDisplayHash) {
                          final targetHash = _groupDisplayHash;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || _cachedDragHash == targetHash)
                              return;
                            final dragMessages = displayItems
                                .whereType<Map<String, dynamic>>()
                                .toList(growable: false);
                            setState(() {
                              _cachedDragHash = targetHash;
                              _dragSelectionOrder = dragMessages
                                  .map(_selectionKeyForGroupMessage)
                                  .toList(growable: false);
                              _dragSelectionLookup = {
                                for (final msg in dragMessages)
                                  _selectionKeyForGroupMessage(msg): msg,
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
                              ChatImagesScope.computeFromGroupMessages(
                                  _messages);
                          _cachedAllImagesHash = _groupDisplayHash;
                        } else if (_cachedAllImagesHash != _groupDisplayHash) {
                          final targetHash = _groupDisplayHash;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || _cachedAllImagesHash == targetHash)
                              return;
                            final recomputed =
                                ChatImagesScope.computeFromGroupMessages(
                                    _messages);
                            if (!mounted) return;
                            setState(() {
                              _cachedAllImages = recomputed;
                              _cachedAllImagesHash = targetHash;
                            });
                          });
                        }

                        // Maps each item's stable String key to its
                        // current flat ListView index — see the
                        // matching findChildIndexCallback below for
                        // why this exists (without it, every visible
                        // bubble gets destroyed + rebuilt from
                        // scratch on every single send).
                        final Map<String, int> itemKeyToFlatIndex = {};
                        for (int idx = 0; idx < displayItems.length; idx++) {
                          final flatIndex = idx;
                          final item = displayItems[idx];
                          if (item is DateTime) {
                            itemKeyToFlatIndex[
                                'day_${item.toIso8601String()}'] = flatIndex;
                          } else if (item is Map<String, dynamic>) {
                            final itemAnimKey = item['animationId']
                                    ?.toString() ??
                                item['id']?.toString() ??
                                '${item['timestamp']}_${widget.group.isChannel ? widget.group.name : (item['sender']?.toString() ?? '?')}_${(item['content']?.toString() ?? '').hashCode}';
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
                              if (_isDragSelectingMessages)
                                _endGroupDragSelection();
                            },
                            onPointerCancel: (_) {
                              if (_isDragSelectingMessages)
                                _endGroupDragSelection();
                            },
                            child: ListView.builder(
                              controller: _scroll,
                              reverse: true,
                              itemCount: displayItems.length,
                              cacheExtent:
                                  SettingsManager.chatCacheExtent.value,
                              addRepaintBoundaries: true,
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top +
                                    kToolbarHeight +
                                    (_showSearch ? 64 : 12),
                                bottom:
                                    72 + MediaQuery.of(context).padding.bottom,
                              ),
                              findChildIndexCallback: (Key key) {
                                if (key is! ValueKey<String>) return null;
                                return itemKeyToFlatIndex[key.value];
                              },
                              itemBuilder: (ctx, i) {
                                final adjustedI = i;
                                final item = displayItems[adjustedI];

                                // Day separator
                                if (item is DateTime) {
                                  return KeyedSubtree(
                                    key: ValueKey<String>(
                                        'day_${item.toIso8601String()}'),
                                    child: _buildGroupDaySeparator(ctx, item),
                                  );
                                }

                                final msg = item as Map<String, dynamic>;
                                final rawSender =
                                    msg['sender']?.toString() ?? '?';
                                final sender = widget.group.isChannel
                                    ? widget.group.name
                                    : rawSender;
                                final content =
                                    msg['content']?.toString() ?? '';
                                final isMe = widget.group.isChannel
                                    ? false
                                    : (rawSender == _currentUsername ||
                                        rawSender == _currentDisplayName);
                                final isSearchMatch = _searchQuery.isNotEmpty &&
                                    content
                                        .toLowerCase()
                                        .contains(_searchQuery);
                                final isCurrentSearchMatch = isSearchMatch &&
                                    _cachedSearchMatches.isNotEmpty &&
                                    _cachedSearchMatches[_currentMatchIdx] ==
                                        adjustedI;

                                bool showSenderInfo = !widget.group.isChannel;

                                final bool showAvatarForThisMessage = (() {
                                  for (int j = adjustedI + 1;
                                      j < displayItems.length;
                                      j++) {
                                    final next = displayItems[j];
                                    if (next is Map<String, dynamic>) {
                                      return next['sender']?.toString() !=
                                          rawSender;
                                    }
                                  }
                                  return true;
                                })();

                                final bubble = Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.7),
                                  child: SwipeableMessageWrapper(
                                    onSwipeRight: () => _onGroupLongPress(msg),
                                    onSwipeLeft: widget.group.canPost
                                        ? () {
                                            final preview = {
                                              'id': msg['id']?.toString(),
                                              'sender': rawSender,
                                              'senderDisplayName': sender,
                                              'content':
                                                  getPreviewText(content),
                                            };
                                            _startReplyingToMessage(preview);
                                          }
                                        : null,
                                    child: GestureDetector(
                                      onTapDown: (tap) {
                                        debugPrint(
                                            '[group_chat_screen::msgTapDown] tapped message id=${msg['id']} replying=${_replyingToMessage != null} reply=${_replyingToMessage?.toString()}\n${StackTrace.current}');
                                      },
                                      child: MessageBubble(
                                        key: ValueKey<String>(
                                            'mb_${msg['timestamp']}_${sender}_${content.hashCode}'),
                                        text: content,
                                        outgoing: isMe,
                                        rawPreview: null,
                                        serverMessageId: null,
                                        hasReminder: _hasReminderSync(
                                            msg['id']?.toString()),
                                        time: (msg['timestamp_ms'] != null)
                                            ? DateTime
                                                .fromMillisecondsSinceEpoch(
                                                    msg['timestamp_ms'] as int)
                                            : (DateTime.tryParse(
                                                    msg['timestamp']) ??
                                                DateTime.now()),
                                        onRequestResend: (_) {},
                                        desktopMenuItems: isDesktop
                                            ? _buildGroupDesktopMenuItems(msg)
                                            : null,
                                        peerUsername: sender,
                                        replyToId: msg['reply_to_id'] is int
                                            ? msg['reply_to_id'] as int
                                            : (msg['reply_to_id'] != null
                                                ? int.tryParse(
                                                    msg['reply_to_id']
                                                        .toString())
                                                : null),
                                        replyToUsername:
                                            msg['reply_to_sender'] != null
                                                ? (widget.group.isChannel
                                                    ? widget.group.name
                                                    : msg['reply_to_sender']
                                                        .toString())
                                                : null,
                                        replyToContent:
                                            msg['reply_to_content']?.toString(),
                                        highlighted:
                                            (_replyingToMessage != null &&
                                                _replyingToMessage!['id']
                                                        ?.toString() ==
                                                    msg['id']?.toString()),
                                        onReplyTap: msg['reply_to_id'] != null
                                            ? () => _scrollToGroupMessageById(
                                                msg['reply_to_id'].toString())
                                            : null,
                                        onRightClick: isDesktop
                                            ? (offset) {
                                                debugPrint(
                                                    '[RightClickMenu] group_chat onRightClick invoked, msgId=${msg['id']}');
                                                final items =
                                                    _buildGroupDesktopMenuItems(
                                                        msg);
                                                debugPrint(
                                                    '[RightClickMenu] group_chat items=${items.length}');
                                                if (items.isNotEmpty) {
                                                  showMessageDesktopMenu(
                                                      context, offset, items);
                                                }
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                                final uniqueKey =
                                    '${msg['timestamp']}_${sender}_${content.hashCode}';
                                // Stable server-based key for reactions
                                final rMsgId =
                                    int.tryParse(msg['id']?.toString() ?? '');
                                final reactionKey = 'gm_${msg['id']}';
                                if (rMsgId != null)
                                  _msgIdToReactionKey[rMsgId] = reactionKey;
                                final animKey =
                                    msg['animationId']?.toString() ??
                                        msg['id']?.toString() ??
                                        uniqueKey;

                                final isFirstAppearance =
                                    !_alreadyRenderedMessageIds
                                        .contains(animKey);
                                if (isFirstAppearance) {
                                  _alreadyRenderedMessageIds.add(animKey);
                                }

                                final shouldAlignRight = alignRight
                                    ? !swapped
                                    : ((swapped && !isMe) ||
                                        (!swapped && isMe));
                                // Sender name/avatar row lives INSIDE
                                // AnimatedMessageBubble's child (below)
                                // rather than as a sibling above it.
                                // It used to sit outside, so it popped
                                // in at full height in a single frame
                                // while only the bubble below it grew
                                // smoothly — the mismatch is what made
                                // the whole row look like it jumped.
                                final Widget? senderInfoRow = showSenderInfo
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if ((swapped && isMe) ||
                                                (!swapped && !isMe))
                                              (showAvatar &&
                                                      showAvatarForThisMessage)
                                                  ? RepaintBoundary(
                                                      child: widget
                                                              .group.isChannel
                                                          ? CircleAvatar(
                                                              radius: 10,
                                                              backgroundImage:
                                                                  NetworkImage(
                                                                      '$serverBase/group/${widget.group.id}/avatar?v=${_avatarVersion}'),
                                                            )
                                                          : AvatarWidget(
                                                              key: ValueKey(
                                                                  'avatar-$sender'),
                                                              username: sender,
                                                              tokenProvider:
                                                                  () async =>
                                                                      null,
                                                              size: 20,
                                                              editable: false,
                                                            ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            if (((swapped && isMe) ||
                                                    (!swapped && !isMe)) &&
                                                showAvatar &&
                                                showAvatarForThisMessage)
                                              const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                sender,
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
                                            if (((swapped && !isMe) ||
                                                    (!swapped && isMe)) &&
                                                showAvatar &&
                                                showAvatarForThisMessage)
                                              const SizedBox(width: 6),
                                            if ((swapped && !isMe) ||
                                                (!swapped && isMe))
                                              (showAvatar &&
                                                      showAvatarForThisMessage)
                                                  ? RepaintBoundary(
                                                      child: AvatarWidget(
                                                        key: ValueKey(
                                                            'avatar-$sender'),
                                                        username: sender,
                                                        tokenProvider:
                                                            () async => null,
                                                        size: 20,
                                                        editable: false,
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                          ],
                                        ),
                                      )
                                    : null;

                                final bubbleWithContext = AnimatedMessageBubble(
                                    key: ValueKey<String>(animKey),
                                    outgoing: isMe,
                                    animate: _hasBuiltMessageListOnce &&
                                        isFirstAppearance &&
                                        SettingsManager
                                            .messageAnimationsEnabled.value,
                                    flightOriginKey:
                                        isMe ? _inputAreaKey : null,
                                    flightFromEdge: !isMe,
                                    alignRight: shouldAlignRight,
                                    child: RepaintBoundary(
                                        child: senderInfoRow == null
                                            ? bubble
                                            : Column(
                                                crossAxisAlignment:
                                                    shouldAlignRight
                                                        ? CrossAxisAlignment.end
                                                        : CrossAxisAlignment
                                                            .start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  senderInfoRow,
                                                  bubble,
                                                ],
                                              )));
                                final contentWithSender = Column(
                                  crossAxisAlignment: shouldAlignRight
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    bubbleWithContext,
                                    MessageReactionBar(
                                      reactions: reactionsFor(reactionKey),
                                      myUsername: _currentUsername ?? '',
                                      outgoing: isMe,
                                      onToggle: (emoji) {
                                        final wasReacted = hasReaction(
                                            reactionKey,
                                            emoji,
                                            _currentUsername ?? '');
                                        toggleReaction(reactionKey, emoji,
                                            _currentUsername ?? '',
                                            anonymous: true);
                                        if (rMsgId != null)
                                          _serverToggleGroupReaction(
                                              rMsgId, emoji, wasReacted);
                                      },
                                      onAddReaction: (ctx2) => openEmojiPicker(
                                          ctx2,
                                          reactionKey,
                                          _currentUsername ?? '',
                                          anonymous: true,
                                          onAfterToggle: (emoji, wasReacted) {
                                        if (rMsgId != null)
                                          _serverToggleGroupReaction(
                                              rMsgId, emoji, wasReacted);
                                      }),
                                    ),
                                    if (widget.group.isChannel)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: _buildCommentsAffordance(
                                            context, colorScheme, msg),
                                      ),
                                  ],
                                );

                                final gcs = Theme.of(context).colorScheme;
                                return ValueListenableBuilder<
                                    ({
                                      bool active,
                                      Map<String, Map<String, dynamic>> selected
                                    })>(
                                  key: ValueKey<String>('msg_$animKey'),
                                  valueListenable: _selectionNotifier,
                                  child: RepaintBoundary(
                                    child: Align(
                                      alignment: shouldAlignRight
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: contentWithSender,
                                    ),
                                  ),
                                  builder: (_, sel, contentChild) {
                                    final isGroupSelected =
                                        sel.selected.containsKey(uniqueKey);
                                    final groupCheckmark = GestureDetector(
                                      onTap: () => _toggleGroupMsgSelection(
                                          msg, uniqueKey),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isGroupSelected
                                                ? gcs.primary
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isGroupSelected
                                                  ? gcs.primary
                                                  : gcs.onSurface
                                                      .withValues(alpha: 0.35),
                                              width: 2,
                                            ),
                                          ),
                                          child: isGroupSelected
                                              ? Icon(Icons.check,
                                                  size: 14,
                                                  color: gcs.onPrimary)
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
                                                duration:
                                                    _messageLongPressDuration),
                                            (instance) {
                                              instance.onLongPressStart = (_) =>
                                                  _startGroupDragSelection(
                                                      msg, uniqueKey);
                                              instance.onLongPressMoveUpdate =
                                                  (details) =>
                                                      _updateGroupDragSelection(
                                                          details
                                                              .globalPosition);
                                              instance.onLongPressEnd = (_) =>
                                                  _endGroupDragSelection();
                                            },
                                          ),
                                        },
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: sel.active
                                              ? () => _toggleGroupMsgSelection(
                                                  msg, uniqueKey)
                                              : null,
                                          onDoubleTap: sel.active
                                              ? null
                                              : () => _enterGroupSelectionMode(
                                                  msg, uniqueKey),
                                          child: AnimatedContainer(
                                            key: (_scrollTargetId != null &&
                                                    _scrollTargetId ==
                                                        msg['id']?.toString())
                                                ? _scrollTargetKey
                                                : null,
                                            duration: const Duration(
                                                milliseconds: 150),
                                            color: isCurrentSearchMatch
                                                ? gcs.primary
                                                    .withValues(alpha: 0.28)
                                                : isSearchMatch
                                                    ? gcs.primary
                                                        .withValues(alpha: 0.12)
                                                    : isGroupSelected
                                                        ? gcs.primaryContainer
                                                            .withValues(
                                                                alpha: 0.45)
                                                        : (_scrollHighlightId !=
                                                                    null &&
                                                                _scrollHighlightId ==
                                                                    msg['id']
                                                                        ?.toString())
                                                            ? gcs.primary
                                                                .withValues(
                                                                    alpha: 0.18)
                                                            : Colors
                                                                .transparent,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 4),
                                            child: Row(
                                              children: [
                                                if (sel.active) groupCheckmark,
                                                Expanded(
                                                    child: AbsorbPointer(
                                                  absorbing: sel.active,
                                                  child: contentChild!,
                                                )),
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
                    );
                  },
                );
              },
            ),
            if (_pinnedMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                left: 16,
                right: 16,
                child: _buildGroupPinnedBanner(context),
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
              child: Center(
                child: _isReadOnlyChannel
                    ? MeasureSize(
                        onChange: (size) {
                          if ((_bottomBarHeight.value - size.height).abs() >
                              0.5) {
                            _bottomBarHeight.value = size.height;
                          }
                        },
                        child: ListenableBuilder(
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
                          final opacity = SettingsManager.elementOpacity.value;
                          final width = SettingsManager.inputBarMaxWidth.value;
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
                                    color: baseColor.withValues(alpha: opacity),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                            child: Text(
                              'You cannot send messages here.',
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
                      ),
                      )
                    : ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.inputBarMaxWidth,
                        builder: (_, width, __) {
                          return Container(
                            constraints: BoxConstraints(maxWidth: width),
                            child: _buildInputBar(context, colorScheme),
                          );
                        },
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
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: btnSize * 0.56,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
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

  Future<void> _handleGroupDroppedFiles(List<String> filePaths,
      {bool skipBulkConfirm = false}) async {
    if (filePaths.isEmpty) return;

    final existing = <String>[];
    for (final fp in filePaths) {
      if (await File(fp).exists()) {
        existing.add(fp);
      } else {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .fileNotFound);
      }
    }
    if (existing.isEmpty) return;

    // Single file — preserve dialog/confirm behavior
    if (existing.length == 1) {
      final filePath = existing.first;
      final basename = p.basename(filePath);
      final ext = p.extension(basename).toLowerCase();
      _showGroupFilePreviewAndSend(filePath, basename, ext);
      return;
    }

    // Pre-collect segments: List<String> for image batches, String for non-image files.
    final segments = <Object>[];
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
    final useBulkConfirm = albumBatches.length > 1 && !skipBulkConfirm;

    if (useBulkConfirm) {
      if (!mounted) return;
      var proceed = false;
      await showDialog<void>(
        context: context,
        builder: (_) => BulkAlbumConfirmDialog(
          imageCount: albumBatches.fold(0, (sum, b) => sum + b.length),
          albumCount: albumBatches.length,
          onSend: () => proceed = true,
          onCancel: () {},
        ),
      );
      if (!proceed) return;
    }

    for (final segment in segments) {
      if (segment is List<String>) {
        if (useBulkConfirm || skipBulkConfirm) {
          unawaited(_processAndUploadAlbum(segment));
        } else {
          if (!mounted) return;
          var proceed = false;
          await showDialog<void>(
            context: context,
            builder: (_) => AlbumPreviewDialog(
              filePaths: segment,
              onSend: () => proceed = true,
              onCancel: () {},
            ),
          );
          if (!proceed) continue;
          await _processAndUploadAlbum(segment);
        }
      } else if (segment is String) {
        if (!mounted) continue;
        final fp = segment;
        final basename = p.basename(fp);
        final ext = p.extension(basename).toLowerCase();
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
        if (proceed) await _sendGroupFile(fp, basename, ext);
      }
    }
  }

  static const _clipboardChannel = MethodChannel('onyx/clipboard');

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
        _handleGroupDroppedFiles(filePaths);
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
        _handleGroupDroppedFiles([tempFile.path]);
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
          final basename = p.basename(filePath);
          final ext = p.extension(basename).toLowerCase();
          debugPrint('[clipboard] File URI pasted: $filePath');
          _showGroupFilePreviewAndSend(filePath, basename, ext);
          return;
        }
      }

      debugPrint('[clipboard] No supported format found in clipboard');
    } catch (e, stackTrace) {
      debugPrint('[clipboard] Error pasting from clipboard: $e');
      debugPrint('[clipboard] Stack trace: $stackTrace');
    }
  }

  void _showGroupFilePreviewAndSend(
    String filePath,
    String basename,
    String ext,
  ) {
    if (SettingsManager.confirmFileUpload.value) {
      final isImage = FileTypeDetector.isImage(filePath);
      showDialog(
        context: context,
        builder: (_) => FilePreviewDialog(
          filePath: filePath,
          onSend: () => _sendGroupFile(filePath, basename, ext),
          onCancel: () {
            rootScreenKey.currentState?.showSnack(
                lookupAppLocalizations(SettingsManager.appLocale.value)
                    .fileCancelled);
          },
          onPasteExtra: isImage ? _pasteImageForAlbum : null,
          onSendAlbum:
              isImage ? (paths) => _processAndUploadAlbum(paths) : null,
        ),
      );
    } else {
      _sendGroupFile(filePath, basename, ext);
    }
  }

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

  Future<void> _sendGroupFile(
    String filePath,
    String basename,
    String ext,
  ) async {
    await _processAndUploadFile(filePath);
  }
}
