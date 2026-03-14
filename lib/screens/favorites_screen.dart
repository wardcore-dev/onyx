// lib/screens/favorites_screen.dart
import 'dart:convert';

import 'package:ONYX/screens/chats_tab.dart' show getPreviewText;
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {
  
  static final Set<String> _sessionInputAnimationsShown = {};

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final FocusNode _focusNode;
  Timer? _typingDebounce;
  bool _shouldPreserveExternalFocus = false;
  bool _suppressAutoRefocus = false;
  bool _showScrollDownButton = false;
  final Set<String> _alreadyRenderedMessageIds = {};
  
  bool _isVisible = false;
  late final AnimationController _enterAnimController;
  late final Animation<double> _enterOpacity;

  late AnimationController _inputEntryController;
  late Animation<double> _inputEntryScaleX;
  late Animation<double> _inputEntryOpacity;
  bool _hasInputAnimated = false;

  List<_ListItem>? _cachedDaySeparatorItems;
  List<ChatMessage>? _lastProcessedMessages;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scroll.addListener(_onScroll);

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
      _enterAnimController.reset();
      _enterAnimController.forward();
      _alreadyRenderedMessageIds.clear();
      
      Future.microtask(() => rootScreenKey.currentState
          ?.ensureMediaCachedForFavorite(widget.favoriteId));
    }
  }

  Map<String, dynamic>? _replyingToMessage;

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
    final atBottom = _scroll.position.pixels <= 1.0;
    if (mounted && _showScrollDownButton != !atBottom) {
      setState(() {
        _showScrollDownButton = !atBottom;
      });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _focusNode.dispose();
    _typingDebounce?.cancel();
    _enterAnimController.dispose();
    _inputEntryController.dispose();
    super.dispose();
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
    _scrollToBottom();
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
          onSend: () {
            _sendFile(filePath, basename, ext, type);
          },
          onCancel: () {
            rootScreenKey.currentState?.showSnack('File cancelled');
          },
        ),
      );
    } else {
      
      _sendFile(filePath, basename, ext, type);
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

  Future<void> _sendFile(
      String filePath, String basename, String ext, String type) async {
    try {
      final localId = DateTime.now().microsecondsSinceEpoch.toString();
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
      if (root != null) {
        root.chats.putIfAbsent(_chatId(), () => []).add(msg);
        root.persistChats();
        chatsVersion.value++;
        root.showSnack(
            ' ${type.toLowerCase().replaceFirst(type[0], type[0].toUpperCase())} added');
      }
    } catch (e, stack) {
      debugPrint('Error sending file: $e\n$stack');
      rootScreenKey.currentState?.showSnack('Failed to send file');
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
    final isMedia = text.toUpperCase().startsWith('VOICEV1:') ||
        text.toUpperCase().startsWith('IMAGEV1:') ||
        text.toUpperCase().startsWith('VIDEOV1:') ||
        text.startsWith('ALBUMv1:') ||
        text.startsWith('[cannot-decrypt');

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
    final isMedia = text.toUpperCase().startsWith('VOICEV1:') ||
        text.toUpperCase().startsWith('IMAGEV1:') ||
        text.toUpperCase().startsWith('VIDEOV1:') ||
        text.startsWith('ALBUMv1:') ||
        text.startsWith('[cannot-decrypt');
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
                                          const Color.fromARGB(255, 173, 136, 237),
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

  List<Widget> _buildFavoritesInputChildren() {
    return [
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
                          'fav:${widget.favoriteId}', _replyingToMessage);
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

      IconButton(
        icon: Icon(
          Icons.attach_file,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          size: 20,
        ),
        onPressed: () async {
          if (!kIsWeb) {
            try {
            final picker = FilePicker.platform;
            final result = await picker.pickFiles(
                type: FileType.any, allowMultiple: true);
            if (result == null || result.files.isEmpty) return;

            final paths = result.files
                .map((f) => f.path)
                .whereType<String>()
                .toList();
            if (paths.isEmpty) return;

            if (paths.length > 1 &&
                paths.every(FileTypeDetector.isImage)) {
              await _sendAlbum(paths);
              return;
            }

            final path = paths.first;
            if (!FileTypeDetector.isAllowed(path)) {
              final ext = p.extension(path).toLowerCase();
              rootScreenKey.currentState
                  ?.showSnack('Unsupported file type: $ext');
              return;
            }
            final basename = p.basename(path);
            final ext = p.extension(basename).toLowerCase();
            final type = FileTypeDetector.getFileType(path);
            _showFilePreviewAndSend(path, basename, ext, type);
            } catch (e) {
              debugPrint('[Attach] FilePicker error: $e');
              rootScreenKey.currentState?.showSnack('File picker error: $e');
            }
          }
        },
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
            maxLines: null,
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
      IconButton(
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _enterOpacity,
      child: _isVisible
          ? Scaffold(
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
        title: Row(
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
        actions: [],
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
                            
                            return Listener(
                              onPointerDown: (_) {
                                if (!isDesktop) return;
                                _suppressAutoRefocus = true;
                                _focusNode.unfocus();
                              },
                              child: ListView.builder(
                                  controller: _scroll,
                                  reverse: true,
                                  cacheExtent: 100, 
                                  addRepaintBoundaries: true,
                                  addAutomaticKeepAlives: false, 
                                  padding: EdgeInsets.only(
                                    top: MediaQuery.of(context).padding.top +
                                        kToolbarHeight +
                                        12,
                                    bottom: 72 + MediaQuery.of(context).padding.bottom,
                                  ),
                                  itemCount: msgs.isEmpty
                                      ? 0
                                      : _buildMessagesWithDaySeparators(msgs)
                                          .length,
                                  itemBuilder: (context, i) {
                                    final items =
                                        _buildMessagesWithDaySeparators(msgs);
                                    final item = items[i];
                                    if (item is _DaySeparatorItem) {
                                      
                                      return RepaintBoundary(
                                        child: _buildDaySeparator(
                                            context, item.date),
                                      );
                                    }
                                    final msg = (item as _MessageItem).message;
                                    final String uniqueKey =
                                        '${msg.id}_${msg.serverMessageId ?? 'local'}_${msg.time.millisecondsSinceEpoch}';
                                    final isFirstAppearance =
                                        !_alreadyRenderedMessageIds
                                            .contains(uniqueKey);
                                    if (isFirstAppearance) {
                                      _alreadyRenderedMessageIds.add(uniqueKey);
                                    }
                                    final bubbleWidget = Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 12),
                                      child: Row(
                                        mainAxisAlignment: alignRight
                                            ? (swapped
                                                ? MainAxisAlignment.start
                                                : MainAxisAlignment.end)
                                            : (swapped
                                                ? MainAxisAlignment.start
                                                : MainAxisAlignment.end),
                                        children: [
                                          Flexible(
                                            child: GestureDetector(
                                              onTapDown: (tap) {
                                                debugPrint(
                                                    '[favorites_screen::msgTapDown] tapped message id=${msg.serverMessageId ?? msg.id} replying=${_replyingToMessage != null} reply=${_replyingToMessage?.toString()}\n${StackTrace.current}');
                                              },
                                              onHorizontalDragEnd: isDesktop ? null : (details) {
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
                                              child: MessageBubble(
                                                key: ValueKey<String>(
                                                    'mb_inner_$uniqueKey'),
                                                text: msg.content,
                                                outgoing: true,
                                                time: msg.time,
                                                peerUsername: '',
                                                chatMessage: msg,
                                                replyToId: msg.replyToId,
                                                replyToUsername:
                                                    msg.replyToSender,
                                                replyToContent:
                                                    msg.replyToContent,
                                                desktopMenuItems: _buildDesktopMenuItems(msg),
                                                highlighted: (msg
                                                                .serverMessageId !=
                                                            null &&
                                                        _replyingToMessage !=
                                                            null &&
                                                        _replyingToMessage![
                                                                    'id']
                                                                ?.toString() ==
                                                            (msg.serverMessageId
                                                                ?.toString())) ||
                                                    (msg.serverMessageId ==
                                                            null &&
                                                        _replyingToMessage !=
                                                            null &&
                                                        _replyingToMessage![
                                                                    'localId']
                                                                ?.toString() ==
                                                            msg.id?.toString()),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    return RepaintBoundary(
                                      child: isFirstAppearance
                                          ? _AnimatedMessageBubble(
                                              key: ValueKey<String>(uniqueKey),
                                              child: bubbleWidget,
                                            )
                                          : bubbleWidget,
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