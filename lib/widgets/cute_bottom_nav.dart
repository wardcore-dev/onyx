
import 'package:flutter/material.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class CuteBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;
  const CuteBottomNav({
    Key? key,
    required this.selectedIndex,
    required this.onTap,
    this.items = const [
      NavItem(Icons.chat_bubble, 'Chats'),
      NavItem(Icons.person, 'Accounts'),
      NavItem(Icons.settings, 'Settings'),
    ],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(
      context,
    ).colorScheme.surface; 
    final pillColor = isDark ? Colors.grey[850] : Colors.white;
    final shadowColor = isDark ? Colors.black26 : Colors.black12;

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          child: Material(
            color: pillColor,
            elevation: 4, 
            shadowColor: shadowColor,
            borderRadius: BorderRadius.circular(28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (i) {
                    final it = items[i];
                    final selected = i == selectedIndex;
                    return Expanded(
                      child: _CuteNavItem(
                        icon: it.icon,
                        label: it.label,
                        selected: selected,
                        onTap: () => onTap(i),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CuteNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CuteNavItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_CuteNavItem> createState() => _CuteNavItemState();
}

class _CuteNavItemState extends State<_CuteNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bounceAnimation = TweenSequence<double>([
      
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -8.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      
      TweenSequenceItem(
        tween: Tween<double>(begin: -8.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      
      TweenSequenceItem(
        tween: Tween<double>(begin: -1.5, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _bounceController.forward().then((_) => _bounceController.reset());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final selectedBg = accent.withOpacity(0.12);
    final selectedIconColor = theme.colorScheme.primary;
    final normalIconColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: widget.selected ? 44 : 38,
                    height: widget.selected ? 44 : 38,
                    decoration: BoxDecoration(
                      color: widget.selected ? selectedBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.icon,
                      size: widget.selected ? 22 : 20,
                      color: widget.selected
                          ? selectedIconColor
                          : normalIconColor,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: widget.selected ? 12 : 11,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                color: widget.selected ? selectedIconColor : normalIconColor,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}