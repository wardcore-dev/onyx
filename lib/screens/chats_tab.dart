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
import '../l10n/app_localizations_extra.dart';
import '../managers/blocklist_manager.dart';
import '../managers/mute_manager.dart';
import '../managers/lock_manager.dart';
import '../dialogs/pin_lock_dialog.dart';
import '../widgets/adaptive_glass_card.dart';
import '../widgets/animated_reorder_list.dart';
import '../widgets/tab_pull_search.dart';
import '../widgets/inline_search_bar.dart';
import '../utils/dialog_utils.dart';
import '../enums/delivery_mode.dart';
import '../services/mesh/mesh_manager.dart';
import '../widgets/onyx_dialog.dart';

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

/// Returns a human-readable preview for a message, correctly distinguishing
/// mesh voice recordings (voice_*.m4a) from music file attachments.
String _meshAwarePreview(dynamic msg) {
  // msg is ChatMessage but we avoid importing the type here; use dynamic.
  if (msg == null) return '';
  final content = (msg.content as String?) ?? '';
  // Mesh file transfers: use MIME type + filename to pick the right label.
  if (content.startsWith('MESH_FILE:')) {
    final filename = content.substring(10);
    final mime = (msg.meshFileMimeType as String?) ?? '';
    if (mime.startsWith('audio/') || mime.startsWith('video/')) {
      // Voice recordings produced by the mic have filename prefix "voice_".
      final base = filename.contains('/') ? filename.split('/').last : filename;
      if (base.startsWith('voice_')) return 'Voice message';
    }
    return _getFileTypeLabel(filename);
  }
  return getPreviewText(content);
}

String getPreviewText(String rawContent) {
  if (rawContent.startsWith('MESH_FILE:')) {
    return _getFileTypeLabel(rawContent.substring(10));
  }
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


class _ChatSumm {
  final String chatId;
  final String otherUsername;
  final String displayName;
  final DateTime lastTs;
  final String preview;
  final bool isBle;
  /// 'wifi' | 'ble' | null — actual transport of the last mesh message.
  final String? meshTransportUsed;

  const _ChatSumm({
    required this.chatId,
    required this.otherUsername,
    required this.displayName,
    required this.lastTs,
    required this.preview,
    this.isBle = false,
    this.meshTransportUsed,
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

/// Wraps a chat row with a soft highlight ring while [pendingHighlightChat]
/// points at [username] — surfaces the target of a notification tap even
/// when the forced auto-navigation into ChatScreen never fires (lost race
/// with the PIN lock screen, or the OS never redelivers the tap). Fades out
/// on its own after a few seconds so it doesn't linger if the user ignores
/// it, and clears immediately once the chat is actually opened (see
/// _openChatWithLockCheck).
class _ChatHighlightRing extends StatefulWidget {
  final String username;
  final Widget child;
  const _ChatHighlightRing({required this.username, required this.child});

  @override
  State<_ChatHighlightRing> createState() => _ChatHighlightRingState();
}

class _ChatHighlightRingState extends State<_ChatHighlightRing> {
  Timer? _autoClearTimer;

  @override
  void dispose() {
    _autoClearTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoClear() {
    _autoClearTimer?.cancel();
    _autoClearTimer = Timer(const Duration(seconds: 6), () {
      if (pendingHighlightChat.value == widget.username) {
        pendingHighlightChat.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: pendingHighlightChat,
      builder: (context, highlighted, child) {
        final isHighlighted = highlighted == widget.username;
        if (isHighlighted) {
          _scheduleAutoClear();
        } else {
          _autoClearTimer?.cancel();
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ChatsTab extends StatefulWidget {
  final Map<String, List<ChatMessage>> chats;
  final String? username;
  final void Function(String other) onOpenChat;
  final void Function(String chatId, String displayName) onDeleteChat;
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

class _ChatsTabState extends State<ChatsTab> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, RouteAware {

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

  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey _searchBarKey = GlobalKey();
  String _searchQuery = '';
  List<TabSearchResult> _searchResults = [];

  // While a chat screen is open on top of this tab, new-message reorders are
  // held back (only the row's content is refreshed in place) so the user
  // sees the "jump to top" animation play when they come back to the list,
  // instead of finding the chat already at the top.
  bool _routeIsCurrent = true;
  final Set<String> _pendingBumpIds = {};
  ModalRoute<void>? _subscribedRoute;

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
    final Set<String> updatedIds = <String>{};
    for (final chatId in chatIds) {
      if (chatId.startsWith('fav:')) continue;
      final msgs = widget.chats[chatId];
      if (msgs == null) {
        _byChatId.remove(chatId);
        _summaries.removeWhere((s) => s.chatId == chatId);
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
      final preview = last != null ? _meshAwarePreview(last) : '';
      final isBle = last?.deliveryMode == DeliveryMode.bleMesh;
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
        isBle: isBle,
        meshTransportUsed: last?.meshTransportUsed,
      );
      updatedIds.add(chatId);
    }

    if (_routeIsCurrent) {
      _bumpToFront(updatedIds);
    } else {
      // A chat screen is open on top of the list: refresh each row's content
      // in place (so preview/time stay correct) without reordering, and
      // remember to animate the jump-to-top once the user returns to the list.
      for (final id in updatedIds) {
        final idx = _summaries.indexWhere((s) => s.chatId == id);
        final s = _byChatId[id];
        if (idx != -1 && s != null) _summaries[idx] = s;
      }
      _pendingBumpIds.addAll(updatedIds);
    }
    _fetchUserProfilesInBackground(usernamesToFetch);
  }

  /// Moves [chatIds] to the front of `_summaries`, ordered by their lastTs
  /// (k<<n, usually k=1) — avoids a full O(n log n) re-sort on every message.
  void _bumpToFront(Set<String> chatIds) {
    if (chatIds.isEmpty) return;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      _subscribedRoute = route;
      if (route != null) routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // A chat screen (or similar) opened on top of the list — hold off on
    // animating reorders until the user comes back to look at it.
    _routeIsCurrent = false;
  }

  @override
  void didPopNext() {
    _routeIsCurrent = true;
    if (_pendingBumpIds.isNotEmpty && mounted) {
      final ids = Set<String>.from(_pendingBumpIds);
      _pendingBumpIds.clear();
      setState(() => _bumpToFront(ids));
    }
  }

  @override
  void didUpdateWidget(covariant ChatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.username != oldWidget.username ||
        !identical(widget.chats, oldWidget.chats)) {
      setState(_rebuildSummaries);
    }
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _screenFadeController.dispose();
    _searchCtrl.dispose();
    if (_userUpdateListener != null) {
      UserCache.updatedUsers.removeListener(_userUpdateListener!);
    }
    chatsVersion.removeListener(_onChatsVersion);
    if (_subscribedRoute != null) routeObserver.unsubscribe(this);
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
      bool isBle = prev?.isBle ?? false;
      String? meshTransportUsed;
      if (msgs.isNotEmpty) {
        final last = msgs.last;
        lastTs = last.time;
        preview = _meshAwarePreview(last);
        isBle = last.deliveryMode == DeliveryMode.bleMesh;
        meshTransportUsed = last.meshTransportUsed;
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
        isBle: isBle,
        meshTransportUsed: meshTransportUsed,
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

  void _showDeleteConfirmationDialog(BuildContext context, _ChatSumm summary) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.deleteChatTitle,
      message: l.deleteChatContent(summary.displayName),
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      LockManager.removeLock('dm_${summary.otherUsername}');
      widget.onDeleteChat(summary.chatId, summary.displayName);
    }
  }

  void _showBlockConfirmationDialog(BuildContext context, _ChatSumm summary) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.blockUserLabel,
      message: l.blockUserConfirmContent(summary.displayName),
      confirmLabel: l.blockUserLabel,
      isDestructive: true,
      icon: Icons.block_rounded,
    );
    if (confirmed == true) {
      widget.onBlockUser(summary.otherUsername, summary.displayName);
    }
  }

  void _showUnblockConfirmationDialog(BuildContext context, _ChatSumm summary) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.unblockUserLabel,
      message: l.unblockUserConfirmContent(summary.displayName),
      confirmLabel: l.unblockUserLabel,
      icon: Icons.lock_open_rounded,
    );
    if (confirmed == true) {
      widget.onUnblockUser(summary.otherUsername);
    }
  }

  Widget Function(BuildContext, double) _chatAvatarBuilder(_ChatSumm summ) {
    return (context, size) => AvatarWidget(
          key: ValueKey('search_avatar-${summ.otherUsername}'),
          username: summ.otherUsername,
          tokenProvider: avatarTokenProvider,
          avatarBaseUrl: serverBase,
          size: size,
          editable: false,
        );
  }

  Future<List<TabSearchResult>> _searchChats(String query) async {
    final lower = query.toLowerCase();
    final nameHits = <TabSearchResult>[];
    final contentHits = <TabSearchResult>[];
    final chats = rootScreenKey.currentState?.chats;

    outer:
    for (final summ in _summaries) {
      final avatarBuilder = _chatAvatarBuilder(summ);
      final nameMatch = summ.displayName.toLowerCase().contains(lower) ||
          summ.otherUsername.toLowerCase().contains(lower);
      if (nameMatch) {
        nameHits.add(TabSearchResult(
          id: summ.otherUsername,
          title: summ.displayName,
          subtitle: '@${summ.otherUsername}',
          snippet: summ.preview.isNotEmpty ? summ.preview : null,
          icon: Icons.person_outline,
          avatarBuilder: avatarBuilder,
        ));
        continue;
      }

      final history = chats?[summ.chatId];
      if (history == null || history.isEmpty) continue;
      // One card per matching message — chats are intentionally not deduped,
      // so a chat with several hits shows up as several separate cards.
      for (var i = history.length - 1; i >= 0; i--) {
        final content = history[i].content;
        if (content.toLowerCase().contains(lower)) {
          contentHits.add(TabSearchResult(
            id: summ.otherUsername,
            title: summ.displayName,
            subtitle: '@${summ.otherUsername}',
            snippet: getPreviewText(content),
            icon: Icons.forum_outlined,
            avatarBuilder: avatarBuilder,
            messageId: history[i].id,
          ));
          if (nameHits.length + contentHits.length >= 30) break outer;
        }
      }
    }

    return [...nameHits, ...contentHits].take(30).toList();
  }

  void _onSearchResultTap(TabSearchResult result) {
    _searchCtrl.clear();
    setState(() { _searchQuery = ''; _searchResults = []; });
    if (result.messageId != null) {
      final ids = [widget.username ?? 'me', result.id]..sort();
      setPendingMessageScrollTarget(ids.join(':'), result.messageId!);
    }
    _openChatWithLockCheck(context, result.id);
  }

  Future<void> _openChatWithLockCheck(BuildContext ctx, String username) async {
    // Clears a notification-tap highlight regardless of how the user got
    // here — manually opening the chat makes the highlight moot.
    if (pendingHighlightChat.value == username) pendingHighlightChat.value = null;
    final lockId = 'dm_$username';
    if (!LockManager.isLocked(lockId) || LockManager.isSessionUnlocked(lockId)) {
      widget.onOpenChat(username);
      return;
    }
    final ok = await showPinDialog(ctx, PinDialogMode.verify, lockId);
    if (ok && mounted) {
      widget.onOpenChat(username);
    }
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
                borderRadius: BorderRadius.circular(28),
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
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: LockManager.lockedChats,
                    builder: (_, locked, __) {
                      final lockId = 'dm_${summary.otherUsername}';
                      final isLocked = locked.contains(lockId);
                      return ListTile(
                        leading: Icon(
                          isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(isLocked ? 'Unlock chat' : 'Lock chat'),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          if (isLocked) {
                            final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
                            if (ok) await LockManager.removeLock(lockId);
                          } else {
                            final set = await showPinDialog(context, PinDialogMode.set, lockId);
                            if (!set) return;
                            await LockManager.lock(lockId);
                          }
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    },
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
        PopupMenuItem<String>(
          value: LockManager.isLocked('dm_${summary.otherUsername}') ? 'unlock' : 'lock',
          child: Row(
            children: [
              Icon(
                LockManager.isLocked('dm_${summary.otherUsername}') ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 18,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Text(LockManager.isLocked('dm_${summary.otherUsername}') ? 'Unlock chat' : 'Lock chat'),
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
    ).then((value) async {
      if (!context.mounted) return;
      if (value == 'mute') {
        MuteManager.mute(summary.otherUsername);
      } else if (value == 'unmute') {
        MuteManager.unmute(summary.otherUsername);
      } else if (value == 'block') {
        _showBlockConfirmationDialog(context, summary);
      } else if (value == 'unblock') {
        _showUnblockConfirmationDialog(context, summary);
      } else if (value == 'lock') {
        final lockId = 'dm_${summary.otherUsername}';
        final set = await showPinDialog(context, PinDialogMode.set, lockId);
        if (!set) return;
        await LockManager.lock(lockId);
      } else if (value == 'unlock') {
        final lockId = 'dm_${summary.otherUsername}';
        final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
        if (ok) await LockManager.removeLock(lockId);
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
    await unfocusAndSettle(context);
    if (!mounted) return;

    final cached = UserCache.getSync(username);
    final dp = (cached != null) ? cached.displayName : displayName;
    final desc = (cached != null) ? cached.description : '';

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
                              widget.onOpenChat(username);
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

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;
    if (trimmed.isEmpty) {
      setState(() { _searchQuery = ''; _searchResults = []; });
      return;
    }
    final results = await _searchChats(trimmed);
    if (!mounted) return;
    setState(() { _searchQuery = trimmed; _searchResults = results; });
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

    final cs = Theme.of(context).colorScheme;
    final bottomPad = 8 + MediaQuery.paddingOf(context).bottom;
    final searchBar = InlineSearchBar(
      key: _searchBarKey,
      controller: _searchCtrl,
      onChanged: _onSearchChanged,
      hintText: AppLocalizations.of(context).searchChatsHint,
      hasText: _searchQuery.isNotEmpty,
    );

    if (_searchQuery.isNotEmpty) {
      return CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: searchBar),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad),
            sliver: SliverList.builder(
              itemCount: _searchResults.length,
              itemBuilder: (ctx, i) {
                final r = _searchResults[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () => _onSearchResultTap(r),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          r.avatarBuilder?.call(ctx, 40) ??
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: cs.primary.withValues(alpha: 0.15),
                                child: Icon(r.icon, size: 18, color: cs.primary),
                              ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (r.snippet != null)
                                  Text(r.snippet!, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return FadeTransition(
      opacity: _listFadeAnim,
      child: AnimatedReorderList<_ChatSumm>(
        items: _summaries,
        keyOf: (it) => it.chatId,
        header: searchBar,
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        separatorHeight: 6,
        itemBuilder: (context, it, i) {
          return _ChatHighlightRing(
            username: it.otherUsername,
            child: RepaintBoundary(
            child: GestureDetector(
              onSecondaryTapUp: _isDesktop
                  ? (details) => _showDesktopContextMenu(context, details.globalPosition, it)
                  : null,
              child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onLongPress: () => _showChatActionsSheet(context, it),
              onTap: () => _openChatWithLockCheck(context, it.otherUsername),
              child: AdaptiveGlassCard(
              borderRadius: 28,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openChatWithLockCheck(context, it.otherUsername),
                      onLongPress: () => _showUserProfileDialog(
                          it.otherUsername, it.displayName),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ValueListenableBuilder<int>(
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
                          // Online dot: only while actually connected (a stale
                          // onlineUsersNotifier from before a disconnect would
                          // otherwise show everyone as online) and only when
                          // the contact hasn't hidden their status from us —
                          // same two conditions chat_screen.dart's header
                          // status line checks for this contact.
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: ListenableBuilder(
                              listenable: Listenable.merge([
                                onlineUsersNotifier,
                                wsConnectedNotifier,
                                userStatusVisibilityNotifier,
                              ]),
                              builder: (_, __) {
                                if (!wsConnectedNotifier.value) {
                                  return const SizedBox.shrink();
                                }
                                final hidden = userStatusVisibilityNotifier
                                        .value[it.otherUsername] ==
                                    'hide';
                                if (hidden) return const SizedBox.shrink();
                                final online = onlineUsersNotifier.value
                                    .contains(it.otherUsername);
                                if (!online) return const SizedBox.shrink();
                                return Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF34C759),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _openChatWithLockCheck(context, it.otherUsername),
                            onLongPress: () => _showUserProfileDialog(
                                it.otherUsername, it.displayName),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
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
                                ValueListenableBuilder<bool>(
                                  valueListenable: SettingsManager.meshModeEnabled,
                                  builder: (_, meshOn, __) {
                                    if (!meshOn) return const SizedBox.shrink();
                                    return ListenableBuilder(
                                      listenable: MeshManager.instance.neighbors,
                                      builder: (_, __) {
                                        final nb = MeshManager.instance.neighbors.neighborByUsername(it.otherUsername);
                                        if (nb == null) return const SizedBox.shrink();
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 5),
                                          child: Icon(
                                            nb.isLan ? Icons.wifi_rounded : Icons.bluetooth_rounded,
                                            size: 12,
                                            color: nb.isLan ? const Color(0xFF34C759) : const Color(0xFF2196F3),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (it.displayName != it.otherUsername)
                            GestureDetector(
                              onTap: () => _openChatWithLockCheck(context, it.otherUsername),
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
                          if (it.isBle)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    AppLocalizations.of(context).localizePreview(it.preview),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _isPurplePreview(it.preview) ? FontWeight.w500 : null,
                                      color: _isPurplePreview(it.preview)
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (it.meshTransportUsed == 'wifi')
                                  const Icon(Icons.wifi_rounded, size: 14, color: Color(0xFF34C759))
                                else
                                  const Icon(Icons.bluetooth_rounded, size: 14, color: Color(0xFF2196F3)),
                              ],
                            )
                          else
                            Text(
                              AppLocalizations.of(context).localizePreview(it.preview),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _isPurplePreview(it.preview) ? FontWeight.w500 : null,
                                color: _isPurplePreview(it.preview)
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: LockManager.lockedChats,
                      builder: (_, locked, __) {
                        final isLocked = locked.contains('dm_${it.otherUsername}');
                        return ValueListenableBuilder<Set<String>>(
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
                                    if (isLocked)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.lock_rounded,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
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
        );
      },
      ),
    );
  }
}