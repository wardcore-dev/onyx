import 'package:flutter/material.dart';

class OptimizedChatListBuilder extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final double itemHeight;
  final EdgeInsets padding;
  final bool addRepaintBoundary;
  final VoidCallback? onLoadMore;
  final bool isLoading;

  const OptimizedChatListBuilder({
    Key? key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemHeight,
    this.controller,
    this.padding = const EdgeInsets.all(0),
    this.addRepaintBoundary = true,
    this.onLoadMore,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<OptimizedChatListBuilder> createState() =>
      _OptimizedChatListBuilderState();
}

class _OptimizedChatListBuilderState extends State<OptimizedChatListBuilder> {
  late ScrollController _controller;
  final Map<int, Widget> _cachedItems = {};

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onScroll);
    }
    _cachedItems.clear();
    super.dispose();
  }

  void _onScroll() {
    
    final visibleStart = _controller.position.pixels / widget.itemHeight;
    final visibleEnd = visibleStart + (MediaQuery.of(context).size.height / widget.itemHeight);

    final itemsToRemove = <int>[];
    _cachedItems.forEach((index, _) {
      if (index < (visibleStart - 10).ceil() || index > visibleEnd.ceil() + 10) {
        itemsToRemove.add(index);
      }
    });

    for (final index in itemsToRemove) {
      _cachedItems.remove(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      
      itemExtent: widget.itemHeight,
      
      cacheExtent: 150,
      
      physics: const ClampingScrollPhysics(),
      itemCount: widget.itemCount + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        
        if (index == widget.itemCount) {
          return Center(
            child: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }

        _cachedItems.putIfAbsent(index, () => widget.itemBuilder(context, index));
        final item = _cachedItems[index]!;

        return widget.addRepaintBoundary
            ? RepaintBoundary(child: item)
            : item;
      },
    );
  }
}

class OptimizedMessageTile extends StatelessWidget {
  final Widget child;
  final bool addRepaintBoundary;

  const OptimizedMessageTile({
    Key? key,
    required this.child,
    this.addRepaintBoundary = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!addRepaintBoundary) return child;
    return RepaintBoundary(child: child);
  }
}

class OptimizedChatTile extends StatelessWidget {
  final Widget child;

  const OptimizedChatTile({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        child: child,
      ),
    );
  }
}