// lib/widgets/voice_channel_popup.dart
//
// Compact dropdown that appears when the user taps the Voice button
// in the AppBar of an external group chat screen.

import 'package:flutter/material.dart';
import '../voice/voice_channel_manager.dart';
import '../managers/external_server_manager.dart';

Future<void> showVoiceChannelPopup(
  BuildContext context,
  String serverId,
) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOut),
        ),
        alignment: const Alignment(0.85, -0.9),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, __) => _VoicePopup(serverId: serverId),
  );
}

class _VoicePopup extends StatefulWidget {
  const _VoicePopup({required this.serverId});
  final String serverId;

  @override
  State<_VoicePopup> createState() => _VoicePopupState();
}

class _VoicePopupState extends State<_VoicePopup> {
  bool _loading = true;
  bool _showCreate = false;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
    VoiceChannelManager.instance.allChannels.addListener(_rebuild);
  }

  @override
  void dispose() {
    VoiceChannelManager.instance.allChannels.removeListener(_rebuild);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final raw = await ExternalServerManager.getVoiceChannels(widget.serverId);
    final map = Map<String, Map<String, List<String>>>.from(
        VoiceChannelManager.instance.allChannels.value);
    final serverMap = <String, List<String>>{};
    for (final ch in raw) {
      final id = ch['id'] as String;
      final users = List<String>.from(ch['users'] as List? ?? []);
      if (users.isNotEmpty) serverMap[id] = users;
    }
    map[widget.serverId] = serverMap;
    VoiceChannelManager.instance.allChannels.value = map;
    if (mounted) setState(() => _loading = false);
  }

  Map<String, List<String>> get _channels =>
      VoiceChannelManager.instance.allChannels.value[widget.serverId] ?? {};

  void _join(String channelId) {
    VoiceChannelManager.instance.joinChannel(widget.serverId, channelId);
    Navigator.of(context).pop();
  }

  void _leave() {
    VoiceChannelManager.instance.leaveChannel();
    Navigator.of(context).pop();
  }

  void _create() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    _join(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top + kToolbarHeight;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(
          top: topPad + 4,
          right: 8,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.55,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Voice Channels',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        // refresh button
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: 'Refresh',
                          visualDensity: VisualDensity.compact,
                          onPressed: _load,
                        ),
                        // + create button
                        IconButton(
                          icon: Icon(
                            _showCreate
                                ? Icons.close_rounded
                                : Icons.add_rounded,
                            size: 20,
                          ),
                          tooltip: 'New channel',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() => _showCreate = !_showCreate);
                            if (_showCreate) {
                              Future.delayed(
                                const Duration(milliseconds: 60),
                                () => _focus.requestFocus(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 1),

                  // ── Create input ──────────────────────────────────────
                  if (_showCreate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Channel name…',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.4),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: scheme.surfaceContainerHighest,
                              ),
                              onSubmitted: (_) => _create(),
                              textInputAction: TextInputAction.go,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _JoinButton(
                            icon: Icons.call_rounded,
                            color: scheme.primary,
                            onTap: _create,
                          ),
                        ],
                      ),
                    ),

                  // ── Channel list ──────────────────────────────────────
                  Flexible(
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          )
                        : ValueListenableBuilder<bool>(
                            valueListenable:
                                VoiceChannelManager.instance.isInChannel,
                            builder: (_, inChannel, __) =>
                                ValueListenableBuilder<String?>(
                              valueListenable:
                                  VoiceChannelManager.instance.currentChannelId,
                              builder: (_, myChannelId, __) {
                                final entries = _channels.entries.toList();

                                if (entries.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 14, 16, 18),
                                    child: Row(
                                      children: [
                                        Icon(Icons.volume_off_rounded,
                                            size: 15,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.3)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'No active channels.\nPress + to create one.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6),
                                  itemCount: entries.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.35),
                                  ),
                                  itemBuilder: (_, i) {
                                    final id = entries[i].key;
                                    final users = entries[i].value;
                                    final isMe =
                                        inChannel && myChannelId == id;
                                    return _ChannelTile(
                                      channelId: id,
                                      users: users,
                                      isMyChannel: isMe,
                                      onJoin: () => _join(id),
                                      onLeave: _leave,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                  ),

                  // ── Footer: connected indicator ───────────────────────
                  ValueListenableBuilder<bool>(
                    valueListenable: VoiceChannelManager.instance.isInChannel,
                    builder: (_, inChannel, __) {
                      if (!inChannel) return const SizedBox.shrink();
                      return ValueListenableBuilder<String?>(
                        valueListenable:
                            VoiceChannelManager.instance.currentChannelId,
                        builder: (_, chId, __) {
                          return ValueListenableBuilder<bool>(
                            valueListenable:
                                VoiceChannelManager.instance.isMuted,
                            builder: (_, muted, __) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer
                                      .withValues(alpha: 0.3),
                                  border: Border(
                                    top: BorderSide(
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF43B581),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        'Connected · $chId',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: scheme.primary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // mute toggle
                                    _JoinButton(
                                      icon: muted
                                          ? Icons.mic_off_rounded
                                          : Icons.mic_rounded,
                                      color: muted
                                          ? scheme.error
                                          : scheme.onSurface
                                              .withValues(alpha: 0.7),
                                      onTap: VoiceChannelManager
                                          .instance.toggleMute,
                                    ),
                                    const SizedBox(width: 4),
                                    // leave
                                    _JoinButton(
                                      icon: Icons.call_end_rounded,
                                      color: scheme.error,
                                      onTap: _leave,
                                    ),
                                  ],
                                ),
                              );
                            },
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
    );
  }
}

// ── Channel tile ──────────────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channelId,
    required this.users,
    required this.isMyChannel,
    required this.onJoin,
    required this.onLeave,
  });

  final String channelId;
  final List<String> users;
  final bool isMyChannel;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isMyChannel ? null : onJoin,
      child: Container(
        color: isMyChannel
            ? scheme.primaryContainer.withValues(alpha: 0.2)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.volume_up_rounded,
                size: 15,
                color: isMyChannel
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channelId,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isMyChannel
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isMyChannel
                          ? scheme.primary
                          : scheme.onSurface,
                    ),
                  ),
                  if (users.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: users.map((u) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF43B581),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              u,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMyChannel)
              _JoinButton(
                icon: Icons.call_end_rounded,
                color: scheme.error,
                onTap: onLeave,
              )
            else
              _JoinButton(
                icon: Icons.call_rounded,
                color: scheme.primary,
                onTap: onJoin,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────────

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
