// lib/widgets/avatar_fullscreen_viewer.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'avatar_widget.dart' show getAvatarCachedBytes;

/// Radius of the small circular avatar this viewer Hero-animates from.
/// Must match the source AvatarWidget's `size / 2` (see call sites).
const double kAvatarHeroSourceRadius = 40.0;

/// Pushes a fullscreen, pinch-to-zoom viewer for [username]'s avatar,
/// Hero-animating from whatever widget shares [heroTag]. The image bytes
/// are resolved before the route is pushed so the Hero flight never shows
/// a placeholder/loading flicker mid-flight.
Future<void> pushAvatarFullscreen(
  BuildContext context, {
  required String username,
  required String heroTag,
  double sourceRadius = kAvatarHeroSourceRadius,
}) async {
  final bytes = await getAvatarCachedBytes(username);
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: AvatarFullscreenViewer(
            username: username,
            heroTag: heroTag,
            sourceRadius: sourceRadius,
            bytes: bytes,
          ),
        );
      },
    ),
  );
}

class AvatarFullscreenViewer extends StatefulWidget {
  final String username;
  final String heroTag;
  final double sourceRadius;
  final Uint8List? bytes;

  const AvatarFullscreenViewer({
    super.key,
    required this.username,
    required this.heroTag,
    this.sourceRadius = kAvatarHeroSourceRadius,
    this.bytes,
  });

  @override
  State<AvatarFullscreenViewer> createState() =>
      _AvatarFullscreenViewerState();
}

class _AvatarFullscreenViewerState extends State<AvatarFullscreenViewer> {
  double _dragOffset = 0.0;
  double _dragProgress = 0.0;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragOffset += d.delta.dy;
      _dragProgress = (_dragOffset.abs() / 300).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final flungAway = (d.primaryVelocity?.abs() ?? 0) > 800;
    if (_dragOffset.abs() > 120 || flungAway) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset = 0.0;
        _dragProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrimOpacity = 0.92 * (1.0 - _dragProgress);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        color: Colors.black.withValues(alpha: scrimOpacity),
        child: Stack(
          children: [
            Center(
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Opacity(
                  opacity: (1.0 - _dragProgress).clamp(0.2, 1.0),
                  child: Hero(
                    tag: widget.heroTag,
                    // The default Hero flight just resizes whichever child
                    // it's given; without this, a circular 80px avatar and
                    // a full-bleed rectangular photo don't read as the same
                    // physical object mid-flight. This shuttle keeps the
                    // corner radius and crop consistent throughout so the
                    // photo appears to grow in place, frame and all.
                    flightShuttleBuilder: (flightCtx, animation, direction,
                        fromCtx, toCtx) {
                      final isPush = direction == HeroFlightDirection.push;
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      final radiusTween = isPush
                          ? Tween<double>(
                              begin: widget.sourceRadius, end: 0.0)
                          : Tween<double>(
                              begin: 0.0, end: widget.sourceRadius);
                      return AnimatedBuilder(
                        animation: curved,
                        builder: (context, _) {
                          return ClipRRect(
                            borderRadius:
                                BorderRadius.circular(radiusTween.evaluate(curved)),
                            child: _AvatarImage(
                              username: widget.username,
                              bytes: widget.bytes,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      );
                    },
                    child: GestureDetector(
                      onTap: () {},
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 5.0,
                        child: _AvatarImage(
                          username: widget.username,
                          bytes: widget.bytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Opacity(
                opacity: (1.0 - _dragProgress).clamp(0.0, 1.0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final String username;
  final Uint8List? bytes;
  final BoxFit fit;

  const _AvatarImage({
    required this.username,
    this.bytes,
    this.fit = BoxFit.contain,
  });

  Widget _fallbackLetter() {
    final letter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return SizedBox(
      width: 240,
      height: 240,
      child: CircleAvatar(
        radius: 120,
        child: Text(
          letter,
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preloaded = bytes;
    if (preloaded != null && preloaded.isNotEmpty) {
      return Image.memory(preloaded, fit: fit, gaplessPlayback: true);
    }
    return FutureBuilder<Uint8List?>(
      future: getAvatarCachedBytes(username),
      builder: (context, snapshot) {
        final fetched = snapshot.data;
        if (fetched == null || fetched.isEmpty) return _fallbackLetter();
        return Image.memory(fetched, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
