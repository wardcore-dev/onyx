// lib/widgets/chats_tab.dart
import 'dart:async';
import 'dart:convert';
import 'package:ONYX/managers/settings_manager.dart';
import 'package:ONYX/managers/unread_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../globals.dart';
import '../widgets/avatar_widget.dart';
import '../managers/user_cache.dart';
import '../l10n/app_localizations.dart';
import '../managers/blocklist_manager.dart';
import '../managers/mute_manager.dart';

String _getFileTypeLabel(String filename) {
  final ext = filename.toLowerCase();

  if (ext.endsWith('.mp3') ||
      ext.endsWith('.wav') ||
      ext.endsWith('.m4a') ||
      ext.endsWith('.aac') ||
      ext.endsWith('.flac') ||
      ext.endsWith('.wma')) {
    return 'Music';
  }

  if (ext.endsWith('.mp4') ||
      ext.endsWith('.mkv') ||
      ext.endsWith('.mov') ||
      ext.endsWith('.avi') ||
      ext.endsWith('.wmv') ||
      ext.endsWith('.flv') ||
      ext.endsWith('.webm') ||
      ext.endsWith('.m4v')) {
    return 'Video';
  }

  if (ext.endsWith('.jpg') ||
      ext.endsWith('.jpeg') ||
      ext.endsWith('.png') ||
      ext.endsWith('.gif') ||
      ext.endsWith('.webp') ||
      ext.endsWith('.bmp') ||
      ext.endsWith('.svg') ||
      ext.endsWith('.ico')) {
    return 'Image';
  }

  if (ext.endsWith('.pdf') ||
      ext.endsWith('.doc') ||
      ext.endsWith('.docx') ||
      ext.endsWith('.txt') ||
      ext.endsWith('.rtf') ||
      ext.endsWith('.odt')) {
    return 'Document';
  }

  if (ext.endsWith('.xls') ||
      ext.endsWith('.xlsx') ||
      ext.endsWith('.csv') ||
      ext.endsWith('.ods')) {
    return 'Spreadsheet';
  }

  if (ext.endsWith('.ppt') || ext.endsWith('.pptx') || ext.endsWith('.odp')) {
    return 'Presentation';
  }

  if (ext.endsWith('.zip') ||
      ext.endsWith('.rar') ||
      ext.endsWith('.7z') ||
      ext.endsWith('.tar') ||
      ext.endsWith('.gz') ||
      ext.endsWith('.bz2') ||
      ext.endsWith('.iso') ||
      ext.endsWith('.exe') ||
      ext.endsWith('.dmg')) {
    return 'Archive';
  }

  if (ext.endsWith('.js') ||
      ext.endsWith('.py') ||
      ext.endsWith('.java') ||
      ext.endsWith('.cpp') ||
      ext.endsWith('.c') ||
      ext.endsWith('.ts') ||
      ext.endsWith('.dart') ||
      ext.endsWith('.swift') ||
      ext.endsWith('.go') ||
      ext.endsWith('.rb') ||
      ext.endsWith('.php') ||
      ext.endsWith('.sh') ||
      ext.endsWith('.json') ||
      ext.endsWith('.xml') ||
      ext.endsWith('.yaml') ||
      ext.endsWith('.yml') ||
      ext.endsWith('.html') ||
      ext.endsWith('.css')) {
    return 'Artifact';
  }

  return 'File';
}

String getPreviewText(String rawContent) {
  if (rawContent.startsWith('VOICEv1:')) return 'Voice message';
  if (rawContent.startsWith('AUDIOv1:')) return 'Music';
  if (rawContent.startsWith('IMAGEv1:')) return 'Image';
  if (rawContent.startsWith('VIDEOv1:') ||
      rawContent.toUpperCase().startsWith('VIDEOV1:')) {
    return 'Video file';
  }

  if (rawContent.startsWith('MEDIA_PROXYv1:') ||
      rawContent.startsWith('MEDIA_PROXY:')) {
    try {
      final jsonPart = rawContent.substring(rawContent.indexOf(':') + 1);
      final data = jsonDecode(jsonPart) as Map<String, dynamic>;
      final type = (data['type'] as String?)?.toLowerCase();
      final orig =
          (data['orig'] ?? data['filename'] ?? data['name'] ?? '') as String;
      if (type == 'voice') return 'Voice message';
      if (type == 'audio') return 'Music';
      if (type == 'video') return 'Video';
      if (type == 'image') return 'Image';
      if (type == 'album') return 'Album';
      if (orig.isNotEmpty) return _getFileTypeLabel(orig);
      return 'File';
    } catch (e) {
      return 'File';
    }
  }

  if (rawContent.startsWith('FILEv1:') ||
      rawContent.startsWith('DOCUMENTv1:') ||
      rawContent.startsWith('ARCHIVEv1:') ||
      rawContent.startsWith('DATAv1:')) {
    try {
      final jsonPart = rawContent.substring(rawContent.indexOf(':') + 1);
      final meta = jsonDecode(jsonPart) as Map<String, dynamic>;
      final filename = (meta['filename'] ??
          meta['orig'] ??
          meta['name'] ??
          'File') as String;
      return _getFileTypeLabel(filename);
    } catch (e) {
      return 'File';
    }
  }

  if (rawContent.startsWith('FILE:')) {
    final filename = rawContent.substring(5);
    return _getFileTypeLabel(filename);
  }
  if (rawContent.startsWith('ALBUMv1:')) {
    try {
      final list = jsonDecode(rawContent.substring('ALBUMv1:'.length)) as List;
      return 'Album · ${list.length} photos';
    } catch (e) {
      return 'Album';
    }
  }
  if (rawContent.startsWith('[cannot-decrypt]')) {
    return '[Message not decrypted]';
  }
  return rawContent;
}

Widget _glassCard({required BuildContext context, required Widget child}) {
  final cs = Theme.of(context).colorScheme;
  return ValueListenableBuilder<double>(
    valueListenable: SettingsManager.elementOpacity,
    builder: (_, opacity, __) {
      return ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) {
          final baseColor = SettingsManager.getElementColor(
            cs.surfaceContainerHighest,
            brightness,
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: child,
            ),
          );
        },
      );
    },
  );
}

class _ChatSumm {
  final String chatId;
  final String otherUsername;
  final String displayName;
  final DateTime lastTs;
  final String preview;

  const _ChatSumm({
    required this.chatId,
    required this.otherUsername,
    required this.displayName,
    required this.lastTs,
    required this.preview,
  });
}

class _UnreadBadge extends StatelessWidget {
  final String chatId;
  const _UnreadBadge({required this.chatId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: unreadManager,
      builder: (context, _) {
        final count = unreadManager.getUnreadCount(chatId);
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        );
      },
    );
  }
}

class ChatsTab extends StatefulWidget {
  final Map<String, List<ChatMessage>> chats;
  final String? username;
  final void Function(String other) onOpenChat;
  final void Function(String chatId) onDeleteChat;
  final void Function(String username, String displayName) onBlockUser;
  final void Function(String username) onUnblockUser;

  const ChatsTab({
    super.key,
    required this.chats,
    required this.username,
    required this.onOpenChat,
    required this.onDeleteChat,
    required this.onBlockUser,
    required this.onUnblockUser,
  });

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  late final AnimationController _listAnimController;
  late final Animation<double> _listFadeAnim;
  late final AnimationController _screenFadeController;
  late final Animation<double> _screenFadeAnimation;
  bool _isVisible = false;
  final Map<String, _ChatSumm> _byChatId = {};
  late List<_ChatSumm> _summaries;
  VoidCallback? _userUpdateListener;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _listFadeAnim = CurvedAnimation(
      parent: _listAnimController,
      curve: Curves.easeOut,
    );
    _screenFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _screenFadeAnimation = CurvedAnimation(
      parent: _screenFadeController,
      curve: Curves.easeOut,
    );
    _rebuildSummaries();
    _userUpdateListener = () {
      if (!mounted) return;
      setState(_rebuildSummaries);
    };
    UserCache.updatedUsers.addListener(_userUpdateListener!);
    chatsVersion.addListener(_onChatsVersion);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isVisible = true);
      _screenFadeController.forward();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _listAnimController.forward();
      });
    });
  }

  void _onChatsVersion() {
    if (!mounted) return;
    final hints = consumeChatListHints();
    if (hints.isNotEmpty) {
      // Incremental path: only rebuild the summaries for chats that changed.
      setState(() => _rebuildHintedSummaries(hints));
    } else {
      // Full rebuild for account-switch, initial load, etc.
      setState(_rebuildSummaries);
    }
  }

  /// Updates only the summaries for [chatIds] and moves them to the front.
  /// O(k) rebuild + O(n) move-to-front, instead of O(n) rebuild + O(n log n) sort
  /// for every single incoming message.
  void _rebuildHintedSummaries(Set<String> chatIds) {
    final Set<String> usernamesToFetch = <String>{};
    for (final chatId in chatIds) {
      if (chatId.startsWith('fav:')) continue;
      final msgs = widget.chats[chatId];
      if (msgs == null) {
        _byChatId.remove(chatId);
        continue;
      }
      final parts = chatId.split(':');
      final other = parts.firstWhere(
        (p) => p != (widget.username ?? 'me'),
        orElse: () => chatId,
      );
      usernamesToFetch.add(other);
      final prev = _byChatId[chatId];
      final last = msgs.isNotEmpty ? msgs.last : null;
      final lastTs = last?.time ?? DateTime.fromMillisecondsSinceEpoch(0);
      final preview = last != null ? getPreviewText(last.content) : '';
      final cached = UserCache.getSync(other);
      final displayName = (cached != null &&
              cached.displayName.isNotEmpty &&
              cached.displayName != other)
          ? cached.displayName
          : (prev?.displayName ?? other);
      _byChatId[chatId] = _ChatSumm(
        chatId: chatId,
        otherUsername: other,
        displayName: displayName,
        lastTs: lastTs,
        preview: preview,
      );
    }
    // O(n) move-to-front: remove hinted chats from their current positions,
    // then insert them at the front sorted by lastTs (k<<n, usually k=1).
    // Avoids the O(n log n) full re-sort + O(n) list allocation on every send.
    _summaries.removeWhere((s) => chatIds.contains(s.chatId));
    final hinted = <_ChatSumm>[];
    for (final id in chatIds) {
      final s = _byChatId[id];
      if (s != null) hinted.add(s);
    }
    if (hinted.length > 1) {
      hinted.sort((a, b) => b.lastTs.compareTo(a.lastTs));
    }
    _summaries.insertAll(0, hinted);
    _fetchUserProfilesInBackground(usernamesToFetch);
  }

  @override
  void didUpdateWidget(covariant ChatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // chatsVersion listener handles data updates; only rebuild if username changed
    if (widget.username != oldWidget.username) {
      setState(_rebuildSummaries);
    }
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _screenFadeController.dispose();
    if (_userUpdateListener != null) {
      UserCache.updatedUsers.removeListener(_userUpdateListener!);
    }
    chatsVersion.removeListener(_onChatsVersion);
    super.dispose();
  }

  void _rebuildSummaries() {
    _byChatId.removeWhere((chatId, _) => !widget.chats.containsKey(chatId));
    final Set<String> usernamesToFetch = <String>{};
    for (final entry in widget.chats.entries) {
      final chatId = entry.key;
      final msgs = entry.value;
      if (chatId.startsWith('fav:')) continue;
      final parts = chatId.split(':');
      final other = parts.firstWhere(
        (p) => p != (widget.username ?? 'me'),
        orElse: () => chatId,
      );
      usernamesToFetch.add(other);
      final prev = _byChatId[chatId];
      DateTime lastTs = prev?.lastTs ?? DateTime.fromMillisecondsSinceEpoch(0);
      String preview = prev?.preview ?? '';
      if (msgs.isNotEmpty) {
        final last = msgs.last;
        lastTs = last.time;
        preview = getPreviewText(last.content);
      }
      final cached = UserCache.getSync(other);
      String displayName = prev?.displayName ?? other;
      if (cached != null &&
          cached.displayName.isNotEmpty &&
          cached.displayName != other) {
        displayName = cached.displayName;
      }
      _byChatId[chatId] = _ChatSumm(
        chatId: chatId,
        otherUsername: other,
        displayName: displayName,
        lastTs: lastTs,
        preview: preview,
      );
    }
    _summaries = _byChatId.values.toList()
      ..sort((a, b) => b.lastTs.compareTo(a.lastTs));
    _fetchUserProfilesInBackground(usernamesToFetch);
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  void _showDeleteConfirmationDialog(BuildContext context, _ChatSumm summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteChatTitle),
        content: Text(AppLocalizations.of(context).deleteChatContent(summary.displayName)),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDeleteChat(summary.chatId);
            },
            child: Text(
              AppLocalizations.of(context).delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmationDialog(BuildContext context, _ChatSumm summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).blockUserLabel),
        content: Text(AppLocalizations.of(context).blockUserConfirmContent(summary.displayName)),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onBlockUser(summary.otherUsername, summary.displayName);
            },
            child: Text(
              AppLocalizations.of(context).blockUserLabel,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnblockConfirmationDialog(BuildContext context, _ChatSumm summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).unblockUserLabel),
        content: Text(AppLocalizations.of(context).unblockUserConfirmContent(summary.displayName)),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onUnblockUser(summary.otherUsername);
            },
            child: Text(AppLocalizations.of(context).unblockUserLabel),
          ),
        ],
      ),
    );
  }

  void _showChatActionsSheet(BuildContext context, _ChatSumm summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBlocked = BlocklistManager.isBlocked(summary.otherUsername);
    final isMuted = MuteManager.isMuted(summary.otherUsername);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ValueListenableBuilder<double>(
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
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Icon(
                      isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: colorScheme.onSurface,
                    ),
                    title: Text(
                      isMuted
                          ? AppLocalizations.of(context).unmuteUserLabel
                          : AppLocalizations.of(context).muteUserLabel,
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      if (isMuted) {
                        MuteManager.unmute(summary.otherUsername);
                      } else {
                        MuteManager.mute(summary.otherUsername);
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  if (isBlocked)
                    ListTile(
                      leading: Icon(Icons.lock_open_rounded, color: colorScheme.primary),
                      title: Text(AppLocalizations.of(context).unblockUserLabel),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _showUnblockConfirmationDialog(context, summary);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    )
                  else
                    ListTile(
                      leading: Icon(Icons.block, color: colorScheme.error),
                      title: Text(AppLocalizations.of(context).blockUserLabel),
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        _showBlockConfirmationDialog(context, summary);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: colorScheme.error),
                    title: Text(AppLocalizations.of(context).delete),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _showDeleteConfirmationDialog(context, summary);
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDesktopContextMenu(BuildContext context, Offset globalPosition, _ChatSumm summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBlocked = BlocklistManager.isBlocked(summary.otherUsername);
    final isMuted = MuteManager.isMuted(summary.otherUsername);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: isMuted ? 'unmute' : 'mute',
          child: Row(
            children: [
              Icon(
                isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                size: 18,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Text(
                isMuted
                    ? AppLocalizations.of(context).unmuteUserLabel
                    : AppLocalizations.of(context).muteUserLabel,
              ),
            ],
          ),
        ),
        if (isBlocked)
          PopupMenuItem<String>(
            value: 'unblock',
            child: Row(
              children: [
                Icon(Icons.lock_open_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context).unblockUserLabel),
              ],
            ),
          )
        else
          PopupMenuItem<String>(
            value: 'block',
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: colorScheme.error),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context).blockUserLabel),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context).delete),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'mute') {
        MuteManager.mute(summary.otherUsername);
      } else if (value == 'unmute') {
        MuteManager.unmute(summary.otherUsername);
      } else if (value == 'block') {
        _showBlockConfirmationDialog(context, summary);
      } else if (value == 'unblock') {
        _showUnblockConfirmationDialog(context, summary);
      } else if (value == 'delete') {
        _showDeleteConfirmationDialog(context, summary);
      }
    });
  }

  Future<void> _fetchUserProfilesInBackground(Set<String> usernames) async {
    for (final username in usernames) {
      unawaited(UserCache.get(username).catchError((_) {
        return null;
      }));
    }
  }

  static bool _isMediaPreview(String preview) {
    return preview == 'Voice message' ||
        preview == 'Image' ||
        preview == 'Video file' ||
        preview.startsWith('[Message not decrypted]');
  }

  static bool _isPurplePreview(String preview) {
    final purpleLabels = {
      'Voice message',
      'Image',
      'Video file',
      'Music',
      'Video',
      'Image',
      'Document',
      'Spreadsheet',
      'Presentation',
      'Archive',
      'Artifact',
      'File'
    };
    if (preview.startsWith('[Message not decrypted]')) return true;
    if (preview == 'Album' || preview.startsWith('Album ·')) return true;
    return purpleLabels.contains(preview);
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0) {
      return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}.${t.month}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return FadeTransition(
      opacity:
          _isVisible ? _screenFadeAnimation : const AlwaysStoppedAnimation(0.0),
      child: _buildContent(),
    );
  }

  Future<void> _showUserProfileDialog(
      String username, String displayName) async {
    
    FocusScope.of(context).unfocus();

    final cached = UserCache.getSync(username);
    final dp = (cached != null) ? cached.displayName : displayName;
    final desc = (cached != null) ? cached.description : '';

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
                  backgroundColor: colorScheme.surface.withValues(alpha: elemOpacity),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        Text(
                          dp,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 12),
                        AvatarWidget(
                          username: username,
                          tokenProvider: avatarTokenProvider,
                          avatarBaseUrl: serverBase,
                          size: 96.0,
                          editable: false,
                        ),
                        const SizedBox(height: 12),
                        
                        if (desc.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              desc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface.withValues(alpha: 0.8 * elemOpacity),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: '@$username'));
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
                                widget.onOpenChat(username);
                              },
                              icon: const Icon(Icons.message),
                              label: const Text('Message'),
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

  Widget _buildContent() {
    if (_summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Opacity(
              opacity: 0.4,
              child: Icon(Icons.chat_outlined, size: 48),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).noChatsYet,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _listFadeAnim,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
        itemCount: _summaries.length,
        
        cacheExtent: 500,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final it = _summaries[i];
          
          return RepaintBoundary(
            child: GestureDetector(
              onSecondaryTapUp: _isDesktop
                  ? (details) => _showDesktopContextMenu(context, details.globalPosition, it)
                  : null,
              child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: () => _showChatActionsSheet(context, it),
              onTap: () => widget.onOpenChat(it.otherUsername),
              child: _glassCard(
              context: context,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onOpenChat(it.otherUsername),
                      onLongPress: () => _showUserProfileDialog(
                          it.otherUsername, it.displayName),
                      child: ValueListenableBuilder<int>(
                        valueListenable: avatarVersion,
                        builder: (_, __, ___) => AvatarWidget(
                          key: ValueKey('avatar-${it.otherUsername}'),
                          username: it.otherUsername,
                          tokenProvider: avatarTokenProvider,
                          avatarBaseUrl: serverBase,
                          size: 40,
                          editable: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => widget.onOpenChat(it.otherUsername),
                            onLongPress: () => _showUserProfileDialog(
                                it.otherUsername, it.displayName),
                            child: Text(
                              it.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (it.displayName != it.otherUsername)
                            GestureDetector(
                              onTap: () => widget.onOpenChat(it.otherUsername),
                              onLongPress: () => _showUserProfileDialog(
                                  it.otherUsername, it.displayName),
                              child: Text(
                                '@${it.otherUsername}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context).localizePreview(it.preview),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _isPurplePreview(it.preview)
                                  ? FontWeight.w500
                                  : null,
                              color: _isPurplePreview(it.preview)
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: MuteManager.mutedUsers,
                      builder: (_, muted, __) {
                        final isMuted = muted.contains(it.otherUsername);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (it.lastTs.millisecondsSinceEpoch > 0)
                              Text(
                                _formatTime(it.lastTs),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isMuted)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.notifications_off_outlined,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                _UnreadBadge(chatId: it.chatId),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    
                  ],
                ),
              ),
            ),
          ),
          ),
        );
      },
      ),
    );
  }
}