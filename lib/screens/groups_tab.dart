// lib/screens/groups_tab.dart
import 'dart:async';
import 'dart:io';
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
import '../l10n/app_localizations.dart';
import '../managers/decoy_manager.dart';
import '../managers/decoy_data_manager.dart';
import '../widgets/adaptive_glass_card.dart';
import '../widgets/animated_reorder_list.dart';
import '../widgets/tab_pull_search.dart';
import '../widgets/inline_search_bar.dart';
import '../managers/lock_manager.dart';
import '../dialogs/pin_lock_dialog.dart';
import '../utils/onyx_base_dir.dart' show getOnyxSupportDirectory, getOnyxDocumentsDirectory;
import '../managers/trash_manager.dart';
import '../widgets/onyx_dialog.dart';
import '../dialogs/profile_presets_dialog.dart';

/// Reads and scans group-history JSON files for a content match — run via
/// `compute` so the (potentially large) `jsonDecode` doesn't block the UI
/// isolate and make the search field stutter while the user types.
/// Returns, per requested history file, up to 5 `{id, snippet}` matches —
/// `id` is the raw message id (matches `_scrollToGroupMessageById`'s lookup)
/// so a tapped search result can land the user directly on that message.
List<List<Map<String, String>>> _findGroupContentMatchesInBackground(Map<String, dynamic> params) {
  final paths = (params['paths'] as List).cast<String?>();
  final lowerQuery = params['lowerQuery'] as String;
  return paths.map((path) {
    final matches = <Map<String, String>>[];
    if (path == null) return matches;
    try {
      final file = File(path);
      if (!file.existsSync()) return matches;
      final data = jsonDecode(file.readAsStringSync());
      if (data is! List) return matches;
      for (var i = data.length - 1; i >= 0; i--) {
        final item = data[i];
        if (item is! Map) continue;
        final content = (item['content'] ?? '').toString();
        if (content.toLowerCase().contains(lowerQuery)) {
          final id = item['id']?.toString();
          if (id == null) continue;
          matches.add({
            'id': id,
            'snippet': content.length > 140 ? '${content.substring(0, 140)}…' : content,
          });
          if (matches.length >= 5) break;
        }
      }
    } catch (_) {
      // Cache file unreadable/corrupt — skip silently, name match still applies.
    }
    return matches;
  }).toList();
}

List<Group> _parseGroupsJsonInBackground(Map<String, String?> params) {
  final jsonBody = params['jsonBody'] ?? '[]';
  final currentUsername = params['currentUsername'];

  final decoded = jsonDecode(jsonBody);
  List<Group> groups = [];
  if (decoded is List) {
    groups = decoded.map<Group>((g) {
      final ownerUsername =
          g['owner'] ?? g['owner_id']?.toString() ?? 'unknown';

      final myRole =
          (currentUsername != null && ownerUsername == currentUsername)
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

class GroupsTab extends StatefulWidget {
  final Function(Group) onOpenGroup;
  const GroupsTab({super.key, required this.onOpenGroup});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Group> _groups = [];
  bool _loading = true;
  bool _hasInternet = true;
  String? _loadedUsername;

  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey _searchBarKey = GlobalKey();
  String _searchQuery = '';
  List<TabSearchResult> _searchResults = [];
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
    if (DecoyManager.isActive.value) {
      _loadDecoyGroups();
    } else {
      _loadGroupsFromCache().then((_) {
        _loadGroupsFromNetwork();
      });
    }

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
    ExternalServerManager.externalGroups
        .removeListener(_onExternalGroupsChanged);
    accountSwitchVersion.removeListener(_onAccountSwitch);
    _searchCtrl.dispose();
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
    if (DecoyManager.isActive.value) return;
    final username = rootScreenKey.currentState?.currentUsername ?? '';
    final cached = await AccountManager.loadGroupsCache(username);

    final fixedGroups = cached.map((g) {
      final shouldBeOwner = g.owner == username;
      final currentRole = g.myRole;

      if (currentRole == null ||
          (shouldBeOwner && currentRole != 'owner') ||
          (!shouldBeOwner && currentRole == 'owner')) {
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
      // Store cached groups as fallback but keep the loading spinner active —
      // the network fetch is the source of truth and will clear _loading once
      // it completes. Showing stale cache before the network confirms would
      // flash groups the user has already left (or recently joined on another
      // device) for ~1 second before the network corrects them.
      setState(() {
        _groups = fixedGroups;
        // _loading stays true; network success/failure clears it.
      });
    }
  }

  void _ensureLoadedForCurrentAccount() {
    if (DecoyManager.isActive.value) return;
    final username = rootScreenKey.currentState?.currentUsername ?? '';
    if (_loadedUsername == username) return;
    debugPrint(
        '[groups_tab] account changed: reloading groups for $username (was=$_loadedUsername)');
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

  void _loadDecoyGroups() {
    if (!mounted) return;
    setState(() {
      _groups = List.of(DecoyDataManager.fakeGroups);
      _loading = false;
    });
    if (_groups.isNotEmpty && !_listAnimController.isCompleted) {
      _listAnimController.forward();
    }
  }

  Future<void> _showAddGroupSheet() async {
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
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: Icon(
                      Icons.add_circle_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.of(ctx).createGroupOrChannel),
                    onTap: () => Navigator.pop(ctx, 'create'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.link_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.of(ctx).viewByToken),
                    onTap: () => Navigator.pop(ctx, 'join'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.dns_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.of(ctx).viewByIp),
                    onTap: () => Navigator.pop(ctx, 'external'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
  }

  Future<void> _loadGroupsFromNetwork() async {
    if (DecoyManager.isActive.value) return;
    final username = rootScreenKey.currentState?.currentUsername ?? '';

    final token = await AccountManager.getToken(username);
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if ((rootScreenKey.currentState?.currentUsername ?? '') != username) {
      debugPrint(
          '[groups_tab] account changed before HTTP fetch, aborting for $username');
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$serverBase/groups'),
        headers: {'authorization': 'Bearer $token'},
      );

      if ((rootScreenKey.currentState?.currentUsername ?? '') != username) {
        debugPrint(
            '[groups_tab] account changed after HTTP response, discarding results for $username');
        return;
      }

      if (res.statusCode == 200) {
        final groups = await compute(_parseGroupsJsonInBackground, {
          'jsonBody': res.body,
          'currentUsername': username,
        });

        if ((rootScreenKey.currentState?.currentUsername ?? '') != username) {
          debugPrint(
              '[groups_tab] account changed after parse, discarding results for $username');
          return;
        }

        await AccountManager.saveGroupsCache(username, groups);
        groupsCacheVersion.value++;

        if (mounted) {
          setState(() {
            _groups = groups;
            _loading = false;
            _hasInternet = true;
          });
          _listAnimController.forward();
        }
      } else {
        debugPrint(
            '[groups_tab] GET /groups failed: ${res.statusCode} ${res.body}');
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[groups_tab] Network error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasInternet = false;
        });
        // Network failed — fall back to whatever the cache loaded.
        if (_groups.isNotEmpty) _listAnimController.forward();
      }
    }
  }

  Future<void> _leaveGroup(Group group) async {
    final token = await AccountManager.getToken(
      rootScreenKey.currentState?.currentUsername ?? '',
    );
    if (token == null) return;
    try {
      final res = await http.post(
        Uri.parse('$serverBase/group/${group.id}/leave'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        TrashManager.instance.addDeletedChat(TrashedChat(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          chatId: 'group:${group.id}',
          displayName: group.name,
          type: TrashedChatType.group,
          messages: const [],
          deletedAt: DateTime.now(),
        ));
        if (mounted) {
          final l = lookupAppLocalizations(SettingsManager.appLocale.value);
          rootScreenKey.currentState?.showSnack(l.leftGroup);
          setState(() {
            _groups.removeWhere((g) => g.id == group.id);
          });
          if (isDesktop &&
              rootScreenKey.currentState?.selectedGroup?.id == group.id) {
            rootScreenKey.currentState?.hideDetailPanel();
          }
          _loadGroupsFromNetwork();
        }
      } else {
        if (mounted) {
          final l = lookupAppLocalizations(SettingsManager.appLocale.value);
          rootScreenKey.currentState?.showSnack(l.failedLeaveGroup);
        }
      }
    } catch (e) {
      if (mounted) {
        final l = lookupAppLocalizations(SettingsManager.appLocale.value);
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
    if (DecoyManager.isActive.value) {
      _loadDecoyGroups();
      return;
    }
    _loadGroupsFromCache().then((_) => _loadGroupsFromNetwork());
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

  void _openProfilePresets() {
    showOnyxDialog(
      context: context,
      builder: (_) => const ProfilePresetsDialog(),
    );
  }

  /// The top bar shown above the group list: a wide "+" pill to add a
  /// group/channel/external server, plus a compact button to the profile
  /// presets screen (saved username/password combos for external servers).
  Widget _buildTopActionsBar() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Row(
        children: [
          Expanded(
            child: AdaptiveGlassCard(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              onTap: _showAddGroupSheet,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.add,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AdaptiveGlassCard(
            borderRadius: 22,
            padding: EdgeInsets.zero,
            onTap: _openProfilePresets,
            child: Tooltip(
              message: AppLocalizations.of(context).profilePresets,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.badge_outlined,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    bool isChannel = false;
    const btnShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(50)));
    const btnPadding = EdgeInsets.symmetric(vertical: 13);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
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
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.group_add_rounded,
                                  size: 18, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(ctx).createGroupChannel,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cs.onSurface.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.close_rounded,
                                    size: 18,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.55)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ValueListenableBuilder<double>(
                              valueListenable: SettingsManager.elementBrightness,
                              builder: (_, brightness, __) {
                                final baseColor =
                                    SettingsManager.getElementColor(
                                  cs.surfaceContainerHighest,
                                  brightness,
                                );
                                return TextField(
                                  controller: nameController,
                                  autofocus: true,
                                  maxLines: 1,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText:
                                        AppLocalizations.of(ctx).groupNameLabel,
                                    hintText:
                                        AppLocalizations.of(ctx).groupNameHint,
                                    filled: true,
                                    fillColor: baseColor.withValues(alpha: 0.5),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(50)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide(
                                          color: cs.outlineVariant
                                              .withValues(alpha: 0.3),
                                          width: 0.8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide(
                                          color: cs.primary, width: 1.4),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 14, horizontal: 20),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              title:
                                  Text(AppLocalizations.of(ctx).channelAdminOnly),
                              controlAffinity: ListTileControlAffinity.leading,
                              value: isChannel,
                              onChanged: (bool? v) =>
                                  setDialogState(() => isChannel = v ?? false),
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: btnPadding,
                                shape: btnShape,
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;
                                final token = await AccountManager.getToken(
                                  rootScreenKey.currentState?.currentUsername ??
                                      '',
                                );
                                if (token == null) return;
                                final res = await http.post(
                                  Uri.parse('$serverBase/group/create'),
                                  headers: {
                                    'authorization': 'Bearer $token',
                                    'content-type': 'application/json',
                                  },
                                  body: jsonEncode(
                                      {'name': name, 'is_channel': isChannel}),
                                );
                                Navigator.pop(ctx);
                                if (res.statusCode == 200) {
                                  _loadGroupsFromNetwork();
                                } else {
                                  final l = lookupAppLocalizations(SettingsManager.appLocale.value);
                                  rootScreenKey.currentState
                                      ?.showSnack(l.failedCreateGroup);
                                }
                              },
                              child: Text(AppLocalizations.of(ctx).create),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _joinGroup() async {
    final tokenController = TextEditingController();
    const btnShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(50)));
    const btnPadding = EdgeInsets.symmetric(vertical: 13);
    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.link_rounded,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(ctx).viewByToken,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
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
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppLocalizations.of(ctx).pasteToken,
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<double>(
                            valueListenable: SettingsManager.elementBrightness,
                            builder: (_, brightness, __) {
                              final baseColor = SettingsManager.getElementColor(
                                cs.surfaceContainerHighest,
                                brightness,
                              );
                              return TextField(
                                controller: tokenController,
                                autofocus: true,
                                maxLines: 1,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: baseColor.withValues(alpha: 0.5),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(
                                        color: cs.outlineVariant
                                            .withValues(alpha: 0.3),
                                        width: 0.8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    borderSide: BorderSide(
                                        color: cs.primary, width: 1.4),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 20),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: btnPadding,
                              shape: btnShape,
                            ),
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
                                final l = lookupAppLocalizations(SettingsManager.appLocale.value);
                                rootScreenKey.currentState
                                    ?.showSnack(l.invalidInviteLinkFormat);
                                return;
                              }
                              final userToken = await AccountManager.getToken(
                                rootScreenKey.currentState?.currentUsername ??
                                    '',
                              );
                              if (userToken == null) {
                                Navigator.of(ctx).pop();
                                rootScreenKey.currentState?.showSnack(
                                    lookupAppLocalizations(SettingsManager.appLocale.value)
                                        .notLoggedIn);
                                return;
                              }
                              try {
                                final res = await http.post(
                                  Uri.parse(
                                      '$serverBase/group/join/$inviteToken'),
                                  headers: {
                                    'authorization': 'Bearer $userToken'
                                  },
                                );
                                Navigator.of(ctx).pop();
                                final l = lookupAppLocalizations(SettingsManager.appLocale.value);
                                if (res.statusCode == 200) {
                                  rootScreenKey.currentState
                                      ?.showSnack(l.groupAddedForViewing);
                                  _loadGroupsFromNetwork();
                                } else {
                                  rootScreenKey.currentState?.showSnack(
                                    res.statusCode == 404
                                        ? l.invalidInviteLink
                                        : l.failedAddGroup,
                                  );
                                }
                              } catch (e) {
                                final l = lookupAppLocalizations(SettingsManager.appLocale.value);
                                rootScreenKey.currentState
                                    ?.showSnack(l.networkError);
                              }
                            },
                            child: Text(AppLocalizations.of(ctx).view),
                          ),
                        ],
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
  }

  String _lockId(Group g) => g.isExternal
      ? 'eg_${g.externalServerId}_${g.id}'
      : 'ng_${g.id}';

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    if (trimmed == _searchQuery) return;
    if (trimmed.isEmpty) {
      setState(() { _searchQuery = ''; _searchResults = []; });
      return;
    }
    final results = await _searchGroups(trimmed);
    if (!mounted) return;
    setState(() { _searchQuery = trimmed; _searchResults = results; });
  }

  Future<List<TabSearchResult>> _searchGroups(String query) async {
    final lower = query.toLowerCase();
    final username = rootScreenKey.currentState?.currentUsername ?? '';
    final allGroups = [..._groups, ...ExternalServerManager.externalGroups.value];

    Widget Function(BuildContext, double) avatarBuilderFor(Group g) {
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
      return (context, size) => CircleAvatar(
            key: ValueKey('search_avatar_${g.isExternal ? (g.externalServerId ?? 'ext') : 'native'}_${g.id}_${g.avatarVersion}'),
            radius: size / 2,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(g.isExternal ? Icons.dns_outlined : Icons.group, size: size * 0.5,
                       color: g.isExternal ? Colors.orange.shade700 : null)
                : null,
          );
    }

    final nameHits = <TabSearchResult>[];
    final contentCandidates = <Group>[];
    for (final g in allGroups) {
      if (g.name.toLowerCase().contains(lower)) {
        nameHits.add(TabSearchResult(
          id: '${g.isExternal ? (g.externalServerId ?? 'ext') : 'native'}:${g.id}',
          title: g.name,
          subtitle: g.isChannel ? 'Канал' : 'Группа',
          icon: g.isChannel ? Icons.campaign_outlined : Icons.groups_outlined,
          avatarBuilder: avatarBuilderFor(g),
        ));
      } else {
        contentCandidates.add(g);
      }
    }

    if (query.trim().length < 2 || username.isEmpty) {
      return nameHits.take(30).toList();
    }

    // Resolve each candidate's history-file path up front (cheap, async dir
    // lookups), then hand the actual read+decode+scan to a background isolate
    // in one shot — `jsonDecode`-ing potentially large history files on the
    // UI isolate is what made the search field stutter while typing.
    final paths = <String?>[];
    for (final g in contentCandidates) {
      try {
        final dir = g.isExternal
            ? await getOnyxDocumentsDirectory()
            : await getOnyxSupportDirectory();
        final file = g.isExternal
            ? File('${dir.path}/ext_group_${g.externalServerId}_${g.id}_history.json')
            : File('${dir.path}/group_${username}_${g.id}_history.json');
        paths.add(file.path);
      } catch (_) {
        paths.add(null);
      }
    }

    final matchLists = contentCandidates.isEmpty
        ? const <List<Map<String, String>>>[]
        : await compute(_findGroupContentMatchesInBackground, {
            'paths': paths,
            'lowerQuery': lower,
          });

    // One card per matching message — chats are intentionally not deduped,
    // so a chat with several hits shows up as several separate cards.
    final contentHits = <TabSearchResult>[];
    outer:
    for (var i = 0; i < matchLists.length; i++) {
      final g = contentCandidates[i];
      final groupKey = '${g.isExternal ? (g.externalServerId ?? 'ext') : 'native'}:${g.id}';
      final avatarBuilder = avatarBuilderFor(g);
      for (var j = 0; j < matchLists[i].length; j++) {
        final match = matchLists[i][j];
        contentHits.add(TabSearchResult(
          id: '$groupKey#$j',
          title: g.name,
          subtitle: g.isChannel ? 'Канал' : 'Группа',
          snippet: match['snippet'],
          icon: Icons.forum_outlined,
          avatarBuilder: avatarBuilder,
          messageId: match['id'],
        ));
        if (nameHits.length + contentHits.length >= 30) break outer;
      }
    }

    return [...nameHits, ...contentHits].take(30).toList();
  }

  void _onSearchResultTap(TabSearchResult result) {
    _searchCtrl.clear();
    setState(() { _searchQuery = ''; _searchResults = []; });
    // Content-match cards carry a "#<index>" suffix to stay unique per
    // matching message — strip it before resolving the underlying group id.
    final rawId = result.id.split('#').first;
    final parts = rawId.split(':');
    if (parts.length != 2) return;
    final scope = parts[0];
    final id = int.tryParse(parts[1]);
    if (id == null) return;
    final allGroups = [..._groups, ...ExternalServerManager.externalGroups.value];
    final g = allGroups.where((g) =>
        '${g.isExternal ? (g.externalServerId ?? 'ext') : 'native'}:${g.id}' ==
        '$scope:$id').firstOrNull;
    if (g == null) return;
    if (result.messageId != null) {
      // Only GroupChatScreen (native groups) currently consumes this — it's
      // harmless to set for external groups too, just never picked up.
      setPendingMessageScrollTarget('$scope:$id', result.messageId!);
    }
    _openGroupWithLockCheck(context, g);
  }

  Future<void> _openGroupWithLockCheck(BuildContext ctx, Group g) async {
    final lockId = _lockId(g);
    if (!LockManager.isLocked(lockId)) {
      _doOpenGroup(ctx, g);
      return;
    }
    final ok = await showPinDialog(ctx, PinDialogMode.verify, lockId);
    if (ok && mounted) {
      _doOpenGroup(ctx, g);
    }
  }

  void _doOpenGroup(BuildContext ctx, Group g) {
    if (g.isExternal) {
      // Route through the same onOpenGroup callback as internal groups
      // (root_screen.dart) instead of pushing our own MaterialPageRoute —
      // that callback already uses root_screen's shared _chatRoute slide
      // transition for external groups too, so both take the identical
      // entrance animation instead of external falling back to the
      // platform-default push.
      widget.onOpenGroup(g);
    } else if (isDesktop) {
      rootScreenKey.currentState?.setState(() {
        rootScreenKey.currentState?.selectedGroup = g;
        rootScreenKey.currentState?.selectedChatOther = null;
      });
    } else {
      widget.onOpenGroup(g);
    }
  }

  void _showGroupActionsSheet(BuildContext context, Group g) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementBrightness,
        builder: (_, brightness, __) {
          final sheetColor = SettingsManager.getElementColor(
              colorScheme.surfaceContainerHighest, brightness);
          return ValueListenableBuilder<Set<String>>(
            valueListenable: LockManager.lockedChats,
            builder: (_, locked, __) {
              final lockId = _lockId(g);
              final isLocked = locked.contains(lockId);
              return SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: sheetColor,
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
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ListTile(
                        leading: Icon(
                          isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                          color: colorScheme.onSurface,
                        ),
                        title: Text(isLocked ? 'Unlock' : 'Lock'),
                        onTap: () async {
                          Navigator.of(sheetCtx).pop();
                          if (isLocked) {
                            final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
                            if (ok) await LockManager.removeLock(lockId);
                          } else {
                            final set = await showPinDialog(context, PinDialogMode.set, lockId);
                            if (!set) return;
                            await LockManager.lock(lockId);
                          }
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline, color: colorScheme.error),
                        title: Text(g.isExternal ? 'Remove server' : 'Leave group'),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          if (g.isExternal) {
                            _showRemoveExternalServerConfirmation(context, g);
                          } else {
                            _showLeaveGroupConfirmation(context, g);
                          }
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showGroupDesktopContextMenu(
      BuildContext context, Offset globalPosition, Group g) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLocked = LockManager.isLocked(_lockId(g));
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx, globalPosition.dy,
        globalPosition.dx, globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: isLocked ? 'unlock' : 'lock',
          child: Row(children: [
            Icon(isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 10),
            Text(isLocked ? 'Unlock' : 'Lock'),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
            const SizedBox(width: 10),
            Text(g.isExternal ? 'Remove server' : 'Leave group',
                style: TextStyle(color: colorScheme.error)),
          ]),
        ),
      ],
    ).then((value) async {
      if (!context.mounted) return;
      final lockId = _lockId(g);
      if (value == 'lock') {
        final set = await showPinDialog(context, PinDialogMode.set, lockId);
        if (!set) return;
        await LockManager.lock(lockId);
      } else if (value == 'unlock') {
        final ok = await showPinDialog(context, PinDialogMode.verify, lockId);
        if (ok) await LockManager.removeLock(lockId);
      } else if (value == 'delete') {
        if (g.isExternal) {
          _showRemoveExternalServerConfirmation(context, g);
        } else {
          _showLeaveGroupConfirmation(context, g);
        }
      }
    });
  }

  void _showLeaveGroupConfirmation(BuildContext context, Group group) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.leaveGroupTitle(group.isChannel.toString()),
      message: l.leaveGroupContent(group.name),
      confirmLabel: l.leave,
      isDestructive: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed == true) {
      LockManager.removeLock('ng_${group.id}');
      _leaveGroup(group);
    }
  }

  void _showRemoveExternalServerConfirmation(
      BuildContext context, Group group) async {
    final server = ExternalServerManager.servers.value
        .where((s) => s.id == group.externalServerId)
        .firstOrNull;
    final serverName = server?.name ?? 'Unknown Server';

    final l = AppLocalizations.of(context);
    final confirmed = await showOnyxConfirmDialog(
      context: context,
      title: l.removeExternalServerTitle,
      message: l.removeExternalServerContent(serverName),
      confirmLabel: l.remove,
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      if (group.externalServerId != null) {
        for (final g in _groups.where(
            (g) => g.externalServerId == group.externalServerId)) {
          LockManager.removeLock('eg_${g.externalServerId}_${g.id}');
        }
        await ExternalServerManager.removeServer(
            group.externalServerId!);
        if (mounted) {
          final l2 = lookupAppLocalizations(SettingsManager.appLocale.value);
          rootScreenKey.currentState
              ?.showSnack(l2.serverRemoved(serverName));
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FadeTransition(
      opacity: _screenVisible
          ? _screenFadeAnimation
          : const AlwaysStoppedAnimation(0.0),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The host root_screen Scaffold already resizes for the keyboard;
        // letting this nested one do it too double-shrinks the tab's content
        // and is exactly what made the search panel/list area get squashed
        // and overlapped by the chat-background layer behind it once the
        // IME opened.
        resizeToAvoidBottomInset: false,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_groups.isEmpty &&
                    ExternalServerManager.externalGroups.value.isEmpty)
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: _buildTopActionsBar(),
                      ),
                      Expanded(
                        child: Center(
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
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              if (!_hasInternet)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '(offline)',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : FadeTransition(
                    opacity: _listFadeAnim,
                    child: ValueListenableBuilder<List<Group>>(
                      valueListenable: ExternalServerManager.externalGroups,
                      builder: (context, extGroups, _) {
                        final allGroups = [..._groups, ...extGroups];
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: _buildTopActionsBar(),
                            ),
                            Expanded(
                              child: Builder(builder: (context) {
                              final cs = Theme.of(context).colorScheme;
                              final bottomPad = 8 + MediaQuery.paddingOf(context).bottom;
                              final searchBar = InlineSearchBar(
                                key: _searchBarKey,
                                controller: _searchCtrl,
                                onChanged: _onSearchChanged,
                                hintText: AppLocalizations.of(context).searchGroupsHint,
                                hasText: _searchQuery.isNotEmpty,
                              );
                              if (_searchQuery.isNotEmpty) {
                                return CustomScrollView(
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  slivers: [
                                    SliverToBoxAdapter(child: searchBar),
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad),
                                      sliver: SliverList.builder(
                                        itemCount: _searchResults.length,
                                        itemBuilder: (ctx, i) {
                                          final r = _searchResults[i];
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: GestureDetector(
                                              onTap: () => _onSearchResultTap(r),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(28),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                child: Row(
                                                  children: [
                                                    r.avatarBuilder?.call(ctx, 40) ??
                                                        CircleAvatar(
                                                          radius: 20,
                                                          backgroundColor: cs.primary.withValues(alpha: 0.15),
                                                          child: Icon(r.icon, size: 18, color: cs.primary),
                                                        ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                          if (r.snippet != null)
                                                            Text(r.snippet!, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return AnimatedReorderList<Group>(
                                items: allGroups,
                                keyOf: (g) =>
                                    '${g.isExternal ? (g.externalServerId ?? 'ext') : 'native'}:${g.id}',
                                header: searchBar,
                                padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad),
                                physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics()),
                                separatorHeight: 6,
                                itemBuilder: (context, g, i) {

                            String? avatarUrl;
                            if (g.isExternal) {
                              final server = ExternalServerManager.servers.value
                                  .where((s) => s.id == g.externalServerId)
                                  .firstOrNull;
                              if (server != null) {
                                avatarUrl =
                                    '${server.baseUrl}/groups/${g.id}/avatar?v=${g.avatarVersion}&sid=${server.id}';
                              }
                            } else {
                              avatarUrl =
                                  '$serverBase/group/${g.id}/avatar?v=${g.avatarVersion}';
                            }

                            return RepaintBoundary(
                              child: GestureDetector(
                                onSecondaryTapUp: isDesktop
                                    ? (d) => _showGroupDesktopContextMenu(context, d.globalPosition, g)
                                    : null,
                                child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => _openGroupWithLockCheck(context, g),
                                onLongPress: () => _showGroupActionsSheet(context, g),
                                child: AdaptiveGlassCard(
                                  borderRadius: 28,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          key: ValueKey(
                                              'list_avatar_${g.externalServerId ?? 'native'}_${g.id}_${g.name}_${g.avatarVersion}'),
                                          radius: 20,
                                          backgroundImage: avatarUrl != null
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: avatarUrl == null
                                              ? Icon(
                                                  g.isExternal
                                                      ? Icons.dns_outlined
                                                      : Icons.group,
                                                  size: 20,
                                                  color: g.isExternal
                                                      ? Colors.orange.shade700
                                                      : null,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      g.name,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                        fontSize: 15,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (g.inviteLink ==
                                                      '12e01467-c154-447b-84f8-133ae76684a1')
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 4),
                                                      child: Icon(
                                                          Icons
                                                              .verified_rounded,
                                                          size: 15,
                                                          color: Colors
                                                              .blue.shade400),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              if (g.isExternal)
                                                ExternalServerBadge(
                                                    isChannel: g.isChannel)
                                              else
                                                Text(
                                                  g.isChannel
                                                      ? AppLocalizations.of(
                                                              context)
                                                          .channelAdminOnlySubtitle
                                                      : AppLocalizations.of(
                                                              context)
                                                          .groupSubtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.7),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        ValueListenableBuilder<Set<String>>(
                                          valueListenable: LockManager.lockedChats,
                                          builder: (_, locked, __) {
                                            final isLocked = locked.contains(_lockId(g));
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Icon(
                                                  g.isChannel
                                                      ? Icons.campaign_outlined
                                                      : Icons.group_outlined,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                                if (isLocked)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Icon(
                                                      Icons.lock_rounded,
                                                      size: 14,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                              ],
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
                                },
                              );
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
