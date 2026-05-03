// lib/screens/favorites_screen.dart
import 'dart:convert';

import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import 'package:ONYX/screens/forward_screen.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../globals.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/avatar_crop_screen.dart';
import '../widgets/adaptive_blur.dart';
import '../models/chat_message.dart';
import '../managers/settings_manager.dart';
import '../widgets/message_bubble.dart';
import '../models/favorite_chat.dart';
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../utils/file_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../utils/image_file_cache.dart';
import '../utils/clipboard_image.dart';
import '../utils/upload_task.dart';
import '../widgets/pending_upload_card.dart';
import '../widgets/chat_search_bar.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/message_reaction_bar.dart';
import '../widgets/media_picker_sheet.dart';

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
  State<_EditableFavoriteAvatar> createState() => _EditableFavoriteAvatarState();
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
  final ScrollController _scroll = ScrollController();
  late final FocusNode _focusNode;
  Timer? _typingDebounce;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;
  final ValueNotifier<bool> _showScrollDownButton = ValueNotifier<bool>(false);
  final Set<String> _alreadyRenderedMessageIds = {};
  
  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryScaleX;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  List<_ListItem>? _cachedDaySeparatorItems;
  List<ChatMessage>? _lastProcessedMessages;

  final List<UploadTask> _pendingUploads = [];

  late final _selectionNotifier = ValueNotifier<({bool active, Map<String, ChatMessage> selected})>((active: false, selected: {}));
  Map<String, ChatMessage> get _selectedFavMessages => _selectionNotifier.value.selected;

  // ── in-chat search ──────────────────────────────────────────────────────────
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentMatchIdx = 0;
  List<int> _cachedSearchMatches = [];
  final _searchStats = ValueNotifier<({int current, int total})>((current: 0, total: 0));
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _scroll.addListener(_onScroll);
    _loadPinnedMessage();

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

    Future.microtask(() => rootScreenKey.currentState
        ?.ensureMediaCachedForFavorite(widget.favoriteId));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus && isDesktop) {
        _focusNode.requestFocus();
      }
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        if (recordingNotifier.value || _shouldPreserveExternalFocus || _suppressAutoRefocus) return;
        
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
        setState(() => _pinnedMessage = Map<String, dynamic>.from(jsonDecode(raw) as Map));
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
        final listviewIdx = k + _pendingUploads.length;
        final totalItems = items.length + _pendingUploads.length;
        final maxExt = _scroll.position.maxScrollExtent;
        final proportional = totalItems > 0
            ? (listviewIdx / totalItems) * maxExt
            : 0.0;

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
            onTap: () => _scrollToFavMessageById(_pinnedMessage?['id']?.toString()),
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
                  Icon(Icons.push_pin_rounded, size: 16, color: colorScheme.primary),
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
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
    _selectionNotifier.value = (active: true, selected: {...cur.selected, uniqueKey: msg});
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

  void _copySelectedFavMessages() {
    final texts = _selectedFavMessages.values
        .where((m) => _isFavTextMessage(m))
        .map((m) => m.content)
        .join('\n');
    if (texts.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: texts));
      rootScreenKey.currentState?.showSnack('Copied');
    }
    _exitFavSelectionMode();
  }

  void _forwardSelectedFavMessages() {
    final contents = _selectedFavMessages.values
        .map((m) => m.content)
        .toList();
    if (contents.isEmpty) return;
    _exitFavSelectionMode();
    ForwardScreen.show(context, contents);
  }

  Future<void> _confirmDeleteSelectedFav() async {
    final toDelete = _selectedFavMessages.values.toList();
    if (toDelete.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${toDelete.length} message${toDelete.length == 1 ? '' : 's'}?'),
        content: const Text('Selected messages will be removed from favorites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
    root.persistChats();
    chatsVersion.value++;
  }

  void _onScroll() {
    final pixels = _scroll.position.pixels;
    if (pixels > 0.0 && pixels <= 1.5 && !_scroll.position.isScrollingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && _scroll.position.pixels > 0.0 && _scroll.position.pixels <= 1.5) {
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
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent) return false;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      if (_showSearch) { _closeSearch(); } else { _openSearch(); }
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
      _currentMatchIdx = (_currentMatchIdx - 1 + _cachedSearchMatches.length) % _cachedSearchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _openSearch() {
    _suppressAutoRefocus = true;
    setState(() { _showSearch = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  void _scrollToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _cachedSearchMatches.isEmpty) return;
      final matchItemIdx = _cachedSearchMatches[_currentMatchIdx];
      final pendingCount = _pendingUploads.length;
      final totalItems = pendingCount + (_cachedDaySeparatorItems?.length ?? 0);
      if (totalItems == 0) return;
      final listIdx = pendingCount + matchItemIdx;
      final maxExtent = _scroll.position.maxScrollExtent;
      final target = (maxExtent * listIdx / totalItems).clamp(0.0, maxExtent);
      _scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _onUserTyping() {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 150), () {});
  }

  void _submitMessage(String value) {
    if (value.trim().isEmpty) return;

    if (_editingMessage != null) {
      final editing = _editingMessage!;
      _cancelEditingMessage();
      final root = rootScreenKey.currentState;
      if (root != null) {
        setState(() {
          editing.updateContent(value.trim());
          _invalidateDaySeparatorCache();
        });
        root.persistChats();
        chatsVersion.value++;
      }
      return;
    }

    final localId = DateTime.now().microsecondsSinceEpoch.toString();
    final int? replyId =
        _replyingToMessage != null && _replyingToMessage!['id'] != null
            ? int.tryParse(_replyingToMessage!['id'].toString())
            : null;
    final msg = ChatMessage(
      id: localId,
      from: 'me',
      to: 'fav:${widget.favoriteId}',
      content: value.trim(),
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
    if (root != null) {
      root.chats.putIfAbsent(_chatId(), () => []).add(msg);
      root.persistChats();
      chatsVersion.value++;
    }
    _textCtrl.clear();

    if (!_shouldPreserveExternalFocus && !recordingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
    _scrollToBottomAfterSend();
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

  Future<void> _handleDroppedFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    if (filePaths.length > 1 && filePaths.every(FileTypeDetector.isImage)) {
      await _sendAlbum(filePaths);
      return;
    }

    for (final filePath in filePaths) {
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
          onSendAlbum: type == 'IMAGE' ? (paths) => _sendAlbum(paths, skipConfirm: true) : null,
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
        rawPaths = await _clipboardChannel.invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (_) {}
      final filePaths = rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        final imgPath = filePaths.firstWhere(FileTypeDetector.isImage, orElse: () => '');
        if (imgPath.isNotEmpty) return imgPath;
      }
      Uint8List? imageBytes;
      try {
        imageBytes = await _clipboardChannel.invokeMethod<Uint8List>('getClipboardImage');
      } catch (_) {}
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.png');
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
        rawPaths = await _clipboardChannel.invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (e) { debugPrint('[err] $e'); }
      final filePaths = rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        debugPrint('[clipboard] File paths from clipboard: $filePaths');
        _handleDroppedFiles(filePaths);
        return;
      }

      Uint8List? imageBytes;
      try {
        imageBytes = await _clipboardChannel.invokeMethod<Uint8List>('getClipboardImage');
      } catch (e) { debugPrint('[err] $e'); }
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/clipboard_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(imageBytes);
        debugPrint('[clipboard] Image pasted from native clipboard: ${tempFile.path}');
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
            rootScreenKey.currentState?.showSnack('Unsupported file type: $ext');
            return;
          }
          final basename = p.basename(filePath);
          final ext = p.extension(basename).toLowerCase();
          final type = FileTypeDetector.getFileType(filePath);
          debugPrint('[clipboard] File URI pasted: $filePath');
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

  Widget _buildPendingUploadWidget(UploadTask task) {
    return PendingUploadCard(
      task: task,
      showProgress: task.type == 'voice', // voice uses S3 presign with real %
      onCancel: () => setState(() => _pendingUploads.remove(task)),
    );
  }

  Future<void> _sendFile(
      String filePath, String basename, String ext, String type) async {
    final task = UploadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type == 'IMAGE'
          ? 'image'
          : type == 'VIDEO'
              ? 'video'
              : type == 'AUDIO'
                  ? 'voice'
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
      final contentJson = jsonEncode({'filename': basename, 'orig': basename});

      late String content;
      late String cachePath;
      late String cacheDir;

      if (type == 'IMAGE') {
        cacheDir =
            '${(await getApplicationSupportDirectory()).path}/image_cache';
        content = 'IMAGEv1:$contentJson';
      } else if (type == 'VIDEO') {
        cacheDir =
            '${(await getApplicationSupportDirectory()).path}/video_cache';
        content = 'VIDEOv1:$contentJson';
      } else if (type == 'AUDIO') {
        cacheDir =
            '${(await getApplicationSupportDirectory()).path}/audio_cache';
        content = 'AUDIOv1:$contentJson';
      } else if (type == 'DOCUMENT') {
        cacheDir =
            '${(await getApplicationSupportDirectory()).path}/document_cache';
        content = 'DOCUMENTv1:$contentJson';
      } else if (type == 'ARCHIVE') {
        cacheDir =
            '${(await getApplicationSupportDirectory()).path}/archive_cache';
        content = 'ARCHIVEv1:$contentJson';
      } else {
        cacheDir =
            '${(await getApplicationSupportDirectory()).path}/data_cache';
        content = 'DATAv1:$contentJson';
      }

      await Directory(cacheDir).create(recursive: true);
      final localFile = File(filePath);
      cachePath = '$cacheDir/$basename';
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
        root.chats.putIfAbsent(_chatId(), () => []).add(msg);
        root.persistChats();
        chatsVersion.value++;
        root.showSnack(
            ' ${type.toLowerCase().replaceFirst(type[0], type[0].toUpperCase())} added');
      }
    } catch (e, stack) {
      setState(() => _pendingUploads.remove(task));
      debugPrint('Error sending file: $e\n$stack');
      rootScreenKey.currentState?.showSnack('Failed to send file');
    }
  }

  Future<void> _sendAlbum(List<String> filePaths, {bool skipConfirm = false}) async {
    final limited = filePaths.take(10).toList();
    if (limited.isEmpty) return;

    if (!skipConfirm && SettingsManager.confirmFileUpload.value) {
      if (!mounted) return;
      var proceed = false;
      await showDialog<void>(
        context: context,
        builder: (_) => AlbumPreviewDialog(
          filePaths: limited,
          onSend: () => proceed = true,
          onCancel: () {},
        ),
      );
      if (!proceed) return;
    }

    try {
      final cacheDir = Directory(
          '${(await getApplicationSupportDirectory()).path}/image_cache');
      await cacheDir.create(recursive: true);

      final albumItems = <Map<String, String>>[];
      for (final filePath in limited) {
        final basename = p.basename(filePath);
        final cachePath = '${cacheDir.path}/$basename';
        await File(filePath).copy(cachePath);
        albumItems.add({'filename': basename, 'orig': basename});
      }

      if (albumItems.isEmpty) return;

      final content = 'ALBUMv1:${jsonEncode(albumItems)}';
      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      final msg = ChatMessage(
        id: localId,
        from: 'me',
        to: 'fav:${widget.favoriteId}',
        content: content,
        outgoing: true,
        delivered: true,
        time: DateTime.now(),
      );

      setState(() { _replyingToMessage = null; });

      final root = rootScreenKey.currentState;
      if (root != null) {
        root.chats.putIfAbsent(_chatId(), () => []).add(msg);
        root.persistChats();
        chatsVersion.value++;
        root.showSnack('Album saved (${albumItems.length} images)');
      }
    } catch (e) {
      debugPrint('Error sending album: $e');
      rootScreenKey.currentState?.showSnack('Failed to save album');
    }
  }

  void _onLongPress(ChatMessage msg) {
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
                  actionTile(Icons.reply_rounded, 'Reply', () {
                    Navigator.pop(ctx);
                    _startReplyingToMessage({
                      'id': msg.id,
                      'sender': msg.from,
                      'senderDisplayName': msg.from,
                      'content': msg.content,
                    });
                  }),
                  actionTile(Icons.add_reaction_outlined, 'React', () {
                    Navigator.pop(ctx);
                    final favKey =
                        '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
                    final me = rootScreenKey.currentState?.currentUsername ?? msg.from;
                    openEmojiPicker(context, favKey, me, onAfterToggle: (_, __) {
                      _persistReactionForFav(favKey, msg);
                    });
                  }),
                  actionTile(
                    _isFavMsgPinned(msg) ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    _isFavMsgPinned(msg) ? 'Unpin' : 'Pin',
                    () {
                      Navigator.pop(ctx);
                      _toggleFavPin(msg);
                    },
                  ),
                  if (isSaveable)
                    actionTile(Icons.save_alt_rounded, 'Save', () {
                      Navigator.pop(ctx);
                      _saveMediaFromMessage(text);
                    }),
                  if (isImage)
                    actionTile(Icons.copy_all_rounded, 'Copy Image', () {
                      Navigator.pop(ctx);
                      copyMessageImageToClipboard(text, (m) => rootScreenKey.currentState?.showSnack(m));
                    }),
                  if (!isMedia)
                    actionTile(Icons.copy_rounded, 'Copy', () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: text));
                      rootScreenKey.currentState?.showSnack('Copied');
                    }),
                  if (!isMedia)
                    actionTile(Icons.edit_rounded, 'Edit', () {
                      Navigator.pop(ctx);
                      _startEditingMessage(msg);
                    }),
                  actionTile(
                    Icons.delete_outline_rounded,
                    'Delete',
                    () {
                      Navigator.pop(ctx);
                      () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Delete message?'),
                            content: const Text(
                                'This message will be removed from favorites.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx2, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade700),
                                onPressed: () => Navigator.pop(ctx2, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
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

  List<ContextMenuButtonItem>? _buildDesktopMenuItems(ChatMessage msg) {
    if (!isDesktop) return null;
    final text = msg.content;
    final isImage = text.startsWith('IMAGEv1:');
    final isAlbum = text.startsWith('ALBUMv1:');
    final isVideo = text.toUpperCase().startsWith('VIDEOV1:');
    final isVoice = text.startsWith('VOICEv1:');
    final isFile = text.startsWith('FILEv1:') || text.startsWith('FILE:');
    final isSaveable = isImage || isAlbum || isVideo || isVoice || isFile;
    final isMedia = isSaveable || text.startsWith('[cannot-decrypt');
    return [
      ContextMenuButtonItem(
        label: 'Reply',
        onPressed: () => _startReplyingToMessage({
          'id': msg.id,
          'sender': msg.from,
          'senderDisplayName': msg.from,
          'content': msg.content,
        }),
      ),
      ContextMenuButtonItem(
        label: 'React',
        onPressed: () {
          final favKey =
              '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
          final me = rootScreenKey.currentState?.currentUsername ?? msg.from;
          openEmojiPicker(context, favKey, me, onAfterToggle: (_, __) {
            _persistReactionForFav(favKey, msg);
          });
        },
      ),
      ContextMenuButtonItem(
        label: _isFavMsgPinned(msg) ? 'Unpin' : 'Pin',
        onPressed: () => _toggleFavPin(msg),
      ),
      if (isSaveable)
        ContextMenuButtonItem(
          label: 'Save',
          onPressed: () => _saveMediaFromMessage(text),
        ),
      if (isImage)
        ContextMenuButtonItem(
          label: 'Copy Image',
          onPressed: () => copyMessageImageToClipboard(text, (m) => rootScreenKey.currentState?.showSnack(m)),
        ),
      if (!isMedia)
        ContextMenuButtonItem(
          label: 'Copy',
          type: ContextMenuButtonType.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            rootScreenKey.currentState?.showSnack('Copied');
          },
        ),
      if (!isMedia)
        ContextMenuButtonItem(
          label: 'Edit',
          onPressed: () => _startEditingMessage(msg),
        ),
      ContextMenuButtonItem(
        label: 'Delete',
        type: ContextMenuButtonType.delete,
        onPressed: () => _desktopDeleteFavorite(msg),
      ),
    ];
  }

  Future<void> _saveMediaFromMessage(String content) async {
    if (kIsWeb) { rootScreenKey.currentState?.showSnack('Save not supported on web'); return; }
    try {
      if (content.startsWith('IMAGEv1:')) {
        final data = jsonDecode(content.substring('IMAGEv1:'.length)) as Map<String, dynamic>;
        final filename = data['url'] as String? ?? data['filename'] as String? ?? '';
        if (filename.isEmpty) return;
        final cached = imageFileCache[filename];
        if (cached == null) { rootScreenKey.currentState?.showSnack('Image not loaded yet'); return; }
        await _saveFileToDevice(cached.file, p.basename(filename));
        return;
      }
      if (content.startsWith('VOICEv1:')) {
        final meta = jsonDecode(content.substring('VOICEv1:'.length)) as Map<String, dynamic>;
        final filename = meta['url'] as String? ?? meta['filename'] as String? ?? '';
        final orig = meta['orig'] as String? ?? p.basename(filename);
        if (filename.isEmpty) return;
        final localPath = mediaFilePathRegistry[filename];
        if (localPath == null) { rootScreenKey.currentState?.showSnack('Voice not loaded yet'); return; }
        String saveName = orig.isNotEmpty ? orig : p.basename(localPath);
        if (p.extension(saveName).isEmpty) saveName = saveName + p.extension(localPath);
        await _saveFileToDevice(File(localPath), saveName);
        return;
      }
      if (content.toUpperCase().startsWith('VIDEOV1:')) {
        final meta = jsonDecode(content.substring('VIDEOv1:'.length)) as Map<String, dynamic>;
        final filename = meta['url'] as String? ?? meta['filename'] as String? ?? '';
        final orig = meta['orig'] as String? ?? p.basename(filename);
        if (filename.isEmpty) return;
        final localPath = mediaFilePathRegistry[filename];
        if (localPath == null) { rootScreenKey.currentState?.showSnack('Video not loaded yet'); return; }
        await _saveFileToDevice(File(localPath), orig.isNotEmpty ? orig : p.basename(localPath));
        return;
      }
      if (content.startsWith('FILEv1:') || content.startsWith('FILE:')) {
        final String filename;
        final String orig;
        if (content.startsWith('FILEv1:')) {
          final meta = jsonDecode(content.substring('FILEv1:'.length)) as Map<String, dynamic>;
          filename = meta['filename'] as String? ?? '';
          orig = meta['orig'] as String? ?? p.basename(filename);
        } else {
          filename = content.substring('FILE:'.length).trim();
          orig = p.basename(filename);
        }
        if (filename.isEmpty) return;
        final localPath = mediaFilePathRegistry[filename];
        if (localPath == null) { rootScreenKey.currentState?.showSnack('File not loaded yet'); return; }
        await _saveFileToDevice(File(localPath), orig.isNotEmpty ? orig : p.basename(localPath));
        return;
      }
      if (content.startsWith('ALBUMv1:')) {
        final list = jsonDecode(content.substring('ALBUMv1:'.length)) as List<dynamic>;
        final items = list.whereType<Map<String, dynamic>>().toList();
        if (items.isEmpty) return;
        int saved = 0, failed = 0;
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          for (final item in items) {
            final filename = item['filename'] as String? ?? '';
            final cached = imageFileCache[filename];
            if (cached == null) { failed++; continue; }
            try {
              final ok = await GallerySaver.saveImage(cached.file.path, albumName: 'ONYX');
              if (ok == true) saved++; else failed++;
            } catch (_) { failed++; }
          }
          rootScreenKey.currentState?.showSnack(
            failed == 0 ? 'All $saved images saved to gallery' : '$saved saved, $failed failed');
          return;
        }
        if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
          final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to save all images');
          if (dirPath == null || dirPath.isEmpty) { rootScreenKey.currentState?.showSnack('Save cancelled'); return; }
          for (final item in items) {
            final filename = item['filename'] as String? ?? '';
            final orig = (item['orig'] as String?)?.isNotEmpty == true ? item['orig'] as String : p.basename(filename);
            final cached = imageFileCache[filename];
            if (cached == null) { failed++; continue; }
            try { await cached.file.copy(p.join(dirPath, orig)); saved++; } catch (_) { failed++; }
          }
          rootScreenKey.currentState?.showSnack(
            failed == 0 ? 'All $saved images saved to: $dirPath' : '$saved saved, $failed failed');
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
        final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'].contains(ext);
        final isVideo = ['.mp4', '.mov', '.avi', '.webm', '.m4v', '.mkv'].contains(ext);
        if (isImage) {
          final saved = await GallerySaver.saveImage(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        } else if (isVideo) {
          final saved = await GallerySaver.saveVideo(file.path, albumName: 'ONYX');
          rootScreenKey.currentState?.showSnack(saved == true ? 'Saved to gallery' : 'Failed to save to gallery');
        } else {
          final dl = await getDownloadsDirectory();
          if (dl == null) { rootScreenKey.currentState?.showSnack('Cannot access Downloads directory'); return; }
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
          final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to save');
          if (dirPath == null) { rootScreenKey.currentState?.showSnack('Save cancelled'); return; }
          destPath = p.join(dirPath, originalName);
        }
        if (destPath == null || destPath.isEmpty) { rootScreenKey.currentState?.showSnack('Save cancelled'); return; }
        await file.copy(destPath);
        rootScreenKey.currentState?.showSnack('Saved to: $destPath');
      }
    } catch (e) {
      rootScreenKey.currentState?.showSnack('Save failed: $e');
    }
  }

  Future<void> _desktopDeleteFavorite(ChatMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be removed from favorites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx2, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx2, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) _deleteMessage(msg);
  }

  List<_ListItem> _buildMessagesWithDaySeparators(List<ChatMessage> msgs) {
    if (msgs.isEmpty) return [];

    if (_cachedDaySeparatorItems != null &&
        _lastProcessedMessages != null &&
        identical(msgs, _lastProcessedMessages)) {
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
    _lastProcessedMessages = msgs;

    return result;
  }

  void _invalidateDaySeparatorCache() {
    _cachedDaySeparatorItems = null;
    _lastProcessedMessages = null;
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
        final appSupport = await getApplicationSupportDirectory();
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
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete avatar?'),
          content: const Text('This will remove this favorite avatar.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton.tonal(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete')),
          ],
        ),
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit chat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () => changeAvatarInDialog(setDialogState),
                    onLongPress: () => removeAvatarInDialog(setDialogState),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: currentAvatarPath != null &&
                                File(currentAvatarPath!).existsSync()
                            ? Image.file(File(currentAvatarPath!),
                                fit: BoxFit.cover)
                            : ValueListenableBuilder<double>(
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
                                      size: 48,
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
              const SizedBox(height: 24),
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, ___) {
                  final baseColor = SettingsManager.getElementColor(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    brightness,
                  );
                  return TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 50,
                    decoration: InputDecoration(
                      labelText: 'Chat name',
                      hintText: 'Enter chat name',
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: baseColor.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: isUploading
                  ? null
                  : () {
                      final newName = controller.text.trim();
                      if (newName.isEmpty) {
                        root.showSnack('Name cannot be empty');
                        return;
                      }
                      final hasTitleChanged = newName != currentTitle;
                      final hasAvatarChanged =
                          currentAvatarPath != currentFav.avatarPath;
                      if (!hasTitleChanged && !hasAvatarChanged) {
                        Navigator.of(ctx).pop(false);
                        return;
                      }
                      Navigator.of(ctx).pop(true);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    _shouldPreserveExternalFocus = false;
    controller.dispose();
    if (result == true) {
      final newName = controller.text.trim();
      if (currentFav.avatarPath != null && currentAvatarPath == null) {
        try {
          await File(currentFav.avatarPath!).delete();
        } catch (e) { debugPrint('[err] $e'); }
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

  List<Widget> _buildFavoritesInputChildren() {
    return [
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
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Material(
                          shape: const CircleBorder(),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              size: 18,
                            ),
                            onPressed: () {
                              rootScreenKey.currentState?.cancelRecording();
                            },
                            visualDensity: VisualDensity.compact,
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
                    ? Theme.of(context).colorScheme.error.withOpacity(0.12)
                    : Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    isRecording ? Icons.stop : Icons.mic,
                    color: isRecording
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    if (isRecording) {
                      rootScreenKey.currentState?.stopRecordingAndUpload(
                          'fav:${widget.favoriteId}',
                          _replyingToMessage,
                          (task) {
                        task.onComplete = (_) async {
                          if (mounted) setState(() => _pendingUploads.remove(task));
                        };
                        if (mounted) setState(() => _pendingUploads.add(task));
                      });
                      setState(() {
                        debugPrint(
                            '[favorites_screen::mic.send] clearing _replyingToMessage\n${StackTrace.current}');
                        _replyingToMessage = null;
                      });
                    } else {
                      rootScreenKey.currentState?.startRecording();
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          onPressed: () async {
            if (kIsWeb) return;

            List<String>? paths;
            if (Platform.isAndroid || Platform.isIOS) {
              paths = await showMediaPickerSheet(context);
            } else {
              try {
                final result = await FilePicker.platform
                    .pickFiles(type: FileType.any, allowMultiple: true);
                paths = result?.files
                    .map((f) => f.path)
                    .whereType<String>()
                    .toList();
              } catch (e) {
                debugPrint('[Attach] FilePicker error: $e');
                rootScreenKey.currentState?.showSnack('File picker error: $e');
              }
            }
            if (paths == null || paths.isEmpty) return;

            if (paths.length > 1 && paths.every(FileTypeDetector.isImage)) {
              await _sendAlbum(paths);
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
          },
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

              if (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyV) &&
                  (HardwareKeyboard.instance.isControlPressed ||
                   HardwareKeyboard.instance.isMetaPressed)) {
                _handlePasteFromClipboard();
                return;
              }

              if (HardwareKeyboard.instance
                  .isLogicalKeyPressed(LogicalKeyboardKey.enter)) {
                if (!HardwareKeyboard.instance.isShiftPressed) {
                  if (_textCtrl.text.trim().isNotEmpty) {
                    _submitMessage(_textCtrl.text);
                  }
                  return;
                }
                if (HardwareKeyboard.instance.isShiftPressed &&
                    _textCtrl.text.isNotEmpty) {
                  final text = _textCtrl.text;
                  final selection = _textCtrl.selection;
                  _textCtrl.text =
                      '${text.substring(0, selection.start)}\n${text.substring(selection.start)}';
                  _textCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: selection.start + 1));
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).localizeHint('Type something...'),
              hintStyle: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
            onChanged: (_) => _onUserTyping(),
            textInputAction: TextInputAction.none,
            contentInsertionConfiguration: ContentInsertionConfiguration(
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
                    } catch (e) { debugPrint('[err] $e'); }
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
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: IconButton(
          icon: Icon(
            Icons.send,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          onPressed: () => _submitMessage(_textCtrl.text),
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
          padding: EdgeInsets.zero,
        ),
      ),
    ];
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
        flexibleSpace: ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementOpacity,
          builder: (_, opacity, __) {
            return ClipRect(
              child: Container(
                color:
                    Theme.of(context).colorScheme.surface.withOpacity(opacity),
              ),
            );
          },
        ),
        automaticallyImplyLeading: false,
        leading: isDesktop
            ? null
            : ValueListenableBuilder(
                valueListenable: _selectionNotifier,
                builder: (_, sel, __) => sel.active
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _exitFavSelectionMode,
                      )
                    : const BackButton(),
              ),
        title: ValueListenableBuilder(
          valueListenable: _selectionNotifier,
          builder: (_, sel, __) => sel.active
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDesktop)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _exitFavSelectionMode,
                      ),
                    Text('${sel.selected.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )
              : Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: favoritesVersion,
                      builder: (context, _, __) {
                        final fav = rootScreenKey.currentState?.favorites.firstWhere(
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
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: favoritesVersion,
                        builder: (context, _, __) {
                          final currentTitle = rootScreenKey.currentState?.favorites
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
                            child: Text(
                              currentTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                    if (sel.selected.values.any(_isFavTextMessage))
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'Copy',
                        onPressed: _copySelectedFavMessages,
                      ),
                    if (sel.selected.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.forward_rounded),
                        tooltip: 'Forward',
                        onPressed: _forwardSelectedFavMessages,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Delete',
                      onPressed: sel.selected.isNotEmpty ? _confirmDeleteSelectedFav : null,
                    ),
                  ])
                : IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search (Ctrl+F)',
                    onPressed: () { if (_showSearch) { _closeSearch(); } else { _openSearch(); } },
                  ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DragDropZone(
        onFilesDropped: _handleDroppedFiles,
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
                    final provider = FileImage(f);
                    return ValueListenableBuilder<double>(
                      valueListenable: SettingsManager.blurSigma,
                      builder: (_, sigma, __) {
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
            ),
            ValueListenableBuilder<int>(
              valueListenable: chatsVersion,
              builder: (_, __, ___) {
                final rootState = rootScreenKey.currentState;
                if (rootState == null) return const SizedBox();
                final msgs = rootState.chats[_chatId()] ?? [];

                _invalidateDaySeparatorCache();

                if (msgs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: SettingsManager.showAvatarInChats,
                  builder: (_, showAvatar, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: SettingsManager.swapMessageAlignment,
                      builder: (_, swapped, __) {
                        return ValueListenableBuilder<bool>(
                          valueListenable:
                              SettingsManager.alignAllMessagesRight,
                          builder: (_, alignRight, __) {
                            final items = _buildMessagesWithDaySeparators(msgs);

                            // Compute search matches
                            if (_showSearch && _searchQuery.isNotEmpty) {
                              _cachedSearchMatches = items.asMap().entries
                                  .where((e) => e.value is _MessageItem &&
                                      (e.value as _MessageItem).message.content
                                          .toLowerCase().contains(_searchQuery))
                                  .map((e) => e.key)
                                  .toList();
                              final clampedIdx = _cachedSearchMatches.isEmpty ? 0
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

                            return Listener(
                              onPointerDown: (_) {
                                if (!isDesktop) return;
                                _suppressAutoRefocus = true;
                                _focusNode.unfocus();
                              },
                              child: ListView.builder(
                                  controller: _scroll,
                                  reverse: true,
                                  cacheExtent: 800,
                                  addRepaintBoundaries: true,
                                  addAutomaticKeepAlives: true,
                                  padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top +
                                        kToolbarHeight +
                                        (_showSearch ? 64 : 12),
                                    bottom: 72 + MediaQuery.of(context).padding.bottom,
                                  ),
                                  itemCount: _pendingUploads.length + items.length,
                                  itemBuilder: (context, i) {
                                    if (i < _pendingUploads.length) {
                                      final task = _pendingUploads[_pendingUploads.length - 1 - i];
                                      return _buildPendingUploadWidget(task);
                                    }
                                    final adjustedI = i - _pendingUploads.length;
                                    final item = items[adjustedI];
                                    if (item is _DaySeparatorItem) {
                                      
                                      return RepaintBoundary(
                                        child: _buildDaySeparator(
                                            context, item.date),
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
                                    final isSearchMatch = _searchQuery.isNotEmpty &&
                                        msg.content.toLowerCase().contains(_searchQuery);
                                    final isCurrentSearchMatch = isSearchMatch &&
                                        _cachedSearchMatches.isNotEmpty &&
                                        _cachedSearchMatches[_currentMatchIdx] == adjustedI;

                                    final cs = Theme.of(context).colorScheme;
                                    final msgBubble = MessageBubble(
                                      key: ValueKey<String>('mb_inner_$uniqueKey'),
                                      text: msg.content,
                                      outgoing: true,
                                      time: msg.time,
                                      peerUsername: '',
                                      chatMessage: msg,
                                      replyToId: msg.replyToId,
                                      replyToUsername: msg.replyToSender,
                                      replyToContent: msg.replyToContent,
                                      desktopMenuItems: _buildDesktopMenuItems(msg),
                                      highlighted: (msg.serverMessageId != null &&
                                              _replyingToMessage != null &&
                                              _replyingToMessage!['id']?.toString() ==
                                                  (msg.serverMessageId?.toString())) ||
                                          (msg.serverMessageId == null &&
                                              _replyingToMessage != null &&
                                              _replyingToMessage!['localId']?.toString() ==
                                                  msg.id.toString()),
                                      onReplyTap: msg.replyToId != null
                                          ? () => _scrollToFavMessageById(msg.replyToId.toString())
                                          : null,
                                    );
                                    final expensiveChild = AnimatedMessageBubble(
                                        key: ValueKey<String>(animKey),
                                        outgoing: msg.outgoing,
                                        animate: isFirstAppearance &&
                                            SettingsManager.messageAnimationsEnabled.value,
                                        child: RepaintBoundary(child: msgBubble),
                                      );
                                    return ValueListenableBuilder<({bool active, Map<String, ChatMessage> selected})>(
                                      valueListenable: _selectionNotifier,
                                      child: expensiveChild,
                                      builder: (_, sel, bubbleChild) {
                                        final isSelected = sel.selected.containsKey(uniqueKey);
                                        return RawGestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          gestures: {
                                            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                                              () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 250)),
                                              (instance) {
                                                instance.onLongPress = sel.active
                                                    ? () => _toggleFavMessageSelection(msg, uniqueKey)
                                                    : () => _enterFavSelectionMode(msg, uniqueKey);
                                              },
                                            ),
                                          },
                                          child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: sel.active
                                              ? () => _toggleFavMessageSelection(msg, uniqueKey)
                                              : null,
                                          onDoubleTap: sel.active
                                              ? null
                                              : () => _enterFavSelectionMode(msg, uniqueKey),
                                          child: AnimatedContainer(
                                            key: (_scrollTargetId != null && (_scrollTargetId == msg.serverMessageId?.toString() || _scrollTargetId == msg.id)) ? _scrollTargetKey : null,
                                            duration: const Duration(milliseconds: 150),
                                            color: isCurrentSearchMatch
                                                ? cs.primary.withValues(alpha: 0.28)
                                                : isSearchMatch
                                                    ? cs.primary.withValues(alpha: 0.12)
                                                    : isSelected
                                                        ? cs.primaryContainer.withValues(alpha: 0.45)
                                                        : (_scrollHighlightId != null &&
                                                                (_scrollHighlightId == msg.serverMessageId?.toString() ||
                                                                    _scrollHighlightId == msg.id))
                                                            ? cs.primary.withValues(alpha: 0.18)
                                                            : Colors.transparent,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            child: Row(
                                              mainAxisAlignment: swapped ? MainAxisAlignment.start : MainAxisAlignment.end,
                                              children: [
                                                if (sel.active)
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 150),
                                                    margin: const EdgeInsets.only(right: 8),
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
                                                            : cs.outline,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: isSelected
                                                        ? Icon(Icons.check,
                                                            size: 14, color: cs.onPrimary)
                                                        : null,
                                                  ),
                                                Flexible(
                                                  child: GestureDetector(
                                                    onHorizontalDragEnd: isDesktop || sel.active
                                                        ? null
                                                        : (details) {
                                                            final v = details.primaryVelocity;
                                                            if (v != null && v > 300) {
                                                              HapticFeedback.selectionClick();
                                                              _onLongPress(msg);
                                                            } else if (v != null && v < -300) {
                                                              final preview = {
                                                                'id': msg.serverMessageId,
                                                                'localId': msg.id,
                                                                'sender': msg.from,
                                                                'senderDisplayName': msg.from,
                                                                'content': getPreviewText(msg.content),
                                                              };
                                                              _startReplyingToMessage(preview);
                                                              HapticFeedback.selectionClick();
                                                            }
                                                          },
                                                    child: Column(
                                                      crossAxisAlignment: swapped
                                                          ? CrossAxisAlignment.start
                                                          : CrossAxisAlignment.end,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        bubbleChild!,
                                                        MessageReactionBar(
                                                          reactions: reactionsFor(uniqueKey),
                                                          myUsername: rootScreenKey.currentState?.currentUsername ?? msg.from,
                                                          outgoing: !swapped,
                                                          onToggle: (emoji) {
                                                            final me = rootScreenKey.currentState?.currentUsername ?? msg.from;
                                                            toggleReaction(uniqueKey, emoji, me);
                                                            _persistReactionForFav(uniqueKey, msg);
                                                          },
                                                          onAddReaction: (ctx2) {
                                                            final me = rootScreenKey.currentState?.currentUsername ?? msg.from;
                                                            openEmojiPicker(ctx2, uniqueKey, me, onAfterToggle: (_, __) {
                                                              _persistReactionForFav(uniqueKey, msg);
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
            if (_showSearch)
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + (_pinnedMessage != null ? 68.0 : 8.0),
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
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              child: _editingMessage != null
                                  ? ValueListenableBuilder<double>(
                                      valueListenable: SettingsManager.elementBrightness,
                                      builder: (_, brightness, ___) {
                                        final colorScheme = Theme.of(context).colorScheme;
                                        final baseColor = SettingsManager.getElementColor(
                                          colorScheme.surfaceContainerHighest,
                                          brightness,
                                        );
                                        return Container(
                                          constraints: BoxConstraints(maxWidth: width),
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
                                                      _editingMessage!.content,
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
                                                onPressed: _cancelEditingMessage,
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
                                          Theme.of(context).colorScheme.surfaceContainerHighest,
                                          brightness,
                                        );
                                        return Container(
                                          constraints: BoxConstraints(maxWidth: width),
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: baseColor.withValues(alpha: opacity),
                                            borderRadius: BorderRadius.circular(16),
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
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _replyingToMessage![
                                                              'senderDisplayName']
                                                          ?.toString() ??
                                                      _replyingToMessage!['sender']
                                                          ?.toString() ??
                                                      'Unknown',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  getPreviewText(
                                                    (_replyingToMessage!['content'] ??
                                                            '')
                                                        .toString(),
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
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
                                    Theme.of(context).colorScheme.surfaceContainerHighest,
                                    brightness,
                                  );
                                  return Container(
                                    constraints: BoxConstraints(maxWidth: width),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: baseColor.withValues(alpha: opacity),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant
                                            .withValues(alpha: 0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: _buildFavoritesInputChildren(),
                                    ),
                                  );
                                },
                              ),
                        ),
                          ],
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
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Material(
                      color: Colors.transparent,
                      child: ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.elementBrightness,
                        builder: (_, brightness, ___) {
                          final baseColor = SettingsManager.getElementColor(
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                            brightness,
                          );
                          return IconButton(
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            icon: Container(
                              width: 32,
                              height: 32,
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
}
