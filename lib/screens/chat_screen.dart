// lib/screens/chat_screen.dart
import '../widgets/marquee_text.dart';
import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import '../services/chat_load_optimizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/onyx_base_dir.dart' show getOnyxDocumentsDirectory, getOnyxSupportDirectory;
import '../globals.dart';
import 'forward_screen.dart';
import 'dart:math' as math;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../enums/liquid_glass_quality.dart';
import '../widgets/chat_background_layer.dart';
import '../models/chat_message.dart';
import '../managers/account_manager.dart' hide UserInfo;
import '../managers/settings_manager.dart';
import '../managers/unread_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/chat_images_scope.dart';
import '../widgets/album_message_widget.dart' show AlbumItem;
import '../widgets/video_message_widget.dart';
import '../widgets/avatar_widget.dart';
import '../call/call_manager.dart';
import '../screens/call_overlay.dart';
import '../managers/user_cache.dart';
import '../screens/settings_tab.dart' show SupportSheet;
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../utils/clipboard_image.dart';
import '../utils/file_utils.dart';
import '../utils/image_file_cache.dart';
import '../utils/upload_task.dart';
import '../utils/blurhash_util.dart';
import '../utils/video_info.dart';
import '../widgets/pending_upload_card.dart';
import '../widgets/chat_search_bar.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../managers/lan_message_manager.dart';
import '../enums/delivery_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../managers/blocklist_manager.dart';
import '../widgets/message_reaction_bar.dart';
import '../widgets/swipeable_message_wrapper.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/measure_size.dart';
import '../enums/scroll_down_button_position.dart';
import '../utils/chat_image_preloader.dart';
import '../utils/dialog_utils.dart';
import '../widgets/empty_chat_placeholder.dart';
import '../utils/gallery_extractor.dart';
import 'media_gallery_screen.dart';

const List<String> _randomHints = [
  'Say hi!',
  'Type something...',
  'Send a voice note?',
  'Got something to share?',
  'Hello?',
  'They’re waiting…',
  'You own your messages.',
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

abstract class _ListItem {}

class _MessageItem extends _ListItem {
  final ChatMessage message;
  _MessageItem(this.message);
}

class _DaySeparatorItem extends _ListItem {
  final DateTime date;
  _DaySeparatorItem(this.date);
}

class _UnreadMarkerItem extends _ListItem {}

class _PendingUploadItem extends _ListItem {
  final UploadTask task;
  _PendingUploadItem(this.task);
}

class ChatScreen extends StatefulWidget {
  final String myUsername;
  final String otherUsername;
  final Future<void> Function(String text, Map<String, dynamic>? replyTo)
      onSend;
  final VoidCallback onTyping;
  final void Function(int? serverMessageId) onRequestResend;
  final Future<void> Function(int messageId, String newText) onEditMessage;
  final Future<void> Function(int messageId) onDeleteMessage;

  const ChatScreen({
    Key? key,
    required this.myUsername,
    required this.otherUsername,
    required this.onSend,
    required this.onTyping,
    required this.onRequestResend,
    required this.onEditMessage,
    required this.onDeleteMessage,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin, ReactionStateMixin {
  static final Set<String> _sessionInputAnimationsShown = {};

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final FocusNode _focusNode;
  late final FocusNode _keyboardListenerFocusNode;
  Timer? _typingThrottle;
  bool _typingSentRecently = false;
  final Set<String> _alreadyRenderedMessageIds = {};
  // True once the message list has painted at least one frame. Entry
  // animations are suppressed until then — closes a race where messages
  // (e.g. from WardLink or disk cache) finish loading asynchronously after
  // the pre-seed snapshot above was taken, which would otherwise make the
  // whole history "appear new" and animate in on open.
  bool _hasBuiltMessageListOnce = false;
  late final String _inputHint;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;
  final ValueNotifier<bool> _scrollDownVisible = ValueNotifier<bool>(false);
  // Tracks the live rendered height of the bottom bar (reply/edit preview +
  // ChatInputBar), which grows as the multi-line text field grows — used to
  // keep the scroll-to-bottom button above it instead of a fixed offset.
  final ValueNotifier<double> _bottomBarHeight = ValueNotifier<double>(76.0);

  String? _droppedFilePath;

  Map<String, dynamic>? _replyingToMessage;

  ChatMessage? _editingMessage;
  Map<String, dynamic>? _pinnedMessage;

  bool _isLANMode = false;
  bool _fastChangeMode = false;
  final _lanManager = LANMessageManager();

  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryScaleX;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  List<ChatMessage>? _cachedMessages;
  List<_ListItem>? _cachedItems;
  int _cachedMessagesHash = 0;

  List<AlbumItem>? _cachedAllImages;
  int _cachedAllImagesHash = 0;
  int _cachedDragHash = 0;

  late final _selectionNotifier =
      ValueNotifier<({bool active, Map<String, ChatMessage> selected})>(
          (active: false, selected: {}));
  Map<String, ChatMessage> get _selectedMessages =>
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
  static const Duration _messageLongPressDuration =
      Duration(milliseconds: 375);
  static const double _dragEdgeZone = 80.0;
  static const double _dragMaxSpeed = 14.0;

  final List<ChatMessage> _olderMessages = [];
  // Fingerprint of the message list last handed to the image preloader, so we
  // skip re-walking the whole list on every unrelated rebuild (reactions,
  // typing, read receipts). Only re-preload when the list actually changes.
  int _preloadStampCount = -1;
  String _preloadStampLast = '';
  final List<UploadTask> _pendingUploads = [];
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  // ── in-chat search ──────────────────────────────────────────────────────────
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentMatchIdx = 0;
  List<int> _cachedSearchMatches = [];
  final _searchStats =
      ValueNotifier<({int current, int total})>((current: 0, total: 0));
  final _searchFocusNode = FocusNode();

  late final Listenable _combinedHeaderListenable;

  void _startReplyingToMessage(Map<String, dynamic> msg) {
    setState(() {
      _replyingToMessage = msg;
    });
  }

  void _cancelReplying() {
    if (_replyingToMessage == null) return;
    setState(() {
      debugPrint(
          '[chat_screen::_cancelReplying] clearing _replyingToMessage\n${StackTrace.current}');
      _replyingToMessage = null;
    });
  }

  void _startEditingMessage(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _replyingToMessage = null;
    });
    _textCtrl.text = msg.content;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _textCtrl.text.length),
    );
    _requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
    });
    _textCtrl.clear();
    _requestFocus();
  }

  String get _pinPrefsKey => 'pinned_dm_${widget.otherUsername}';

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
    return pinId == (msg.serverMessageId?.toString() ?? msg.id);
  }

  void _togglePin(ChatMessage msg) {
    if (_isMsgPinned(msg)) {
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

  String get _chatId {
    final ids = [widget.myUsername, widget.otherUsername]..sort();
    return ids.join(':');
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

  void _scrollToMessageById(int? serverId, {String? localId}) {
    if (serverId == null && localId == null) return;
    final rootState = rootScreenKey.currentState;
    if (rootState == null) return;
    final msgs = <ChatMessage>[
      ...(rootState.chats[_chatId] ?? []),
      ..._olderMessages
    ];
    final items = _buildMessagesWithDaySeparators(msgs);

    int? foundIdx;
    String? foundId;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is _MessageItem) {
        final m = item.message;
        if (serverId != null && m.serverMessageId == serverId) {
          foundIdx = i;
          foundId = m.serverMessageId.toString();
          break;
        }
        if (localId != null && m.id == localId) {
          foundIdx = i;
          foundId = m.id;
          break;
        }
      }
    }
    if (foundIdx == null || foundId == null) return;

    final listviewIdx = foundIdx + _pendingUploads.length;
    final totalItems = items.length + _pendingUploads.length;
    final maxExt = _scroll.position.maxScrollExtent;
    final proportional =
        totalItems > 0 ? (listviewIdx / totalItems) * maxExt : 0.0;

    setState(() => _scrollTargetId = foundId);

    _scroll
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

  /// If a search-result tap asked to land on a specific message in this chat
  /// (see [setPendingMessageScrollTarget]), scroll to and highlight it once
  /// the message list is laid out — instead of opening at the bottom.
  void _consumePendingScrollTarget() {
    final pendingId = consumePendingMessageScrollTarget(_chatId);
    if (pendingId == null) return;
    void attempt([int retries = 6]) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scrollToMessageById(int.tryParse(pendingId), localId: pendingId);
      } else if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt(retries - 1));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

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
          final serverId = int.tryParse(pinId ?? '');
          return GestureDetector(
            onTap: () => _scrollToMessageById(serverId, localId: pinId),
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

  bool _isTextMessage(ChatMessage msg) {
    final t = msg.content;
    return !t.startsWith('IMAGEv1:') &&
        !t.startsWith('ALBUMv1:') &&
        !t.toUpperCase().startsWith('VIDEOV1:') &&
        !t.startsWith('VOICEv1:') &&
        !t.startsWith('FILEv1:') &&
        !t.startsWith('FILE:') &&
        !t.startsWith('MEDIA_PROXYv1:') &&
        !t.startsWith('[cannot-decrypt');
  }

  void _enterSelectionMode(ChatMessage msg, String uniqueKey) {
    HapticFeedback.mediumImpact();
    final cur = _selectionNotifier.value;
    _selectionNotifier.value =
        (active: true, selected: {...cur.selected, uniqueKey: msg});
  }

  void _exitSelectionMode() {
    _selectionNotifier.value = (active: false, selected: {});
  }

  void _toggleMessageSelection(ChatMessage msg, String uniqueKey) {
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

  GlobalKey _messageItemKey(String uniqueKey) =>
      _messageItemKeys.putIfAbsent(uniqueKey, () => GlobalKey());

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
    final from = min(start, end);
    final to = max(start, end);
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
      final context = _messageItemKeys[uniqueKey]?.currentContext;
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
    final box =
        _messageListViewportKey.currentContext?.findRenderObject() as RenderBox?;
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
    final box =
        _messageListViewportKey.currentContext?.findRenderObject() as RenderBox?;
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

  void _copySelectedMessages() {
    final texts = _selectedMessages.values
        .where(_isTextMessage)
        .map((m) => m.content)
        .join('\n\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).msgCopied);
    }
    _exitSelectionMode();
  }

  void _forwardSelectedMessages() {
    final contents = _selectedMessages.values.map((m) => m.content).toList();
    if (contents.isEmpty) return;
    _exitSelectionMode();
    ForwardScreen.show(context, contents);
  }

  Future<void> _confirmDeleteSelected() async {
    // media can be deleted anytime (outgoing), text only within 30s (canEditOrDelete already checks outgoing+timer)
    final toDelete = _selectedMessages.values
        .where((m) =>
            m.serverMessageId != null &&
            (!_isTextMessage(m) ? m.outgoing : m.canEditOrDelete))
        .toList();
    if (toDelete.isEmpty) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteMessageTitle),
        content: Text(toDelete.length == 1
            ? l.deleteMessageContent
            : 'Delete ${toDelete.length} messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final snapshot = List<ChatMessage>.from(toDelete);
      _exitSelectionMode();
      for (final msg in snapshot) {
        if (msg.content.startsWith('ALBUMv1:')) {
          await _deleteAlbumFiles(msg.content);
        } else {
          await _deleteMediaFile(msg.content);
        }
        await widget.onDeleteMessage(msg.serverMessageId!);
      }
    }
  }

  void _showMessageMenu(ChatMessage msg) {
    _focusNode.unfocus();
    final text = msg.content;
    final l = AppLocalizations.of(context);

    if (text.startsWith('[cannot-decrypt')) return;

    final isImage = text.startsWith('IMAGEv1:');
    final isAlbum = text.startsWith('ALBUMv1:');
    final isVideo = text.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = text.startsWith('VOICEv1:');
    final isFile = text.startsWith('FILEv1:') || text.startsWith('FILE:');
    final isSaveable = isImage || isAlbum || isVideo || isVoice || isFile;
    final isMedia = isSaveable || text.startsWith('MEDIA_PROXYv1:');

    _shouldPreserveExternalFocus = true;

    final canEdit = msg.canEditOrDelete;
    final canDelete = msg.outgoing;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MessageActionsSheet(
        msg: msg,
        canEditDelete: canEdit,
        isMedia: isMedia,
        canAlwaysDelete: isMedia,
        onReply: () {
          Navigator.pop(ctx);
          final preview = {
            'id': msg.serverMessageId,
            'localId': msg.id,
            'sender': msg.from,
            'senderDisplayName': msg.from,
            'content': getPreviewText(msg.content),
          };
          _startReplyingToMessage(preview);
        },
        onSave: isSaveable
            ? () {
                Navigator.pop(ctx);
                _saveMediaFromMessage(text, l);
              }
            : null,
        onEdit: canEdit && !isMedia
            ? () {
                Navigator.pop(ctx);
                _startEditingMessage(msg);
              }
            : null,
        onCopy: () {
          Navigator.pop(ctx);
          Clipboard.setData(ClipboardData(text: msg.content));
          rootScreenKey.currentState?.showSnack(l.msgCopied);
        },
        isPinned: _isMsgPinned(msg),
        onPin: () {
          Navigator.pop(ctx);
          _togglePin(msg);
        },
        onDelete: canDelete
            ? () async {
                Navigator.pop(ctx);
                final cannotDeleteMsg = l.cannotDeleteMsg;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    title: Text(l.deleteMessageTitle),
                    content: Text(l.deleteMessageContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700),
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: Text(l.delete,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (msg.serverMessageId == null) {
                    rootScreenKey.currentState?.showSnack(cannotDeleteMsg);
                    return;
                  }

                  if (msg.content.startsWith('ALBUMv1:')) {
                    await _deleteAlbumFiles(msg.content);
                  } else {
                    await _deleteMediaFile(msg.content);
                  }
                  await widget.onDeleteMessage(msg.serverMessageId!);
                }
              }
            : null,
        onReact: () {
          Navigator.pop(ctx);
          final msgKey =
              '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
          openEmojiPicker(context, msgKey, widget.myUsername,
              onAfterToggle: (emoji, wasReacted) {
            if (msg.serverMessageId != null)
              _serverTogglePrivateReaction(
                  msgKey, msg.serverMessageId!, emoji, wasReacted);
          });
        },
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        _shouldPreserveExternalFocus = false;
      });
    });
  }

  List<DesktopMenuItem>? _buildDesktopMenuItems(ChatMessage msg) {
    if (!isDesktop) return null;
    final text = msg.content;
    if (text.startsWith('[cannot-decrypt')) return null;
    final isImage = text.startsWith('IMAGEv1:');
    final isAlbum = text.startsWith('ALBUMv1:');
    final isVideo = text.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = text.startsWith('VOICEv1:');
    final isFile = text.startsWith('FILEv1:') || text.startsWith('FILE:');
    final isMedia = isVoice ||
        isImage ||
        isVideo ||
        text.toUpperCase().startsWith('FILEV1:') ||
        isAlbum ||
        isFile ||
        text.startsWith('MEDIA_PROXYv1:');
    final l = AppLocalizations.of(context);
    return [
      DesktopMenuItem(
        icon: Icons.reply_rounded,
        label: l.reply,
        onPressed: () => _startReplyingToMessage({
          'id': msg.serverMessageId,
          'localId': msg.id,
          'sender': msg.from,
          'senderDisplayName': msg.from,
          'content': getPreviewText(msg.content),
        }),
      ),
      DesktopMenuItem(
        icon: Icons.add_reaction_outlined,
        label: l.react,
        onPressed: () {
          final msgKey =
              '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
          openEmojiPicker(context, msgKey, widget.myUsername,
              onAfterToggle: (emoji, wasReacted) {
            if (msg.serverMessageId != null)
              _serverTogglePrivateReaction(
                  msgKey, msg.serverMessageId!, emoji, wasReacted);
          });
        },
      ),
      if (isImage || isAlbum || isVideo || isVoice || isFile)
        DesktopMenuItem(
          icon: Icons.save_alt_rounded,
          label: l.save,
          onPressed: () => _saveMediaFromMessage(text, l),
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
            Clipboard.setData(ClipboardData(text: msg.content));
            rootScreenKey.currentState?.showSnack(l.msgCopied);
          },
        ),
      if (msg.canEditOrDelete && !isMedia)
        DesktopMenuItem(
          icon: Icons.edit_rounded,
          label: l.edit,
          onPressed: () => _startEditingMessage(msg),
        ),
      DesktopMenuItem(
        icon: _isMsgPinned(msg) ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        label: _isMsgPinned(msg) ? l.unpin : l.pin,
        onPressed: () => _togglePin(msg),
      ),
      if (msg.outgoing)
        DesktopMenuItem(
          icon: Icons.delete_outline_rounded,
          label: l.delete,
          type: ContextMenuButtonType.delete,
          color: Colors.red.shade400,
          onPressed: () => _desktopDeleteMessage(msg),
        ),
      if (isFile)
        DesktopMenuItem(
          icon: Icons.folder_open_rounded,
          label: l.showInFileSystem,
          onPressed: () {
            String filename = '';
            try {
              if (text.startsWith('FILEv1:')) {
                final meta = jsonDecode(text.substring('FILEv1:'.length))
                    as Map<String, dynamic>;
                filename = meta['filename'] as String? ?? '';
              } else {
                filename = text.substring('FILE:'.length).trim();
              }
            } catch (_) {}
            final localPath =
                filename.isNotEmpty ? mediaFilePathRegistry[filename] : null;
            if (localPath == null) {
              rootScreenKey.currentState
                  ?.showSnack(l.fileNotLoadedOpenFirst);
              return;
            }
            revealInFileSystem(localPath);
          },
        ),
    ];
  }

  Future<void> _saveMediaFromMessage(String content, AppLocalizations l) async {
    if (kIsWeb) {
      rootScreenKey.currentState?.showSnack(l.saveNotSupportedOnWeb);
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
          rootScreenKey.currentState?.showSnack(l.imageNotLoadedYet);
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
          rootScreenKey.currentState?.showSnack(l.voiceNotLoadedYet);
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
          rootScreenKey.currentState?.showSnack(l.videoNotLoadedYet);
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
          rootScreenKey.currentState?.showSnack(l.fileNotLoadedYet);
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
          rootScreenKey.currentState?.showSnack('Saved to: $destPath');
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
        rootScreenKey.currentState?.showSnack('Saved to: $destPath');
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  Future<void> _desktopDeleteMessage(ChatMessage msg) async {
    final l = AppLocalizations.of(context);
    if (msg.serverMessageId == null) {
      rootScreenKey.currentState?.showSnack(l.cannotDeleteMsg);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: Text(l.deleteMessageTitle),
        content: Text(l.deleteMessageContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx2, true),
            child: Text(l.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (msg.content.startsWith('ALBUMv1:')) {
        await _deleteAlbumFiles(msg.content);
      } else {
        await _deleteMediaFile(msg.content);
      }
      await widget.onDeleteMessage(msg.serverMessageId!);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPinnedMessage();
    _loadPrivateReactions();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    rootScreenKey.currentState?.subscribeToPrivateReactions(
        widget.otherUsername, _onPrivateReactionUpdate);
    final randomIndex = Random().nextInt(_randomHints.length);
    _inputHint = _randomHints[randomIndex];
    _focusNode = FocusNode();
    _keyboardListenerFocusNode = FocusNode();

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

    assert(() {
      final rootUser = rootScreenKey.currentState?.currentUsername;
      debugPrint(
          '[ChatScreen.init] widget.myUsername=${widget.myUsername}, root.currentUsername=$rootUser, other=${widget.otherUsername}');
      return true;
    }());

    _scroll.addListener(_onScroll);

    // Pre-seed rendered-ids so existing messages don't all animate on open —
    // only messages added during this session (including a brand-new chat's
    // very first message) get an entry animation.
    final root = rootScreenKey.currentState;
    if (root != null) {
      final chatId = root.chatIdForUser(widget.otherUsername);
      final existingMsgs = root.chats[chatId] ?? const [];
      for (final m in existingMsgs) {
        _alreadyRenderedMessageIds.add(m.id);
      }
    }

    _loadFastChangeSetting();
    _consumePendingScrollTarget();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusNode.hasFocus && isDesktop) _requestFocus();

      // Delay read-marking until AFTER the navigation animation completes.
      // Calling it during the animation bumps chatsVersion synchronously,
      // which triggers a ChatsTab rebuild on every frame → jitter on fat accounts.
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
      if (mounted) setState(() {});
      if (!_focusNode.hasFocus && mounted) {
        if (isDesktop &&
            !recordingNotifier.value &&
            !_shouldPreserveExternalFocus &&
            !_suppressAutoRefocus &&
            ModalRoute.of(context)?.isCurrent == true) {
          _requestFocus();
        }
      }
    });

    _combinedHeaderListenable = Listenable.merge([
      typingUsersNotifier,
      wsConnectedNotifier,
      onlineUsersNotifier,
      userStatusNotifier,
      userStatusVisibilityNotifier,
    ]);
  }

  void _checkInputAnimationState() {
    final chatId = 'chat_${widget.otherUsername}';

    if (!_sessionInputAnimationsShown.contains(chatId)) {
      _inputEntryController.forward();
      _sessionInputAnimationsShown.add(chatId);
      _hasInputAnimated = true;
    } else {
      _inputEntryController.value = 1.0;
      _hasInputAnimated = true;
    }
  }

  Future<void> _loadFastChangeSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('fast_change_mode') ?? false;
      if (mounted) {
        setState(() {
          _fastChangeMode = saved;
        });
      }
    } catch (e) {
      debugPrint('[ChatScreen] Failed to load fast change setting: $e');
    }
  }

  Future<void> _saveFastChangeSetting(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fast_change_mode', value);
    } catch (e) {
      debugPrint('[ChatScreen] Failed to save fast change setting: $e');
    }
  }

  Future<void> _showUserProfileDialog(String username) async {
    await unfocusAndSettle(context);
    if (!mounted) return;

    final cached = UserCache.getSync(username);
    final dp = (cached != null) ? cached.displayName : username;
    final desc = cached?.description ?? '';

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'User profile',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 187),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final l = AppLocalizations.of(ctx);
        const btnShape = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(50)),
        );
        const btnPadding = EdgeInsets.symmetric(vertical: 13);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header tinted ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(0, 28, 16, 20),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Column(
                            children: [
                              AvatarWidget(
                                username: username,
                                tokenProvider: avatarTokenProvider,
                                avatarBaseUrl: serverBase,
                                size: 80.0,
                                editable: false,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                dp,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: '@$username'));
                                  rootScreenKey.currentState?.showSnack(
                                      AppLocalizations.of(context)
                                          .copiedUsername(username));
                                },
                                child: Text(
                                  '@$username',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    desc,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Buttons ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              FocusScope.of(context).requestFocus(_focusNode);
                            },
                            style: FilledButton.styleFrom(
                              padding: btnPadding,
                              shape: btnShape,
                            ),
                            icon: const Icon(Icons.message_rounded, size: 18),
                            label: Text(l.profileMessage),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: btnPadding,
                              shape: btnShape,
                            ),
                            child: Text(l.close),
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
    );
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
    _scrollDownVisible.value = !atBottom;
    if (SettingsManager.messagePaginationEnabled.value &&
        _hasMoreMessages &&
        !_isLoadingMore &&
        _scroll.hasClients &&
        pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    final rootState = rootScreenKey.currentState;
    if (rootState == null) return;

    final ids = [widget.myUsername, widget.otherUsername]..sort();
    final chatId = ids.join(':');
    final mainMsgs = rootState.chats[chatId] ?? [];
    final allMsgs = [...mainMsgs, ..._olderMessages];

    final oldest = allMsgs.isNotEmpty ? allMsgs.last : null;
    final oldestId = oldest?.serverMessageId;
    if (oldestId == null) {
      if (mounted)
        setState(() {
          _hasMoreMessages = false;
        });
      return;
    }

    if (mounted)
      setState(() {
        _isLoadingMore = true;
      });

    try {
      final older = await ChatLoadOptimizer()
          .loadOlderMessages(widget.myUsername, widget.otherUsername, oldestId);
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        if (older.isEmpty) {
          _hasMoreMessages = false;
        } else {
          _olderMessages.addAll(older);
        }
      });
      // Preload images for newly fetched older messages so they're ready
      // before the user scrolls to them.
      if (older.isNotEmpty)
        ChatImagePreloader.preload(older, peerUsername: widget.otherUsername);
    } catch (e) {
      debugPrint('[loadMoreMessages] $e');
      if (mounted)
        setState(() {
          _isLoadingMore = false;
        });
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUsername != widget.otherUsername) {
      _alreadyRenderedMessageIds.clear();
      _hasBuiltMessageListOnce = false;
      _cachedMessages = null;
      _cachedItems = null;
      _olderMessages.clear();
      _isLoadingMore = false;
      _hasMoreMessages = true;
      final randomIndex = Random().nextInt(_randomHints.length);
      setState(() {
        _inputHint = _randomHints[randomIndex];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(0);
        }

        _markMessagesAsRead();
      });
    }
  }

  void _markMessagesAsRead() {
    final rootState = rootScreenKey.currentState;
    if (rootState == null) return;

    final me = rootScreenKey.currentState?.currentUsername ?? widget.myUsername;
    final List<String> ids = [me, widget.otherUsername]..sort();
    final String chatId = ids.join(':');
    final msgs = rootState.chats[chatId];

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
      rootState.schedulePersistChats();
      addChatListHint(chatId);
      chatsVersion.value++;
      bumpChatMessageVersion(chatId);
    }

    unreadManager.markAsRead(chatId);
  }

  // Use instead of _requestFocus() so that canRequestFocus is
  // re-enabled first (ChatInputBar sets it to false on mobile to block
  // keyboard restoration after dialogs close).
  void _requestFocus() {
    _focusNode.canRequestFocus = true;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _selectionNotifier.dispose();
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _stopDragAutoScroll();
    _scroll.dispose();
    _scrollDownVisible.dispose();
    _bottomBarHeight.dispose();
    _focusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    _typingThrottle?.cancel();
    _inputEntryController.dispose();
    _searchController.dispose();
    _searchStats.dispose();
    _searchFocusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    rootScreenKey.currentState?.unsubscribeFromPrivateReactions();
    super.dispose();
  }

  Future<void> _loadPrivateReactions() async {
    final root = rootScreenKey.currentState;
    if (root == null || !mounted) return;
    final chatId = root.chatIdForUser(widget.otherUsername);
    final messages = root.chats[chatId] ?? [];

    // Apply cached reactions immediately (instant, no network needed)
    final cachedBatch = <String, Map<String, dynamic>>{};
    for (final msg in messages) {
      if (msg.reactions.isNotEmpty) {
        final key =
            '${msg.id}_${msg.serverMessageId}_${msg.time.millisecondsSinceEpoch}';
        cachedBatch[key] = msg.reactions.map((e, u) => MapEntry(e, u));
      }
    }
    if (cachedBatch.isNotEmpty && mounted) applyReactionBatch(cachedBatch);

    // Then refresh from server
    final ids = messages
        .where((m) => m.serverMessageId != null)
        .map((m) => m.serverMessageId!.toString())
        .toList();
    if (ids.isEmpty) return;
    final token = await AccountManager.getToken(widget.myUsername);
    if (token == null || !mounted) return;
    try {
      final resp = await http.get(
        Uri.parse('$serverBase/messages/reactions?ids=${ids.join(",")}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reactionsData =
            (data['reactions'] as Map<String, dynamic>?) ?? {};
        final batch = <String, Map<String, dynamic>>{};
        for (final msg in messages) {
          if (msg.serverMessageId == null) continue;
          final r = reactionsData[msg.serverMessageId.toString()];
          final key =
              '${msg.id}_${msg.serverMessageId}_${msg.time.millisecondsSinceEpoch}';
          if (r is Map) {
            final reactionMap = Map<String, dynamic>.from(r);
            batch[key] = reactionMap;
            // Persist into the message so it's available next time
            msg.reactions = reactionMap.map(
              (e, u) => MapEntry(
                  e,
                  (u is List)
                      ? u.map((x) => x.toString()).toList()
                      : <String>[]),
            );
          } else {
            msg.reactions = {};
          }
        }
        if (batch.isNotEmpty) applyReactionBatch(batch);
      }
    } catch (e) {
      debugPrint('[reactions.private.load] error: $e');
    }
  }

  void _onPrivateReactionUpdate(Map<String, dynamic> obj) {
    if (!mounted) return;
    final msgIdRaw = obj['message_id'];
    final msgId =
        msgIdRaw is int ? msgIdRaw : int.tryParse(msgIdRaw?.toString() ?? '');
    if (msgId == null) return;
    final reactions = (obj['reactions'] as Map<String, dynamic>?) ?? {};
    final root = rootScreenKey.currentState;
    if (root == null) return;
    final chatId = root.chatIdForUser(widget.otherUsername);
    final messages = root.chats[chatId] ?? [];
    for (final msg in messages) {
      if (msg.serverMessageId == msgId) {
        final key =
            '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
        applyReactionUpdate(key, reactions);
        // Persist into the message for next open
        msg.reactions = reactions.map(
          (e, u) => MapEntry(e,
              (u is List) ? u.map((x) => x.toString()).toList() : <String>[]),
        );
        break;
      }
    }
  }

  Future<void> _serverTogglePrivateReaction(
      String uniqueKey, int serverMsgId, String emoji, bool remove) async {
    if (!mounted) return;
    final token = await AccountManager.getToken(widget.myUsername);
    if (token == null) {
      debugPrint(
          '[reaction.private] token null for ${widget.myUsername}, skipping');
      return;
    }
    try {
      debugPrint(
          '[reaction.private] ${remove ? "DELETE" : "POST"} msgId=$serverMsgId emoji=$emoji other=${widget.otherUsername}');
      http.Response resp;
      if (remove) {
        resp = await http.delete(
          Uri.parse(
              '$serverBase/messages/$serverMsgId/reactions/${Uri.encodeComponent(emoji)}?other_username=${Uri.encodeComponent(widget.otherUsername)}'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } else {
        resp = await http.post(
          Uri.parse('$serverBase/messages/$serverMsgId/reactions'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(
              {'emoji': emoji, 'other_username': widget.otherUsername}),
        );
      }
      debugPrint(
          '[reaction.private] server responded ${resp.statusCode}: ${resp.body}');
    } catch (e) {
      debugPrint('[reaction.private] server error: $e');
    }
  }

  // ── search helpers ───────────────────────────────────────────────────────────

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
      if (mounted) _requestFocus();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
      _currentMatchIdx = 0;
    });
  }

  void _navigateSearchPrev() {
    // ↑ = older messages (higher adjustedI = toward top of chat)
    if (_cachedSearchMatches.isEmpty) return;
    setState(() {
      _currentMatchIdx = (_currentMatchIdx + 1) % _cachedSearchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _navigateSearchNext() {
    // ↓ = newer messages (lower adjustedI = toward bottom of chat)
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
      final pendingCount = _pendingUploads.length;
      final totalItems = pendingCount + (_cachedItems?.length ?? 0);
      if (totalItems == 0) return;
      final listIdx = pendingCount + matchItemIdx;
      final maxExtent = _scroll.position.maxScrollExtent;
      final target = (maxExtent * listIdx / totalItems).clamp(0.0, maxExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _onUserTyping() {
    if (!_typingSentRecently) {
      try {
        widget.onTyping();
      } catch (_) {}
      _typingSentRecently = true;
      _typingThrottle?.cancel();
      _typingThrottle = Timer(const Duration(milliseconds: 800), () {
        _typingSentRecently = false;
      });
    }

    if (!_focusNode.hasFocus &&
        !_shouldPreserveExternalFocus &&
        !recordingNotifier.value) {
      _requestFocus();
    }
  }

  Future<void> _submitMessage(String value) async {
    if (value.trim().isEmpty) return;

    final content = value.trim();

    if (_editingMessage != null) {
      final editing = _editingMessage!;
      final serverId = editing.serverMessageId;
      if (serverId != null) {
        setState(() {
          _editingMessage = null;
        });
        _textCtrl.clear();
        _requestFocus();
        await widget.onEditMessage(serverId, content);
      }
      return;
    }

    if (_isLANMode) {
      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      final int? replyId =
          _replyingToMessage != null && _replyingToMessage!['id'] != null
              ? int.tryParse(_replyingToMessage!['id'].toString())
              : null;

      final message = ChatMessage(
        id: localId,
        from: widget.myUsername,
        to: widget.otherUsername,
        content: content,
        outgoing: true,
        delivered: false,
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
        deliveryMode: DeliveryMode.lan,
      );

      final sent = await _lanManager.sendMessage(message, widget.otherUsername);
      if (!sent) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedSendLan);
        return;
      }

      final replyWithMode = _replyingToMessage != null
          ? Map<String, dynamic>.from(_replyingToMessage!)
          : <String, dynamic>{};
      replyWithMode['_deliveryMode'] = 'lan';
      await widget.onSend(content, replyWithMode);
    } else {
      await widget.onSend(content, _replyingToMessage);
    }

    _textCtrl.clear();
    _shouldPreserveExternalFocus = false;
    _requestFocus();

    setState(() {
      _replyingToMessage = null;
    });
    _scrollToBottomAfterSend();
  }

  Future<void> _showDeliveryModeDialog() async {
    final l = AppLocalizations.of(context);
    final lanEnabledMsg = l.lanModeEnabled;
    final internetEnabledMsg = l.internetModeEnabled;
    final userNotInLanMsg = l.deliveryUserNotInLan;

    if (_fastChangeMode) {
      final lanAvailable =
          _lanManager.isUserAvailableInLAN(widget.otherUsername);
      if (lanAvailable) {
        setState(() {
          _isLANMode = !_isLANMode;

          final modes = Map<String, bool>.from(lanModePerChat.value);
          modes[widget.otherUsername] = _isLANMode;
          lanModePerChat.value = modes;
        });
        if (_isLANMode) {
          rootScreenKey.currentState?.showSnack(lanEnabledMsg);
        } else {
          rootScreenKey.currentState?.showSnack(internetEnabledMsg);
        }
        return;
      } else {
        rootScreenKey.currentState?.showSnack(userNotInLanMsg);
        return;
      }
    }

    bool tempFastChange = _fastChangeMode;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l.deliveryModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language, color: Colors.blue),
                title: Text(l.deliveryInternet),
                subtitle: Text(l.deliveryInternetSubtitle),
                onTap: () => Navigator.of(ctx).pop('internet'),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.router,
                  color: _lanManager.isUserAvailableInLAN(widget.otherUsername)
                      ? Colors.green
                      : Colors.grey,
                ),
                title: Text(
                  'LAN',
                  style: TextStyle(
                    color:
                        _lanManager.isUserAvailableInLAN(widget.otherUsername)
                            ? null
                            : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  _lanManager.isUserAvailableInLAN(widget.otherUsername)
                      ? l.deliveryLanSubtitle
                      : l.deliveryUserNotInLan,
                  style: TextStyle(
                    color:
                        _lanManager.isUserAvailableInLAN(widget.otherUsername)
                            ? null
                            : Colors.grey,
                  ),
                ),
                enabled: _lanManager.isUserAvailableInLAN(widget.otherUsername),
                onTap: () => Navigator.of(ctx).pop('lan'),
              ),
              const Divider(height: 24),
              CheckboxListTile(
                title: Text(l.fastChange),
                subtitle: Text(l.fastChangeSubtitle),
                value: tempFastChange,
                onChanged: (value) {
                  setDialogState(() {
                    tempFastChange = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );

    if (tempFastChange != _fastChangeMode) {
      setState(() {
        _fastChangeMode = tempFastChange;
      });
      _saveFastChangeSetting(tempFastChange);
    }

    if (choice != null) {
      setState(() {
        _isLANMode = choice == 'lan';

        final modes = Map<String, bool>.from(lanModePerChat.value);
        modes[widget.otherUsername] = _isLANMode;
        lanModePerChat.value = modes;
      });
      if (_isLANMode) {
        rootScreenKey.currentState?.showSnack(lanEnabledMsg);
      } else {
        rootScreenKey.currentState?.showSnack(internetEnabledMsg);
      }
    }
  }

  Future<void> _openAttachmentPicker() async {
    if (kIsWeb) {
      rootScreenKey.currentState?.showSnack(
        'Attachment upload: desktop/mobile only',
      );
      return;
    }

    List<String>? paths;
    if (Platform.isAndroid || Platform.isIOS) {
      paths = await showMediaPickerSheet(context);
    } else {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: true,
        );
        paths = result?.files.map((f) => f.path).whereType<String>().toList();
      } catch (e) {
        debugPrint('[Attach] FilePicker error: $e');
        rootScreenKey.currentState?.showSnack('File picker error: $e');
      }
    }
    if (paths == null || paths.isEmpty) return;

    if (paths.length > 1) {
      await _handleDroppedFiles(paths);
      return;
    }

    final path = paths.first;
    final basename = p.basename(path);
    final ext = p.extension(basename).toLowerCase();

    String fileType;
    if (FileTypeDetector.isImage(path)) {
      fileType = 'IMAGE';
    } else if (FileTypeDetector.isVideo(path)) {
      fileType = 'VIDEO';
    } else if (FileTypeDetector.isAudio(path)) {
      fileType = 'AUDIO';
    } else if (FileTypeDetector.isDocument(path)) {
      fileType = 'DOCUMENT';
    } else if (FileTypeDetector.isCompress(path)) {
      fileType = 'COMPRESS';
    } else if (FileTypeDetector.isData(path)) {
      fileType = 'DATA';
    } else {
      fileType = 'FILE';
    }

    _showFilePreviewAndSend(path, basename, ext, fileType);
  }

  Future<void> _showMessagePreview(
      String text, Map<String, dynamic>? replyTo) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.previewMessageTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyTo != null) ...[
                    Text(
                      l.replyingTo(replyTo['senderDisplayName'] ??
                          replyTo['sender'] ??
                          '?'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      replyTo['content']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    l.previewYourMessage,
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
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.send),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      widget.onSend(text, _replyingToMessage);
      _textCtrl.clear();

      if (!_shouldPreserveExternalFocus && !recordingNotifier.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_focusNode.hasFocus) {
            _requestFocus();
          }
        });
      }

      _scrollToBottomAfterSend();
    }
  }

  void _oldSubmitMessage(String value) {}

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

  /// Called specifically after sending a message so the new bubble "slides in"
  /// instead of appearing statically. Waits one frame for the new item to be
  /// in the tree, creates a small upward offset, then animates back to 0.
  void _scrollToBottomAfterSend() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pixels = _scroll.position.pixels;
      if (pixels <= 4.0) {
        // Already at bottom — nudge up so the animate-to-0 is visible
        _scroll.jumpTo(56.0);
      }
      _scroll.animateTo(
        0.0,
        duration: const Duration(milliseconds: 310),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onLongPress(ChatMessage msg, [TapDownDetails? details]) {
    final text = msg.content;
    if (text.toUpperCase().startsWith('VOICEV1:') ||
        text.toUpperCase().startsWith('IMAGEV1:') ||
        text.toUpperCase().startsWith('VIDEOV1:') ||
        text.startsWith('[cannot-decrypt')) {
      return;
    }

    _shouldPreserveExternalFocus = true;

    RelativeRect position = RelativeRect.fromLTRB(0, 0, 0, 0);
    if (details != null) {
      final dx = details.globalPosition.dx;
      final dy = details.globalPosition.dy;
      final overlay =
          Overlay.of(context)?.context.findRenderObject() as RenderBox?;
      if (overlay != null) {
        final right = overlay.size.width - dx;
        final bottom = overlay.size.height - dy;
        position = RelativeRect.fromLTRB(dx, dy, right, bottom);
      }
    }

    showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
            value: 'copy', child: Text(AppLocalizations.of(context).copy)),
      ],
      elevation: 8,
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: text));
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).msgCopied);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        _shouldPreserveExternalFocus = false;
      });
    });
  }

  List<_ListItem> _buildMessagesWithDaySeparators(List<ChatMessage> msgs) {
    if (msgs.isEmpty) return [];

    final unreadCount = msgs.where((m) => !m.outgoing && !m.isRead).length;
    final currentHash = msgs.length.hashCode ^
        (msgs.isNotEmpty ? msgs.last.id.hashCode : 0) ^
        unreadCount.hashCode;

    if (_cachedMessages != null &&
        _cachedMessagesHash == currentHash &&
        _cachedItems != null) {
      debugPrint(
          '[ChatScreen] Using CACHED items (${_cachedItems!.length} items, hash: $currentHash)');
      return _cachedItems!;
    }

    debugPrint(
        '[ChatScreen] Building NEW items list from ${msgs.length} messages (hash changed: $_cachedMessagesHash → $currentHash)');

    final items = <_ListItem>[];
    DateTime? currentDay;
    int? firstUnreadIndex;

    for (int i = 0; i < msgs.length; i++) {
      if (!msgs[i].isRead) {
        firstUnreadIndex = i;
        break;
      }
    }

    for (int i = 0; i < msgs.length; i++) {
      final msg = msgs[i];
      final msgDate = DateTime(msg.time.year, msg.time.month, msg.time.day);

      if (currentDay == null || currentDay != msgDate) {
        items.add(_DaySeparatorItem(msgDate));
        currentDay = msgDate;
      }

      if (firstUnreadIndex != null && i == firstUnreadIndex && i > 0) {
        items.add(_UnreadMarkerItem());
      }

      items.add(_MessageItem(msg));
    }

    final result = items.reversed.toList();

    _cachedMessages = List.from(msgs);
    _cachedItems = result;
    _cachedMessagesHash = currentHash;

    return result;
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

  Widget _buildUnreadMarker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Unread messages',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = rootScreenKey.currentState?.currentUsername ?? widget.myUsername;
    final List<String> ids = [me, widget.otherUsername]..sort();
    final String chatId = ids.join(':');

    return DragDropZone(
      onFilesDropped: _handleDroppedFiles,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: isDesktop
              ? null
              : ValueListenableBuilder(
                  valueListenable: _selectionNotifier,
                  builder: (_, sel, __) => sel.active
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _exitSelectionMode,
                        )
                      : const BackButton(),
                ),
          flexibleSpace: ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementOpacity,
            builder: (_, opacity, __) {
              return ClipRect(
                child: Container(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withOpacity(opacity),
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
                          onPressed: _exitSelectionMode,
                        ),
                      Text(
                        '${sel.selected.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _showUserProfileDialog(widget.otherUsername),
                        onLongPress: () =>
                            _showUserProfileDialog(widget.otherUsername),
                        child: AvatarWidget(
                          key: ValueKey('avatar-${widget.otherUsername}'),
                          username: widget.otherUsername,
                          tokenProvider: avatarTokenProvider,
                          avatarBaseUrl: serverBase,
                          size: 40.0,
                          editable: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final userInfo =
                                UserCache.getSync(widget.otherUsername);
                            final displayName =
                                userInfo?.displayName ?? widget.otherUsername;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _showUserProfileDialog(
                                      widget.otherUsername),
                                  onLongPress: () => _showUserProfileDialog(
                                      widget.otherUsername),
                                  child: MarqueeText(
                                    text: displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                AnimatedBuilder(
                                  animation: _combinedHeaderListenable,
                                  builder: (context, child) {
                                    final typing = typingUsersNotifier.value
                                        .contains(widget.otherUsername);
                                    if (typing) {
                                      return const Text(
                                        'typing...',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orangeAccent),
                                      );
                                    }

                                    final isConnected =
                                        wsConnectedNotifier.value;
                                    if (!isConnected) {
                                      return const Text(
                                        'no connection (auto mode)',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      );
                                    }

                                    final online = onlineUsersNotifier.value
                                        .contains(widget.otherUsername);
                                    final statuses = userStatusNotifier.value;
                                    final visMap =
                                        userStatusVisibilityNotifier.value;

                                    final visibilityEntry =
                                        visMap.containsKey(widget.otherUsername)
                                            ? visMap[widget.otherUsername]
                                            : null;

                                    if (visibilityEntry == 'hide') {
                                      return const SizedBox.shrink();
                                    }

                                    final customStatus =
                                        statuses[widget.otherUsername];

                                    if (customStatus != null &&
                                        customStatus.isNotEmpty) {
                                      return Builder(
                                        builder: (ctx) {
                                          final statusColor = online
                                              ? const Color(0xFF2ECC71)
                                              : Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.9);
                                          return Text(
                                            customStatus,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor),
                                          );
                                        },
                                      );
                                    }

                                    if (visibilityEntry == 'show') {
                                      final statusText =
                                          online ? 'online' : 'offline';
                                      return Builder(
                                        builder: (ctx) {
                                          final statusColor = online
                                              ? const Color(0xFF2ECC71)
                                              : Theme.of(ctx)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.9);
                                          return Text(
                                            statusText,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor),
                                          );
                                        },
                                      );
                                    }

                                    if (online) {
                                      return Builder(
                                        builder: (ctx) {
                                          const statusColor = Color(0xFF2ECC71);
                                          return const Text(
                                            'online',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor),
                                          );
                                        },
                                      );
                                    }

                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            ValueListenableBuilder(
              valueListenable: _selectionNotifier,
              builder: (_, sel, __) => sel.active
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      if (sel.selected.values.any(_isTextMessage))
                        IconButton(
                          icon: const Icon(Icons.copy_rounded),
                          tooltip: l.copy,
                          onPressed: _copySelectedMessages,
                        ),
                      if (sel.selected.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.forward_rounded),
                          tooltip: l.forward,
                          onPressed: _forwardSelectedMessages,
                        ),
                      if (sel.selected.values.any((m) => m.outgoing))
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                          ),
                          tooltip: 'Delete',
                          onPressed: _confirmDeleteSelected,
                        ),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Search (Ctrl+F)',
                        onPressed: () {
                          if (_showSearch)
                            _closeSearch();
                          else
                            _openSearch();
                        },
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: callManager.isInCall,
                        builder: (ctx, inCall, _) => inCall
                            ? const SizedBox()
                            : IconButton(
                                icon: Icon(
                                  Icons.phone,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.8),
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: Text(AppLocalizations.of(context)
                                          .voiceCallsTitle),
                                      content: Text(AppLocalizations.of(context)
                                          .voiceCallsContent),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(false),
                                          child: Text(
                                              AppLocalizations.of(context)
                                                  .cancel),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(dCtx).pop(false);
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) =>
                                                  const SupportSheet(),
                                            );
                                          },
                                          child: Text(
                                              AppLocalizations.of(context)
                                                  .supportOnyxBtn),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dCtx).pop(true),
                                          child: Text(
                                              AppLocalizations.of(context)
                                                  .call),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    callManager
                                        .startCall(widget.otherUsername!);
                                  }
                                },
                              ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: BlocklistManager.blockedUsers,
                        builder: (_, blocked, __) {
                          final isBlocked = widget.otherUsername != null &&
                              blocked.contains(widget.otherUsername!);
                          return PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (menuCtx) => [
                              PopupMenuItem<String>(
                                value: 'gallery',
                                child: Row(
                                  children: [
                                    const Icon(Icons.photo_library_outlined, size: 18),
                                    const SizedBox(width: 10),
                                    Text(AppLocalizations.of(context).galleryMenuLabel),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: isBlocked ? 'unblock' : 'security',
                                child: Row(
                                  children: [
                                    Icon(
                                        isBlocked
                                            ? Icons.lock_open_rounded
                                            : Icons.shield_outlined,
                                        size: 18),
                                    const SizedBox(width: 10),
                                    Text(isBlocked
                                        ? AppLocalizations.of(context).unblockUserLabel
                                        : AppLocalizations.of(context).securityCheckTitle),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'gallery') {
                                final rootState = rootScreenKey.currentState;
                                final msgs = [
                                  ...(rootState?.chats[chatId] ?? const <ChatMessage>[]),
                                  ..._olderMessages,
                                ];
                                showMediaGalleryDialog(
                                  context,
                                  items: extractGalleryItemsFromChatMessages(msgs),
                                  peerUsername: widget.otherUsername,
                                );
                                return;
                              }
                              if (BlocklistManager.isBlocked(
                                  widget.otherUsername ?? '')) {
                                final other = widget.otherUsername ?? '';
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: Text(AppLocalizations.of(context)
                                        .unblockUserLabel),
                                    content: Text(AppLocalizations.of(context)
                                        .unblockUserConfirmContent(other)),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dCtx).pop(false),
                                        child: Text(AppLocalizations.of(context)
                                            .cancel),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dCtx).pop(true),
                                        child: Text(AppLocalizations.of(context)
                                            .unblockUserLabel),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                await BlocklistManager.unblock(other);
                                try {
                                  final token = await AccountManager.getToken(
                                      widget.myUsername);
                                  await http.delete(
                                    Uri.parse('$serverBase/block/$other'),
                                    headers: {'authorization': 'Bearer $token'},
                                  );
                                } catch (e) {
                                  debugPrint('[unblock] failed: $e');
                                }
                                return;
                              }
                              final recipient = widget.otherUsername;
                              final secTitle = AppLocalizations.of(context)
                                  .securityCheckTitle;
                              final secContent = AppLocalizations.of(context)
                                  .securityCheckContent(recipient);
                              final closeLabel =
                                  AppLocalizations.of(context).close;
                              String? theirPubB64;
                              String? myPubB64;
                              final token = await AccountManager.getToken(
                                  widget.myUsername);
                              try {
                                final results = await Future.wait([
                                  http.get(
                                    Uri.parse('$serverBase/pubkey/$recipient'),
                                    headers: {'authorization': 'Bearer $token'},
                                  ),
                                  http.get(
                                    Uri.parse(
                                        '$serverBase/pubkey/${widget.myUsername}'),
                                    headers: {'authorization': 'Bearer $token'},
                                  ),
                                ]);
                                if (results[0].statusCode == 200) {
                                  theirPubB64 =
                                      (jsonDecode(results[0].body))['pubkey']
                                          as String?;
                                }
                                if (results[1].statusCode == 200) {
                                  myPubB64 =
                                      (jsonDecode(results[1].body))['pubkey']
                                          as String?;
                                }
                              } catch (e) {
                                rootScreenKey.currentState?.showSnack(
                                    AppLocalizations(
                                            SettingsManager.appLocale.value)
                                        .failedToFetchPubkey);
                                return;
                              }
                              if (theirPubB64 == null) {
                                rootScreenKey.currentState?.showSnack(
                                    AppLocalizations(
                                            SettingsManager.appLocale.value)
                                        .userHasNoPubkey);
                                return;
                              }
                              if (myPubB64 == null) {
                                rootScreenKey.currentState?.showSnack(
                                    AppLocalizations(
                                            SettingsManager.appLocale.value)
                                        .userHasNoPubkey);
                                return;
                              }
                              if (!mounted) return;

                              final myUsername = widget.myUsername;
                              final otherUsername = widget.otherUsername;
                              final List<String> sortedNames = [
                                myUsername,
                                otherUsername
                              ]..sort();
                              final List<int> myPubBytes =
                                  base64Decode(myPubB64);
                              final List<int> theirPubBytes =
                                  base64Decode(theirPubB64);
                              final List<int> keyA =
                                  sortedNames[0] == myUsername
                                      ? myPubBytes
                                      : theirPubBytes;
                              final List<int> keyB =
                                  sortedNames[0] == myUsername
                                      ? theirPubBytes
                                      : myPubBytes;
                              final combined =
                                  Uint8List.fromList([...keyA, ...keyB]);
                              final hash =
                                  dart_crypto.sha256.convert(combined).bytes;
                              final indices = [
                                hash[0],
                                hash[1],
                                hash[2],
                                hash[3]
                              ];

                              const List<String> emojiList = [
                                "😀",
                                "😁",
                                "😂",
                                "🤣",
                                "😃",
                                "😄",
                                "😅",
                                "😆",
                                "😇",
                                "😈",
                                "👿",
                                "😉",
                                "😊",
                                "😋",
                                "😌",
                                "😍",
                                "🥰",
                                "😎",
                                "😏",
                                "😐",
                                "😑",
                                "😒",
                                "😓",
                                "😔",
                                "😕",
                                "🙂",
                                "🙃",
                                "😗",
                                "😙",
                                "😚",
                                "😘",
                                "🥲",
                                "😭",
                                "😢",
                                "😥",
                                "😰",
                                "😨",
                                "😱",
                                "😳",
                                "🥵",
                                "🥶",
                                "😮",
                                "😤",
                                "😠",
                                "😡",
                                "🤬",
                                "😞",
                                "😟",
                                "😣",
                                "😖",
                                "😫",
                                "😩",
                                "🥺",
                                "🤯",
                                "😬",
                                "🤔",
                                "🤭",
                                "🤫",
                                "🤥",
                                "🙄",
                                "🤢",
                                "🤮",
                                "🤧",
                                "🥴",
                                "😵",
                                "🤑",
                                "🤠",
                                "🥳",
                                "🥸",
                                "🧐",
                                "🤓",
                                "👻",
                                "💀",
                                "☠",
                                "👹",
                                "👺",
                                "🤡",
                                "👾",
                                "🎃",
                                "🎄",
                                "🎆",
                                "🎇",
                                "🧨",
                                "✨",
                                "🎉",
                                "🎊",
                                "🎋",
                                "🎍",
                                "🎎",
                                "🎏",
                                "🎐",
                                "🎑",
                                "🎀",
                                "🏆",
                                "🥇",
                                "🥈",
                                "🥉",
                                "🏅",
                                "🥊",
                                "🎯",
                                "🎳",
                                "🎮",
                                "🎰",
                                "🎲",
                                "🧩",
                                "🧸",
                                "♟",
                                "🎨",
                                "🎪",
                                "🎬",
                                "🎤",
                                "🎧",
                                "🎼",
                                "🎵",
                                "🎶",
                                "🎸",
                                "🎹",
                                "🥁",
                                "🎷",
                                "🎺",
                                "🎻",
                                "🪕",
                                "📱",
                                "💻",
                                "🖥",
                                "⌨",
                                "🖱",
                                "💾",
                                "💿",
                                "📀",
                                "📺",
                                "📻",
                                "📷",
                                "📸",
                                "📹",
                                "🎥",
                                "🔍",
                                "🔎",
                                "🔦",
                                "💡",
                                "©",
                                "®",
                                "™",
                                "🐶",
                                "🐱",
                                "🐭",
                                "🐹",
                                "🐰",
                                "🦊",
                                "🐻",
                                "🐼",
                                "🐨",
                                "🐯",
                                "🦁",
                                "🐮",
                                "🐷",
                                "🐸",
                                "🐵",
                                "🐔",
                                "🐧",
                                "🐦",
                                "🐤",
                                "🦆",
                                "🦅",
                                "🦉",
                                "🦇",
                                "🐝",
                                "🦋",
                                "🐌",
                                "🐞",
                                "🐜",
                                "🐢",
                                "🐍",
                                "🦎",
                                "🦖",
                                "🦕",
                                "🦈",
                                "🐬",
                                "🐳",
                                "🐋",
                                "🦭",
                                "🐊",
                                "🐲",
                                "🐉",
                                "🦌",
                                "🦙",
                                "🦘",
                                "🦡",
                                "🦗",
                                "🦂",
                                "🌵",
                                "🌲",
                                "🌳",
                                "🌴",
                                "🌱",
                                "🌿",
                                "☘",
                                "🍀",
                                "🍁",
                                "🍂",
                                "🍃",
                                "🌺",
                                "🌻",
                                "🌸",
                                "🌼",
                                "🌷",
                                "🌹",
                                "🥀",
                                "🌞",
                                "🌕",
                                "🌙",
                                "🌟",
                                "💫",
                                "⭐",
                                "🌠",
                                "☄",
                                "☀",
                                "⛅",
                                "☁",
                                "🌧",
                                "⛈",
                                "🌩",
                                "🌨",
                                "🌪",
                                "🌈",
                                "🌊",
                                "💧",
                                "💦",
                                "🔥",
                                "🌍",
                                "🌎",
                                "🌏",
                                "🏔",
                                "⛰",
                                "🌋",
                                "🏕",
                                "🏖",
                                "🏜",
                                "🏝",
                                "🏞",
                                "🏟",
                                "🏛",
                                "🏗",
                                "🧱",
                                "🏠",
                                "🏡",
                              ];

                              final emojis = indices
                                  .map((i) => emojiList[i % emojiList.length])
                                  .toList();

                              final dialogColorScheme =
                                  Theme.of(context).colorScheme;
                              const cardBtnShape = RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(50)),
                              );
                              showDialog(
                                context: context,
                                builder: (dCtx) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 32),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: 400),
                                      child: Material(
                                        color: dialogColorScheme.surface,
                                        borderRadius:
                                            BorderRadius.circular(28),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              20, 16, 20, 20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  const Spacer(),
                                                  GestureDetector(
                                                    onTap: () => Navigator.of(
                                                            dCtx)
                                                        .pop(),
                                                    child: Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: dialogColorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.07),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Icon(
                                                        Icons.close_rounded,
                                                        size: 18,
                                                        color: dialogColorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.55),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: dialogColorScheme
                                                      .primary
                                                      .withValues(alpha: 0.12),
                                                ),
                                                child: Icon(
                                                  Icons.shield_rounded,
                                                  size: 32,
                                                  color:
                                                      dialogColorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                secTitle,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                secContent,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: dialogColorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 18),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: dialogColorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          18),
                                                  border: Border.all(
                                                    color: dialogColorScheme
                                                        .outlineVariant
                                                        .withValues(
                                                            alpha: 0.3),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: emojis
                                                      .map((e) => Text(
                                                            e,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        40),
                                                          ))
                                                      .toList(),
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              OutlinedButton(
                                                onPressed: () =>
                                                    Navigator.of(dCtx).pop(),
                                                style: OutlinedButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          vertical: 13),
                                                  shape: cardBtnShape,
                                                ),
                                                child: Text(closeLabel),
                                              ),
                                            ],
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
                      ),
                    ]),
            ),
          ],
        ),
        body: Stack(
          children: [
            const ChatBackgroundLayer(),
            ValueListenableBuilder<int>(
              valueListenable: getChatMessageVersion(chatId),
              builder: (_, __, ___) {
                final rootState = rootScreenKey.currentState;
                if (rootState == null) return const SizedBox();
                if (!_hasBuiltMessageListOnce) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _hasBuiltMessageListOnce = true;
                  });
                }
                final mainMsgs = rootState.chats[chatId] ?? [];
                final msgs = [...mainMsgs, ..._olderMessages];
                if (msgs.isEmpty) {
                  return EmptyChatPlaceholder(
                      label: AppLocalizations.of(context).noMessagesYet);
                }

                final items = _buildMessagesWithDaySeparators(msgs);

                // Preload images for all current messages so initState finds
                // files in imageFileCache before widgets scroll into view.
                // Guarded by a list fingerprint so we don't re-walk the whole
                // list on every unrelated rebuild.
                final stampLast = msgs.isEmpty ? '' : msgs.last.id;
                if (msgs.length != _preloadStampCount ||
                    stampLast != _preloadStampLast) {
                  _preloadStampCount = msgs.length;
                  _preloadStampLast = stampLast;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ChatImagePreloader.preload(msgs,
                        peerUsername: widget.otherUsername);
                  });
                }

                // Update search matches (side-effect during build is safe here
                // because we only assign fields, no setState).
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

                if (_cachedDragHash != _cachedMessagesHash) {
                  _cachedDragHash = _cachedMessagesHash;
                  final dragMessages = items
                      .whereType<_MessageItem>()
                      .map((item) => item.message)
                      .toList(growable: false);
                  _dragSelectionOrder = dragMessages
                      .map(_selectionKeyForMessage)
                      .toList(growable: false);
                  _dragSelectionLookup = {
                    for (final msg in dragMessages) _selectionKeyForMessage(msg): msg,
                  };
                  _dragSelectionIndices = {
                    for (int idx = 0; idx < _dragSelectionOrder.length; idx++)
                      _dragSelectionOrder[idx]: idx,
                  };
                }
                if (_cachedAllImages == null || _cachedAllImagesHash != _cachedMessagesHash) {
                  _cachedAllImages = ChatImagesScope.computeFromChatMessages(msgs);
                  _cachedAllImagesHash = _cachedMessagesHash;
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
                            return Listener(
                              key: _messageListViewportKey,
                              onPointerDown: (_) {
                                if (!isDesktop) return;
                                _suppressAutoRefocus = true;
                                _focusNode.unfocus();
                              },
                              onPointerUp: (_) {
                                if (_isDragSelectingMessages) _endMessageDragSelection();
                              },
                              onPointerCancel: (_) {
                                if (_isDragSelectingMessages) _endMessageDragSelection();
                              },
                              child: ListView.builder(
                                controller: _scroll,
                                reverse: true,
                                cacheExtent: SettingsManager.chatCacheExtent.value,
                                addRepaintBoundaries: true,
                                addAutomaticKeepAlives: false,
                                padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top +
                                        kToolbarHeight +
                                        (_showSearch ? 64 : 12),
                                    bottom: 72 +
                                        MediaQuery.of(context).padding.bottom),
                                itemCount: _pendingUploads.length +
                                    items.length +
                                    (_isLoadingMore || _hasMoreMessages
                                        ? 1
                                        : 0),
                                itemBuilder: (context, i) {
                                  // Pending uploads sit at the bottom (index 0 in reversed list)
                                  if (i < _pendingUploads.length) {
                                    final task = _pendingUploads[
                                        _pendingUploads.length - 1 - i];
                                    return _buildPendingUploadWidget(task);
                                  }
                                  final adjustedI = i - _pendingUploads.length;
                                  if (adjustedI == items.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: _isLoadingMore
                                          ? const Center(
                                              child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)))
                                          : const SizedBox.shrink(),
                                    );
                                  }
                                  final item = items[adjustedI];

                                  if (item is _DaySeparatorItem) {
                                    return _buildDaySeparator(
                                        context, item.date);
                                  } else if (item is _UnreadMarkerItem) {
                                    return _buildUnreadMarker(context);
                                  } else if (item is _MessageItem) {
                                    final msg = item.message;
                                    final String uniqueKey =
                                        '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
                                    // Use stable local id for animation tracking so that
                                    // when serverMessageId arrives the key doesn't change
                                    // and trigger a second animation on the same bubble.
                                    final String animKey = msg.id;

                                    final bool isFirstAppearance =
                                        !_alreadyRenderedMessageIds
                                            .contains(animKey);
                                    if (isFirstAppearance) {
                                      _alreadyRenderedMessageIds.add(animKey);
                                    }

                                    final isIncoming = !msg.outgoing;
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

                                    final shouldShowRight = alignRight
                                        ? !swapped
                                        : (swapped ? isIncoming : msg.outgoing);

                                    final cs = Theme.of(context).colorScheme;

                                    final msgBubble = MessageBubble(
                                      key: ValueKey<String>(
                                          'mb_inner_$uniqueKey'),
                                      text: msg.content,
                                      outgoing: msg.outgoing,
                                      rawPreview: msg.rawEnvelopePreview,
                                      serverMessageId: msg.serverMessageId,
                                      time: msg.time,
                                      onRequestResend: (id) =>
                                          widget.onRequestResend(id),
                                      desktopMenuItems:
                                          _buildDesktopMenuItems(msg),
                                      peerUsername: widget.otherUsername,
                                      chatMessage: msg,
                                      replyToId: msg.replyToId,
                                      replyToUsername: msg.replyToSender,
                                      replyToContent: msg.replyToContent,
                                      onReplyTap: msg.replyToId != null
                                          ? () => _scrollToMessageById(
                                              msg.replyToId)
                                          : null,
                                      highlighted:
                                          (msg.serverMessageId != null &&
                                                  _replyingToMessage != null &&
                                                  _replyingToMessage!['id']
                                                          ?.toString() ==
                                                      msg.serverMessageId
                                                          ?.toString()) ||
                                              (msg.serverMessageId == null &&
                                                  _replyingToMessage != null &&
                                                  _replyingToMessage!['localId']
                                                          ?.toString() ==
                                                      msg.id.toString()),
                                      onRightClick: isDesktop
                                          ? (offset) {
                                              debugPrint('[RightClickMenu] chat_screen onRightClick invoked, msgId=${msg.id}');
                                              final items =
                                                  _buildDesktopMenuItems(msg);
                                              debugPrint('[RightClickMenu] chat_screen items=${items?.length}');
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
                                      child: RepaintBoundary(child: msgBubble),
                                    );

                                    return ValueListenableBuilder<
                                        ({
                                          bool active,
                                          Map<String, ChatMessage> selected
                                        })>(
                                      valueListenable: _selectionNotifier,
                                      child: expensiveChild,
                                      builder: (_, sel, bubbleChild) {
                                        final isSelected =
                                            sel.selected.containsKey(uniqueKey);
                                        final checkmark = AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          margin: const EdgeInsets.only(
                                              right: 8),
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? cs.primary
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? cs.primary
                                                  : cs.onSurface
                                                      .withValues(alpha: 0.35),
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? Icon(Icons.check,
                                                  size: 14, color: cs.onPrimary)
                                              : null,
                                        );
                                        return KeyedSubtree(
                                          key: _messageItemKey(uniqueKey),
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
                                                    _startMessageDragSelection(
                                                        msg, uniqueKey);
                                                instance.onLongPressMoveUpdate =
                                                    (details) =>
                                                        _updateMessageDragSelection(
                                                            details.globalPosition);
                                                instance.onLongPressEnd = (_) =>
                                                    _endMessageDragSelection();
                                              },
                                            ),
                                          },
                                          child: GestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onTap: sel.active
                                                ? () => _toggleMessageSelection(
                                                    msg, uniqueKey)
                                                : null,
                                            onDoubleTap: sel.active
                                                ? null
                                                : () => _enterSelectionMode(
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
                                              curve: Curves.easeOut,
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
                                                mainAxisAlignment:
                                                    shouldShowRight
                                                        ? MainAxisAlignment.end
                                                        : MainAxisAlignment
                                                            .start,
                                                children: [
                                                  if (sel.active) checkmark,
                                                  Flexible(
                                                    child: SwipeableMessageWrapper(
                                                      disabled: sel.active,
                                                      onSwipeRight: () =>
                                                          _showMessageMenu(msg),
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
                                                      child: GestureDetector(
                                                      // Desktop right-click is handled by MessageBubble's
                                                      // own onRightClick (floating menu). An onSecondaryTap
                                                      // here too would also pop the mobile bottom-sheet menu
                                                      // for the same click.
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            shouldShowRight
                                                                ? CrossAxisAlignment
                                                                    .end
                                                                : CrossAxisAlignment
                                                                    .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          AbsorbPointer(
                                                            absorbing: sel.active,
                                                            child: bubbleChild!,
                                                          ),
                                                          MessageReactionBar(
                                                            reactions:
                                                                reactionsFor(
                                                                    uniqueKey),
                                                            myUsername: widget
                                                                .myUsername,
                                                            outgoing:
                                                                msg.outgoing,
                                                            onToggle: (emoji) {
                                                              final wasReacted =
                                                                  hasReaction(
                                                                      uniqueKey,
                                                                      emoji,
                                                                      widget
                                                                          .myUsername);
                                                              toggleReaction(
                                                                  uniqueKey,
                                                                  emoji,
                                                                  widget
                                                                      .myUsername);
                                                              if (msg.serverMessageId !=
                                                                  null)
                                                                _serverTogglePrivateReaction(
                                                                    uniqueKey,
                                                                    msg.serverMessageId!,
                                                                    emoji,
                                                                    wasReacted);
                                                            },
                                                            onAddReaction: (ctx) =>
                                                                openEmojiPicker(
                                                                    ctx,
                                                                    uniqueKey,
                                                                    widget
                                                                        .myUsername,
                                                                    onAfterToggle:
                                                                        (emoji,
                                                                            wasReacted) {
                                                              if (msg.serverMessageId !=
                                                                  null)
                                                                _serverTogglePrivateReaction(
                                                                    uniqueKey,
                                                                    msg.serverMessageId!,
                                                                    emoji,
                                                                    wasReacted);
                                                            }),
                                                          ),
                                                        ],
                                                      ),
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
                                  }

                                  return const SizedBox.shrink();
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
                child: _buildPinnedBanner(context),
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
                    opacity: CurvedAnimation(
                        parent: animation, curve: Curves.easeOut),
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
            ValueListenableBuilder<bool>(
              valueListenable: _scrollDownVisible,
              builder: (_, visible, child) => AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !visible,
                  child: child,
                ),
              ),
              child: ValueListenableBuilder<double>(
                valueListenable: _bottomBarHeight,
                builder: (_, barHeight, __) => ValueListenableBuilder<ScrollDownButtonPosition>(
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
                            bottom: barHeight + 12.0 + MediaQuery.of(context).padding.bottom + 16,
                            left: position == ScrollDownButtonPosition.left ? 16 : 0,
                            right: position == ScrollDownButtonPosition.right ? 16 : 0,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Stack(
                              children: [
                                ValueListenableBuilder<double>(
                                  valueListenable: SettingsManager.elementBrightness,
                                  builder: (_, brightness, ___) {
                                    final baseColor = SettingsManager.getElementColor(
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      brightness,
                                    );
                                    return IconButton(
                                      splashRadius: btnSize / 2 + 4,
                                      padding: EdgeInsets.zero,
                                      icon: Container(
                                        width: btnSize,
                                        height: btnSize,
                                        decoration: BoxDecoration(
                                          color: baseColor.withValues(alpha: 0.5),
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
                                ListenableBuilder(
                                  listenable: unreadManager,
                                  builder: (context, _) {
                                    final me =
                                        rootScreenKey.currentState?.currentUsername ??
                                            widget.myUsername;
                                    final List<String> ids = [me, widget.otherUsername]
                                      ..sort();
                                    final String chatId = ids.join(':');
                                    final unreadCount =
                                        unreadManager.getUnreadCount(chatId);
                                    if (unreadCount == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          unreadCount.toString(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
                              child: _editingMessage != null
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
                                        final colorScheme =
                                            Theme.of(context).colorScheme;
                                        return Container(
                                          constraints:
                                              BoxConstraints(maxWidth: width),
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: baseColor.withValues(
                                                alpha: opacity),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_rounded,
                                                  size: 16,
                                                  color: colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Editing',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      getPreviewText(
                                                          _editingMessage!
                                                              .content),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.6),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close,
                                                    size: 18),
                                                onPressed: _cancelEditing,
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
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: baseColor.withValues(
                                                alpha: opacity),
                                            borderRadius:
                                                BorderRadius.circular(16),
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
                                                      CrossAxisAlignment.start,
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
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.7),
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
                            AnimatedBuilder(
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
                                  final baseColor =
                                      SettingsManager.getElementColor(
                                    Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    brightness,
                                  );
                                  final borderColor = Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.15);
                                  // Liquid glass на Android, iOS и macOS; на Windows/Linux — стандартный рендер.
                                  final glassAllowed =
                                      !Platform.isWindows && !Platform.isLinux;
                                  final useGlass = glassAllowed &&
                                      SettingsManager.liquidGlassOnInput.value;
                                  final bar = ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: width),
                                    child: ChatInputBar(
                                      controller: _textCtrl,
                                      textFocusNode: _focusNode,
                                      recordingListenable: recordingNotifier,
                                      onCancelRecording: () {
                                        rootScreenKey.currentState
                                            ?.cancelRecording();
                                      },
                                      onMicPressed: (isRecording) {
                                        if (isRecording) {
                                          rootScreenKey.currentState
                                              ?.stopRecordingAndUpload(
                                            widget.otherUsername,
                                            _replyingToMessage,
                                            (task) {
                                              task.onComplete = (_) async {
                                                if (mounted) {
                                                  setState(() =>
                                                      _pendingUploads.remove(task));
                                                }
                                              };
                                              if (mounted) {
                                                setState(() =>
                                                    _pendingUploads.add(task));
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
                                      onAttachPressed: _openAttachmentPicker,
                                      onSendPressed: () =>
                                          _submitMessage(_textCtrl.text),
                                      onSendLongPress: _showDeliveryModeDialog,
                                      onPaste: _handlePasteFromClipboard,
                                      onChanged: (_) => _onUserTyping(),
                                      hintText: AppLocalizations.of(context)
                                          .localizeHint(_inputHint),
                                      backgroundColor: useGlass ? Colors.white : baseColor,
                                      opacity: useGlass ? 0.0 : opacity,
                                      borderColor: useGlass ? Colors.transparent : borderColor,
                                      glassMode: useGlass,
                                      sendIcon: _isLANMode
                                          ? Icons.router
                                          : Icons.send,
                                      sendColor: _isLANMode
                                          ? Colors.green
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
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
                                                bytes = await _clipboardChannel
                                                    .invokeMethod<Uint8List>(
                                                  'readContentUri',
                                                  {'uri': data.uri},
                                                );
                                              } catch (_) {}
                                            }
                                            if (bytes != null &&
                                                bytes.isNotEmpty &&
                                                mounted) {
                                              final ext = data.mimeType
                                                      .contains('/')
                                                  ? data.mimeType
                                                      .split('/')
                                                      .last
                                                  : 'png';
                                              final tempDir =
                                                  await getTemporaryDirectory();
                                              final tempFile = File(
                                                '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.$ext',
                                              );
                                              await tempFile.writeAsBytes(bytes);
                                              _handleDroppedFiles(
                                                  [tempFile.path]);
                                            }
                                          } catch (e) {
                                            debugPrint(
                                              '[ContentInsert] Error: $e',
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                  if (!useGlass) return bar;
                                  final quality = SettingsManager.liquidGlassInputQuality.value;
                                  final blur           = SettingsManager.liquidGlassInputBlur.value;
                                  final tint           = SettingsManager.liquidGlassInputTint.value;
                                  final saturation     = SettingsManager.liquidGlassInputSaturation.value;
                                  final chromatic      = SettingsManager.liquidGlassInputChromatic.value;
                                  final refractive     = SettingsManager.liquidGlassInputRefractive.value;
                                  final lightIntensity = SettingsManager.liquidGlassInputLightIntensity.value;
                                  final thickness      = SettingsManager.liquidGlassInputThickness.value;
                                  final glassQuality = switch (quality) {
                                    LiquidGlassQuality.fast    => GlassQuality.standard,
                                    LiquidGlassQuality.medium  => GlassQuality.minimal,
                                    LiquidGlassQuality.quality => GlassQuality.premium,
                                  };
                                  final isDark = Theme.of(context).brightness == Brightness.dark;
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
                                    lightAngle: 0.75 * math.pi,
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
          ],
        ),
      ),
    );
  }

  Future<void> _handleDroppedFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    // Single file — preserve dialog/confirm behavior
    if (filePaths.length == 1) {
      final filePath = filePaths.first;
      final file = File(filePath);
      if (!await file.exists()) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }
      final basename = p.basename(filePath);
      final ext = p.extension(basename).toLowerCase();
      if (FileTypeDetector.isImage(filePath)) {
        _showFilePreviewAndSend(filePath, basename, ext, 'IMAGE');
      } else if (FileTypeDetector.isVideo(filePath)) {
        _showFilePreviewAndSend(filePath, basename, ext, 'VIDEO');
      } else if (FileTypeDetector.isAudio(filePath)) {
        _showFilePreviewAndSend(filePath, basename, ext, 'AUDIO');
      } else if (FileTypeDetector.isDocument(filePath)) {
        _showFilePreviewAndSend(filePath, basename, ext, 'DOCUMENT');
      } else if (FileTypeDetector.isCompress(filePath)) {
        _showFilePreviewAndSend(filePath, basename, ext, 'ARCHIVE');
      } else if (FileTypeDetector.isData(filePath)) {
        _showFilePreviewAndSend(filePath, basename, ext, 'DATA');
      } else {
        _showFilePreviewAndSend(filePath, basename, ext, 'FILE');
      }
      return;
    }

    // Multiple files — filter existing, then process all in order
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

    // Batch consecutive images (≤10 per album message), send all others individually.
    // Each album batch shows its own confirmation dialog (one dialog per 10 images).
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
        await _sendAlbum(batch); // shows album dialog per batch if setting enabled
      } else {
        if (!mounted) return;
        final basename = p.basename(fp);
        final ext = p.extension(basename).toLowerCase();
        final fileType = FileTypeDetector.isVideo(fp)
            ? 'VIDEO'
            : FileTypeDetector.isAudio(fp)
                ? 'AUDIO'
                : FileTypeDetector.isDocument(fp)
                    ? 'DOCUMENT'
                    : FileTypeDetector.isCompress(fp)
                        ? 'ARCHIVE'
                        : FileTypeDetector.isData(fp)
                            ? 'DATA'
                            : 'FILE';
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
        if (proceed) await _sendFile(fp, basename, ext, fileType);
        i++;
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
      } catch (_) {}
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
      } catch (_) {}
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
          final filename = p.basename(filePath);
          final ext = filename.contains('.')
              ? '.${filename.split('.').last.toLowerCase()}'
              : '';
          String fileType;
          if (FileTypeDetector.isImage(filePath)) {
            fileType = 'IMAGE';
          } else if (FileTypeDetector.isVideo(filePath)) {
            fileType = 'VIDEO';
          } else if (FileTypeDetector.isAudio(filePath)) {
            fileType = 'AUDIO';
          } else if (FileTypeDetector.isDocument(filePath)) {
            fileType = 'DOCUMENT';
          } else if (FileTypeDetector.isCompress(filePath)) {
            fileType = 'COMPRESS';
          } else if (FileTypeDetector.isData(filePath)) {
            fileType = 'DATA';
          } else {
            fileType = 'FILE';
          }
          debugPrint('[clipboard] File URI pasted: $filePath');
          if (!mounted) return;
          _showFilePreviewAndSend(filePath, filename, ext, fileType);
          return;
        }
      }

      debugPrint('[clipboard] No supported format found in clipboard');
    } catch (e, stackTrace) {
      debugPrint('[clipboard] Error pasting from clipboard: $e');
      debugPrint('[clipboard] Stack trace: $stackTrace');
    }
  }

  void _showFilePreviewAndSend(
    String filePath,
    String basename,
    String ext,
    String fileType,
  ) {
    if (SettingsManager.confirmFileUpload.value) {
      showDialog(
        context: context,
        builder: (_) => FilePreviewDialog(
          filePath: filePath,
          onSend: () => _sendFile(filePath, basename, ext, fileType),
          onCancel: () {
            rootScreenKey.currentState?.showSnack(
                AppLocalizations(SettingsManager.appLocale.value)
                    .fileCancelled);
          },
          onPasteExtra: fileType == 'IMAGE' ? _pasteImageForAlbum : null,
          onSendAlbum: fileType == 'IMAGE'
              ? (paths) => _sendAlbum(paths, skipConfirm: true)
              : null,
        ),
      );
    } else {
      _sendFile(filePath, basename, ext, fileType);
    }
  }

  /// Reads an image from the clipboard and returns its temp file path, or null.
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

  Future<String?> _presignUpload({
    required String token,
    required String type,
    required String ext,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final presignResp = await http.post(
      Uri.parse('$serverBase/media/presign/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'type': type,
        'ext': ext,
        'size': bytes.length,
        'contentType': contentType
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
      return null;
    }
    if (presignResp.statusCode != 200) {
      debugPrint('[presignUpload] step1 failed: ${presignResp.statusCode}');
      return null;
    }
    final presignData = jsonDecode(presignResp.body) as Map<String, dynamic>;
    final presignedUrl = presignData['presignedUrl'] as String;
    final filename = presignData['filename'] as String;

    final client = http.Client();
    try {
      final putRequest = http.Request('PUT', Uri.parse(presignedUrl));
      putRequest.headers['Content-Type'] = contentType;
      putRequest.bodyBytes = bytes;
      final putStreamed = await client.send(putRequest);
      if (putStreamed.statusCode != 200) {
        debugPrint('[presignUpload] S3 PUT failed: ${putStreamed.statusCode}');
        return null;
      }
    } finally {
      client.close();
    }

    final confirmResp = await http.post(
      Uri.parse('$serverBase/media/presign/confirm'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'type': type,
        'filename': filename,
        'to': widget.otherUsername,
        'no_notify': true
      }),
    );
    if (confirmResp.statusCode != 200) {
      debugPrint('[presignUpload] confirm failed: ${confirmResp.statusCode}');
      if (confirmResp.statusCode == 413) {
        dynamic body;
        try {
          body = jsonDecode(confirmResp.body);
        } catch (_) {}
        rootScreenKey.currentState?.showSnack(
          body is Map
              ? (body['detail'] ?? 'Storage quota exceeded')
              : 'Storage quota exceeded',
        );
      }
      return null;
    }
    return filename;
  }

  // ── Upload with streaming progress, pause/cancel/resume support ────────────

  Future<String?> _presignUploadWithProgress({
    required String token,
    required String presignType,
    required String ext,
    required String contentType,
    required Uint8List bytes,
    required UploadTask task,
  }) async {
    // Step 1: Get presigned URL
    final presignResp = await http.post(
      Uri.parse('$serverBase/media/presign/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'type': presignType,
        'ext': ext,
        'size': bytes.length,
        'contentType': contentType
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
      task.status = UploadStatus.failed;
      if (mounted) setState(() {});
      return null;
    }
    if (presignResp.statusCode != 200) {
      debugPrint('[presignUpload] presign failed: ${presignResp.statusCode}');
      task.status = UploadStatus.failed;
      if (mounted) setState(() {});
      return null;
    }
    final presignData = jsonDecode(presignResp.body) as Map<String, dynamic>;
    final presignedUrl = presignData['presignedUrl'] as String;
    final filename = presignData['filename'] as String;

    // Step 2: Stream upload with chunk-level progress tracking
    final client = http.Client();
    task.activeClient = client;
    try {
      final request = http.StreamedRequest('PUT', Uri.parse(presignedUrl));
      request.headers['Content-Type'] = contentType;
      request.contentLength = bytes.length;

      final responseFuture = client.send(request);

      const chunkSize = 65536; // 64 KB
      int offset = 0;
      while (offset < bytes.length) {
        if (task.status == UploadStatus.paused) {
          await request.sink.close();
          return null;
        }
        final end = (offset + chunkSize).clamp(0, bytes.length);
        request.sink.add(bytes.sublist(offset, end));
        offset = end;
        task.progress = offset / bytes.length;
        if (mounted) setState(() {});
        await Future.delayed(Duration.zero); // yield to UI
      }
      await request.sink.close();

      final response = await responseFuture;
      await response.stream.drain();
      if (response.statusCode != 200) {
        debugPrint('[presignUpload] S3 PUT failed: ${response.statusCode}');
        task.status = UploadStatus.failed;
        if (mounted) setState(() {});
        return null;
      }
    } catch (e) {
      debugPrint('[presignUpload] upload error: $e');
      if (task.status != UploadStatus.paused) {
        task.status = UploadStatus.failed;
        if (mounted) setState(() {});
      }
      return null;
    } finally {
      client.close();
      task.activeClient = null;
    }

    // Step 3: Confirm upload
    final confirmResp = await http.post(
      Uri.parse('$serverBase/media/presign/confirm'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'type': presignType,
        'filename': filename,
        'to': widget.otherUsername,
        'no_notify': true
      }),
    );
    if (confirmResp.statusCode != 200) {
      debugPrint('[presignUpload] confirm failed: ${confirmResp.statusCode}');
      if (confirmResp.statusCode == 413) {
        dynamic body;
        try {
          body = jsonDecode(confirmResp.body);
        } catch (_) {}
        rootScreenKey.currentState?.showSnack(
          body is Map
              ? (body['detail'] ?? 'Storage quota exceeded')
              : 'Storage quota exceeded',
        );
      }
      task.status = UploadStatus.failed;
      if (mounted) setState(() {});
      return null;
    }

    task.status = UploadStatus.done;
    task.progress = 1.0;
    if (mounted) setState(() {});
    return filename;
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
      showProgress: true, // presign S3 upload — real byte-level progress
      onCancel: () => _cancelUpload(task),
    );
  }

  Future<void> _sendFile(
    String filePath,
    String basename,
    String ext,
    String fileType,
  ) async {
    if (_isLANMode) {
      return await _sendFileLAN(filePath, basename, fileType);
    }

    if (fileType == 'IMAGE') {
      await _sendImage(filePath, basename, ext);
    } else if (fileType == 'VIDEO') {
      await _sendVideo(filePath, basename, ext);
    } else {
      // Generic file / audio upload with progress tracking
      try {
        final token = await AccountManager.getToken(
            rootScreenKey.currentState?.currentUsername ?? '');
        if (token == null) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
          return;
        }

        final localFile = File(filePath);
        if (!await localFile.exists()) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
          return;
        }
        if (await localFile.length() == 0) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).fileEmpty);
          return;
        }

        final plainBytes = await localFile.readAsBytes();
        final root = rootScreenKey.currentState;
        if (root == null) {
          rootScreenKey.currentState?.showSnack('RootScreen not ready');
          return;
        }

        final uploadType = (fileType == 'AUDIO') ? 'voice' : 'file';
        final fileExt = p.extension(basename).toLowerCase();

        // Show pending upload card immediately
        final task = UploadTask(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          type: uploadType,
          localPath: filePath,
          basename: basename,
        );
        task.presignType = 'file';
        task.presignExt = fileExt;
        task.presignContentType = 'application/octet-stream';
        if (mounted)
          setState(() {
            _pendingUploads.add(task);
          });

        final (encryptedBytes, fileMediaKeyB64) =
            await root.encryptMediaRandom(plainBytes, kind: 'file');
        task.encryptedBytes = encryptedBytes;
        task.mediaKey = fileMediaKeyB64;
        task.status = UploadStatus.uploading;
        if (mounted) setState(() {});

        final replyTo = _replyingToMessage;
        if (mounted)
          setState(() {
            _replyingToMessage = null;
          });

        task.onComplete = (filename) async {
          final content = 'FILEv1:${jsonEncode({
                'filename': filename,
                'owner': widget.myUsername,
                'orig': basename,
                'key': fileMediaKeyB64
              })}';
          await widget.onSend(content, replyTo);
          if (mounted)
            setState(() {
              _pendingUploads.remove(task);
            });
          if (mounted)
            rootScreenKey.currentState?.showSnack(
                AppLocalizations(SettingsManager.appLocale.value).fileSent);
        };

        final filename = await _presignUploadWithProgress(
          token: token,
          presignType: 'file',
          ext: fileExt,
          contentType: 'application/octet-stream',
          bytes: encryptedBytes,
          task: task,
        );
        if (filename == null) {
          if (task.status == UploadStatus.failed) {
            if (mounted)
              setState(() {
                _pendingUploads.remove(task);
              });
            rootScreenKey.currentState?.showSnack('Upload failed');
          }
          return;
        }
        await task.onComplete!(filename);
      } catch (e) {
        if (mounted) rootScreenKey.currentState?.showSnack('Error: $e');
      }
    }
  }

  Future<void> _sendFileLAN(
      String filePath, String basename, String fileType) async {
    try {
      debugPrint(
          '[LAN SEND] Starting - filePath: "$filePath", basename: "$basename", fileType: $fileType');

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[LAN SEND] ERROR: Source file not found');
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }

      final fileBytes = await file.readAsBytes();
      debugPrint('[LAN SEND] Read ${fileBytes.length} bytes from source');

      final appDocuments = await getOnyxDocumentsDirectory();
      final lanMediaDir = Directory('${appDocuments.path}/lan_media');
      if (!await lanMediaDir.exists()) {
        await lanMediaDir.create(recursive: true);
        debugPrint('[LAN SEND] Created lan_media directory');
      }

      final localLanFile = File('${lanMediaDir.path}/$basename');
      await localLanFile.writeAsBytes(fileBytes, flush: true);
      debugPrint(
          '[LAN SEND] Saved locally to: ${localLanFile.path} (exists: ${await localLanFile.exists()})');

      String mediaType;
      if (fileType == 'IMAGE') {
        mediaType = 'image';
      } else if (fileType == 'VIDEO') {
        mediaType = 'video';
      } else if (fileType == 'AUDIO') {
        mediaType = 'voice';
      } else {
        mediaType = 'file';
      }

      final sent = await _lanManager.sendMediaMessage(
        from: widget.myUsername,
        to: widget.otherUsername,
        mediaType: mediaType,
        mediaData: Uint8List.fromList(fileBytes),
        filename: basename,
        replyTo: _replyingToMessage,
      );

      if (!sent) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedSendLan);
        return;
      }

      String content;
      if (mediaType == 'image') {
        content = 'IMAGEv1:${jsonEncode({'url': 'lan://$basename'})}';
      } else if (mediaType == 'video') {
        content = 'VIDEOv1:${jsonEncode({'url': 'lan://$basename'})}';
      } else if (mediaType == 'voice') {
        final duration = fileBytes.length ~/ (16000 * 2);
        final format = basename.split('.').last;
        content = 'VOICEv1:${jsonEncode({
              'url': 'lan://$basename',
              'duration': duration,
              'format': format
            })}';
      } else {
        content = 'FILEv1:${jsonEncode({'filename': 'lan://$basename'})}';
      }

      await widget.onSend(content, {
        ..._replyingToMessage ?? {},
        '_deliveryMode': 'lan',
      });

      if (mounted) {
        setState(() {
          _replyingToMessage = null;
        });
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).fileSentLan);
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack('Error sending via LAN: $e');
      }
    }
  }

  Future<void> _sendImage(String filePath, String basename, String ext) async {
    MediaType contentType;
    if (ext == '.png')
      contentType = MediaType('image', 'png');
    else if (ext == '.webp')
      contentType = MediaType('image', 'webp');
    else if (ext == '.gif')
      contentType = MediaType('image', 'gif');
    else
      contentType = MediaType('image', 'jpeg');

    try {
      final token = await AccountManager.getToken(
          rootScreenKey.currentState?.currentUsername ?? '');
      if (token == null) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
        return;
      }

      final ok = await (rootScreenKey.currentState
              ?.checkQuotaAndPrompt(limitMb: 10.0, includeImageCache: false) ??
          Future.value(true));
      if (!ok) return;

      final localFile = File(filePath);
      if (!await localFile.exists()) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }
      if (await localFile.length() == 0) {
        rootScreenKey.currentState?.showSnack('File is empty');
        return;
      }

      final plainBytes = await localFile.readAsBytes();
      final root = rootScreenKey.currentState;
      if (root == null) {
        rootScreenKey.currentState?.showSnack('RootScreen not ready');
        return;
      }

      // Compute a BlurHash so the recipient sees a blurred preview before the
      // full image finishes downloading (embedded in the IMAGEv1 metadata).
      final blur = await computeBlurHash(plainBytes);

      // Create pending upload task — shows blurred preview immediately
      final task = UploadTask(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: 'image',
        localPath: filePath,
        basename: basename,
      );
      task.previewBytes = plainBytes;
      task.presignType = 'image';
      task.presignExt = ext;
      task.presignContentType = '${contentType.type}/${contentType.subtype}';
      if (mounted)
        setState(() {
          _pendingUploads.add(task);
        });

      final (encryptedBytes, imageMediaKeyB64) =
          await root.encryptMediaRandom(plainBytes, kind: 'image');
      task.encryptedBytes = encryptedBytes;
      task.mediaKey = imageMediaKeyB64;
      task.status = UploadStatus.uploading;
      if (mounted) setState(() {});

      final replyTo = _replyingToMessage;
      if (mounted)
        setState(() {
          _replyingToMessage = null;
        });

      task.onComplete = (filename) async {
        try {
          final appSupport = await getOnyxSupportDirectory();
          final cacheDir = Directory('${appSupport.path}/image_cache');
          await cacheDir.create(recursive: true);
          if (await localFile.exists())
            await localFile.copy('${cacheDir.path}/$filename');
        } catch (e) {
          debugPrint('[chat_screen] Failed to copy image to cache: $e');
        }
        final meta = jsonEncode({
          'filename': filename,
          'owner': widget.myUsername,
          'orig': basename,
          'key': imageMediaKeyB64,
          if (blur != null) 'blur': blur.hash,
          if (blur != null) 'ar': blur.aspectRatio,
        });
        await widget.onSend('IMAGEv1:$meta', replyTo);
        if (mounted)
          setState(() {
            _pendingUploads.remove(task);
          });
        if (mounted)
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).imageSent);
      };

      final filename = await _presignUploadWithProgress(
        token: token,
        presignType: 'image',
        ext: ext,
        contentType: '${contentType.type}/${contentType.subtype}',
        bytes: encryptedBytes,
        task: task,
      );
      if (filename == null) {
        if (task.status == UploadStatus.failed) {
          if (mounted)
            setState(() {
              _pendingUploads.remove(task);
            });
          rootScreenKey.currentState?.showSnack('Upload failed');
        }
        // If paused, task stays in list so user can resume
        return;
      }
      await task.onComplete!(filename);
    } catch (e) {
      if (mounted) rootScreenKey.currentState?.showSnack('Error: $e');
    }
  }

  Future<void> _deleteAlbumFiles(String content) async {
    try {
      final items = (jsonDecode(content.substring('ALBUMv1:'.length)) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final filenames = items
          .map((m) => m['filename'] as String? ?? '')
          .where((f) =>
              f.isNotEmpty && !f.startsWith('http') && !f.startsWith('lan://'))
          .toList();
      if (filenames.isEmpty) return;

      final token = await AccountManager.getToken(
          rootScreenKey.currentState?.currentUsername ?? '');
      if (token == null) return;

      await http.delete(
        Uri.parse('$serverBase/image/batch'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({'filenames': filenames}),
      );
    } catch (e) {
      debugPrint('[album delete] $e');
    }
  }

  Future<void> _deleteMediaFile(String content) async {
    const typeMap = {
      'VOICEv1:': 'voice',
      'IMAGEv1:': 'image',
      'VIDEOv1:': 'video',
      'FILEv1:': 'file',
      'AUDIOv1:': 'file',
    };
    String? type;
    String? filename;
    for (final entry in typeMap.entries) {
      if (content.startsWith(entry.key)) {
        type = entry.value;
        try {
          final meta = jsonDecode(content.substring(entry.key.length))
              as Map<String, dynamic>;
          filename = meta['filename'] as String?;
        } catch (_) {}
        break;
      }
    }
    if (type == null || filename == null || filename.isEmpty) return;
    if (filename.startsWith('http') || filename.startsWith('lan://')) return;

    try {
      final token = await AccountManager.getToken(
          rootScreenKey.currentState?.currentUsername ?? '');
      if (token == null) return;

      await http.delete(
        Uri.parse('$serverBase/media/single'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({'filename': filename, 'type': type}),
      );
    } catch (e) {
      debugPrint('[media delete single] $e');
    }
  }

  Future<void> _sendAlbum(List<String> filePaths,
      {bool skipConfirm = false}) async {
    if (filePaths.isEmpty) return;

    if (!skipConfirm) {
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

    try {
      final token = await AccountManager.getToken(
          rootScreenKey.currentState?.currentUsername ?? '');
      if (token == null) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
        return;
      }

      final ok = await (rootScreenKey.currentState?.checkQuotaAndPrompt(
            limitMb: 10.0 * filePaths.length,
            includeImageCache: false,
          ) ??
          Future.value(true));
      if (!ok) return;

      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value)
              .uploadingImages(filePaths.length));

      final appSupport = await getOnyxSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/image_cache');
      await cacheDir.create(recursive: true);

      final albumItems = <Map<String, dynamic>>[];

      for (final filePath in filePaths) {
        final localFile = File(filePath);
        if (!await localFile.exists()) continue;

        final basename = p.basename(filePath);
        final ext = p.extension(basename).toLowerCase();

        final MediaType contentType;
        if (ext == '.png') {
          contentType = MediaType('image', 'png');
        } else if (ext == '.webp') {
          contentType = MediaType('image', 'webp');
        } else if (ext == '.gif') {
          contentType = MediaType('image', 'gif');
        } else {
          contentType = MediaType('image', 'jpeg');
        }

        final plainBytes = await localFile.readAsBytes();
        final root = rootScreenKey.currentState;
        if (root == null) return;

        final blur = await computeBlurHash(plainBytes);

        final (encryptedBytes, albumItemKeyB64) =
            await root.encryptMediaRandom(plainBytes, kind: 'image');

        final filename = await _presignUpload(
          token: token,
          type: 'image',
          ext: ext,
          contentType: '${contentType.type}/${contentType.subtype}',
          bytes: encryptedBytes,
        );
        if (filename == null) {
          debugPrint('[album] presign upload failed for $basename');
          continue;
        }

        try {
          await localFile.copy('${cacheDir.path}/$filename');
        } catch (_) {}

        albumItems.add({
          'filename': filename,
          'owner': widget.myUsername,
          'orig': basename,
          'key': albumItemKeyB64,
          if (blur != null) 'blur': blur.hash,
          if (blur != null) 'ar': blur.aspectRatio,
        });
      }

      if (albumItems.isEmpty) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .albumUploadFailed);
        return;
      }

      final content = 'ALBUMv1:${jsonEncode(albumItems)}';
      final replyTo = _replyingToMessage;

      if (mounted)
        setState(() {
          _replyingToMessage = null;
        });

      await widget.onSend(content, replyTo);

      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .albumSent(albumItems.length));
      }
    } catch (e) {
      if (mounted) rootScreenKey.currentState?.showSnack('Error: $e');
    }
  }

  Future<void> _sendVideo(String filePath, String basename, String ext) async {
    final MediaType contentType;
    if (ext == '.mov')
      contentType = MediaType('video', 'quicktime');
    else if (ext == '.avi')
      contentType = MediaType('video', 'x-msvideo');
    else if (ext == '.mkv')
      contentType = MediaType('video', 'x-matroska');
    else if (ext == '.webm')
      contentType = MediaType('video', 'webm');
    else if (ext == '.flv')
      contentType = MediaType('video', 'x-flv');
    else if (ext == '.m4v')
      contentType = MediaType('video', 'x-m4v');
    else
      contentType = MediaType('video', 'mp4');

    try {
      final token = await AccountManager.getToken(
          rootScreenKey.currentState?.currentUsername ?? '');
      if (token == null) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
        return;
      }

      final ok = await (rootScreenKey.currentState
              ?.checkQuotaAndPrompt(limitMb: 100.0, includeImageCache: false) ??
          Future.value(true));
      if (!ok) return;

      final localFile = File(filePath);
      if (!await localFile.exists()) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }
      if (await localFile.length() == 0) {
        rootScreenKey.currentState?.showSnack('File is empty');
        return;
      }

      final plainBytes = await localFile.readAsBytes();
      // Extract AR + blurHash poster before upload so recipients get instant preview.
      final videoInfo = await extractVideoInfo(filePath);
      final root = rootScreenKey.currentState;
      if (root == null) {
        rootScreenKey.currentState?.showSnack('RootScreen not ready');
        return;
      }

      // Create pending upload task — shows video placeholder immediately
      final task = UploadTask(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: 'video',
        localPath: filePath,
        basename: basename,
      );
      task.presignType = 'video';
      task.presignExt = ext;
      task.presignContentType = '${contentType.type}/${contentType.subtype}';
      if (mounted)
        setState(() {
          _pendingUploads.add(task);
        });

      final (encryptedBytes, videoMediaKeyB64) =
          await root.encryptMediaRandom(plainBytes, kind: 'video');
      task.encryptedBytes = encryptedBytes;
      task.mediaKey = videoMediaKeyB64;
      task.status = UploadStatus.uploading;
      if (mounted) setState(() {});

      final replyTo = _replyingToMessage;
      if (mounted)
        setState(() {
          _replyingToMessage = null;
        });

      task.onComplete = (filename) async {
        final meta = jsonEncode({
          'filename': filename,
          'owner': widget.myUsername,
          'orig': basename,
          'key': videoMediaKeyB64,
          if (videoInfo?.hash != null) 'blur': videoInfo!.hash,
          if (videoInfo != null) 'ar': videoInfo.ar,
        });
        await widget.onSend('VIDEOv1:$meta', replyTo);
        if (mounted)
          setState(() {
            _pendingUploads.remove(task);
          });
        if (mounted)
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).videoSent);
      };

      final filename = await _presignUploadWithProgress(
        token: token,
        presignType: 'video',
        ext: ext,
        contentType: '${contentType.type}/${contentType.subtype}',
        bytes: encryptedBytes,
        task: task,
      );
      if (filename == null) {
        if (task.status == UploadStatus.failed) {
          if (mounted)
            setState(() {
              _pendingUploads.remove(task);
            });
          rootScreenKey.currentState?.showSnack('Upload failed');
        }
        return;
      }
      await task.onComplete!(filename);
    } catch (e) {
      if (mounted) rootScreenKey.currentState?.showSnack('Error: $e');
    }
  }
}

class _MessageActionsSheet extends StatefulWidget {
  final ChatMessage msg;
  final bool canEditDelete;
  final bool isMedia;

  final bool canAlwaysDelete;
  final VoidCallback onReply;
  final VoidCallback? onSave;
  final VoidCallback? onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final bool isPinned;
  final VoidCallback? onReact;

  const _MessageActionsSheet({
    required this.msg,
    required this.canEditDelete,
    required this.isMedia,
    this.canAlwaysDelete = false,
    required this.onReply,
    this.onSave,
    this.onEdit,
    required this.onCopy,
    this.onDelete,
    this.onPin,
    this.isPinned = false,
    this.onReact,
  });

  @override
  State<_MessageActionsSheet> createState() => _MessageActionsSheetState();
}

class _MessageActionsSheetState extends State<_MessageActionsSheet> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.msg.editSecondsLeft;

    if (widget.canEditDelete && _secondsLeft != 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = widget.msg.editSecondsLeft;
        if (!mounted) return;
        setState(() => _secondsLeft = left);
        if (left == 0) _timer?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    final canAct = widget.canEditDelete && _secondsLeft != 0;

    String editLabel() {
      if (!canAct) return l.edit;
      if (_secondsLeft > 0) return l.editTimerLabel(_secondsLeft);
      return l.edit;
    }

    String deleteLabel() {
      if (widget.canAlwaysDelete) return l.delete;
      if (!canAct) return l.delete;
      if (_secondsLeft > 0) return l.deleteTimerLabel(_secondsLeft);
      return l.delete;
    }

    Widget actionTile(IconData icon, String label, VoidCallback? onTap,
        {Color? color}) {
      final effective = color ?? colorScheme.onSurface;
      return ListTile(
        leading: Icon(icon,
            color: onTap != null
                ? effective
                : colorScheme.onSurface.withValues(alpha: 0.3)),
        title: Text(
          label,
          style: TextStyle(
            color: onTap != null
                ? effective
                : colorScheme.onSurface.withValues(alpha: 0.3),
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
          colorScheme.surfaceContainerHighest,
          brightness,
        );
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
                actionTile(Icons.reply_rounded, l.reply, widget.onReply),
                actionTile(
                    Icons.add_reaction_outlined, l.react, widget.onReact),
                actionTile(
                  widget.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  widget.isPinned ? l.unpin : l.pin,
                  widget.onPin,
                ),
                if (widget.onSave != null)
                  actionTile(Icons.save_alt_rounded, l.save, widget.onSave),
                if (widget.msg.outgoing && !widget.isMedia)
                  actionTile(
                    Icons.edit_rounded,
                    editLabel(),
                    canAct ? widget.onEdit : null,
                  ),
                if (!widget.isMedia)
                  actionTile(Icons.copy_rounded, l.copy, widget.onCopy),
                if (widget.msg.outgoing && widget.onDelete != null)
                  actionTile(
                    Icons.delete_outline_rounded,
                    deleteLabel(),
                    (canAct || widget.canAlwaysDelete) ? widget.onDelete : null,
                    color: Colors.red.shade400,
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditTimerBadge extends StatefulWidget {
  final ChatMessage msg;

  const _EditTimerBadge({required this.msg});

  @override
  State<_EditTimerBadge> createState() => _EditTimerBadgeState();
}

class _EditTimerBadgeState extends State<_EditTimerBadge> {
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.msg.editSecondsLeft;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = widget.msg.editSecondsLeft;
      setState(() => _secondsLeft = left);
      if (left == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft == 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    if (_secondsLeft < 0) {
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          Icons.edit_outlined,
          size: 13,
          color: colorScheme.primary.withValues(alpha: 0.5),
        ),
      );
    }
    final progress = _secondsLeft / 30.0;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        width: 18,
        height: 18,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: colorScheme.primary.withValues(alpha: 0.6),
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
            ),
            Text(
              '$_secondsLeft',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
