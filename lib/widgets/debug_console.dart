// lib/widgets/debug_console.dart
import 'package:flutter/material.dart';
import 'package:ONYX/utils/performance_monitor.dart';

class DebugConsole extends StatefulWidget {
  final bool initialShow;

  const DebugConsole({
    Key? key,
    this.initialShow = false,
  }) : super(key: key);

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  bool _isVisible = false;
  late ScrollController _scrollController;
  final _monitor = PerformanceMonitor();

  @override
  void initState() {
    super.initState();
    _isVisible = widget.initialShow;
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleConsole() {
    setState(() => _isVisible = !_isVisible);
  }

  void _clearLogs() {
    _monitor.clear();
    setState(() {});
  }

  void _exportLogs() {
    final text = _monitor.exportAsText();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Performance Report'),
        content: SingleChildScrollView(
          child: Text(
            text,
            style: TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return Positioned(
        bottom: 16,
        right: 16,
        child: FloatingActionButton.small(
          onPressed: _toggleConsole,
          child: Icon(Icons.bug_report),
        ),
      );
    }

    final stats = _monitor.getStats();
    final logs = _monitor.getLogs();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 16, spreadRadius: 4),
          ],
        ),
        child: Column(
          children: [
            
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Debug Console • Logs: ${logs.length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.download, size: 18),
                        onPressed: _exportLogs,
                        tooltip: 'Export',
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 18),
                        onPressed: _clearLogs,
                        tooltip: 'Clear',
                        splashRadius: 20,
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18),
                        onPressed: _toggleConsole,
                        tooltip: 'Close',
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Builds: ${stats.totalBuilds} | Drops: ${stats.frameDrops}',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'Avg Build: ${stats.avgBuildTime.toStringAsFixed(2)}ms',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isError = log.message.contains('ERROR') || log.message.contains('FAILED');
                  final isDrop = log.message.contains('FRAME DROP');
                  final isBuild = log.message.startsWith('BUILD');

                  Color? color;
                  if (isError) color = Colors.red;
                  if (isDrop) color = Colors.orange;
                  if (isBuild) color = Colors.green;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      log.toString(),
                      style: TextStyle(
                        color: color ?? Colors.white70,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}