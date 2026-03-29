// lib/screens/forward_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../models/group.dart';
import '../models/favorite_chat.dart';
import '../models/external_server.dart';
import '../managers/account_manager.dart';
import '../managers/external_server_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/user_cache.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/adaptive_blur.dart';
import '../widgets/animated_nav_icon.dart';

class ForwardScreen extends StatefulWidget {
  final List<String> contents;
  final bool isDialog;
  const ForwardScreen({super.key, required this.contents, this.isDialog = false});

  /// Shows the forward UI: a popup dialog on desktop, full-screen route on mobile.
  static Future<void> show(BuildContext context, List<String> contents) {
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        builder: (_) => ForwardScreen(contents: contents, isDialog: true),
      );
    }
    return Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ForwardScreen(contents: contents)),
    );
  }

  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  int _tabIndex = 0;
  late final PageController _pageController;

  List<String> _chatUsernames = [];
  List<Group> _internalGroups = [];
  List<Group> _externalGroups = [];
  List<FavoriteChat> _favorites = [];
  bool _groupsLoading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadData() {
    final root = rootScreenKey.currentState;
    if (root == null) return;
    final me = root.currentUsername ?? '';

    final usernames = <String>[];
    for (final key in root.chats.keys) {
      if (key.startsWith('fav:')) continue;
      final parts = key.split(':');
      if (parts.length == 2) {
        final other = parts.firstWhere((p) => p != me, orElse: () => '');
        if (other.isNotEmpty && other != me) usernames.add(other);
      }
    }
    _chatUsernames = usernames;
    _favorites = root.favorites.toList();
    _loadGroups(me);
  }

  Future<void> _loadGroups(String username) async {
    final internal = await AccountManager.loadGroupsCache(username);
    final external =
        List<Group>.from(ExternalServerManager.externalGroups.value);
    if (mounted) {
      setState(() {
        _internalGroups = internal;
        _externalGroups = external;
        _groupsLoading = false;
      });
    }
  }

  void _selectTab(int i) {
    if (i == _tabIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _tabIndex = i);
    _pageController.jumpToPage(i);
  }

  // ── send actions ─────────────────────────────────────────────────────────────

  Future<void> _sendToDirect(String username) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      for (final content in widget.contents) {
        await rootScreenKey.currentState?.sendChatMessage(username, content);
      }
      if (mounted) {
        Navigator.of(context).pop();
        rootScreenKey.currentState?.showSnack('Message forwarded');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendToInternalGroup(Group group) async {
    if (_sending) return;
    if (!group.canPost) {
      rootScreenKey.currentState
          ?.showSnack('You don\'t have permission to post here');
      return;
    }
    setState(() => _sending = true);
    try {
      final username = rootScreenKey.currentState?.currentUsername ?? '';
      final token = await AccountManager.getToken(username);
      if (token == null) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      for (final content in widget.contents) {
        await http.post(
          Uri.parse('$serverBase/group/${group.id}/send'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'content': content}),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        rootScreenKey.currentState?.showSnack('Message forwarded');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendToExternalGroup(Group group) async {
    if (_sending) return;
    if (!group.canPost) {
      rootScreenKey.currentState
          ?.showSnack('You don\'t have permission to post here');
      return;
    }
    final serverId = group.externalServerId;
    if (serverId == null) return;
    setState(() => _sending = true);
    try {
      for (final content in widget.contents) {
        await ExternalServerManager.sendMessage(serverId, group.id, content);
      }
      if (mounted) {
        Navigator.of(context).pop();
        rootScreenKey.currentState?.showSnack('Message forwarded');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _sendToFavorite(FavoriteChat fav) {
    if (_sending) return;
    final root = rootScreenKey.currentState;
    if (root == null) return;
    for (final content in widget.contents) {
      root.sendMessageToFavorite(fav.id, content);
    }
    Navigator.of(context).pop();
    root.showSnack('Message forwarded');
  }

  // ── favorite avatar (local file or bookmark fallback) ───────────────────────

  Widget _buildFavAvatar(BuildContext context, FavoriteChat fav) {
    final scheme = Theme.of(context).colorScheme;
    final path = fav.avatarPath;
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: FileImage(File(path)),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.primaryContainer,
      child: Icon(Icons.bookmark, color: scheme.primary),
    );
  }

  // ── glass card (same as chats_tab) ──────────────────────────────────────────

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

  // ── background (mobile scaffold only) ────────────────────────────────────────

  Widget _buildBackground() {
    return ValueListenableBuilder<String?>(
      valueListenable: SettingsManager.chatBackground,
      builder: (_, path, __) {
        if (path == null) return const SizedBox.shrink();
        final f = File(path);
        if (!f.existsSync()) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: SettingsManager.blurBackground,
          builder: (_, blur, __) {
            return ValueListenableBuilder<double>(
              valueListenable: SettingsManager.blurSigma,
              builder: (_, sigma, __) {
                final provider = FileImage(f);
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
    );
  }

  // ── shared NavigationBar destinations ────────────────────────────────────────

  Widget _buildNavigationBar(ColorScheme scheme) {
    return NavigationBar(
      selectedIndex: _tabIndex,
      onDestinationSelected: _selectTab,
      height: 58,
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.15),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: [
        NavigationDestination(
          icon: AnimatedNavIcon(
            icon: Icons.chat_bubble,
            size: 22,
            isSelected: _tabIndex == 0,
            animationType: NavIconAnimationType.bounce,
            entryDelay: 300,
          ),
          selectedIcon: AnimatedNavIcon(
            icon: Icons.chat_bubble,
            size: 24,
            color: scheme.primary,
            isSelected: _tabIndex == 0,
            animationType: NavIconAnimationType.bounce,
            entryDelay: 300,
          ),
          label: '',
        ),
        NavigationDestination(
          icon: AnimatedNavIcon(
            icon: Icons.group,
            size: 22,
            isSelected: _tabIndex == 1,
            animationType: NavIconAnimationType.bounce,
            entryDelay: 400,
          ),
          selectedIcon: AnimatedNavIcon(
            icon: Icons.group,
            size: 24,
            color: scheme.primary,
            isSelected: _tabIndex == 1,
            animationType: NavIconAnimationType.bounce,
            entryDelay: 400,
          ),
          label: '',
        ),
        NavigationDestination(
          icon: AnimatedNavIcon(
            icon: Icons.bookmark,
            size: 22,
            isSelected: _tabIndex == 2,
            animationType: NavIconAnimationType.bounce,
            entryDelay: 500,
          ),
          selectedIcon: AnimatedNavIcon(
            icon: Icons.bookmark,
            size: 24,
            color: scheme.primary,
            isSelected: _tabIndex == 2,
            animationType: NavIconAnimationType.bounce,
            entryDelay: 500,
          ),
          label: '',
        ),
      ],
    );
  }

  // ── floating glass nav bar (scaffold / mobile) ────────────────────────────────

  Widget _buildFloatingNavBar(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementOpacity,
          builder: (_, opacity, __) {
            final scheme = Theme.of(context).colorScheme;
            final navBackground = SettingsManager.getElementColor(
              scheme.surfaceContainerHighest,
              brightness,
            ).withValues(alpha: opacity);

            final screenW = MediaQuery.of(context).size.width;
            final navWidth = screenW / 3;

            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 58,
                        width: navWidth + 20,
                        decoration: BoxDecoration(
                          color: navBackground,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragUpdate: (details) {
                                final tabWidth = navWidth / 3;
                                final newIndex =
                                    (details.localPosition.dx / tabWidth)
                                        .floor()
                                        .clamp(0, 2);
                                _selectTab(newIndex);
                              },
                              child: SizedBox(
                                width: navWidth,
                                height: 58,
                                child: _buildNavigationBar(scheme),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── inline nav bar (dialog / desktop) ────────────────────────────────────────

  Widget _buildInlineNavBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementOpacity,
          builder: (_, opacity, __) {
            final bg = SettingsManager.getElementColor(
              scheme.surfaceContainerHighest,
              brightness,
            ).withValues(alpha: (opacity * 0.5).clamp(0.0, 1.0));
            return Container(
              height: 64,
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: _buildNavigationBar(scheme),
            );
          },
        );
      },
    );
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) return _buildDialogLayout(context);
    final bottomInset = MediaQuery.of(context).padding.bottom + 76;
    return _buildScaffoldLayout(context, bottomInset);
  }

  // Desktop popup
  Widget _buildDialogLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, brightness, __) {
        return ValueListenableBuilder<double>(
          valueListenable: SettingsManager.elementOpacity,
          builder: (_, opacity, __) {
            final bgColor = SettingsManager.getElementColor(
              scheme.surfaceContainerHighest,
              brightness,
            ).withValues(alpha: (opacity * 1.2).clamp(0.0, 1.0));

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 480, maxHeight: 560),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // ── header ──
                        SizedBox(
                          height: 56,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  'Forward message',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => Navigator.of(context).pop(),
                                  splashRadius: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                        // ── content ──
                        Expanded(
                          child: _sending
                              ? const Center(child: CircularProgressIndicator())
                              : PageView(
                                  controller: _pageController,
                                  onPageChanged: (i) =>
                                      setState(() => _tabIndex = i),
                                  children: [
                                    _buildChatsTab(8),
                                    _buildGroupsTab(8),
                                    _buildFavoritesTab(8),
                                  ],
                                ),
                        ),
                        // ── inline nav ──
                        _buildInlineNavBar(context),
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
  }

  // Mobile full-screen
  Widget _buildScaffoldLayout(BuildContext context, double bottomInset) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsManager.applyGlobally,
      builder: (_, applyGlobally, __) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Forward message'),
            backgroundColor: Colors.transparent,
          ),
          body: Stack(
            children: [
              if (applyGlobally) _buildBackground(),
              if (_sending)
                const Center(child: CircularProgressIndicator())
              else
                PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _tabIndex = i),
                  children: [
                    _buildChatsTab(bottomInset),
                    _buildGroupsTab(bottomInset),
                    _buildFavoritesTab(bottomInset),
                  ],
                ),
              _buildFloatingNavBar(context),
            ],
          ),
        );
      },
    );
  }

  // ── tabs ────────────────────────────────────────────────────────────────────

  Widget _buildChatsTab(double bottomInset) {
    if (_chatUsernames.isEmpty) {
      return const Center(child: Text('No chats'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          12,
          widget.isDialog
              ? 8
              : kToolbarHeight + MediaQuery.of(context).padding.top + 8,
          12,
          bottomInset + 8),
      itemCount: _chatUsernames.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final username = _chatUsernames[i];
        final profile = UserCache.getSync(username);
        final displayName = profile?.displayName ?? username;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _sendToDirect(username),
          child: _glassCard(
            context: context,
            child: Row(
              children: [
                AvatarWidget(
                  username: username,
                  tokenProvider: avatarTokenProvider,
                  avatarBaseUrl: serverBase,
                  size: 40,
                  editable: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displayName != username)
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
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

  Widget _buildGroupsTab(double bottomInset) {
    if (_groupsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final all = [..._internalGroups, ..._externalGroups]
        .where((g) => g.canPost)
        .toList();
    if (all.isEmpty) {
      return const Center(child: Text('No groups'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          12,
          widget.isDialog
              ? 8
              : kToolbarHeight + MediaQuery.of(context).padding.top + 8,
          12,
          bottomInset + 8),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final g = all[i];
        final isExternal = g.isExternal;
        ExternalServer? server;
        if (isExternal && g.externalServerId != null) {
          try {
            server = ExternalServerManager.servers.value
                .firstWhere((s) => s.id == g.externalServerId);
          } catch (_) {
            server = null;
          }
        }
        final avatarUrl = isExternal && server != null
            ? '${server.baseUrl}/groups/${g.id}/avatar?v=${g.avatarVersion}&sid=${server.id}'
            : '$serverBase/group/${g.id}/avatar?v=${g.avatarVersion}';
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => isExternal
              ? _sendToExternalGroup(g)
              : _sendToInternalGroup(g),
          child: _glassCard(
            context: context,
            child: Row(
              children: [
                CircleAvatar(
                  key: ValueKey('fwd_grp_${g.id}_${g.avatarVersion}'),
                  radius: 20,
                  backgroundImage: NetworkImage(avatarUrl),
                  onBackgroundImageError: (_, __) {},
                  child: null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        g.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isExternal && server != null)
                        Text(
                          server.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
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

  Widget _buildFavoritesTab(double bottomInset) {
    if (_favorites.isEmpty) {
      return const Center(child: Text('No favorites'));
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          12,
          widget.isDialog
              ? 8
              : kToolbarHeight + MediaQuery.of(context).padding.top + 8,
          12,
          bottomInset + 8),
      itemCount: _favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final fav = _favorites[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _sendToFavorite(fav),
          child: _glassCard(
            context: context,
            child: Row(
              children: [
                _buildFavAvatar(context, fav),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fav.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
