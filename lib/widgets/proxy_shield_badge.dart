// lib/widgets/proxy_shield_badge.dart
import 'package:flutter/material.dart';
import '../globals.dart';
import '../managers/settings_manager.dart';

class ProxyShieldBadge extends StatelessWidget {
  const ProxyShieldBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: proxyActiveNotifier,
      builder: (_, active, __) {
        if (!active) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: wsConnectedNotifier,
          builder: (_, connected, __) {
            if (!connected) return const SizedBox.shrink();

            const color = Color(0xFF4CAF50); 

            return Tooltip(
              message: 'Connected via proxy',
              child: GestureDetector(
                onTap: () => _showProxyDialog(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: color.withValues(alpha: 0.25),
                      ),
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: color,
                      ),
                      Positioned(
                        bottom: 2,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProxyDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final host = SettingsManager.proxyHost.value.trim();
    final port = SettingsManager.proxyPort.value.trim();
    final type = SettingsManager.proxyType.value.toUpperCase();
    final username = SettingsManager.proxyUsername.value.trim();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: colorScheme.surface,
        elevation: 8,
        
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 20,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Proxy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _InfoTile(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  label: 'Status',
                  value: 'Connected',
                ),
                const SizedBox(height: 8),

                _InfoTile(
                  icon: Icons.swap_horiz_rounded,
                  iconColor: colorScheme.primary,
                  label: 'Type',
                  value: type,
                ),
                const SizedBox(height: 8),

                _InfoTile(
                  icon: Icons.dns_outlined,
                  iconColor: colorScheme.primary,
                  label: 'Server',
                  value: host.isNotEmpty
                      ? '$host${port.isNotEmpty ? ':$port' : ''}'
                      : '—',
                ),

                if (username.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: colorScheme.secondary,
                    label: 'Login',
                    value: username,
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 4),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}