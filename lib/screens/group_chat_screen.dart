// lib/screens/group_chat_screen.dart
import 'package:ONYX/managers/settings_manager.dart';
import '../l10n/app_localizations.dart';
import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import 'package:flutter/material.dart';
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

class _AnimatedMessageBubble extends StatelessWidget {
  final Widget child;
  const _AnimatedMessageBubble({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child; 
  }
}

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
  final Map<String, String> _pendingMessageIds =
      {}; 
  bool _loadedFromCache = false;
  bool _isDisposed = false;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;

  String? _editingMsgId;        
  String? _editingOriginalContent;
  bool _showScrollDownButton = false;
  
  bool _isVisible = false;
  late final AnimationController _enterAnimController;
  late final Animation<double> _enterOpacity;

  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryScaleX;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  final List<Map<String, dynamic>> _wsIncomingBuffer = [];
  Timer? _wsFlushTimer;
  static const int _wsBatchSize = 50;
  static const int _wsBatchDelayMs = 50;

  Map<String, dynamic>? _replyingToMessage;

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

  late int _avatarVersion;

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
    _loadHistoryFromCache().then((_) {
      _loadHistoryFromNetwork();
    });
    _loadMemberCount();
    rootScreenKey.currentState?.subscribeToGroup(widget.group.id, _onGroupMsg);

    _enterAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _enterOpacity = CurvedAnimation(
      parent: _enterAnimController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isVisible = true);
        _enterAnimController.forward();
      }
    });

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
      
      _markMessagesAsRead();
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
    
    final atBottom = _scroll.position.pixels <= 1.0;
    if (mounted && _showScrollDownButton != !atBottom) {
      setState(() {
        _showScrollDownButton = !atBottom;
      });
    }
    
  }

  void _onGroupLongPress(Map<String, dynamic> msg) {
    _focusNode.unfocus();
    final content = msg['content']?.toString() ?? '';
    final isMedia = content.toUpperCase().startsWith('VOICEV1:') ||
        content.toUpperCase().startsWith('IMAGEV1:') ||
        content.toUpperCase().startsWith('VIDEOV1:') ||
        content.toUpperCase().startsWith('MEDIA_PROXYV1:') ||
        content.startsWith('[cannot-decrypt');

    final rawSender = msg['sender']?.toString() ?? '';
    final isMe = rawSender == _currentUsername || rawSender == _currentDisplayName;
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
                    actionTile(Icons.reply_rounded, AppLocalizations.of(context).reply, () {
                      Navigator.pop(ctx);
                      _startReplyingToMessage(msg);
                    }),
                    if (!isMedia)
                      actionTile(Icons.copy_rounded, AppLocalizations.of(context).copy, () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: content));
                        rootScreenKey.currentState?.showSnack(AppLocalizations.of(context).msgCopied);
                      }),
                    if (isMe && !isMedia && msgId != null)
                      actionTile(Icons.edit_rounded, AppLocalizations.of(context).edit, () {
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
                                title: Text(AppLocalizations.of(context).deleteMessageTitle),
                                content: Text(AppLocalizations.of(context).deleteGroupMsgContent),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx2, false),
                                    child: Text(AppLocalizations.of(context).cancel),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red.shade700),
                                    onPressed: () =>
                                        Navigator.pop(ctx2, true),
                                    child: Text(AppLocalizations.of(context).delete,
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

  List<ContextMenuButtonItem>? _buildDesktopMenuItems(Map<String, dynamic> msg) {
    if (!isDesktop) return null;
    final content = msg['content']?.toString() ?? '';
    final rawSender = msg['sender']?.toString() ?? '';
    final isMe = widget.group.isChannel
        ? false
        : (rawSender == _currentUsername || rawSender == _currentDisplayName);
    final msgId = msg['id']?.toString();
    final isMedia = content.toUpperCase().startsWith('VOICEV1:') ||
        content.toUpperCase().startsWith('IMAGEV1:') ||
        content.toUpperCase().startsWith('VIDEOV1:') ||
        content.toUpperCase().startsWith('MEDIA_PROXYV1:') ||
        content.startsWith('[cannot-decrypt');
    final l = AppLocalizations.of(context);
    return [
      ContextMenuButtonItem(
        label: l.reply,
        onPressed: () => _startReplyingToMessage(msg),
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
      if (isMe && msgId != null)
        ContextMenuButtonItem(
          label: l.delete,
          type: ContextMenuButtonType.delete,
          onPressed: () => _desktopDeleteGroupMessage(msg, msgId),
        ),
    ];
  }

  Future<void> _desktopDeleteGroupMessage(Map<String, dynamic> msg, String msgId) async {
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
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedDelete);
      }
    } catch (e) {
      if (mounted) rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedDelete);
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
          final idx =
              _messages.indexWhere((m) => m['id']?.toString() == msgId);
          if (idx >= 0) _messages[idx]['content'] = newContent;
        });
        unawaited(_saveHistoryToCache(_messages));
      } else if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedEdit);
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedEdit);
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
    _isDisposed = true;
    _localRouteObserver.unsubscribe(this);
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    rootScreenKey.currentState?.unsubscribeFromGroup(widget.group.id);
    _pendingMessageIds.clear();
    groupAvatarVersion.removeListener(_onGroupAvatarUpdate);
    _enterAnimController.dispose();
    _inputEntryController.dispose();
    _wsFlushTimer?.cancel();
    super.dispose();
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
      rootScreenKey.currentState?.subscribeToGroup(widget.group.id, _onGroupMsg);

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
      final renderedIds = <String>{};

      for (final item in data) {
        final id = (item['id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          final tsStr = (item['timestamp'] ?? item['created_at'])?.toString() ?? DateTime.now().toIso8601String();
          final tsMs = DateTime.tryParse(tsStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
          final msg = {
            'id': id,
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

          final sender = msg['sender']?.toString() ?? '?';
          final content = msg['content']?.toString() ?? '';
          final uniqueKey = '${msg['timestamp']}_${sender}_${content.hashCode}';
          renderedIds.add(uniqueKey);
        }
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _messages = newMessages;
          _allMessageIds.addAll(seenIds);
          _alreadyRenderedMessageIds.addAll(renderedIds);
          _loadedFromCache = true;
        });
        debugPrint(
            '[GroupChat] Loaded ${newMessages.length} messages from cache');
        for (final msg in newMessages.take(3)) {
          debugPrint(
              '[GroupChat] Cached message: id=${msg['id']}, reply_to_id=${msg['reply_to_id']}, reply_to_sender=${msg['reply_to_sender']}, reply_to_content=${msg['reply_to_content']}');
        }
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
            final tsStr = (item['timestamp'] ?? item['created_at'])?.toString() ?? DateTime.now().toIso8601String();
        final tsMs = DateTime.tryParse(tsStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
        newMessages.add({
              'id': id,
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

        final renderedIds = <String>{};
        for (final msg in newMessages) {
          final sender = msg['sender']?.toString() ?? '?';
          final content = msg['content']?.toString() ?? '';
          final uniqueKey = '${msg['timestamp']}_${sender}_${content.hashCode}';
          renderedIds.add(uniqueKey);
        }

        if (mounted && !_isDisposed) {
          setState(() {
            _messages = newMessages;
            _allMessageIds.clear();
            _allMessageIds.addAll(seenIds);
            _alreadyRenderedMessageIds.clear();
            _alreadyRenderedMessageIds.addAll(renderedIds);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      if (mounted && !_loadedFromCache) {
        rootScreenKey.currentState
            ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).noInternetCached);
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
      if (distance > 200) {
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
    final maxScroll = _scroll.position.maxScrollExtent;
    final current = _scroll.position.pixels;
    if (current >= maxScroll - 120) {
      _scroll.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _markMessagesAsRead() {
    
    final unreadIds = _messages
        .where((m) => m['sender'] != _currentUsername &&
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
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
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).sendFailed);
      }
    }
  }

  Future<String?> _uploadToProvider(
      Uint8List bytes, String filename, MediaProvider provider) async {
    try {
      switch (provider) {
        case MediaProvider.catbox:
          final req = http.MultipartRequest(
              'POST', Uri.parse('https://catbox.moe/user/api.php'));
          req.fields['reqtype'] = 'fileupload';
          req.files.add(http.MultipartFile.fromBytes('fileToUpload', bytes,
              filename: filename));
          final resp = await http.Response.fromStream(await req.send());
          if (resp.statusCode == 200) {
            final body = resp.body.trim();
            if (body.startsWith('http')) return body;
          }
          debugPrint('[upload:catbox] status=${resp.statusCode} body=${resp.body.trim()}');
          return null;
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
        rootScreenKey.currentState
            ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).mediaUploadNotSupportedWeb);
      }
      return;
    }
    FilePickerResult? result;
    try {
      result = await FilePicker.platform
          .pickFiles(type: FileType.any, allowMultiple: true);
    } catch (e) {
      debugPrint('[Attach] FilePicker error: $e');
      if (mounted) rootScreenKey.currentState?.showSnack('File picker error: $e');
      return;
    }
    if (result?.files.isEmpty ?? true) return;

    final paths = result!.files
        .map((f) => f.path)
        .whereType<String>()
        .toList();
    if (paths.isEmpty) {
      if (mounted) rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).localFileRequired);
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
        rootScreenKey.currentState
            ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).unsupportedFileType(p.extension(path)));
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
    if (mounted) {
      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingFile(basename));
    }
    final link = await _uploadToProvider(bytes, basename, provider);
    if (link == null) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadFailed);
      }
      return;
    }

    final fileType = FileTypeDetector.getFileType(filePath);
    final typeMapping = {
      'IMAGE': 'image',
      'VIDEO': 'video',
      'AUDIO': 'audio',
    };
    final type = typeMapping[fileType]?.toLowerCase();

    final payload = jsonEncode({
      'url': link,
      'orig': basename,
      'provider': provider.name,
      if (type != null) 'type': type,
    });
    final content = 'MEDIA_PROXYv1:$payload';
    unawaited(_doSendToServer(content));
  }

  Future<void> _processAndUploadAlbum(List<String> filePaths) async {
    if (_isReadOnlyChannel) return;
    final limited = filePaths.take(10).toList();
    if (limited.isEmpty) return;

    const provider = MediaProvider.catbox;
    if (mounted) {
      rootScreenKey.currentState
          ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingImages(limited.length));
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
      if (mounted) rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).albumUploadFailed);
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

    if (SettingsManager.confirmVoiceUpload.value) {
      
      final durationSeconds = (bytes.length / 16000).ceil();
      final duration = Duration(seconds: durationSeconds);

      if (mounted) {
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => VoiceConfirmDialog(
                duration: duration,
                onSend: () async {
                  final basename = p.basename(path);
                  const provider = MediaProvider.catbox;
                  if (mounted) {
                    rootScreenKey.currentState?.showSnack(
                        AppLocalizations(SettingsManager.appLocale.value).uploadingVoice);
                  }
                  final link =
                      await _uploadToProvider(bytes, basename, provider);
                  if (link == null) {
                    if (mounted) {
                      rootScreenKey.currentState
                          ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).voiceUploadFailed);
                    }
                    return;
                  }
                  final payload = jsonEncode({
                    'url': link,
                    'orig': basename,
                    'provider': provider.name,
                    'type': 'voice',
                  });
                  final content = 'MEDIA_PROXYv1:$payload';
                  unawaited(_doSendToServer(content));
                },
                onCancel: () {
                  if (mounted) {
                    rootScreenKey.currentState
                        ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).voiceCancelled);
                  }
                },
              ),
            ) ??
            false;
      }
    } else {
      
      final basename = p.basename(path);
      const provider = MediaProvider.catbox;
      if (mounted) {
        rootScreenKey.currentState
            ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingVoice);
      }
      final link = await _uploadToProvider(bytes, basename, provider);
      if (link == null) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).voiceUploadFailed);
        }
        return;
      }
      final payload = jsonEncode({
        'url': link,
        'orig': basename,
        'provider': provider.name,
        'type': 'voice',
      });
      final content = 'MEDIA_PROXYv1:$payload';
      unawaited(_doSendToServer(content));
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
    } catch (e) { debugPrint('[err] $e'); }
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
            _messages[msgIndex]['id'] = messageId;
            _messages[msgIndex]['isPending'] = false;
            _allMessageIds.remove(tempMessageId);
            _allMessageIds.add(messageId);
          }
        });
        _scrollToBottomIfNeeded();
        unawaited(_saveHistoryToCache(_messages));
      }
    } else {
      final replyContent = msg['reply_to_content']?.toString() ?? '';
      final tsStr = (msg['timestamp'] ?? msg['created_at'] ?? DateTime.now().toIso8601String()).toString();
      final tsMs = DateTime.tryParse(tsStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
      final newMsg = {
        'id': messageId,
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
      debugPrint('[GroupChat Animation] Batch received: ${toAdd.length}, only last $animateLimit will animate');
    }

    final idsToAdd = <String>[];
    for (final m in toAdd) {
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty) idsToAdd.add(id);
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _messages.addAll(toAdd);
        _allMessageIds.addAll(idsToAdd);
      });
      _scrollToBottomIfNeeded();
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
    } catch (e) { debugPrint('[err] $e'); }
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
          } catch (e) { debugPrint('[err] $e'); }
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).leftGroup);
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedLeaveGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).networkError);
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
        rootScreenKey.currentState
            ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).avatarOnlyOwnerMod);
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
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedReadFile);
        }
        return;
      }
      bytes = file.bytes!;
      filename = file.name;
    } else {
      if (path == null) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).localFileRequired);
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
      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingAvatar);
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
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).avatarUpdatedGroup);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedUpdateGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).networkError);
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
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).avatarDeleted);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedDeleteAvatar);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).networkError);
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
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).avatarUpdatedGroup);
          setState(() {});
        }
      } else {
        if (mounted) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedUpdateGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).networkError);
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
          backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: SettingsManager.elementOpacity.value),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(widget.group.isChannel ? AppLocalizations.of(context).editChannelTitle : AppLocalizations.of(context).editGroupTitle),
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
                    Clipboard.setData(
                        ClipboardData(text: widget.group.inviteLink.split('/').last));
                    if (mounted) {
                      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).tokenCopied);
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
                    rootScreenKey.currentState
                        ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).groupNameLength);
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
                    } catch (e) { debugPrint('[err] $e'); }

                    if (mounted) {
                      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).groupUpdated);
                    }
                    Navigator.of(ctx).pop(true);
                  } else {
                    if (mounted) {
                      rootScreenKey.currentState
                          ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedUpdateGroup);
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).networkError);
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
                                          : (_replyingToMessage!['senderDisplayName']
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
                        color: colorScheme.outlineVariant.withValues(alpha: 0.15),
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
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Material(
                                      shape: const CircleBorder(),
                                      color: colorScheme.errorContainer,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: colorScheme.onErrorContainer,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          debugPrint(
                                              '<<TRASH PRESSED>> cancel recording in group');
                                          rootScreenKey.currentState
                                              ?.cancelRecording();
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
                        maxLines: null,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).localizeHint(_inputHint),
                          hintStyle: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
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
    return FadeTransition(
      opacity: _enterOpacity,
      child: _isVisible
          ? Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: colorScheme.surface,
              appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementOpacity,
          builder: (_, opacity, __) {
            return ClipRect(
              child: Container(
                color: colorScheme.surface.withOpacity(opacity),
              ),
            );
          },
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: _canManageGroup
                  ? _showEditGroupDialog
                  : null,
              onLongPress: _canManageGroup
                  ? () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(AppLocalizations.of(context).deleteAvatarTitle),
                          content: Text(AppLocalizations.of(context).deleteAvatarContent),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(AppLocalizations.of(context).cancel)),
                            FilledButton.tonal(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(AppLocalizations.of(context).delete)),
                          ],
                        ),
                      );
                      if (confirmed == true) await _deleteGroupAvatar();
                    }
                  : null,
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(avatarUrl),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _canManageGroup
                  ? _showEditGroupDialog
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (_memberCount != null)
                    Text(
                      AppLocalizations.of(context).memberCount(_memberCount!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_canManageGroup)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditGroupDialog,
            ),
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.group.inviteLink.split('/').last));
              if (mounted) {
                rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).tokenCopied);
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'leave') {
                final confirmed = await _showLeaveConfirmation(context);
                if (confirmed == true) {
                  await _leaveGroup();
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'leave',
                child: Text(AppLocalizations.of(context).leaveGroupTitle(false)),
              ),
            ],
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
                          valueListenable: SettingsManager.enablePerformanceOptimizations,
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
                            return Listener(
                              onPointerDown: (_) {
                                if (!isDesktop) return;
                                _suppressAutoRefocus = true;
                                _focusNode.unfocus();
                              },
                              child: ListView.builder(
                              controller: _scroll,
                              reverse: true,
                              itemCount: _messages.length,
                              cacheExtent: 100, 
                              addRepaintBoundaries: true,
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top +
                                    kToolbarHeight +
                                    12,
                                bottom: 72 + MediaQuery.of(context).padding.bottom,
                              ),
                              itemBuilder: (ctx, i) {
                                final msg = _messages[_messages.length - 1 - i];
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
                                
                                bool showSenderInfo = !widget.group.isChannel;

                                final bool showAvatarForThisMessage = (() {
                                  if (i + 1 >= _messages.length) return true;
                                  final nextMsg =
                                      _messages[_messages.length - 1 - (i + 1)];
                                  final nextSender =
                                      nextMsg['sender']?.toString() ?? '?';
                                  return nextSender != rawSender;
                                })();

                                final bubble = Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.7),
                                  child: GestureDetector(
                                    onTapDown: (tap) {
                                      debugPrint(
                                          '[group_chat_screen::msgTapDown] tapped message id=${msg['id']} replying=${_replyingToMessage != null} reply=${_replyingToMessage?.toString()}\n${StackTrace.current}');
                                    },
                                    onHorizontalDragEnd: isDesktop ? null : (details) {
                                      final v = details.primaryVelocity;
                                      if (v != null && v > 300) {
                                        HapticFeedback.selectionClick();
                                        _onGroupLongPress(msg);
                                      } else if (v != null && v < -300) {
                                        final preview = {
                                          'id': msg['id']?.toString(),
                                          'sender': rawSender,
                                          'senderDisplayName': sender,
                                          'content': getPreviewText(content),
                                        };
                                        _startReplyingToMessage(preview);
                                        HapticFeedback.selectionClick();
                                      }
                                    },
                                    child: MessageBubble(
                                      key: ValueKey<String>(
                                          'mb_${msg['timestamp']}_${sender}_${content.hashCode}'),
                                      text: content,
                                      outgoing: isMe,
                                      rawPreview: null,
                                      serverMessageId: null,
                                      time:
                                          (msg['timestamp_ms'] != null)
                                              ? DateTime.fromMillisecondsSinceEpoch(msg['timestamp_ms'] as int)
                                              : (DateTime.tryParse(msg['timestamp']) ?? DateTime.now()),
                                      onRequestResend: (_) {},
                                      desktopMenuItems: _buildDesktopMenuItems(msg),
                                      peerUsername: sender,
                                      replyToId: msg['reply_to_id'] is int
                                          ? msg['reply_to_id'] as int
                                          : (msg['reply_to_id'] != null
                                              ? int.tryParse(
                                                  msg['reply_to_id'].toString())
                                              : null),
                                      replyToUsername: msg['reply_to_sender'] != null
                                          ? (widget.group.isChannel
                                              ? widget.group.name
                                              : msg['reply_to_sender'].toString())
                                          : null,
                                      replyToContent:
                                          msg['reply_to_content']?.toString(),
                                      highlighted:
                                          (_replyingToMessage != null &&
                                              _replyingToMessage!['id']
                                                      ?.toString() ==
                                                  msg['id']?.toString()),
                                    ),
                                  ),
                                );
                                final uniqueKey =
                                    '${msg['timestamp']}_${sender}_${content.hashCode}';
                                
                                final isFirstAppearance =
                                    !_alreadyRenderedMessageIds.contains(uniqueKey);
                                if (isFirstAppearance) {
                                  _alreadyRenderedMessageIds.add(uniqueKey);
                                  
                                  debugPrint('[GroupChat Animation] New message detected: sender=$sender, isFirstAppearance=true, key=$uniqueKey');
                                }

                                final bool suppressed = msg['suppressAnimation'] == true;
                                final bubbleWithAnimation = (isFirstAppearance && !suppressed)
                                    ? _AnimatedMessageBubble(key: ValueKey<String>(uniqueKey), child: bubble)
                                    : bubble;
                                if (isFirstAppearance && !suppressed) {
                                  debugPrint('[GroupChat Animation] Animation TRIGGERED for key=$uniqueKey');
                                } else if (isFirstAppearance && suppressed) {
                                  debugPrint('[GroupChat Animation] Animation SUPPRESSED for key=$uniqueKey (batch)');
                                }

                                final bubbleWithContext = bubbleWithAnimation;
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
                                      ),
                                      bubbleWithContext,
                                    ],
                                  );
                                } else {
                                  contentWithSender = bubbleWithContext;
                                }
                                return RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: Align(
                                      alignment: shouldAlignRight
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: contentWithSender,
                                    ),
                                  ),
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
                            valueListenable: SettingsManager.inputBarMaxWidth,
                            builder: (_, width, __) {
                              return ValueListenableBuilder<double>(
                                valueListenable: SettingsManager.elementBrightness,
                                builder: (_, brightness, ___) {
                                  final baseColor = SettingsManager.getElementColor(
                                    colorScheme.surfaceContainerHighest,
                                    brightness,
                                  );
                                  return Container(
                                    constraints: BoxConstraints(maxWidth: width),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: baseColor.withValues(alpha: opacity),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant
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
            AnimatedOpacity(
              opacity: _showScrollDownButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showScrollDownButton,
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
          ],
        ),
      ),
              )
          : const SizedBox.shrink(), 
    );
  }

  Future<void> _handleGroupDroppedFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    final existing = <String>[];
    for (final fp in filePaths) {
      if (await File(fp).exists()) {
        existing.add(fp);
      } else {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
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
        rawPaths = await _clipboardChannel.invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (e) { debugPrint('[err] $e'); }
      final filePaths = rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        debugPrint('[clipboard] File paths from clipboard: $filePaths');
        _handleGroupDroppedFiles(filePaths);
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
      showDialog(
        context: context,
        builder: (_) => FilePreviewDialog(
          filePath: filePath,
          onSend: () => _sendGroupFile(filePath, basename, ext),
          onCancel: () {
            rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileCancelled);
          },
        ),
      );
    } else {
      
      _sendGroupFile(filePath, basename, ext);
    }
  }

  Future<void> _sendGroupFile(
    String filePath,
    String basename,
    String ext,
  ) async {
    await _processAndUploadFile(filePath);
  }
}