// lib/screens/group_chat_screen.dart
import 'package:ONYX/screens/forward_screen.dart';
import 'package:ONYX/managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:ui' as ui;
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
import '../widgets/avatar_widget.dart';
import '../widgets/avatar_crop_screen.dart';
import '../widgets/cached_remote_avatar.dart';
import '../enums/media_provider.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../utils/file_utils.dart';
import '../utils/image_file_cache.dart';
import '../utils/clipboard_image.dart';
import '../utils/upload_task.dart';
import '../widgets/pending_upload_card.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/animated_message_bubble.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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
    with RouteAware, SingleTickerProviderStateMixin {
  static final Set<String> _sessionInputAnimationsShown = {};

  late final RouteObserver<Route<void>> _localRouteObserver;
  final TextEditingController _textCtrl = TextEditingController();
  late final FocusNode _focusNode;
  List<Map<String, dynamic>> _messages = [];
  final ScrollController _scroll = ScrollController();
  String? _currentUsername;
  String? _currentDisplayName;
  int? _memberCount;
  late final String _inputHint;
  final Set<String> _allMessageIds = {};
  final Set<String> _alreadyRenderedMessageIds = {};
  final Map<String, String> _pendingMessageIds = {};
  final List<UploadTask> _pendingUploads = [];
  bool _loadedFromCache = false;
  bool _isDisposed = false;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;

  String? _editingMsgId;
  String? _editingOriginalContent;
  final ValueNotifier<bool> _showScrollDownButton = ValueNotifier<bool>(false);



  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryScaleX;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  final List<Map<String, dynamic>> _wsIncomingBuffer = [];
  Timer? _wsFlushTimer;
  static const int _wsBatchSize = 50;
  static const int _wsBatchDelayMs = 50;

  Map<String, dynamic>? _replyingToMessage;
  Map<String, dynamic>? _pinnedMessage;

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

  String? _scrollHighlightId;
  Timer? _highlightTimer;
  final GlobalKey _scrollTargetKey = GlobalKey();
  String? _scrollTargetId;

  // ── Day-separator display items ─────────────────────────────────────────
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
    final hash = _messages.length ^
        (_messages.isNotEmpty ? (_messages.last['id']?.hashCode ?? 0) : 0);
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

  void _copySelectedGroupMessages() {
    final texts = _selectedGroupMessages.values
        .where(_isGroupTextMessage)
        .map((m) => m['content']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value).msgCopied);
    }
    _exitGroupSelectionMode();
  }

  void _forwardSelectedGroupMessages() {
    final contents = _selectedGroupMessages.values
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteMessageTitle),
        content: Text(toDelete.length == 1
            ? l.deleteGroupMsgContent
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
    _loadHistoryFromCache().then((_) {
      _loadHistoryFromNetwork();
    });
    _loadMemberCount();
    rootScreenKey.currentState?.subscribeToGroup(widget.group.id, _onGroupMsg);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);

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

  void _onGroupLongPress(Map<String, dynamic> msg) {
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
                    actionTile(
                        Icons.reply_rounded, AppLocalizations.of(context).reply,
                        () {
                      Navigator.pop(ctx);
                      _startReplyingToMessage(msg);
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
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx2) => AlertDialog(
                                title: Text(AppLocalizations.of(context)
                                    .deleteMessageTitle),
                                content: Text(AppLocalizations.of(context)
                                    .deleteGroupMsgContent),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx2, false),
                                    child: Text(
                                        AppLocalizations.of(context).cancel),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red.shade700),
                                    onPressed: () => Navigator.pop(ctx2, true),
                                    child: Text(
                                        AppLocalizations.of(context).delete,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ),
                                ],
                              ),
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

  List<ContextMenuButtonItem> _buildGroupDesktopMenuItems(
      Map<String, dynamic> msg) {
    final content = msg['content']?.toString() ?? '';
    final rawSender = msg['sender']?.toString() ?? '';
    final isMe = rawSender == _currentUsername || rawSender == _currentDisplayName;
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
      ContextMenuButtonItem(
        label: l.reply,
        onPressed: () => _startReplyingToMessage(msg),
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
              : () => _copyGroupProxyImage(content),
        ),
      if (!isMedia)
        ContextMenuButtonItem(
          label: l.copy,
          type: ContextMenuButtonType.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            rootScreenKey.currentState?.showSnack(l.msgCopied);
          },
        ),
      if (isMe && !isMedia && msgId != null)
        ContextMenuButtonItem(
          label: l.edit,
          onPressed: () => _startEditingGroupMessage(msg),
        ),
      ContextMenuButtonItem(
        label: _isGroupMsgPinned(msg) ? 'Unpin' : 'Pin',
        onPressed: () => _toggleGroupPin(msg),
      ),
      if (isMe && msgId != null)
        ContextMenuButtonItem(
          label: l.delete,
          type: ContextMenuButtonType.delete,
          onPressed: () => _desktopDeleteGroupMessage(msg, msgId),
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
            saved == true ? 'Saved to gallery' : 'Failed to save to gallery',
          );
        } else if (isVideo) {
          final saved =
              await GallerySaver.saveVideo(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(
            saved == true ? 'Saved to gallery' : 'Failed to save to gallery',
          );
        } else {
          // Audio / documents / archives — copy to Downloads/ONYX
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

  Future<void> _desktopDeleteGroupMessage(
      Map<String, dynamic> msg, String msgId) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: Text(l.deleteMessageTitle),
        content: Text(l.deleteGroupMsgContent),
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
            AppLocalizations(SettingsManager.appLocale.value).failedDelete);
      }
    } catch (e) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedDelete);
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
            AppLocalizations(SettingsManager.appLocale.value).failedEdit);
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).failedEdit);
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
    _selectionNotifier.dispose();
    _isDisposed = true;
    _localRouteObserver.unsubscribe(this);
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    rootScreenKey.currentState?.unsubscribeFromGroup(widget.group.id);
    _pendingMessageIds.clear();
    groupAvatarVersion.removeListener(_onGroupAvatarUpdate);
    _showScrollDownButton.dispose();
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
      final pendingCount = _pendingUploads.length;
      final totalItems = pendingCount + _rebuildGroupDisplayItems().length;
      if (totalItems == 0) return;
      final listIdx = pendingCount + matchAdjI;
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

  Future<void> _loadHistoryFromCache() async {
    final username = _currentUsername ?? '';
    if (username.isEmpty) return;
    try {
      final appDir = await getApplicationSupportDirectory();
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
          };
          newMessages.add(msg);
        }
      }
      if (mounted && !_isDisposed) {
        setState(() {
          _messages = newMessages;
          _allMessageIds.addAll(seenIds);
          _loadedFromCache = true;
        });
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      if (mounted && !_loadedFromCache) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).noInternetCached);
      }
    }
  }

  Future<void> _saveHistoryToCache(List<Map<String, dynamic>> messages) async {
    try {
      final username = _currentUsername ?? '';
      if (username.isEmpty) return;
      final appDir = await getApplicationSupportDirectory();
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

    final token = await AccountManager.getToken(_currentUsername ?? '');
    if (token == null) return;

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
      _scrollToBottomAfterSend();
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

              debugPrint(
                  '[group_chat_screen::send] clearing _replyingToMessage\n${StackTrace.current}');
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
            AppLocalizations(SettingsManager.appLocale.value).sendFailed);
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
            AppLocalizations(SettingsManager.appLocale.value)
                .mediaUploadNotSupportedWeb);
      }
      return;
    }
    FilePickerResult? result;
    try {
      result = await FilePicker.platform
          .pickFiles(type: FileType.any, allowMultiple: true);
    } catch (e) {
      debugPrint('[Attach] FilePicker error: $e');
      if (mounted)
        rootScreenKey.currentState?.showSnack('File picker error: $e');
      return;
    }
    if (result?.files.isEmpty ?? true) return;

    final paths = result!.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) {
      if (mounted)
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
                .localFileRequired);
      return;
    }

    if (paths.length > 1 && paths.every(FileTypeDetector.isImage)) {
      if (SettingsManager.confirmFileUpload.value) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlbumPreviewDialog(
            filePaths: paths,
            onSend: () => _processAndUploadAlbum(paths),
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
                ? 'voice'
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
              AppLocalizations(SettingsManager.appLocale.value).uploadFailed);
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

  Widget _buildPendingUploadWidget(UploadTask task) {
    return PendingUploadCard(
      task: task,
      showProgress: false, // catbox upload — no byte-level progress
      onCancel: () => _cancelUpload(task),
    );
  }

  Future<void> _processAndUploadAlbum(List<String> filePaths) async {
    if (_isReadOnlyChannel) return;
    final limited = filePaths.take(10).toList();
    if (limited.isEmpty) return;

    const provider = MediaProvider.catbox;
    if (mounted) {
      rootScreenKey.currentState?.showSnack(
          AppLocalizations(SettingsManager.appLocale.value)
              .uploadingImages(limited.length));
    }

    final items = <Map<String, String>>[];
    for (final filePath in limited) {
      final basename = p.basename(filePath);
      final bytes = await File(filePath).readAsBytes();
      final link = await _uploadToProvider(bytes, basename, provider);
      if (link == null) {
        debugPrint('[group-album] upload failed for $basename');
        continue;
      }
      items.add({'url': link, 'orig': basename, 'provider': provider.name});
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
              AppLocalizations(SettingsManager.appLocale.value)
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
                        AppLocalizations(SettingsManager.appLocale.value)
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

      if (_replyingToMessage != null)
        setState(() {
          debugPrint(
              '[group_chat_screen::clear] clearing _replyingToMessage\n${StackTrace.current}');
          _replyingToMessage = null;
        });
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  void _onGroupMsg(Map<String, dynamic> msg) {
    if (_isDisposed) return;

    final typ = msg['type'] as String?;
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

    const int animateLimit = 3;
    if (toAdd.length > animateLimit) {
      for (int i = 0; i < toAdd.length - animateLimit; i++) {
        toAdd[i]['suppressAnimation'] = true;
      }
      debugPrint(
          '[GroupChat Animation] Batch received: ${toAdd.length}, only last $animateLimit will animate');
    }

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
            final appDir = await getApplicationSupportDirectory();
            final file = File(
                '${appDir.path}/group_${username}_${widget.group.id}_history.json');
            if (await file.exists()) await file.delete();
          } catch (e) {
            debugPrint('[err] $e');
          }
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value).leftGroup);
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .failedLeaveGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).networkError);
      }
    }
  }

  Future<bool?> _showLeaveConfirmation(BuildContext context) {
    final l = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.leaveGroupTitle(false)),
        content: Text(l.leaveGroupContent('')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.leave)),
        ],
      ),
    );
  }

  Future<void> _uploadGroupAvatar() async {
    if (!_canManageGroup) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value)
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
              AppLocalizations(SettingsManager.appLocale.value).failedReadFile);
        }
        return;
      }
      bytes = file.bytes!;
      filename = file.name;
    } else {
      if (path == null) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
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
          AppLocalizations(SettingsManager.appLocale.value).uploadingAvatar);
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
              AppLocalizations(SettingsManager.appLocale.value)
                  .avatarUpdatedGroup);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .failedUpdateGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).networkError);
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
              AppLocalizations(SettingsManager.appLocale.value).avatarDeleted);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .failedDeleteAvatar);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).networkError);
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
              AppLocalizations(SettingsManager.appLocale.value)
                  .avatarUpdatedGroup);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(
              AppLocalizations(SettingsManager.appLocale.value)
                  .failedUpdateGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(
            AppLocalizations(SettingsManager.appLocale.value).networkError);
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
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: SettingsManager.elementOpacity.value),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(widget.group.isChannel
              ? AppLocalizations.of(context).editChannelTitle
              : AppLocalizations.of(context).editGroupTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => changeAvatarInDialog(setDialogState),
                      onLongPress: () => removeAvatarInDialog(setDialogState),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(
                            '$serverBase/group/${widget.group.id}/avatar?v=${_avatarVersion}'),
                      ),
                    ),
                    if (isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, ___) {
                  final baseColor = SettingsManager.getElementColor(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    brightness,
                  );
                  return TextField(
                    controller: controller,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: widget.group.isChannel
                          ? AppLocalizations.of(context).channelNameLabel
                          : AppLocalizations.of(context).groupNameLabel,
                      hintText: widget.group.isChannel
                          ? AppLocalizations.of(context).channelNameHint
                          : AppLocalizations.of(context).groupNameHint,
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: baseColor.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(AppLocalizations.of(context).copyLink),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                        text: widget.group.inviteLink.split('/').last));
                    if (mounted) {
                      rootScreenKey.currentState?.showSnack(
                          AppLocalizations(SettingsManager.appLocale.value)
                              .tokenCopied);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppLocalizations.of(context).cancel)),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isEmpty || newName.length > 50) {
                  if (mounted) {
                    rootScreenKey.currentState?.showSnack(
                        AppLocalizations(SettingsManager.appLocale.value)
                            .groupNameLength);
                  }
                  return;
                }

                final token =
                    await AccountManager.getToken(_currentUsername ?? '');
                if (token == null) return;
                try {
                  final res = await http.post(
                    Uri.parse('$serverBase/group/${widget.group.id}/rename'),
                    headers: {
                      'authorization': 'Bearer $token',
                      'content-type': 'application/json'
                    },
                    body: jsonEncode({'name': newName}),
                  );
                  if (res.statusCode == 200) {
                    try {
                      final j = jsonDecode(res.body) as Map<String, dynamic>;
                      final updatedName = j['name']?.toString();
                      if (updatedName != null) {
                        final username =
                            rootScreenKey.currentState?.currentUsername ?? '';
                        final cached =
                            await AccountManager.loadGroupsCache(username);
                        final updated = cached
                            .map((g) => g.id == widget.group.id
                                ? Group(
                                    id: g.id,
                                    name: updatedName,
                                    isChannel: g.isChannel,
                                    owner: g.owner,
                                    inviteLink: g.inviteLink,
                                    avatarVersion: g.avatarVersion,
                                    myRole: g.myRole)
                                : g)
                            .toList();
                        await AccountManager.saveGroupsCache(username, updated);

                        groupsVersion.value++;

                        final root = rootScreenKey.currentState;
                        if (root != null &&
                            root.selectedGroup != null &&
                            root.selectedGroup!.id == widget.group.id) {
                          root.selectedGroup = Group(
                              id: widget.group.id,
                              name: updatedName,
                              isChannel: widget.group.isChannel,
                              owner: widget.group.owner,
                              inviteLink: widget.group.inviteLink,
                              avatarVersion: widget.group.avatarVersion,
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
                          AppLocalizations(SettingsManager.appLocale.value)
                              .groupUpdated);
                    }
                    Navigator.of(ctx).pop(true);
                  } else {
                    if (mounted) {
                      rootScreenKey.currentState?.showSnack(
                          AppLocalizations(SettingsManager.appLocale.value)
                              .failedUpdateGroup);
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    rootScreenKey.currentState?.showSnack(
                        AppLocalizations(SettingsManager.appLocale.value)
                            .networkError);
                  }
                }
              },
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
        ),
      ),
    );

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
              child: ValueListenableBuilder<double>(
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
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<bool>(
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
                                          padding: const EdgeInsets.only(
                                              bottom: 6.0),
                                          child: Material(
                                            shape: const CircleBorder(),
                                            color: colorScheme.errorContainer,
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: colorScheme
                                                    .onErrorContainer,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                debugPrint(
                                                    '<<TRASH PRESSED>> cancel recording in group');
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
                                      ? colorScheme.error
                                          .withValues(alpha: 0.12)
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
                                      debugPrint(
                                          '<<MIC BUTTON PRESSED>> isRecording=$isRecording in group');
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
                        IconButton(
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
                        Expanded(
                          child: KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (event) {
                              if (event is KeyDownEvent) {
                                if (HardwareKeyboard.instance
                                        .isLogicalKeyPressed(
                                            LogicalKeyboardKey.keyV) &&
                                    (HardwareKeyboard
                                            .instance.isControlPressed ||
                                        HardwareKeyboard
                                            .instance.isMetaPressed)) {
                                  _handlePasteFromClipboard();
                                  return;
                                }

                                if (HardwareKeyboard.instance
                                    .isLogicalKeyPressed(
                                        LogicalKeyboardKey.enter)) {
                                  if (!HardwareKeyboard
                                      .instance.isShiftPressed) {
                                    if (_textCtrl.text.trim().isNotEmpty) {
                                      _sendMessage(_textCtrl.text);
                                    }
                                    return;
                                  }
                                  if (HardwareKeyboard
                                          .instance.isShiftPressed &&
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
                              maxLines: null,
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
                                      _handleGroupDroppedFiles([tempFile.path]);
                                    }
                                  } catch (e) {
                                    debugPrint('[ContentInsert] Error: $e');
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
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
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
                                onPressed: _exitGroupSelectionMode,
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
                                onPressed: _exitGroupSelectionMode,
                              ),
                            Text(
                              '${sel.selected.length} selected',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            GestureDetector(
                              onTap:
                                  _canManageGroup ? _showEditGroupDialog : null,
                              onLongPress: _canManageGroup
                                  ? () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(
                                              AppLocalizations.of(context)
                                                  .deleteAvatarTitle),
                                          content: Text(
                                              AppLocalizations.of(context)
                                                  .deleteAvatarContent),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: Text(
                                                    AppLocalizations.of(context)
                                                        .cancel)),
                                            FilledButton.tonal(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: Text(
                                                    AppLocalizations.of(context)
                                                        .delete)),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true)
                                        await _deleteGroupAvatar();
                                    }
                                  : null,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(avatarUrl),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap:
                                  _canManageGroup ? _showEditGroupDialog : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.group.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (widget.group.inviteLink == '12e01467-c154-447b-84f8-133ae76684a1')
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4),
                                          child: Icon(Icons.verified_rounded, size: 15, color: Colors.blue.shade400),
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
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                ],
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
                            if (sel.selected.values.any(_isGroupTextMessage))
                              IconButton(
                                icon: const Icon(Icons.copy_rounded),
                                tooltip: 'Copy',
                                onPressed: _copySelectedGroupMessages,
                              ),
                            if (sel.selected.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.forward_rounded),
                                tooltip: 'Forward',
                                onPressed: _forwardSelectedGroupMessages,
                              ),
                            if (sel.selected.values.any(_isMyGroupMessage))
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: Colors.red.shade400),
                                tooltip: 'Delete',
                                onPressed: _confirmDeleteSelectedGroupMessages,
                              ),
                          ])
                        : Row(mainAxisSize: MainAxisSize.min, children: [
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
                            if (_canManageGroup)
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _showEditGroupDialog,
                              ),
                            IconButton(
                              icon: const Icon(Icons.link),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                    text: widget.group.inviteLink
                                        .split('/')
                                        .last));
                                if (mounted) {
                                  rootScreenKey.currentState?.showSnack(
                                      AppLocalizations(
                                              SettingsManager.appLocale.value)
                                          .tokenCopied);
                                }
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (String value) async {
                                if (value == 'leave') {
                                  final confirmed =
                                      await _showLeaveConfirmation(context);
                                  if (confirmed == true) {
                                    await _leaveGroup();
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'leave',
                                  child: Text(AppLocalizations.of(context)
                                      .leaveGroupTitle(false)),
                                ),
                              ],
                            ),
                          ]),
                  ),
                ],
              ),
              body: DragDropZone(
                onFilesDropped: _handleGroupDroppedFiles,
                enabled: !_isReadOnlyChannel,
                child: Stack(
                  children: [
                    ValueListenableBuilder<String?>(
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
                                final image = Image.file(f, fit: BoxFit.cover);
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
                    ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.showAvatarInChats,
                      builder: (_, showAvatar, __) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: SettingsManager.swapMessageAlignment,
                          builder: (_, swapped, __) {
                            return ValueListenableBuilder<bool>(
                              valueListenable:
                                  SettingsManager.alignAllMessagesRight,
                              builder: (_, alignRight, __) {
                                // Compute search matches (indices into display items)
                                final displayItems =
                                    _rebuildGroupDisplayItems();
                                if (_showSearch && _searchQuery.isNotEmpty) {
                                  final newMatches = <int>[];
                                  for (int j = 0;
                                      j < displayItems.length;
                                      j++) {
                                    final item = displayItems[j];
                                    if (item is Map<String, dynamic>) {
                                      final c =
                                          item['content']?.toString() ?? '';
                                      if (c
                                          .toLowerCase()
                                          .contains(_searchQuery)) {
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
                                    current:
                                        newMatches.isEmpty ? 0 : clampedIdx + 1,
                                    total: newMatches.length,
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
                                return Listener(
                                  onPointerDown: (_) {
                                    if (!isDesktop) return;
                                    _suppressAutoRefocus = true;
                                    _focusNode.unfocus();
                                  },
                                  child: ListView.builder(
                                    controller: _scroll,
                                    reverse: true,
                                    itemCount: _pendingUploads.length +
                                        displayItems.length,
                                    cacheExtent: 800,
                                    addRepaintBoundaries: true,
                                    padding: EdgeInsets.only(
                                      top: MediaQuery.of(context).padding.top +
                                          kToolbarHeight +
                                          (_showSearch ? 64 : 12),
                                      bottom: 72 +
                                          MediaQuery.of(context).padding.bottom,
                                    ),
                                    itemBuilder: (ctx, i) {
                                      if (i < _pendingUploads.length) {
                                        final task = _pendingUploads[
                                            _pendingUploads.length - 1 - i];
                                        return _buildPendingUploadWidget(task);
                                      }
                                      final adjustedI =
                                          i - _pendingUploads.length;
                                      final item = displayItems[adjustedI];

                                      // Day separator
                                      if (item is DateTime) {
                                        return _buildGroupDaySeparator(
                                            ctx, item);
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
                                      final isSearchMatch =
                                          _searchQuery.isNotEmpty &&
                                              content
                                                  .toLowerCase()
                                                  .contains(_searchQuery);
                                      final isCurrentSearchMatch =
                                          isSearchMatch &&
                                              _cachedSearchMatches.isNotEmpty &&
                                              _cachedSearchMatches[
                                                      _currentMatchIdx] ==
                                                  adjustedI;

                                      bool showSenderInfo =
                                          !widget.group.isChannel;

                                      final bool showAvatarForThisMessage =
                                          (() {
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
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7),
                                        child: GestureDetector(
                                          onTapDown: (tap) {
                                            debugPrint(
                                                '[group_chat_screen::msgTapDown] tapped message id=${msg['id']} replying=${_replyingToMessage != null} reply=${_replyingToMessage?.toString()}\n${StackTrace.current}');
                                          },
                                          onHorizontalDragEnd: isDesktop
                                              ? null
                                              : (details) {
                                                  final v =
                                                      details.primaryVelocity;
                                                  if (v != null && v > 300) {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    _onGroupLongPress(msg);
                                                  } else if (v != null &&
                                                      v < -300) {
                                                    final preview = {
                                                      'id':
                                                          msg['id']?.toString(),
                                                      'sender': rawSender,
                                                      'senderDisplayName':
                                                          sender,
                                                      'content': getPreviewText(
                                                          content),
                                                    };
                                                    _startReplyingToMessage(
                                                        preview);
                                                    HapticFeedback
                                                        .selectionClick();
                                                  }
                                                },
                                          child: MessageBubble(
                                            key: ValueKey<String>(
                                                'mb_${msg['timestamp']}_${sender}_${content.hashCode}'),
                                            text: content,
                                            outgoing: isMe,
                                            rawPreview: null,
                                            serverMessageId: null,
                                            time: (msg['timestamp_ms'] != null)
                                                ? DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        msg['timestamp_ms']
                                                            as int)
                                                : (DateTime.tryParse(
                                                        msg['timestamp']) ??
                                                    DateTime.now()),
                                            onRequestResend: (_) {},
                                            desktopMenuItems: isDesktop
                                                ? _buildGroupDesktopMenuItems(
                                                    msg)
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
                                                msg['reply_to_content']
                                                    ?.toString(),
                                            highlighted:
                                                (_replyingToMessage != null &&
                                                    _replyingToMessage!['id']
                                                            ?.toString() ==
                                                        msg['id']?.toString()),
                                            onReplyTap: msg['reply_to_id'] !=
                                                    null
                                                ? () =>
                                                    _scrollToGroupMessageById(
                                                        msg['reply_to_id']
                                                            .toString())
                                                : null,
                                          ),
                                        ),
                                      );
                                      final uniqueKey =
                                          '${msg['timestamp']}_${sender}_${content.hashCode}';
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

                                      final bool suppressed =
                                          msg['suppressAnimation'] == true;
                                      final bubbleWithContext =
                                          AnimatedMessageBubble(
                                              key: ValueKey<String>(animKey),
                                              outgoing: isMe,
                                              animate: isFirstAppearance &&
                                                  !suppressed &&
                                                  SettingsManager.messageAnimationsEnabled.value,
                                              child: RepaintBoundary(
                                                  child: bubble));
                                      final shouldAlignRight = alignRight
                                          ? !swapped
                                          : ((swapped && !isMe) ||
                                              (!swapped && isMe));
                                      Widget contentWithSender;
                                      if (showSenderInfo) {
                                        contentWithSender = Column(
                                          crossAxisAlignment: shouldAlignRight
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 4.0),
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
                                                            child: widget.group
                                                                    .isChannel
                                                                ? CircleAvatar(
                                                                    radius: 10,
                                                                    backgroundImage:
                                                                        NetworkImage(
                                                                            '$serverBase/group/${widget.group.id}/avatar?v=${_avatarVersion}'),
                                                                  )
                                                                : AvatarWidget(
                                                                    key: ValueKey(
                                                                        'avatar-$sender'),
                                                                    username:
                                                                        sender,
                                                                    tokenProvider:
                                                                        () async =>
                                                                            null,
                                                                    size: 20,
                                                                    editable:
                                                                        false,
                                                                  ),
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                                  if (((swapped && isMe) ||
                                                          (!swapped &&
                                                              !isMe)) &&
                                                      showAvatar &&
                                                      showAvatarForThisMessage)
                                                    const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      sender,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                        color: colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.7),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                                                  () async =>
                                                                      null,
                                                              size: 20,
                                                              editable: false,
                                                            ),
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                                ],
                                              ),
                                            ),
                                            bubbleWithContext,
                                          ],
                                        );
                                      } else {
                                        contentWithSender = bubbleWithContext;
                                      }

                                      final gcs = Theme.of(context).colorScheme;
                                      return ValueListenableBuilder<
                                          ({
                                            bool active,
                                            Map<String,
                                                Map<String, dynamic>> selected
                                          })>(
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
                                          final isGroupSelected = sel.selected
                                              .containsKey(uniqueKey);
                                          final groupCheckmark =
                                              GestureDetector(
                                            onTap: () =>
                                                _toggleGroupMsgSelection(
                                                    msg, uniqueKey),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 150),
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
                                                            .withValues(
                                                                alpha: 0.35),
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
                                          return RawGestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            gestures: {
                                              LongPressGestureRecognizer:
                                                  GestureRecognizerFactoryWithHandlers<
                                                      LongPressGestureRecognizer>(
                                                () =>
                                                    LongPressGestureRecognizer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    250)),
                                                (instance) {
                                                  instance.onLongPress = sel
                                                          .active
                                                      ? () =>
                                                          _toggleGroupMsgSelection(
                                                              msg, uniqueKey)
                                                      : () =>
                                                          _enterGroupSelectionMode(
                                                              msg, uniqueKey);
                                                },
                                              ),
                                            },
                                            child: GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onTap: sel.active
                                                  ? () =>
                                                      _toggleGroupMsgSelection(
                                                          msg, uniqueKey)
                                                  : null,
                                              onDoubleTap: sel.active
                                                  ? null
                                                  : () =>
                                                      _enterGroupSelectionMode(
                                                          msg, uniqueKey),
                                              child: AnimatedContainer(
                                                key: (_scrollTargetId != null &&
                                                        _scrollTargetId ==
                                                            msg['id']
                                                                ?.toString())
                                                    ? _scrollTargetKey
                                                    : null,
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                color: isCurrentSearchMatch
                                                    ? gcs.primary
                                                        .withValues(alpha: 0.28)
                                                    : isSearchMatch
                                                        ? gcs.primary
                                                            .withValues(
                                                                alpha: 0.12)
                                                        : isGroupSelected
                                                            ? gcs
                                                                .primaryContainer
                                                                .withValues(
                                                                    alpha: 0.45)
                                                            : (_scrollHighlightId !=
                                                                        null &&
                                                                    _scrollHighlightId ==
                                                                        msg['id']
                                                                            ?.toString())
                                                                ? gcs.primary
                                                                    .withValues(
                                                                        alpha:
                                                                            0.18)
                                                                : Colors
                                                                    .transparent,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 4),
                                                child: Row(
                                                  children: [
                                                    if (sel.active &&
                                                        !shouldAlignRight)
                                                      groupCheckmark,
                                                    Expanded(
                                                        child: contentChild!),
                                                    if (sel.active &&
                                                        shouldAlignRight)
                                                      groupCheckmark,
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
                            );
                          },
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
                        child: _buildGroupPinnedBanner(context),
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
                      child: Center(
                        child: _isReadOnlyChannel
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
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 16),
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
                                              'This is a channel. You cannot send messages here.',
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
                            : ValueListenableBuilder<double>(
                                valueListenable:
                                    SettingsManager.inputBarMaxWidth,
                                builder: (_, width, __) {
                                  return Container(
                                    constraints:
                                        BoxConstraints(maxWidth: width),
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
                                      Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: 18,
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
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
  }

  Future<void> _handleGroupDroppedFiles(List<String> filePaths) async {
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
      final basename = p.basename(filePath);
      final ext = p.extension(basename).toLowerCase();
      _showGroupFilePreviewAndSend(filePath, basename, ext);
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
                AppLocalizations(SettingsManager.appLocale.value)
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
