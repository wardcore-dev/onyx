// lib/dialogs/server_connection_dialog.dart
import 'package:flutter/material.dart';
import '../managers/external_server_manager.dart';
import '../managers/account_manager.dart';
import '../managers/settings_manager.dart';
import '../widgets/security_warning_card.dart';
import '../l10n/app_localizations.dart';

class ServerConnectionDialog extends StatefulWidget {
  const ServerConnectionDialog({super.key});

  @override
  State<ServerConnectionDialog> createState() => _ServerConnectionDialogState();
}

class _ServerConnectionDialogState extends State<ServerConnectionDialog> {
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
      setState(() => _error = AppLocalizations(SettingsManager.appLocale.value).enterValidIp);
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
          _error = '${AppLocalizations(SettingsManager.appLocale.value).couldNotConnect('$_parsedHost:$_parsedPort')}\n${e.toString()}';
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
        setState(() => _error = AppLocalizations(SettingsManager.appLocale.value).usernameRequiredMsg);
        return;
      }
    }

    final password = _passwordController.text;
    if (!isChannel && password.isEmpty) {
      setState(() => _error = AppLocalizations(SettingsManager.appLocale.value).passwordRequiredForGroups);
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
        final colorScheme = Theme.of(context).colorScheme;
        final isChannel = _serverInfo?['is_channel'] == true;
        final l = AppLocalizations(SettingsManager.appLocale.value);
        final connectionType = isChannel ? l.externalChannelType : l.externalGroupType;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.connectedToServer(connectionType, server.name),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: SettingsManager.elementOpacity.value),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 4,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations(SettingsManager.appLocale.value).connectionFailed(e.toString());
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (context, brightness, child) {
        final dialogColor = SettingsManager.getElementColor(
          colorScheme.surface,
          brightness,
        );
        return Dialog(
          backgroundColor: dialogColor.withValues(alpha: SettingsManager.elementOpacity.value),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          constraints: const BoxConstraints(
            maxWidth: 420,
            maxHeight: 600,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              Text(
                AppLocalizations.of(context).joinExternalServer,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),

              if (!_infoLoaded) ...[
                Text(
                  AppLocalizations.of(context).enterServerAddress,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    hintText: '127.0.0.1:9090',
                    labelText: 'IP:Port',
                    labelStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    prefixIcon: Icon(Icons.dns_outlined,
                        color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: SettingsManager.getElementColor(
                            colorScheme.surfaceContainerHighest, brightness)
                        .withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.15),
                          width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.15),
                          width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 1.4),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _fetchInfo(),
                ),
                const SizedBox(height: 16),
              ],

              if (_infoLoaded && _serverInfo != null) ...[
                _buildServerInfoCard(),
                const SizedBox(height: 16),

                if (!(_serverInfo!['is_channel'] == true && _serverInfo!['public_channel_token'] != null)) ...[
                  const SecurityWarningCard(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
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
                                AppLocalizations.of(context).identityVisible,
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
                                    '${AppLocalizations.of(context).usernameLabel}: ',
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
                      AppLocalizations.of(context).passwordLabel,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).passwordLabel,
                        labelStyle: TextStyle(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.7)),
                        prefixIcon: Icon(Icons.lock_outline,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: SettingsManager.getElementColor(
                                colorScheme.surfaceContainerHighest, brightness)
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.15),
                              width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.15),
                              width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: colorScheme.primary, width: 1.4),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.6)),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).noPasswordForChannels,
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
                ] else ...[
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).noRegistrationRequired,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (!_infoLoaded)
                FilledButton.icon(
                  onPressed: _loading ? null : _fetchInfo,
                  icon: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_loading ? AppLocalizations.of(context).connecting : AppLocalizations.of(context).connectBtn),
                )
              else
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
                        child: Text(AppLocalizations.of(context).back),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _connect,
                        icon: _loading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_serverInfo?['is_channel'] == true && _serverInfo?['public_channel_token'] != null
                                ? Icons.visibility
                                : Icons.login),
                        label: Text(_loading
                            ? AppLocalizations.of(context).connecting
                            : (_serverInfo?['is_channel'] == true && _serverInfo?['public_channel_token'] != null ? AppLocalizations.of(context).view : AppLocalizations.of(context).join)),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context).cancel),
              ),
            ],
          ),
        ),
          ),
        );
      },
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dns, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info['group_name'] ?? info['name'] ?? 'Unknown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              Text(
                '$_parsedHost:$_parsedPort',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              if ((info['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(info['description'], style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.8))),
              ],
              if ((info['motd'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(info['motd'], style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
              const Divider(height: 12),
              _infoRow(AppLocalizations.of(context).serverInfoGroups, '${info['groups_count'] ?? 0}'),
              _infoRow(AppLocalizations.of(context).serverInfoMembers, '${info['total_members'] ?? 0}'),
              _infoRow(AppLocalizations.of(context).serverInfoMedia, '${info['media_provider'] ?? 'none'}'),
              _infoRow(AppLocalizations.of(context).serverInfoMaxFile, '${info['max_file_size_mb'] ?? 0} MB'),
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
          Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}