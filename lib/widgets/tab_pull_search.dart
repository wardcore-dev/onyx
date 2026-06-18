// lib/widgets/tab_pull_search.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../globals.dart';
import '../managers/settings_manager.dart';
import 'adaptive_glass_card.dart';

/// A single hit surfaced by a tab's deep search — either a name/contact match
/// or a match found somewhere in that chat's message history.
class TabSearchResult {
  final String id;
  final String title;
  final String? subtitle;
  final String? snippet;
  final IconData icon;

  /// Builds the same avatar the host tab shows for this chat in its normal
  /// list (network image, cached file, AvatarWidget, …) so a result reads as
  /// an expanded chat card rather than a generic search hit. Falls back to a
  /// plain [icon] circle when not supplied.
  final Widget Function(BuildContext context, double size)? avatarBuilder;

  /// The matched message's id (ChatMessage.id), present only for content-match
  /// results. Lets the host tab tell the destination chat screen to scroll to
  /// and highlight that exact message on open, instead of landing at the
  /// bottom — see [setPendingMessageScrollTarget] in globals.dart.
  final String? messageId;

  const TabSearchResult({
    required this.id,
    required this.title,
    this.subtitle,
    this.snippet,
    this.icon = Icons.chat_bubble_outline,
    this.avatarBuilder,
    this.messageId,
  });
}

/// Wraps a tab's chat list so that pulling down past the top edge (the
/// classic "pull to search" overscroll, mirroring Telegram/Gmail) reveals a
/// deep-search panel — distinct in look from the inline magnifying-glass
/// search, styled as a frosted "spotlight" bar that reacts to the user's
/// opacity/brightness theme settings like the rest of the app's surfaces.
class TabPullSearchOverlay extends StatefulWidget {
  final Widget child;
  final String hintText;
  final Future<List<TabSearchResult>> Function(String query) onSearch;
  final void Function(TabSearchResult result) onResultTap;

  const TabPullSearchOverlay({
    super.key,
    required this.child,
    required this.onSearch,
    required this.onResultTap,
    this.hintText = 'Поиск чатов и сообщений…',
  });

  @override
  State<TabPullSearchOverlay> createState() => _TabPullSearchOverlayState();
}

class _TabPullSearchOverlayState extends State<TabPullSearchOverlay>
    with SingleTickerProviderStateMixin {
  // Deliberately a long, heavy pull — like a browser's "release to refresh"
  // arc — so the search panel only commits once the user has dragged far
  // past the point where a normal overscroll bounce would settle back. Big
  // enough that a brisk fling toward the top can't cross it by accident.
  static const _openThreshold = 190.0;

  late final AnimationController _anim;
  late final Animation<double> _curve;

  // Smoothly deflates the "pull to search" ring back to nothing when the user
  // releases before crossing the open threshold — without it, the indicator
  // just sits at whatever size it was mid-bounce and then snaps away the
  // instant the list settles, which reads as "hanging".
  late final AnimationController _pullResetController;
  Animation<double>? _pullResetAnim;
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _open = false;
  bool _triggered = false;
  double _pullDistance = 0;

  Timer? _debounce;
  int _searchGeneration = 0;
  bool _searching = false;
  String _lastQuery = '';
  List<TabSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _pullResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    if (_open) tabPullSearchOpen.value = false;
    _anim.dispose();
    _pullResetController.dispose();
    _textCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Eases [_pullDistance] back down to zero from wherever it currently sits
  /// — used when the user lets go without pulling far enough to open the
  /// panel, so the indicator visibly retracts instead of freezing in place.
  void _animatePullToZero() {
    if (_pullDistance <= 0) return;
    _pullResetController.stop();
    final anim = Tween<double>(begin: _pullDistance, end: 0).animate(
      CurvedAnimation(parent: _pullResetController, curve: Curves.easeOutCubic),
    );
    _pullResetAnim = anim;
    anim.addListener(() {
      if (!mounted || _pullResetAnim != anim) return;
      setState(() => _pullDistance = anim.value);
    });
    _pullResetController.forward(from: 0);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;

    if (_open) {
      // Mirrors Telegram: scrolling the list back into its content (away
      // from the top) is the "reverse" of the pull-down gesture that opened
      // the panel, and collapses it again. Skip this once there's an active
      // query though — the list area is now showing search results, and
      // scrolling through matches shouldn't dismiss the search itself.
      if (_textCtrl.text.trim().isEmpty && notification is ScrollUpdateNotification) {
        final delta = notification.scrollDelta ?? 0;
        if (delta > 0 && metrics.pixels > metrics.minScrollExtent) {
          _closePanel();
        }
      }
      return false;
    }

    // BouncingScrollPhysics (iOS/macOS/desktop default here) never emits
    // OverscrollNotification — it just lets `pixels` go negative past the
    // top edge and reports that through ScrollUpdateNotification. Reading
    // the depth straight off the metrics covers that case; the explicit
    // OverscrollNotification branch covers ClampingScrollPhysics (Android),
    // where `pixels` stays clamped at minScrollExtent instead.
    final bounceDepth = metrics.pixels < metrics.minScrollExtent
        ? metrics.minScrollExtent - metrics.pixels
        : 0.0;

    // A fast fling toward the top produces exactly the same overscroll —
    // just driven by momentum (a ballistic simulation) instead of the
    // finger. `dragDetails` is only non-null while the user is actively
    // holding and moving their finger, so gating on it means a brisk swipe
    // can no longer "accidentally" cross the threshold and pop the search
    // open; only a deliberate, sustained pull counts.
    final DragUpdateDetails? dragDetails = switch (notification) {
      ScrollUpdateNotification u => u.dragDetails,
      OverscrollNotification o => o.dragDetails,
      _ => null,
    };
    final isActiveDrag = dragDetails != null;

    final isOverscrolling = bounceDepth > 0 ||
        (notification is OverscrollNotification && notification.overscroll < 0);

    if (isActiveDrag) {
      // A live finger is in control — track it and cancel any in-flight
      // retract from a previous pull that the user grabbed again.
      _pullResetController.stop();
      if (bounceDepth > 0) {
        final next = bounceDepth;
        if (next != _pullDistance) setState(() => _pullDistance = next);
      } else if (notification is OverscrollNotification && notification.overscroll < 0) {
        final next = _pullDistance - notification.overscroll;
        if (next != _pullDistance) setState(() => _pullDistance = next);
      }
    } else if (isOverscrolling ||
        notification is ScrollEndNotification ||
        (notification is ScrollUpdateNotification &&
            metrics.pixels >= metrics.minScrollExtent)) {
      // The finger just lifted (still mid-bounce) or the scroll has fully
      // settled without crossing the threshold — start retracting the
      // indicator the instant the drag ends, not once the whole ballistic
      // bounce-back finishes (that's what made it look "stuck" for a beat).
      _triggered = false;
      if (_pullDistance > 0 && !_pullResetController.isAnimating) {
        _animatePullToZero();
      }
      return false;
    }

    if (!_triggered && _pullDistance >= _openThreshold) {
      _triggered = true;
      _openPanel();
    }
    return false;
  }

  void _openPanel() {
    if (_open) return;
    HapticFeedback.mediumImpact();
    tabPullSearchOpen.value = true;
    setState(() => _open = true);
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _closePanel() {
    if (!_open) return;
    _debounce?.cancel();
    _searchGeneration++;
    _focusNode.unfocus();
    tabPullSearchOpen.value = false;
    _anim.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _open = false;
        _textCtrl.clear();
        _results = const [];
        _searching = false;
        _lastQuery = '';
        _pullDistance = 0;
        _triggered = false;
      });
    });
  }

  void _onQueryChanged(String raw) {
    final query = raw.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _searchGeneration++;
      setState(() {
        _results = const [];
        _searching = false;
        _lastQuery = '';
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_searchGeneration;
    List<TabSearchResult> results;
    try {
      results = await widget.onSearch(query);
    } catch (_) {
      results = const [];
    }
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _results = results;
      _searching = false;
      _lastQuery = query;
    });
  }

  void _handleResultTap(TabSearchResult result) {
    _closePanel();
    widget.onResultTap(result);
  }

  @override
  Widget build(BuildContext context) {
    // Telegram-style reveal: the panel grows in place at the top and pushes
    // the chat list downward, instead of floating over a dimmed backdrop.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap the panel against the space this overlay actually has to work
        // with — not the full screen height. Some host tabs share that space
        // with other chrome above the list, and the keyboard can shrink it
        // further still; sizing off `MediaQuery` instead would let the panel
        // demand more room than is left and squash the list beneath it.
        final maxPanelHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.55
            : MediaQuery.sizeOf(context).height * 0.5;
        final cs = Theme.of(context).colorScheme;
        final hasQuery = _textCtrl.text.trim().isNotEmpty;
        // Once there's an active query, the search results take over the
        // list area itself — rendered as cards matching the host's normal
        // chat-list cards — instead of floating in a separate panel.
        final showResults = _open && hasQuery;
        return Stack(
          children: [
            Column(
              children: [
                SizeTransition(
                  sizeFactor: _curve,
                  axisAlignment: -1.0,
                  child: _open ? _buildPanel(context, maxPanelHeight) : const SizedBox.shrink(),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: showResults ? _buildResultsList(context, cs) : widget.child,
                  ),
                ),
              ],
            ),
            // While the user is dragging — before the pull commits — a growing
            // ring tracks the gesture in the overscroll gap, exactly like a
            // browser's "pull to refresh" arrow filling up before it lets go.
            if (!_open && _pullDistance > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _pullDistance,
                child: IgnorePointer(child: _buildPullIndicator(context)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPullIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (_pullDistance / _openThreshold).clamp(0.0, 1.0);
    return Center(
      child: Opacity(
        opacity: progress,
        child: Transform.scale(
          scale: 0.5 + 0.5 * progress,
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.6,
              color: cs.primary,
              backgroundColor: cs.primary.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating pill-shaped search field only — mirrors SearchDialogContent's
  /// _searchFieldStandard rounding so both search UIs read as the same visual
  /// language. Results are no longer shown in a separate floating card here;
  /// they replace the host list itself (see [_buildResultsList]) so the
  /// search reads as "the list changed" rather than "something popped up".
  Widget _buildPanel(BuildContext context, double maxHeight) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementOpacity,
        builder: (_, opacity, __) {
          return ValueListenableBuilder<double>(
            valueListenable: SettingsManager.elementBrightness,
            builder: (_, brightness, __) {
              final panelColor = SettingsManager.getElementColor(
                cs.surfaceContainerHigh,
                brightness,
              ).withValues(alpha: opacity.clamp(0.9, 1.0));
              final borderColor = cs.outlineVariant.withValues(alpha: 0.25);

              return Container(
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  style: TextStyle(fontSize: 16, color: cs.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.search_rounded,
                          color: cs.onSurface.withValues(alpha: 0.5), size: 22),
                    ),
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.45),
                      fontSize: 15,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Renders search results as a scrollable list of full-width cards that
  /// match the host tab's normal chat-list cards (AdaptiveGlassCard,
  /// borderRadius 16, circle avatar + title + preview row) — so searching
  /// reads as "the list itself changed to show matches", not as a separate
  /// panel popping up. One card per matching message; chats are intentionally
  /// not deduped — a chat with several hits shows up as several cards.
  Widget _buildResultsList(BuildContext context, ColorScheme cs) {
    if (_searching) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Ничего не найдено по запросу «$_lastQuery»',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _buildResultCard(context, cs, _results[i]),
    );
  }

  Widget _buildResultCard(BuildContext context, ColorScheme cs, TabSearchResult r) {
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleResultTap(r),
        child: AdaptiveGlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              children: [
                r.avatarBuilder?.call(context, 40) ??
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      child: Icon(r.icon, size: 18, color: cs.primary),
                    ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _highlighted(
                        r.title,
                        _lastQuery,
                        base: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          fontSize: 15,
                        ),
                        highlight: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                          fontSize: 15,
                          backgroundColor: cs.primary.withValues(alpha: 0.16),
                        ),
                        maxLines: 1,
                      ),
                      if (r.snippet != null && r.snippet!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _highlighted(
                            r.snippet!,
                            _lastQuery,
                            base: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                            highlight: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                              backgroundColor: cs.primary.withValues(alpha: 0.16),
                            ),
                            maxLines: 1,
                          ),
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
  }

  /// Renders [text] with every case-insensitive occurrence of [query]
  /// emphasised via [highlight]; everything else uses [base].
  Widget _highlighted(
    String text,
    String query, {
    required TextStyle base,
    required TextStyle highlight,
    int? maxLines,
  }) {
    if (query.isEmpty) {
      return Text(text,
          maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null, style: base);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: base));
      }
      spans.add(TextSpan(text: text.substring(idx, idx + query.length), style: highlight));
      start = idx + query.length;
    }
    return RichText(
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      text: TextSpan(children: spans),
    );
  }
}
