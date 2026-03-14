import 'package:flutter/material.dart';

class MessageNotificationData {
  final String username;
  final String displayName;
  final String message;
  final String? avatarUrl;
  final Duration displayDuration;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  MessageNotificationData({
    required this.username,
    required this.displayName,
    required this.message,
    this.avatarUrl,
    Duration? displayDuration,
    this.onTap,
    this.onClose,
  }) : displayDuration = displayDuration ?? const Duration(seconds: 5);
}

class MessageNotificationPopup extends StatefulWidget {
  final MessageNotificationData data;
  final VoidCallback onClose;

  const MessageNotificationPopup({
    Key? key,
    required this.data,
    required this.onClose,
  }) : super(key: key);

  @override
  State<MessageNotificationPopup> createState() => _MessageNotificationPopupState();
}

class _MessageNotificationPopupState extends State<MessageNotificationPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    Future.delayed(widget.data.displayDuration, () {
      if (mounted) {
        _closeWithAnimation();
      }
    });
  }

  void _closeWithAnimation() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(16),
            child: _buildNotificationCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.data.onTap?.call();
            _closeWithAnimation();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                
                _buildAvatar(),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.data.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey[300]
                              : Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _closeWithAnimation,
                      borderRadius: BorderRadius.circular(6),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: isDark
                            ? Colors.grey[500]
                            : Colors.grey[500],
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

  Widget _buildAvatar() {
    const avatarSize = 40.0;

    if (widget.data.avatarUrl != null && widget.data.avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: avatarSize,
          height: avatarSize,
          color: Colors.grey[300],
          child: Image.network(
            widget.data.avatarUrl!,
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildDefaultAvatar(avatarSize),
          ),
        ),
      );
    }

    return _buildDefaultAvatar(avatarSize);
  }

  Widget _buildDefaultAvatar(double size) {
    final firstLetter = widget.data.displayName.isNotEmpty
        ? widget.data.displayName[0].toUpperCase()
        : '?';
    final backgroundColor = _getAvatarColor(widget.data.username);

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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String seed) {
    final colors = [
      const Color(0xFF6750A4), 
      const Color(0xFF7D5260), 
      const Color(0xFF6F4E37), 
      const Color(0xFF8B6914), 
      const Color(0xFF33658A), 
      const Color(0xFF2D6A4F), 
      const Color(0xFFC1121F), 
      const Color(0xFFF77F00), 
    ];

    final hash = seed.hashCode;
    return colors[hash.abs() % colors.length];
  }
}