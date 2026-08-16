// lib/screens/favorites_screen.dart
import '../widgets/marquee_text.dart';
import '../widgets/empty_chat_placeholder.dart';
import '../widgets/onyx_dialog.dart';
import '../utils/code_heuristic.dart';
import '../utils/chat_image_preloader.dart';
import '../utils/gallery_extractor.dart';
import 'media_gallery_screen.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../enums/liquid_glass_quality.dart';

import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import 'package:ONYX/screens/forward_screen.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_extra.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;
import 'package:crypto/crypto.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../globals.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/avatar_crop_screen.dart';
import '../widgets/chat_background_layer.dart';
import '../models/chat_message.dart';
import '../services/wardlink/wardlink_tombstones.dart';
import '../services/wardlink/wardlink_sync_service.dart';
import '../managers/settings_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_images_scope.dart';
import '../widgets/album_message_widget.dart' show AlbumItem;
import '../models/favorite_chat.dart';
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../utils/clipboard_image.dart';
import '../utils/file_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../utils/image_file_cache.dart';
import '../utils/upload_task.dart';
import '../utils/blurhash_util.dart';
import '../utils/video_info.dart';
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

abstract class _ListItem {}

class _MessageItem extends _ListItem {
  final ChatMessage message;
  _MessageItem(this.message);
}

class _DaySeparatorItem extends _ListItem {
  final DateTime date;
  _DaySeparatorItem(this.date);
}

class _EditableFavoriteAvatar extends StatefulWidget {
  final String id;
  final String? currentAvatarPath;
  final double size;
  final VoidCallback? onTap;
  const _EditableFavoriteAvatar({
    super.key,
    required this.id,
    this.currentAvatarPath,
    this.size = 40,
    this.onTap,
  });

  @override
  State<_EditableFavoriteAvatar> createState() =>
      _EditableFavoriteAvatarState();
}

class _EditableFavoriteAvatarState extends State<_EditableFavoriteAvatar> {
  bool? _cachedExists;

  @override
  void didUpdateWidget(_EditableFavoriteAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentAvatarPath != widget.currentAvatarPath) {
      _cachedExists = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    Widget avatarContent;

    _cachedExists ??= (widget.currentAvatarPath != null &&
        File(widget.currentAvatarPath!).existsSync());

    if (_cachedExists!) {
      avatarContent = Image.file(
        File(widget.currentAvatarPath!),
        fit: BoxFit.cover,
        width: sz,
        height: sz,
        errorBuilder: (_, __, ___) {
          _cachedExists = false;
          return ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementBrightness,
            builder: (_, brightness, ___) {
              final baseColor = SettingsManager.getElementColor(
                Theme.of(context).colorScheme.surfaceContainerHighest,
                brightness,
              );
              return Container(
                color: baseColor.withValues(alpha: 0.3),
                child: Icon(
                  Icons.bookmark,
                  size: sz * 0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          );
        },
      );
    } else {
      avatarContent = ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, ___) {
          final baseColor = SettingsManager.getElementColor(
            Theme.of(context).colorScheme.surfaceContainerHighest,
            brightness,
          );
          return Container(
            color: baseColor.withValues(alpha: 0.3),
            child: Icon(
              Icons.bookmark,
              size: sz * 0.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      );
    }
    final child = ClipOval(
      child: SizedBox(
        width: sz,
        height: sz,
        child: avatarContent,
      ),
    );
    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: child,
      );
    }
    return child;
  }
}

class FavoritesScreen extends StatefulWidget {
  final String favoriteId;
  final String title;
  const FavoritesScreen({
    super.key,
    required this.favoriteId,
    required this.title,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin, ReactionStateMixin {
  static final Set<String> _sessionInputAnimationsShown = {};

  final TextEditingController _textCtrl = TextEditingController();
  final GlobalKey _inputAreaKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  late final FocusNode _focusNode;
  Timer? _typingDebounce;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;
  final ValueNotifier<bool> _showScrollDownButton = ValueNotifier<bool>(false);
  final ValueNotifier<double> _bottomBarHeight = ValueNotifier<double>(76.0);
  final Set<String> _alreadyRenderedMessageIds = {};
  // True once the message list has painted at least one frame. Entry
  // animations are suppressed until then — closes a race where messages
  // (e.g. from WardLink or disk cache) finish loading asynchronously after
  // the pre-seed snapshot above was taken, which would otherwise make the
  // whole history "appear new" and animate in on open.
  bool _hasBuiltMessageListOnce = false;

  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryTranslateY;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  List<_ListItem>? _cachedDaySeparatorItems;
  int _cachedDaySeparatorHash = 0;

  List<AlbumItem>? _cachedAllImages;
  int _cachedAllImagesHash = 0;

  int _cachedDragHash = 0;

  // Fingerprint of the message list last handed to the image preloader.
  int _preloadStampCount = -1;
  String _preloadStampLast = '';

  final List<UploadTask> _pendingUploads = [];

  late final _selectionNotifier =
      ValueNotifier<({bool active, Map<String, ChatMessage> selected})>(
          (active: false, selected: {}));
  Map<String, ChatMessage> get _selectedFavMessages =>
      _selectionNotifier.value.selected;
  final GlobalKey _messageListViewportKey = GlobalKey();
  final Map<String, GlobalKey> _messageItemKeys = {};
  List<String> _dragSelectionOrder = const [];
  Map<String, ChatMessage> _dragSelectionLookup = const {};
  Map<String, int> _dragSelectionIndices = const {};
  bool _isDragSelectingMessages = false;
  String? _dragSelectionAnchorKey;
  String? _dragSelectionCurrentKey;
  Map<String, ChatMessage> _dragSelectionBase = const {};
  Offset _lastDragPointerGlobal = Offset.zero;
  Timer? _dragAutoScrollTimer;
  static const Duration _messageLongPressDuration = Duration(milliseconds: 375);
  static const double _dragEdgeZone = 80.0;
  static const double _dragMaxSpeed = 14.0;

  // ── in-chat search ──────────────────────────────────────────────────────────
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentMatchIdx = 0;
  List<int> _cachedSearchMatches = [];
  final _searchStats =
      ValueNotifier<({int current, int total})>((current: 0, total: 0));
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _scroll.addListener(_onScroll);
    _loadPinnedMessage();
    _consumePendingFavScrollTarget();
    _subscribeReminders();

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

    // Pre-seed rendered-ids so existing messages don't all animate on open —
    // only messages added during this session will get an entry animation.
    final existingMsgs =
        rootScreenKey.currentState?.chats['fav:${widget.favoriteId}'] ??
            const [];
    for (final m in existingMsgs) {
      _alreadyRenderedMessageIds.add(m.id);
    }

    Future.microtask(() => rootScreenKey.currentState
        ?.ensureMediaCachedForFavorite(widget.favoriteId));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus && isDesktop) {
        _focusNode.requestFocus();
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
  }

  void _checkInputAnimationState() {
    final favoriteId = 'fav_${widget.favoriteId}';

    if (!_sessionInputAnimationsShown.contains(favoriteId)) {
      _inputEntryController.forward();
      _sessionInputAnimationsShown.add(favoriteId);
      _hasInputAnimated = true;
    } else {
      _inputEntryController.value = 1.0;
      _hasInputAnimated = true;
    }
  }

  @override
  void didUpdateWidget(covariant FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoriteId != widget.favoriteId) {
      _alreadyRenderedMessageIds.clear();
      final existingMsgs =
          rootScreenKey.currentState?.chats['fav:${widget.favoriteId}'] ??
              const [];
      for (final m in existingMsgs) {
        _alreadyRenderedMessageIds.add(m.id);
      }
      _hasBuiltMessageListOnce = false;
      if (_scroll.hasClients) {
        _scroll.jumpTo(0.0);
      }
      // Reset pinned message immediately so the old chat's banner doesn't flash,
      // then load the correct one for the new chat.
      setState(() => _pinnedMessage = null);
      _loadPinnedMessage();
      Future.microtask(() => rootScreenKey.currentState
          ?.ensureMediaCachedForFavorite(widget.favoriteId));
    }
  }

  Map<String, dynamic>? _replyingToMessage;
  Map<String, dynamic>? _pinnedMessage;

  // Live cache of "chatId|messageId" keys with an active reminder — kept
  // in sync via a stream so the desktop right-click menu (built
  // synchronously on every message, on every rebuild) can check reminder
  // state without a DB round-trip per render.
  Set<String> _reminderKeys = {};
  StreamSubscription? _reminderKeysSub;

  void _subscribeReminders() {
    final accountId = rootScreenKey.currentState?.currentUsername;
    if (accountId == null) return;
    _reminderKeysSub =
        ReminderService.watchActiveReminders(accountId).listen((rows) {
      if (!mounted) return;
      setState(() {
        _reminderKeys = rows.map((r) => '${r.chatId}|${r.messageId}').toSet();
      });
    });
  }

  bool _hasReminderSync(ChatMessage msg) {
    final chatId = 'fav:${widget.favoriteId}';
    final messageId = msg.serverMessageId?.toString() ?? msg.id;
    return _reminderKeys.contains('$chatId|$messageId');
  }

  ChatMessage? _editingMessage;

  void _startReplyingToMessage(Map<String, dynamic> msg) {
    setState(() {
      _replyingToMessage = msg;
    });
  }

  void _cancelReplying() {
    if (_replyingToMessage == null) return;
    setState(() {
      debugPrint(
          '[favorites_screen::_cancelReplying] clearing _replyingToMessage\n${StackTrace.current}');
      _replyingToMessage = null;
    });
  }

  bool _isFavMsgPinned(ChatMessage msg) {
    final pinId = _pinnedMessage?['id']?.toString();
    if (pinId == null) return false;
    return pinId == (msg.serverMessageId?.toString() ?? msg.id);
  }

  String get _pinPrefsKey => 'pinned_fav_${widget.favoriteId}';

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

  void _toggleFavPin(ChatMessage msg) {
    if (_isFavMsgPinned(msg)) {
      setState(() => _pinnedMessage = null);
    } else {
      setState(() {
        _pinnedMessage = {
          'id': msg.serverMessageId?.toString() ?? msg.id,
          'content': msg.content,
          'sender': msg.from,
        };
      });
    }
    _savePinnedMessage();
  }

  String? _scrollHighlightId;
  Timer? _highlightTimer;
  final GlobalKey _scrollTargetKey = GlobalKey();
  String? _scrollTargetId;

  void _flashHighlight(String id) {
    _highlightTimer?.cancel();
    setState(() => _scrollHighlightId = id);
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _scrollHighlightId = null);
    });
  }

  void _scrollToFavMessageById(String? msgId) {
    if (msgId == null || !_scroll.hasClients) return;
    final rootState = rootScreenKey.currentState;
    if (rootState == null) return;
    final msgs = rootState.chats[_chatId()] ?? [];
    final items = _buildMessagesWithDaySeparators(msgs);
    for (int k = 0; k < items.length; k++) {
      final item = items[k];
      if (item is! _MessageItem) continue;
      final m = item.message;
      final mId = m.serverMessageId?.toString() ?? m.id;
      if (mId == msgId) {
        final listviewIdx = k;
        final totalItems = items.length;
        final maxExt = _scroll.position.maxScrollExtent;
        final proportional =
            totalItems > 0 ? (listviewIdx / totalItems) * maxExt : 0.0;

        setState(() => _scrollTargetId = mId);

        _scroll
            .animateTo(proportional.clamp(0.0, maxExt),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut)
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

        _flashHighlight(mId);
        return;
      }
    }
  }

  /// If a search-result tap asked to land on a specific message in this
  /// favorite (see [setPendingMessageScrollTarget]), scroll to and highlight
  /// it once the message list is laid out — instead of opening at the bottom.
  void _consumePendingFavScrollTarget() {
    final pendingId =
        consumePendingMessageScrollTarget('fav:${widget.favoriteId}');
    if (pendingId == null) return;
    void attempt([int retries = 6]) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scrollToFavMessageById(pendingId);
      } else if (retries > 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => attempt(retries - 1));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  Widget _buildFavPinnedBanner(BuildContext context) {
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
                _scrollToFavMessageById(_pinnedMessage?['id']?.toString()),
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

  Future<void> _handleReminderToggle({
    required ChatMessage msg,
    required bool hasReminder,
    required String chatId,
    required String messageId,
    required String chatTitle,
  }) async {
    final myAccountId = rootScreenKey.currentState?.currentUsername;
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
      chatType: 'fav',
      chatId: chatId,
      chatTitle: chatTitle,
      messagePreview: getPreviewText(msg.content),
      accentColorArgb: accentColorArgb,
      scheduledAt: picked,
    );
    rootScreenKey.currentState?.showSnack(l.reminderSet);
  }

  void _startEditingMessage(ChatMessage msg) {
    setState(() => _editingMessage = msg);
    _textCtrl.text = msg.content;
    _textCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: msg.content.length));
    _focusNode.requestFocus();
  }

  void _cancelEditingMessage() {
    setState(() => _editingMessage = null);
    _textCtrl.clear();
    _focusNode.requestFocus();
  }

  bool _isFavTextMessage(ChatMessage msg) {
    final c = msg.content;
    return !c.startsWith('IMAGEv1:') &&
        !c.startsWith('ALBUMv1:') &&
        !c.toUpperCase().startsWith('VIDEOV1:') &&
        !c.startsWith('VOICEv1:') &&
        !c.startsWith('FILEv1:') &&
        !c.startsWith('FILE:') &&
        !c.startsWith('AUDIOv1:') &&
        !c.startsWith('DOCUMENTv1:') &&
        !c.startsWith('ARCHIVEv1:') &&
        !c.startsWith('DATAv1:') &&
        !c.startsWith('[cannot-decrypt');
  }

  void _enterFavSelectionMode(ChatMessage msg, String uniqueKey) {
    HapticFeedback.mediumImpact();
    final cur = _selectionNotifier.value;
    _selectionNotifier.value =
        (active: true, selected: {...cur.selected, uniqueKey: msg});
  }

  void _exitFavSelectionMode() {
    _selectionNotifier.value = (active: false, selected: {});
  }

  void _toggleFavMessageSelection(ChatMessage msg, String uniqueKey) {
    final cur = _selectionNotifier.value;
    final next = Map<String, ChatMessage>.from(cur.selected);
    if (next.containsKey(uniqueKey)) {
      next.remove(uniqueKey);
      _selectionNotifier.value = (active: next.isNotEmpty, selected: next);
    } else {
      next[uniqueKey] = msg;
      _selectionNotifier.value = (active: true, selected: next);
    }
  }

  String _selectionKeyForMessage(ChatMessage msg) =>
      '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';

  // Keyed by the message's STABLE local id (not `uniqueKey`, which embeds
  // serverMessageId/time and changes the moment a sent message gets
  // acknowledged). See ChatScreen for the full story on why an unstable key
  // here tears down the in-flight AnimatedMessageBubble mid-animation.
  GlobalKey _messageItemKey(String stableId) =>
      _messageItemKeys.putIfAbsent(stableId, () => GlobalKey());

  void _startMessageDragSelection(ChatMessage msg, String uniqueKey) {
    final cur = _selectionNotifier.value;
    final next = Map<String, ChatMessage>.from(cur.selected);
    if (!cur.active) {
      HapticFeedback.mediumImpact();
    }
    next[uniqueKey] = msg;
    _selectionNotifier.value = (active: true, selected: next);
    _dragSelectionBase = Map<String, ChatMessage>.from(cur.selected)
      ..[uniqueKey] = msg;
    _dragSelectionAnchorKey = uniqueKey;
    _dragSelectionCurrentKey = uniqueKey;
    _isDragSelectingMessages = true;
    _selectMessageRangeTo(uniqueKey);
  }

  void _updateMessageDragSelection(Offset globalPosition) {
    if (!_isDragSelectingMessages) return;
    _lastDragPointerGlobal = globalPosition;
    final hoveredKey = _messageKeyAtGlobal(globalPosition);
    if (hoveredKey != null && hoveredKey != _dragSelectionCurrentKey) {
      _selectMessageRangeTo(hoveredKey);
    }
    _updateDragAutoScroll();
  }

  void _endMessageDragSelection() {
    _isDragSelectingMessages = false;
    _dragSelectionAnchorKey = null;
    _dragSelectionCurrentKey = null;
    _dragSelectionBase = const {};
    _stopDragAutoScroll();
  }

  void _selectMessageRangeTo(String uniqueKey) {
    final anchorKey = _dragSelectionAnchorKey;
    if (anchorKey == null) return;
    final start = _dragSelectionIndices[anchorKey];
    final end = _dragSelectionIndices[uniqueKey];
    if (start == null || end == null) return;
    final from = math.min(start, end);
    final to = math.max(start, end);
    final next = Map<String, ChatMessage>.from(_dragSelectionBase);
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
      final stableId = _dragSelectionLookup[uniqueKey]?.id;
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
        _selectMessageRangeTo(hoveredKey);
      }
    });
  }

  void _stopDragAutoScroll() {
    _dragAutoScrollTimer?.cancel();
    _dragAutoScrollTimer = null;
  }

  // Map insertion order (`.values`) reflects selection/drag-recompute order,
  // not chronological order — always re-sort by `time` first.
  List<ChatMessage> get _selectedFavMessagesChronological =>
      _selectedFavMessages.values.toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  void _copySelectedFavMessages() {
    final texts = _selectedFavMessagesChronological
        .where((m) => _isFavTextMessage(m))
        .map((m) => m.content)
        .join('\n\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack(
          lookupAppLocalizations(SettingsManager.appLocale.value).msgCopied);
    }
    _exitFavSelectionMode();
  }

  void _forwardSelectedFavMessages() {
    final contents =
        _selectedFavMessagesChronological.map((m) => m.content).toList();
    if (contents.isEmpty) return;
    _exitFavSelectionMode();
    ForwardScreen.show(context, contents);
  }

  Future<void> _confirmDeleteSelectedFav() async {
    final toDelete = _selectedFavMessages.values.toList();
    if (toDelete.isEmpty) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title:
          'Delete ${toDelete.length} message${toDelete.length == 1 ? '' : 's'}?',
      message: l.favSelectedRemovedFromFavorites,
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      for (final msg in toDelete) {
        _deleteMessage(msg);
      }
      _exitFavSelectionMode();
    }
  }

  void _deleteMessage(ChatMessage msg) {
    final root = rootScreenKey.currentState;
    if (root == null) return;
    final chatId = _chatId();
    setState(() {
      root.chats[chatId]?.removeWhere((m) => m.id == msg.id);
      _invalidateDaySeparatorCache();
    });
    root.schedulePersistChats(chatId: chatId);
    bumpChatMessageVersion(chatId);
    chatsVersion.value++;
    // Tombstone so WardLink removes this message on paired devices too, and
    // poke them now so it applies immediately.
    WardLinkTombstones.recordMsgDeleted(chatId, msg.id);
    WardLinkSyncService.instance.pokeNow();
    // Clean up any media file the deleted message referenced locally.
    root.cleanupOrphanedMessages([msg]);
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

  @override
  void dispose() {
    _reminderKeysSub?.cancel();
    _selectionNotifier.dispose();
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    _typingDebounce?.cancel();
    _inputEntryController.dispose();
    _searchController.dispose();
    _searchStats.dispose();
    _searchFocusNode.dispose();
    _showScrollDownButton.dispose();
    _bottomBarHeight.dispose();
    _stopDragAutoScroll();
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
      final matchItemIdx = _cachedSearchMatches[_currentMatchIdx];
      final totalItems = _cachedDaySeparatorItems?.length ?? 0;
      if (totalItems == 0) return;
      final listIdx = matchItemIdx;
      final maxExtent = _scroll.position.maxScrollExtent;
      final target = (maxExtent * listIdx / totalItems).clamp(0.0, maxExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _onUserTyping() {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 150), () {});
  }

  Future<void> _submitMessage(String value) async {
    if (value.trim().isEmpty) return;

    if (_editingMessage != null) {
      final editing = _editingMessage!;
      _cancelEditingMessage();
      final root = rootScreenKey.currentState;
      if (root != null) {
        final chatId = _chatId();
        setState(() {
          editing.updateContent(value.trim());
          editing.editedAt = DateTime.now();
          _invalidateDaySeparatorCache();
        });
        root.schedulePersistChats(chatId: chatId);
        bumpChatMessageVersion(chatId);
        chatsVersion.value++;
      }
      return;
    }

    var content = value.trim();
    if (looksLikeCode(content)) {
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
        content = '```${detectCodeLanguage(content)}\n$content\n```';
      }
    }

    final localId = generateLocalMessageId();
    final int? replyId =
        _replyingToMessage != null && _replyingToMessage!['id'] != null
            ? int.tryParse(_replyingToMessage!['id'].toString())
            : null;
    final msg = ChatMessage(
      id: localId,
      from: 'me',
      to: 'fav:${widget.favoriteId}',
      content: content,
      outgoing: true,
      delivered: true,
      time: DateTime.now(),
      replyToId: replyId,
      replyToSender: _replyingToMessage != null
          ? (_replyingToMessage!['senderDisplayName'] ??
                  _replyingToMessage!['sender'])
              ?.toString()
          : null,
      replyToContent: _replyingToMessage != null
          ? (_replyingToMessage!['content'])?.toString()
          : null,
    );

    setState(() {
      _replyingToMessage = null;
    });
    final root = rootScreenKey.currentState;
    if (root != null) {
      final chatId = _chatId();
      root.chats.putIfAbsent(chatId, () => []).add(msg);
      root.schedulePersistChats(chatId: chatId);
      bumpChatMessageVersion(chatId);
      chatsVersion.value++;
      root.bumpFavToTop(widget.favoriteId);
      unawaited(WardLinkSyncService.instance.pokeNow());
    }
    _textCtrl.clear();

    if (!_shouldPreserveExternalFocus && !recordingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _handleDroppedFiles(List<String> filePaths,
      {bool skipBulkConfirm = false}) async {
    if (filePaths.isEmpty) return;

    // Single file — preserve dialog/confirm behavior
    if (filePaths.length == 1) {
      final filePath = filePaths.first;
      if (!await File(filePath).exists()) {
        rootScreenKey.currentState?.showSnack(
            lookupAppLocalizations(SettingsManager.appLocale.value)
                .fileNotFound);
        return;
      }
      final basename = p.basename(filePath);
      final ext = p.extension(basename).toLowerCase();
      String type;
      if (FileTypeDetector.isImage(filePath)) {
        type = 'IMAGE';
      } else if (FileTypeDetector.isVideo(filePath)) {
        type = 'VIDEO';
      } else if (FileTypeDetector.isAudio(filePath)) {
        type = 'AUDIO';
      } else if (FileTypeDetector.isDocument(filePath)) {
        type = 'DOCUMENT';
      } else if (FileTypeDetector.isCompress(filePath)) {
        type = 'ARCHIVE';
      } else if (FileTypeDetector.isData(filePath)) {
        type = 'DATA';
      } else {
        type = 'FILE';
      }
      _showFilePreviewAndSend(filePath, basename, ext, type);
      return;
    }

    // Multiple files — filter existing
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
    // (e.g. 3000-image) sends to favorites.
    final useBulkConfirm = albumBatches.length > 1 &&
        SettingsManager.confirmFileUpload.value &&
        !skipBulkConfirm;
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
          await _sendAlbum(segment, skipConfirm: true);
        } else {
          await _sendAlbum(segment);
        }
      } else {
        final fp = segment as String;
        if (FileTypeDetector.isVideo(fp) &&
            SettingsManager.confirmFileUpload.value) {
          if (!mounted)
            continue; // skip per-file dialog; don't stop remaining sends
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
          if (proceed) await _sendFile(fp, basename, ext, 'VIDEO');
        } else {
          final basename = p.basename(fp);
          final ext = p.extension(basename).toLowerCase();
          final type = FileTypeDetector.isAudio(fp)
              ? 'AUDIO'
              : FileTypeDetector.isDocument(fp)
                  ? 'DOCUMENT'
                  : FileTypeDetector.isCompress(fp)
                      ? 'ARCHIVE'
                      : FileTypeDetector.isData(fp)
                          ? 'DATA'
                          : 'FILE';
          await _sendFile(fp, basename, ext, type);
        }
      }
    }
  }

  void _showFilePreviewAndSend(
      String filePath, String basename, String ext, String type) {
    if (SettingsManager.confirmFileUpload.value) {
      showDialog(
        context: context,
        builder: (_) => FilePreviewDialog(
          filePath: filePath,
          onSend: () => _sendFile(filePath, basename, ext, type),
          onCancel: () {
            rootScreenKey.currentState?.showSnack('File cancelled');
          },
          onPasteExtra: type == 'IMAGE' ? _pasteImageForAlbum : null,
          onSendAlbum: type == 'IMAGE'
              ? (paths) => _sendAlbum(paths, skipConfirm: true)
              : null,
        ),
      );
    } else {
      _sendFile(filePath, basename, ext, type);
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
        if (!mounted) return;
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
        if (!mounted) return;
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
          if (!FileTypeDetector.isAllowed(filePath)) {
            final ext = p.extension(filePath).toLowerCase();
            rootScreenKey.currentState
                ?.showSnack('Unsupported file type: $ext');
            return;
          }
          final basename = p.basename(filePath);
          final ext = p.extension(basename).toLowerCase();
          final type = FileTypeDetector.getFileType(filePath);
          debugPrint('[clipboard] File URI pasted: $filePath');
          if (!mounted) return;
          _showFilePreviewAndSend(filePath, basename, ext, type);
          return;
        }
      }

      debugPrint('[clipboard] No supported format found in clipboard');
    } catch (e, stackTrace) {
      debugPrint('[clipboard] Error pasting from clipboard: $e');
      debugPrint('[clipboard] Stack trace: $stackTrace');
    }
  }

  void _cancelAllUploads() {
    setState(() => _pendingUploads.clear());
  }

  Future<void> _sendFile(
      String filePath, String basename, String ext, String type) async {
    final task = UploadTask(
      id: generateLocalMessageId(),
      type: type == 'IMAGE'
          ? 'image'
          : type == 'VIDEO'
              ? 'video'
              : type == 'AUDIO'
                  ? 'audio'
                  : 'file',
      localPath: filePath,
      basename: basename,
    );
    if (type == 'IMAGE') {
      try {
        task.previewBytes = await File(filePath).readAsBytes();
      } catch (_) {}
    }
    task.status = UploadStatus.uploading;
    setState(() => _pendingUploads.add(task));

    try {
      final localId = task.id;
      // Storage/content key must never be the picker's original basename
      // alone — two different files with the same original name (very
      // common with camera/screenshot filenames) would otherwise collide
      // and silently overwrite each other in the shared cache dir. Stamp it
      // with a unique prefix, same pattern as voice recordings and LAN
      // transfers use, and keep the real name only in 'orig' for display.
      final storageName = '${DateTime.now().microsecondsSinceEpoch}_$basename';
      final contentJson =
          jsonEncode({'filename': storageName, 'orig': basename});

      late String content;
      late String cachePath;
      late String cacheDir;

      if (type == 'IMAGE') {
        cacheDir = '${(await getOnyxSupportDirectory()).path}/image_cache';
        final blur = task.previewBytes != null
            ? await computeBlurHash(task.previewBytes!)
            : null;
        content = 'IMAGEv1:${jsonEncode({
              'filename': storageName,
              'orig': basename,
              if (blur != null) 'blur': blur.hash,
              if (blur != null) 'ar': blur.aspectRatio,
            })}';
      } else if (type == 'VIDEO') {
        cacheDir = '${(await getOnyxSupportDirectory()).path}/video_cache';
        final videoInfo = await extractVideoInfo(filePath);
        content = 'VIDEOv1:${jsonEncode({
              'filename': storageName,
              'orig': basename,
              if (videoInfo?.hash != null) 'blur': videoInfo!.hash,
              if (videoInfo != null) 'ar': videoInfo.ar,
            })}';
      } else if (type == 'AUDIO') {
        cacheDir = '${(await getOnyxSupportDirectory()).path}/audio_cache';
        content = 'AUDIOv1:$contentJson';
      } else if (type == 'DOCUMENT') {
        cacheDir = '${(await getOnyxSupportDirectory()).path}/document_cache';
        content = 'DOCUMENTv1:$contentJson';
      } else if (type == 'ARCHIVE') {
        cacheDir = '${(await getOnyxSupportDirectory()).path}/archive_cache';
        content = 'ARCHIVEv1:$contentJson';
      } else {
        cacheDir = '${(await getOnyxSupportDirectory()).path}/data_cache';
        content = 'DATAv1:$contentJson';
      }

      await Directory(cacheDir).create(recursive: true);
      final localFile = File(filePath);
      cachePath = '$cacheDir/$storageName';
      await localFile.copy(cachePath);

      final int? replyId =
          _replyingToMessage != null && _replyingToMessage!['id'] != null
              ? int.tryParse(_replyingToMessage!['id'].toString())
              : null;
      final msg = ChatMessage(
        id: localId,
        from: 'me',
        to: 'fav:${widget.favoriteId}',
        content: content,
        outgoing: true,
        delivered: true,
        time: DateTime.now(),
        replyToId: replyId,
        replyToSender: _replyingToMessage != null
            ? (_replyingToMessage!['senderDisplayName'] ??
                    _replyingToMessage!['sender'])
                ?.toString()
            : null,
        replyToContent: _replyingToMessage != null
            ? (_replyingToMessage!['content'])?.toString()
            : null,
      );

      setState(() {
        debugPrint(
            '[favorites_screen::send] clearing _replyingToMessage\n${StackTrace.current}');
        _replyingToMessage = null;
      });

      final root = rootScreenKey.currentState;
      setState(() => _pendingUploads.remove(task));
      if (root != null) {
        final chatId = _chatId();
        root.chats.putIfAbsent(chatId, () => []).add(msg);
        root.schedulePersistChats(chatId: chatId);
        bumpChatMessageVersion(chatId);
        chatsVersion.value++;
        root.bumpFavToTop(widget.favoriteId);
        unawaited(WardLinkSyncService.instance.pokeNow());
        root.showSnack(
            ' ${type.toLowerCase().replaceFirst(type[0], type[0].toUpperCase())} added');
      }
    } catch (e, stack) {
      setState(() => _pendingUploads.remove(task));
      debugPrint('Error sending file: $e\n$stack');
      rootScreenKey.currentState?.showSnack('Failed to send file');
    }
  }

  Future<void> _sendAlbum(List<String> filePaths,
      {bool skipConfirm = false}) async {
    if (filePaths.isEmpty) return;
    // Capture widget-bound values before any async gap so that if the widget
    // is reconfigured mid-upload the album still lands in the correct favorite.
    final favoriteId = widget.favoriteId;

    if (!skipConfirm && SettingsManager.confirmFileUpload.value) {
      if (!mounted) return;
      var proceed = false;
      await showDialog<void>(
        context: context,
        builder: (_) => AlbumPreviewDialog(
          filePaths: filePaths,
          onSend: () => proceed = true,
          onCancel: () {},
        ),
      );
      if (!proceed) return;
    }

    final albumTask = UploadTask(
      id: 'album_${DateTime.now().millisecondsSinceEpoch}',
      type: 'album',
      localPath: '',
      basename: '',
    );
    albumTask.albumTotal = filePaths.length;
    albumTask.status = UploadStatus.uploading;
    if (mounted) setState(() => _pendingUploads.add(albumTask));

    try {
      final cacheDir =
          Directory('${(await getOnyxSupportDirectory()).path}/image_cache');
      await cacheDir.create(recursive: true);

      // Copy + blurhash every image concurrently instead of one-by-one —
      // sequential isolate spawns per image were causing multi-second
      // delays between albums on large batches.
      // Storage key must be unique per file, not just the original basename
      // (camera/screenshot names collide constantly, and this batch itself
      // can contain duplicates) — otherwise two images silently overwrite
      // each other in the shared image_cache dir. Index disambiguates within
      // the batch; the timestamp disambiguates across batches.
      final albumStamp = DateTime.now().microsecondsSinceEpoch;
      final albumItems =
          await Future.wait(filePaths.asMap().entries.map((entry) async {
        final index = entry.key;
        final filePath = entry.value;
        final basename = p.basename(filePath);
        final storageName = '${albumStamp}_${index}_$basename';
        final cachePath = '${cacheDir.path}/$storageName';
        final srcFile = File(filePath);
        await srcFile.copy(cachePath);
        BlurResult? blur;
        try {
          blur = await computeBlurHash(await srcFile.readAsBytes());
        } catch (_) {}
        albumTask.albumDone++;
        albumTask.progress = albumTask.albumDone / albumTask.albumTotal;
        return {
          'filename': storageName,
          'orig': basename,
          if (blur != null) 'blur': blur.hash,
          if (blur != null) 'ar': blur.aspectRatio,
        };
      }));

      if (albumItems.isEmpty) return;

      final content = 'ALBUMv1:${jsonEncode(albumItems)}';
      final localId = generateLocalMessageId();
      final msg = ChatMessage(
        id: localId,
        from: 'me',
        to: 'fav:$favoriteId',
        content: content,
        outgoing: true,
        delivered: true,
        time: DateTime.now(),
      );

      if (mounted)
        setState(() {
          _replyingToMessage = null;
        });

      final root = rootScreenKey.currentState;
      if (root != null) {
        final chatId = 'fav:$favoriteId';
        root.chats.putIfAbsent(chatId, () => []).add(msg);
        root.schedulePersistChats(chatId: chatId);
        bumpChatMessageVersion(chatId);
        chatsVersion.value++;
        root.bumpFavToTop(favoriteId);
        root.showSnack('Album saved (${albumItems.length} images)');
      }
    } catch (e) {
      debugPrint('Error sending album: $e');
      rootScreenKey.currentState?.showSnack('Failed to save album');
    } finally {
      if (mounted) setState(() => _pendingUploads.remove(albumTask));
    }
  }

  void _onLongPress(ChatMessage msg) async {
    _focusNode.unfocus();
    final text = msg.content;
    final isImage = text.startsWith('IMAGEv1:');
    final isAlbum = text.startsWith('ALBUMv1:');
    final isVideo = text.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = text.startsWith('VOICEv1:');
    final isFile = text.startsWith('FILEv1:') || text.startsWith('FILE:');
    final isSaveable = isImage || isAlbum || isVideo || isVoice || isFile;
    final isMedia = isSaveable || text.startsWith('[cannot-decrypt');

    _shouldPreserveExternalFocus = true;
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    final reminderChatId = 'fav:${widget.favoriteId}';
    final reminderMsgId = msg.serverMessageId?.toString() ?? msg.id;
    final myAccountId = rootScreenKey.currentState?.currentUsername;
    var hasReminder = false;
    if (myAccountId != null) {
      hasReminder = await ReminderService.hasActiveReminder(
          myAccountId, reminderChatId, reminderMsgId);
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
                  actionTile(Icons.reply_rounded, l.reply, () {
                    Navigator.pop(ctx);
                    _startReplyingToMessage({
                      'id': msg.id,
                      'sender': msg.from,
                      'senderDisplayName': msg.from,
                      'content': msg.content,
                    });
                  }),
                  actionTile(Icons.add_reaction_outlined, l.react, () {
                    Navigator.pop(ctx);
                    final favKey =
                        '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
                    final me =
                        rootScreenKey.currentState?.currentUsername ?? msg.from;
                    openEmojiPicker(context, favKey, me,
                        onAfterToggle: (_, __) {
                      _persistReactionForFav(favKey, msg);
                    });
                  }),
                  actionTile(
                    _isFavMsgPinned(msg)
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    _isFavMsgPinned(msg) ? l.unpin : l.pin,
                    () {
                      Navigator.pop(ctx);
                      _toggleFavPin(msg);
                    },
                  ),
                  actionTile(
                    hasReminder
                        ? Icons.alarm_off_rounded
                        : Icons.alarm_add_rounded,
                    hasReminder ? l.cancelReminder : l.setReminder,
                    () {
                      Navigator.pop(ctx);
                      _handleReminderToggle(
                        msg: msg,
                        hasReminder: hasReminder,
                        chatId: reminderChatId,
                        messageId: reminderMsgId,
                        chatTitle: widget.title,
                      );
                    },
                  ),
                  if (isSaveable)
                    actionTile(Icons.save_alt_rounded, l.save, () {
                      Navigator.pop(ctx);
                      _saveMediaFromMessage(text);
                    }),
                  if (!isMedia)
                    actionTile(Icons.copy_rounded, l.copy, () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: text));
                      rootScreenKey.currentState?.showSnack(l.msgCopied);
                    }),
                  if (!isMedia)
                    actionTile(Icons.edit_rounded, l.edit, () {
                      Navigator.pop(ctx);
                      _startEditingMessage(msg);
                    }),
                  actionTile(
                    Icons.delete_outline_rounded,
                    l.delete,
                    () {
                      Navigator.pop(ctx);
                      () async {
                        final confirmed = await showOnyxConfirmDialog(
                          context: context,
                          title: l.deleteMessageTitle,
                          message: l.deleteFavMessageContent,
                          confirmLabel: l.delete,
                          isDestructive: true,
                          icon: Icons.delete_outline_rounded,
                        );
                        if (confirmed == true) {
                          _deleteMessage(msg);
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
      ),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _shouldPreserveExternalFocus = false;
      });
    });
  }

  List<DesktopMenuItem>? _buildDesktopMenuItems(ChatMessage msg) {
    if (!isDesktop) return null;
    final text = msg.content;
    final isImage = text.startsWith('IMAGEv1:');
    final isAlbum = text.startsWith('ALBUMv1:');
    final isVideo = text.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = text.startsWith('VOICEv1:');
    final isFile = text.startsWith('FILEv1:') || text.startsWith('FILE:');
    final isSaveable = isImage || isAlbum || isVideo || isVoice || isFile;
    final isMedia = isSaveable || text.startsWith('[cannot-decrypt');
    final l = AppLocalizations.of(context);
    return [
      DesktopMenuItem(
        icon: Icons.reply_rounded,
        label: l.reply,
        onPressed: () => _startReplyingToMessage({
          'id': msg.id,
          'sender': msg.from,
          'senderDisplayName': msg.from,
          'content': msg.content,
        }),
      ),
      DesktopMenuItem(
        icon: Icons.add_reaction_outlined,
        label: l.react,
        onPressed: () {
          final favKey =
              '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
          final me = rootScreenKey.currentState?.currentUsername ?? msg.from;
          openEmojiPicker(context, favKey, me, onAfterToggle: (_, __) {
            _persistReactionForFav(favKey, msg);
          });
        },
      ),
      DesktopMenuItem(
        icon: _isFavMsgPinned(msg)
            ? Icons.push_pin_outlined
            : Icons.push_pin_rounded,
        label: _isFavMsgPinned(msg) ? l.unpin : l.pin,
        onPressed: () => _toggleFavPin(msg),
      ),
      DesktopMenuItem(
        icon: _hasReminderSync(msg)
            ? Icons.alarm_off_rounded
            : Icons.alarm_add_rounded,
        label: _hasReminderSync(msg) ? l.cancelReminder : l.setReminder,
        onPressed: () => _handleReminderToggle(
          msg: msg,
          hasReminder: _hasReminderSync(msg),
          chatId: 'fav:${widget.favoriteId}',
          messageId: msg.serverMessageId?.toString() ?? msg.id,
          chatTitle: widget.title,
        ),
      ),
      if (isSaveable)
        DesktopMenuItem(
          icon: Icons.save_alt_rounded,
          label: l.save,
          onPressed: () => _saveMediaFromMessage(text),
        ),
      if (isImage)
        DesktopMenuItem(
          icon: Icons.copy_all_rounded,
          label: l.copyImage,
          onPressed: () => copyMessageImageToClipboard(
              text, (m) => rootScreenKey.currentState?.showSnack(m)),
        ),
      if (!isMedia)
        DesktopMenuItem(
          icon: Icons.content_copy_rounded,
          label: l.copy,
          type: ContextMenuButtonType.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            rootScreenKey.currentState?.showSnack(l.msgCopied);
          },
        ),
      if (!isMedia)
        DesktopMenuItem(
          icon: Icons.edit_rounded,
          label: l.edit,
          onPressed: () => _startEditingMessage(msg),
        ),
      DesktopMenuItem(
        icon: Icons.delete_outline_rounded,
        label: l.delete,
        type: ContextMenuButtonType.delete,
        color: Colors.red.shade400,
        onPressed: () => _desktopDeleteFavorite(msg),
      ),
    ];
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
          showSavedToSnack(destPath);
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
        showSavedToSnack(destPath);
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  Future<void> _desktopDeleteFavorite(ChatMessage msg) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.favDeleteMessageQuestion,
      message: l.favMessageRemovedFromFavorites,
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) _deleteMessage(msg);
  }

  List<_ListItem> _buildMessagesWithDaySeparators(List<ChatMessage> msgs) {
    if (msgs.isEmpty) return [];

    final currentHash = msgs.length.hashCode ^
        (msgs.isNotEmpty ? msgs.last.id.hashCode : 0) ^
        (msgs.isNotEmpty ? msgs.last.content.hashCode : 0);

    if (_cachedDaySeparatorItems != null &&
        _cachedDaySeparatorHash == currentHash) {
      return _cachedDaySeparatorItems!;
    }

    final items = <_ListItem>[];
    DateTime? currentDay;
    for (int i = 0; i < msgs.length; i++) {
      final msg = msgs[i];
      final msgDate = DateTime(msg.time.year, msg.time.month, msg.time.day);
      if (currentDay == null || currentDay != msgDate) {
        items.add(_DaySeparatorItem(msgDate));
        currentDay = msgDate;
      }
      items.add(_MessageItem(msg));
    }

    final result = items.reversed.toList();

    _cachedDaySeparatorItems = result;
    _cachedDaySeparatorHash = currentHash;

    return result;
  }

  void _invalidateDaySeparatorCache() {
    _cachedDaySeparatorItems = null;
    _cachedDaySeparatorHash = 0;
    _cachedAllImages = null;
    _cachedAllImagesHash = 0;
    _cachedDragHash = 0;
  }

  Widget _buildDaySeparator(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final msgDate = date;
    final l = AppLocalizations.of(context);
    String dayText;
    if (msgDate == today) {
      dayText = l.today;
    } else if (msgDate == yesterday) {
      dayText = l.yesterday;
    } else {
      dayText = '${date.day}.${date.month}.${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color:
                  Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dayText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color:
                  Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    _shouldPreserveExternalFocus = true;
    _focusNode.unfocus();
    final root = rootScreenKey.currentState;
    if (root == null) {
      _shouldPreserveExternalFocus = false;
      return;
    }
    final currentFav = root.favorites.firstWhere(
        (f) => f.id == widget.favoriteId,
        orElse: () => throw Exception('Favorite not found'));
    final currentTitle = currentFav.title;
    String? currentAvatarPath = currentFav.avatarPath;
    final originalAvatarPath = currentFav.avatarPath;
    bool appliedOptimisticChange = false;
    final controller = TextEditingController(text: currentTitle);
    bool isUploading = false;
    final l = AppLocalizations.of(context);

    Future<void> changeAvatarInDialog(StateSetter setDialogState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      setDialogState(() => isUploading = true);
      try {
        final Uint8List fileBytes = await pickedFile.readAsBytes();

        if (!mounted) return;
        final cropped = await showAvatarCropScreen(context, fileBytes);
        if (cropped == null) {
          setDialogState(() => isUploading = false);
          return;
        }
        final appSupport = await getOnyxSupportDirectory();
        final avatarDir = Directory('${appSupport.path}/fav_avatars');
        await avatarDir.create(recursive: true);
        final hash = md5.convert(cropped).toString().substring(0, 12);
        final safeName = '${widget.favoriteId}_$hash.jpg';
        final destPath = '${avatarDir.path}/$safeName';
        final destFile = File(destPath);
        await destFile.writeAsBytes(cropped);

        final optimisticFav = currentFav.copyWith(avatarPath: destPath);
        root.updateFavorite(optimisticFav);
        favoritesVersion.value++;
        appliedOptimisticChange = true;

        setDialogState(() {
          currentAvatarPath = destPath;
          isUploading = false;
        });
      } catch (e, stack) {
        debugPrint('Avatar save error: $e\n$stack');
        root.showSnack('Failed to save avatar');
        setDialogState(() => isUploading = false);
      }
    }

    void removeAvatarInDialog(StateSetter setDialogState) async {
      final confirmed = await showOnyxConfirmDialog(
        context: context,
        title: l.favDeleteAvatarQuestion,
        message: l.favRemoveAvatarConfirm,
        confirmLabel: l.delete,
        isDestructive: true,
        icon: Icons.delete_outline_rounded,
      );
      if (confirmed == true) {
        setDialogState(() {
          currentAvatarPath = null;
        });
        final optimisticFav = currentFav.copyWith(avatarPath: null);
        root.updateFavorite(optimisticFav);
        favoritesVersion.value++;
        appliedOptimisticChange = true;
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
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
                      // ── Header ──────────────────────────────────────────
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
                              child: Icon(Icons.bookmark_rounded,
                                  size: 18, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l.editChat,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
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
                      // ── Content ───────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
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
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              cs.outline.withValues(alpha: 0.2),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: currentAvatarPath != null &&
                                                File(currentAvatarPath!)
                                                    .existsSync()
                                            ? Image.file(
                                                File(currentAvatarPath!),
                                                fit: BoxFit.cover)
                                            : ValueListenableBuilder<double>(
                                                valueListenable: SettingsManager
                                                    .elementBrightness,
                                                builder: (_, brightness, ___) {
                                                  final baseColor =
                                                      SettingsManager
                                                          .getElementColor(
                                                    cs.surfaceContainerHighest,
                                                    brightness,
                                                  );
                                                  return Container(
                                                    color: baseColor.withValues(
                                                        alpha: 0.3),
                                                    child: Icon(
                                                      Icons.bookmark,
                                                      size: 42,
                                                      color: cs.primary,
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
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
                                  autofocus: true,
                                  maxLength: 50,
                                  decoration: InputDecoration(
                                    labelText: l.chatNameLabel,
                                    hintText: 'Enter chat name',
                                    counterText: '',
                                    filled: true,
                                    fillColor: baseColor.withValues(alpha: 0.3),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(28)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                          color: cs.outlineVariant
                                              .withValues(alpha: 0.3),
                                          width: 0.8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                          color: cs.primary, width: 1.4),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50)),
                                      ),
                                    ),
                                    child: Text(l.cancel),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: isUploading
                                        ? null
                                        : () {
                                            final newName =
                                                controller.text.trim();
                                            if (newName.isEmpty) {
                                              root.showSnack(
                                                  'Name cannot be empty');
                                              return;
                                            }
                                            final hasTitleChanged =
                                                newName != currentTitle;
                                            final hasAvatarChanged =
                                                currentAvatarPath !=
                                                    currentFav.avatarPath;
                                            if (!hasTitleChanged &&
                                                !hasAvatarChanged) {
                                              Navigator.of(ctx).pop(false);
                                              return;
                                            }
                                            Navigator.of(ctx).pop(true);
                                          },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(50)),
                                      ),
                                    ),
                                    child: Text(l.save),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _shouldPreserveExternalFocus = false;
    controller.dispose();
    if (result == true) {
      final newName = controller.text.trim();
      if (currentFav.avatarPath != null && currentAvatarPath == null) {
        try {
          await File(currentFav.avatarPath!).delete();
        } catch (e) {
          debugPrint('[err] $e');
        }
      }
      final updatedFav =
          currentFav.copyWith(title: newName, avatarPath: currentAvatarPath);
      root.updateFavorite(updatedFav);
      root.showSnack(' Updated successfully');
      favoritesVersion.value++;
    } else {
      if (appliedOptimisticChange) {
        final reverted = currentFav.copyWith(avatarPath: originalAvatarPath);
        root.updateFavorite(reverted);
        favoritesVersion.value++;
      }
    }
  }

  String _chatId() => 'fav:${widget.favoriteId}';

  void _persistReactionForFav(String key, ChatMessage msg) {
    final current = reactionsFor(key);
    msg.reactions
      ..clear()
      ..addAll(current.map((k, v) => MapEntry(k, List<String>.from(v))));
    rootScreenKey.currentState?.schedulePersistChats(chatId: _chatId());
  }

  Future<void> _pickFavoriteAttachments() async {
    if (kIsWeb) return;

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
        rootScreenKey.currentState?.showSnack('File picker error: $e');
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
      final ext = p.extension(path).toLowerCase();
      rootScreenKey.currentState?.showSnack('Unsupported file type: $ext');
      return;
    }
    final basename = p.basename(path);
    final ext = p.extension(basename).toLowerCase();
    final type = FileTypeDetector.getFileType(path);
    _showFilePreviewAndSend(path, basename, ext, type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                    onPressed: _exitFavSelectionMode,
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
                                  ? _exitFavSelectionMode
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
                        final textContent = ValueListenableBuilder<int>(
                          valueListenable: favoritesVersion,
                          builder: (context, _, __) {
                            final currentTitle =
                                rootScreenKey.currentState?.favorites
                                        .firstWhere(
                                          (f) => f.id == widget.favoriteId,
                                          orElse: () => FavoriteChat(
                                              id: widget.favoriteId,
                                              title: widget.title,
                                              createdAt: DateTime.now()),
                                        )
                                        .title ??
                                    widget.title;
                            return GestureDetector(
                              onTap: _showEditNameDialog,
                              child: MarqueeText(
                                text: currentTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            );
                          },
                        );
                        final pill = AdaptiveGlassPill(
                          backgroundColor: bgColor,
                          borderColor: borderColor,
                          child: Row(
                            mainAxisSize:
                                isWide ? MainAxisSize.min : MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: favoritesVersion,
                                builder: (context, _, __) {
                                  final fav = rootScreenKey
                                      .currentState?.favorites
                                      .firstWhere(
                                    (f) => f.id == widget.favoriteId,
                                    orElse: () => FavoriteChat(
                                        id: widget.favoriteId,
                                        title: widget.title,
                                        createdAt: DateTime.now()),
                                  );
                                  return _EditableFavoriteAvatar(
                                    id: widget.favoriteId,
                                    currentAvatarPath: fav?.avatarPath,
                                    size: 40,
                                    onTap: _showEditNameDialog,
                                  );
                                },
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
                          onTap: _showEditNameDialog,
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
                            if (sel.selected.values.any(_isFavTextMessage))
                              selBtn(Icons.copy_rounded, null, 'Copy',
                                  _copySelectedFavMessages),
                            if (sel.selected.isNotEmpty)
                              selBtn(Icons.forward_rounded, null, 'Forward',
                                  _forwardSelectedFavMessages),
                            selBtn(
                                Icons.delete_outline_rounded,
                                cs.error,
                                'Delete',
                                sel.selected.isNotEmpty
                                    ? _confirmDeleteSelectedFav
                                    : null),
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
                                onSelected: (value) {
                                  if (value == 'gallery') {
                                    final msgs = rootScreenKey
                                            .currentState?.chats[_chatId()] ??
                                        const <ChatMessage>[];
                                    showMediaGalleryDialog(
                                      context,
                                      items:
                                          extractGalleryItemsFromChatMessages(
                                              msgs),
                                      peerUsername: widget.title,
                                      onJumpToMessage: (id) =>
                                          _scrollToFavMessageById(id),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
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
      extendBodyBehindAppBar: true,
      body: DragDropZone(
        onFilesDropped: _handleDroppedFiles,
        child: Stack(
          children: [
            const ChatBackgroundLayer(),
            ValueListenableBuilder<int>(
              valueListenable: getChatMessageVersion(_chatId()),
              builder: (_, __, ___) {
                final rootState = rootScreenKey.currentState;
                if (rootState == null) return const SizedBox();
                final msgs = rootState.chats[_chatId()] ?? [];

                if (msgs.isEmpty) {
                  return EmptyChatPlaceholder(
                      label: AppLocalizations.of(context).noMessagesYet);
                }
                // Only flip this after a frame that actually had history
                // loaded — see group_chat_screen.dart for why flipping it
                // on an empty/placeholder frame breaks the
                // chat-open-doesn't-animate gating.
                if (!_hasBuiltMessageListOnce) {
                  if (_alreadyRenderedMessageIds.isEmpty) {
                    // No pre-seeded history → first message in a new chat.
                    // Set immediately so the bubble mounts with animate:true
                    // (didUpdateWidget is a no-op in AnimatedMessageBubble).
                    _hasBuiltMessageListOnce = true;
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _hasBuiltMessageListOnce = true;
                    });
                  }
                }
                final msgsHash = msgs.length.hashCode ^
                    (msgs.isNotEmpty ? msgs.last.id.hashCode : 0) ^
                    (msgs.isNotEmpty ? msgs.last.content.hashCode : 0);
                // Deferred for the same reason as ChatScreen: this hash
                // goes stale on every send, and the full-history recompute
                // is expensive enough in heavy chats to block the frame the
                // new bubble's entrance animation starts on.
                if (_cachedAllImages == null) {
                  _cachedAllImages =
                      ChatImagesScope.computeFromChatMessages(msgs);
                  _cachedAllImagesHash = msgsHash;
                } else if (_cachedAllImagesHash != msgsHash) {
                  final targetHash = msgsHash;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _cachedAllImagesHash == targetHash) return;
                    final recomputed =
                        ChatImagesScope.computeFromChatMessages(msgs);
                    if (!mounted) return;
                    setState(() {
                      _cachedAllImages = recomputed;
                      _cachedAllImagesHash = targetHash;
                    });
                  });
                }
                return ChatImagesScope(
                  allImages: _cachedAllImages!,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: SettingsManager.showAvatarInChats,
                    builder: (_, showAvatar, __) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: SettingsManager.swapMessageAlignment,
                        builder: (_, swapped, __) {
                          return ValueListenableBuilder<bool>(
                            valueListenable:
                                SettingsManager.alignAllMessagesRight,
                            builder: (_, alignRight, __) {
                              final items =
                                  _buildMessagesWithDaySeparators(msgs);

                              // Only re-preload when the list actually changes,
                              // not on every unrelated rebuild.
                              final stampLast =
                                  msgs.isEmpty ? '' : msgs.last.id;
                              if (msgs.length != _preloadStampCount ||
                                  stampLast != _preloadStampLast) {
                                _preloadStampCount = msgs.length;
                                _preloadStampLast = stampLast;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  ChatImagePreloader.preload(msgs);
                                });
                              }

                              // Compute search matches
                              if (_showSearch && _searchQuery.isNotEmpty) {
                                _cachedSearchMatches = items
                                    .asMap()
                                    .entries
                                    .where((e) =>
                                        e.value is _MessageItem &&
                                        (e.value as _MessageItem)
                                            .message
                                            .content
                                            .toLowerCase()
                                            .contains(_searchQuery))
                                    .map((e) => e.key)
                                    .toList();
                                final clampedIdx = _cachedSearchMatches.isEmpty
                                    ? 0
                                    : _currentMatchIdx.clamp(
                                        0, _cachedSearchMatches.length - 1);
                                final stats = (
                                  current: _cachedSearchMatches.isEmpty
                                      ? 0
                                      : clampedIdx + 1,
                                  total: _cachedSearchMatches.length,
                                );
                                if (_searchStats.value != stats) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) _searchStats.value = stats;
                                  });
                                }
                              } else {
                                _cachedSearchMatches = [];
                                if (_searchStats.value.total != 0) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted)
                                      _searchStats.value =
                                          (current: 0, total: 0);
                                  });
                                }
                              }
                              if (_cachedDragHash != _cachedDaySeparatorHash) {
                                final targetHash = _cachedDaySeparatorHash;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!mounted || _cachedDragHash == targetHash)
                                    return;
                                  final dragMessages = items
                                      .whereType<_MessageItem>()
                                      .map((item) => item.message)
                                      .toList(growable: false);
                                  setState(() {
                                    _cachedDragHash = targetHash;
                                    _dragSelectionOrder = dragMessages
                                        .map(_selectionKeyForMessage)
                                        .toList(growable: false);
                                    _dragSelectionLookup = {
                                      for (final msg in dragMessages)
                                        _selectionKeyForMessage(msg): msg,
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

                              // Maps each item's stable String key to its
                              // current flat ListView index — see the matching
                              // findChildIndexCallback below for why this
                              // exists (without it, every visible bubble gets
                              // destroyed + rebuilt from scratch on every
                              // single send).
                              final Map<String, int> itemKeyToFlatIndex = {};
                              for (int idx = 0; idx < items.length; idx++) {
                                final flatIndex = idx;
                                final item = items[idx];
                                if (item is _DaySeparatorItem) {
                                  itemKeyToFlatIndex[
                                          'day_${item.date.toIso8601String()}'] =
                                      flatIndex;
                                } else if (item is _MessageItem) {
                                  itemKeyToFlatIndex['msg_${item.message.id}'] =
                                      flatIndex;
                                }
                              }

                              return Listener(
                                key: _messageListViewportKey,
                                onPointerDown: (_) {
                                  if (!isDesktop) return;
                                  _suppressAutoRefocus = true;
                                  _focusNode.unfocus();
                                },
                                onPointerUp: (_) {
                                  if (_isDragSelectingMessages)
                                    _endMessageDragSelection();
                                },
                                onPointerCancel: (_) {
                                  if (_isDragSelectingMessages)
                                    _endMessageDragSelection();
                                },
                                child: ListView.builder(
                                  controller: _scroll,
                                  reverse: true,
                                  cacheExtent:
                                      SettingsManager.chatCacheExtent.value,
                                  addRepaintBoundaries: true,
                                  addAutomaticKeepAlives: true,
                                  padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top +
                                        kToolbarHeight +
                                        (_showSearch ? 64 : 12),
                                    bottom: 72 +
                                        MediaQuery.of(context).padding.bottom,
                                  ),
                                  itemCount: items.length,
                                  findChildIndexCallback: (Key key) {
                                    if (key is! ValueKey<String>) return null;
                                    return itemKeyToFlatIndex[key.value];
                                  },
                                  itemBuilder: (context, i) {
                                    final adjustedI = i;
                                    final item = items[adjustedI];
                                    if (item is _DaySeparatorItem) {
                                      return KeyedSubtree(
                                        key: ValueKey<String>(
                                            'day_${item.date.toIso8601String()}'),
                                        child: RepaintBoundary(
                                          child: _buildDaySeparator(
                                              context, item.date),
                                        ),
                                      );
                                    }
                                    final msg = (item as _MessageItem).message;
                                    final String uniqueKey =
                                        '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
                                    seedReactions(uniqueKey, msg.reactions);
                                    final String animKey = msg.id;
                                    final isFirstAppearance =
                                        !_alreadyRenderedMessageIds
                                            .contains(animKey);
                                    if (isFirstAppearance) {
                                      _alreadyRenderedMessageIds.add(animKey);
                                    }
                                    final isSearchMatch =
                                        _searchQuery.isNotEmpty &&
                                            msg.content
                                                .toLowerCase()
                                                .contains(_searchQuery);
                                    final isCurrentSearchMatch =
                                        isSearchMatch &&
                                            _cachedSearchMatches.isNotEmpty &&
                                            _cachedSearchMatches[
                                                    _currentMatchIdx] ==
                                                adjustedI;

                                    final cs = Theme.of(context).colorScheme;
                                    final msgBubble = MessageBubble(
                                      key: ValueKey<String>(
                                          'mb_inner_$uniqueKey'),
                                      text: msg.content,
                                      outgoing: true,
                                      time: msg.time,
                                      peerUsername: '',
                                      chatMessage: msg,
                                      replyToId: msg.replyToId,
                                      replyToUsername: msg.replyToSender,
                                      replyToContent: msg.replyToContent,
                                      hasReminder: _hasReminderSync(msg),
                                      desktopMenuItems:
                                          _buildDesktopMenuItems(msg),
                                      highlighted:
                                          (msg.serverMessageId != null &&
                                                  _replyingToMessage != null &&
                                                  _replyingToMessage!['id']
                                                          ?.toString() ==
                                                      (msg.serverMessageId
                                                          ?.toString())) ||
                                              (msg.serverMessageId == null &&
                                                  _replyingToMessage != null &&
                                                  _replyingToMessage!['localId']
                                                          ?.toString() ==
                                                      msg.id.toString()),
                                      onReplyTap: msg.replyToId != null
                                          ? () => _scrollToFavMessageById(
                                              msg.replyToId.toString())
                                          : null,
                                      onRightClick: isDesktop
                                          ? (offset) {
                                              debugPrint(
                                                  '[RightClickMenu] favorites onRightClick invoked, msgId=${msg.id}');
                                              final items =
                                                  _buildDesktopMenuItems(msg);
                                              debugPrint(
                                                  '[RightClickMenu] favorites items=${items?.length}');
                                              if (items != null &&
                                                  items.isNotEmpty) {
                                                showMessageDesktopMenu(
                                                    context, offset, items);
                                              }
                                            }
                                          : null,
                                    );
                                    final expensiveChild =
                                        AnimatedMessageBubble(
                                      key: ValueKey<String>(animKey),
                                      outgoing: msg.outgoing,
                                      animate: _hasBuiltMessageListOnce &&
                                          isFirstAppearance &&
                                          SettingsManager
                                              .messageAnimationsEnabled.value,
                                      flightOriginKey:
                                          msg.outgoing ? _inputAreaKey : null,
                                      flightFromEdge: !msg.outgoing,
                                      alignRight: !swapped,
                                      child: RepaintBoundary(child: msgBubble),
                                    );
                                    return ValueListenableBuilder<
                                        ({
                                          bool active,
                                          Map<String, ChatMessage> selected
                                        })>(
                                      key: ValueKey<String>('msg_$animKey'),
                                      valueListenable: _selectionNotifier,
                                      child: expensiveChild,
                                      builder: (_, sel, bubbleChild) {
                                        final isSelected =
                                            sel.selected.containsKey(uniqueKey);
                                        return KeyedSubtree(
                                          key: _messageItemKey(animKey),
                                          child: RawGestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            gestures: {
                                              LongPressGestureRecognizer:
                                                  GestureRecognizerFactoryWithHandlers<
                                                      LongPressGestureRecognizer>(
                                                () => LongPressGestureRecognizer(
                                                    duration:
                                                        _messageLongPressDuration),
                                                (instance) {
                                                  instance.onLongPressStart = (_) =>
                                                      _startMessageDragSelection(
                                                          msg, uniqueKey);
                                                  instance.onLongPressMoveUpdate =
                                                      (details) =>
                                                          _updateMessageDragSelection(
                                                              details
                                                                  .globalPosition);
                                                  instance.onLongPressEnd = (_) =>
                                                      _endMessageDragSelection();
                                                },
                                              ),
                                            },
                                            child: GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: sel.active
                                                  ? () =>
                                                      _toggleFavMessageSelection(
                                                          msg, uniqueKey)
                                                  : null,
                                              onDoubleTap: sel.active
                                                  ? null
                                                  : () =>
                                                      _enterFavSelectionMode(
                                                          msg, uniqueKey),
                                              child: AnimatedContainer(
                                                key: (_scrollTargetId != null &&
                                                        (_scrollTargetId ==
                                                                msg.serverMessageId
                                                                    ?.toString() ||
                                                            _scrollTargetId ==
                                                                msg.id))
                                                    ? _scrollTargetKey
                                                    : null,
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                color: isCurrentSearchMatch
                                                    ? cs.primary
                                                        .withValues(alpha: 0.28)
                                                    : isSearchMatch
                                                        ? cs.primary.withValues(
                                                            alpha: 0.12)
                                                        : isSelected
                                                            ? cs.primaryContainer
                                                                .withValues(
                                                                    alpha: 0.45)
                                                            : (_scrollHighlightId !=
                                                                        null &&
                                                                    (_scrollHighlightId ==
                                                                            msg.serverMessageId
                                                                                ?.toString() ||
                                                                        _scrollHighlightId ==
                                                                            msg
                                                                                .id))
                                                                ? cs.primary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.18)
                                                                : Colors
                                                                    .transparent,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 12),
                                                child: Row(
                                                  mainAxisAlignment: swapped
                                                      ? MainAxisAlignment.start
                                                      : MainAxisAlignment.end,
                                                  children: [
                                                    if (sel.active)
                                                      AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    150),
                                                        margin: const EdgeInsets
                                                            .only(right: 8),
                                                        width: 22,
                                                        height: 22,
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: isSelected
                                                              ? cs.primary
                                                              : Colors
                                                                  .transparent,
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? cs.primary
                                                                : cs.outline,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: isSelected
                                                            ? Icon(Icons.check,
                                                                size: 14,
                                                                color: cs
                                                                    .onPrimary)
                                                            : null,
                                                      ),
                                                    Flexible(
                                                      child:
                                                          SwipeableMessageWrapper(
                                                        disabled: sel.active,
                                                        onSwipeRight: () =>
                                                            _onLongPress(msg),
                                                        onSwipeLeft: () {
                                                          final preview = {
                                                            'id': msg
                                                                .serverMessageId,
                                                            'localId': msg.id,
                                                            'sender': msg.from,
                                                            'senderDisplayName':
                                                                msg.from,
                                                            'content':
                                                                getPreviewText(
                                                                    msg.content),
                                                          };
                                                          _startReplyingToMessage(
                                                              preview);
                                                        },
                                                        child: Column(
                                                          crossAxisAlignment: swapped
                                                              ? CrossAxisAlignment
                                                                  .start
                                                              : CrossAxisAlignment
                                                                  .end,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            AbsorbPointer(
                                                              absorbing:
                                                                  sel.active,
                                                              child:
                                                                  bubbleChild!,
                                                            ),
                                                            MessageReactionBar(
                                                              reactions:
                                                                  reactionsFor(
                                                                      uniqueKey),
                                                              myUsername: rootScreenKey
                                                                      .currentState
                                                                      ?.currentUsername ??
                                                                  msg.from,
                                                              outgoing:
                                                                  !swapped,
                                                              onToggle:
                                                                  (emoji) {
                                                                final me = rootScreenKey
                                                                        .currentState
                                                                        ?.currentUsername ??
                                                                    msg.from;
                                                                toggleReaction(
                                                                    uniqueKey,
                                                                    emoji,
                                                                    me);
                                                                _persistReactionForFav(
                                                                    uniqueKey,
                                                                    msg);
                                                              },
                                                              onAddReaction:
                                                                  (ctx2) {
                                                                final me = rootScreenKey
                                                                        .currentState
                                                                        ?.currentUsername ??
                                                                    msg.from;
                                                                openEmojiPicker(
                                                                    ctx2,
                                                                    uniqueKey,
                                                                    me,
                                                                    onAfterToggle:
                                                                        (_, __) {
                                                                  _persistReactionForFav(
                                                                      uniqueKey,
                                                                      msg);
                                                                });
                                                              },
                                                            ),
                                                          ],
                                                        ),
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
                              );
                            },
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
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                left: 16,
                right: 16,
                child: _buildFavPinnedBanner(context),
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
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: 12.0 + MediaQuery.of(context).padding.bottom,
                    left: 16,
                    right: 16),
                child: ValueListenableBuilder<double>(
                  valueListenable: SettingsManager.elementOpacity,
                  builder: (_, opacity, __) {
                    return ValueListenableBuilder<double>(
                      valueListenable: SettingsManager.inputBarMaxWidth,
                      builder: (_, width, __) {
                        return MeasureSize(
                          onChange: (size) {
                            if ((_bottomBarHeight.value - size.height).abs() >
                                0.5) {
                              _bottomBarHeight.value = size.height;
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: _editingMessage != null
                                    ? ValueListenableBuilder<double>(
                                        valueListenable:
                                            SettingsManager.elementBrightness,
                                        builder: (_, brightness, ___) {
                                          final colorScheme =
                                              Theme.of(context).colorScheme;
                                          final baseColor =
                                              SettingsManager.getElementColor(
                                            colorScheme.surfaceContainerHighest,
                                            brightness,
                                          );
                                          return Container(
                                            constraints:
                                                BoxConstraints(maxWidth: width),
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
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
                                              children: [
                                                Icon(Icons.edit,
                                                    size: 16,
                                                    color: colorScheme.primary),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Edit message',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: colorScheme
                                                              .primary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _editingMessage!
                                                            .content,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                  alpha: 0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.close,
                                                      size: 18),
                                                  onPressed:
                                                      _cancelEditingMessage,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashRadius: 18,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32),
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
                                        valueListenable:
                                            SettingsManager.elementBrightness,
                                        builder: (_, brightness, ___) {
                                          final baseColor =
                                              SettingsManager.getElementColor(
                                            Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            brightness,
                                          );
                                          return Container(
                                            constraints:
                                                BoxConstraints(maxWidth: width),
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: baseColor.withValues(
                                                  alpha: opacity),
                                              borderRadius:
                                                  BorderRadius.circular(28),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant
                                                    .withValues(alpha: 0.15),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        _replyingToMessage![
                                                                    'senderDisplayName']
                                                                ?.toString() ??
                                                            _replyingToMessage![
                                                                    'sender']
                                                                ?.toString() ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        getPreviewText(
                                                          (_replyingToMessage![
                                                                      'content'] ??
                                                                  '')
                                                              .toString(),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                      alpha:
                                                                          0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.close,
                                                      size: 18),
                                                  onPressed: _cancelReplying,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  splashRadius: 18,
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              // Below the reply preview, above the input bar —
                              // plain Column children, so they stack instead
                              // of overlapping.
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                child: _pendingUploads.isNotEmpty
                                    ? UploadProgressBar(
                                        tasks: _pendingUploads,
                                        maxWidth: width,
                                        // Favorites uploads are a local file
                                        // copy, not a network transfer — there's
                                        // no real byte-level percentage to show.
                                        showProgress: false,
                                        onCancelAll: _cancelAllUploads,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              AnimatedBuilder(
                                animation: _inputEntryController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset:
                                        Offset(0, _inputEntryTranslateY.value),
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
                                    SettingsManager
                                        .liquidGlassInputLightIntensity,
                                    SettingsManager.liquidGlassInputThickness,
                                  ]),
                                  builder: (_, __) {
                                    final brightness =
                                        SettingsManager.elementBrightness.value;
                                    final baseColor =
                                        SettingsManager.getElementColor(
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      brightness,
                                    );
                                    final isMobile = !Platform.isWindows &&
                                        !Platform.isLinux;
                                    final useGlass = isMobile &&
                                        SettingsManager
                                            .liquidGlassOnInput.value;
                                    final bar = ConstrainedBox(
                                      constraints:
                                          BoxConstraints(maxWidth: width),
                                      child: ChatInputBar(
                                        inputAreaKey: _inputAreaKey,
                                        controller: _textCtrl,
                                        textFocusNode: _focusNode,
                                        recordingListenable: recordingNotifier,
                                        recordingLevelListenable:
                                            recordingLevelNotifier,
                                        onCancelRecording: () {
                                          rootScreenKey.currentState
                                              ?.cancelRecording();
                                        },
                                        onMicPressed: (isRecording) {
                                          if (isRecording) {
                                            rootScreenKey.currentState
                                                ?.stopRecordingAndUpload(
                                              'fav:${widget.favoriteId}',
                                              _replyingToMessage,
                                              (task) {
                                                task.onComplete = (_) async {
                                                  if (mounted) {
                                                    setState(() =>
                                                        _pendingUploads
                                                            .remove(task));
                                                  }
                                                };
                                                if (mounted) {
                                                  setState(() => _pendingUploads
                                                      .add(task));
                                                }
                                              },
                                            );
                                            setState(() {
                                              _replyingToMessage = null;
                                            });
                                          } else {
                                            rootScreenKey.currentState
                                                ?.startRecording();
                                          }
                                        },
                                        onAttachPressed:
                                            _pickFavoriteAttachments,
                                        onSendPressed: () =>
                                            _submitMessage(_textCtrl.text),
                                        onPaste: _handlePasteFromClipboard,
                                        onChanged: (_) => _onUserTyping(),
                                        hintText: AppLocalizations.of(context)
                                            .localizeHint('Type something...'),
                                        backgroundColor:
                                            useGlass ? Colors.white : baseColor,
                                        opacity: useGlass ? 0.0 : opacity,
                                        borderColor: useGlass
                                            ? Colors.transparent
                                            : Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.15),
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
                                              if (bytes == null &&
                                                  data.uri.isNotEmpty) {
                                                try {
                                                  bytes =
                                                      await _clipboardChannel
                                                          .invokeMethod<
                                                                  Uint8List>(
                                                              'readContentUri',
                                                              {
                                                        'uri': data.uri
                                                      });
                                                } catch (e) {
                                                  debugPrint('[err] $e');
                                                }
                                              }
                                              if (bytes != null &&
                                                  bytes.isNotEmpty &&
                                                  mounted) {
                                                final ext =
                                                    data.mimeType.contains('/')
                                                        ? data.mimeType
                                                            .split('/')
                                                            .last
                                                        : 'png';
                                                final tempDir =
                                                    await getTemporaryDirectory();
                                                final tempFile = File(
                                                    '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.$ext');
                                                await tempFile
                                                    .writeAsBytes(bytes);
                                                _handleDroppedFiles(
                                                    [tempFile.path]);
                                              }
                                            } catch (e) {
                                              debugPrint(
                                                  '[ContentInsert] Error: $e');
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                    if (!useGlass) return bar;
                                    final quality = SettingsManager
                                        .liquidGlassInputQuality.value;
                                    final blur = SettingsManager
                                        .liquidGlassInputBlur.value;
                                    final tint = SettingsManager
                                        .liquidGlassInputTint.value;
                                    final saturation = SettingsManager
                                        .liquidGlassInputSaturation.value;
                                    final chromatic = SettingsManager
                                        .liquidGlassInputChromatic.value;
                                    final refractive = SettingsManager
                                        .liquidGlassInputRefractive.value;
                                    final lightIntensity = SettingsManager
                                        .liquidGlassInputLightIntensity.value;
                                    final thickness = SettingsManager
                                        .liquidGlassInputThickness.value;
                                    final glassQuality = switch (quality) {
                                      LiquidGlassQuality.fast =>
                                        GlassQuality.standard,
                                      LiquidGlassQuality.medium =>
                                        GlassQuality.minimal,
                                      LiquidGlassQuality.quality =>
                                        GlassQuality.premium,
                                    };
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
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
                                      shape: LiquidRoundedRectangle(
                                          borderRadius: 28),
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
                                    12.0 +
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
}
