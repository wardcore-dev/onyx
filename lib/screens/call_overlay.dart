// lib/screens/call_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../call/call_manager.dart';

class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  double _minimizedX = 12.0;
  double _minimizedY = 12.0;

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
    _hasDragged = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final RenderBox? renderBox = _widgetKey.currentContext?.findRenderObject() as RenderBox?;
    final widgetWidth = renderBox?.size.width ?? 160.0;
    final widgetHeight = renderBox?.size.height ?? 50.0;

    final deltaX = event.position.dx - _dragStartX;
    final deltaY = event.position.dy - _dragStartY;

    double newX = _widgetStartX + deltaX;
    double newY = _widgetStartY + deltaY;

    newX = newX.clamp(0.0, screenWidth - widgetWidth);
    newY = newY.clamp(0.0, screenHeight - widgetHeight);

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
          return Positioned.fill(child: _buildIncomingCallUI(context));
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

                final isDesktop =
                    !kIsWeb &&
                    (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

                return isDesktop
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
    final cs = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Container(
      color: Colors.black45,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Incoming call', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface)),
              Text('From: ${callManager.incomingPeer ?? "Unknown"}', style: TextStyle(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'global_reject',
                    backgroundColor: Colors.red,
                    onPressed: callManager.rejectCall,
                    child: const Icon(Icons.call_end),
                  ),
                  const SizedBox(width: 48),
                  FloatingActionButton(
                    heroTag: 'global_accept',
                    backgroundColor: Colors.green,
                    onPressed: callManager.acceptCall,
                    child: const Icon(Icons.call),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMinimizedCallUI(BuildContext context) {
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final fontSize = isDesktop ? 12.0 : 13.0;
    final closeSize = isDesktop ? 20.0 : 24.0;
    final closeIconSize = isDesktop ? 14.0 : 16.0;

    return Positioned(
      left: _minimizedX,
      top: _minimizedY,
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
                  callManager.peerUsername ?? callManager.incomingPeer ?? 'Call',
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
                    backgroundColor: MaterialStateProperty.all<Color>(const Color(0xFFEF5350)),
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
    );
  }

  Widget _buildDesktopCallUI(BuildContext context) {
    return Stack(
      children: [
        _buildRemoteVideo(context),
        Positioned(
          top: 48,
          right: 48,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 200,
                height: 150,
                child: RTCVideoView(callManager.localRenderer),
              ),
            ),
          ),
        ),
        Positioned(
          top: 48,
          left: 0,
          right: 0,
          child: _buildConnectionStatus(context),
        ),
        Positioned(
          top: 96,
          left: 0,
          right: 0,
          child: Text(
            callManager.peerUsername ?? callManager.incomingPeer ?? 'Unknown',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
                ),
              ),
              const SizedBox(width: 32),
              ValueListenableBuilder<bool>(
                valueListenable: callManager.isVideoMuted,
                builder: (ctx, isVideoMuted, _) => _CallButton(
                  icon: Icons.videocam_off,
                  activeIcon: Icons.videocam,
                  isActive: !isVideoMuted,
                  onPressed: callManager.toggleVideo,
                  size: 64,
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
              ),
              const SizedBox(width: 32),
              _CallButton(
                icon: Icons.expand_less,
                activeIcon: Icons.expand_less,
                isActive: true,
                onPressed: callManager.minimizeCall,
                size: 64,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCallUI(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildRemoteVideo(context),

            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildConnectionStatus(context),
                  const SizedBox(height: 8),
                  Text(
                    callManager.peerUsername ??
                        callManager.incomingPeer ??
                        'Unknown',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                          label: 'Mute',
                        ),
                        _IconWithLabel(
                          iconBuilder: (_) => ValueListenableBuilder<bool>(
                            valueListenable: callManager.isVideoMuted,
                            builder: (ctx, isVideoMuted, _) => _CallButton(
                              icon: Icons.videocam_off,
                              activeIcon: Icons.videocam,
                              isActive: !isVideoMuted,
                              onPressed: callManager.toggleVideo,
                              size: 56,
                            ),
                          ),
                          label: 'Video',
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
                          label: 'Speaker',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        
                        ValueListenableBuilder<bool>(
                          valueListenable: callManager.isVideoMuted,
                          builder: (_, videoMuted, __) => AnimatedOpacity(
                            opacity: videoMuted ? 0.3 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: _CallButton(
                              icon: Icons.flip_camera_ios_rounded,
                              activeIcon: Icons.flip_camera_ios_rounded,
                              isActive: !videoMuted,
                              onPressed: videoMuted ? () {} : callManager.switchCamera,
                              size: 56,
                            ),
                          ),
                        ),
                        _CallButton(
                          icon: Icons.call_end,
                          activeIcon: Icons.call_end,
                          color: const Color(0xFFEF5350),
                          onPressed: callManager.hangup,
                          isActive: true,
                          size: 76,
                        ),
                        _CallButton(
                          icon: Icons.expand_less,
                          activeIcon: Icons.expand_less,
                          isActive: true,
                          onPressed: callManager.minimizeCall,
                          size: 56,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 72,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 90,
                    height: 120,
                    child: RTCVideoView(callManager.localRenderer),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: callManager.isRemoteVideoEnabled,
      builder: (ctx, hasVideo, _) {
        if (!hasVideo) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'No video\n(audio only)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }
        return Container(
          color: Colors.black,
          child: RTCVideoView(
            callManager.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: callManager.isConnecting,
      builder: (ctx, connecting, _) {
        if (connecting) {
          return Text(
            'Connecting…',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        return ValueListenableBuilder<String>(
          valueListenable: callManager.relayMode,
          builder: (ctx, mode, __) {
            String text;
            Color color;
            if (mode == 'Relay') {
              text = 'Relay (via server)';
              color = Colors.orange;
            } else {
              text = 'Direct call (P2P)';
              color = Colors.green;
            }
            return Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        );
      },
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
  const _CallButton({
    required this.icon,
    required this.activeIcon,
    this.isActive = true,
    required this.onPressed,
    this.color,
    this.size = 56,
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
      child: Theme(
        data: Theme.of(context).copyWith(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
        ),
        child: FloatingActionButton(
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
    );
  }
}