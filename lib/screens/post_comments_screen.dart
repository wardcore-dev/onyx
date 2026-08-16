// lib/screens/post_comments_screen.dart
//
// Internal-group counterpart to external_post_comments_screen.dart: the
// Telegram-style discussion thread under a channel post, but talking to our
// own Node.js server (serverBase + AccountManager token) instead of an
// ExternalServer (self-hosted Rust instance). Kept as its own file (rather
// than parameterizing the external screen) because the two backends expose
// different URL shapes: /group/:groupId/... here vs. the external server's
// flat /messages/:id/comments (it only ever hosts one group).
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'dart:io';
import '../enums/liquid_glass_quality.dart';
import '../globals.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../widgets/onyx_dialog.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_reaction_bar.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/swipeable_message_wrapper.dart';
import '../widgets/voice_confirm_dialog.dart';
import '../l10n/app_localizations.dart';
import 'chats_tab.dart' show getPreviewText;

/// Shows the comment thread for a single internal-group channel post as a
/// centered modal, matching showExternalPostCommentsDialog's chrome.
///
/// [onPickAttachment]/[onUploadVoice] are provided by GroupChatScreen (which
/// already owns the upload plumbing for the main chat) and return the
/// encoded MEDIA_PROXYv1 content string ready to post as a comment, or null
/// on cancel/failure — same contract as the external comments dialog.
Future<void> showPostCommentsDialog({
  required BuildContext context,
  required int groupId,
  required int postId,
  required String postSender,
  required String postContent,
  required bool canDeleteAny,
  Future<String?> Function()? onPickAttachment,
  Future<String?> Function(Uint8List bytes)? onUploadVoice,
  GlobalKey<PostCommentsScreenState>? key,
}) {
  return showOnyxDialog<void>(
    context: context,
    builder: (context) => PostCommentsScreen(
      key: key,
      groupId: groupId,
      postId: postId,
      postSender: postSender,
      postContent: postContent,
      canDeleteAny: canDeleteAny,
      onPickAttachment: onPickAttachment,
      onUploadVoice: onUploadVoice,
    ),
  );
}

class PostCommentsScreen extends StatefulWidget {
  final int groupId;
  final int postId;
  final String postSender;
  final String postContent;
  final bool canDeleteAny;
  final Future<String?> Function()? onPickAttachment;
  final Future<String?> Function(Uint8List bytes)? onUploadVoice;

  const PostCommentsScreen({
    super.key,
    required this.groupId,
    required this.postId,
    required this.postSender,
    required this.postContent,
    required this.canDeleteAny,
    this.onPickAttachment,
    this.onUploadVoice,
  });

  @override
  State<PostCommentsScreen> createState() => PostCommentsScreenState();
}

class PostCommentsScreenState extends State<PostCommentsScreen>
    with ReactionStateMixin<PostCommentsScreen> {
  final List<Map<String, dynamic>> _comments = [];
  final Set<String> _alreadyAnimated = {};
  // Origin for the outgoing-comment fly-in animation — same mechanic as the
  // main chat's _inputAreaKey: the bubble flies from the composer's on-screen
  // position to its slot in the list instead of springing up from below.
  final GlobalKey _inputAreaKey = GlobalKey();
  bool _loading = true;
  bool _uploadingAttachment = false;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _textFocusNode = FocusNode();
  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingComment;
  final ValueNotifier<bool> _showScrollToBottom = ValueNotifier(false);

  String get _myUsername => rootScreenKey.currentState?.currentUsername ?? '';

  String _reactionKey(dynamic commentId) => 'comment_$commentId';

  @override
  void initState() {
    super.initState();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // Reverse list: pixels == 0 is the bottom (newest comment).
    _showScrollToBottom.value = _scrollController.position.pixels > 200;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textFocusNode.dispose();
    _showScrollToBottom.dispose();
    super.dispose();
  }

  /// Called by GroupChatScreen when a comment_added/comment_deleted/
  /// comment_reaction_update WS event arrives for this post while the
  /// thread is open.
  void handleWsEvent(Map<String, dynamic> obj) {
    if (!mounted) return;
    final type = obj['type']?.toString();
    if (type == 'comment_added') {
      final comment = obj['comment'] as Map<String, dynamic>?;
      if (comment != null && !_comments.any((c) => c['id'] == comment['id'])) {
        setState(() {
          // This WS echo can beat the HTTP response to our own optimistic
          // send (see _postCommentContent). If a temp_ placeholder for it
          // is still sitting in the list, splice the real comment into
          // that same slot and carry over its animationId instead of
          // appending a second copy — appending would give the real
          // comment a fresh key, so it plays its own entrance animation
          // and the optimistic bubble's fly-in looks like it snaps back
          // and replays.
          final tempIdx = _comments.indexWhere((c) =>
              c['id'].toString().startsWith('temp_') &&
              c['sender'] == comment['sender'] &&
              c['content'] == comment['content']);
          final merged = Map<String, dynamic>.from(comment);
          if (tempIdx >= 0) {
            merged['animationId'] = _comments[tempIdx]['animationId'];
            _comments[tempIdx] = merged;
          } else {
            _comments.add(merged);
          }
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottomIfNeeded());
      }
    } else if (type == 'comment_deleted') {
      final commentId = obj['comment_id'];
      setState(() => _comments.removeWhere((c) => c['id'] == commentId));
    } else if (type == 'comment_edited') {
      final commentId = obj['comment_id'];
      final newContent = obj['new_content']?.toString();
      if (newContent != null) {
        setState(() {
          final idx = _comments.indexWhere((c) => c['id'] == commentId);
          if (idx >= 0) _comments[idx]['content'] = newContent;
        });
      }
    } else if (type == 'comment_reaction_update') {
      final commentId = obj['comment_id'];
      final reactions = obj['reactions'];
      if (reactions is Map) {
        applyReactionCounts(
            _reactionKey(commentId), Map<String, dynamic>.from(reactions));
      }
    }
  }

  // Unconditional: always scrolls all the way to the bottom (newest
  // comment). Used for the initial load and the floating "scroll to
  // bottom" button — both places where the user (or the screen opening)
  // explicitly wants to land at the very end regardless of where the list
  // currently sits.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // Only nudges the scroll position when already at/near the bottom —
  // mirrors GroupChatScreen._scrollToBottomIfNeeded. Using jumpTo(0) (a
  // no-op when already at 0) rather than an animated scroll is what keeps
  // this from racing the outgoing bubble's own fly-in animation: a
  // concurrent scroll animation moving the list while
  // AnimatedMessageBubble.flightOriginKey is mid-flight makes the bubble
  // land in the wrong spot and look like it snaps into place.
  void _scrollToBottomIfNeeded() {
    if (!_scrollController.hasClients) return;
    final current = _scrollController.position.pixels;
    if (current <= 1.5) {
      _scrollController.jumpTo(0.0);
    } else if (current <= 120) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadComments() async {
    try {
      final token = await AccountManager.getToken(_myUsername);
      if (token == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final response = await http.get(
        Uri.parse(
            '$serverBase/group/${widget.groupId}/messages/${widget.postId}/comments'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (mounted) {
          setState(() {
            _comments
              ..clear()
              ..addAll(data.map((e) => Map<String, dynamic>.from(e as Map)));
            for (final c in _comments) {
              _alreadyAnimated.add('c_${c['id']}');
              final reactions = c['reactions'];
              if (reactions is Map) {
                seedReactions(_reactionKey(c['id']),
                    Map<String, dynamic>.from(reactions));
              }
            }
            _loading = false;
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_editingComment != null) {
      final editId = _editingComment!['id'];
      _cancelEditingComment();
      await _submitCommentEdit(editId, text);
      return;
    }
    // Clear the field immediately — the optimistic bubble below is what the
    // user sees as "sent", not the network response.
    _controller.clear();
    await _postCommentContent(text);
  }

  void _startEditingComment(Map<String, dynamic> c) {
    final content = c['content']?.toString() ?? '';
    setState(() {
      _editingComment = c;
      _replyingTo = null;
    });
    _controller.text = content;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: content.length));
    _textFocusNode.requestFocus();
  }

  void _cancelEditingComment() {
    setState(() => _editingComment = null);
    _controller.clear();
    _textFocusNode.requestFocus();
  }

  Future<void> _submitCommentEdit(dynamic commentId, String newContent) async {
    final l = AppLocalizations.of(context);
    try {
      final token = await AccountManager.getToken(_myUsername);
      if (token == null) return;
      final response = await http
          .patch(
            Uri.parse(
                '$serverBase/group/${widget.groupId}/comments/$commentId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'content': newContent}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          final idx = _comments.indexWhere((c) => c['id'] == commentId);
          if (idx >= 0) _comments[idx]['content'] = newContent;
        });
      } else if (mounted) {
        _showSnack(l.failedEditComment);
      }
    } catch (e) {
      if (mounted) _showSnack(l.failedEditComment);
    }
  }

  /// Posts [content] as a comment. Renders it locally the instant it's
  /// called (before the network round-trip), then reconciles with the
  /// server's response — matching how the main chat sends messages, so
  /// comments don't feel laggier than a real message just because they go
  /// through a second endpoint.
  Future<bool> _postCommentContent(String content) async {
    final l = AppLocalizations.of(context);
    final replySnapshot = _replyingTo;
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    // Stable identity that survives the temp-id -> real-id swap below, so
    // the entrance animation plays exactly once on first appearance instead
    // of replaying when the server's real id comes back (see
    // animated_message_bubble.dart's note on keeping the same ValueKey
    // across rebuilds).
    final animationId = 'c_$tempId';
    final optimistic = {
      'id': tempId,
      'animationId': animationId,
      'post_id': widget.postId,
      'sender': _myUsername,
      'content': content,
      'reply_to_id': replySnapshot?['id'],
      'reply_to_sender': replySnapshot?['sender'],
      'reply_to_content': replySnapshot?['content'],
      'created_at': DateTime.now().toIso8601String(),
    };
    if (mounted) {
      setState(() {
        _comments.add(optimistic);
        _replyingTo = null;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottomIfNeeded());
    }

    void discardOptimistic() {
      if (!mounted) return;
      setState(() => _comments.removeWhere((c) => c['id'] == tempId));
    }

    try {
      final token = await AccountManager.getToken(_myUsername);
      if (token == null) {
        discardOptimistic();
        return false;
      }
      final response = await http
          .post(
            Uri.parse(
                '$serverBase/group/${widget.groupId}/messages/${widget.postId}/comments'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'content': content,
              if (replySnapshot != null) 'reply_to_id': replySnapshot['id'],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final comment = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            final idx = _comments.indexWhere((c) => c['id'] == tempId);
            // The WS comment_added event can beat the HTTP response here
            // (same comment, delivered twice) — de-dupe by real id rather
            // than assuming the optimistic slot is still the only copy.
            final alreadyFromWs =
                _comments.any((c) => c['id'] == comment['id']);
            if (idx >= 0) {
              if (alreadyFromWs) {
                _comments.removeAt(idx);
              } else {
                // Keep the same animationId so the ValueKey below doesn't
                // change and Flutter treats this as an update to the
                // existing bubble rather than a fresh one — no re-trigger.
                comment['animationId'] = animationId;
                _comments[idx] = comment;
              }
            } else if (!alreadyFromWs) {
              _comments.add(comment);
            }
          });
        }
        return true;
      }
      discardOptimistic();
      if (mounted) {
        try {
          final error =
              jsonDecode(response.body)['error'] ?? l.failedPostComment;
          _showSnack(l.errorMsg(error.toString()));
        } catch (_) {
          _showSnack(l.failedPostComment);
        }
      }
      return false;
    } catch (e) {
      discardOptimistic();
      if (mounted) _showSnack(l.failedPostComment);
      return false;
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (widget.onPickAttachment == null || _uploadingAttachment) return;
    setState(() => _uploadingAttachment = true);
    try {
      final content = await widget.onPickAttachment!();
      if (content != null) await _postCommentContent(content);
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _startRecording() async {
    rootScreenKey.currentState?.startRecording();
  }

  Future<void> _stopRecordingAndUpload() async {
    await rootScreenKey.currentState?.stopRecordingOnly();
    final path = rootScreenKey.currentState?.lastRecordedPathForUpload;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();

    Future<void> upload() async {
      if (widget.onUploadVoice == null) return;
      setState(() => _uploadingAttachment = true);
      try {
        final content = await widget.onUploadVoice!(bytes);
        if (content != null) await _postCommentContent(content);
      } finally {
        if (mounted) setState(() => _uploadingAttachment = false);
      }
    }

    if (SettingsManager.confirmVoiceUpload.value) {
      final durationSeconds = (bytes.length / 16000).ceil();
      final duration = Duration(seconds: durationSeconds);
      if (mounted) {
        await showDialog<bool>(
          context: context,
          builder: (_) => VoiceConfirmDialog(
            duration: duration,
            onSend: upload,
            onCancel: () {},
          ),
        );
      }
    } else {
      await upload();
    }
  }

  // Mirrors _buildCommentInputBar in external_post_comments_screen.dart so
  // the composer looks and behaves identically between internal and
  // external groups.
  Widget _buildCommentInputBar(ColorScheme colorScheme, AppLocalizations l) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SettingsManager.elementOpacity,
        SettingsManager.elementBrightness,
        SettingsManager.liquidGlassOnInput,
        SettingsManager.liquidGlassInputQuality,
        SettingsManager.liquidGlassInputBlur,
        SettingsManager.liquidGlassInputTint,
        SettingsManager.liquidGlassInputSaturation,
        SettingsManager.liquidGlassInputChromatic,
        SettingsManager.liquidGlassInputRefractive,
        SettingsManager.liquidGlassInputLightIntensity,
        SettingsManager.liquidGlassInputThickness,
      ]),
      builder: (_, __) {
        final opacity = SettingsManager.elementOpacity.value;
        final brightness = SettingsManager.elementBrightness.value;
        final baseColor = SettingsManager.getElementColor(
          colorScheme.surfaceContainerHighest,
          brightness,
        );
        final isMobile = !Platform.isWindows && !Platform.isLinux;
        final useGlass = isMobile && SettingsManager.liquidGlassOnInput.value;
        final bar = ChatInputBar(
          inputAreaKey: _inputAreaKey,
          controller: _controller,
          textFocusNode: _textFocusNode,
          recordingListenable: recordingNotifier,
          recordingLevelListenable: recordingLevelNotifier,
          onCancelRecording: () {
            rootScreenKey.currentState?.cancelRecording();
          },
          onMicPressed: (isRecording) {
            if (isRecording) {
              _stopRecordingAndUpload();
            } else {
              _startRecording();
            }
          },
          onAttachPressed:
              widget.onPickAttachment == null || _uploadingAttachment
                  ? () {}
                  : _pickAndSendAttachment,
          onSendPressed: _sendComment,
          onPaste: () async {},
          hintText: l.writeCommentHint,
          backgroundColor: useGlass ? Colors.white : baseColor,
          opacity: useGlass ? 0.0 : opacity,
          borderColor: useGlass
              ? Colors.transparent
              : colorScheme.outlineVariant.withValues(alpha: 0.15),
          glassMode: useGlass,
        );
        if (!useGlass) return bar;

        final quality = SettingsManager.liquidGlassInputQuality.value;
        final blur = SettingsManager.liquidGlassInputBlur.value;
        final tint = SettingsManager.liquidGlassInputTint.value;
        final saturation = SettingsManager.liquidGlassInputSaturation.value;
        final chromatic = SettingsManager.liquidGlassInputChromatic.value;
        final refractive = SettingsManager.liquidGlassInputRefractive.value;
        final lightIntensity =
            SettingsManager.liquidGlassInputLightIntensity.value;
        final thickness = SettingsManager.liquidGlassInputThickness.value;
        final glassQuality = switch (quality) {
          LiquidGlassQuality.fast => GlassQuality.standard,
          LiquidGlassQuality.medium => GlassQuality.minimal,
          LiquidGlassQuality.quality => GlassQuality.premium,
        };
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final tintColor = isDark
            ? Colors.white.withValues(alpha: tint)
            : Colors.black.withValues(alpha: tint);
        final settings = LiquidGlassSettings(
          thickness: thickness,
          blur: blur,
          chromaticAberration: chromatic,
          lightIntensity: lightIntensity,
          refractiveIndex: refractive,
          saturation: saturation,
          ambientStrength: 0.8,
          lightAngle: 0.75 * pi,
          glassColor: tintColor,
        );
        return GlassCard(
          useOwnLayer: true,
          settings: settings,
          quality: glassQuality,
          padding: EdgeInsets.zero,
          shape: LiquidRoundedRectangle(borderRadius: 28),
          clipBehavior: Clip.antiAlias,
          child: bar,
        );
      },
    );
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final l = AppLocalizations.of(context);
    final confirm = await showOnyxConfirmDialog(
      context: context,
      title: l.deleteMessageTitle,
      message: l.deleteGroupMsgContent,
      confirmLabel: l.delete,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirm != true) return;

    try {
      final token = await AccountManager.getToken(_myUsername);
      if (token == null) return;
      final response = await http.delete(
        Uri.parse(
            '$serverBase/group/${widget.groupId}/comments/${comment['id']}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(
              () => _comments.removeWhere((c) => c['id'] == comment['id']));
        }
      } else if (mounted) {
        _showSnack(l.failedDeleteComment);
      }
    } catch (e) {
      if (mounted) _showSnack(l.failedDeleteComment);
    }
  }

  Future<void> _serverToggleCommentReaction(
      dynamic commentId, String emoji, bool wasReacted) async {
    try {
      final token = await AccountManager.getToken(_myUsername);
      if (token == null) return;
      final http.Response resp;
      if (wasReacted) {
        final url =
            '$serverBase/group/${widget.groupId}/comments/$commentId/reactions/${Uri.encodeComponent(emoji)}';
        resp = await http.delete(
          Uri.parse(url),
          headers: {'authorization': 'Bearer $token'},
        );
      } else {
        final url =
            '$serverBase/group/${widget.groupId}/comments/$commentId/reactions';
        resp = await http.post(
          Uri.parse(url),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'emoji': emoji}),
        );
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        final reactions = data?['reactions'];
        if (reactions is Map) {
          applyReactionUpdate(
              _reactionKey(commentId), Map<String, dynamic>.from(reactions));
        }
      } else {
        toggleReaction(_reactionKey(commentId), emoji, _myUsername,
            anonymous: true);
        if (mounted) {
          final l = AppLocalizations.of(context);
          try {
            final error = jsonDecode(resp.body)['error'] ?? l.failedReaction;
            _showSnack(l.errorMsg(error.toString()));
          } catch (_) {
            _showSnack(l.failedReaction);
          }
        }
      }
    } catch (e) {
      debugPrint('[comment-reaction] error: $e');
    }
  }

  List<DesktopMenuItem> _buildCommentMenuItems(Map<String, dynamic> c) {
    final l = AppLocalizations.of(context);
    final sender = c['sender']?.toString() ?? '';
    final content = c['content']?.toString() ?? '';
    final isMe = sender == _myUsername;
    final canDelete = isMe || widget.canDeleteAny;
    return [
      DesktopMenuItem(
        icon: Icons.reply_rounded,
        label: l.reply,
        onPressed: () {
          if (_editingComment != null) _controller.clear();
          setState(() {
            _replyingTo = c;
            _editingComment = null;
          });
        },
      ),
      DesktopMenuItem(
        icon: Icons.add_reaction_outlined,
        label: l.react,
        onPressed: () {
          openEmojiPicker(context, _reactionKey(c['id']), _myUsername,
              anonymous: true, onAfterToggle: (emoji, wasReacted) {
            _serverToggleCommentReaction(c['id'], emoji, wasReacted);
          });
        },
      ),
      DesktopMenuItem(
        icon: Icons.content_copy_rounded,
        label: l.copy,
        type: ContextMenuButtonType.copy,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: content));
          _showSnack(l.msgCopied);
        },
      ),
      if (isMe)
        DesktopMenuItem(
          icon: Icons.edit_rounded,
          label: l.edit,
          onPressed: () => _startEditingComment(c),
        ),
      if (canDelete)
        DesktopMenuItem(
          icon: Icons.delete_outline_rounded,
          label: l.delete,
          type: ContextMenuButtonType.delete,
          color: Colors.red.shade400,
          onPressed: () => _deleteComment(c),
        ),
    ];
  }

  void _showCommentActionMenu(Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final items = _buildCommentMenuItems(c);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
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
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => ListTile(
                    leading: Icon(item.icon, color: item.color),
                    title:
                        Text(item.label, style: TextStyle(color: item.color)),
                    dense: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      item.onPressed?.call();
                    },
                  )),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    rootScreenKey.currentState?.showSnack(msg);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // Shrink the comment list by however much the keyboard eats into the
    // viewport, so the dialog's total height still fits above it and the
    // input row at the bottom stays on-screen instead of sliding under the
    // keyboard (OnyxDialogShell's Dialog has no scroll/resize of its own).
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final listHeight = (420 - keyboardHeight).clamp(120.0, 420.0);
    return OnyxDialogShell(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnyxDialogHeader(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mode_comment_outlined,
                  size: 20, color: cs.primary),
            ),
            title: Text(
              l.commentsTitle,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            subtitle: Text(
              '${widget.postSender}: ${getPreviewText(widget.postContent)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
            onClose: () => Navigator.of(context).pop(),
          ),
          SizedBox(
            height: listHeight,
            child: Stack(
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(
                            child: Text(l.noCommentsYet,
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5))))
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                            itemCount: _comments.length,
                            itemBuilder: (context, i) {
                              // reverse:true renders index 0 at the bottom —
                              // same trick GroupChatScreen's main list uses
                              // so sending while already scrolled to the
                              // newest comment needs no scroll motion at
                              // all, which is what keeps the outgoing
                              // bubble's fly-in animation from racing a
                              // concurrent scroll (see
                              // _scrollToBottomIfNeeded).
                              final c = _comments[_comments.length - 1 - i];
                              final sender = c['sender']?.toString() ?? '';
                              final content = c['content']?.toString() ?? '';
                              final replyToSender =
                                  c['reply_to_sender']?.toString();
                              final replyToContent =
                                  c['reply_to_content']?.toString();
                              final isMe = sender == _myUsername;
                              final createdAt =
                                  DateTime.tryParse(
                                          c['created_at']?.toString() ?? '') ??
                                      DateTime.now();
                              final animKey =
                                  c['animationId']?.toString() ?? 'c_${c['id']}';
                              final isFirstAppearance =
                                  !_alreadyAnimated.contains(animKey);
                              if (isFirstAppearance) {
                                _alreadyAnimated.add(animKey);
                              }
                              final isDesktop = !kIsWeb &&
                                  (Platform.isWindows ||
                                      Platform.isMacOS ||
                                      Platform.isLinux);

                              final bubble = Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: SwipeableMessageWrapper(
                                  onSwipeRight: () =>
                                      _showCommentActionMenu(c),
                                  onSwipeLeft: () {
                                    if (_editingComment != null) {
                                      _controller.clear();
                                    }
                                    setState(() {
                                      _replyingTo = c;
                                      _editingComment = null;
                                    });
                                  },
                                  child: MessageBubble(
                                    key: ValueKey('mb_$animKey'),
                                    text: content,
                                    outgoing: isMe,
                                    time: createdAt,
                                    peerUsername: sender,
                                    replyToUsername: replyToSender,
                                    replyToContent: replyToContent,
                                    desktopMenuItems: isDesktop
                                        ? _buildCommentMenuItems(c)
                                        : null,
                                    onRightClick: isDesktop
                                        ? (offset) {
                                            final items =
                                                _buildCommentMenuItems(c);
                                            if (items.isNotEmpty) {
                                              showMessageDesktopMenu(
                                                  context, offset, items);
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                              );

                              final animatedBubble = AnimatedMessageBubble(
                                key: ValueKey('anim_$animKey'),
                                outgoing: isMe,
                                animate: isFirstAppearance,
                                flightOriginKey: isMe ? _inputAreaKey : null,
                                flightFromEdge: !isMe,
                                alignRight: isMe,
                                child: bubble,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 2, left: 4),
                                        child: Text(sender,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.6))),
                                      ),
                                    Align(
                                      alignment: isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: animatedBubble,
                                    ),
                                    Align(
                                      alignment: isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: MessageReactionBar(
                                        reactions:
                                            reactionsFor(_reactionKey(c['id'])),
                                        myUsername: _myUsername,
                                        outgoing: isMe,
                                        onToggle: (emoji) {
                                          final wasReacted = hasReaction(
                                              _reactionKey(c['id']),
                                              emoji,
                                              _myUsername);
                                          toggleReaction(
                                              _reactionKey(c['id']),
                                              emoji,
                                              _myUsername,
                                              anonymous: true);
                                          _serverToggleCommentReaction(
                                              c['id'], emoji, wasReacted);
                                        },
                                        onAddReaction: (ctx2) {
                                          openEmojiPicker(ctx2,
                                              _reactionKey(c['id']),
                                              _myUsername,
                                              anonymous: true,
                                              onAfterToggle:
                                                  (emoji, wasReacted) {
                                            _serverToggleCommentReaction(
                                                c['id'], emoji, wasReacted);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollToBottom,
                    builder: (_, show, __) => AnimatedScale(
                      scale: show ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: AnimatedOpacity(
                        opacity: show ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: FloatingActionButton.small(
                          heroTag: 'internal_comments_scroll_to_bottom',
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_editingComment != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l.edit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.primary),
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelEditingComment,
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  )
                else if (_replyingTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_replyingTo!['sender']}: ${getPreviewText(_replyingTo!['content']?.toString() ?? '')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _replyingTo = null),
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
                _buildCommentInputBar(cs, l),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
