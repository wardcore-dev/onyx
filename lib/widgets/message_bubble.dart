// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../managers/settings_manager.dart';
import '../managers/external_server_manager.dart';
import '../widgets/image_message_widget.dart';
import '../widgets/album_message_widget.dart';
import '../widgets/voice_message_widget.dart';
import '../widgets/video_message_widget.dart';
import '../widgets/code_block_widget.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/link_preview_card.dart';
import '../models/chat_message.dart';
import '../globals.dart';
import '../models/font_family.dart';
import '../enums/delivery_mode.dart';
import '../services/mesh/mesh_file_transfer.dart';

/// A menu item for the desktop right-click context menu, with optional icon.
class DesktopMenuItem {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final ContextMenuButtonType type;
  final Color? color;

  const DesktopMenuItem({
    this.icon,
    required this.label,
    this.onPressed,
    this.type = ContextMenuButtonType.custom,
    this.color,
  });
}

IconData? _standardIcon(ContextMenuButtonType type) => switch (type) {
      ContextMenuButtonType.copy => Icons.content_copy_rounded,
      ContextMenuButtonType.cut => Icons.content_cut_rounded,
      ContextMenuButtonType.paste => Icons.content_paste_rounded,
      ContextMenuButtonType.selectAll => Icons.select_all_rounded,
      ContextMenuButtonType.delete => Icons.delete_outline_rounded,
      _ => null,
    };

Widget _menuRow({
  required IconData? icon,
  required String label,
  required VoidCallback? onPressed,
  required ColorScheme cs,
  Color? color,
}) {
  final c = color ?? cs.onSurface;
  return InkWell(
    onTap: onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: icon != null ? Icon(icon, size: 18, color: c) : null,
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, color: c)),
        ],
      ),
    ),
  );
}

class _ContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _ContextMenuLayoutDelegate(this.anchor);
  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = anchor.dx;
    double y = anchor.dy;
    if (x + childSize.width > size.width) x = size.width - childSize.width;
    if (y + childSize.height > size.height) y = size.height - childSize.height;
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_ContextMenuLayoutDelegate old) => old.anchor != anchor;
}

/// Shows the desktop floating context menu at [position] with the given [items].
/// Uses the same card style as the SelectionArea context menu in [MessageBubble].
void showMessageDesktopMenu(
  BuildContext context,
  Offset position,
  List<DesktopMenuItem> items,
) {
  debugPrint(
      '[RightClickMenu] showMessageDesktopMenu called, items=${items.length}, mounted=${context.mounted}, pos=$position');
  ContextMenuController.removeAny();
  final controller = ContextMenuController();
  controller.show(
    context: context,
    contextMenuBuilder: (ctx) {
      debugPrint(
          '[RightClickMenu] contextMenuBuilder running, building menu UI');
      final cs = Theme.of(ctx).colorScheme;
      return TapRegion(
        onTapOutside: (_) {
          debugPrint(
              '[RightClickMenu] TapRegion.onTapOutside fired, removing menu');
          ContextMenuController.removeAny();
        },
        child: CustomSingleChildLayout(
          delegate: _ContextMenuLayoutDelegate(position),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: SettingsManager.glassSurfaceColor(cs.surfaceContainerHigh),
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items)
                      _menuRow(
                        icon: _standardIcon(item.type) ?? item.icon,
                        label: item.label,
                        onPressed: item.onPressed == null
                            ? null
                            : () {
                                ContextMenuController.removeAny();
                                item.onPressed!();
                              },
                        cs: cs,
                        color: item.color,
                      ),
                  ],
                ),
              ),
            ),
          ), // closes CustomSingleChildLayout
        ), // closes TapRegion
      );
    },
  );
}

enum _MdTokenType { plain, bold, underline, strike, italic, code, url }

class _MdToken {
  final _MdTokenType type;
  final String text;
  final String raw;
  const _MdToken(this.type, this.text, [this.raw = '']);
}

final RegExp _mdTokenRx = RegExp(
  r'\*\*(.+?)\*\*' // **bold**
  r'|__(.+?)__' // __underline__
  r'|~~(.+?)~~' // ~~strikethrough~~
  r'|\*(.+?)\*' // *italic*
  r'|`([^`]+)`' // `inline code`
  r'|\bhttps?://[^\s<>"{}|\\^`\[\]]+' // URL
  r'|\bwww\.[^\s<>"{}|\\^`\[\]]+', // www URL
  caseSensitive: false,
  dotAll: false,
);

// Bounded cache of regex tokenization results, keyed by raw message text.
// Capped so a very long chat session doesn't grow this unboundedly.
final Map<String, List<_MdToken>> _mdTokenCache = <String, List<_MdToken>>{};
const int _mdTokenCacheLimit = 300;

// Hoisted so the pattern isn't recompiled on every bubble rebuild (it's
// used in two places that both ran on every rebuild of a text message).
final RegExp _codeBlockRegex =
    RegExp(r'```([\w+-]*)\s*([\s\S]*?)```', multiLine: true);

List<_MdToken> _tokenizeMarkdown(String input) {
  final cached = _mdTokenCache[input];
  if (cached != null) return cached;

  final tokens = <_MdToken>[];
  int lastEnd = 0;
  for (final m in _mdTokenRx.allMatches(input)) {
    if (m.start > lastEnd) {
      tokens
          .add(_MdToken(_MdTokenType.plain, input.substring(lastEnd, m.start)));
    }
    final raw = m.group(0)!;
    if (m.group(1) != null) {
      tokens.add(_MdToken(_MdTokenType.bold, m.group(1)!));
    } else if (m.group(2) != null) {
      tokens.add(_MdToken(_MdTokenType.underline, m.group(2)!));
    } else if (m.group(3) != null) {
      tokens.add(_MdToken(_MdTokenType.strike, m.group(3)!));
    } else if (m.group(4) != null) {
      tokens.add(_MdToken(_MdTokenType.italic, m.group(4)!));
    } else if (m.group(5) != null) {
      tokens.add(_MdToken(_MdTokenType.code, m.group(5)!));
    } else {
      tokens.add(_MdToken(_MdTokenType.url, raw, raw));
    }
    lastEnd = m.end;
  }
  if (lastEnd < input.length) {
    tokens.add(_MdToken(_MdTokenType.plain, input.substring(lastEnd)));
  }

  if (_mdTokenCache.length >= _mdTokenCacheLimit) {
    _mdTokenCache.remove(_mdTokenCache.keys.first);
  }
  _mdTokenCache[input] = tokens;
  return tokens;
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool outgoing;
  final String? rawPreview;
  final int? serverMessageId;
  final DateTime time;
  final void Function(int? id)? onRequestResend;
  final String peerUsername;
  final ChatMessage? chatMessage;
  final int? replyToId;
  final String? replyToUsername;
  final String? replyToContent;
  final bool highlighted;
  final VoidCallback? onReplyTap;
  final bool hasReminder;

  final List<DesktopMenuItem>? desktopMenuItems;

  /// Called with the global tap position when the user right-clicks on desktop.
  /// When provided, the built-in SelectionArea context menu is suppressed and
  /// this callback is responsible for showing its own menu.
  final void Function(Offset)? onRightClick;

  /// When provided, SelectionArea is replaced with a plain GestureDetector so
  /// the long-press can be handled by the caller (e.g. message selection mode).
  final VoidCallback? onLongPress;

  const MessageBubble({
    Key? key,
    required this.text,
    required this.outgoing,
    this.rawPreview,
    this.serverMessageId,
    required this.time,
    this.onRequestResend,
    required this.peerUsername,
    this.chatMessage,
    this.replyToId,
    this.replyToUsername,
    this.replyToContent,
    this.highlighted = false,
    this.onReplyTap,
    this.hasReminder = false,
    this.desktopMenuItems,
    this.onRightClick,
    this.onLongPress,
  }) : super(key: key);

  bool get isDiagnostic => text.startsWith('[cannot-decrypt');

  // Hoisted to a static field: the 4 underlying notifiers never change, so
  // building a fresh Listenable.merge() (and re-subscribing to all 4) on
  // every single bubble's every rebuild was pure churn across the whole
  // visible list each time a new message arrived.
  static final Listenable _appearanceListenable = Listenable.merge([
    SettingsManager.fontFamily,
    SettingsManager.fontSizeMultiplier,
    SettingsManager.elementBrightness,
    SettingsManager.elementOpacity,
  ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appearanceListenable,
      builder: (context, _) {
        return _buildMessageBubble(
          context,
          SettingsManager.fontFamily.value,
          SettingsManager.fontSizeMultiplier.value,
          SettingsManager.elementBrightness.value,
          SettingsManager.elementOpacity.value,
        );
      },
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    FontFamilyType fontFamily,
    double fontSizeMultiplier,
    double brightness,
    double msgOpacity,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    const double outgoingBorderAlpha = 0.3;
    const double incomingBorderAlpha = 0.2;
    final Color textRaw = colorScheme.onSurface;
    final Color textColor = textRaw;
    Widget primaryContent;
    String? linkPreviewUrl;

    final bool isLight = colorScheme.surface.computeLuminance() > 0.5;
    final Color outgoingBase = isLight
        ? Color.lerp(colorScheme.surface, colorScheme.primary, 0.20)!
        : colorScheme.primaryContainer;
    final Color baseRawOutgoing = SettingsManager.getElementColor(
      outgoingBase,
      brightness,
    );
    final Color baseRawIncoming = SettingsManager.getElementColor(
      colorScheme.surfaceVariant,
      brightness,
    );

    final Color replyBgOutgoing = SettingsManager.getElementColor(
      colorScheme.surface,
      brightness,
    );
    final Color replyBgIncoming = SettingsManager.getElementColor(
      colorScheme.surfaceVariant,
      brightness,
    );
    final Color pendingUploadBg = SettingsManager.getElementColor(
      colorScheme.surfaceContainer,
      brightness,
    );

    if (replyToContent != null && replyToContent!.isNotEmpty) {
      debugPrint(
          '[MessageBubble] Has reply - replyToId=$replyToId, replyToUsername=$replyToUsername, replyToContent=$replyToContent');
    }
    final Color baseColor = outgoing
        ? baseRawOutgoing.withOpacity(msgOpacity)
        : baseRawIncoming.withOpacity(msgOpacity);
    final Color borderColor = outgoing
        ? colorScheme.primary.withOpacity(msgOpacity * outgoingBorderAlpha)
        : colorScheme.outline.withOpacity(msgOpacity * incomingBorderAlpha);
    final Color textColorFinal = textRaw.withOpacity(msgOpacity);

    if (text.startsWith('MESH_FILE:')) {
      final mimeType = chatMessage?.meshFileMimeType ?? '';
      final localPath = chatMessage?.meshFileLocalPath;
      final meshFileName =
          chatMessage?.meshFileName ?? text.substring('MESH_FILE:'.length);
      final fileSize = chatMessage?.meshFileSize ?? 0;
      final meshFileId = chatMessage?.meshFileId;

      if (mimeType.startsWith('image/') && localPath != null) {
        primaryContent = ImageMessageWidget(
          filename: 'file://$localPath',
          peerUsername: peerUsername,
          isOutgoing: outgoing,
          fontSizeMultiplier: fontSizeMultiplier,
        );
      } else if (mimeType.startsWith('audio/') && localPath != null) {
        mediaFilePathRegistry[meshFileName] = localPath;
        primaryContent = IntrinsicWidth(
          child: VoiceMessagePlayer(
            filename: meshFileName,
            label: '',
            peerUsername: peerUsername,
          ),
        );
      } else if (mimeType.startsWith('video/') && localPath != null) {
        primaryContent = VideoMessageWidget(
          filename: 'file://$localPath',
          peerUsername: peerUsername,
          fontSizeMultiplier: fontSizeMultiplier,
        );
      } else {
        // File not yet received — show progress or placeholder
        final IconData fileIcon;
        if (mimeType.startsWith('image/'))
          fileIcon = Icons.image_rounded;
        else if (mimeType.startsWith('video/'))
          fileIcon = Icons.videocam_rounded;
        else if (mimeType.startsWith('audio/'))
          fileIcon = Icons.audiotrack_rounded;
        else
          fileIcon = Icons.insert_drive_file_rounded;

        primaryContent = ValueListenableBuilder<Map<String, double>>(
          valueListenable: MeshFileTransferService.instance.progress,
          builder: (_, progressMap, __) {
            final progress =
                meshFileId != null ? (progressMap[meshFileId] ?? 0.0) : 0.0;
            return _meshFilePlaceholder(
                meshFileName, fileSize, fileIcon, colorScheme,
                progress: progress);
          },
        );
      }
    } else if (text.startsWith('VOICEv1:')) {
      final meta =
          jsonDecode(text.substring('VOICEv1:'.length)) as Map<String, dynamic>;

      final filename =
          meta['url'] as String? ?? meta['filename'] as String? ?? '';
      final owner = meta['owner'] as String?;
      final voiceMediaKeyB64 = meta['key'] as String?;
      debugPrint(
          '[MessageBubble] VOICE - url: ${meta['url']}, filename: ${meta['filename']}, owner: $owner, result: "$filename"');
      primaryContent = IntrinsicWidth(
        child: VoiceMessagePlayer(
          filename: filename,
          owner: owner,
          label: '',
          peerUsername: peerUsername,
          mediaKeyB64: voiceMediaKeyB64,
        ),
      );
    } else if (text.startsWith('AUDIOv1:')) {
      try {
        final meta = jsonDecode(text.substring('AUDIOv1:'.length))
            as Map<String, dynamic>;
        final filename =
            (meta['filename'] ?? meta['orig'] ?? 'audio') as String;
        final orig = (meta['orig'] ?? meta['filename'] ?? '') as String;
        final owner = meta['owner'] as String?;
        final audioKeyB64 = meta['key'] as String?;
        primaryContent = VoiceMessagePlayer(
          filename: filename,
          owner: owner,
          label: '',
          peerUsername: peerUsername,
          mediaKeyB64: audioKeyB64,
          isFile: true,
          origName: orig.isNotEmpty ? orig : null,
          expand: true,
        );
      } catch (e) {
        primaryContent = FileMessageWidget(
          filename: text,
          peerUsername: peerUsername,
          isOutgoing: outgoing,
          senderUsername: chatMessage?.from,
          fontSizeMultiplier: fontSizeMultiplier,
        );
      }
    } else if (text.startsWith('IMAGEv1:')) {
      final jsonPart = text.substring('IMAGEv1:'.length);
      final data = jsonDecode(jsonPart) as Map<String, dynamic>;

      final filename =
          data['url'] as String? ?? data['filename'] as String? ?? '';
      final owner = data['owner'] as String?;
      final imageMediaKeyB64 = data['key'] as String?;
      final blurHash = data['blur'] as String?;
      final ar = (data['ar'] as num?)?.toDouble();
      debugPrint(
          '[MessageBubble] IMAGE - url: ${data['url']}, filename: ${data['filename']}, owner: $owner, result: "$filename"');
      primaryContent = ImageMessageWidget(
        filename: filename,
        owner: owner,
        peerUsername: peerUsername,
        isOutgoing: outgoing,
        mediaKeyB64: imageMediaKeyB64,
        blurHash: blurHash,
        initialAspectRatio: ar,
        fontSizeMultiplier: fontSizeMultiplier,
      );
    } else if (text.toUpperCase().startsWith('VIDEOV1:')) {
      final prefixLen = 'VIDEOv1:'.length;
      final meta =
          jsonDecode(text.substring(prefixLen)) as Map<String, dynamic>;

      final filename = meta['url'] as String? ?? meta['filename'] as String?;
      final owner = meta['owner'] as String?;
      final origName = meta['orig'] as String? ?? 'video';
      final pending = meta['pending_upload'] == true;
      final videoMediaKeyB64 = meta['key'] as String?;
      final videoBlurHash = meta['blur'] as String?;
      final videoAr = (meta['ar'] as num?)?.toDouble();
      debugPrint(
          '[MessageBubble] VIDEO - url: ${meta['url']}, filename: ${meta['filename']}, owner: $owner, result: "$filename", pending: $pending');
      if (pending) {
        primaryContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: pendingUploadBg.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_file, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Uploading $origName...',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        );
      } else if (filename != null && filename.isNotEmpty) {
        primaryContent = VideoMessageWidget(
          filename: filename,
          owner: owner,
          peerUsername: peerUsername,
          mediaKeyB64: videoMediaKeyB64,
          blurHash: videoBlurHash,
          initialAspectRatio: videoAr,
          fontSizeMultiplier: fontSizeMultiplier,
        );
      } else {
        primaryContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: colorScheme.error,
              ),
              const SizedBox(width: 6),
              Text(
                'Video not uploaded',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onError,
                ),
              ),
            ],
          ),
        );
      }
    } else if (text.startsWith('DOCUMENTv1:') ||
        text.startsWith('ARCHIVEv1:') ||
        text.startsWith('DATAv1:')) {
      try {
        final meta = jsonDecode(text.substring(text.indexOf(':') + 1))
            as Map<String, dynamic>;
        final filename = meta['filename'] as String? ?? '';
        primaryContent = FileMessageWidget(
          filename: filename,
          peerUsername: peerUsername,
          isOutgoing: outgoing,
          senderUsername: chatMessage?.from,
          fontSizeMultiplier: fontSizeMultiplier,
        );
      } catch (e) {
        primaryContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('File not available',
              style: TextStyle(color: colorScheme.onError)),
        );
      }
    } else if (text.startsWith('FILEv1:') || text.startsWith('FILE:')) {
      String filename = '';
      String? owner;
      String? fileMediaKeyB64;
      try {
        String origName = '';
        if (text.startsWith('FILEv1:')) {
          final meta = jsonDecode(text.substring('FILEv1:'.length))
              as Map<String, dynamic>;
          filename = meta['filename'] as String? ?? '';
          owner = meta['owner'] as String?;
          fileMediaKeyB64 = meta['key'] as String?;
          origName = meta['orig'] as String? ?? '';
        } else {
          filename = text.substring('FILE:'.length).trim();
        }
        if (filename.isNotEmpty) {
          const audioExts = {
            '.mp3',
            '.wav',
            '.aac',
            '.m4a',
            '.flac',
            '.ogg',
            '.wma',
            '.opus',
            '.aiff',
            '.aif'
          };
          final audioName = origName.isNotEmpty ? origName : filename;
          final dot = audioName.lastIndexOf('.');
          final ext = dot >= 0 ? audioName.substring(dot).toLowerCase() : '';
          if (audioExts.contains(ext) && !filename.startsWith('lan://')) {
            primaryContent = VoiceMessagePlayer(
              filename: filename,
              owner: owner,
              label: '',
              peerUsername: peerUsername,
              mediaKeyB64: fileMediaKeyB64,
              isFile: true,
              origName: origName.isNotEmpty ? origName : null,
              expand: true,
            );
          } else {
            primaryContent = FileMessageWidget(
              filename: filename,
              owner: owner,
              peerUsername: peerUsername,
              isOutgoing: outgoing,
              senderUsername: chatMessage?.from,
              mediaKeyB64: fileMediaKeyB64,
              fontSizeMultiplier: fontSizeMultiplier,
            );
          }
        } else {
          primaryContent = Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('File not available',
                style: TextStyle(color: colorScheme.onError)),
          );
        }
      } catch (e) {
        primaryContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('File not available',
              style: TextStyle(color: colorScheme.onError)),
        );
      }
    } else if (text.startsWith('ALBUMv1:')) {
      try {
        final list =
            jsonDecode(text.substring('ALBUMv1:'.length)) as List<dynamic>;
        final albumItems = list
            .whereType<Map<String, dynamic>>()
            .map(AlbumItem.fromJson)
            .where((i) => i.filename.isNotEmpty)
            .toList();
        if (albumItems.isEmpty) throw Exception('Empty album');
        primaryContent = AlbumMessageWidget(
          items: albumItems,
          peerUsername: peerUsername,
          isOutgoing: outgoing,
          fontSizeMultiplier: fontSizeMultiplier,
        );
      } catch (e) {
        primaryContent = Text(' Invalid ALBUM: $e');
      }
    } else if (text.startsWith('MEDIA_PROXYv1:')) {
      try {
        final jsonPart = text.substring('MEDIA_PROXYv1:'.length);
        final data = jsonDecode(jsonPart) as Map<String, dynamic>;
        final url = (data['url'] as String?)?.trim();
        final orig = data['orig'] as String? ?? 'file';
        final type = data['type'] as String?;

        if (type == 'album') {
          final rawItems = data['items'];
          final itemList = rawItems is List ? rawItems : [];
          final albumItems = itemList
              .whereType<Map<String, dynamic>>()
              .map(AlbumItem.fromJson)
              .where((i) => i.filename.isNotEmpty)
              .toList();
          primaryContent = AlbumMessageWidget(
            items: albumItems,
            peerUsername: '<external>',
            isOutgoing: outgoing,
            fontSizeMultiplier: fontSizeMultiplier,
          );
        } else {
          if (url == null || url.isEmpty) throw Exception('No URL');

          final authUrl = ExternalServerManager.addTokenToUrl(url);

          if (type == 'voice') {
            primaryContent = IntrinsicWidth(
              child: VoiceMessagePlayer(
                filename: authUrl,
                label: '',
                peerUsername: '<external>',
              ),
            );
          } else if (type == 'audio') {
            primaryContent = VoiceMessagePlayer(
              filename: authUrl,
              label: '',
              peerUsername: '<external>',
              origName: orig.isNotEmpty ? orig : null,
              expand: true,
            );
          } else if (type == 'document' ||
              type == 'archive' ||
              type == 'data' ||
              type == 'file') {
            primaryContent = FileMessageWidget(
              filename: orig,
              peerUsername: '<external>',
              isOutgoing: outgoing,
              senderUsername: chatMessage?.from,
              directUrl: authUrl,
              fontSizeMultiplier: fontSizeMultiplier,
            );
          } else {
            final lower = url.toLowerCase();
            final origLower = orig.toLowerCase();
            final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
                    .any(origLower.endsWith) ||
                ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any(lower.endsWith);
            final isVideo = ['.mp4', '.mov', '.m4v', '.webm', '.m4a']
                    .any(origLower.endsWith) ||
                ['.mp4', '.mov', '.m4v', '.webm', '.m4a'].any(lower.endsWith);

            if (isImage) {
              primaryContent = ImageMessageWidget(
                filename: authUrl,
                peerUsername: '<external>',
                isOutgoing: outgoing,
                fontSizeMultiplier: fontSizeMultiplier,
              );
            } else if (isVideo) {
              primaryContent = VideoMessageWidget(
                filename: authUrl,
                peerUsername: '<external>',
                fontSizeMultiplier: fontSizeMultiplier,
              );
            } else {
              primaryContent = FileMessageWidget(
                filename: orig,
                peerUsername: '<external>',
                isOutgoing: outgoing,
                senderUsername: chatMessage?.from,
                directUrl: authUrl,
                fontSizeMultiplier: fontSizeMultiplier,
              );
            }
          }
        }
      } catch (e) {
        primaryContent = Text(' Invalid MEDIA_PROXY: $e');
      }
    } else {
      final _urlRx = RegExp(
        r'\bhttps?://[^\s<>"{}|\\^`\[\]]+|\bwww\.[^\s<>"{}|\\^`\[\]]+',
        caseSensitive: false,
      );
      final _firstMatch = _urlRx.firstMatch(text);
      if (_firstMatch != null) {
        final _raw = _firstMatch.group(0)!;
        linkPreviewUrl = _raw.startsWith('http') ? _raw : 'https://$_raw';
      }

      primaryContent = Builder(
        builder: (context) {
          final codeMatches = _codeBlockRegex.allMatches(text).toList();

          bool looksLikeCode = _isLikelyCode(text);

          if (codeMatches.isNotEmpty || looksLikeCode) {
            final children = <Widget>[];
            int lastEnd = 0;

            if (codeMatches.isNotEmpty) {
              for (final match in codeMatches) {
                final start = match.start;
                final end = match.end;

                if (start > lastEnd) {
                  final beforeText = text.substring(lastEnd, start);
                  if (beforeText.trim().isNotEmpty) {
                    children.add(
                      Text.rich(
                        _buildRichText(beforeText, colorScheme, textColor,
                            fontFamily, fontSizeMultiplier),
                        softWrap: true,
                      ),
                    );
                  }
                }

                final language = match.group(1) ?? 'plaintext';
                final code = match.group(2) ?? '';
                children.add(
                  CodeBlockWidget(
                    code: code.trim(),
                    language: language,
                  ),
                );

                lastEnd = end;
              }

              if (lastEnd < text.length) {
                final afterText = text.substring(lastEnd);
                if (afterText.trim().isNotEmpty) {
                  children.add(
                    Text.rich(
                      _buildRichText(afterText, colorScheme, textColor,
                          fontFamily, fontSizeMultiplier),
                      softWrap: true,
                    ),
                  );
                }
              }
            } else if (looksLikeCode) {
              children.add(
                CodeBlockWidget(
                  code: text.trim(),
                  language: _detectLanguage(text),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            );
          } else {
            return _buildMarkdownWidget(
                text, colorScheme, textColor, fontFamily, fontSizeMultiplier);
          }
        },
      );
    }

    final Color borderColorFinal =
        highlighted ? Theme.of(context).colorScheme.primary : borderColor;
    final double borderWidthFinal = highlighted ? 2.0 : 0.8;
    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final innerBubble = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColorFinal, width: borderWidthFinal),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      constraints:
          BoxConstraints(maxWidth: _getMaxWidth(text, fontSizeMultiplier)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyToContent != null && (replyToContent ?? '').isNotEmpty) ...[
            GestureDetector(
              onTap: onReplyTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: outgoing
                      ? replyBgOutgoing.withValues(alpha: 0.06)
                      : replyBgIncoming.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.08),
                      width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyToUsername != null)
                      Text(
                        replyToUsername!,
                        style: fontFamily.getBodyTextStyle(
                          fontSize: 12 * fontSizeMultiplier,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    if (replyToUsername != null) const SizedBox(height: 4),
                    Builder(builder: (_) {
                      final special = _parseReplySpecial(replyToContent ?? '');
                      final labelStyle = fontFamily
                          .getBodyTextStyle(
                            fontSize: 12 * fontSizeMultiplier,
                            color: textColorFinal.withValues(alpha: 0.85),
                          )
                          .copyWith(fontStyle: FontStyle.italic);
                      if (special != null) {
                        return Text(
                          special.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        );
                      }
                      return Text(
                        (replyToContent ?? '').trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          primaryContent,
          if (linkPreviewUrl != null) LinkPreviewCard(url: linkPreviewUrl!),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chatMessage?.pendingSend == true) ...[
                Icon(
                  Icons.schedule,
                  size: 10 * fontSizeMultiplier,
                  color: textColorFinal.withOpacity(0.55),
                ),
                const SizedBox(width: 3),
              ],
              if (chatMessage?.deliveryMode.isLAN == true) ...[
                Icon(
                  Icons.wifi,
                  size: 10 * fontSizeMultiplier,
                  color: Colors.green.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
              ],
              if (chatMessage?.deliveryMode.isMesh == true) ...[
                Icon(
                  chatMessage?.meshTransportUsed == 'wifi'
                      ? Icons.wifi
                      : Icons.bluetooth,
                  size: 10 * fontSizeMultiplier,
                  color: chatMessage?.meshTransportUsed == 'wifi'
                      ? Colors.green.withValues(alpha: 0.85)
                      : Colors.blueAccent.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
              ],
              if (hasReminder) ...[
                Icon(
                  Icons.alarm_rounded,
                  size: 11 * fontSizeMultiplier,
                  color: colorScheme.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
              ],
              SelectionContainer.disabled(
                child: Text(
                  _formatMessageTime(time),
                  style: fontFamily
                      .getBodyTextStyle(
                        fontSize: 8 * fontSizeMultiplier,
                        color: textColorFinal.withValues(alpha: 0.7),
                      )
                      .copyWith(height: 1.0),
                ),
              ),
            ],
          ),
          if (isDiagnostic)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text.contains('auth_fail')
                          ? (chatMessage?.encryptedForDevice != null
                              ? 'Encrypted for ${chatMessage!.encryptedForDevice}. Open it on that device.'
                              : 'This message was encrypted for another device. Open it on that device.')
                          : 'Message cannot be decrypted',
                      style: fontFamily.getBodyTextStyle(
                        fontSize: 12 * fontSizeMultiplier,
                        color: textColorFinal,
                      ),
                      softWrap: true,
                    ),
                  ),
                  if (!text.contains('auth_fail'))
                    TextButton(
                      onPressed: () {
                        if (onRequestResend != null)
                          onRequestResend!(serverMessageId);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      child: Text(
                        'Request resend',
                        style: fontFamily.getBodyTextStyle(
                            fontSize: 12 * fontSizeMultiplier),
                      ),
                    ),
                ],
              ),
            ),
          if (isDiagnostic && rawPreview != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'preview: ${rawPreview}',
                style: fontFamily.getBodyTextStyle(
                  fontSize: 10 * fontSizeMultiplier,
                  color: textColorFinal.withOpacity(0.7),
                ),
                softWrap: true,
              ),
            ),
        ],
      ),
    );
    // When onLongPress is provided the parent handles all gestures via its
    // own RawGestureDetector. Skip SelectionArea so it doesn't compete.
    if (onLongPress != null) {
      return innerBubble;
    }

    if (isDesktop) {
      // When onRightClick is supplied, the caller handles the context menu.
      // We suppress SelectionArea's own context menu (returning an invisible
      // SizedBox) so only the caller's showMenu popup appears.
      // A Listener (which bypasses the gesture arena) detects the secondary
      // button press and invokes the callback.
      if (onRightClick != null) {
        // SelectableRegion (inside SelectionArea below) also reacts to a
        // secondary click whenever there is selectable content under the
        // cursor (plain text, video captions, etc.): it calls its own
        // contextMenuBuilder and internally does
        // ContextMenuController.removeAny() + show(). If we raced it with
        // our own show() the two would stomp on each other (menu flashes
        // or never appears). Instead we piggyback on its contextMenuBuilder
        // hook directly -- it only fires when SelectableRegion has decided
        // to show a menu, so there is no race. We defer our actual
        // showMessageDesktopMenu call to the next frame (post-frame
        // callback) because contextMenuBuilder runs *during* that overlay
        // entry's build, and calling removeAny()/show() synchronously at
        // that point would trip "setState during build".
        //
        // When there is nothing selectable under the cursor (images,
        // albums), SelectableRegion never calls contextMenuBuilder at all,
        // so we fall back to showing the menu ourselves a couple of frames
        // after the right-click if that hook hasn't fired by then.
        Offset? lastSecondaryPos;
        bool handledBySelectableRegion = false;

        void showFallbackIfNotHandled() {
          if (!handledBySelectableRegion && lastSecondaryPos != null) {
            onRightClick!(lastSecondaryPos!);
          }
        }

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (PointerDownEvent event) {
            if (event.buttons == kSecondaryMouseButton) {
              lastSecondaryPos = event.position;
              handledBySelectableRegion = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showFallbackIfNotHandled();
                });
              });
            }
          },
          child: SelectionArea(
            contextMenuBuilder: (ctx, regionState) {
              handledBySelectableRegion = true;
              final position = lastSecondaryPos ??
                  regionState.contextMenuAnchors.primaryAnchor;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onRightClick!(position);
              });
              return const SizedBox.shrink();
            },
            child: innerBubble,
          ),
        );
      }
      return SelectionArea(
        contextMenuBuilder:
            (BuildContext menuCtx, SelectableRegionState regionState) {
          final anchors = regionState.contextMenuAnchors;
          final standard = regionState.contextMenuButtonItems;
          final cs = Theme.of(menuCtx).colorScheme;
          final hasCopy = (desktopMenuItems ?? [])
              .any((m) => m.type == ContextMenuButtonType.copy);

          return CustomSingleChildLayout(
            delegate: _ContextMenuLayoutDelegate(anchors.primaryAnchor),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: SettingsManager.glassSurfaceColor(cs.surfaceContainerHigh),
              child: IntrinsicWidth(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in standard)
                        if (item.type != ContextMenuButtonType.selectAll &&
                            !(hasCopy &&
                                item.type == ContextMenuButtonType.copy))
                          _menuRow(
                            icon: _standardIcon(item.type),
                            label: item.label ?? '',
                            onPressed: item.onPressed == null
                                ? null
                                : () {
                                    ContextMenuController.removeAny();
                                    item.onPressed!();
                                  },
                            cs: cs,
                          ),
                      for (final item in desktopMenuItems ?? [])
                        _menuRow(
                          icon: item.icon,
                          label: item.label,
                          onPressed: item.onPressed == null
                              ? null
                              : () {
                                  ContextMenuController.removeAny();
                                  item.onPressed!();
                                },
                          cs: cs,
                          color: item.color,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        child: innerBubble,
      );
    } else {
      return SelectionArea(
        child: innerBubble,
      );
    }
  }

  /// Returns (icon, label) for special message types shown in reply previews.
  ({IconData icon, String label})? _parseReplySpecial(String content) {
    final c = content.trim();
    for (final prefix in [
      'DATAv1:',
      'DOCUMENTv1:',
      'ARCHIVEv1:',
      'FILEv1:',
      'FILE:'
    ]) {
      if (c.startsWith(prefix)) {
        try {
          final meta =
              jsonDecode(c.substring(prefix.length)) as Map<String, dynamic>;
          final filename =
              meta['filename'] as String? ?? meta['orig'] as String? ?? 'File';
          final icon = prefix == 'ARCHIVEv1:'
              ? Icons.folder_zip_outlined
              : Icons.attach_file;
          return (icon: icon, label: filename);
        } catch (_) {
          return (icon: Icons.attach_file, label: 'File');
        }
      }
    }
    for (final prefix in ['IMAGEv1:', 'IMAGE:', 'ALBUM:', 'ALBUMv1:']) {
      if (c.startsWith(prefix))
        return (icon: Icons.image_outlined, label: 'Photo');
    }
    for (final prefix in ['VIDEOv1:', 'VIDEO:']) {
      if (c.startsWith(prefix))
        return (icon: Icons.videocam_outlined, label: 'Video');
    }
    for (final prefix in ['VOICE:', 'AUDIO:', 'VOICEv1:', 'AUDIOv1:']) {
      if (c.startsWith(prefix))
        return (icon: Icons.mic_outlined, label: 'Voice message');
    }
    if (c.startsWith('MESH_FILE:')) {
      final filename = c.substring('MESH_FILE:'.length).trim();
      final dot = filename.lastIndexOf('.');
      final ext = dot >= 0 ? filename.substring(dot).toLowerCase() : '';
      const audioExts = {
        '.mp3',
        '.wav',
        '.aac',
        '.m4a',
        '.flac',
        '.ogg',
        '.wma',
        '.opus',
        '.aiff',
        '.aif'
      };
      const imageExts = {
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.heic',
        '.heif',
        '.bmp'
      };
      const videoExts = {'.mp4', '.mov', '.mkv', '.avi', '.webm', '.3gp'};
      if (audioExts.contains(ext) || filename.startsWith('voice_')) {
        return (icon: Icons.mic_outlined, label: 'Voice message');
      } else if (imageExts.contains(ext)) {
        return (icon: Icons.image_outlined, label: 'Photo');
      } else if (videoExts.contains(ext)) {
        return (icon: Icons.videocam_outlined, label: 'Video');
      }
      return (
        icon: Icons.attach_file,
        label: filename.isNotEmpty ? filename : 'File'
      );
    }
    return null;
  }

  String _formatMessageTime(DateTime t) {
    return '${t.day}.${t.month}.${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  // Парсит inline-markdown + ссылки и возвращает список InlineSpan.
  // Поддерживает: **bold**, *italic*, __underline__, ~~strike~~, `code`, URLs.
  //
  // The regex tokenization itself is cached per raw message text (see
  // _tokenizeMarkdown below): message text never changes after a bubble is
  // created, but this widget rebuilds (theme/font/brightness changes, list
  // version bumps) far more often than that. Re-running multiple regexes
  // over every visible bubble's text on every such rebuild was a measurable
  // chunk of the per-frame cost on phones when a new message animates in.
  List<InlineSpan> _markdownSpans(
    String input,
    ColorScheme colorScheme,
    Color textColor,
    FontFamilyType fontFamily,
    double fontSizeMultiplier, {
    TextStyle? baseStyle,
  }) {
    final base = baseStyle ??
        fontFamily
            .getBodyTextStyle(fontSize: 14 * fontSizeMultiplier)
            .copyWith(color: textColor);
    final tokens = _tokenizeMarkdown(input);
    final parts = <InlineSpan>[];
    for (final t in tokens) {
      switch (t.type) {
        case _MdTokenType.plain:
          parts.add(TextSpan(text: t.text, style: base));
          break;
        case _MdTokenType.bold:
          parts.add(TextSpan(
              text: t.text, style: base.copyWith(fontWeight: FontWeight.bold)));
          break;
        case _MdTokenType.underline:
          parts.add(TextSpan(
              text: t.text,
              style: base.copyWith(decoration: TextDecoration.underline)));
          break;
        case _MdTokenType.strike:
          parts.add(TextSpan(
              text: t.text,
              style: base.copyWith(decoration: TextDecoration.lineThrough)));
          break;
        case _MdTokenType.italic:
          parts.add(TextSpan(
              text: t.text, style: base.copyWith(fontStyle: FontStyle.italic)));
          break;
        case _MdTokenType.code:
          parts.add(TextSpan(
            text: t.text,
            style: base.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
              fontSize: (base.fontSize ?? 14) * 0.92,
            ),
          ));
          break;
        case _MdTokenType.url:
          final raw = t.raw;
          final fullUrl = raw.startsWith('http') ? raw : 'https://$raw';
          parts.add(TextSpan(
            text: raw,
            style: base.copyWith(
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launchUrl(Uri.parse(fullUrl),
                        mode: LaunchMode.externalApplication)
                    .catchError((_) {
                  rootScreenKey.currentState?.showSnack('Cannot open link');
                  return false;
                });
              },
          ));
          break;
      }
    }
    return parts;
  }

  TextSpan _buildRichText(
    String input,
    ColorScheme colorScheme,
    Color textColor,
    FontFamilyType fontFamily,
    double fontSizeMultiplier,
  ) {
    return TextSpan(
      children: _markdownSpans(
          input, colorScheme, textColor, fontFamily, fontSizeMultiplier),
      style: fontFamily
          .getBodyTextStyle(fontSize: 14 * fontSizeMultiplier)
          .copyWith(color: textColor),
    );
  }

  // Строит виджет с поддержкой заголовков (## / ###) и inline-markdown.
  Widget _buildMarkdownWidget(
    String text,
    ColorScheme colorScheme,
    Color textColor,
    FontFamilyType fontFamily,
    double fontSizeMultiplier,
  ) {
    final baseTextStyle = fontFamily
        .getBodyTextStyle(fontSize: 14 * fontSizeMultiplier)
        .copyWith(color: textColor);
    final lines = text.split('\n');
    final bool hasHeadings =
        lines.any((l) => l.startsWith('## ') || l.startsWith('### '));
    if (!hasHeadings) {
      return Text.rich(
        TextSpan(
          children: _markdownSpans(
              text, colorScheme, textColor, fontFamily, fontSizeMultiplier),
          style: baseTextStyle,
        ),
        softWrap: true,
      );
    }
    // Есть заголовки — собираем построчно, группируя обычные строки.
    final widgets = <Widget>[];
    final buffer = StringBuffer();
    void flushBuffer() {
      final s = buffer.toString();
      if (s.isNotEmpty) {
        widgets.add(Text.rich(
          TextSpan(
            children: _markdownSpans(
                s, colorScheme, textColor, fontFamily, fontSizeMultiplier),
            style: baseTextStyle,
          ),
          softWrap: true,
        ));
        buffer.clear();
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('### ')) {
        flushBuffer();
        final content = line.substring(4);
        widgets.add(Text.rich(
          TextSpan(
            children: _markdownSpans(
                content, colorScheme, textColor, fontFamily, fontSizeMultiplier,
                baseStyle: fontFamily
                    .getBodyTextStyle(fontSize: 15 * fontSizeMultiplier)
                    .copyWith(color: textColor, fontWeight: FontWeight.w600)),
          ),
          softWrap: true,
        ));
      } else if (line.startsWith('## ')) {
        flushBuffer();
        final content = line.substring(3);
        widgets.add(Text.rich(
          TextSpan(
            children: _markdownSpans(
                content, colorScheme, textColor, fontFamily, fontSizeMultiplier,
                baseStyle: fontFamily
                    .getBodyTextStyle(fontSize: 17 * fontSizeMultiplier)
                    .copyWith(color: textColor, fontWeight: FontWeight.bold)),
          ),
          softWrap: true,
        ));
      } else {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }
    }
    flushBuffer();
    if (widgets.length == 1) return widgets.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  bool _isLikelyCode(String text) {
    if (text.isEmpty) return false;
    if (text.length < 10) return false;

    int codeIndicators = 0;

    if (text.contains('{') ||
        text.contains('}') ||
        text.contains('[') ||
        text.contains(']') ||
        text.contains('(') && text.contains(')')) {
      codeIndicators++;
    }

    if (text.contains(';')) {
      codeIndicators++;
    }

    if (text.contains('=>') ||
        text.contains('==') ||
        text.contains('!=') ||
        text.contains('===') ||
        text.contains('const ') ||
        text.contains('final ') ||
        text.contains('let ') ||
        text.contains('var ') ||
        text.contains('function') ||
        text.contains('class ') ||
        text.contains('def ') ||
        text.contains('void ')) {
      codeIndicators += 2;
    }

    final lines = text.split('\n');
    if (lines.length > 2) {
      int linesWithIndent = 0;
      for (final line in lines) {
        if (line.startsWith('  ') || line.startsWith('\t')) {
          linesWithIndent++;
        }
      }
      if (linesWithIndent > lines.length * 0.3) {
        codeIndicators++;
      }
    }

    return codeIndicators >= 2;
  }

  String _detectLanguage(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('void main') ||
        lower.contains('import') && lower.contains('dart')) {
      return 'dart';
    }
    if (lower.contains('def ') ||
        lower.contains('import ') &&
            (lower.contains('sys') || lower.contains('os'))) {
      return 'python';
    }
    if (lower.contains('function ') ||
        lower.contains('const ') && lower.contains('=>')) {
      return 'javascript';
    }
    if (lower.contains('public class') || lower.contains('public static')) {
      return 'java';
    }
    if (lower.contains('class ') && lower.contains('{')) {
      if (lower.contains('async') || lower.contains('await')) {
        return 'dart';
      }
      return 'java';
    }
    if (lower.contains('#include')) {
      return 'cpp';
    }

    return 'plaintext';
  }

  double _getMaxWidth(String text, double fontSizeMultiplier) {
    final lines = text.split('\n');

    int maxLineLength = 0;
    for (final line in lines) {
      if (line.length > maxLineLength) {
        maxLineLength = line.length;
      }
    }

    final hasCodeBlock = _codeBlockRegex.hasMatch(text);

    if (hasCodeBlock) {
      final estimatedWidth = (maxLineLength * 7.5 * fontSizeMultiplier)
          .clamp(200.0 * fontSizeMultiplier, 900.0 * fontSizeMultiplier);
      return estimatedWidth + 40 * fontSizeMultiplier;
    } else {
      // 350 comfortably fits the media widgets' own scaled max widths
      // (image/video 280–300 * multiplier) plus their rounded-card padding.
      return 350 * fontSizeMultiplier;
    }
  }
}

Widget _meshFilePlaceholder(
    String filename, int fileSize, IconData icon, ColorScheme colorScheme,
    {double progress = 0.0}) {
  final sizeStr = fileSize > 0
      ? fileSize < 1024 * 1024
          ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
          : '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
      : '';
  final isTransferring = progress > 0.0 && progress < 1.0;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(filename,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (sizeStr.isNotEmpty)
                  Text(sizeStr,
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        if (isTransferring) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 3,
            ),
          ),
        ],
      ],
    ),
  );
}
