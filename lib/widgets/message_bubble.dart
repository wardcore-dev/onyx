// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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

  final List<ContextMenuButtonItem>? desktopMenuItems;
  /// Called with the global tap position when the user right-clicks on desktop.
  /// When provided, the built-in SelectionArea context menu is suppressed and
  /// this callback is responsible for showing its own menu.
  final void Function(Offset)? onRightClick;

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
    this.desktopMenuItems,
    this.onRightClick,
  }) : super(key: key);

  bool get isDiagnostic => text.startsWith('[cannot-decrypt');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SettingsManager.fontFamily,
        SettingsManager.fontSizeMultiplier,
        SettingsManager.elementBrightness,
        SettingsManager.elementOpacity,
      ]),
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
    const double incomingBaseAlpha = 0.5;
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
          debugPrint('[MessageBubble] Has reply - replyToId=$replyToId, replyToUsername=$replyToUsername, replyToContent=$replyToContent');
        }
        final Color baseColor = outgoing
            ? baseRawOutgoing.withOpacity(msgOpacity)
            : baseRawIncoming.withOpacity(msgOpacity * incomingBaseAlpha);
        final Color borderColor = outgoing
            ? colorScheme.primary.withOpacity(msgOpacity * outgoingBorderAlpha)
            : colorScheme.outline.withOpacity(msgOpacity * incomingBorderAlpha);
        final Color textColorFinal = textRaw.withOpacity(msgOpacity);

        if (text.startsWith('VOICEv1:')) {
          final meta =
              jsonDecode(text.substring('VOICEv1:'.length)) as Map<String, dynamic>;
          
          final filename = meta['url'] as String? ?? meta['filename'] as String? ?? '';
          final owner = meta['owner'] as String?;
          final voiceMediaKeyB64 = meta['key'] as String?;
          debugPrint('[MessageBubble] VOICE - url: ${meta['url']}, filename: ${meta['filename']}, owner: $owner, result: "$filename"');
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
            final meta = jsonDecode(text.substring('AUDIOv1:'.length)) as Map<String, dynamic>;
            final filename = (meta['filename'] ?? meta['orig'] ?? 'audio') as String;
            primaryContent = FileMessageWidget(
              filename: filename,
              peerUsername: peerUsername,
              isOutgoing: outgoing,
              senderUsername: chatMessage?.from,
            );
          } catch (e) {
            
            primaryContent = FileMessageWidget(
              filename: text,
              peerUsername: peerUsername,
              isOutgoing: outgoing,
              senderUsername: chatMessage?.from,
            );
          }
        } else if (text.startsWith('IMAGEv1:')) {
      final jsonPart = text.substring('IMAGEv1:'.length);
      final data = jsonDecode(jsonPart) as Map<String, dynamic>;
      
      final filename = data['url'] as String? ?? data['filename'] as String? ?? '';
      final owner = data['owner'] as String?;
      final imageMediaKeyB64 = data['key'] as String?;
      debugPrint('[MessageBubble] IMAGE - url: ${data['url']}, filename: ${data['filename']}, owner: $owner, result: "$filename"');
      primaryContent = ImageMessageWidget(
        filename: filename,
        owner: owner,
        peerUsername: peerUsername,
        isOutgoing: outgoing,
        mediaKeyB64: imageMediaKeyB64,
      );
    } else if (text.toUpperCase().startsWith('VIDEOV1:')) {
      final prefixLen = 'VIDEOv1:'.length; 
      final meta = jsonDecode(text.substring(prefixLen)) as Map<String, dynamic>;
      
      final filename = meta['url'] as String? ?? meta['filename'] as String?;
      final owner = meta['owner'] as String?;
      final origName = meta['orig'] as String? ?? 'video';
      final pending = meta['pending_upload'] == true;
      final videoMediaKeyB64 = meta['key'] as String?;
      debugPrint('[MessageBubble] VIDEO - url: ${meta['url']}, filename: ${meta['filename']}, owner: $owner, result: "$filename", pending: $pending');
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
        } else if (text.startsWith('DOCUMENTv1:') || text.startsWith('ARCHIVEv1:') || text.startsWith('DATAv1:')) {
      
      try {
        final meta = jsonDecode(text.substring(text.indexOf(':') + 1)) as Map<String, dynamic>;
        final filename = meta['filename'] as String? ?? '';
        primaryContent = FileMessageWidget(
          filename: filename,
          peerUsername: peerUsername,
          isOutgoing: outgoing,
          senderUsername: chatMessage?.from,
        );
      } catch (e) {
        primaryContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('File not available', style: TextStyle(color: colorScheme.onError)),
        );
      }
    } else if (text.startsWith('FILEv1:') || text.startsWith('FILE:')) {
      
      String filename = '';
      String? owner;
      String? fileMediaKeyB64;
      try {
        if (text.startsWith('FILEv1:')) {
          final meta = jsonDecode(text.substring('FILEv1:'.length)) as Map<String, dynamic>;
          filename = meta['filename'] as String? ?? '';
          owner = meta['owner'] as String?;
          fileMediaKeyB64 = meta['key'] as String?;
        } else {
          filename = text.substring('FILE:'.length).trim();
        }
        if (filename.isNotEmpty) {
          primaryContent = FileMessageWidget(
            filename: filename,
            owner: owner,
            peerUsername: peerUsername,
            isOutgoing: outgoing,
            senderUsername: chatMessage?.from,
            mediaKeyB64: fileMediaKeyB64,
          );
        } else {
          primaryContent = Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('File not available', style: TextStyle(color: colorScheme.onError)),
          );
        }
      } catch (e) {
        primaryContent = Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('File not available', style: TextStyle(color: colorScheme.onError)),
        );
      }
        } else if (text.startsWith('ALBUMv1:')) {
          try {
            final list = jsonDecode(text.substring('ALBUMv1:'.length)) as List<dynamic>;
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
            );
          } catch (e) {
            primaryContent = Text(' Invalid ALBUM: $e');
          }
        } else if (text.startsWith('MEDIA_PROXYv1:')) {        try {
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
          } else if (type == 'audio' || type == 'document' || type == 'archive' || type == 'data' || type == 'file') {
            
            primaryContent = FileMessageWidget(
              filename: orig,
              peerUsername: '<external>',
              isOutgoing: outgoing,
              senderUsername: chatMessage?.from,
              directUrl: authUrl,
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
              );
            } else if (isVideo) {
              primaryContent = VideoMessageWidget(
                filename: authUrl,
                peerUsername: '<external>',
              );
            } else {
              
              primaryContent = FileMessageWidget(
                filename: orig,
                peerUsername: '<external>',
                isOutgoing: outgoing,
                senderUsername: chatMessage?.from,
                directUrl: authUrl,
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
          
          final codeBlockRegex = RegExp(r'```([\w+-]*)\s*([\s\S]*?)```', multiLine: true);
          final codeMatches = codeBlockRegex.allMatches(text).toList();
          
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
                        _buildRichText(beforeText, colorScheme, textColor),
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
                      _buildRichText(afterText, colorScheme, textColor),
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
            return _buildMarkdownWidget(text, colorScheme, textColor);
          }
        },
      );
    }

        final Color borderColorFinal = highlighted ? Theme.of(context).colorScheme.primary : borderColor;
        final double borderWidthFinal = highlighted ? 2.0 : 0.8;
        final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);
        final innerBubble = Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColorFinal, width: borderWidthFinal),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          constraints: BoxConstraints(maxWidth: _getMaxWidth(text)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyToContent != null && (replyToContent ?? '').isNotEmpty) ...[
                GestureDetector(
                  onTap: onReplyTap,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: outgoing
                          ? replyBgOutgoing.withValues(alpha: 0.06)
                          : replyBgIncoming.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08), width: 0.6),
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
                        Text(
                          (replyToContent ?? '').trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: fontFamily.getBodyTextStyle(
                            fontSize: 12 * fontSizeMultiplier,
                            color: textColorFinal.withOpacity(0.85),
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              primaryContent,
              if (linkPreviewUrl != null)
                LinkPreviewCard(url: linkPreviewUrl!),
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
                  Text(
                    _formatMessageTime(time),
                    style: fontFamily.getBodyTextStyle(
                      fontSize: 8 * fontSizeMultiplier,
                      color: textColorFinal.withOpacity(0.7),
                    ).copyWith(height: 1.0),
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
                            if (onRequestResend != null) onRequestResend!(serverMessageId);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          child: Text(
                            'Request resend',
                            style: fontFamily.getBodyTextStyle(fontSize: 12 * fontSizeMultiplier),
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
        if (isDesktop) {
          // When onRightClick is supplied, the caller handles the context menu.
          // We suppress SelectionArea's own context menu (returning an invisible
          // SizedBox) so only the caller's showMenu popup appears.
          // A Listener (which bypasses the gesture arena) detects the secondary
          // button press and invokes the callback.
          if (onRightClick != null) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (PointerDownEvent event) {
                if (event.buttons == kSecondaryMouseButton) {
                  ContextMenuController.removeAny();
                  onRightClick!(event.position);
                }
              },
              child: SelectionArea(
                contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                child: innerBubble,
              ),
            );
          }
          return SelectionArea(
            contextMenuBuilder: (BuildContext menuCtx, SelectableRegionState regionState) {
              final standard = regionState.contextMenuButtonItems;
              final hasCopy = standard.any(
                  (item) => item.type == ContextMenuButtonType.copy);
              final extra = (desktopMenuItems ?? [])
                  .where((item) => !(hasCopy && item.type == ContextMenuButtonType.copy))
                  .map((item) => ContextMenuButtonItem(
                        label: item.label,
                        type: item.type,
                        onPressed: item.onPressed == null
                            ? null
                            : () {
                                ContextMenuController.removeAny();
                                item.onPressed!();
                              },
                      ))
                  .toList();
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: regionState.contextMenuAnchors,
                buttonItems: [...standard, ...extra],
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

  String _formatMessageTime(DateTime t) {
    return '${t.day}.${t.month}.${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  // Парсит inline-markdown + ссылки и возвращает список InlineSpan.
  // Поддерживает: **bold**, *italic*, __underline__, ~~strike~~, `code`, URLs.
  List<InlineSpan> _markdownSpans(String input, ColorScheme colorScheme, Color textColor, {TextStyle? baseStyle}) {
    final parts = <InlineSpan>[];
    // Порядок важен: более длинные токены идут раньше.
    final tokenRx = RegExp(
      r'\*\*(.+?)\*\*'           // **bold**
      r'|__(.+?)__'              // __underline__
      r'|~~(.+?)~~'              // ~~strikethrough~~
      r'|\*(.+?)\*'              // *italic*
      r'|`([^`]+)`'              // `inline code`
      r'|\bhttps?://[^\s<>"{}|\\^`\[\]]+'  // URL
      r'|\bwww\.[^\s<>"{}|\\^`\[\]]+',     // www URL
      caseSensitive: false,
      dotAll: false,
    );
    int lastEnd = 0;
    final base = baseStyle ?? TextStyle(color: textColor);
    for (final m in tokenRx.allMatches(input)) {
      if (m.start > lastEnd) {
        parts.add(TextSpan(text: input.substring(lastEnd, m.start), style: base));
      }
      final raw = m.group(0)!;
      if (m.group(1) != null) {
        // **bold**
        parts.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(2) != null) {
        // __underline__
        parts.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(decoration: TextDecoration.underline),
        ));
      } else if (m.group(3) != null) {
        // ~~strikethrough~~
        parts.add(TextSpan(
          text: m.group(3),
          style: base.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else if (m.group(4) != null) {
        // *italic*
        parts.add(TextSpan(
          text: m.group(4),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(5) != null) {
        // `inline code`
        parts.add(TextSpan(
          text: m.group(5),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
            fontSize: (base.fontSize ?? 14) * 0.92,
          ),
        ));
      } else {
        // URL
        final fullUrl = raw.startsWith('http') ? raw : 'https://$raw';
        parts.add(TextSpan(
          text: raw,
          style: base.copyWith(
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication)
                  .catchError((_) {
                rootScreenKey.currentState?.showSnack('Cannot open link');
                return false;
              });
            },
        ));
      }
      lastEnd = m.end;
    }
    if (lastEnd < input.length) {
      parts.add(TextSpan(text: input.substring(lastEnd), style: base));
    }
    return parts;
  }

  TextSpan _buildRichText(String input, ColorScheme colorScheme, Color textColor) {
    return TextSpan(
      children: _markdownSpans(input, colorScheme, textColor),
      style: TextStyle(color: textColor),
    );
  }

  // Строит виджет с поддержкой заголовков (## / ###) и inline-markdown.
  Widget _buildMarkdownWidget(String text, ColorScheme colorScheme, Color textColor) {
    final lines = text.split('\n');
    final bool hasHeadings = lines.any((l) => l.startsWith('## ') || l.startsWith('### '));
    if (!hasHeadings) {
      return Text.rich(
        TextSpan(
          children: _markdownSpans(text, colorScheme, textColor),
          style: TextStyle(color: textColor),
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
            children: _markdownSpans(s, colorScheme, textColor),
            style: TextStyle(color: textColor),
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
            children: _markdownSpans(content, colorScheme, textColor,
                baseStyle: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          softWrap: true,
        ));
      } else if (line.startsWith('## ')) {
        flushBuffer();
        final content = line.substring(3);
        widgets.add(Text.rich(
          TextSpan(
            children: _markdownSpans(content, colorScheme, textColor,
                baseStyle: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold)),
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
    
    if (text.contains('{') || text.contains('}') || 
        text.contains('[') || text.contains(']') ||
        text.contains('(') && text.contains(')')) {
      codeIndicators++;
    }
    
    if (text.contains(';')) {
      codeIndicators++;
    }
    
    if (text.contains('=>') || text.contains('==') || 
        text.contains('!=') || text.contains('===') ||
        text.contains('const ') || text.contains('final ') ||
        text.contains('let ') || text.contains('var ') ||
        text.contains('function') || text.contains('class ') ||
        text.contains('def ') || text.contains('void ')) {
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
    
    if (lower.contains('void main') || lower.contains('import') && lower.contains('dart')) {
      return 'dart';
    }
    if (lower.contains('def ') || lower.contains('import ') && (lower.contains('sys') || lower.contains('os'))) {
      return 'python';
    }
    if (lower.contains('function ') || lower.contains('const ') && lower.contains('=>')) {
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

  double _getMaxWidth(String text) {
    final lines = text.split('\n');
    
    int maxLineLength = 0;
    for (final line in lines) {
      if (line.length > maxLineLength) {
        maxLineLength = line.length;
      }
    }
    
    final codeBlockRegex = RegExp(r'```([\w+-]*)\s*([\s\S]*?)```', multiLine: true);
    final hasCodeBlock = codeBlockRegex.hasMatch(text);
    
    if (hasCodeBlock) {
      
      final estimatedWidth = (maxLineLength * 7.5).clamp(200.0, 900.0);
      return estimatedWidth + 40; 
    } else {
      
      return 350;
    }
  }
}