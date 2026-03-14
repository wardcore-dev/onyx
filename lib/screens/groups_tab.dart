// lib/screens/groups_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart';
import '../managers/settings_manager.dart';
import '../models/group.dart';
import '../managers/account_manager.dart';
import '../managers/external_server_manager.dart';
import '../widgets/external_server_badge.dart';
import '../dialogs/server_connection_dialog.dart';
import 'external_group_chat_screen.dart';
import '../l10n/app_localizations.dart';

List<Group> _parseGroupsJsonInBackground(Map<String, String?> params) {
  final jsonBody = params['jsonBody'] ?? '[]';
  final currentUsername = params['currentUsername'];

  final decoded = jsonDecode(jsonBody);
  List<Group> groups = [];
  if (decoded is List) {
    groups = decoded.map<Group>((g) {
      final ownerUsername = g['owner'] ?? g['owner_id']?.toString() ?? 'unknown';
      
      final myRole = (currentUsername != null && ownerUsername == currentUsername)
          ? 'owner'
          : 'member';

      return Group.fromJson({
        'id': g['id'],
        'name': g['name'] ?? 'Unknown Group',
        'is_channel': g['is_channel'] ?? false,
        'owner': ownerUsername,
        'invite_link': g['invite_link'] ?? g['invite_token'] ?? '',
        'avatar_version': g['avatar_version'] ?? 0,
        'my_role': myRole,
      });
    }).toList();
  }
  return groups;
}

Widget _glassCard({required BuildContext context, required Widget child}) {
  final colorScheme = Theme.of(context).colorScheme;
  return ValueListenableBuilder<double>(
    valueListenable: SettingsManager.elementOpacity,
    builder: (_, opacity, __) {
      return ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) {
          final baseColor = SettingsManager.getElementColor(
            colorScheme.surfaceContainerHighest,
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
                  color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  width: 1.0,
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

class GroupsTab extends StatefulWidget {
  final Function(Group) onOpenGroup;
  const GroupsTab({super.key, required this.onOpenGroup});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  List<Group> _groups = [];
  bool _loading = true;
  bool _hasInternet = true;
  String? _loadedUsername; 
  late final AnimationController _listAnimController;
  late final Animation<double> _listFadeAnim;
  late final AnimationController _screenFadeController;
  late final Animation<double> _screenFadeAnimation;
  bool _screenVisible = false;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _listFadeAnim = CurvedAnimation(
      parent: _listAnimController,
      curve: Curves.easeOut,
    );
    _screenFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _screenFadeAnimation = CurvedAnimation(
      parent: _screenFadeController,
      curve: Curves.easeOut,
    );

    _loadedUsername = rootScreenKey.currentState?.currentUsername ?? '';
    _loadGroupsFromCache().then((_) {
      _loadGroupsFromNetwork();
    });

    groupAvatarVersion.addListener(_onGroupAvatarUpdate);
    
    groupsVersion.addListener(_onGroupsVersion);
    
    ExternalServerManager.externalGroups.addListener(_onExternalGroupsChanged);
    
    accountSwitchVersion.addListener(_onAccountSwitch);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _screenVisible = true);
        _screenFadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    groupAvatarVersion.removeListener(_onGroupAvatarUpdate);
    groupsVersion.removeListener(_onGroupsVersion);
    ExternalServerManager.externalGroups.removeListener(_onExternalGroupsChanged);
    accountSwitchVersion.removeListener(_onAccountSwitch);
    _listAnimController.dispose();
    _screenFadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureLoadedForCurrentAccount();
    });
  }

  Future<void> _loadGroupsFromCache() async {
    final username = rootScreenKey.currentState?.currentUsername ?? '';
    final cached = await AccountManager.loadGroupsCache(username);

    final fixedGroups = cached.map((g) {
      
      final shouldBeOwner = g.owner == username;
      final currentRole = g.myRole;

      if (currentRole == null || (shouldBeOwner && currentRole != 'owner') || (!shouldBeOwner && currentRole == 'owner')) {
        return Group(
          id: g.id,
          name: g.name,
          isChannel: g.isChannel,
          owner: g.owner,
          inviteLink: g.inviteLink,
          avatarVersion: g.avatarVersion,
          externalServerId: g.externalServerId,
          myRole: shouldBeOwner ? 'owner' : 'member',
        );
      }
      return g;
    }).toList();

    if (mounted) {
      setState(() {
        _groups = fixedGroups;
        _loading = _groups.isEmpty;
      });
      if (_groups.isNotEmpty) {
        _listAnimController.forward();
      }
    }
  }

  void _ensureLoadedForCurrentAccount() {
    final username = rootScreenKey.currentState?.currentUsername ?? '';
    if (_loadedUsername == username) return;
    debugPrint('[groups_tab] account changed: reloading groups for $username (was=$_loadedUsername)');
    _loadedUsername = username;

    if (mounted) {
      setState(() {
        _groups = [];
        _loading = true;
        _hasInternet = true;
      });
      _listAnimController.reset();
    }

    _loadGroupsFromCache().then((_) => _loadGroupsFromNetwork());
  }

  void _onAccountSwitch() {
    _ensureLoadedForCurrentAccount();
  }

  Future<void> _loadGroupsFromNetwork() async {
    
    final username = rootScreenKey.currentState?.currentUsername ?? '';

    final token = await AccountManager.getToken(username);
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if ((rootScreenKey.currentState?.currentUsername ?? '') != username) {
      debugPrint('[groups_tab] account changed before HTTP fetch, aborting for $username');
      return;
    }

    try {
      
      final res = await http.get(
        Uri.parse('$serverBase/groups'),
        headers: {'authorization': 'Bearer $token'},
      );

      if ((rootScreenKey.currentState?.currentUsername ?? '') != username) {
        debugPrint('[groups_tab] account changed after HTTP response, discarding results for $username');
        return;
      }

      if (res.statusCode == 200) {
        
        final groups = await compute(_parseGroupsJsonInBackground, {
          'jsonBody': res.body,
          'currentUsername': username,
        });

        if ((rootScreenKey.currentState?.currentUsername ?? '') != username) {
          debugPrint('[groups_tab] account changed after parse, discarding results for $username');
          return;
        }

        await AccountManager.saveGroupsCache(username, groups);

        if (mounted) {
          setState(() {
            _groups = groups;
            _loading = false;
            _hasInternet = true;
          });
          _listAnimController.forward();
        }
      } else {
        debugPrint('[groups_tab] GET /groups failed: ${res.statusCode} ${res.body}');
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[groups_tab] Network error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasInternet = false;
        });
      }
    }
  }

  Future<void> _leaveGroup(int groupId) async {
    final token = await AccountManager.getToken(
      rootScreenKey.currentState?.currentUsername ?? '',
    );
    if (token == null) return;
    try {
      final res = await http.post(
        Uri.parse('$serverBase/group/$groupId/leave'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        if (mounted) {
          final l = AppLocalizations(SettingsManager.appLocale.value);
          rootScreenKey.currentState?.showSnack(l.leftGroup);
          _loadGroupsFromNetwork();
        }
      } else {
        if (mounted) {
          final l = AppLocalizations(SettingsManager.appLocale.value);
          rootScreenKey.currentState?.showSnack(l.failedLeaveGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations(SettingsManager.appLocale.value);
        rootScreenKey.currentState?.showSnack(l.networkError);
      }
    }
  }

  void _onGroupAvatarUpdate() {
    final updates = groupAvatarVersion.value;
    if (updates.isEmpty) return;
    bool changed = false;
    final newList = _groups.map((g) {
      final updated = updates[g.id];
      if (updated != null && updated != g.avatarVersion) {
        changed = true;
        return Group(
          id: g.id,
          name: g.name,
          isChannel: g.isChannel,
          owner: g.owner,
          inviteLink: g.inviteLink,
          avatarVersion: updated,
        );
      }
      return g;
    }).toList();

    if (changed && mounted) {
      setState(() {
        _groups = newList;
      });
      
      final username = rootScreenKey.currentState?.currentUsername ?? '';
      AccountManager.saveGroupsCache(username, _groups);
    }
  }

  void _onGroupsVersion() {
    
    _loadGroupsFromCache();
  }

  void _onExternalGroupsChanged() {
    if (mounted) {
      setState(() {});
      
      if (ExternalServerManager.externalGroups.value.isNotEmpty) {
        _listAnimController.forward();
      }
    }
  }

  Future<void> _joinExternalServer() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ServerConnectionDialog(),
    );
    if (result == true && mounted) {
      setState(() {}); 
    }
  }

  void _openExternalGroup(Group group) {
    final server = ExternalServerManager.servers.value
        .where((s) => s.id == group.externalServerId)
        .firstOrNull;
    if (server == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExternalGroupChatScreen(group: group, server: server),
      ),
    );
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    bool isChannel = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: SettingsManager.elementOpacity.value),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(ctx).createGroupChannel),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(ctx).groupNameLabel,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<double>(
                valueListenable: SettingsManager.elementBrightness,
                builder: (_, brightness, __) {
                  final baseColor = SettingsManager.getElementColor(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    brightness,
                  );
                  return TextField(
                    controller: nameController,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(ctx).groupNameHint,
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: baseColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(AppLocalizations.of(ctx).channelAdminOnly),
                controlAffinity: ListTileControlAffinity.leading,
                value: isChannel,
                onChanged: (bool? v) => setState(() => isChannel = v ?? false),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx).cancel),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final token = await AccountManager.getToken(
                  rootScreenKey.currentState?.currentUsername ?? '',
                );
                if (token == null) return;
                final res = await http.post(
                  Uri.parse('$serverBase/group/create'),
                  headers: {
                    'authorization': 'Bearer $token',
                    'content-type': 'application/json',
                  },
                  body: jsonEncode({'name': name, 'is_channel': isChannel}),
                );
                Navigator.pop(ctx);
                if (res.statusCode == 200) {
                  _loadGroupsFromNetwork();
                } else {
                  final l = AppLocalizations(SettingsManager.appLocale.value);
                  rootScreenKey.currentState?.showSnack(l.failedCreateGroup);
                }
              },
              child: Text(AppLocalizations.of(ctx).create),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup() async {
    final tokenController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface.withValues(alpha: SettingsManager.elementOpacity.value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(ctx).viewByToken),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(ctx).pasteToken,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<double>(
              valueListenable: SettingsManager.elementBrightness,
              builder: (_, brightness, __) {
                final baseColor = SettingsManager.getElementColor(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  brightness,
                );
                return TextField(
                  controller: tokenController,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: baseColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                );
              },
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          FilledButton.tonal(
            onPressed: () async {
              String raw = tokenController.text.trim();
              if (raw.isEmpty) return;
              String inviteToken;

              if (raw.contains('://join/')) {
                
                inviteToken = raw.split('://join/').last;
              } else if (raw.contains('/group/')) {
                
                inviteToken = raw.split('/group/').last;
              } else {
                
                inviteToken = raw;
              }

              inviteToken = inviteToken.trim();
              if (inviteToken.isEmpty) {
                final l = AppLocalizations(SettingsManager.appLocale.value);
                rootScreenKey.currentState?.showSnack(l.invalidInviteLinkFormat);
                return;
              }

              final userToken = await AccountManager.getToken(
                rootScreenKey.currentState?.currentUsername ?? '',
              );
              if (userToken == null) {
                Navigator.of(ctx).pop();
                rootScreenKey.currentState?.showSnack(AppLocalizations(SettingsManager.appLocale.value).notLoggedIn);
                return;
              }
              try {
                final res = await http.post(
                  Uri.parse('$serverBase/group/join/$inviteToken'),
                  headers: {'authorization': 'Bearer $userToken'},
                );
                Navigator.of(ctx).pop();
                final l = AppLocalizations(SettingsManager.appLocale.value);
                if (res.statusCode == 200) {
                  rootScreenKey.currentState?.showSnack(l.groupAddedForViewing);
                  _loadGroupsFromNetwork();
                } else {
                  rootScreenKey.currentState?.showSnack(
                    res.statusCode == 404 ? l.invalidInviteLink : l.failedAddGroup,
                  );
                }
              } catch (e) {
                final l = AppLocalizations(SettingsManager.appLocale.value);
                rootScreenKey.currentState?.showSnack(l.networkError);
              }
            },
            child: Text(AppLocalizations.of(ctx).view),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupConfirmation(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).leaveGroupTitle(group.isChannel)),
        content: Text(AppLocalizations.of(context).leaveGroupContent(group.name)),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _leaveGroup(group.id);
            },
            child: Text(
              AppLocalizations.of(context).leave,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveExternalServerConfirmation(BuildContext context, Group group) {
    final server = ExternalServerManager.servers.value
        .where((s) => s.id == group.externalServerId)
        .firstOrNull;
    final serverName = server?.name ?? 'Unknown Server';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).removeExternalServerTitle),
        content: Text(AppLocalizations.of(context).removeExternalServerContent(serverName)),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (group.externalServerId != null) {
                await ExternalServerManager.removeServer(group.externalServerId!);
                if (mounted) {
                  final l = AppLocalizations(SettingsManager.appLocale.value);
                  rootScreenKey.currentState?.showSnack(l.serverRemoved(serverName));
                  setState(() {});
                }
              }
            },
            child: Text(
              AppLocalizations.of(context).remove,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return FadeTransition(
      opacity: _screenVisible ? _screenFadeAnimation : const AlwaysStoppedAnimation(0.0),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_groups.isEmpty && ExternalServerManager.externalGroups.value.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: 0.4,
                          child: Icon(Icons.group_outlined, size: 48),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context).noGroupsYet,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        if (!_hasInternet)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              '(offline)',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  )
                
                : FadeTransition(
                    opacity: _listFadeAnim,
                    child: ValueListenableBuilder<List<Group>>(
                      valueListenable: ExternalServerManager.externalGroups,
                      builder: (context, extGroups, _) {
                        final allGroups = [..._groups, ...extGroups];
                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
                          itemCount: allGroups.length,
                          cacheExtent: 500,
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final g = allGroups[i];

                            String? avatarUrl;
                            if (g.isExternal) {
                              final server = ExternalServerManager.servers.value
                                  .where((s) => s.id == g.externalServerId)
                                  .firstOrNull;
                              if (server != null) {
                                avatarUrl = '${server.baseUrl}/groups/${g.id}/avatar?v=${g.avatarVersion}&sid=${server.id}';
                              }
                            } else {
                              avatarUrl = '$serverBase/group/${g.id}/avatar?v=${g.avatarVersion}';
                            }

                            return RepaintBoundary(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  if (g.isExternal) {
                                    if (isDesktop) {
                                      widget.onOpenGroup(g);
                                    } else {
                                      _openExternalGroup(g);
                                    }
                                  } else if (isDesktop) {
                                    rootScreenKey.currentState?.setState(() {
                                      rootScreenKey.currentState?.selectedGroup = g;
                                      rootScreenKey.currentState?.selectedChatOther = null;
                                    });
                                  } else {
                                    widget.onOpenGroup(g);
                                  }
                                },
                                onLongPress: () {
                                  if (g.isExternal) {
                                    _showRemoveExternalServerConfirmation(context, g);
                                  } else {
                                    _showLeaveGroupConfirmation(context, g);
                                  }
                                },
                                child: _glassCard(
                                  context: context,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          key: ValueKey('list_avatar_${g.externalServerId ?? 'native'}_${g.id}_${g.name}_${g.avatarVersion}'),
                                          radius: 20,
                                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                          child: avatarUrl == null
                                              ? Icon(
                                                  g.isExternal ? Icons.dns_outlined : Icons.group,
                                                  size: 20,
                                                  color: g.isExternal ? Colors.orange.shade700 : null,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                g.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              if (g.isExternal)
                                                ExternalServerBadge(isChannel: g.isChannel)
                                              else
                                                Text(
                                                  g.isChannel ? AppLocalizations.of(context).channelAdminOnlySubtitle : AppLocalizations.of(context).groupSubtitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: Icon(
                                            g.isChannel ? Icons.ondemand_video_outlined : Icons.group_outlined,
                                            size: 16,
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                    ),
                  ),
        floatingActionButton: !_loading
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 70,
                ),
                child: FloatingActionButton(
                  onPressed: () async {
                    final colorScheme = Theme.of(context).colorScheme;
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      useRootNavigator: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ValueListenableBuilder<double>(
                        valueListenable: SettingsManager.elementBrightness,
                        builder: (_, brightness, __) {
                          final sheetColor = SettingsManager.getElementColor(
                            colorScheme.surfaceContainerHighest,
                            brightness,
                          );
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
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ListTile(
                                    leading: Icon(Icons.add_circle_outline_rounded,
                                        color: colorScheme.primary),
                                    title: Text(AppLocalizations.of(ctx).createGroupOrChannel),
                                    onTap: () => Navigator.pop(ctx, 'create'),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.link_rounded,
                                        color: colorScheme.primary),
                                    title: Text(AppLocalizations.of(ctx).viewByToken),
                                    onTap: () => Navigator.pop(ctx, 'join'),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.dns_outlined,
                                        color: colorScheme.primary),
                                    title: Text(AppLocalizations.of(ctx).viewByIp),
                                    onTap: () => Navigator.pop(ctx, 'external'),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                    if (choice == 'create') {
                      _createGroup();
                    } else if (choice == 'join') {
                      _joinGroup();
                    } else if (choice == 'external') {
                      _joinExternalServer();
                    }
                  },
                  tooltip: AppLocalizations.of(context).newGroup,
                  child: const Icon(Icons.add),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}