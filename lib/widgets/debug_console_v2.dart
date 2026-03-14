// lib/widgets/debug_console_v2.dart
import 'package:flutter/material.dart';
import 'package:ONYX/utils/performance_monitor.dart';

class DebugConsoleV2 extends StatefulWidget {
  final bool initialShow;
  final List<String> externalLogs; 

  const DebugConsoleV2({
    Key? key,
    this.initialShow = false,
    this.externalLogs = const [],
  }) : super(key: key);

  @override
  State<DebugConsoleV2> createState() => _DebugConsoleV2State();
}

class _DebugConsoleV2State extends State<DebugConsoleV2> {
  bool _isVisible = false;
  late ScrollController _scrollController;
  final _monitor = PerformanceMonitor();
  bool _autoScroll = true;
  String _filterText = '';

  int _selectedTab = 0; 

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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _getFilteredLogs() {
    final List<String> allLogs = [
      ..._monitor.getLogs().map((log) => log.toString()),
      ...widget.externalLogs,
    ];

    List<String> filtered = allLogs;

    if (_selectedTab == 1) {
      filtered = filtered.where((log) => log.contains('[ERROR]')).toList();
    } else if (_selectedTab == 2) {
      filtered = filtered
          .where((log) =>
              log.contains('FRAME DROP') || log.contains('BUILD') ||
              log.contains('OPERATION'))
          .toList();
    } else if (_selectedTab == 3) {
      filtered = filtered.where((log) => log.contains('BUILD:')).toList();
    }

    if (_filterText.isNotEmpty) {
      filtered = filtered
          .where((log) => log.toLowerCase().contains(_filterText.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  Color _logColor(String log) {
    if (log.contains('[ERROR]') || log.contains('FAILED')) return Colors.red;
    if (log.contains('FRAME DROP')) return Colors.orange;
    if (log.contains('BUILD:')) return Colors.green;
    if (log.contains('[WARNING]')) return Colors.yellow[700]!;
    return Colors.blue[200]!;
  }

  void _exportLogs() {
    final logs = _getFilteredLogs();
    final text = logs.join('\n');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Экспорт логов'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isPortrait = screenHeight > screenWidth;
    final panelHeight = isPortrait ? screenHeight * 0.4 : screenHeight * 0.5;
    final panelWidth = screenWidth * 0.95;

    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    final filteredLogs = _getFilteredLogs();
    final stats = _monitor.getStats();

    return Positioned(
      bottom: 0,
      left: (screenWidth - panelWidth) / 2,
      right: (screenWidth - panelWidth) / 2,
      height: panelHeight,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(bottom: BorderSide(color: Colors.grey[700]!)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        ' Debug Console',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.download, size: 16),
                            onPressed: _exportLogs,
                            tooltip: 'Экспорт',
                            constraints: const BoxConstraints(maxWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () {
                              _monitor.clear();
                              setState(() {});
                            },
                            tooltip: 'Очистить',
                            constraints: const BoxConstraints(maxWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _isVisible = false),
                            tooltip: 'Закрыть',
                            constraints: const BoxConstraints(maxWidth: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Logs: ${stats.totalLogs} | Builds: ${stats.totalBuilds} | '
                          'Drops: ${stats.frameDrops} | Avg: ${stats.avgBuildTime.toStringAsFixed(1)}ms',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabButton('All', 0),
                              const SizedBox(width: 4),
                              _buildTabButton('Errors', 1),
                              const SizedBox(width: 4),
                              _buildTabButton('Perf', 2),
                              const SizedBox(width: 4),
                              _buildTabButton('Build', 3),
                              const SizedBox(width: 12),
                              
                              Expanded(
                                child: TextField(
                                  onChanged: (val) =>
                                      setState(() => _filterText = val),
                                  decoration: InputDecoration(
                                    hintText: 'Поиск...',
                                    hintStyle:
                                        const TextStyle(fontSize: 11),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      borderSide: BorderSide(
                                          color: Colors.grey[700]!),
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(
                color: Colors.black87,
                child: filteredLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'Нет логов',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredLogs.length,
                        itemBuilder: (ctx, idx) {
                          final log = filteredLogs[idx];
                          final color = _logColor(log);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontFamily: 'Courier',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                border: Border(top: BorderSide(color: Colors.grey[700]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Checkbox(
                    value: _autoScroll,
                    onChanged: (val) => setState(() => _autoScroll = val ?? true),
                  ),
                  const Text(
                    'Auto scroll',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _selectedTab == index ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }
}