import 'package:flutter/material.dart';
import '../managers/notification_manager.dart';

class NotificationOverlayWidget extends StatefulWidget {
  const NotificationOverlayWidget({Key? key}) : super(key: key);

  @override
  NotificationOverlayWidgetState createState() => NotificationOverlayWidgetState();
}

class NotificationOverlayWidgetState extends State<NotificationOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final notificationManager = OverlayNotificationManager();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    notificationManager.currentNotification.addListener(_handleNotificationChange);
  }

  void _handleNotificationChange() {
    if (notificationManager.currentNotification.value != null) {
      
      _animationController.forward(from: 0.0);
    } else {
      
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    notificationManager.currentNotification.removeListener(_handleNotificationChange);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OverlayNotification?>(
      valueListenable: notificationManager.currentNotification,
      builder: (context, notification, _) {
        if (notification == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 16,
          bottom: 16,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _NotificationCard(
                notification: notification,
                onDismiss: () => notificationManager.dismiss(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final OverlayNotification notification;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
  });

  @override
  _NotificationCardState createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          notification.onTap?.call();
          widget.onDismiss();
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[800]!
                    : Colors.grey[200]!,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  _buildAvatar(notification, theme),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        Text(
                          notification.displayName ?? notification.username,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        Text(
                          notification.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  InkWell(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[600]
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(OverlayNotification notification, ThemeData theme) {
    final avatarSize = 48.0;

    if (notification.avatarUrl != null && notification.avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          notification.avatarUrl!,
          width: avatarSize,
          height: avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(
            notification.displayName ?? notification.username,
            avatarSize,
            theme,
          ),
        ),
      );
    }

    return _buildDefaultAvatar(
      notification.displayName ?? notification.username,
      avatarSize,
      theme,
    );
  }

  Widget _buildDefaultAvatar(String name, double size, ThemeData theme) {
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final backgroundColor = _getAvatarColor(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.red,
      Colors.cyan,
    ];

    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }
}