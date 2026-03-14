import 'package:flutter/material.dart';

class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final double itemHeight;
  final EdgeInsets padding;
  final bool addRepaintBoundary;

  const OptimizedListView({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemHeight,
    this.controller,
    this.padding = const EdgeInsets.all(0),
    this.addRepaintBoundary = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      
      itemExtent: itemHeight,
      
      cacheExtent: 100,
      
      physics: const ClampingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final item = itemBuilder(context, index);
        
        return addRepaintBoundary
            ? RepaintBoundary(child: item)
            : item;
      },
    );
  }
}

class OptimizedGridView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final ScrollController? controller;
  final EdgeInsets padding;

  const OptimizedGridView({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.controller,
    this.padding = const EdgeInsets.all(0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: gridDelegate,
      cacheExtent: 200,
      physics: const ClampingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
    );
  }
}

class OptimizedSingleChildScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsets padding;
  final bool addRepaintBoundary;

  const OptimizedSingleChildScrollView({
    Key? key,
    required this.child,
    this.controller,
    this.padding = const EdgeInsets.all(0),
    this.addRepaintBoundary = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget result = SingleChildScrollView(
      controller: controller,
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (addRepaintBoundary) {
      result = RepaintBoundary(child: result);
    }

    return result;
  }
}

class OptimizedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color backgroundColor;
  final BorderRadiusGeometry borderRadius;
  final VoidCallback? onTap;

  const OptimizedCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    final content = Padding(
      padding: padding,
      child: child,
    );

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

class OptimizedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  const OptimizedText(
    this.text, {
    Key? key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    return RepaintBoundary(
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

class OptimizedAnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;
  final Curve curve;

  const OptimizedAnimatedBuilder({
    Key? key,
    required this.animation,
    required this.builder,
    this.duration = const Duration(milliseconds: 200), 
    this.curve = Curves.easeOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        
        return RepaintBoundary(
          child: builder(context, animation.value),
        );
      },
    );
  }
}

class OptimizedBlur extends StatelessWidget {
  final Widget child;
  final double sigma;

  const OptimizedBlur({
    Key? key,
    required this.child,
    this.sigma = 4.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    return Stack(
      children: [
        child,
        
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.1),
          ),
        ),
      ],
    );
  }
}