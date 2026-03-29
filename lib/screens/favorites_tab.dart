// lib/screens/favorites_tab.dart
import 'dart:io';
import 'dart:convert';
import 'package:ONYX/globals.dart';
import 'package:ONYX/managers/settings_manager.dart';
import 'package:ONYX/models/chat_message.dart';
import 'package:ONYX/models/favorite_chat.dart';
import 'package:flutter/material.dart';

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

String _formatTime(DateTime t) {
  final now = DateTime.now();
  if (now.difference(t).inDays == 0) {
    return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.day}.${t.month}';
}

bool _isMediaPreview(String preview) {
  return preview == 'Voice message' ||
      preview == 'Image' ||
      preview == 'Video file' ||
      preview.startsWith('[Message not decrypted]');
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

class _FavoritesTabState extends State<FavoritesTab> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  late final AnimationController _listAnimController;
  late final Animation<double> _listFadeAnim;
  bool _isVisible = false;
  
  late double _staggerStep; 

  @override
  void initState() {
    super.initState();
    
    final dur = Platform.isWindows ? const Duration(milliseconds: 120) : const Duration(milliseconds: 350);
    _staggerStep = Platform.isWindows ? 0.02 : 0.05;
    _listAnimController = AnimationController(
      duration: dur,
      vsync: this,
    );
    _listFadeAnim = CurvedAnimation(
      parent: _listAnimController,
      curve: Curves.easeOut,
    );
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _isVisible = true);
        if (!_listAnimController.isAnimating) _listAnimController.forward();
      }
    });
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
  }

  String _getPreviewForFavorite(String favId, Map<String, List<ChatMessage>> allChats) {
    final chatId = 'fav:$favId';
    final msgs = allChats[chatId] ?? [];
    if (msgs.isEmpty) return '';
    return _getPreviewText(msgs.last.content);
  }

  DateTime _getLastTsForFavorite(String favId, Map<String, List<ChatMessage>> allChats) {
    final chatId = 'fav:$favId';
    final msgs = allChats[chatId] ?? [];
    if (msgs.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return msgs.last.time;
  }

  String _getFileTypeLabel(String filename) {
    final ext = filename.toLowerCase();

    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.m4a') ||
        ext.endsWith('.aac') || ext.endsWith('.flac') || ext.endsWith('.wma')) {
      return 'Music';
    }

    if (ext.endsWith('.mp4') || ext.endsWith('.mkv') || ext.endsWith('.mov') ||
        ext.endsWith('.avi') || ext.endsWith('.wmv') || ext.endsWith('.flv') ||
        ext.endsWith('.webm') || ext.endsWith('.m4v')) {
      return 'Video';
    }

    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') ||
        ext.endsWith('.gif') || ext.endsWith('.webp') || ext.endsWith('.bmp') ||
        ext.endsWith('.svg') || ext.endsWith('.ico')) {
      return 'Image';
    }

    if (ext.endsWith('.pdf') || ext.endsWith('.doc') || ext.endsWith('.docx') ||
        ext.endsWith('.txt') || ext.endsWith('.rtf') || ext.endsWith('.odt')) {
      return 'Document';
    }

    if (ext.endsWith('.xls') || ext.endsWith('.xlsx') || ext.endsWith('.csv') ||
        ext.endsWith('.ods')) {
      return 'Spreadsheet';
    }

    if (ext.endsWith('.ppt') || ext.endsWith('.pptx') || ext.endsWith('.odp')) {
      return 'Presentation';
    }

    if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z') ||
        ext.endsWith('.tar') || ext.endsWith('.gz') || ext.endsWith('.bz2') ||
        ext.endsWith('.iso') || ext.endsWith('.exe') || ext.endsWith('.dmg')) {
      return 'Archive';
    }

    if (ext.endsWith('.js') || ext.endsWith('.py') || ext.endsWith('.java') ||
        ext.endsWith('.cpp') || ext.endsWith('.c') || ext.endsWith('.ts') ||
        ext.endsWith('.dart') || ext.endsWith('.swift') || ext.endsWith('.go') ||
        ext.endsWith('.rb') || ext.endsWith('.php') || ext.endsWith('.sh') ||
        ext.endsWith('.json') || ext.endsWith('.xml') || ext.endsWith('.yaml') ||
        ext.endsWith('.yml') || ext.endsWith('.html') || ext.endsWith('.css')) {
      return 'Artifact';
    }

    return 'File';
  }

  bool _isPurplePreview(String preview) {
    
    final purpleLabels = {
      'Voice message', 'Image', 'Video file', 'Music', 'Video', 'Image', 'Document',
      'Spreadsheet', 'Presentation', 'Archive', 'Artifact', 'File'
    };
    if (preview.startsWith('[Message not decrypted]')) return true;
    if (preview == 'Album' || preview.startsWith('Album ·')) return true;
    return purpleLabels.contains(preview);
  }

  String _getPreviewText(String rawContent) {
    if (rawContent.startsWith('VOICEv1:')) return 'Voice message';
    if (rawContent.startsWith('AUDIOv1:')) return 'Music';
    if (rawContent.startsWith('IMAGEv1:')) return 'Image';
    if (rawContent.startsWith('VIDEOv1:') || rawContent.toUpperCase().startsWith('VIDEOV1:')) return 'Video file';

    if (rawContent.startsWith('MEDIA_PROXYv1:') || rawContent.startsWith('MEDIA_PROXY:')) {
      try {
        final jsonPart = rawContent.substring(rawContent.indexOf(':') + 1);
        final data = jsonDecode(jsonPart) as Map<String, dynamic>;
        final type = (data['type'] as String?)?.toLowerCase();
        final orig = (data['orig'] ?? data['filename'] ?? data['name'] ?? '') as String;
        if (type == 'voice') return 'Voice message';
        if (type == 'audio') return 'Music';
        if (type == 'video') return 'Video';
        if (type == 'image') return 'Image';
        if (orig.isNotEmpty) return _getFileTypeLabel(orig);
        return 'File';
      } catch (e) {
        return 'File';
      }
    }

    if (rawContent.startsWith('FILEv1:') || rawContent.startsWith('DOCUMENTv1:') || rawContent.startsWith('ARCHIVEv1:') || rawContent.startsWith('DATAv1:')) {
      try {
        final jsonPart = rawContent.substring(rawContent.indexOf(':') + 1);
        final meta = jsonDecode(jsonPart) as Map<String, dynamic>;
        final filename = (meta['filename'] ?? meta['orig'] ?? meta['name'] ?? 'File') as String;
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

  void _showDeleteConfirmation(BuildContext context, FavoriteChat fav) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from favorites?'),
        content: Text('Are you sure you want to remove "${fav.title}" from your favorites?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete(fav.id);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return ValueListenableBuilder<int>(
      valueListenable: chatsVersion,
      builder: (context, _, __) {
        return ValueListenableBuilder<int>(
          valueListenable: favoritesVersion,
          builder: (context, __, ___) {
            final chats = rootScreenKey.currentState?.chats ?? {};
            final sortedFavorites = [...widget.favorites]..sort((a, b) {
              final tsA = _getLastTsForFavorite(a.id, chats);
              final tsB = _getLastTsForFavorite(b.id, chats);
              return tsB.compareTo(tsA);
            });
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
              itemCount: sortedFavorites.length + 1,
              cacheExtent: 500,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
            if (i == sortedFavorites.length) {
              final colorScheme = Theme.of(context).colorScheme;
              return FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(
                    parent: _listAnimController,
                    curve: Interval(
                      sortedFavorites.length * _staggerStep,
                      1.0,
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.15),
                        width: 0.8,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final name = await _promptName(context);
                        if (name?.isNotEmpty == true) {
                          widget.onAdd(FavoriteChat.create(name!));
                        }
                      },
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            final fav = sortedFavorites[i];
            final preview = _getPreviewForFavorite(fav.id, chats);
            final lastTs = _getLastTsForFavorite(fav.id, chats);

            return FadeTransition(
              opacity: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _listAnimController,
                  curve: Interval(i * _staggerStep, 1.0, curve: Curves.easeOut),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.onOpen(fav.id),
                onLongPress: () => _showDeleteConfirmation(context, fav),
                child: _glassCard(
                  context: context,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    child: Row(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: SettingsManager.elementBrightness,
                          builder: (_, brightness, __) {
                            final baseColor = SettingsManager.getElementColor(
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                              brightness,
                            );
                            return SizedBox(
                              width: 40,
                              height: 40,
                              child: ClipOval(
                                child: fav.avatarPath != null
                                    ? Image.file(
                                        File(fav.avatarPath!),
                                        fit: BoxFit.cover,
                                        width: 40,
                                        height: 40,
                                        errorBuilder: (ctx, err, st) => CircleAvatar(
                                          radius: 20,
                                          backgroundColor: baseColor,
                                          child: Icon(
                                            Icons.bookmark,
                                            size: 18,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 20,
                                        backgroundColor: baseColor,
                                        child: Icon(
                                          Icons.bookmark,
                                          size: 18,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
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
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (preview.isNotEmpty)
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isPurplePreview(preview) ? FontWeight.w500 : null,
                                    color: _isPurplePreview(preview)
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (lastTs.millisecondsSinceEpoch > 0)
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                _formatTime(lastTs),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
          },
        );
      },
    );
  }

  Future<String?> _promptName(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementBrightness,
          builder: (_, brightness, __) {
            final fillColor = SettingsManager.getElementColor(
                cs.surfaceContainerHighest, brightness);
            return AlertDialog(
              backgroundColor: cs.surface.withValues(alpha: SettingsManager.elementOpacity.value),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('New Favorite Chat'),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                decoration: InputDecoration(
                  labelText: 'Chat name',
                  labelStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: fillColor.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                        width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                        width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: cs.primary, width: 1.4),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}