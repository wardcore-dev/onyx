// lib/screens/favorites_tab.dart
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory;
import 'package:ONYX/globals.dart';
import 'package:ONYX/managers/settings_manager.dart';
import 'package:ONYX/models/chat_message.dart';
import 'package:ONYX/models/fav_folder.dart';
import 'package:ONYX/models/favorite_chat.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../widgets/adaptive_glass_card.dart';
import '../widgets/animated_reorder_list.dart';
import '../widgets/tab_pull_search.dart';
import '../widgets/avatar_crop_screen.dart';
import 'fav_sync_receive_screen.dart';
import 'fav_sync_send_screen.dart';
import '../managers/lock_manager.dart';
import '../dialogs/pin_lock_dialog.dart';
import '../widgets/inline_search_bar.dart';

String _formatTime(DateTime t) {
  final now = DateTime.now();
  if (now.difference(t).inDays == 0) {
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.day}.${t.month}';
}

String _getFileTypeLabel(String filename) {
  final ext = filename.toLowerCase();
  if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.m4a') ||
      ext.endsWith('.aac') || ext.endsWith('.flac') || ext.endsWith('.wma')) {
    return 'Music';
  }
  if (ext.endsWith('.mp4') || ext.endsWith('.mkv') || ext.endsWith('.mov') ||
      ext.endsWith('.avi') || ext.endsWith('.wmv') || ext.endsWith('.flv')) {
    return 'Video';
  }
  if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') ||
      ext.endsWith('.png') || ext.endsWith('.gif') || ext.endsWith('.webp')) {
    return 'Image';
  }
  if (ext.endsWith('.pdf')) return 'Document';
  if (ext.endsWith('.doc') || ext.endsWith('.docx')) return 'Document';
  if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) return 'Spreadsheet';
  if (ext.endsWith('.ppt') || ext.endsWith('.pptx')) return 'Presentation';
  if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z')) {
    return 'Archive';
  }
  return 'File';
}

bool _isPurplePreview(String preview) {
  const purpleLabels = {
    'Voice message', 'Music', 'Image', 'Video', 'Video file',
    'Document', 'Spreadsheet', 'Presentation', 'Archive', 'Artifact', 'File'
  };
  if (preview.startsWith('[Message not decrypted]')) return true;
  if (preview == 'Album' || preview.startsWith('Album ·')) return true;
  return purpleLabels.contains(preview);
}

String _getPreviewText(String rawContent) {
  if (rawContent.startsWith('VOICEv1:')) return 'Voice message';
  if (rawContent.startsWith('AUDIOv1:')) return 'Music';
  if (rawContent.startsWith('IMAGEv1:')) return 'Image';
  if (rawContent.startsWith('VIDEOv1:') ||
      rawContent.toUpperCase().startsWith('VIDEOV1:')) return 'Video file';
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
      if (orig.isNotEmpty) return _getFileTypeLabel(orig);
      return 'File';
    } catch (_) {
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
      final filename =
          (meta['filename'] ?? meta['orig'] ?? meta['name'] ?? 'File') as String;
      return _getFileTypeLabel(filename);
    } catch (_) {
      return 'File';
    }
  }
  if (rawContent.startsWith('FILE:')) {
    return _getFileTypeLabel(rawContent.substring(5));
  }
  if (rawContent.startsWith('ALBUMv1:')) {
    try {
      final list = jsonDecode(rawContent.substring('ALBUMv1:'.length)) as List;
      return 'Album · ${list.length} photos';
    } catch (_) {
      return 'Album';
    }
  }
  if (rawContent.startsWith('[cannot-decrypt]')) {
    return '[Message not decrypted]';
  }
  return rawContent;
}

String _getFavPreview(String favId, Map<String, List<ChatMessage>> allChats) {
  final msgs = allChats['fav:$favId'] ?? [];
  if (msgs.isEmpty) return '';
  return _getPreviewText(msgs.last.content);
}

DateTime _getFavLastTs(String favId, Map<String, List<ChatMessage>> allChats) {
  final msgs = allChats['fav:$favId'] ?? [];
  if (msgs.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return msgs.last.time;
}


class FavoritesTab extends StatefulWidget {
  final List<FavoriteChat> favorites;
  final void Function(String id) onOpen;
  final void Function(FavoriteChat chat) onAdd;
  final void Function(String id) onDelete;

  const FavoritesTab({
    super.key,
    required this.favorites,
    required this.onOpen,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, RouteAware {
  @override
  bool get wantKeepAlive => true;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  late final AnimationController _listAnimController;
  late final AnimationController _selectionAnimController;
  late final Animation<double> _selectionAnim;
  bool _editMode = false;
  String? _openFolderId;

  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey _searchBarKey = GlobalKey();
  String _searchQuery = '';
  List<TabSearchResult> _searchResults = [];

  // Multi-select: long-press / toolbar button enters a mode where tapping
  // chats toggles them; a bottom toolbar then bulk-deletes or moves them.
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  late double _staggerStep;

  // While a favourite chat is open on top of this tab, "jump to top" reorders
  // are held back at their last-seen order so the user sees the chat slide to
  // the top once they return to the list, instead of finding it already there.
  bool _routeIsCurrent = true;
  List<String>? _frozenTopOrder;
  ModalRoute<void>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    final dur = Platform.isWindows
        ? const Duration(milliseconds: 120)
        : const Duration(milliseconds: 350);
    _staggerStep = Platform.isWindows ? 0.02 : 0.05;
    _listAnimController = AnimationController(duration: dur, vsync: this);
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _listAnimController.forward();
    });
    _selectionAnimController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _selectionAnim = CurvedAnimation(
      parent: _selectionAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
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
    _routeIsCurrent = false;
    _frozenTopOrder = List<String>.from(rootScreenKey.currentState?.favTopOrder ?? const []);
  }

  @override
  void didPopNext() {
    _routeIsCurrent = true;
    if (_frozenTopOrder != null && mounted) {
      setState(() => _frozenTopOrder = null);
    }
  }

  /// Order to actually display: while covered by a pushed route, pure
  /// reorders (same set of ids, different order — e.g. a "jump to top") are
  /// frozen at their last-seen position so the move can be animated once the
  /// user returns. Structural changes (added/removed favourites/folders)
  /// still apply immediately.
  List<String> _displayTopOrder(List<String> liveOrder) {
    if (_routeIsCurrent || _frozenTopOrder == null) return liveOrder;
    final frozen = _frozenTopOrder!;
    if (frozen.length == liveOrder.length &&
        frozen.toSet().containsAll(liveOrder) &&
        liveOrder.toSet().containsAll(frozen)) {
      return frozen;
    }
    // Structural change while covered — accept it and keep freezing from here.
    _frozenTopOrder = List<String>.from(liveOrder);
    return _frozenTopOrder!;
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    _selectionAnimController.dispose();
    _searchCtrl.dispose();
    if (_subscribedRoute != null) routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;
    if (trimmed.isEmpty) {
      setState(() { _searchQuery = ''; _searchResults = []; });
      return;
    }
    final results = await _searchFavorites(trimmed);
    if (!mounted) return;
    setState(() { _searchQuery = trimmed; _searchResults = results; });
  }

  Widget _buildInlineSearchBar(ColorScheme cs) {
    return Builder(
      builder: (context) => InlineSearchBar(
        key: _searchBarKey,
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        hintText: AppLocalizations.of(context).searchFavoritesHint,
        hasText: _searchQuery.isNotEmpty,
      ),
    );
  }

  // ── Multi-select ───────────────────────────────────────────────────────────

  void _enterSelection([String? id]) {
    setState(() {
      _selectionMode = true;
      _editMode = false;
      _selectedIds.clear();
      if (id != null) _selectedIds.add(id);
    });
    _selectionAnimController.forward();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
    if (_selectedIds.isEmpty) _selectionAnimController.reverse();
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _selectionAnimController.reverse();
  }

  // ── Action sheets ──────────────────────────────────────────────────────────

  void _showAddSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: cs.primary),
                ),
                title: Text(l.newChat),
                subtitle: Text(l.newChatSubtitle),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) => _NewChatDialog(onAdd: widget.onAdd),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.folder_outlined,
                      size: 18, color: cs.secondary),
                ),
                title: Text(l.newFolder),
                subtitle: Text(l.newFolderSubtitle),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) => const _NewFolderDialog(),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDesktopContextMenu(
      BuildContext context, Offset pos, FavoriteChat fav, List<FavFolder> folders) {
    final cs = Theme.of(context).colorScheme;
    final currentFolder =
        folders.where((f) => f.chatIds.contains(fav.id)).firstOrNull;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem<String>(
          value: 'select',
          child: Row(children: [
            Icon(Icons.checklist_rounded, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Select'),
          ]),
        ),
        if (currentFolder != null)
          PopupMenuItem<String>(
            value: 'remove_folder',
            child: Row(children: [
              Icon(Icons.folder_off_outlined, size: 18, color: cs.onSurface),
              const SizedBox(width: 10),
              Text('Remove from "${currentFolder.name}"'),
            ]),
          ),
        if (folders.isNotEmpty)
          PopupMenuItem<String>(
            value: 'move',
            child: Row(children: [
              Icon(Icons.drive_file_move_outline, size: 18, color: cs.onSurface),
              const SizedBox(width: 10),
              const Text('Move to folder'),
            ]),
          ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Edit'),
          ]),
        ),
        PopupMenuItem<String>(
          value: LockManager.isLocked('fav_${fav.id}') ? 'unlock' : 'lock',
          child: Row(children: [
            Icon(
              LockManager.isLocked('fav_${fav.id}') ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18, color: cs.onSurface,
            ),
            const SizedBox(width: 10),
            Text(LockManager.isLocked('fav_${fav.id}') ? 'Unlock' : 'Lock'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: cs.error),
            const SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: cs.error)),
          ]),
        ),
      ],
    ).then((value) async {
      if (!context.mounted) return;
      if (value == 'select') {
        _enterSelection(fav.id);
      } else if (value == 'remove_folder') {
        rootScreenKey.currentState?.moveChatOutOfFolder(fav.id);
      } else if (value == 'move') {
        _showFolderPicker(context, fav, folders);
      } else if (value == 'edit') {
        showDialog<void>(context: context, builder: (_) => _EditChatDialog(fav: fav));
      } else if (value == 'lock') {
        final lockId = 'fav_${fav.id}';
        final set = await showPinDialog(context, PinDialogMode.set, lockId);
        if (!set) return;
        await LockManager.lock(lockId);
      } else if (value == 'unlock') {
        final lockId = 'fav_${fav.id}';
        final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
        if (ok) await LockManager.removeLock(lockId);
      } else if (value == 'delete') {
        _confirmDelete(context, fav);
      }
    });
  }

  void _showDesktopInlineContextMenu(
      BuildContext context, Offset pos, FavoriteChat fav, ColorScheme cs) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem<String>(
          value: 'remove_folder',
          child: Row(children: [
            Icon(Icons.folder_off_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Remove from folder'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Edit'),
          ]),
        ),
        PopupMenuItem<String>(
          value: LockManager.isLocked('fav_${fav.id}') ? 'unlock' : 'lock',
          child: Row(children: [
            Icon(
              LockManager.isLocked('fav_${fav.id}') ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18, color: cs.onSurface,
            ),
            const SizedBox(width: 10),
            Text(LockManager.isLocked('fav_${fav.id}') ? 'Unlock' : 'Lock'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: cs.error),
            const SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: cs.error)),
          ]),
        ),
      ],
    ).then((value) async {
      if (!context.mounted) return;
      if (value == 'remove_folder') {
        rootScreenKey.currentState?.moveChatOutOfFolder(fav.id);
      } else if (value == 'edit') {
        showDialog<void>(context: context, builder: (_) => _EditChatDialog(fav: fav));
      } else if (value == 'lock') {
        final lockId = 'fav_${fav.id}';
        final set = await showPinDialog(context, PinDialogMode.set, lockId);
        if (!set) return;
        await LockManager.lock(lockId);
      } else if (value == 'unlock') {
        final lockId = 'fav_${fav.id}';
        final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
        if (ok) await LockManager.removeLock(lockId);
      } else if (value == 'delete') {
        _confirmDelete(context, fav);
      }
    });
  }

  /// Builds the same avatar the favorites list shows for [fav] so a result
  /// reads as an expanded chat card rather than a generic search hit.
  Widget Function(BuildContext, double) _favAvatarBuilder(FavoriteChat fav) {
    return (context, size) {
      final cs = Theme.of(context).colorScheme;
      return ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) {
          final baseColor = SettingsManager.getElementColor(
            cs.surfaceContainerHighest,
            brightness,
          );
          return SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: fav.avatarPath != null
                  ? Image.file(File(fav.avatarPath!),
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                            radius: size / 2,
                            backgroundColor: baseColor,
                            child: Icon(Icons.bookmark, size: size * 0.45, color: cs.primary),
                          ))
                  : CircleAvatar(
                      radius: size / 2,
                      backgroundColor: baseColor,
                      child: Icon(Icons.bookmark, size: size * 0.45, color: cs.primary),
                    ),
            ),
          );
        },
      );
    };
  }

  Future<List<TabSearchResult>> _searchFavorites(String query) async {
    final lower = query.toLowerCase();
    final root = rootScreenKey.currentState;
    final allChats = root?.chats ?? {};
    final allFavs = root?.favorites ?? widget.favorites;
    final nameHits = <TabSearchResult>[];
    final contentHits = <TabSearchResult>[];

    outer:
    for (final fav in allFavs) {
      final history = allChats['fav:${fav.id}'];
      final avatarBuilder = _favAvatarBuilder(fav);
      if (fav.title.toLowerCase().contains(lower)) {
        nameHits.add(TabSearchResult(
          id: fav.id,
          title: fav.title,
          snippet: history != null && history.isNotEmpty
              ? _getPreviewText(history.last.content)
              : null,
          icon: Icons.star_outline_rounded,
          avatarBuilder: avatarBuilder,
        ));
        continue;
      }

      if (history == null || history.isEmpty) continue;
      // One card per matching message — chats are intentionally not deduped,
      // so a chat with several hits shows up as several separate cards.
      for (var i = history.length - 1; i >= 0; i--) {
        final content = history[i].content;
        if (content.toLowerCase().contains(lower)) {
          contentHits.add(TabSearchResult(
            id: fav.id,
            title: fav.title,
            snippet: _getPreviewText(content),
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
    if (result.messageId != null) {
      setPendingMessageScrollTarget('fav:${result.id}', result.messageId!);
    }
    _openFavWithLockCheck(context, result.id);
  }

  Future<void> _openFavWithLockCheck(BuildContext ctx, String favId) async {
    // Check if the chat lives inside a locked folder — prompt for folder PIN first.
    final folders = rootScreenKey.currentState?.favFolders ?? const <FavFolder>[];
    final parentFolder = folders.where((f) => f.chatIds.contains(favId)).firstOrNull;
    if (parentFolder != null) {
      final folderLockId = 'fav_folder_${parentFolder.id}';
      if (LockManager.isLocked(folderLockId) &&
          !LockManager.isSessionUnlocked(folderLockId)) {
        final ok = await showPinDialog(ctx, PinDialogMode.verify, folderLockId);
        if (!ok || !mounted) return;
      }
    }

    // Then check the chat's own lock.
    final lockId = 'fav_$favId';
    if (!LockManager.isLocked(lockId) || LockManager.isSessionUnlocked(lockId)) {
      widget.onOpen(favId);
      return;
    }
    if (!mounted || !ctx.mounted) return;
    final ok = await showPinDialog(ctx, PinDialogMode.verify, lockId);
    if (ok && mounted) {
      widget.onOpen(favId);
    }
  }

  void _showChatActions(BuildContext context, FavoriteChat fav,
      List<FavFolder> folders) {
    final cs = Theme.of(context).colorScheme;
    final currentFolder =
        folders.where((f) => f.chatIds.contains(fav.id)).firstOrNull;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.bookmark, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(fav.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('Select'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _enterSelection(fav.id);
                },
              ),
              if (currentFolder != null)
                ListTile(
                  leading: const Icon(Icons.folder_off_outlined),
                  title: Text('Remove from "${currentFolder.name}"'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    rootScreenKey.currentState?.moveChatOutOfFolder(fav.id);
                  },
                ),
              if (folders.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Move to folder'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showFolderPicker(context, fav, folders);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) => _EditChatDialog(fav: fav),
                  );
                },
              ),
              ValueListenableBuilder<Set<String>>(
                valueListenable: LockManager.lockedChats,
                builder: (_, locked, __) {
                  final lockId = 'fav_${fav.id}';
                  final isLocked = locked.contains(lockId);
                  return ListTile(
                    leading: Icon(
                      isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: cs.onSurface,
                    ),
                    title: Text(isLocked ? 'Unlock' : 'Lock'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
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
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context, fav);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderPicker(
      BuildContext context, FavoriteChat fav, List<FavFolder> folders) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text('Move to folder',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: cs.onSurface)),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  children: folders.map((folder) {
                    final isCurrentFolder =
                        folder.chatIds.contains(fav.id);
                    return ListTile(
                      leading: folder.avatarPath != null &&
                              File(folder.avatarPath!).existsSync()
                          ? CircleAvatar(
                              radius: 18,
                              backgroundImage:
                                  FileImage(File(folder.avatarPath!)))
                          : CircleAvatar(
                              radius: 18,
                              backgroundColor: cs.secondaryContainer,
                              child: Icon(Icons.folder,
                                  size: 18, color: cs.secondary)),
                      title: Text(folder.name),
                      subtitle: Text('${folder.chatIds.length} chats',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.5))),
                      trailing: isCurrentFolder
                          ? Icon(Icons.check, color: cs.primary)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (!isCurrentFolder) {
                          rootScreenKey.currentState
                              ?.moveChatToFolder(fav.id, folder.id);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showFolderActions(BuildContext context, FavFolder folder) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 18, color: cs.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(folder.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) => _EditFolderDialog(folder: folder),
                  );
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ValueListenableBuilder<Set<String>>(
                valueListenable: LockManager.lockedChats,
                builder: (_, locked, __) {
                  final lockId = 'fav_folder_${folder.id}';
                  final isLocked = locked.contains(lockId);
                  return ListTile(
                    leading: Icon(
                      isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: cs.onSurface,
                    ),
                    title: Text(isLocked ? 'Unlock folder' : 'Lock folder'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
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
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Delete folder',
                    style: TextStyle(color: cs.error)),
                subtitle: const Text('Chats will be moved to top level'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final lockId = 'fav_folder_${folder.id}';
                  if (LockManager.isLocked(lockId)) {
                    final ok = await showPinDialog(
                        context, PinDialogMode.verify, lockId);
                    if (!ok) return;
                  }
                  await LockManager.removeLock(lockId);
                  rootScreenKey.currentState?.deleteFavFolder(folder.id);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDesktopFolderContextMenu(
      BuildContext context, Offset pos, FavFolder folder) {
    final cs = Theme.of(context).colorScheme;
    final lockId = 'fav_folder_${folder.id}';
    final isLocked = LockManager.isLocked(lockId);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Edit'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'lock',
          child: Row(children: [
            Icon(
              isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18,
              color: cs.onSurface,
            ),
            const SizedBox(width: 10),
            Text(isLocked ? 'Unlock folder' : 'Lock folder'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: cs.error),
            const SizedBox(width: 10),
            Text('Delete folder', style: TextStyle(color: cs.error)),
          ]),
        ),
      ],
    ).then((value) async {
      if (!context.mounted) return;
      if (value == 'edit') {
        showDialog<void>(
            context: context,
            builder: (_) => _EditFolderDialog(folder: folder));
      } else if (value == 'lock') {
        if (isLocked) {
          final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
          if (ok) await LockManager.removeLock(lockId);
        } else {
          final set = await showPinDialog(context, PinDialogMode.set, lockId);
          if (!set) return;
          await LockManager.lock(lockId);
        }
      } else if (value == 'delete') {
        if (isLocked) {
          final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
          if (!ok) return;
        }
        await LockManager.removeLock(lockId);
        rootScreenKey.currentState?.deleteFavFolder(folder.id);
      }
    });
  }

  void _confirmDelete(BuildContext context, FavoriteChat fav) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor:
              cs.surface.withValues(alpha: SettingsManager.elementOpacity.value),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete chat?'),
          content: Text(
              'Remove "${fav.title}" and all its messages from favorites?'),
          actions: [
            TextButton(
                onPressed: Navigator.of(ctx).pop,
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                LockManager.removeLock('fav_${fav.id}');
                widget.onDelete(fav.id);
              },
              child: Text('Delete', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFolderWithLockCheck(BuildContext ctx, FavFolder folder) async {
    final lockId = 'fav_folder_${folder.id}';
    if (!LockManager.isLocked(lockId) || LockManager.isSessionUnlocked(lockId)) {
      _openFolder(ctx, folder);
      return;
    }
    final ok = await showPinDialog(ctx, PinDialogMode.verify, lockId);
    if (ok && mounted) {
      _openFolder(ctx, folder);
    }
  }

  void _openFolder(BuildContext context, FavFolder folder) {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      setState(() => _openFolderId = folder.id);
    } else {
      showDialog<void>(
        context: context,
        builder: (_) => _FolderContentDialog(
          folderId: folder.id,
          onOpen: widget.onOpen,
        ),
      );
    }
  }

  // ── Sync sheet ─────────────────────────────────────────────────────────────

  void _showSyncSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('WardLink',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: cs.onSurface)),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.qr_code_rounded,
                      size: 20, color: cs.primary),
                ),
                title: Text(l.wardlinkReceive),
                subtitle: Text(l.wardlinkReceiveSubtitle),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const FavSyncReceiveScreen(),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.qr_code_scanner_rounded,
                      size: 20, color: cs.secondary),
                ),
                title: Text(l.wardlinkSend),
                subtitle: Text(l.wardlinkSendSubtitle),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const FavSyncSendScreen(),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<int>(
      valueListenable: chatsVersion,
      builder: (context, _, __) {
        return ValueListenableBuilder<int>(
          valueListenable: favoritesVersion,
          builder: (context, __, ___) {
            final root = rootScreenKey.currentState;
            final allChats = root?.chats ?? {};
            final favTopOrder = _displayTopOrder(root?.favTopOrder ?? []);
            final favFolders = root?.favFolders ?? [];
            final allFavs = root?.favorites ?? widget.favorites;

            Widget child;
            String contentKey;
            if (_openFolderId != null) {
              final folder = favFolders
                  .where((f) => f.id == _openFolderId)
                  .firstOrNull;
              if (folder == null) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => setState(() => _openFolderId = null));
                child = _buildNormalMode(
                    context, favTopOrder, favFolders, allFavs, allChats);
                contentKey = 'normal';
              } else {
                child = _buildInlineFolderView(
                    context, folder, allFavs, allChats);
                contentKey = 'folder:${folder.id}';
              }
            } else if (_editMode) {
              child = _buildEditMode(
                  context, favTopOrder, favFolders, allFavs, allChats);
              contentKey = 'edit';
            } else {
              child = _buildNormalMode(
                  context, favTopOrder, favFolders, allFavs, allChats);
              contentKey = 'normal';
            }

            // Desktop swaps folder/list content in place (no pushed route, so
            // no built-in transition) — cross-fade so switching folders isn't
            // an abrupt jump cut. Mobile opens folders as a dialog instead,
            // which already animates, so this only matters on desktop, but
            // applying it everywhere is harmless.
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: ValueKey(contentKey), child: child),
            );
          },
        );
      },
    );
  }

  // ── Normal mode (ListView) ─────────────────────────────────────────────────

  Widget _buildNormalMode(
    BuildContext context,
    List<String> favTopOrder,
    List<FavFolder> favFolders,
    List<FavoriteChat> allFavs,
    Map<String, List<ChatMessage>> allChats,
  ) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = 8 + MediaQuery.paddingOf(context).bottom;
    final searchBar = _buildInlineSearchBar(cs);

    if (_searchQuery.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _buildToolbar(context, favTopOrder.isNotEmpty),
          ),
          Expanded(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
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
                        child: _buildSearchResultTile(ctx, r, cs),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _buildToolbar(context, favTopOrder.isNotEmpty),
        ),
        Expanded(
          child: AnimatedReorderList<String>(
            items: favTopOrder,
            keyOf: (id) => id,
            header: searchBar,
            padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            separatorHeight: 6,
            itemBuilder: (context, id, i) {
              final folder = favFolders.where((f) => f.id == id).firstOrNull;
              return FadeTransition(
                opacity: Tween(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _listAnimController,
                    curve: Interval(i * _staggerStep, 1.0, curve: Curves.easeOut),
                  ),
                ),
                child: folder != null
                    ? _buildFolderTile(context, folder, allFavs)
                    : _buildChatTile(context, id, allFavs, favFolders, allChats),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(BuildContext context, TabSearchResult r, ColorScheme cs) {
    return GestureDetector(
      onTap: () => _onSearchResultTap(r),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (r.avatarBuilder != null)
              SizedBox(width: 40, height: 40, child: r.avatarBuilder!(context, 40))
            else
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
                  Text(r.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (r.snippet != null)
                    Text(r.snippet!,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit mode (ReorderableListView) ───────────────────────────────────────

  Widget _buildEditMode(
    BuildContext context,
    List<String> favTopOrder,
    List<FavFolder> favFolders,
    List<FavoriteChat> allFavs,
    Map<String, List<ChatMessage>> allChats,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _buildToolbar(context, favTopOrder.isNotEmpty),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
                12, 4, 12, 8 + MediaQuery.paddingOf(context).bottom),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, _, __) =>
                Material(color: Colors.transparent, child: child),
            itemCount: favTopOrder.length,
            onReorder: (oldIdx, newIdx) =>
                rootScreenKey.currentState?.reorderFavTop(oldIdx, newIdx),
            itemBuilder: (context, i) {
              final id = favTopOrder[i];
              final folder = favFolders.where((f) => f.id == id).firstOrNull;
              return Padding(
                key: ValueKey(id),
                padding: const EdgeInsets.only(bottom: 6),
                child: folder != null
                    ? _buildFolderTile(context, folder, allFavs,
                        editMode: true, dragIndex: i)
                    : _buildChatTile(context, id, allFavs, favFolders,
                        allChats,
                        editMode: true, dragIndex: i),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Toolbar row ────────────────────────────────────────────────────────────
  //
  // The toolbar morphs in place between "normal" and "selection" mode instead
  // of being swapped outright: each button slot keeps its position and only
  // its content/colour cross-fades + slides, while a leading close button
  // grows in from zero width. Driven by _selectionAnimController.

  Widget _buildToolbar(BuildContext context, bool hasItems) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _listAnimController,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
      ),
      child: AnimatedBuilder(
        animation: _selectionAnim,
        builder: (context, _) {
          final t = _selectionAnim.value;
          return Row(
            children: [
              _morphCloseSlot(cs, t),
              Expanded(child: _morphCenterSlot(context, cs, t)),
              const SizedBox(width: 8),
              _morphSyncMoveSlot(context, cs, t),
              if (hasItems) ...[
                const SizedBox(width: 8),
                _morphEditDeleteSlot(context, cs, t),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Cross-fades + slightly slides between [oldChild] (visible at t=0) and
  /// [newChild] (visible at t=1) — the classic Apple "flip" text/icon swap.
  Widget _crossFadeContent({
    required double t,
    required Widget oldChild,
    required Widget newChild,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -8 * t),
            child: oldChild,
          ),
        ),
        Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: newChild,
          ),
        ),
      ],
    );
  }

  Widget _morphCloseSlot(ColorScheme cs, double t) {
    return ClipRect(
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: t,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AdaptiveGlassCard(
            borderRadius: 14,
            padding: EdgeInsets.zero,
            onTap: t > 0.4 ? _exitSelection : null,
            child: Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Opacity(
                opacity: t,
                child: Icon(Icons.close_rounded, size: 20, color: cs.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _morphCenterSlot(BuildContext context, ColorScheme cs, double t) {
    final count = _selectedIds.length;
    return AdaptiveGlassCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      onTap: t < 0.5 ? () => _showAddSheet(context) : null,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _crossFadeContent(
          t: t,
          oldChild: Icon(Icons.add, size: 20, color: cs.primary),
          newChild: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                count == 0 ? 'Select chats' : '$count selected',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _morphSyncMoveSlot(BuildContext context, ColorScheme cs, double t) {
    final hasSelection = _selectedIds.isNotEmpty;
    return AdaptiveGlassCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      onTap: t < 0.5
          ? () => _showSyncSheet(context)
          : (hasSelection ? () => _bulkMoveToFolder(context) : null),
      child: Container(
        height: 44,
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary
              .withValues(alpha: t >= 0.5 && !hasSelection ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _crossFadeContent(
          t: t,
          oldChild: Icon(Icons.sync_rounded, size: 20, color: cs.primary),
          newChild: Icon(Icons.drive_file_move_outline,
              size: 20,
              color: cs.primary.withValues(alpha: hasSelection ? 1 : 0.4)),
        ),
      ),
    );
  }

  Widget _morphEditDeleteSlot(BuildContext context, ColorScheme cs, double t) {
    final hasSelection = _selectedIds.isNotEmpty;
    final startColor = _editMode ? Colors.green : cs.primary;
    final color = Color.lerp(startColor, cs.error, t)!;
    final bgAlpha = t >= 0.5
        ? (hasSelection ? 0.12 : 0.05)
        : (_editMode ? 0.18 : 0.12);
    return AdaptiveGlassCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      onTap: t < 0.5
          ? () => setState(() => _editMode = !_editMode)
          : (hasSelection ? () => _confirmBulkDelete(context) : null),
      child: Container(
        height: 44,
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _crossFadeContent(
          t: t,
          oldChild: Icon(_editMode ? Icons.check_rounded : Icons.sort_rounded,
              size: 20, color: color),
          newChild: Icon(Icons.delete_outline,
              size: 20, color: color.withValues(alpha: hasSelection ? 1 : 0.4)),
        ),
      ),
    );
  }

  void _confirmBulkDelete(BuildContext context) {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor:
              cs.surface.withValues(alpha: SettingsManager.elementOpacity.value),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete ${ids.length} chat${ids.length == 1 ? '' : 's'}?'),
          content: const Text(
              'The selected chats and all their messages will be removed from favorites.'),
          actions: [
            TextButton(
                onPressed: Navigator.of(ctx).pop,
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                for (final id in ids) {
                  LockManager.removeLock('fav_$id');
                  widget.onDelete(id);
                }
                _exitSelection();
              },
              child: Text('Delete', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );
  }

  void _bulkMoveToFolder(BuildContext context) {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final root = rootScreenKey.currentState;
    final folders = root?.favFolders ?? const <FavFolder>[];
    final cs = Theme.of(context).colorScheme;

    void applyMove(String folderId) {
      for (final id in ids) {
        root?.moveChatToFolder(id, folderId);
      }
      _exitSelection();
    }

    Future<void> createAndMove() async {
      final name = await _promptFolderName(context);
      if (name == null || name.trim().isEmpty) return;
      final folderId = root?.createFavFolder(name.trim());
      if (folderId != null) applyMove(folderId);
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
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
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                    'Move ${ids.length} chat${ids.length == 1 ? '' : 's'} to folder',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: cs.onSurface)),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.primary.withValues(alpha: 0.15),
                        child: Icon(Icons.create_new_folder_outlined,
                            size: 18, color: cs.primary),
                      ),
                      title: const Text('New folder…'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        createAndMove();
                      },
                    ),
                    for (final folder in folders)
                      ListTile(
                        leading: folder.avatarPath != null &&
                                File(folder.avatarPath!).existsSync()
                            ? CircleAvatar(
                                radius: 18,
                                backgroundImage:
                                    FileImage(File(folder.avatarPath!)))
                            : CircleAvatar(
                                radius: 18,
                                backgroundColor: cs.secondaryContainer,
                                child: Icon(Icons.folder,
                                    size: 18, color: cs.secondary)),
                        title: Text(folder.name),
                        subtitle: Text('${folder.chatIds.length} chats',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          applyMove(folder.id);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptFolderName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor:
              cs.surface.withValues(alpha: SettingsManager.elementOpacity.value),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('New folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
                onPressed: Navigator.of(ctx).pop,
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // ── Chat tile ──────────────────────────────────────────────────────────────

  Widget _buildChatTile(
    BuildContext context,
    String chatId,
    List<FavoriteChat> allFavs,
    List<FavFolder> favFolders,
    Map<String, List<ChatMessage>> allChats, {
    bool editMode = false,
    int? dragIndex,
  }) {
    final fav = allFavs.where((f) => f.id == chatId).firstOrNull;
    if (fav == null) return const SizedBox.shrink();

    final preview = _getFavPreview(fav.id, allChats);
    final lastTs = _getFavLastTs(fav.id, allChats);
    final cs = Theme.of(context).colorScheme;
    final selected = _selectionMode && _selectedIds.contains(fav.id);

    return GestureDetector(
      onSecondaryTapUp: _isDesktop && !editMode && !_selectionMode
          ? (d) => _showDesktopContextMenu(context, d.globalPosition, fav, favFolders)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: cs.primary, width: 2)
              : null,
        ),
        child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: editMode
            ? null
            : _selectionMode
                ? () => _toggleSelect(fav.id)
                : () => _openFavWithLockCheck(context, fav.id),
        onLongPress: editMode || _selectionMode
            ? null
            : () => _showChatActions(context, fav, favFolders),
        child: AdaptiveGlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, __) {
                  final baseColor = SettingsManager.getElementColor(
                    cs.surfaceContainerHighest,
                    brightness,
                  );
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: fav.avatarPath != null
                          ? Image.file(File(fav.avatarPath!),
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                    radius: 20,
                                    backgroundColor: baseColor,
                                    child: Icon(Icons.bookmark,
                                        size: 18, color: cs.primary),
                                  ))
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: baseColor,
                              child: Icon(Icons.bookmark,
                                  size: 18, color: cs.primary),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fav.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _isPurplePreview(preview)
                              ? FontWeight.w500
                              : null,
                          color: _isPurplePreview(preview)
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              if (!editMode)
                ValueListenableBuilder<Set<String>>(
                  valueListenable: LockManager.lockedChats,
                  builder: (_, locked, __) {
                    final isLocked = locked.contains('fav_${fav.id}');
                    if (!isLocked) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock_rounded, size: 14,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                    );
                  },
                ),
              if (!editMode && !_selectionMode &&
                  lastTs.millisecondsSinceEpoch > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    _formatTime(lastTs),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              if (editMode && dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.drag_handle_rounded,
                        size: 22,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                  ),
                ),
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  // ── Folder tile ────────────────────────────────────────────────────────────

  Widget _buildFolderTile(
    BuildContext context,
    FavFolder folder,
    List<FavoriteChat> allFavs, {
    bool editMode = false,
    int? dragIndex,
  }) {
    final cs = Theme.of(context).colorScheme;
    final count = folder.chatIds.length;

    // Folders aren't part of multi-select (you select chats, then move them
    // into a folder) — dim and disable them while selecting.
    return Opacity(
      opacity: _selectionMode ? 0.4 : 1,
      child: GestureDetector(
      onSecondaryTapUp: _isDesktop && !editMode && !_selectionMode
          ? (d) => _showDesktopFolderContextMenu(context, d.globalPosition, folder)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: editMode || _selectionMode
            ? null
            : () => _openFolderWithLockCheck(context, folder),
        onLongPress: editMode || _selectionMode
            ? null
            : () => _showFolderActions(context, folder),
        child: AdaptiveGlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, __) {
                  final baseColor = SettingsManager.getElementColor(
                      cs.surfaceContainerHighest, brightness);
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: folder.avatarPath != null &&
                              File(folder.avatarPath!).existsSync()
                          ? Image.file(File(folder.avatarPath!),
                              fit: BoxFit.cover, width: 40, height: 40)
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: baseColor,
                              child: Icon(Icons.folder_rounded,
                                  size: 20, color: cs.primary),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_rounded,
                            size: 14, color: cs.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count chat${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (editMode && dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.drag_handle_rounded,
                        size: 22,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                  ),
                ),
              if (!editMode) ...[
                ValueListenableBuilder<Set<String>>(
                  valueListenable: LockManager.lockedChats,
                  builder: (_, locked, __) {
                    final lockId = 'fav_folder_${folder.id}';
                    if (!locked.contains(lockId)) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock_rounded,
                          size: 14,
                          color: cs.onSurface.withValues(alpha: 0.45)),
                    );
                  },
                ),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.3)),
              ],
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }

  // ── Inline folder view (desktop) ──────────────────────────────────────────

  Widget _buildInlineFolderView(
    BuildContext context,
    FavFolder folder,
    List<FavoriteChat> allFavs,
    Map<String, List<ChatMessage>> allChats,
  ) {
    final cs = Theme.of(context).colorScheme;
    final folderChats = folder.chatIds
        .map((id) => allFavs.where((f) => f.id == id).firstOrNull)
        .whereType<FavoriteChat>()
        .toList();
    final displayChats = folderChats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _openFolderId = null;
                  _editMode = false;
                }),
                tooltip: 'Back',
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: ClipOval(
                  child: folder.avatarPath != null &&
                          File(folder.avatarPath!).existsSync()
                      ? Image.file(File(folder.avatarPath!),
                          fit: BoxFit.cover, width: 28, height: 28)
                      : CircleAvatar(
                          radius: 14,
                          backgroundColor: cs.secondaryContainer,
                          child: Icon(Icons.folder_rounded,
                              size: 14, color: cs.secondary),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  folder.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (folderChats.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _editMode ? Icons.check_rounded : Icons.sort_rounded,
                    color: _editMode ? Colors.green : cs.primary,
                  ),
                  onPressed: () => setState(() => _editMode = !_editMode),
                  tooltip: _editMode ? 'Done' : 'Reorder',
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: folderChats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No chats in this folder yet.\nLong-press a chat and choose "Move to folder".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          height: 1.5,
                          fontSize: 13),
                    ),
                  ),
                )
              : _editMode
                  ? _buildInlineReorderList(
                      context, folder, displayChats, allChats, cs)
                  : _buildInlineNormalList(
                      context, displayChats, allChats, cs),
        ),
      ],
    );
  }

  Widget _buildInlineNormalList(
      BuildContext context,
      List<FavoriteChat> chats,
      Map<String, List<ChatMessage>> allChats,
      ColorScheme cs) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) =>
          _buildInlineChatRow(context, chats[i], allChats, cs),
    );
  }

  Widget _buildInlineReorderList(
      BuildContext context,
      FavFolder folder,
      List<FavoriteChat> chats,
      Map<String, List<ChatMessage>> allChats,
      ColorScheme cs) {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(
          12, 4, 12, 8 + MediaQuery.paddingOf(context).bottom),
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      itemCount: chats.length,
      onReorder: (oldIdx, newIdx) {
        var newIdx0 = newIdx;
        if (newIdx0 > oldIdx) newIdx0--;
        final ids = chats.map((c) => c.id).toList();
        final item = ids.removeAt(oldIdx);
        ids.insert(newIdx0, item);
        rootScreenKey.currentState?.setFolderChatOrder(folder.id, ids);
      },
      itemBuilder: (context, i) => Padding(
        key: ValueKey(chats[i].id),
        padding: const EdgeInsets.only(bottom: 6),
        child: _buildInlineChatRow(context, chats[i], allChats, cs,
            editMode: true),
      ),
    );
  }

  Widget _buildInlineChatRow(
      BuildContext context,
      FavoriteChat fav,
      Map<String, List<ChatMessage>> allChats,
      ColorScheme cs, {
      bool editMode = false}) {
    final preview = _getFavPreview(fav.id, allChats);
    final lastTs = _getFavLastTs(fav.id, allChats);

    return GestureDetector(
      onSecondaryTapUp: _isDesktop && !editMode
          ? (d) => _showDesktopInlineContextMenu(context, d.globalPosition, fav, cs)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: editMode ? null : () => _openFavWithLockCheck(context, fav.id),
        onLongPress: editMode
            ? null
            : () => _showInlineChatActions(context, fav, cs),
        child: AdaptiveGlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, __) {
                  final baseColor = SettingsManager.getElementColor(
                      cs.surfaceContainerHighest, brightness);
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: fav.avatarPath != null
                          ? Image.file(File(fav.avatarPath!),
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                    radius: 20,
                                    backgroundColor: baseColor,
                                    child: Icon(Icons.bookmark,
                                        size: 18, color: cs.primary),
                                  ))
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: baseColor,
                              child: Icon(Icons.bookmark,
                                  size: 18, color: cs.primary)),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fav.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15)),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _isPurplePreview(preview)
                              ? FontWeight.w500
                              : null,
                          color: _isPurplePreview(preview)
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ValueListenableBuilder<Set<String>>(
                valueListenable: LockManager.lockedChats,
                builder: (_, locked, __) {
                  final isLocked = locked.contains('fav_${fav.id}');
                  if (!isLocked) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.lock_rounded, size: 14,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  );
                },
              ),
              if (!editMode && lastTs.millisecondsSinceEpoch > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    _formatTime(lastTs),
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showInlineChatActions(
      BuildContext context, FavoriteChat fav, ColorScheme cs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
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
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.bookmark, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(fav.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Remove from folder'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  rootScreenKey.currentState?.moveChatOutOfFolder(fav.id);
                },
              ),
              ValueListenableBuilder<Set<String>>(
                valueListenable: LockManager.lockedChats,
                builder: (_, locked, __) {
                  final lockId = 'fav_${fav.id}';
                  final isLocked = locked.contains(lockId);
                  return ListTile(
                    leading: Icon(
                      isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: cs.onSurface,
                    ),
                    title: Text(isLocked ? 'Unlock' : 'Lock'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
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
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete chat?'),
                      content:
                          Text('Remove "${fav.title}" and all its messages?'),
                      actions: [
                        TextButton(
                            onPressed: Navigator.of(dCtx).pop,
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.of(dCtx).pop();
                            LockManager.removeLock('fav_${fav.id}');
                            rootScreenKey.currentState
                                ?.deleteFavoriteById(fav.id);
                          },
                          child:
                              Text('Delete', style: TextStyle(color: cs.error)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Folder content dialog ──────────────────────────────────────────────────────

class _FolderContentDialog extends StatefulWidget {
  final String folderId;
  final void Function(String id) onOpen;

  const _FolderContentDialog({
    required this.folderId,
    required this.onOpen,
  });

  @override
  State<_FolderContentDialog> createState() => _FolderContentDialogState();
}

class _FolderContentDialogState extends State<_FolderContentDialog> {
  bool _editMode = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  Future<void> _openWithLockCheck(BuildContext ctx, String favId) async {
    final lockId = 'fav_$favId';
    if (!LockManager.isLocked(lockId) || LockManager.isSessionUnlocked(lockId)) {
      widget.onOpen(favId);
      return;
    }
    final ok = await showPinDialog(ctx, PinDialogMode.verify, lockId);
    if (ok && mounted) {
      widget.onOpen(favId);
    }
  }

  void _showDesktopContextMenu(
      BuildContext context, Offset pos, FavoriteChat fav, ColorScheme cs) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        PopupMenuItem<String>(
          value: 'remove_folder',
          child: Row(children: [
            Icon(Icons.folder_off_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Remove from folder'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            const Text('Edit'),
          ]),
        ),
        PopupMenuItem<String>(
          value: LockManager.isLocked('fav_${fav.id}') ? 'unlock' : 'lock',
          child: Row(children: [
            Icon(
              LockManager.isLocked('fav_${fav.id}') ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18, color: cs.onSurface,
            ),
            const SizedBox(width: 10),
            Text(LockManager.isLocked('fav_${fav.id}') ? 'Unlock' : 'Lock'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: cs.error),
            const SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: cs.error)),
          ]),
        ),
      ],
    ).then((value) async {
      if (!context.mounted) return;
      if (value == 'remove_folder') {
        rootScreenKey.currentState?.moveChatOutOfFolder(fav.id);
      } else if (value == 'edit') {
        showDialog<void>(
            context: context, builder: (_) => _EditChatDialog(fav: fav));
      } else if (value == 'lock') {
        final lockId = 'fav_${fav.id}';
        final set = await showPinDialog(context, PinDialogMode.set, lockId);
        if (!set) return;
        await LockManager.lock(lockId);
      } else if (value == 'unlock') {
        final lockId = 'fav_${fav.id}';
        final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
        if (ok) await LockManager.removeLock(lockId);
      } else if (value == 'delete') {
        showDialog(
          context: context,
          builder: (dCtx) => AlertDialog(
            title: const Text('Delete chat?'),
            content: Text('Remove "${fav.title}" and all its messages?'),
            actions: [
              TextButton(
                  onPressed: Navigator.of(dCtx).pop,
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.of(dCtx).pop();
                  LockManager.removeLock('fav_${fav.id}');
                  rootScreenKey.currentState?.deleteFavoriteById(fav.id);
                },
                child: Text('Delete', style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        );
      }
    });
  }

  void _showChatActions(BuildContext context, FavoriteChat fav,
      ColorScheme cs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: SettingsManager.getElementColor(
                cs.surfaceContainerHighest,
                SettingsManager.elementBrightness.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  Icon(Icons.bookmark, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(fav.title,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Remove from folder'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  rootScreenKey.currentState?.moveChatOutOfFolder(fav.id);
                },
              ),
              ValueListenableBuilder<Set<String>>(
                valueListenable: LockManager.lockedChats,
                builder: (_, locked, __) {
                  final lockId = 'fav_${fav.id}';
                  final isLocked = locked.contains(lockId);
                  return ListTile(
                    leading: Icon(
                      isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: cs.onSurface,
                    ),
                    title: Text(isLocked ? 'Unlock' : 'Lock'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
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
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete chat?'),
                      content: Text(
                          'Remove "${fav.title}" and all its messages?'),
                      actions: [
                        TextButton(
                            onPressed: Navigator.of(dCtx).pop,
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.of(dCtx).pop();
                            LockManager.removeLock('fav_${fav.id}');
                            rootScreenKey.currentState
                                ?.deleteFavoriteById(fav.id);
                          },
                          child: Text('Delete',
                              style: TextStyle(color: cs.error)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ValueListenableBuilder<int>(
        valueListenable: chatsVersion,
        builder: (_, __, ___) => ValueListenableBuilder<int>(
        valueListenable: favoritesVersion,
        builder: (_, __, ___) {
          final root = rootScreenKey.currentState;
          final folder = root?.favFolders
              .where((f) => f.id == widget.folderId)
              .firstOrNull;

          if (folder == null) {
            // Folder was deleted while open
            WidgetsBinding.instance
                .addPostFrameCallback((_) => Navigator.of(context).pop());
            return const SizedBox(width: 400, height: 100,
                child: Center(child: CircularProgressIndicator()));
          }

          final allFavs = root?.favorites ?? [];
          final allChats = root?.chats ?? {};

          final folderChats = folder.chatIds
              .map((id) => allFavs.where((f) => f.id == id).firstOrNull)
              .whereType<FavoriteChat>()
              .toList();
          final displayChats = folderChats;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title bar
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      bottom: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: ClipOval(
                          child: folder.avatarPath != null &&
                                  File(folder.avatarPath!).existsSync()
                              ? Image.file(File(folder.avatarPath!),
                                  fit: BoxFit.cover, width: 36, height: 36)
                              : CircleAvatar(
                                  radius: 18,
                                  backgroundColor: cs.secondaryContainer,
                                  child: Icon(Icons.folder_rounded,
                                      size: 18, color: cs.secondary),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folder.name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (folderChats.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _editMode
                                ? Icons.check_rounded
                                : Icons.sort_rounded,
                            color: _editMode ? Colors.green : cs.primary,
                          ),
                          onPressed: () =>
                              setState(() => _editMode = !_editMode),
                          tooltip: _editMode ? 'Done' : 'Reorder',
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: folderChats.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text('No chats in this folder yet.\n'
                                'Long-press a chat and choose "Move to folder".',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5),
                                    height: 1.5)),
                          ),
                        )
                      : _editMode
                          ? _buildReorderList(
                              context, folder, displayChats, allChats, cs)
                          : _buildNormalList(
                              context, displayChats, allChats, cs),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _buildNormalList(
      BuildContext context,
      List<FavoriteChat> chats,
      Map<String, List<ChatMessage>> allChats,
      ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final fav = chats[i];
        return _buildChatRow(context, fav, allChats, cs);
      },
    );
  }

  Widget _buildReorderList(
      BuildContext context,
      FavFolder folder,
      List<FavoriteChat> chats,
      Map<String, List<ChatMessage>> allChats,
      ColorScheme cs) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      itemCount: chats.length,
      onReorder: (oldIdx, newIdx) {
        var newIdx0 = newIdx;
        if (newIdx0 > oldIdx) newIdx0--;
        final ids = chats.map((c) => c.id).toList();
        final item = ids.removeAt(oldIdx);
        ids.insert(newIdx0, item);
        rootScreenKey.currentState?.setFolderChatOrder(folder.id, ids);
      },
      itemBuilder: (context, i) {
        final fav = chats[i];
        return Padding(
          key: ValueKey(fav.id),
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildChatRow(context, fav, allChats, cs,
              editMode: true, dragIndex: i),
        );
      },
    );
  }

  Widget _buildChatRow(
      BuildContext context,
      FavoriteChat fav,
      Map<String, List<ChatMessage>> allChats,
      ColorScheme cs, {
      bool editMode = false,
      int? dragIndex}) {
    final preview = _getFavPreview(fav.id, allChats);
    final lastTs = _getFavLastTs(fav.id, allChats);

    return GestureDetector(
      onSecondaryTapUp: _isDesktop && !editMode
          ? (d) => _showDesktopContextMenu(context, d.globalPosition, fav, cs)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: editMode ? null : () => _openWithLockCheck(context, fav.id),
        onLongPress:
            editMode ? null : () => _showChatActions(context, fav, cs),
        child: AdaptiveGlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, __) {
                  final baseColor = SettingsManager.getElementColor(
                      cs.surfaceContainerHighest, brightness);
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: fav.avatarPath != null
                          ? Image.file(File(fav.avatarPath!),
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                    radius: 20,
                                    backgroundColor: baseColor,
                                    child: Icon(Icons.bookmark,
                                        size: 18, color: cs.primary),
                                  ))
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: baseColor,
                              child: Icon(Icons.bookmark,
                                  size: 18, color: cs.primary)),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fav.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15)),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _isPurplePreview(preview)
                              ? FontWeight.w500
                              : null,
                          color: _isPurplePreview(preview)
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!editMode)
                ValueListenableBuilder<Set<String>>(
                  valueListenable: LockManager.lockedChats,
                  builder: (_, locked, __) {
                    final isLocked = locked.contains('fav_${fav.id}');
                    if (!isLocked) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock_rounded, size: 14,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                    );
                  },
                ),
              if (!editMode && lastTs.millisecondsSinceEpoch > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    _formatTime(lastTs),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              if (editMode && dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.drag_handle_rounded,
                        size: 22,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ── Edit chat dialog ──────────────────────────────────────────────────────────

class _EditChatDialog extends StatefulWidget {
  final FavoriteChat fav;
  const _EditChatDialog({required this.fav});

  @override
  State<_EditChatDialog> createState() => _EditChatDialogState();
}

class _EditChatDialogState extends State<_EditChatDialog> {
  late final TextEditingController _nameCtrl;
  late String? _avatarPath;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.fav.title);
    _avatarPath = widget.fav.avatarPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await showAvatarCropScreen(context, bytes);
      if (cropped == null) { setState(() => _isUploading = false); return; }
      final dir = Directory(
          '${(await getOnyxSupportDirectory()).path}/fav_avatars');
      await dir.create(recursive: true);
      final hash = md5.convert(cropped).toString().substring(0, 12);
      final path = '${dir.path}/${widget.fav.id}_$hash.jpg';
      await File(path).writeAsBytes(cropped);
      if (!mounted) return;
      setState(() { _avatarPath = path; _isUploading = false; });
    } catch (_) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove avatar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _avatarPath = null);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final updated = widget.fav.copyWith(title: name, avatarPath: _avatarPath);
    rootScreenKey.currentState?.updateFavorite(updated);
    rootScreenKey.currentState?.saveFavorites();
    favoritesVersion.value++;
    Navigator.of(context).pop();
  }

  static const _btnShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(50)),
  );
  static const _btnPadding = EdgeInsets.symmetric(vertical: 13);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        final fillColor = SettingsManager.getElementColor(
            cs.surfaceContainerHighest, brightness);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                            child: Icon(Icons.edit_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.editChat,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.55)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Avatar ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Center(
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAvatar,
                          onLongPress: _avatarPath != null ? _removeAvatar : null,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: cs.outline.withValues(alpha: 0.2),
                                      width: 2),
                                ),
                                child: ClipOval(
                                  child: _avatarPath != null &&
                                          File(_avatarPath!).existsSync()
                                      ? Image.file(File(_avatarPath!),
                                          fit: BoxFit.cover)
                                      : Container(
                                          color: fillColor.withValues(alpha: 0.3),
                                          child: Icon(Icons.bookmark,
                                              size: 42, color: cs.primary),
                                        ),
                                ),
                              ),
                              if (_isUploading)
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Center(
                                      child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ── Name field ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            maxLength: 50,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            decoration: InputDecoration(
                              labelText: l.chatNameLabel,
                              counterText: '',
                              filled: true,
                              fillColor: fillColor.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color:
                                        cs.outlineVariant.withValues(alpha: 0.3),
                                    width: 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: cs.primary, width: 1.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isUploading ? null : _save,
                            style: FilledButton.styleFrom(
                              padding: _btnPadding,
                              shape: _btnShape,
                            ),
                            child: Text(l.save),
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
}

// ── Edit folder dialog ────────────────────────────────────────────────────────

class _EditFolderDialog extends StatefulWidget {
  final FavFolder folder;
  const _EditFolderDialog({required this.folder});

  @override
  State<_EditFolderDialog> createState() => _EditFolderDialogState();
}

class _EditFolderDialogState extends State<_EditFolderDialog> {
  late final TextEditingController _nameCtrl;
  late String? _avatarPath;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.folder.name);
    _avatarPath = widget.folder.avatarPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await showAvatarCropScreen(context, bytes);
      if (cropped == null) { setState(() => _isUploading = false); return; }
      final dir = Directory(
          '${(await getOnyxSupportDirectory()).path}/fav_folder_avatars');
      await dir.create(recursive: true);
      final hash = md5.convert(cropped).toString().substring(0, 12);
      final path = '${dir.path}/${widget.folder.id}_$hash.jpg';
      await File(path).writeAsBytes(cropped);
      if (!mounted) return;
      setState(() { _avatarPath = path; _isUploading = false; });
    } catch (_) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove avatar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _avatarPath = null);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final root = rootScreenKey.currentState;
    if (name != widget.folder.name) root?.renameFavFolder(widget.folder.id, name);
    if (_avatarPath != widget.folder.avatarPath) {
      root?.setFavFolderAvatar(widget.folder.id, _avatarPath);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    const btnShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(50)));
    const btnPadding = EdgeInsets.symmetric(vertical: 13);
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        final fillColor = SettingsManager.getElementColor(
            cs.surfaceContainerHighest, brightness);
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
                    // ── Header ────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        border: Border(
                          bottom: BorderSide(
                              color: cs.primary.withValues(alpha: 0.10),
                              width: 0.8),
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
                            child: Icon(Icons.folder_open_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l.editFolder,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
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
                            child: GestureDetector(
                              onTap: _isUploading ? null : _pickAvatar,
                              onLongPress:
                                  _avatarPath != null ? _removeAvatar : null,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: cs.outline
                                              .withValues(alpha: 0.2),
                                          width: 2),
                                    ),
                                    child: ClipOval(
                                      child: _avatarPath != null &&
                                              File(_avatarPath!).existsSync()
                                          ? Image.file(File(_avatarPath!),
                                              fit: BoxFit.cover)
                                          : Container(
                                              color: cs.primaryContainer
                                                  .withValues(alpha: 0.5),
                                              child: Icon(
                                                  Icons.folder_rounded,
                                                  size: 44,
                                                  color: cs.primary),
                                            ),
                                    ),
                                  ),
                                  if (_isUploading)
                                    Container(
                                      width: 88,
                                      height: 88,
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Center(
                                          child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(l.tapAvatarLongRemove,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.45))),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            maxLength: 50,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            decoration: InputDecoration(
                              labelText: l.folderNameLabel,
                              counterText: '',
                              filled: true,
                              fillColor: fillColor.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.3),
                                    width: 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: cs.primary, width: 1.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                padding: btnPadding, shape: btnShape),
                            onPressed: _isUploading ? null : _save,
                            child: Text(l.save),
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
}

// ── New folder dialog ─────────────────────────────────────────────────────────

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog();

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _nameCtrl = TextEditingController();
  String? _avatarPath;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await showAvatarCropScreen(context, bytes);
      if (cropped == null) { setState(() => _isUploading = false); return; }
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final dir = Directory(
          '${(await getOnyxSupportDirectory()).path}/fav_folder_avatars');
      await dir.create(recursive: true);
      final hash = md5.convert(cropped).toString().substring(0, 12);
      final path = '${dir.path}/${id}_$hash.jpg';
      await File(path).writeAsBytes(cropped);
      if (!mounted) return;
      setState(() { _avatarPath = path; _isUploading = false; });
    } catch (_) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _create() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    rootScreenKey.currentState?.createFavFolder(name, avatarPath: _avatarPath);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    const btnShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(50)));
    const btnPadding = EdgeInsets.symmetric(vertical: 13);
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        final fillColor = SettingsManager.getElementColor(
            cs.surfaceContainerHighest, brightness);
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
                    // ── Header ────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.06),
                        border: Border(
                          bottom: BorderSide(
                              color: cs.primary.withValues(alpha: 0.10),
                              width: 0.8),
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
                            child: Icon(Icons.create_new_folder_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l.newFolder,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
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
                            child: GestureDetector(
                              onTap: _isUploading ? null : _pickAvatar,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: cs.outline
                                              .withValues(alpha: 0.2),
                                          width: 2),
                                    ),
                                    child: ClipOval(
                                      child: _avatarPath != null &&
                                              File(_avatarPath!).existsSync()
                                          ? Image.file(File(_avatarPath!),
                                              fit: BoxFit.cover)
                                          : Container(
                                              color: cs.primaryContainer
                                                  .withValues(alpha: 0.5),
                                              child: Icon(
                                                  Icons.folder_rounded,
                                                  size: 44,
                                                  color: cs.primary),
                                            ),
                                    ),
                                  ),
                                  if (_isUploading)
                                    Container(
                                      width: 88,
                                      height: 88,
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Center(
                                          child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            maxLength: 50,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _create(),
                            decoration: InputDecoration(
                              labelText: l.folderNameLabel,
                              counterText: '',
                              filled: true,
                              fillColor: fillColor.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.3),
                                    width: 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: cs.primary, width: 1.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                padding: btnPadding, shape: btnShape),
                            onPressed: _isUploading ? null : _create,
                            child: Text(l.create),
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
}

// ── New chat dialog ───────────────────────────────────────────────────────────

class _NewChatDialog extends StatefulWidget {
  final void Function(FavoriteChat) onAdd;
  const _NewChatDialog({required this.onAdd});

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _nameCtrl = TextEditingController();
  String? _avatarPath;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await showAvatarCropScreen(context, bytes);
      if (cropped == null) { setState(() => _isUploading = false); return; }
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final dir = Directory(
          '${(await getOnyxSupportDirectory()).path}/fav_avatars');
      await dir.create(recursive: true);
      final hash = md5.convert(cropped).toString().substring(0, 12);
      final path = '${dir.path}/${id}_${hash}.jpg';
      await File(path).writeAsBytes(cropped);
      if (!mounted) return;
      setState(() { _avatarPath = path; _isUploading = false; });
    } catch (_) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _create() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final fav = FavoriteChat.create(name).copyWith(avatarPath: _avatarPath);
    widget.onAdd(fav);
    Navigator.of(context).pop();
  }

  static const _btnShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(50)),
  );
  static const _btnPadding = EdgeInsets.symmetric(vertical: 13);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        final fillColor = SettingsManager.getElementColor(
            cs.surfaceContainerHighest, brightness);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                            child: Icon(Icons.bookmark_add_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.createChat,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.55)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Content ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: _isUploading ? null : _pickAvatar,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: cs.outline.withValues(alpha: 0.2),
                                          width: 2),
                                    ),
                                    child: ClipOval(
                                      child: _avatarPath != null &&
                                              File(_avatarPath!).existsSync()
                                          ? Image.file(File(_avatarPath!),
                                              fit: BoxFit.cover)
                                          : Container(
                                              color: fillColor.withValues(alpha: 0.3),
                                              child: Icon(Icons.bookmark,
                                                  size: 42, color: cs.primary),
                                            ),
                                    ),
                                  ),
                                  if (_isUploading)
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle),
                                      child: const Center(
                                          child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white))),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _nameCtrl,
                            autofocus: true,
                            maxLength: 50,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _create(),
                            decoration: InputDecoration(
                              labelText: l.chatNameLabel,
                              counterText: '',
                              filled: true,
                              fillColor: fillColor.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: cs.outlineVariant.withValues(alpha: 0.3),
                                    width: 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: cs.primary, width: 1.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isUploading ? null : _create,
                            style: FilledButton.styleFrom(
                              padding: _btnPadding,
                              shape: _btnShape,
                            ),
                            child: Text(l.create),
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
}