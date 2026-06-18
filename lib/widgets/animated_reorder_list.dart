import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../managers/settings_manager.dart';

/// A list that smoothly animates an item sliding to its new slot when the
/// underlying order changes (e.g. a chat jumping to the top after a new
/// message), in the spirit of iMessage's conversation list.
///
/// Falls back to an instant, unanimated rebuild for anything more complex
/// than a single item changing position (items added/removed, multiple
/// items reordered at once, full resets such as account switches or search
/// filtering) — those are rare and don't need to feel "alive" the way a
/// chat jumping to the top does.
class AnimatedReorderList<T> extends StatefulWidget {
  const AnimatedReorderList({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.header,
    this.padding,
    this.physics,
    this.separatorHeight = 0,
  });

  final List<T> items;
  final String Function(T item) keyOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Optional widget rendered above the list, scrolling with it.
  final Widget? header;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  /// Height of the gap rendered between items (mirrors `ListView.separated`).
  final double separatorHeight;

  @override
  State<AnimatedReorderList<T>> createState() => _AnimatedReorderListState<T>();
}

class _AnimatedReorderListState<T> extends State<AnimatedReorderList<T>>
    with TickerProviderStateMixin {
  static const _moveDuration = Duration(milliseconds: 420);

  GlobalKey<SliverAnimatedListState> _listKey = GlobalKey<SliverAnimatedListState>();
  late List<T> _displayed;

  /// Stable per-item keys, used to measure an item's on-screen position for
  /// the "flight" overlay below. Keyed by `widget.keyOf(item)`.
  final Map<String, GlobalKey> _itemKeys = {};

  /// Id of the item currently being flown to its new slot — its regular slot
  /// is rendered invisible (but still occupies space) while the overlay
  /// "ghost" shows the real visual flying above the rest of the list.
  String? _flyingId;
  OverlayEntry? _flightEntry;
  AnimationController? _flightController;
  ui.Image? _flightImage;

  @override
  void initState() {
    super.initState();
    _displayed = List<T>.from(widget.items);
  }

  @override
  void dispose() {
    _flightEntry?.remove();
    _flightController?.dispose();
    _flightImage?.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void didUpdateWidget(covariant AnimatedReorderList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Note: callers may mutate their list in place (e.g. move-to-front
    // helpers), so an `identical()` check on the list reference would miss
    // those changes. Always diff against our own snapshot instead.
    _reconcile(widget.items);
  }

  void _reconcile(List<T> newItems) {
    final oldIds = _displayed.map(widget.keyOf).toList(growable: false);
    final newIds = newItems.map(widget.keyOf).toList(growable: false);

    if (_listEquals(oldIds, newIds)) {
      // Same order — just refresh the backing data (e.g. preview text changed).
      setState(() => _displayed = List<T>.from(newItems));
      return;
    }

    final move = _singleMove(oldIds, newIds);
    if (move != null && SettingsManager.chatListMoveAnimationsEnabled.value) {
      final (from, to) = move;
      _flyMove(from, to, newItems);
      return;
    }

    // Anything more complex (adds/removes/multi-moves/full reset): resync
    // instantly without animation by recreating the AnimatedList.
    _flightEntry?.remove();
    _flightEntry = null;
    _flightController?.dispose();
    _flightController = null;
    setState(() {
      _displayed = List<T>.from(newItems);
      _flyingId = null;
      _listKey = GlobalKey<SliverAnimatedListState>();
    });
  }

  /// Animates a single item moving from [from] to [to]: the real slot
  /// collapses/expands like a normal list move (so neighbours glide smoothly
  /// into place) while a frozen snapshot of the card lifts off, gains a
  /// shadow and sails above every other card to its destination — landing
  /// exactly as the real slot finishes opening underneath it.
  ///
  /// We fly a *rasterized snapshot* rather than the live widget: these cards
  /// can carry expensive shader-based "liquid glass" backgrounds, and
  /// rebuilding/repainting that every animation frame in an Overlay (a
  /// different compositing context, where its blur has nothing meaningful
  /// to sample behind it) is what caused the "invisible and janky" flight.
  /// A flat image is cheap to transform and always paints identically.
  void _flyMove(int from, int to, List<T> newItems) {
    final movedId = widget.keyOf(_displayed[from]);
    final updatedItem = newItems.firstWhere(
      (it) => widget.keyOf(it) == movedId,
      orElse: () => _displayed[from],
    );

    // Refresh the moving card's content in its current slot *first* — only
    // its position should animate, not its content. If we snapshotted now,
    // the flying ghost would carry the stale preview/timestamp from before
    // this update and only show the real one once it lands.
    setState(() => _displayed[from] = updatedItem);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _beginFlyMove(from, to, newItems, movedId);
    });
  }

  void _beginFlyMove(int from, int to, List<T> newItems, String movedId) {
    final landingId = widget.keyOf(_displayed[to]);
    final removedItem = _displayed[from];

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    final overlayBox = overlayState?.context.findRenderObject() as RenderBox?;

    Rect? fromRect;
    Rect? toRect;
    Future<ui.Image>? snapshotFuture;
    if (overlayState != null && overlayBox != null && overlayBox.hasSize) {
      final movedObj = _itemKeys[movedId]?.currentContext?.findRenderObject();
      final landingRect = _rectInOverlay(landingId, overlayBox);
      if (movedObj is RenderRepaintBoundary &&
          movedObj.attached &&
          movedObj.hasSize &&
          landingRect != null) {
        final topLeft = movedObj.localToGlobal(Offset.zero, ancestor: overlayBox);
        fromRect = topLeft & movedObj.size;
        toRect = Rect.fromLTWH(
          landingRect.left,
          landingRect.top,
          fromRect.width,
          fromRect.height,
        );
        try {
          final dpr = MediaQuery.of(context).devicePixelRatio;
          // Captured synchronously now, while the card is still fully
          // visible — the resulting Future resolves with *this* frame's
          // pixels regardless of how the tree changes afterwards.
          snapshotFuture = movedObj.toImage(pixelRatio: dpr);
        } catch (_) {
          snapshotFuture = null;
        }
      }
    }

    final flying = fromRect != null &&
        toRect != null &&
        snapshotFuture != null &&
        overlayState != null;

    // Retire the old key so the item's new slot gets a fresh GlobalKey —
    // the outgoing transition keeps animating under the old identity while
    // the incoming one settles under a new one (avoids duplicate-key clashes).
    if (flying) _itemKeys.remove(movedId);

    setState(() {
      if (flying) _flyingId = movedId;
      _displayed.removeAt(from);
      _listKey.currentState?.removeItem(
        from,
        (context, animation) =>
            _buildEntry(context, removedItem, animation, incoming: false, keyed: false),
        duration: _moveDuration,
      );
      _displayed.insert(to, newItems[to]);
      _listKey.currentState?.insertItem(to, duration: _moveDuration);
      // Other items may have changed content too (e.g. previews); sync the
      // rest of the shadow list without touching the animated slots.
      _displayed = List<T>.from(newItems);
    });

    if (flying) {
      _awaitSnapshotAndLaunch(snapshotFuture, overlayState, fromRect, toRect, movedId);
    }
  }

  Rect? _rectInOverlay(String id, RenderBox overlayBox) {
    final ctx = _itemKeys[id]?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & box.size;
  }

  Future<void> _awaitSnapshotAndLaunch(
    Future<ui.Image> snapshotFuture,
    OverlayState overlayState,
    Rect fromRect,
    Rect toRect,
    String id,
  ) async {
    ui.Image? image;
    try {
      image = await snapshotFuture;
    } catch (_) {
      image = null;
    }
    if (!mounted || _flyingId != id) {
      image?.dispose();
      return;
    }
    if (image == null) {
      // Couldn't capture a frame — just reveal the real card in place.
      setState(() => _flyingId = null);
      return;
    }
    _launchGhost(overlayState, fromRect, toRect, image, id);
  }

  void _launchGhost(
    OverlayState overlayState,
    Rect fromRect,
    Rect toRect,
    ui.Image image,
    String id,
  ) {
    _flightEntry?.remove();
    _flightController?.dispose();
    _flightImage?.dispose();
    _flightImage = image;

    final controller = AnimationController(vsync: this, duration: _moveDuration);
    _flightController = controller;
    final rectAnim = RectTween(begin: fromRect, end: toRect).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
    );
    // Lift mid-flight: rises and grows a shadow on takeoff, settles flat on landing.
    final lift = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: controller,
          // The image is built once and reused every frame — only the
          // transform/shadow are recomputed, keeping the flight smooth.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: RawImage(image: image, fit: BoxFit.fill),
          ),
          builder: (context, child) {
            final rect = rectAnim.value ?? toRect;
            final liftValue = lift.value;
            return Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 1.0 + 0.045 * liftValue,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.38 * liftValue),
                          blurRadius: 26 * liftValue,
                          spreadRadius: 1,
                          offset: Offset(0, 10 * liftValue),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    _flightEntry = entry;
    overlayState.insert(entry);

    controller.forward().whenCompleteOrCancel(() {
      entry.remove();
      if (identical(_flightEntry, entry)) _flightEntry = null;
      if (identical(_flightController, controller)) _flightController = null;
      if (identical(_flightImage, image)) _flightImage = null;
      controller.dispose();
      image.dispose();
      if (mounted && _flyingId == id) {
        setState(() => _flyingId = null);
      }
    });
  }

  /// If [newIds] can be produced from [oldIds] by moving exactly one element
  /// to a different position (keeping all others in relative order), returns
  /// the (fromIndex, toIndex) pair; otherwise null.
  (int, int)? _singleMove(List<String> oldIds, List<String> newIds) {
    if (oldIds.length != newIds.length) return null;
    if (oldIds.length < 2) return null;
    if (!_sameElements(oldIds, newIds)) return null;

    int start = 0;
    while (start < oldIds.length && oldIds[start] == newIds[start]) {
      start++;
    }
    if (start == oldIds.length) return null; // identical

    final movedId = newIds[start];
    final fromIndex = oldIds.indexOf(movedId);
    if (fromIndex == start) return null;

    final probe = List<String>.from(oldIds)
      ..removeAt(fromIndex)
      ..insert(start, movedId);
    if (_listEquals(probe, newIds)) return (fromIndex, start);
    return null;
  }

  bool _sameElements(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = a.toSet();
    final sb = b.toSet();
    return sa.length == a.length && sb.length == b.length && sa.containsAll(sb);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _buildEntry(
    BuildContext context,
    T item,
    Animation<double> animation, {
    required bool incoming,
    bool keyed = true,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: incoming ? Curves.easeOutCubic : Curves.easeInCubic,
    );
    final index = incoming ? _displayed.indexOf(item) : 0;
    final id = widget.keyOf(item);
    final isFlying = _flyingId == id;

    Widget content = widget.itemBuilder(context, item, index);
    // While the ghost overlay is sailing to its new slot, hide the real card
    // (it still reserves space, so the size transition below stays correct).
    if (isFlying) content = Opacity(opacity: 0, child: content);
    // Wrap in our own RepaintBoundary (rather than relying on callers to
    // provide one) so `_flyMove` can always find a `RenderRepaintBoundary`
    // at this key to measure and snapshot — regardless of what the caller's
    // itemBuilder happens to return (e.g. favourites wrap theirs in a plain
    // FadeTransition with no boundary of its own).
    if (keyed) content = RepaintBoundary(key: _keyFor(id), child: content);

    return SizeTransition(
      sizeFactor: curved,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, incoming ? -0.18 : 0.12),
            end: Offset.zero,
          ).animate(curved),
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: widget.physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (widget.header != null)
          SliverToBoxAdapter(child: widget.header),
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverAnimatedList(
            key: _listKey,
            initialItemCount: _displayed.length,
            itemBuilder: (context, index, animation) {
              if (index >= _displayed.length) return const SizedBox.shrink();
              final entry = _buildEntry(
                context, _displayed[index], animation, incoming: true);
              if (widget.separatorHeight <= 0) return entry;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  entry,
                  SizedBox(height: widget.separatorHeight),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
