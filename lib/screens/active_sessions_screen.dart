// lib/screens/active_sessions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../managers/account_manager.dart';

class ActiveSessionsScreen extends StatefulWidget {
  final String serverBase;
  final String token;

  const ActiveSessionsScreen({
    super.key,
    required this.serverBase,
    required this.token,
  });

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('${widget.serverBase}/me/sessions'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _sessions = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load sessions'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; _loading = false; });
    }
  }

  Future<void> _revokeSession(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke session?'),
        content: const Text('This device will be immediately logged out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${widget.serverBase}/me/sessions/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        _loadSessions();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to revoke session')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _approveSession(int id) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverBase}/me/sessions/$id/approve'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        _loadSessions();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve device')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (e) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadSessions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final s = _sessions[i];
                      final isCurrent = s['is_current'] == true;
                      final isTrusted = s['e2e_trusted'] == true;
                      final isPending = !isTrusted && !isCurrent;
                      final id = s['id'] as int;
                      final deviceName = s['device_name'] as String? ?? 'Unknown device';
                      final deviceOs = s['device_os'] as String? ?? 'Unknown OS';
                      final lastUsed = _formatDate(s['last_used_at'] as String?);

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isPending
                                ? Colors.orange.withValues(alpha: 0.7)
                                : isCurrent
                                    ? colorScheme.primary.withValues(alpha: 0.6)
                                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                            width: isPending || isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isPending
                                ? Colors.orange.withValues(alpha: 0.15)
                                : isCurrent
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainerHighest,
                            child: Icon(
                              _deviceIcon(deviceOs),
                              color: isPending
                                  ? Colors.orange.shade700
                                  : isCurrent
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deviceName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'This device',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPending)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_clock, size: 12, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Waiting for approval',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                '$deviceOs • Last active: $lastUsed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          trailing: isCurrent
                              ? null
                              : isPending
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                                          tooltip: 'Approve device',
                                          onPressed: () => _approveSession(id),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.logout, color: Colors.red.shade400),
                                          tooltip: 'Revoke this session',
                                          onPressed: () => _revokeSession(id),
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.logout, color: Colors.red.shade400),
                                      tooltip: 'Revoke this session',
                                      onPressed: () => _revokeSession(id),
                                    ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _deviceIcon(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('android')) return Icons.phone_android;
    if (lower.contains('ios')) return Icons.phone_iphone;
    if (lower.contains('windows')) return Icons.desktop_windows;
    if (lower.contains('mac')) return Icons.laptop_mac;
    if (lower.contains('linux')) return Icons.computer;
    return Icons.devices;
  }
}

class ActiveSessionsTab extends StatefulWidget {
  final String serverBase;
  final String? username;
  final VoidCallback onBack;

  const ActiveSessionsTab({
    super.key,
    required this.serverBase,
    this.username,
    required this.onBack,
  });

  @override
  State<ActiveSessionsTab> createState() => _ActiveSessionsTabState();
}

class _ActiveSessionsTabState extends State<ActiveSessionsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void didUpdateWidget(ActiveSessionsTab old) {
    super.didUpdateWidget(old);
    if (old.username != widget.username) {
      _token = null;
      _loadSessions();
    }
  }

  Future<void> _loadSessions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final username = widget.username;
      if (username == null) {
        setState(() { _error = 'Not logged in'; _loading = false; });
        return;
      }
      _token ??= await AccountManager.getToken(username);
      if (!mounted) return;
      if (_token == null) {
        setState(() { _error = 'Not authenticated'; _loading = false; });
        return;
      }
      final res = await http.get(
        Uri.parse('${widget.serverBase}/me/sessions'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _sessions = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load sessions (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Network error: $e'; _loading = false; });
    }
  }

  Future<void> _revokeSession(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke session?'),
        content: const Text('This device will be immediately logged out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await http.delete(
        Uri.parse('${widget.serverBase}/me/sessions/$id'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        _loadSessions();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to revoke session')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveSession(int id) async {
    try {
      final res = await http.post(
        Uri.parse('${widget.serverBase}/me/sessions/$id/approve'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 200) {
        _loadSessions();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve device')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (e) {
      return iso;
    }
  }

  IconData _deviceIcon(String os) {
    final lower = os.toLowerCase();
    if (lower.contains('android')) return Icons.phone_android;
    if (lower.contains('ios')) return Icons.phone_iphone;
    if (lower.contains('windows')) return Icons.desktop_windows;
    if (lower.contains('mac')) return Icons.laptop_mac;
    if (lower.contains('linux')) return Icons.computer;
    return Icons.devices;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: widget.onBack,
                tooltip: 'Back to Settings',
              ),
              const Text(
                'Active Devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadSessions,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _loadSessions, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: _sessions.isEmpty
                          ? const Center(child: Text('No active sessions found'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _sessions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final s = _sessions[i];
                                final isCurrent = s['is_current'] == true;
                                final isTrusted = s['e2e_trusted'] == true;
                                final isPending = !isTrusted && !isCurrent;
                                final id = s['id'] as int;
                                final deviceName = s['device_name'] as String? ?? 'Unknown device';
                                final deviceOs = s['device_os'] as String? ?? 'Unknown OS';
                                final lastUsed = _formatDate(s['last_used_at'] as String?);
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isPending
                                          ? Colors.orange.withValues(alpha: 0.7)
                                          : isCurrent
                                              ? colorScheme.primary.withValues(alpha: 0.6)
                                              : colorScheme.outlineVariant.withValues(alpha: 0.3),
                                      width: isPending || isCurrent ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: isPending
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : isCurrent
                                              ? colorScheme.primaryContainer
                                              : colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        _deviceIcon(deviceOs),
                                        color: isPending
                                            ? Colors.orange.shade700
                                            : isCurrent
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            deviceName,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (isCurrent)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'This device',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPending)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 3),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.lock_clock, size: 12, color: Colors.orange.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Waiting for approval',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Text(
                                          '$deviceOs • Last active: $lastUsed',
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    trailing: isCurrent
                                        ? null
                                        : isPending
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                                                    tooltip: 'Approve device',
                                                    onPressed: () => _approveSession(id),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.logout, color: Colors.red.shade400),
                                                    tooltip: 'Revoke this session',
                                                    onPressed: () => _revokeSession(id),
                                                  ),
                                                ],
                                              )
                                            : IconButton(
                                            icon: Icon(Icons.logout, color: Colors.red.shade400),
                                            tooltip: 'Revoke this session',
                                            onPressed: () => _revokeSession(id),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}