// lib/widgets/account_graph_view.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../managers/account_manager.dart';
import '../managers/decoy_data_manager.dart';
import '../managers/decoy_manager.dart';
import '../managers/external_server_manager.dart';
import '../managers/lock_manager.dart';
import '../managers/settings_manager.dart';
import '../managers/unread_manager.dart';
import '../models/chat_message.dart';
import '../models/fav_folder.dart';
import '../models/favorite_chat.dart';
import '../models/group.dart';
import '../services/profile_store.dart';

// ─────────────────────── enum ───────────────────────────────────────────────

enum _CatType { chats, groups, channels, favorites, external, favFolder }

// ─────────────────────── helpers ────────────────────────────────────────────

String _peerFromKey(String key, String myUsername) {
  if (!key.contains(':')) return key;
  final parts = key.split(':');
  for (final part in parts) {
    if (part.toLowerCase() != myUsername.toLowerCase()) return part;
  }
  return key;
}

// ─────────────────────── orbit models ───────────────────────────────────────

class _ItemOrbit {
  final String id;
  final String label;
  final _CatType catType;
  final double radius; // unique per item — no two items share a radius
  final double basePhase;
  final double speed; // rad/s, positive = CCW
  final int msgCount;
  final bool hasUnread;
  final VoidCallback? onTap;
  final String? avatarKey;
  final List<_ItemOrbit> children; // non-empty for folder items

  const _ItemOrbit({
    required this.id,
    required this.label,
    required this.catType,
    required this.radius,
    required this.basePhase,
    required this.speed,
    required this.msgCount,
    required this.hasUnread,
    this.onTap,
    this.avatarKey,
    this.children = const [],
  });

  Offset posAt(Offset catCenter, double elapsed) {
    final angle = basePhase + speed * elapsed;
    return catCenter +
        Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }
}

class _CatOrbit {
  final String id;
  final _CatType catType;
  final double radius;
  final double basePhase;
  final double speed; // rad/s, negative = CW
  final List<_ItemOrbit> items;
  final String? name;       // display label override (used for folder names)
  final String? avatarKey;  // key into avatars map for cat-node avatar

  const _CatOrbit({
    required this.id,
    required this.catType,
    required this.radius,
    required this.basePhase,
    required this.speed,
    required this.items,
    this.name,
    this.avatarKey,
  });

  Offset posAt(Offset origin, double elapsed) {
    final angle = basePhase + speed * elapsed;
    return origin + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  String get label => name ?? switch (catType) {
        _CatType.chats => 'Chats',
        _CatType.groups => 'Groups',
        _CatType.channels => 'Channels',
        _CatType.favorites => 'Favorites',
        _CatType.external => 'External',
        _CatType.favFolder => 'Folder',
      };

  IconData get icon => switch (catType) {
        _CatType.chats => Icons.chat_bubble_outline_rounded,
        _CatType.groups => Icons.group_outlined,
        _CatType.channels => Icons.campaign_outlined,
        _CatType.favorites => Icons.bookmarks_outlined,
        _CatType.external => Icons.public_outlined,
        _CatType.favFolder => Icons.folder_outlined,
      };
}

// ─────────────────────── painter ────────────────────────────────────────────

class _GraphPainter extends CustomPainter {
  // orbitElapsed controls orbital positions; pauses when animation is off.
  // liveElapsed always advances — controls dot rings, online glow, account glow.
  final ValueNotifier<double> orbitElapsed;
  final ValueNotifier<double> liveElapsed;

  final Offset origin;
  final String myUsername;
  final String myDisplayName;
  final List<_CatOrbit> categories;
  final Map<String, ui.Image> avatars;
  final Set<String> onlineUsers;
  final ColorScheme colors;
  final bool skipHeavyEffects;

  static const _acctR = 36.0;
  static const _catR = 26.0;
  static const _itemR = 18.0;

  _GraphPainter({
    required this.orbitElapsed,
    required this.liveElapsed,
    required this.origin,
    required this.myUsername,
    required this.myDisplayName,
    required this.categories,
    required this.avatars,
    required this.onlineUsers,
    required this.colors,
    required this.skipHeavyEffects,
  }) : super(repaint: Listenable.merge([orbitElapsed, liveElapsed]));

  @override
  void paint(Canvas canvas, Size size) {
    final t = orbitElapsed.value; // orbital positions
    final lt = liveElapsed.value; // live effects: dots, glow, pulse

    final p = Paint();

    // faint orbit guide rings for categories
    p
      ..style = PaintingStyle.stroke
      ..color = colors.onSurface.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    for (final cat in categories) {
      canvas.drawCircle(origin, cat.radius, p);
    }

    final catPos = <String, Offset>{
      for (final cat in categories) cat.id: cat.posAt(origin, t),
    };

    // edges: origin → category
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = colors.primary.withValues(alpha: 0.22);
    for (final cat in categories) {
      canvas.drawLine(origin, catPos[cat.id]!, p);
    }

    // item orbit rings + category → item edges
    for (final cat in categories) {
      final cp = catPos[cat.id]!;
      for (final item in cat.items) {
        p
          ..style = PaintingStyle.stroke
          ..color = colors.onSurface.withValues(alpha: 0.04)
          ..strokeWidth = 1.0;
        canvas.drawCircle(cp, item.radius, p);
        p.color = colors.secondary.withValues(alpha: 0.18);
        canvas.drawLine(cp, item.posAt(cp, t), p);
      }
    }

    // child (folder-chat) orbit rings + folder → child edges
    for (final cat in categories) {
      final cp = catPos[cat.id]!;
      for (final item in cat.items) {
        if (item.children.isEmpty) continue;
        final ip = item.posAt(cp, t);
        for (final child in item.children) {
          p
            ..style = PaintingStyle.stroke
            ..color = colors.onSurface.withValues(alpha: 0.035)
            ..strokeWidth = 0.8;
          canvas.drawCircle(ip, child.radius, p);
          p.color = colors.tertiary.withValues(alpha: 0.14);
          canvas.drawLine(ip, child.posAt(ip, t), p);
        }
      }
    }

    // category nodes
    for (final cat in categories) {
      _drawCat(canvas, catPos[cat.id]!, cat);
    }

    // item nodes (folder items drawn with ring indicator)
    for (final cat in categories) {
      final cp = catPos[cat.id]!;
      for (final item in cat.items) {
        final ip = item.posAt(cp, t);
        final isOnline =
            item.catType == _CatType.chats && onlineUsers.contains(item.label);
        _drawItem(canvas, ip, item, lt, isOnline);
      }
    }

    // child nodes orbiting their folder items
    for (final cat in categories) {
      final cp = catPos[cat.id]!;
      for (final item in cat.items) {
        if (item.children.isEmpty) continue;
        final ip = item.posAt(cp, t);
        for (final child in item.children) {
          _drawItem(canvas, child.posAt(ip, t), child, lt, false);
        }
      }
    }

    // account node on top
    _drawAccount(canvas, origin, lt);
  }

  // ── account ───────────────────────────────────────────────────────────────

  void _drawAccount(Canvas canvas, Offset pos, double lt) {
    const r = _acctR;
    final p = Paint();

    final glow = 0.18 + 0.07 * math.sin(lt * 0.9);
    if (!skipHeavyEffects) {
      p
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 16)
        ..color = colors.primary.withValues(alpha: glow);
      canvas.drawCircle(pos, r + 10, p);
      p.maskFilter = null;
    }

    p
      ..style = PaintingStyle.fill
      ..color = colors.surface;
    canvas.drawCircle(pos, r, p);

    final img = avatars[myUsername];
    if (img != null) {
      _clipAvatar(canvas, pos, r - 1, img);
    } else {
      p.color = colors.primaryContainer;
      canvas.drawCircle(pos, r, p);
      _paintInitial(
          canvas, pos, myDisplayName, r * 0.60, colors.onPrimaryContainer,
          bold: true);
    }

    p
      ..style = PaintingStyle.stroke
      ..color = colors.primary.withValues(alpha: 0.78)
      ..strokeWidth = 2.2;
    canvas.drawCircle(pos, r, p);

    _paintLabel(canvas, Offset(pos.dx, pos.dy + r + 14), myDisplayName,
        colors.onSurface,
        bold: true);
  }

  // ── category ──────────────────────────────────────────────────────────────

  void _drawCat(Canvas canvas, Offset pos, _CatOrbit cat) {
    const r = _catR;
    final p = Paint();

    final isFolder = cat.catType == _CatType.favFolder;
    final bgColor =
        isFolder ? colors.tertiaryContainer : colors.secondaryContainer;
    final fgColor = isFolder
        ? colors.onTertiaryContainer
        : colors.onSecondaryContainer;
    final borderColor =
        isFolder ? colors.tertiary : colors.secondary;

    p
      ..style = PaintingStyle.fill
      ..color = bgColor.withValues(alpha: 0.28);
    canvas.drawCircle(pos, r + 3, p);
    p.color = bgColor;
    canvas.drawCircle(pos, r, p);

    final img = cat.avatarKey != null ? avatars[cat.avatarKey] : null;
    if (img != null) {
      _clipAvatar(canvas, pos, r - 1, img);
    } else {
      _paintIcon(canvas, pos, cat.icon, r * 0.88, fgColor);
    }

    p
      ..style = PaintingStyle.stroke
      ..color = borderColor.withValues(alpha: 0.50)
      ..strokeWidth = 1.6;
    canvas.drawCircle(pos, r, p);

    _paintLabel(canvas, Offset(pos.dx, pos.dy + r + 12), cat.label,
        colors.onSurface.withValues(alpha: 0.82));
  }

  // ── item ──────────────────────────────────────────────────────────────────

  void _drawItem(
      Canvas canvas, Offset pos, _ItemOrbit item, double lt, bool isOnline) {
    const r = _itemR;
    final p = Paint();

    // online glow emanates from behind the node — drawn first
    if (isOnline) _drawOnlineGlow(canvas, pos, r, lt);

    // folder mini-planet indicator: faint ring showing it has child orbits
    if (item.children.isNotEmpty) {
      p
        ..style = PaintingStyle.stroke
        ..color = colors.tertiary.withValues(alpha: 0.38)
        ..strokeWidth = 1.4;
      canvas.drawCircle(pos, r + 5, p);
    }

    final bg = switch (item.catType) {
      _CatType.chats => colors.surfaceContainerHighest,
      _CatType.groups => colors.tertiaryContainer,
      _CatType.channels => colors.primaryContainer,
      _CatType.favorites || _CatType.favFolder => colors.secondaryContainer,
      _CatType.external => colors.surfaceContainer,
    };
    final fg = switch (item.catType) {
      _CatType.chats => colors.onSurfaceVariant,
      _CatType.groups => colors.onTertiaryContainer,
      _CatType.channels => colors.onPrimaryContainer,
      _CatType.favorites || _CatType.favFolder => colors.onSecondaryContainer,
      _CatType.external => colors.onSurface,
    };

    p
      ..style = PaintingStyle.fill
      ..color = bg;
    canvas.drawCircle(pos, r, p);

    final img = avatars[item.avatarKey ?? item.id];
    if (img != null) {
      _clipAvatar(canvas, pos, r - 1, img);
    } else {
      _paintInitial(canvas, pos, item.label, r * 0.68, fg);
    }

    // border: green when online, red when unread, default otherwise
    p
      ..style = PaintingStyle.stroke
      ..color = isOnline
          ? const Color(0xFF2ECC71).withValues(alpha: 0.85)
          : item.hasUnread
              ? colors.error.withValues(alpha: 0.75)
              : colors.outline.withValues(alpha: 0.30)
      ..strokeWidth = (isOnline || item.hasUnread) ? 1.8 : 1.2;
    canvas.drawCircle(pos, r, p);

    if (item.hasUnread && !isOnline) {
      final dot = pos + Offset(r * 0.70, -r * 0.70);
      p
        ..style = PaintingStyle.fill
        ..color = colors.error;
      canvas.drawCircle(dot, 4.5, p);
      p
        ..style = PaintingStyle.stroke
        ..color = colors.surface
        ..strokeWidth = 1.5;
      canvas.drawCircle(dot, 4.5, p);
    }

    _paintLabel(canvas, Offset(pos.dx, pos.dy + r + 10), item.label,
        colors.onSurface.withValues(alpha: 0.72),
        fontSize: 10.5);

    // dot ring always uses liveElapsed — animates even when orbits are frozen
    if (item.msgCount > 0) _drawDotRing(canvas, pos, item.msgCount, lt);
  }

  // Three concentric glowing rings emanating from the node border — no dot
  void _drawOnlineGlow(Canvas canvas, Offset pos, double r, double lt) {
    final pulse = 0.45 + 0.45 * math.sin(lt * (math.pi / 3) + pos.dx * 0.002);
    final p = Paint()..style = PaintingStyle.stroke;

    p
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.55 * pulse)
      ..strokeWidth = 2.5;
    canvas.drawCircle(pos, r + 3, p);

    if (skipHeavyEffects) return; // skip outer rings on mobile

    p
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.28 * pulse)
      ..strokeWidth = 4.0;
    canvas.drawCircle(pos, r + 7, p);

    p
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.12 * pulse)
      ..strokeWidth = 5.0;
    canvas.drawCircle(pos, r + 13, p);
  }

  // Dot ring uses liveElapsed (lt) so it keeps spinning even when orbits freeze
  void _drawDotRing(Canvas canvas, Offset center, int msgCount, double lt) {
    final count = math.min(msgCount, 16);
    const ringR = 27.0;
    final rotation = lt * 0.38;
    final p = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < count; i++) {
      final angle = rotation + i * (2 * math.pi / count);
      final pos =
          center + Offset(math.cos(angle) * ringR, math.sin(angle) * ringR);
      final fade =
          (0.45 + 0.45 * math.sin(lt * 1.7 + i * 0.95)).clamp(0.0, 1.0);
      p.color = colors.primary.withValues(alpha: fade);
      canvas.drawCircle(pos, 2.0, p);
    }
  }

  // ── drawing utilities ─────────────────────────────────────────────────────

  void _clipAvatar(Canvas canvas, Offset center, double radius, ui.Image img) {
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(
        img, src, Rect.fromCircle(center: center, radius: radius), Paint());
    canvas.restore();
  }

  void _paintInitial(
      Canvas canvas, Offset center, String text, double sz, Color color,
      {bool bold = false}) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text[0].toUpperCase(),
        style: TextStyle(
            fontSize: sz,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintLabel(Canvas canvas, Offset pos, String text, Color color,
      {double fontSize = 11.5, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 92);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy));
  }

  void _paintIcon(
      Canvas canvas, Offset center, IconData icon, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
            fontSize: size,
            color: color,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}

// ─────────────────────── widget ─────────────────────────────────────────────

class AccountGraphView extends StatefulWidget {
  final void Function(String username)? onChatTap;
  final void Function(Group group)? onGroupTap;
  final void Function(Group group)? onExternalGroupTap;
  final void Function(String favId)? onFavoriteTap;

  const AccountGraphView({
    super.key,
    this.onChatTap,
    this.onGroupTap,
    this.onExternalGroupTap,
    this.onFavoriteTap,
  });

  @override
  State<AccountGraphView> createState() => _AccountGraphViewState();
}

class _AccountGraphViewState extends State<AccountGraphView>
    with SingleTickerProviderStateMixin {
  static const double _canvas = 5000.0;
  static const Offset _origin = Offset(_canvas / 2, _canvas / 2);

  // persisted across mounts so view doesn't reset when returning from a chat
  static double _savedOrbitElapsed = 0.0;
  static double _savedLiveElapsed = 0.0;
  static Matrix4? _savedTransform;

  // avatar byte cache — survives widget dispose so remounts don't re-fetch
  static final Map<String, Uint8List> _cachedBytes = {};

  // ticker always runs; orbitElapsed pauses when animation is off
  late final Ticker _ticker;
  final ValueNotifier<double> _orbitElapsed = ValueNotifier(0.0);
  final ValueNotifier<double> _liveElapsed = ValueNotifier(0.0);
  Duration _lastTick = Duration.zero;
  int _frameSkip = 0;
  double _pendingDt = 0.0;

  late final TransformationController _tx;

  List<_CatOrbit> _categories = [];
  List<Group> _groups = [];
  String _myUsername = '';
  String _myDisplayName = '';

  String? _token;
  final Map<String, ui.Image> _avatars = {};
  final Map<String, bool> _loadingAvatar = {};
  final Set<String> _missingAvatarKeys = {};
  final Map<String, String> _favAvatarPaths =
      {}; // 'fav_{id}' → local file path
  Set<String> _onlineUsers = {};
  bool _isHoveringItem = false;
  bool _avatarWarmupScheduled = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // seed online set immediately so it's correct before first notifier event
    _onlineUsers = Set.of(onlineUsersNotifier.value);
    _ticker = createTicker(_onTick);
    _tx = TransformationController();

    // restore saved state if setting is on
    if (SettingsManager.graphPreservePosition.value) {
      if (_savedOrbitElapsed > 0) _orbitElapsed.value = _savedOrbitElapsed;
      if (_savedLiveElapsed > 0) _liveElapsed.value = _savedLiveElapsed;
    }

    groupsVersion.addListener(_onGroupsChanged);
    groupsCacheVersion.addListener(_onGroupsChanged);
    chatsVersion.addListener(_scheduleRebuild);
    favoritesVersion.addListener(_onFavoritesChanged);
    accountSwitchVersion.addListener(_onAccountSwitch);
    avatarVersion.addListener(_onAvatarChanged);
    groupAvatarVersion.addListener(_onAvatarChanged);
    onlineUsersNotifier.addListener(_onOnlineChanged);
    SettingsManager.graphOrbitSpeed.addListener(_scheduleRebuild);
    ExternalServerManager.externalGroups.addListener(_scheduleRebuild);
    LockManager.lockedChats.addListener(_scheduleRebuild);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preserve = SettingsManager.graphPreservePosition.value;
      if (preserve && _savedTransform != null) {
        _tx.value = _savedTransform!.clone();
      } else {
        _centerView();
      }
      _loadData();
      _ticker.start(); // ticker always runs
      // re-center after data loads so targetR reflects real category radii
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          _rebuildGraph();
          if (!SettingsManager.graphPreservePosition.value) _centerView();
        }
      });
    });
  }

  @override
  void dispose() {
    if (SettingsManager.graphPreservePosition.value) {
      _savedOrbitElapsed = _orbitElapsed.value;
      _savedLiveElapsed = _liveElapsed.value;
      _savedTransform = _tx.value.clone();
    }

    _ticker.dispose();
    _orbitElapsed.dispose();
    _liveElapsed.dispose();
    _tx.dispose();
    _debounce?.cancel();

    groupsVersion.removeListener(_onGroupsChanged);
    groupsCacheVersion.removeListener(_onGroupsChanged);
    chatsVersion.removeListener(_scheduleRebuild);
    favoritesVersion.removeListener(_onFavoritesChanged);
    accountSwitchVersion.removeListener(_onAccountSwitch);
    avatarVersion.removeListener(_onAvatarChanged);
    groupAvatarVersion.removeListener(_onAvatarChanged);
    onlineUsersNotifier.removeListener(_onOnlineChanged);
    SettingsManager.graphOrbitSpeed.removeListener(_scheduleRebuild);
    ExternalServerManager.externalGroups.removeListener(_scheduleRebuild);
    LockManager.lockedChats.removeListener(_scheduleRebuild);

    for (final img in _avatars.values) {
      img.dispose();
    }
    super.dispose();
  }

  // ── ticker — always running ───────────────────────────────────────────────

  void _onTick(Duration ts) {
    if (_lastTick == Duration.zero) {
      _lastTick = ts;
      return;
    }
    final rawDt = (ts - _lastTick).inMicroseconds / 1e6;
    _lastTick = ts;
    // clamp prevents a large jump after the widget was offscreen/paused
    final dt = rawDt.clamp(0.0, 0.05);

    if (!isDesktop) {
      // throttle to ~30 fps on mobile by processing every other frame
      _pendingDt += dt;
      _frameSkip++;
      if (_frameSkip % 2 != 0) return;
      final effectiveDt = _pendingDt;
      _pendingDt = 0.0;
      _liveElapsed.value += effectiveDt;
      if (SettingsManager.graphAnimation.value) {
        _orbitElapsed.value += effectiveDt;
      }
      return;
    }

    _liveElapsed.value += dt;
    if (SettingsManager.graphAnimation.value) {
      _orbitElapsed.value += dt;
    }
  }

  // ── listeners ─────────────────────────────────────────────────────────────

  void _onGroupsChanged() => _loadGroups();
  void _onAccountSwitch() => _loadData();

  void _onFavoritesChanged() {
    // clear cached favorite avatars so new avatarPath is picked up immediately
    for (final key in _favAvatarPaths.keys) {
      _avatars.remove(key)?.dispose();
      _loadingAvatar.remove(key);
      _missingAvatarKeys.remove(key);
      _cachedBytes.remove(key);
    }
    _scheduleRebuild();
  }

  void _onAvatarChanged() {
    _token = null;
    for (final img in _avatars.values) {
      img.dispose();
    }
    _avatars.clear();
    _loadingAvatar.clear();
    _missingAvatarKeys.clear();
    _cachedBytes.clear();
    _loadData();
  }

  void _onOnlineChanged() {
    if (mounted) {
      setState(() => _onlineUsers = Set.of(onlineUsersNotifier.value));
    }
  }

  void _scheduleRebuild() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _rebuildGraph();
    });
  }

  // ── data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final token = await avatarTokenProvider();
    if (!mounted) return;
    _token = token;
    await _loadGroups();
  }

  Future<void> _loadGroups() async {
    final username = rootScreenKey.currentState?.currentUsername ?? '';
    if (username.isEmpty) return;
    final groups = DecoyManager.isActive.value
        ? DecoyDataManager.fakeGroups.toList()
        : await AccountManager.loadGroupsCache(username);
    if (!mounted) return;
    _groups = groups;
    _rebuildGraph();
  }

  // ── graph rebuild ─────────────────────────────────────────────────────────

  void _rebuildGraph() {
    if (!mounted) return;
    final state = rootScreenKey.currentState;
    final username = state?.currentUsername ?? '';
    final favorites = state?.favorites ?? <FavoriteChat>[];
    final favFolders = state?.favFolders ?? <FavFolder>[];
    final allChats = state?.chats ?? <String, List<ChatMessage>>{};
    final inFolderIds =
        favFolders.expand((f) => f.chatIds).toSet();

    _myUsername = username;
    _myDisplayName = username;

    // raw chat keys (not favorites/groups), excluding locked DMs
    var chatKeys = allChats.keys
        .where((k) => !k.startsWith('fav:') && !k.startsWith('grp:'))
        .where((k) => !LockManager.isLocked('dm_${_peerFromKey(k, username)}'))
        .toList();

    // sort by last message time: newest = index 0 = innermost orbit
    chatKeys.sort((a, b) {
      final aMsg = allChats[a];
      final bMsg = allChats[b];
      final aTime =
          (aMsg != null && aMsg.isNotEmpty) ? aMsg.last.time : DateTime(2000);
      final bTime =
          (bMsg != null && bMsg.isNotEmpty) ? bMsg.last.time : DateTime(2000);
      return bTime
          .compareTo(aTime); // newest first → smallest ii → innermost orbit
    });

    // main server groups (AccountManager cache never has externalServerId)
    final mainGroups = _groups
        .where((g) => !g.isChannel && !LockManager.isLocked('ng_${g.id}'))
        .toList();
    final mainChannels = _groups
        .where((g) => g.isChannel && !LockManager.isLocked('ng_${g.id}'))
        .toList();

    // external groups come from ExternalServerManager, never from _groups
    final extGroups = (DecoyManager.isActive.value
            ? DecoyDataManager.fakeGroups
                .where((g) => g.externalServerId != null)
                .toList()
            : ExternalServerManager.externalGroups.value)
        .where((g) =>
            !LockManager.isLocked('eg_${g.externalServerId}_${g.id}'))
        .toList();

    final orbitSec = SettingsManager.graphOrbitSpeed.value;
    final catSpeed = -(2 * math.pi / orbitSec);
    final itemBaseSpeed = (2 * math.pi / (orbitSec * 0.667));
    const catBaseR = 180.0; // starting radius before first category
    const itemBaseR = 110.0;
    const itemStep = 18.0; // unique orbit per item

    // (catType, items, id, name-override, avatarKey)
    final catDefs =
        <(_CatType, List<_ItemOrbit>, String, String?, String?)>[];

    // ── Chats (newest = innermost) ─────────────────────────────────────────
    if (chatKeys.isNotEmpty) {
      final items = <_ItemOrbit>[];
      for (int ii = 0; ii < chatKeys.length; ii++) {
        final key = chatKeys[ii];
        final peer = _peerFromKey(key, username);
        items.add(_ItemOrbit(
          id: key, label: peer, catType: _CatType.chats,
          radius: itemBaseR + ii * itemStep, // ii=0 → newest → innermost
          basePhase: ii * 0.42,
          speed: itemBaseSpeed * (0.80 + (ii % 5) * 0.08),
          msgCount: allChats[key]?.length ?? 0,
          hasUnread: unreadManager.getUnreadCount(key) > 0,
          onTap: () => widget.onChatTap?.call(peer),
          avatarKey: peer,
        ));
      }
      catDefs.add((_CatType.chats, items, 'chats', null, null));
    }

    // ── Groups ─────────────────────────────────────────────────────────────
    if (mainGroups.isNotEmpty) {
      final items = <_ItemOrbit>[];
      for (int ii = 0; ii < mainGroups.length; ii++) {
        final g = mainGroups[ii];
        items.add(_ItemOrbit(
          id: 'group:${g.id}',
          label: g.name,
          catType: _CatType.groups,
          radius: itemBaseR + ii * itemStep,
          basePhase: ii * 0.42,
          speed: itemBaseSpeed * (0.80 + (ii % 5) * 0.08),
          msgCount:
              groupChats[g.id]?.where((m) => m['sender'] == username).length ??
                  0,
          hasUnread: false,
          onTap: () => widget.onGroupTap?.call(g),
          avatarKey: 'grp_${g.id}_${g.avatarVersion}',
        ));
      }
      catDefs.add((_CatType.groups, items, 'groups', null, null));
    }

    // ── Channels ───────────────────────────────────────────────────────────
    if (mainChannels.isNotEmpty) {
      final items = <_ItemOrbit>[];
      for (int ii = 0; ii < mainChannels.length; ii++) {
        final g = mainChannels[ii];
        items.add(_ItemOrbit(
          id: 'channel:${g.id}',
          label: g.name,
          catType: _CatType.channels,
          radius: itemBaseR + ii * itemStep,
          basePhase: ii * 0.42,
          speed: itemBaseSpeed * (0.80 + (ii % 5) * 0.08),
          msgCount:
              groupChats[g.id]?.where((m) => m['sender'] == username).length ??
                  0,
          hasUnread: false,
          onTap: () => widget.onGroupTap?.call(g),
          avatarKey: 'grp_${g.id}_${g.avatarVersion}',
        ));
      }
      catDefs.add((_CatType.channels, items, 'channels', null, null));
    }

    // ── Favorites: unfoldered chats + folder mini-planets with children ───────
    const childBaseR = itemBaseR;
    const childStep = itemStep;
    final unfolderedFavs = favorites
        .where((f) =>
            !inFolderIds.contains(f.id) &&
            !LockManager.isLocked('fav_${f.id}'))
        .toList();
    final allFavItems = <_ItemOrbit>[];
    int favIdx = 0;

    for (final fav in unfolderedFavs) {
      final favKey = 'fav_${fav.id}';
      if (fav.avatarPath != null && fav.avatarPath!.isNotEmpty) {
        _favAvatarPaths[favKey] = fav.avatarPath!;
      } else {
        _favAvatarPaths.remove(favKey);
      }
      allFavItems.add(_ItemOrbit(
        id: fav.id,
        label: fav.title,
        catType: _CatType.favorites,
        radius: itemBaseR + favIdx * itemStep,
        basePhase: favIdx * 0.42,
        speed: itemBaseSpeed * (0.80 + (favIdx % 5) * 0.08),
        msgCount: allChats['fav:${fav.id}']?.length ?? 0,
        hasUnread: false,
        onTap: () => widget.onFavoriteTap?.call(fav.id),
        avatarKey: favKey,
      ));
      favIdx++;
    }

    for (final folder in favFolders) {
      if (LockManager.isLocked('fav_folder_${folder.id}')) continue;
      final chatsInFolder = folder.chatIds
          .map((id) => favorites.where((f) => f.id == id).firstOrNull)
          .whereType<FavoriteChat>()
          .where((f) => !LockManager.isLocked('fav_${f.id}'))
          .toList();
      if (chatsInFolder.isEmpty) continue;

      final folderKey = 'folder_${folder.id}';
      if (folder.avatarPath != null && folder.avatarPath!.isNotEmpty) {
        _favAvatarPaths[folderKey] = folder.avatarPath!;
      } else {
        _favAvatarPaths.remove(folderKey);
      }

      final children = <_ItemOrbit>[];
      for (int ci = 0; ci < chatsInFolder.length; ci++) {
        final fav = chatsInFolder[ci];
        final favKey = 'fav_${fav.id}';
        if (fav.avatarPath != null && fav.avatarPath!.isNotEmpty) {
          _favAvatarPaths[favKey] = fav.avatarPath!;
        } else {
          _favAvatarPaths.remove(favKey);
        }
        children.add(_ItemOrbit(
          id: fav.id,
          label: fav.title,
          catType: _CatType.favFolder,
          radius: childBaseR + ci * childStep,
          basePhase: ci * 0.67,
          speed: itemBaseSpeed * 1.4 * (0.80 + (ci % 5) * 0.08),
          msgCount: allChats['fav:${fav.id}']?.length ?? 0,
          hasUnread: false,
          onTap: () => widget.onFavoriteTap?.call(fav.id),
          avatarKey: favKey,
        ));
      }

      // push folder outward so its child orbits don't overlap Favorites items
      final folderR = itemBaseR +
          favIdx * itemStep +
          (childBaseR + children.length * childStep) * 0.55;
      allFavItems.add(_ItemOrbit(
        id: folder.id,
        label: folder.name,
        catType: _CatType.favFolder,
        radius: folderR,
        basePhase: favIdx * 0.42,
        speed: itemBaseSpeed * (0.80 + (favIdx % 5) * 0.08),
        msgCount: 0,
        hasUnread: false,
        onTap: null,
        avatarKey: folderKey,
        children: children,
      ));
      favIdx++;
    }

    if (allFavItems.isNotEmpty) {
      catDefs.add((_CatType.favorites, allFavItems, 'favorites', null, null));
    }

    // ── External groups & channels from ExternalServerManager ──────────────
    if (extGroups.isNotEmpty) {
      final items = <_ItemOrbit>[];
      for (int ii = 0; ii < extGroups.length; ii++) {
        final g = extGroups[ii];
        // key includes externalServerId to avoid collisions with local group IDs
        final extAvatarKey =
            'ext_${g.externalServerId}_${g.id}_${g.avatarVersion}';
        items.add(_ItemOrbit(
          id: 'ext:${g.externalServerId}:${g.id}',
          label: g.name,
          catType: _CatType.external,
          radius: itemBaseR + ii * itemStep,
          basePhase: ii * 0.42,
          speed: itemBaseSpeed * (0.80 + (ii % 5) * 0.08),
          msgCount:
              groupChats[g.id]?.where((m) => m['sender'] == username).length ??
                  0,
          hasUnread: false,
          onTap: () => widget.onExternalGroupTap?.call(g),
          avatarKey: extAvatarKey,
        ));
      }
      catDefs.add((_CatType.external, items, 'external', null, null));
    }

    // Original size-based formula, but folder items contribute their child
    // count (at half weight) so Favorites with large folders naturally sits
    // further out without pushing everything else too far.
    const catItemFactor = 22.0;
    const catSeqOffset = 14.0;

    final n = catDefs.length;
    final newCats = <_CatOrbit>[];
    for (int i = 0; i < n; i++) {
      final items = catDefs[i].$2;
      // effective item count: each folder item adds half its children count
      final effectiveCount = items.fold<double>(
        0,
        (sum, item) => sum + 1 + item.children.length * 0.5,
      );
      // extra push for folder children: half the outer child orbit radius
      double folderPush = 0;
      for (final item in items) {
        if (item.children.isNotEmpty) {
          folderPush =
              math.max(folderPush, item.children.last.radius * 0.5);
        }
      }
      final catR = catBaseR +
          effectiveCount * catItemFactor +
          i * catSeqOffset +
          folderPush;
      newCats.add(_CatOrbit(
        id: catDefs[i].$3,
        catType: catDefs[i].$1,
        name: catDefs[i].$4,
        avatarKey: catDefs[i].$5,
        radius: catR,
        basePhase: n > 0 ? i * (2 * math.pi / n) : 0.0,
        speed: catSpeed,
        items: items,
      ));
    }

    setState(() => _categories = newCats);
    _scheduleAvatarWarmup();
  }

  // ── avatar loading ────────────────────────────────────────────────────────

  void _scheduleAvatarWarmup() {
    if (_avatarWarmupScheduled || !mounted) return;
    _avatarWarmupScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 120), () async {
      _avatarWarmupScheduled = false;
      if (!mounted) return;
      await _loadPriorityAvatars();
    });
  }

  Iterable<(_CatType, _ItemOrbit)> _priorityAvatarItems() sync* {
    final perCategoryLimit = isDesktop ? 8 : 4;
    final maxItems = isDesktop ? 28 : 14;
    var emitted = 0;
    for (final cat in _categories) {
      var taken = 0;
      for (final item in cat.items) {
        if (item.avatarKey == null) continue;
        yield (cat.catType, item);
        taken++;
        emitted++;
        if (taken >= perCategoryLimit || emitted >= maxItems) return;
      }
    }
  }

  Future<void> _loadPriorityAvatars() async {
    // Instantly decode any bytes already cached from a previous mount
    await _warmFromCache();

    // Only external servers still need a token (their own, below); profile
    // avatars are local files since the central server is gone.
    final token = _token ?? '';
    if (!mounted) return;
    if (DecoyManager.isActive.value) return;
    final username = _myUsername;
    if (username.isEmpty) return;

    await _loadProfileAvatar(username, username);

    var processed = 0;
    for (final entry in _priorityAvatarItems()) {
      final catType = entry.$1;
      final item = entry.$2;
      final key = item.avatarKey;
      if (key == null || _missingAvatarKeys.contains(key)) continue;

      if (catType == _CatType.chats) {
        await _loadProfileAvatar(key, item.label);
      } else if (!kCentralServerRemoved &&
          (catType == _CatType.groups || catType == _CatType.channels)) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final gid = int.tryParse(parts[1]);
          if (gid != null && gid > 0) {
            final ver = parts.length > 2 ? parts[2] : '0';
            await _fetchAvatar(
              key,
              '$serverBase/group/$gid/avatar?v=$ver',
              token,
            );
          }
        }
      } else if (catType == _CatType.external) {
        if (key.startsWith('ext_')) {
          final parts = key.split('_');
          if (parts.length >= 3) {
            final sid = parts[1];
            final gid = int.tryParse(parts[2]);
            final ver = parts.length > 3 ? parts[3] : '0';
            if (gid != null && gid > 0) {
              try {
                final srv = ExternalServerManager.servers.value
                    .firstWhere((s) => s.id == sid);
                await _fetchAvatar(
                  key,
                  '${srv.baseUrl}/group/$gid/avatar?v=$ver',
                  srv.token,
                );
              } catch (_) {
                _missingAvatarKeys.add(key);
              }
            }
          }
        }
      } else if (catType == _CatType.favorites ||
          catType == _CatType.favFolder) {
        final path = _favAvatarPaths[key];
        if (path != null && path.isNotEmpty) {
          await _loadLocalAvatar(key, path);
        }
      }

      processed++;
      if (processed % 4 == 0) {
        await Future.delayed(Duration.zero);
      }
      if (!mounted) return;
    }

    // Load remaining avatars not covered by the priority limit
    await _loadAllAvatars();
  }

  Future<void> _loadAllAvatars() async {
    // Only external servers still need a token (their own, below); profile
    // avatars are local files since the central server is gone.
    final token = _token ?? '';
    if (!mounted) return;
    if (DecoyManager.isActive.value) return;
    final username = _myUsername;
    if (username.isEmpty) return;

    await _loadProfileAvatar(username, username);

    for (final cat in _categories) {
      for (final item in cat.items) {
        final key = item.avatarKey;
        if (key == null) continue;

        if (cat.catType == _CatType.chats) {
          await _loadProfileAvatar(key, item.label);
        } else if (!kCentralServerRemoved &&
            (cat.catType == _CatType.groups ||
                cat.catType == _CatType.channels)) {
          // key format: 'grp_{gid}_{ver}'
          final parts = key.split('_');
          if (parts.length >= 2) {
            final gid = int.tryParse(parts[1]);
            if (gid != null && gid > 0) {
              final ver = parts.length > 2 ? parts[2] : '0';
              await _fetchAvatar(
                  key, '$serverBase/group/$gid/avatar?v=$ver', token);
            }
          }
        } else if (cat.catType == _CatType.external) {
          // key format: 'ext_{serverId}_{gid}_{ver}'
          // serverId is 32-char hex (no underscores), so split safely
          if (key.startsWith('ext_')) {
            final parts = key.split('_');
            if (parts.length >= 3) {
              final sid = parts[1];
              final gid = int.tryParse(parts[2]);
              final ver = parts.length > 3 ? parts[3] : '0';
              if (gid != null && gid > 0) {
                try {
                  final srv = ExternalServerManager.servers.value
                      .firstWhere((s) => s.id == sid);
                  await _fetchAvatar(
                    key,
                    '${srv.baseUrl}/group/$gid/avatar?v=$ver',
                    srv.token,
                  );
                } catch (_) {
                  // server not found or no avatar — initials shown
                }
              }
            }
          }
        } else if (cat.catType == _CatType.favorites ||
            cat.catType == _CatType.favFolder) {
          final path = _favAvatarPaths[key];
          if (path != null && path.isNotEmpty) {
            await _loadLocalAvatar(key, path);
          }
        }

        // load children of folder items (chats inside the folder)
        for (final child in item.children) {
          final ck = child.avatarKey;
          if (ck == null) continue;
          final path = _favAvatarPaths[ck];
          if (path != null && path.isNotEmpty) {
            await _loadLocalAvatar(ck, path);
          }
          if (!mounted) return;
        }

        if (!mounted) return;
      }
    }
  }

  // Decode any already-cached bytes into _avatars without hitting network/disk.
  Future<void> _warmFromCache() async {
    if (_cachedBytes.isEmpty) return;
    var decoded = 0;
    for (final entry in _cachedBytes.entries) {
      if (_avatars.containsKey(entry.key)) continue;
      try {
        final codec = await ui.instantiateImageCodec(
          entry.value,
          targetWidth: 80,
          targetHeight: 80,
        );
        final frame = await codec.getNextFrame();
        if (!mounted) return;
        _avatars[entry.key] = frame.image;
        decoded++;
        if (decoded % 8 == 0) await Future.delayed(Duration.zero);
      } catch (_) {}
    }
    if (mounted && decoded > 0) setState(() {});
  }

  Future<void> _loadLocalAvatar(String key, String path) async {
    if (_avatars.containsKey(key) || _loadingAvatar[key] == true) return;
    _loadingAvatar[key] = true;
    try {
      final bytes = await File(path).readAsBytes();
      if (!mounted) return;
      _cachedBytes[key] = bytes;
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 80, targetHeight: 80);
      final frame = await codec.getNextFrame();
      if (mounted) {
        _avatars[key] = frame.image;
        setState(() {});
      }
    } catch (_) {
      // file not found or corrupt — initials fallback
    } finally {
      _loadingAvatar[key] = false;
    }
  }

  /// A person's avatar from the local profile store (what AvatarWidget shows).
  Future<void> _loadProfileAvatar(String key, String username) async {
    if (_avatars.containsKey(key) || _loadingAvatar[key] == true) return;
    _loadingAvatar[key] = true;
    try {
      final raw = await ProfileStore.readAvatar(username);
      if (raw == null || raw.isEmpty || !mounted) return;
      final bytes = Uint8List.fromList(raw);
      _cachedBytes[key] = bytes;
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 80, targetHeight: 80);
      final frame = await codec.getNextFrame();
      if (mounted) {
        _avatars[key] = frame.image;
        setState(() {});
      }
    } catch (_) {
      // missing or corrupt -- initials are drawn instead
    } finally {
      _loadingAvatar[key] = false;
    }
  }

  Future<void> _fetchAvatar(String key, String url, String token) async {
    if (_avatars.containsKey(key) || _loadingAvatar[key] == true) return;
    _loadingAvatar[key] = true;
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200 && mounted) {
        _cachedBytes[key] = resp.bodyBytes;
        final codec = await ui.instantiateImageCodec(
          resp.bodyBytes,
          targetWidth: 80,
          targetHeight: 80,
        );
        final frame = await codec.getNextFrame();
        if (mounted) {
          _avatars[key] = frame.image;
          setState(() {});
        }
      } else if (resp.statusCode == 404) {
        _missingAvatarKeys.add(key);
      }
    } catch (_) {
      // initials fallback
    } finally {
      _loadingAvatar[key] = false;
    }
  }

  // ── camera ────────────────────────────────────────────────────────────────

  void _centerView() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final vs = box.size;
    // targetR = furthest edge across all categories so initial zoom fits everything
    double targetR = 700.0;
    for (final cat in _categories) {
      if (cat.items.isEmpty) {
        final edge = cat.radius + 110.0 + 60;
        if (edge > targetR) targetR = edge;
        continue;
      }
      for (final item in cat.items) {
        final childOuter = item.children.isNotEmpty
            ? item.children.last.radius + _GraphPainter._itemR
            : 0.0;
        final edge = cat.radius + item.radius + childOuter + 60;
        if (edge > targetR) targetR = edge;
      }
    }
    final scale = math.min(vs.width / 2 / targetR, vs.height / 2 / targetR);
    final tx = vs.width / 2 - _origin.dx * scale;
    final ty = vs.height / 2 - _origin.dy * scale;
    _tx.value = Matrix4.translationValues(tx, ty, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
  }

  // ── tap + hover detection ─────────────────────────────────────────────────

  void _onHover(PointerHoverEvent event) {
    Matrix4 inv;
    try {
      inv = Matrix4.inverted(_tx.value);
    } catch (_) {
      return;
    }
    final pt = MatrixUtils.transformPoint(inv, event.localPosition);
    final t = _orbitElapsed.value;
    for (final cat in _categories) {
      final cp = cat.posAt(_origin, t);
      for (final item in cat.items) {
        final ip = item.posAt(cp, t);
        if ((pt - ip).distance < _GraphPainter._itemR + 10) {
          if (!_isHoveringItem) setState(() => _isHoveringItem = true);
          return;
        }
        for (final child in item.children) {
          if ((pt - child.posAt(ip, t)).distance < _GraphPainter._itemR + 10) {
            if (!_isHoveringItem) setState(() => _isHoveringItem = true);
            return;
          }
        }
      }
    }
    if (_isHoveringItem) setState(() => _isHoveringItem = false);
  }

  void _onTapUp(TapUpDetails details) {
    Matrix4 inv;
    try {
      inv = Matrix4.inverted(_tx.value);
    } catch (_) {
      return;
    }
    final pt = MatrixUtils.transformPoint(inv, details.localPosition);
    final t = _orbitElapsed.value;

    for (final cat in _categories) {
      final cp = cat.posAt(_origin, t);
      for (final item in cat.items) {
        final ip = item.posAt(cp, t);
        // check children first (they're drawn on top)
        for (final child in item.children) {
          if ((pt - child.posAt(ip, t)).distance < _GraphPainter._itemR + 10) {
            child.onTap?.call();
            return;
          }
        }
        if ((pt - ip).distance < _GraphPainter._itemR + 10) {
          item.onTap?.call();
          return;
        }
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: _isHoveringItem ? SystemMouseCursors.click : MouseCursor.defer,
      onHover: _onHover,
      child: GestureDetector(
        onTapUp: _onTapUp,
        child: InteractiveViewer(
          transformationController: _tx,
          constrained: false,
          minScale: 0.03,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: SizedBox(
            width: _canvas,
            height: _canvas,
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(_canvas, _canvas),
                painter: _GraphPainter(
                  orbitElapsed: _orbitElapsed,
                  liveElapsed: _liveElapsed,
                  origin: _origin,
                  myUsername: _myUsername,
                  myDisplayName: _myDisplayName,
                  categories: _categories,
                  avatars: _avatars,
                  onlineUsers: _onlineUsers,
                  colors: colors,
                  skipHeavyEffects: !isDesktop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
