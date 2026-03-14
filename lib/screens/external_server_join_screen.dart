// lib/screens/external_server_join_screen.dart
import 'package:flutter/material.dart';
import '../managers/external_server_manager.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../models/external_server.dart';
import '../models/group.dart';
import '../widgets/security_warning_card.dart';

class ExternalServerJoinScreen extends StatefulWidget {
  const ExternalServerJoinScreen({super.key});

  @override
  State<ExternalServerJoinScreen> createState() => _ExternalServerJoinScreenState();
}

class _ExternalServerJoinScreenState extends State<ExternalServerJoinScreen> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _infoLoaded = false;
  String? _error;
  Map<String, dynamic>? _serverInfo;
  String _parsedHost = '';
  int _parsedPort = 9090;

  @override
  void initState() {
    super.initState();
    _loadDefaultUsername();
  }

  Future<void> _loadDefaultUsername() async {
    final current = await AccountManager.getCurrentAccount();
    if (current != null && mounted) {
      _usernameController.text = current;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _parseHostPort() {
    final input = _hostController.text.trim();
    if (input.isEmpty) return;

    final parts = input.split(':');
    _parsedHost = parts[0];
    if (parts.length > 1) {
      _parsedPort = int.tryParse(parts[1]) ?? 9090;
    } else {
      _parsedPort = 9090;
    }
  }

  Future<void> _fetchInfo() async {
    _parseHostPort();
    if (_parsedHost.isEmpty) {
      setState(() => _error = 'Enter a valid IP address or hostname');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final info = await ExternalServerManager.fetchServerInfo(_parsedHost, _parsedPort);
      if (mounted) {
        setState(() {
          _serverInfo = info;
          _infoLoaded = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to $_parsedHost:$_parsedPort\n${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    final isChannel = _serverInfo?['is_channel'] == true;

    var username = _usernameController.text.trim();
    if (username.isEmpty) {
      
      await _loadDefaultUsername();
      username = _usernameController.text.trim();
      if (username.isEmpty) {
        setState(() => _error = 'Username is required. Please make sure you have created an account in the app.');
        return;
      }
    }

    final password = _passwordController.text;
    if (!isChannel && password.isEmpty) {
      setState(() => _error = 'Password is required for groups');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final server = await ExternalServerManager.registerOnServer(
        host: _parsedHost,
        port: _parsedPort,
        username: username,
        displayName: username,
        password: isChannel ? '' : password,  
        serverInfo: _serverInfo!,
      );

      ExternalServerManager.connectWebSocket(server.id);

      await ExternalServerManager.refreshAllExternalGroups();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to "${server.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection failed: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join External Server'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            if (!_infoLoaded) ...[
              Text(
                'Enter server address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  hintText: '192.168.1.100:9090',
                  labelText: 'IP:Port',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.dns_outlined),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _fetchInfo(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _fetchInfo,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_loading ? 'Connecting...' : 'Connect'),
              ),
            ],

            if (_infoLoaded && _serverInfo != null) ...[
              _buildServerInfoCard(),
              const SizedBox(height: 16),

              const SecurityWarningCard(),
              const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your identity will be visible to the server',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Username: ',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                Text(
                                  _usernameController.text,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (_serverInfo!['is_channel'] != true) ...[
                  Text(
                    'Password',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  
                  ValueListenableBuilder<double>(
                    valueListenable: SettingsManager.elementBrightness,
                    builder: (context, brightness, child) {
                      final baseColor = SettingsManager.getElementColor(
                        colorScheme.surfaceContainerHighest,
                        brightness,
                      );
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No password required for channels',
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _infoLoaded = false;
                          _serverInfo = null;
                        });
                      },
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _connect,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login),
                      label: Text(_loading ? 'Connecting...' : 'Join'),
                    ),
                  ),
                ],
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfoCard() {
    final info = _serverInfo!;
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (context, brightness, child) {
        final baseColor = SettingsManager.getElementColor(
          colorScheme.surfaceContainerHighest,
          brightness,
        );
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info['group_name'] ?? info['name'] ?? 'Unknown',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              Text(
                '$_parsedHost:$_parsedPort',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              if ((info['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(info['description'], style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.8))),
              ],
              if ((info['motd'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(info['motd'], style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
              const Divider(height: 20),
              _infoRow('Groups', '${info['groups_count'] ?? 0}'),
              _infoRow('Members', '${info['total_members'] ?? 0}'),
              _infoRow('Media', '${info['media_provider'] ?? 'none'}'),
              _infoRow('Max file size', '${info['max_file_size_mb'] ?? 0} MB'),
              _infoRow('Max members/group', '${info['max_members_per_group'] ?? 0}'),
              if (info['require_approval'] == true)
                _infoRow('Approval required', 'Yes'),
              if (info['features'] != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (info['features'] as List<dynamic>).map((f) {
                    return Chip(
                      label: Text(f.toString(), style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.7))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}