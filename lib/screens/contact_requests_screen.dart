// lib/screens/contact_requests_screen.dart
//
// "Requests": people who added us by our onion address and wait to be
// accepted (see onion_requests.dart). A modal in AboutOnyxDialog's chrome:
// the list, and -- in the same modal -- a card per request with who they
// say they are, their verified address, their comment, and Accept / Decline
// (decline, or decline and block). Nothing here goes back to them until
// Accept. Also the composer for our own requests' comment.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../globals.dart' show rootScreenKey;
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_extra.dart';
import '../services/onion/onion_paired_peers.dart';
import '../services/onion/onion_requests.dart';
import '../services/onion/onion_transport_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/onyx_dialog.dart';
import 'chats_tab.dart' show getPreviewText;

/// Before a contact request goes out (adding someone by address): an
/// AboutOnyx-style modal for its comment. Returns the comment, '' for
/// "without a comment", or null if closed -- then nothing is sent at all.
Future<String?> showContactRequestComposer(
    BuildContext context, String shownName) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final l = AppLocalizations.of(ctx);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: cs.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.mark_chat_unread_outlined,
                            color: cs.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.contactRequestComposeTitle,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            Text(shownName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    l.contactRequestComposeBody(shownName),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: OnionRequests.maxMessageLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l.contactRequestComposeHint,
                      filled: true,
                      fillColor: cs.primary.withValues(alpha: 0.05),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.12)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                            color: cs.primary.withValues(alpha: 0.12)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: ctrl,
                        builder: (_, v, __) => FilledButton(
                          onPressed: v.text.trim().isEmpty
                              ? null
                              : () => Navigator.of(ctx).pop(v.text.trim()),
                          style: FilledButton.styleFrom(
                            padding: kOnyxDialogButtonPadding,
                            shape: kOnyxDialogButtonShape,
                          ),
                          child: Text(l.contactRequestSend),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(''),
                        style: OutlinedButton.styleFrom(
                          padding: kOnyxDialogButtonPadding,
                          shape: kOnyxDialogButtonShape,
                        ),
                        child: Text(l.contactRequestSkip),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  ctrl.dispose();
  return result;
}

Future<void> showContactRequestsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ContactRequestsDialog(),
  );
}

/// Whether accepting [req] would merge a different key into an existing
/// contact's chat (same self-claimed username).
bool contactRequestClashes(OnionContactRequest req) =>
    OnionPairedPeers.allByUsername(req.username)
        .any((p) => p.identityPubB64 != req.pub);

String _shownName(OnionContactRequest r) =>
    r.name.isNotEmpty ? r.name : '@${r.username}';

/// A stranger has no avatar for us (no profile until accepted): a letter.
class _LetterAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _LetterAvatar({required this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final letter =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ContactRequestsDialog extends StatefulWidget {
  const _ContactRequestsDialog();

  @override
  State<_ContactRequestsDialog> createState() => _ContactRequestsDialogState();
}

class _ContactRequestsDialogState extends State<_ContactRequestsDialog> {
  /// The request open in the card view; null = the list.
  String? _openPub;

  Future<void> _accept(OnionContactRequest req) async {
    final l = AppLocalizations.of(context);
    await OnionTransportService.instance.acceptRequest(req.pub);
    rootScreenKey.currentState
        ?.showSnack(l.contactRequestAccepted(_shownName(req)));
    if (mounted) setState(() => _openPub = null);
  }

  /// Decline, or decline and block -- the user picks.
  Future<void> _decline(OnionContactRequest req) async {
    final choice = await showOnyxDialog<String>(
      context: context,
      barrierLabel: AppLocalizations.of(context).contactRequestDeclineTitle,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        final cs = Theme.of(ctx).colorScheme;
        return OnyxDialogShell(
          maxWidth: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnyxDialogHeader(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_off_outlined,
                      size: 20, color: cs.error),
                ),
                title: Text(
                  l.contactRequestDeclineTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                onClose: () => Navigator.of(ctx).pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  l.contactRequestDeclineChoiceBody,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop('block'),
                      style: FilledButton.styleFrom(
                        padding: kOnyxDialogButtonPadding,
                        shape: kOnyxDialogButtonShape,
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      child: Text(l.contactRequestDeclineAndBlock),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop('decline'),
                      style: OutlinedButton.styleFrom(
                        padding: kOnyxDialogButtonPadding,
                        shape: kOnyxDialogButtonShape,
                        foregroundColor: cs.error,
                        side: BorderSide(
                            color: cs.error.withValues(alpha: 0.5)),
                      ),
                      child: Text(l.contactRequestDecline),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: kOnyxDialogButtonPadding,
                        shape: kOnyxDialogButtonShape,
                      ),
                      child: Text(l.cancel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    await OnionTransportService.instance
        .declineRequest(req.pub, block: choice == 'block');
    if (mounted) setState(() => _openPub = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Material(
          color: cs.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(28),
          child: ValueListenableBuilder<List<OnionContactRequest>>(
            valueListenable: OnionRequests.requests,
            builder: (context, reqs, _) {
              final open =
                  _openPub == null ? null : OnionRequests.byPub(_openPub!);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(cs, l, open),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: open == null
                          ? _list(cs, l, reqs)
                          : _card(cs, l, open),
                    ),
                  ),
                  if (open != null) _actions(cs, l, open),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs, AppLocalizations l, OnionContactRequest? open) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
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
          GestureDetector(
            onTap: open == null ? null : () => setState(() => _openPub = null),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                  open == null
                      ? Icons.person_add_alt_1_rounded
                      : Icons.arrow_back_rounded,
                  color: cs.primary,
                  size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              open == null ? l.contactRequestsEntry : _shownName(open),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  size: 18, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
      ColorScheme cs, AppLocalizations l, List<OnionContactRequest> reqs) {
    if (reqs.isEmpty) {
      return Padding(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.all(32),
        child: Text(
          l.contactRequestsEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('list'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      itemCount: reqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final req = reqs[i];
        final clash = contactRequestClashes(req);
        final last = req.messages.isEmpty ? null : req.messages.last;
        final preview = last == null ? null : getPreviewText(last.text);
        final isFile = last != null && preview != last.text;
        return InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: () => setState(() => _openPub = req.pub),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.10),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                _LetterAvatar(name: _shownName(req)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _shownName(req),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          if (clash) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: Color(0xFFFFA000)),
                          ],
                        ],
                      ),
                      Text(
                        last == null
                            ? '@${req.username} · ${l.contactRequestNoMessages}'
                            : (isFile
                                ? l.localizePreview(preview!)
                                : last.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isFile ? FontWeight.w500 : null,
                          color: isFile
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(ColorScheme cs, AppLocalizations l, OnionContactRequest req) {
    final clash = contactRequestClashes(req);
    final muted = cs.onSurface.withValues(alpha: 0.6);
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary)),
              const SizedBox(height: 6),
              child,
            ],
          ),
        );
    // A pill (radius 27), like the rows of this modal.
    Widget copyable(String text) => InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
            rootScreenKey.currentState?.showSnack(l.msgCopied);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.10), width: 0.8),
            ),
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    color: cs.onSurface)),
          ),
        );

    return ListView(
      key: ValueKey('card-${req.pub}'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      children: [
        Center(child: _LetterAvatar(name: _shownName(req), size: 72)),
        const SizedBox(height: 10),
        Text(_shownName(req),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        Text('@${req.username}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted)),
        if (clash) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA000).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFFA000).withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFFA000), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.contactRequestNameClash(req.username),
                      style: TextStyle(fontSize: 13, color: cs.onSurface)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.contactRequestInfo,
                  style: TextStyle(fontSize: 12.5, color: muted)),
            ),
          ],
        ),
        section(l.contactRequestAddress, copyable(req.onionAddress)),
        section(
          l.contactRequestAttached,
          req.messages.isEmpty
              ? Text(l.contactRequestNoMessages,
                  style: TextStyle(fontSize: 13, color: muted))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in req.messages)
                      _RequestMessage(m: m, peerUsername: req.username),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _actions(ColorScheme cs, AppLocalizations l, OnionContactRequest req) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _decline(req),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                padding: kOnyxDialogButtonPadding,
                shape: kOnyxDialogButtonShape,
              ),
              child: Text(l.contactRequestDecline),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => _accept(req),
              style: FilledButton.styleFrom(
                padding: kOnyxDialogButtonPadding,
                shape: kOnyxDialogButtonShape,
              ),
              child: Text(l.contactRequestAccept),
            ),
          ),
        ],
      ),
    );
  }
}

/// The message that came with the request, drawn as the same bubble as in
/// a chat -- minus the link preview (a stranger's URL is never fetched).
/// A file pointer shows as a note: files from non-contacts aren't stored.
class _RequestMessage extends StatelessWidget {
  final OnionRequestMessage m;
  final String peerUsername;
  const _RequestMessage({required this.m, required this.peerUsername});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isFile = getPreviewText(m.text) != m.text;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: MessageBubble(
          text: isFile ? l.contactRequestFileHidden : m.text,
          outgoing: false,
          time: m.at,
          peerUsername: peerUsername,
          allowLinkPreview: false,
        ),
      ),
    );
  }
}
