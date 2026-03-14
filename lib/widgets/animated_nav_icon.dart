import 'package:flutter/material.dart';

enum NavIconAnimationType {
  bounce,
  rotateScale,
  pulse,
  slideUp,
  spin,
}

class AnimatedNavIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final bool isSelected;
  final NavIconAnimationType animationType;
  final int entryDelay;

  const AnimatedNavIcon({
    super.key,
    required this.icon,
    this.size = 22,
    this.color,
    this.isSelected = false,
    this.animationType = NavIconAnimationType.bounce,
    this.entryDelay = 0,
  });

  @override
  State<AnimatedNavIcon> createState() => _AnimatedNavIconState();
}

class _AnimatedNavIconState extends State<AnimatedNavIcon>
    with TickerProviderStateMixin {
  late AnimationController _tapController;
  late AnimationController _entryController;
  late Animation<double> _tapBounce;
  late Animation<double> _entryOffset;
  late Animation<double> _entryOpacity;

  @override
  void initState() {
    super.initState();

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 465),
      vsync: this,
    );

    _entryController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _tapBounce = TweenSequence<double>([
      
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
    ]).animate(_tapController);

    _entryOffset = Tween<double>(begin: -35.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.easeOut,
      ),
    );

    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    Future.delayed(Duration(milliseconds: widget.entryDelay), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected && widget.isSelected) {
      _tapController.forward().then((_) => _tapController.reset());
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_tapController, _entryController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _entryOffset.value + _tapBounce.value),
          child: Opacity(
            opacity: _entryOpacity.value,
            child: Icon(
              widget.icon,
              size: widget.size,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}