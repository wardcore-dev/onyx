// lib/screens/chat_screen.dart
import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import '../services/chat_load_optimizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
import '../globals.dart';
import '../widgets/adaptive_blur.dart';
import '../models/chat_message.dart';
import '../managers/account_manager.dart' hide UserInfo;
import '../managers/settings_manager.dart';
import '../managers/unread_manager.dart';
import '../widgets/message_bubble.dart';
import '../widgets/video_message_widget.dart';
import '../widgets/avatar_widget.dart';
import '../call/call_manager.dart';
import '../screens/call_overlay.dart';
import '../managers/user_cache.dart';
import '../screens/settings_tab.dart' show SupportSheet;
import '../widgets/drag_drop_zone.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/album_preview_dialog.dart';
import '../utils/file_utils.dart';
import '../managers/lan_message_manager.dart';
import '../enums/delivery_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

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
    with SingleTickerProviderStateMixin {
  
  static final Set<String> _sessionInputAnimationsShown = {};

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final FocusNode _focusNode;
  Timer? _typingThrottle;
  bool _typingSentRecently = false;
  final Set<String> _alreadyRenderedMessageIds = {};
  late final String _inputHint;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;
  bool _showScrollDownButton = false;
  
  bool _isVisible = false;
  late final AnimationController _enterAnimController;
  late final Animation<double> _enterOpacity;

  String? _droppedFilePath;

  Map<String, dynamic>? _replyingToMessage;

  ChatMessage? _editingMessage;

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

  final List<ChatMessage> _olderMessages = [];
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

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
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() { _editingMessage = null; });
    _textCtrl.clear();
    _focusNode.requestFocus();
  }

  void _showMessageMenu(ChatMessage msg) {
    _focusNode.unfocus();
    final text = msg.content;
    final l = AppLocalizations.of(context);
    
    if (text.startsWith('[cannot-decrypt')) return;

    final isMedia = text.toUpperCase().startsWith('VOICEV1:') ||
        text.toUpperCase().startsWith('IMAGEV1:') ||
        text.toUpperCase().startsWith('VIDEOV1:') ||
        text.toUpperCase().startsWith('FILEV1:') ||
        text.startsWith('ALBUMv1:') ||
        text.startsWith('MEDIA_PROXYv1:');

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
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        _shouldPreserveExternalFocus = false;
      });
    });
  }

  List<ContextMenuButtonItem>? _buildDesktopMenuItems(ChatMessage msg) {
    if (!isDesktop) return null;
    final text = msg.content;
    if (text.startsWith('[cannot-decrypt')) return null;
    final isMedia = text.toUpperCase().startsWith('VOICEV1:') ||
        text.toUpperCase().startsWith('IMAGEV1:') ||
        text.toUpperCase().startsWith('VIDEOV1:') ||
        text.toUpperCase().startsWith('FILEV1:') ||
        text.startsWith('ALBUMv1:') ||
        text.startsWith('MEDIA_PROXYv1:');
    final l = AppLocalizations.of(context);
    return [
      ContextMenuButtonItem(
        label: l.reply,
        onPressed: () => _startReplyingToMessage({
          'id': msg.serverMessageId,
          'localId': msg.id,
          'sender': msg.from,
          'senderDisplayName': msg.from,
          'content': getPreviewText(msg.content),
        }),
      ),
      if (!isMedia)
        ContextMenuButtonItem(
          label: l.copy,
          type: ContextMenuButtonType.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: msg.content));
            rootScreenKey.currentState?.showSnack(l.msgCopied);
          },
        ),
      if (msg.canEditOrDelete && !isMedia)
        ContextMenuButtonItem(
          label: l.edit,
          onPressed: () => _startEditingMessage(msg),
        ),
      if (msg.outgoing)
        ContextMenuButtonItem(
          label: l.delete,
          type: ContextMenuButtonType.delete,
          onPressed: () => _desktopDeleteMessage(msg),
        ),
    ];
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
    final randomIndex = Random().nextInt(_randomHints.length);
    _inputHint = _randomHints[randomIndex];
    _focusNode = FocusNode();

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

    assert(() {
      final rootUser = rootScreenKey.currentState?.currentUsername;
      debugPrint(
          '[ChatScreen.init] widget.myUsername=${widget.myUsername}, root.currentUsername=$rootUser, other=${widget.otherUsername}');
      return true;
    }());

    _scroll.addListener(_onScroll);

    _loadFastChangeSetting();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        
        if (isDesktop) {
          _focusNode.requestFocus();
        }
      }
      
      _markMessagesAsRead();
    });

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        
        if (isDesktop &&
            !recordingNotifier.value &&
            !_shouldPreserveExternalFocus &&
            !_suppressAutoRefocus &&
            ModalRoute.of(context)?.isCurrent == true) {
          _focusNode.requestFocus();
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
    
    FocusScope.of(context).unfocus();

    final cached = UserCache.getSync(username);
    final dp = (cached != null) ? cached.displayName : username;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementOpacity,
          builder: (_, elemOpacity, __) {
            final colorScheme = Theme.of(ctx).colorScheme;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Dialog(
                  backgroundColor:
                      colorScheme.surface.withValues(alpha: elemOpacity),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarWidget(
                          username: username,
                          tokenProvider: avatarTokenProvider,
                          avatarBaseUrl: serverBase,
                          size: 96.0,
                          editable: false,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dp,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: '@$username'));
                            rootScreenKey.currentState
                                ?.showSnack(AppLocalizations.of(context).copiedUsername(username));
                          },
                          child: Text('@$username',
                              style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                FocusScope.of(context)
                                    .requestFocus(_focusNode);
                              },
                              icon: const Icon(Icons.message),
                              label: Text(AppLocalizations.of(context).message),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ],
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
  }

  void _onScroll() {
    final atBottom = _scroll.position.pixels <= 1.0;
    if (mounted && _showScrollDownButton != !atBottom) {
      setState(() {
        _showScrollDownButton = !atBottom;
      });
    }
    if (SettingsManager.messagePaginationEnabled.value &&
        _hasMoreMessages &&
        !_isLoadingMore &&
        _scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
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
      if (mounted) setState(() { _hasMoreMessages = false; });
      return;
    }

    if (mounted) setState(() { _isLoadingMore = true; });

    try {
      final older = await ChatLoadOptimizer().loadOlderMessages(
          widget.myUsername, widget.otherUsername, oldestId);
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        if (older.isEmpty) {
          _hasMoreMessages = false;
        } else {
          _olderMessages.addAll(older);
        }
      });
    } catch (e) {
      debugPrint('[loadMoreMessages] $e');
      if (mounted) setState(() { _isLoadingMore = false; });
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUsername != widget.otherUsername) {
      _alreadyRenderedMessageIds.clear();
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
      chatsVersion.value++;
    }

    unreadManager.markAsRead(chatId);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    _typingThrottle?.cancel();
    _enterAnimController.dispose();
    _inputEntryController.dispose();
    super.dispose();
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
      _focusNode.requestFocus();
    }
  }

  Future<void> _submitMessage(String value) async {
    
    if (value.trim().isEmpty) return;

    final content = value.trim();

    if (_editingMessage != null) {
      final editing = _editingMessage!;
      final serverId = editing.serverMessageId;
      if (serverId != null) {
        setState(() { _editingMessage = null; });
        _textCtrl.clear();
        _focusNode.requestFocus();
        await widget.onEditMessage(serverId, content);
      }
      return;
    }

    if (_isLANMode) {
      
      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      final int? replyId = _replyingToMessage != null && _replyingToMessage!['id'] != null
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
            ? (_replyingToMessage!['senderDisplayName'] ?? _replyingToMessage!['sender'])?.toString()
            : null,
        replyToContent: _replyingToMessage != null
            ? (_replyingToMessage!['content'])?.toString()
            : null,
        deliveryMode: DeliveryMode.lan,
      );

      final sent = await _lanManager.sendMessage(message, widget.otherUsername);
      if (!sent) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedSendLan);
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
    _focusNode.requestFocus();
    
    setState(() {
      debugPrint(
          '[chat_screen::submitMessage] clearing _replyingToMessage\n${StackTrace.current}');
      _replyingToMessage = null;
    });
    _scrollToBottom();
  }

  Future<void> _showDeliveryModeDialog() async {
    final l = AppLocalizations.of(context);
    final lanEnabledMsg = l.lanModeEnabled;
    final internetEnabledMsg = l.internetModeEnabled;
    final userNotInLanMsg = l.deliveryUserNotInLan;
    
    if (_fastChangeMode) {
      final lanAvailable = _lanManager.isUserAvailableInLAN(widget.otherUsername);
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
                    color: _lanManager.isUserAvailableInLAN(widget.otherUsername)
                        ? null
                        : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  _lanManager.isUserAvailableInLAN(widget.otherUsername)
                      ? l.deliveryLanSubtitle
                      : l.deliveryUserNotInLan,
                  style: TextStyle(
                    color: _lanManager.isUserAvailableInLAN(widget.otherUsername)
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
                      l.replyingTo(replyTo['senderDisplayName'] ?? replyTo['sender'] ?? '?'),
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
            _focusNode.requestFocus();
          }
        });
      }

      _scrollToBottom();
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
        PopupMenuItem<String>(value: 'copy', child: Text(AppLocalizations.of(context).copy)),
      ],
      elevation: 8,
    ).then((value) {
      if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: text));
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).msgCopied);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        _shouldPreserveExternalFocus = false;
      });
    });
  }

  List<_ListItem> _buildMessagesWithDaySeparators(List<ChatMessage> msgs) {
    if (msgs.isEmpty) return [];

    final currentHash = msgs.length.hashCode ^ (msgs.isNotEmpty ? msgs.last.id.hashCode : 0);

    if (_cachedMessages != null && _cachedMessagesHash == currentHash && _cachedItems != null) {
      debugPrint('[ChatScreen] Using CACHED items (${_cachedItems!.length} items, hash: $currentHash)');
      return _cachedItems!;
    }

    debugPrint('[ChatScreen] Building NEW items list from ${msgs.length} messages (hash changed: $_cachedMessagesHash → $currentHash)');

    if (_alreadyRenderedMessageIds.isEmpty && msgs.isNotEmpty) {
      for (final msg in msgs) {
        final uniqueKey =
            '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
        _alreadyRenderedMessageIds.add(uniqueKey);
      }
    }

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
    final me = rootScreenKey.currentState?.currentUsername ?? widget.myUsername;
    final List<String> ids = [me, widget.otherUsername]..sort();
    final String chatId = ids.join(':');

    return DragDropZone(
      onFilesDropped: _handleDroppedFiles,
      child: FadeTransition(
        opacity: _enterOpacity,
        child: _isVisible
            ? Scaffold(
                extendBodyBehindAppBar: true,
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
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withOpacity(opacity),
                ),
              );
            },
          ),
          title: Row(
            children: [
              GestureDetector(
                onTap: () => _showUserProfileDialog(widget.otherUsername),
                onLongPress: () => _showUserProfileDialog(widget.otherUsername),
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
                    final userInfo = UserCache.getSync(widget.otherUsername);
                    final displayName =
                        userInfo?.displayName ?? widget.otherUsername;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _showUserProfileDialog(widget.otherUsername),
                          onLongPress: () =>
                              _showUserProfileDialog(widget.otherUsername),
                          child: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        
                        AnimatedBuilder(
                          animation: _combinedHeaderListenable,
                          builder: (context, child) {
                            
                            final typing = typingUsersNotifier.value.contains(widget.otherUsername);
                            if (typing) {
                              return const Text(
                                'typing...',
                                style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                              );
                            }

                            final isConnected = wsConnectedNotifier.value;
                            if (!isConnected) {
                              return const Text(
                                'no connection (auto mode)',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              );
                            }

                            final online = onlineUsersNotifier.value.contains(widget.otherUsername);
                            final statuses = userStatusNotifier.value;
                            final visMap = userStatusVisibilityNotifier.value;

                            final visibilityEntry = visMap.containsKey(widget.otherUsername)
                                ? visMap[widget.otherUsername]
                                : null;

                            if (visibilityEntry == 'hide') {
                              return const SizedBox.shrink();
                            }

                            final customStatus = statuses[widget.otherUsername];

                            if (customStatus != null && customStatus.isNotEmpty) {
                              return Builder(
                                builder: (ctx) {
                                  final statusColor = online
                                      ? const Color(0xFF2ECC71)
                                      : Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.9);
                                  return Text(
                                    customStatus,
                                    style: TextStyle(fontSize: 12, color: statusColor),
                                  );
                                },
                              );
                            }

                            if (visibilityEntry == 'show') {
                              final statusText = online ? 'online' : 'offline';
                              return Builder(
                                builder: (ctx) {
                                  final statusColor = online
                                      ? const Color(0xFF2ECC71)
                                      : Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.9);
                                  return Text(
                                    statusText,
                                    style: TextStyle(fontSize: 12, color: statusColor),
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
                                    style: TextStyle(fontSize: 12, color: statusColor),
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
          actions: [
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
                              title: Text(AppLocalizations.of(context).voiceCallsTitle),
                              content: Text(AppLocalizations.of(context).voiceCallsContent),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dCtx).pop(false),
                                  child: Text(AppLocalizations.of(context).cancel),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(dCtx).pop(false);
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => const SupportSheet(),
                                    );
                                  },
                                  child: Text(AppLocalizations.of(context).supportOnyxBtn),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(dCtx).pop(true),
                                  child: Text(AppLocalizations.of(context).call),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            callManager.startCall(widget.otherUsername!);
                          }
                        },
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.shield, size: 20),
              onPressed: () async {
                final recipient = widget.otherUsername;
                final secTitle = AppLocalizations.of(context).securityCheckTitle;
                final secContent = AppLocalizations.of(context).securityCheckContent(recipient);
                final closeLabel = AppLocalizations.of(context).close;
                String? theirPubB64;
                String? myPubB64;
                final token = await AccountManager.getToken(widget.myUsername);
                try {
                  final results = await Future.wait([
                    http.get(
                      Uri.parse('$serverBase/pubkey/$recipient'),
                      headers: {'authorization': 'Bearer $token'},
                    ),
                    http.get(
                      Uri.parse('$serverBase/pubkey/${widget.myUsername}'),
                      headers: {'authorization': 'Bearer $token'},
                    ),
                  ]);
                  if (results[0].statusCode == 200) {
                    theirPubB64 = (jsonDecode(results[0].body))['pubkey'] as String?;
                  }
                  if (results[1].statusCode == 200) {
                    myPubB64 = (jsonDecode(results[1].body))['pubkey'] as String?;
                  }
                } catch (e) {
                  rootScreenKey.currentState
                      ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedToFetchPubkey);
                  return;
                }
                if (theirPubB64 == null) {
                  rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).userHasNoPubkey);
                  return;
                }
                if (myPubB64 == null) {
                  rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).userHasNoPubkey);
                  return;
                }
                if (!mounted) return;

                final myUsername = widget.myUsername;
                final otherUsername = widget.otherUsername;
                final List<String> sortedNames = [myUsername, otherUsername]
                  ..sort();
                final List<int> myPubBytes = base64Decode(myPubB64);
                final List<int> theirPubBytes = base64Decode(theirPubB64);
                final List<int> keyA =
                    sortedNames[0] == myUsername ? myPubBytes : theirPubBytes;
                final List<int> keyB =
                    sortedNames[0] == myUsername ? theirPubBytes : myPubBytes;
                final combined = Uint8List.fromList([...keyA, ...keyB]);
                final hash = dart_crypto.sha256.convert(combined).bytes;
                final indices = [hash[0], hash[1], hash[2], hash[3]];

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

                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(secTitle),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            secContent,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: emojis
                                .map((e) => Text(
                                      e,
                                      style: const TextStyle(fontSize: 48),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(closeLabel),
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
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
            ),
            ValueListenableBuilder<int>(
              valueListenable: chatsVersion,
              builder: (_, chatsVer, ___) {
                debugPrint('[ChatScreen] ValueListenableBuilder rebuild: chatsVersion=$chatsVer, chatId=$chatId');
                final rootState = rootScreenKey.currentState;
                if (rootState == null) return const SizedBox();
                final mainMsgs = rootState.chats[chatId] ?? [];
                final msgs = [...mainMsgs, ..._olderMessages];
                debugPrint('[ChatScreen] Messages count for $chatId: ${msgs.length}');
                if (msgs.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context).noMessagesYet));
                }

                final items = _buildMessagesWithDaySeparators(msgs);

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
                                      addAutomaticKeepAlives: false, 
                                      padding: EdgeInsets.only(
                                          top: MediaQuery.of(context)
                                                  .padding
                                                  .top +
                                              kToolbarHeight +
                                              12,
                                          bottom: 72 + MediaQuery.of(context).padding.bottom),
                                      itemCount: items.length + (_isLoadingMore || _hasMoreMessages ? 1 : 0),
                                      itemBuilder: (context, i) {
                                        if (i == items.length) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: _isLoadingMore
                                                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                                                : const SizedBox.shrink(),
                                          );
                                        }
                                        final item = items[i];

                                        if (item is _DaySeparatorItem) {
                                          return _buildDaySeparator(
                                              context, item.date);
                                        } else if (item is _UnreadMarkerItem) {
                                          return _buildUnreadMarker(context);
                                        } else if (item is _MessageItem) {
                                          final msg = item.message;
                                          final String uniqueKey =
                                              '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
                                          
                                          final bool isFirstAppearance =
                                              !_alreadyRenderedMessageIds
                                                  .contains(uniqueKey);
                                          if (isFirstAppearance) {
                                            _alreadyRenderedMessageIds
                                                .add(uniqueKey);
                                            
                                            debugPrint('[Chat Animation] New message detected: outgoing=${msg.outgoing}, isFirstAppearance=true, key=$uniqueKey');
                                          }

                                          final isIncoming = !msg.outgoing;
                                          
                                          final shouldShowRight = alignRight
                                              ? !swapped
                                              : (swapped
                                                  ? isIncoming
                                                  : msg.outgoing);

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 12),
                                            child: Row(
                                              mainAxisAlignment: shouldShowRight
                                                  ? MainAxisAlignment.end
                                                  : MainAxisAlignment.start,
                                              children: [
                                                Flexible(
                                                  child: isFirstAppearance
                                                      ? _AnimatedMessageBubble(
                                                          key: ValueKey<String>(
                                                              uniqueKey),
                                                          child:
                                                              RepaintBoundary(
                                                            child:
                                                                GestureDetector(
                                                              onTapDown: (tap) {
                                                                debugPrint(
                                                                    '[chat_screen::msgTapDown] tapped message id=${msg.serverMessageId ?? msg.id} replying=${_replyingToMessage != null} reply=${_replyingToMessage?.toString()}\n${StackTrace.current}');
                                                              },
                                                              onHorizontalDragEnd: isDesktop ? null : (details) {
                                                                final v = details.primaryVelocity;
                                                                if (v != null && v > 300) {
                                                                  HapticFeedback.selectionClick();
                                                                  _showMessageMenu(msg);
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
                                                              child:
                                                                  MessageBubble(
                                                                key: ValueKey<
                                                                        String>(
                                                                    'mb_inner_$uniqueKey'),
                                                                text:
                                                                    msg.content,
                                                                outgoing: msg
                                                                    .outgoing,
                                                                rawPreview: msg
                                                                    .rawEnvelopePreview,
                                                                serverMessageId:
                                                                    msg.serverMessageId,
                                                                time: msg.time,
                                                                onRequestResend:
                                                                    (id) => widget
                                                                        .onRequestResend(
                                                                            id),

                                                                desktopMenuItems: _buildDesktopMenuItems(msg),
                                                                peerUsername: widget
                                                                    .otherUsername,
                                                                chatMessage: msg,
                                                                replyToId: msg
                                                                    .replyToId,
                                                                replyToUsername:
                                                                    msg.replyToSender,
                                                                replyToContent:
                                                                    msg.replyToContent,
                                                                highlighted: (msg
                                                                                .serverMessageId !=
                                                                            null &&
                                                                        _replyingToMessage !=
                                                                            null &&
                                                                        _replyingToMessage!['id']?.toString() ==
                                                                            (msg.serverMessageId
                                                                                ?.toString())) ||
                                                                    (msg.serverMessageId ==
                                                                            null &&
                                                                        _replyingToMessage !=
                                                                            null &&
                                                                        _replyingToMessage!['localId']?.toString() ==
                                                                            msg.id?.toString()),
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      : RepaintBoundary(
                                                          child:
                                                              GestureDetector(
                                                            onHorizontalDragEnd: isDesktop ? null : (details) {
                                                              final v = details.primaryVelocity;
                                                              if (v != null && v > 300) {
                                                                HapticFeedback.selectionClick();
                                                                _showMessageMenu(msg);
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
                                                            child:
                                                                MessageBubble(
                                                              key: ValueKey<
                                                                      String>(
                                                                  'mb_inner_$uniqueKey'),
                                                              text: msg.content,
                                                              outgoing:
                                                                  msg.outgoing,
                                                              rawPreview: msg
                                                                  .rawEnvelopePreview,
                                                              serverMessageId: msg
                                                                  .serverMessageId,
                                                              time: msg.time,
                                                              onRequestResend:
                                                                  (id) => widget
                                                                      .onRequestResend(
                                                                          id),

                                                              desktopMenuItems: _buildDesktopMenuItems(msg),
                                                              peerUsername: widget
                                                                  .otherUsername,
                                                              chatMessage: msg,
                                                              replyToId:
                                                                  msg.replyToId,
                                                              replyToUsername: msg
                                                                  .replyToSender,
                                                              replyToContent: msg
                                                                  .replyToContent,
                                                              highlighted: (msg
                                                                              .serverMessageId !=
                                                                          null &&
                                                                      _replyingToMessage !=
                                                                          null &&
                                                                      _replyingToMessage!['id']
                                                                              ?.toString() ==
                                                                          (msg.serverMessageId
                                                                              ?.toString())) ||
                                                                  (msg.serverMessageId == null &&
                                                                      _replyingToMessage !=
                                                                          null &&
                                                                      _replyingToMessage!['localId']
                                                                              ?.toString() ==
                                                                          msg.id
                                                                              ?.toString()),
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                              ],
                                            ),
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
                    );
              },
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
                                        final baseColor = SettingsManager.getElementColor(
                                          Theme.of(context).colorScheme.surfaceContainerHighest,
                                          brightness,
                                        );
                                        final colorScheme = Theme.of(context).colorScheme;
                                        return Container(
                                          constraints: BoxConstraints(maxWidth: width),
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: baseColor.withValues(alpha: opacity),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: colorScheme.primary.withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_rounded, size: 16, color: colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Editing',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: colorScheme.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      getPreviewText(_editingMessage!.content),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 18),
                                                onPressed: _cancelEditing,
                                                visualDensity: VisualDensity.compact,
                                                splashRadius: 18,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                                children: [
                                  ValueListenableBuilder<bool>(
                                    valueListenable: recordingNotifier,
                                    builder: (context, isRecording, _) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedOpacity(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            opacity: isRecording ? 1.0 : 0.0,
                                            child: isRecording
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 6.0),
                                                    child: Material(
                                                      shape:
                                                          const CircleBorder(),
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .errorContainer,
                                                      child: IconButton(
                                                        icon: Icon(
                                                          Icons.delete,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onErrorContainer,
                                                          size: 18,
                                                        ),
                                                        onPressed: () {
                                                          debugPrint(
                                                              '<<TRASH PRESSED>> cancel recording');
                                                          rootScreenKey
                                                              .currentState
                                                              ?.cancelRecording();
                                                        },
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        splashRadius: 20,
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                          Material(
                                            shape: const CircleBorder(),
                                            color: isRecording
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                    .withOpacity(0.12)
                                                : Colors.transparent,
                                            child: IconButton(
                                              icon: Icon(
                                                isRecording
                                                    ? Icons.stop
                                                    : Icons.mic,
                                                color: isRecording
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .error
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                debugPrint(
                                                    '<<MIC BUTTON PRESSED>> isRecording=$isRecording');
                                                if (isRecording) {
                                                  rootScreenKey.currentState
                                                      ?.stopRecordingAndUpload(
                                                          widget.otherUsername,
                                                          _replyingToMessage);
                                                  
                                                  setState(() {
                                                    debugPrint(
                                                        '[chat_screen::mic.send] clearing _replyingToMessage\n${StackTrace.current}');
                                                    _replyingToMessage = null;
                                                  });
                                                } else {
                                                  rootScreenKey.currentState
                                                      ?.startRecording();
                                                }
                                              },
                                              visualDensity:
                                                  VisualDensity.compact,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      if (!kIsWeb) {
                                        try {
                                        final picker = FilePicker.platform;
                                        final result = await picker.pickFiles(
                                            type: FileType.any,
                                            allowMultiple: true);
                                        if (result == null ||
                                            result.files.isEmpty) return;

                                        final paths = result.files
                                            .map((f) => f.path)
                                            .whereType<String>()
                                            .toList();
                                        if (paths.isEmpty) {
                                          rootScreenKey.currentState?.showSnack(
                                              'Web upload not supported');
                                          return;
                                        }

                                        if (paths.length > 1 &&
                                            paths.every(FileTypeDetector.isImage)) {
                                          await _sendAlbum(paths);
                                          return;
                                        }

                                        final path = paths.first;
                                        final basename = p.basename(path);
                                        final ext =
                                            p.extension(basename).toLowerCase();

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

                                        _showFilePreviewAndSend(
                                            path, basename, ext, fileType);
                                        } catch (e) {
                                          debugPrint('[Attach] FilePicker error: $e');
                                          rootScreenKey.currentState?.showSnack(
                                              'File picker error: $e');
                                        }
                                      } else {
                                        rootScreenKey.currentState?.showSnack(
                                            'Attachment upload: desktop/mobile only');
                                      }
                                    },
                                    visualDensity: VisualDensity.compact,
                                    splashRadius: 20,
                                    padding: EdgeInsets.zero,
                                  ),

                                  Expanded(
                                    child: RawKeyboardListener(
                                      focusNode: FocusNode(),
                                      onKey: (event) async {
                                        
                                        if (event.isKeyPressed(LogicalKeyboardKey.keyV) &&
                                            (event.isControlPressed || event.isMetaPressed)) {
                                          await _handlePasteFromClipboard();
                                          return;
                                        }

                                        if (event.isKeyPressed(
                                            LogicalKeyboardKey.enter)) {
                                          if (!event.isShiftPressed) {
                                            
                                            if (_textCtrl.text
                                                .trim()
                                                .isNotEmpty) {
                                              _submitMessage(_textCtrl.text);
                                            }
                                            
                                            return;
                                          }
                                          
                                          if (event.isShiftPressed &&
                                              _textCtrl.text.isNotEmpty) {
                                            final text = _textCtrl.text;
                                            final selection =
                                                _textCtrl.selection;
                                            _textCtrl.text = text.substring(
                                                    0, selection.start) +
                                                '\n' +
                                                text.substring(selection.start);
                                            _textCtrl.selection =
                                                TextSelection.fromPosition(
                                                    TextPosition(
                                                        offset:
                                                            selection.start +
                                                                1));
                                          }
                                        }
                                      },
                                      child: TextField(
                                        focusNode: _focusNode,
                                        controller: _textCtrl,
                                        onTap: () => _suppressAutoRefocus = false,
                                        maxLines: null,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: AppLocalizations.of(context).localizeHint(_inputHint),
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
                                              const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 12,
                                          ),
                                        ),
                                        
                                        onChanged: (_) => _onUserTyping(),
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
                                                } catch (_) {}
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
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _submitMessage(_textCtrl.text),
                                        onLongPress: () => _showDeliveryModeDialog(),
                                        customBorder: const CircleBorder(),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            _isLANMode ? Icons.router : Icons.send,
                                            color: _isLANMode
                                                ? Colors.green
                                                : Theme.of(context).colorScheme.primary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
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
                      child: Stack(
                        children: [
                          ValueListenableBuilder<double>(
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
                          ListenableBuilder(
                            listenable: unreadManager,
                            builder: (context, _) {
                              final me =
                                  rootScreenKey.currentState?.currentUsername ??
                                      widget.myUsername;
                              final List<String> ids = [
                                me,
                                widget.otherUsername
                              ]..sort();
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
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
                ),
              ),
            ),
          ],
        ),
      )
            : const SizedBox.shrink(), 
      ),
    );
  }

  Future<void> _handleDroppedFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    if (filePaths.length > 1 && filePaths.every(FileTypeDetector.isImage)) {
      await _sendAlbum(filePaths);
      return;
    }

    final filePath = filePaths.first;
    final file = File(filePath);
    if (!await file.exists()) {
      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
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
  }

  static const _clipboardChannel = MethodChannel('onyx/clipboard');

  Future<void> _handlePasteFromClipboard() async {
    try {
      
      List<Object?>? rawPaths;
      try {
        rawPaths = await _clipboardChannel.invokeMethod<List<Object?>>('getClipboardFilePaths');
      } catch (_) {}
      final filePaths = rawPaths?.whereType<String>().where((s) => s.isNotEmpty).toList();
      if (filePaths != null && filePaths.isNotEmpty) {
        debugPrint('[clipboard] File paths from clipboard: $filePaths');
        _handleDroppedFiles(filePaths);
        return;
      }

      Uint8List? imageBytes;
      try {
        imageBytes = await _clipboardChannel.invokeMethod<Uint8List>('getClipboardImage');
      } catch (_) {}
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
            rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileCancelled);
          },
        ),
      );
    } else {
      
      _sendFile(filePath, basename, ext, fileType);
    }
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
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'ext': ext, 'size': bytes.length, 'contentType': contentType}),
    );
    if (presignResp.statusCode == 413) {
      dynamic body;
      try { body = jsonDecode(presignResp.body); } catch (_) {}
      rootScreenKey.currentState?.showSnack(
        body is Map ? (body['detail'] ?? 'Storage quota exceeded') : 'Storage quota exceeded',
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
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'type': type, 'filename': filename, 'to': widget.otherUsername, 'no_notify': true}),
    );
    if (confirmResp.statusCode != 200) {
      debugPrint('[presignUpload] confirm failed: ${confirmResp.statusCode}');
      if (confirmResp.statusCode == 413) {
        dynamic body;
        try { body = jsonDecode(confirmResp.body); } catch (_) {}
        rootScreenKey.currentState?.showSnack(
          body is Map ? (body['detail'] ?? 'Storage quota exceeded') : 'Storage quota exceeded',
        );
      }
      return null;
    }
    return filename;
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
      
      try {
        final token = await AccountManager.getToken(
            rootScreenKey.currentState?.currentUsername ?? '');
        if (token == null) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
          return;
        }

        final localFile = File(filePath);
        if (!await localFile.exists()) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
          return;
        }

        final length = await localFile.length();
        if (length == 0) {
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileEmpty);
          return;
        }

        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingFile(basename));

        final plainBytes = await localFile.readAsBytes();
        final root = rootScreenKey.currentState;
        if (root == null) {
          rootScreenKey.currentState?.showSnack('RootScreen not ready');
          return;
        }

        final (encryptedBytes, fileMediaKeyB64) = await root.encryptMediaRandom(
            plainBytes, kind: 'file');

        final filename = await _presignUpload(
          token: token,
          type: 'file',
          ext: p.extension(basename).toLowerCase(),
          contentType: 'application/octet-stream',
          bytes: encryptedBytes,
        );
        if (filename == null) {
          if (mounted) rootScreenKey.currentState?.showSnack('Upload failed');
          return;
        }

        final content = 'FILEv1:${jsonEncode({'filename': filename, 'owner': widget.myUsername, 'orig': basename, 'key': fileMediaKeyB64})}';
        await widget.onSend(content, _replyingToMessage);
        
        if (mounted) {
          setState(() {
            debugPrint(
                '[chat_screen::file.send] clearing _replyingToMessage\n${StackTrace.current}');
            _replyingToMessage = null;
          });
          rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileSent);
        }
      } catch (e) {
        if (mounted) {
          rootScreenKey.currentState?.showSnack('Error: $e');
        }
      }
    }
  }

  Future<void> _sendFileLAN(String filePath, String basename, String fileType) async {
    try {
      debugPrint('[LAN SEND] Starting - filePath: "$filePath", basename: "$basename", fileType: $fileType');

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[LAN SEND] ERROR: Source file not found');
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }

      final fileBytes = await file.readAsBytes();
      debugPrint('[LAN SEND] Read ${fileBytes.length} bytes from source');

      final appDocuments = await getApplicationDocumentsDirectory();
      final lanMediaDir = Directory('${appDocuments.path}/lan_media');
      if (!await lanMediaDir.exists()) {
        await lanMediaDir.create(recursive: true);
        debugPrint('[LAN SEND] Created lan_media directory');
      }

      final localLanFile = File('${lanMediaDir.path}/$basename');
      await localLanFile.writeAsBytes(fileBytes, flush: true);
      debugPrint('[LAN SEND] Saved locally to: ${localLanFile.path} (exists: ${await localLanFile.exists()})');

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
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).failedSendLan);
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
        content = 'VOICEv1:${jsonEncode({'url': 'lan://$basename', 'duration': duration, 'format': format})}';
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
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileSentLan);
      }
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack('Error sending via LAN: $e');
      }
    }
  }

  Future<void> _sendImage(String filePath, String basename, String ext) async {
    MediaType? contentType;
    if (ext == '.jpg' || ext == '.jpeg')
      contentType = MediaType('image', 'jpeg');
    else if (ext == '.png')
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
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
        return;
      }

      final ok = await (rootScreenKey.currentState?.checkQuotaAndPrompt(
            limitMb: 10.0,
            includeImageCache: false,
          ) ??
          Future.value(true));
      if (!ok) return;

      final localFile = File(filePath);
      if (!await localFile.exists()) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }

      final length = await localFile.length();
      if (length == 0) {
        rootScreenKey.currentState?.showSnack('File is empty');
        return;
      }

      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingFile(basename));

      final plainBytes = await localFile.readAsBytes();
      final root = rootScreenKey.currentState;
      if (root == null) {
        rootScreenKey.currentState?.showSnack('RootScreen not ready');
        return;
      }

      final (encryptedBytes, imageMediaKeyB64) = await root
          .encryptMediaRandom(plainBytes, kind: 'image');

      final filename = await _presignUpload(
        token: token,
        type: 'image',
        ext: ext,
        contentType: '${contentType.type}/${contentType.subtype}',
        bytes: encryptedBytes,
      );
      if (filename == null) {
        if (mounted) rootScreenKey.currentState?.showSnack('Upload failed');
        return;
      }

      try {
        final appSupport = await getApplicationSupportDirectory();
        final cacheDir = Directory('${appSupport.path}/image_cache');
        await cacheDir.create(recursive: true);
        final sourceFile = File(filePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy('${cacheDir.path}/$filename');
        }
      } catch (e) {
        debugPrint('[chat_screen] Failed to copy image to cache: $e');
      }

      final meta = jsonEncode({'filename': filename, 'owner': widget.myUsername, 'orig': basename, 'key': imageMediaKeyB64});
      final content = 'IMAGEv1:$meta';
      final replyTo = _replyingToMessage;

      if (mounted) setState(() { _replyingToMessage = null; });

      await widget.onSend(content, replyTo);

      if (mounted) rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).imageSent);
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack('Error: $e');
      }
    }
  }

  Future<void> _deleteAlbumFiles(String content) async {
    try {
      final items = (jsonDecode(content.substring('ALBUMv1:'.length)) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final filenames = items
          .map((m) => m['filename'] as String? ?? '')
          .where((f) => f.isNotEmpty && !f.startsWith('http') && !f.startsWith('lan://'))
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
      'FILEv1:':  'file',
      'AUDIOv1:': 'file',
    };
    String? type;
    String? filename;
    for (final entry in typeMap.entries) {
      if (content.startsWith(entry.key)) {
        type = entry.value;
        try {
          final meta = jsonDecode(content.substring(entry.key.length)) as Map<String, dynamic>;
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

  Future<void> _sendAlbum(List<String> filePaths) async {
    final limited = filePaths.take(10).toList();
    if (limited.isEmpty) return;

    if (SettingsManager.confirmFileUpload.value) {
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
      final token = await AccountManager.getToken(
          rootScreenKey.currentState?.currentUsername ?? '');
      if (token == null) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
        return;
      }

      final ok = await (rootScreenKey.currentState?.checkQuotaAndPrompt(
            limitMb: 10.0 * limited.length,
            includeImageCache: false,
          ) ??
          Future.value(true));
      if (!ok) return;

      rootScreenKey.currentState
          ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingImages(limited.length));

      final appSupport = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/image_cache');
      await cacheDir.create(recursive: true);

      final albumItems = <Map<String, String>>[];

      for (final filePath in limited) {
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

        final (encryptedBytes, albumItemKeyB64) = await root
            .encryptMediaRandom(plainBytes, kind: 'image');

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

        albumItems.add({'filename': filename, 'owner': widget.myUsername, 'orig': basename, 'key': albumItemKeyB64});
      }

      if (albumItems.isEmpty) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).albumUploadFailed);
        return;
      }

      final content = 'ALBUMv1:${jsonEncode(albumItems)}';
      final replyTo = _replyingToMessage;

      if (mounted) setState(() { _replyingToMessage = null; });

      await widget.onSend(content, replyTo);

      if (mounted) {
        rootScreenKey.currentState
            ?.showSnack(AppLocalizations(SettingsManager.appLocale.value).albumSent(albumItems.length));
      }
    } catch (e) {
      if (mounted) rootScreenKey.currentState?.showSnack('Error: $e');
    }
  }

  Future<void> _sendVideo(String filePath, String basename, String ext) async {
    MediaType? contentType;
    if (ext == '.mp4')
      contentType = MediaType('video', 'mp4');
    else if (ext == '.mov')
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
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
        return;
      }

      final ok = await (rootScreenKey.currentState?.checkQuotaAndPrompt(
            limitMb: 100.0,
            includeImageCache: false,
          ) ??
          Future.value(true));
      if (!ok) return;

      final localFile = File(filePath);
      if (!await localFile.exists()) {
        rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).fileNotFound);
        return;
      }

      final length = await localFile.length();
      if (length == 0) {
        rootScreenKey.currentState?.showSnack('File is empty');
        return;
      }

      rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).uploadingFile(basename));

      final plainBytes = await localFile.readAsBytes();
      final root = rootScreenKey.currentState;
      if (root == null) {
        rootScreenKey.currentState?.showSnack('RootScreen not ready');
        return;
      }

      final (encryptedBytes, videoMediaKeyB64) = await root
          .encryptMediaRandom(plainBytes, kind: 'video');

      final filename = await _presignUpload(
        token: token,
        type: 'video',
        ext: ext,
        contentType: '${contentType.type}/${contentType.subtype}',
        bytes: encryptedBytes,
      );
      if (filename == null) {
        if (mounted) rootScreenKey.currentState?.showSnack('Upload failed');
        return;
      }

      final meta = jsonEncode({'filename': filename, 'owner': widget.myUsername, 'orig': basename, 'key': videoMediaKeyB64});
      final content = 'VIDEOv1:$meta';
      final replyTo = _replyingToMessage;

      if (mounted) setState(() { _replyingToMessage = null; });

      await widget.onSend(content, replyTo);

      if (mounted) rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).videoSent);
    } catch (e) {
      if (mounted) {
        rootScreenKey.currentState?.showSnack('Error: $e');
      }
    }
  }
}

class _MessageActionsSheet extends StatefulWidget {
  final ChatMessage msg;
  final bool canEditDelete;
  final bool isMedia;
  
  final bool canAlwaysDelete;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  const _MessageActionsSheet({
    required this.msg,
    required this.canEditDelete,
    required this.isMedia,
    this.canAlwaysDelete = false,
    required this.onReply,
    this.onEdit,
    required this.onCopy,
    this.onDelete,
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
    
    final canAct = widget.canEditDelete && _secondsLeft != 0;

    String editLabel() {
      if (!canAct) return 'Edit';
      if (_secondsLeft > 0) return 'Edit  ·  ${_secondsLeft}s';
      return 'Edit'; 
    }

    String deleteLabel() {
      
      if (widget.canAlwaysDelete) return 'Delete';
      if (!canAct) return 'Delete';
      if (_secondsLeft > 0) return 'Delete  ·  ${_secondsLeft}s';
      return 'Delete'; 
    }

    Widget actionTile(IconData icon, String label, VoidCallback? onTap,
        {Color? color}) {
      final effective = color ?? colorScheme.onSurface;
      return ListTile(
        leading: Icon(icon, color: onTap != null ? effective : colorScheme.onSurface.withValues(alpha: 0.3)),
        title: Text(
          label,
          style: TextStyle(
            color: onTap != null ? effective : colorScheme.onSurface.withValues(alpha: 0.3),
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
            actionTile(Icons.reply_rounded, 'Reply', widget.onReply),
            if (widget.msg.outgoing && !widget.isMedia)
              actionTile(
                Icons.edit_rounded,
                editLabel(),
                canAct ? widget.onEdit : null,
              ),
            if (!widget.isMedia)
              actionTile(Icons.copy_rounded, 'Copy', widget.onCopy),
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

class _AnimatedMessageBubble extends StatelessWidget {
  final Widget child;

  const _AnimatedMessageBubble({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child; 
  }
}