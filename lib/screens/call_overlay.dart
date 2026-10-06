// lib/screens/call_overlay.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:google_fonts/google_fonts.dart';
import '../call/call_manager.dart';
import '../l10n/app_localizations.dart';
import 'call_stage.dart';

class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

/// On desktop the window's own title bar (CustomTitleBar, 42px) sits at the
/// top of the root Stack: the call UI starts below it so minimize / maximize
/// / close stay reachable during a call.
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
double get _topInset => _isDesktop ? 42.0 : 0.0;

class _CallOverlayState extends State<CallOverlay> {
  double _minimizedX = 12.0;
  double _minimizedY = _topInset + 12.0;

  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  double _widgetStartX = 0.0;
  double _widgetStartY = 0.0;
  bool _hasDragged = false;

  final GlobalKey _widgetKey = GlobalKey();

  void _onPointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
    _dragStartY = event.position.dy;
    _widgetStartX = _minimizedX;
    _widgetStartY = _minimizedY;
    _hasDragged = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final dx = (event.position.dx - _dragStartX).abs();
    final dy = (event.position.dy - _dragStartY).abs();
    if (dx <= 8 && dy <= 8) return; // ignore tiny movements (finger jitter)
    _hasDragged = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final RenderBox? renderBox =
        _widgetKey.currentContext?.findRenderObject() as RenderBox?;
    final widgetWidth = renderBox?.size.width ?? 160.0;
    final widgetHeight = renderBox?.size.height ?? 50.0;

    final deltaX = event.position.dx - _dragStartX;
    final deltaY = event.position.dy - _dragStartY;

    double newX = _widgetStartX + deltaX;
    double newY = _widgetStartY + deltaY;

    newX = newX.clamp(0.0, screenWidth - widgetWidth);
    newY = newY.clamp(_topInset, screenHeight - widgetHeight);

    setState(() {
      _minimizedX = newX;
      _minimizedY = newY;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_hasDragged) {
      callManager.restoreCall();
    }

    _hasDragged = false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: callManager.isIncomingCall,
      builder: (ctx, isIncoming, _) {
        if (isIncoming) {
          return Positioned(
            top: _topInset,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildIncomingCallUI(context),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: callManager.isInCall,
          builder: (ctx, inCall, _) {
            if (!inCall) return const SizedBox();

            return ValueListenableBuilder<bool>(
              valueListenable: callManager.isMinimized,
              builder: (ctx, isMinimized, __) {
                if (isMinimized) {
                  return _buildMinimizedCallUI(context);
                }

                return _isDesktop
                    ? _buildDesktopCallUI(context)
                    : _buildMobileCallUI(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIncomingCallUI(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final peer = callManager.incomingPeer ?? '?';
    return Material(
      color: cs.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CallStage(
            username: peer,
            status: Text(
              callManager.incomingIsOnion
                  ? '${l.callIncomingTitle} · ${l.callPathTor}'
                  : l.callIncomingTitle,
              style: GoogleFonts.inter(
                color: cs.onSurface.withValues(alpha: 0.75),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundAction(
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFFF3B30),
                    label: l.callDecline,
                    onTap: callManager.rejectCall,
                  ),
                  const SizedBox(width: 88),
                  _RoundAction(
                    icon: Icons.call_rounded,
                    color: const Color(0xFF34C759),
                    label: l.callAccept,
                    onTap: callManager.acceptCall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimizedCallUI(BuildContext context) {
    final fontSize = _isDesktop ? 12.0 : 13.0;
    final closeSize = _isDesktop ? 20.0 : 24.0;
    final closeIconSize = _isDesktop ? 14.0 : 16.0;

    return Positioned(
      left: _minimizedX,
      top: _minimizedY,
      // The overlay lives above the Navigator, outside any Material: without
      // one, Text falls back to the debug style (yellow double underline).
      child: Material(
        type: MaterialType.transparency,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          child: Container(
            key: _widgetKey,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xCC2C2C2E),
                  Color(0xCC1C1C1E),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.08),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    callManager.peerUsername ??
                        callManager.incomingPeer ??
                        AppLocalizations.of(context).callFallbackName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: closeSize,
                  height: closeSize,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: closeIconSize,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      _hasDragged = true;
                      callManager.hangup();
                    },
                    padding: EdgeInsets.zero,
                    splashRadius: closeSize / 2,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          const Color(0xFFEF5350)),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(closeSize / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCallUI(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Positioned(
      top: _topInset,
      left: 0,
      right: 0,
      bottom: 0,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(child: _buildStage(context)),
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: callManager.isMuted,
                    builder: (ctx, isMuted, _) => _CallButton(
                      icon: Icons.mic_off,
                      activeIcon: Icons.mic,
                      isActive: !isMuted,
                      onPressed: callManager.toggleMute,
                      size: 64,
                      tooltip: l.callMute,
                    ),
                  ),
                  const SizedBox(width: 32),
                  _CallButton(
                    icon: Icons.call_end,
                    activeIcon: Icons.call_end,
                    color: const Color(0xFFEF5350),
                    onPressed: callManager.hangup,
                    isActive: true,
                    size: 72,
                    tooltip: l.callEnd,
                  ),
                  const SizedBox(width: 32),
                  _CallButton(
                    icon: Icons.expand_less,
                    activeIcon: Icons.expand_less,
                    isActive: true,
                    onPressed: callManager.minimizeCall,
                    size: 64,
                    tooltip: l.callMinimize,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCallUI(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildStage(context),
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                    // A dark tint keeps the white buttons readable on a
                    // light theme too.
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconWithLabel(
                          iconBuilder: (_) => ValueListenableBuilder<bool>(
                            valueListenable: callManager.isMuted,
                            builder: (ctx, isMuted, _) => _CallButton(
                              icon: Icons.mic_off,
                              activeIcon: Icons.mic,
                              isActive: !isMuted,
                              onPressed: callManager.toggleMute,
                              size: 56,
                            ),
                          ),
                          label: l.callMute,
                        ),
                        _CallButton(
                          icon: Icons.call_end,
                          activeIcon: Icons.call_end,
                          color: const Color(0xFFEF5350),
                          onPressed: callManager.hangup,
                          isActive: true,
                          size: 72,
                          tooltip: l.callEnd,
                        ),
                        _IconWithLabel(
                          iconBuilder: (_) => ValueListenableBuilder<bool>(
                            valueListenable: callManager.isSpeakerOn,
                            builder: (ctx, isSpeaker, _) => _CallButton(
                              icon: Icons.volume_down,
                              activeIcon: Icons.volume_up,
                              isActive: isSpeaker,
                              onPressed: callManager.toggleSpeaker,
                              size: 56,
                            ),
                          ),
                          label: l.callSpeaker,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Minimize, top-left.
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                // No tooltip: see _CallButton (no Overlay above the call UI).
                onPressed: callManager.minimizeCall,
                icon: Icon(Icons.expand_more_rounded,
                    size: 30, color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Voice-only calls: always the avatar screen.
  Widget _buildStage(BuildContext context) => CallStage(
        username: callManager.peerUsername ?? callManager.incomingPeer ?? '?',
        status: _buildConnectionStatus(context, onTheme: true),
      );

  /// [onTheme]: drawn on the themed CallStage rather than over video.
  Widget _buildConnectionStatus(BuildContext context, {bool onTheme = false}) {
    final plain = onTheme
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)
        : Colors.white;
    return AnimatedBuilder(
      animation:
          Listenable.merge([callManager.isConnecting, callManager.isRinging]),
      builder: (ctx, _) {
        // Ringing (they haven't picked up) -> "Calling...", answered but no
        // audio yet -> "Connecting...".
        if (callManager.isRinging.value || callManager.isConnecting.value) {
          final l = AppLocalizations.of(ctx);
          return _AnimatedEllipsis(
            text: callManager.isRinging.value
                ? l.callStatusCalling
                : l.callStatusConnecting,
            style: GoogleFonts.inter(
              color: plain,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        return AnimatedBuilder(
          animation:
              Listenable.merge([callManager.relayMode, callManager.quality]),
          builder: (ctx, __) {
            final l = AppLocalizations.of(ctx);
            final mode = callManager.relayMode.value;
            String text;
            Color color;
            if (mode == 'Tor') {
              text = l.callPathTor;
              color = const Color(0xFFB388FF);
            } else if (mode == 'Relay') {
              text = l.callPathRelay;
              color = Colors.orange;
            } else {
              text = l.callPathDirect;
              color = Colors.green;
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QualityBars(level: callManager.quality.value),
                const SizedBox(width: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// "Calling" / "Connecting" with three dots appearing one after another.
/// The dots keep their width (invisible ones are transparent) so the text
/// doesn't jitter sideways.
class _AnimatedEllipsis extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _AnimatedEllipsis({required this.text, required this.style});

  @override
  State<_AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<_AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden = widget.style.copyWith(color: Colors.transparent);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // 0, 1, 2, 3 dots, a quarter of the cycle each.
        final shown = (_c.value * 4).floor().clamp(0, 3);
        return Text.rich(
          TextSpan(
            text: widget.text,
            style: widget.style,
            children: [
              for (var i = 0; i < 3; i++)
                TextSpan(text: '.', style: i < shown ? null : hidden),
            ],
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}

/// Big round accept / decline button with a caption (incoming call).
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.6),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Four signal-strength bars for the call's connection quality (0 = not
/// measured yet: all dim).
class _QualityBars extends StatelessWidget {
  final int level;
  const _QualityBars({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      4 => Colors.greenAccent,
      3 => Colors.lightGreenAccent,
      2 => Colors.amberAccent,
      1 => Colors.redAccent,
      _ => Colors.white38,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Container(
            width: 4,
            height: 5.0 + i * 3,
            decoration: BoxDecoration(
              color: i <= level ? color : Colors.white24,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          if (i < 4) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class _IconWithLabel extends StatelessWidget {
  final Widget Function(BuildContext) iconBuilder;
  final String label;
  const _IconWithLabel({required this.iconBuilder, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        iconBuilder(context),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final String? tooltip;
  const _CallButton({
    required this.icon,
    required this.activeIcon,
    this.isActive = true,
    required this.onPressed,
    this.color,
    this.size = 56,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        color ?? (isActive ? Colors.white : Colors.grey.withOpacity(0.3));
    final iconColor = isActive ? Colors.black : Colors.white;
    final iconSize = size * 0.5;
    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        // Not FloatingActionButton.tooltip: this screen sits above the
        // Navigator, outside any Overlay, and a Tooltip can't be built there
        // (the button turned into a grey box). The label still reaches
        // screen readers.
        label: tooltip,
        button: true,
        child: Theme(
        data: Theme.of(context).copyWith(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: FloatingActionButton(
          // Several of these on one screen: no shared Hero tag.
          heroTag: null,
          onPressed: onPressed,
          backgroundColor: bgColor,
          foregroundColor: iconColor,
          elevation: 2,
          hoverElevation: isActive ? 6 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Opacity(
            opacity: isActive ? 1.0 : 0.8,
            child: Icon(isActive ? activeIcon : icon, size: iconSize),
          ),
        ),
        ),
      ),
    );
  }
}
