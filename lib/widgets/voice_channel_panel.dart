// lib/widgets/voice_channel_panel.dart
//
// Collapsible panel shown at the top of an external group chat screen.
// Lists active voice channels and lets users create new ones.

import 'package:flutter/material.dart';
import '../voice/voice_channel_manager.dart';
import '../managers/external_server_manager.dart';

class VoiceChannelPanel extends StatefulWidget {
  const VoiceChannelPanel({super.key, required this.serverId});
  final String serverId;

  @override
  State<VoiceChannelPanel> createState() => _VoiceChannelPanelState();
}

class _VoiceChannelPanelState extends State<VoiceChannelPanel> {
  bool _expanded = true;
  bool _loading = true;
  bool _showCreate = false;
  final _createCtrl = TextEditingController();
  final _createFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchInitial();
    VoiceChannelManager.instance.allChannels.addListener(_onChannelsChanged);
  }

  @override
  void dispose() {
    VoiceChannelManager.instance.allChannels.removeListener(_onChannelsChanged);
    _createCtrl.dispose();
    _createFocus.dispose();
    super.dispose();
  }

  void _onChannelsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchInitial() async {
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

  void _joinOrCreate(String name) {
    final channelId = name.trim();
    if (channelId.isEmpty) return;
    VoiceChannelManager.instance.joinChannel(widget.serverId, channelId);
    setState(() {
      _showCreate = false;
      _createCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Container(
        color: scheme.surfaceContainerLow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            size: 16,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.volume_up_rounded, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'VOICE CHANNELS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          if (_loading) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // "+" button — add/create channel
                  Tooltip(
                    message: 'Create voice channel',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showCreate = !_showCreate;
                          _expanded = true;
                        });
                        if (_showCreate) {
                          Future.delayed(const Duration(milliseconds: 50),
                              () => _createFocus.requestFocus());
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _showCreate ? Icons.close_rounded : Icons.add_rounded,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Create channel input ──────────────────────────────────────
            if (_showCreate && _expanded)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up_rounded,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _createCtrl,
                        focusNode: _createFocus,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Channel name',
                          hintStyle: TextStyle(
                              fontSize: 13,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor:
                              scheme.surfaceContainerHighest,
                        ),
                        onSubmitted: _joinOrCreate,
                        textInputAction: TextInputAction.go,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _joinOrCreate(_createCtrl.text),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.call_rounded,
                            size: 16, color: scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Channel list ─────────────────────────────────────────────
            if (_expanded)
              ValueListenableBuilder<bool>(
                valueListenable: VoiceChannelManager.instance.isInChannel,
                builder: (_, inChannel, __) =>
                    ValueListenableBuilder<String?>(
                  valueListenable:
                      VoiceChannelManager.instance.currentChannelId,
                  builder: (_, myChannelId, __) {
                    final entries = _channels.entries.toList();

                    if (entries.isEmpty && !_loading) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            Icon(Icons.volume_off_rounded,
                                size: 13,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'No active channels — press + to create one',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: entries.map((e) {
                        final isMe =
                            inChannel && myChannelId == e.key;
                        return _ChannelRow(
                          channelId: e.key,
                          users: e.value,
                          isMyChannel: isMe,
                          myServerId: widget.serverId,
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Channel row ──────────────────────────────────────────────────────────────

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channelId,
    required this.users,
    required this.isMyChannel,
    required this.myServerId,
  });

  final String channelId;
  final List<String> users;
  final bool isMyChannel;
  final String myServerId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: isMyChannel
          ? scheme.primaryContainer.withValues(alpha: 0.22)
          : Colors.transparent,
      child: InkWell(
        onTap: isMyChannel
            ? null
            : () =>
                VoiceChannelManager.instance.joinChannel(myServerId, channelId),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    size: 14,
                    color: isMyChannel
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      channelId,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isMyChannel
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color:
                            isMyChannel ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (isMyChannel)
                    _Chip(
                      label: 'Leave',
                      icon: Icons.call_end_rounded,
                      color: scheme.error,
                      onTap: () =>
                          VoiceChannelManager.instance.leaveChannel(),
                    )
                  else
                    _Chip(
                      label: 'Join',
                      icon: Icons.call_rounded,
                      color: scheme.primary,
                      onTap: () => VoiceChannelManager.instance
                          .joinChannel(myServerId, channelId),
                    ),
                ],
              ),
              if (users.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 3),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: users
                        .map((u) => _UserPill(username: u))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small action chip ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ── User pill ─────────────────────────────────────────────────────────────────

class _UserPill extends StatelessWidget {
  const _UserPill({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          username,
          style: TextStyle(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
