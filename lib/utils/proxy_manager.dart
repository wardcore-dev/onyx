import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../managers/settings_manager.dart';
import 'global_log_collector.dart';

enum ProxyType { none, http, socks5 }

void _proxyLog(String message) {
  debugPrint('[proxy] $message');
  globalLogs.log(message, category: 'PROXY');
}

class ProxyManager {
  
  static HttpOverrides? _lastApplied;

  static HttpOverrides? get lastApplied => _lastApplied;

  static bool pendingApplyOnConnect = false;

  static void deferToFirstConnect() {
    pendingApplyOnConnect = true;
    HttpOverrides.global = null;
    _lastApplied = null;
    _proxyLog('Proxy deferred — will apply after first direct connection');
  }

  static void applyFromSettings() {
    if (!SettingsManager.proxyEnabled.value) {
      HttpOverrides.global = null;
      _lastApplied = null;
      _proxyLog('Proxy disabled — direct connection');
      return;
    }

    final host = SettingsManager.proxyHost.value.trim();
    final portStr = SettingsManager.proxyPort.value.trim();
    final port = int.tryParse(portStr) ?? 0;

    if (host.isEmpty || port <= 0) {
      HttpOverrides.global = null;
      _proxyLog('Proxy config invalid (host=$host port=$port) — direct connection');
      return;
    }

    final typeStr = SettingsManager.proxyType.value;
    final type =
        typeStr == 'socks5' ? ProxyType.socks5 : ProxyType.http;

    final username = SettingsManager.proxyUsername.value.trim();
    final password = SettingsManager.proxyPassword.value;

    final override = _ProxyHttpOverrides(
      type: type,
      host: host,
      port: port,
      username: username.isNotEmpty ? username : null,
      password: username.isNotEmpty ? password : null,
    );
    HttpOverrides.global = override;
    _lastApplied = override;

    _proxyLog(
      'Proxy applied: ${typeStr.toUpperCase()} $host:$port'
      '${username.isNotEmpty ? ' (auth: $username)' : ''}',
    );
  }

  static void reset() {
    HttpOverrides.global = null;
    _lastApplied = null;
    _proxyLog('Proxy reset — direct connection');
  }

  static Future<(bool, String)> testConnection() async {
    if (!SettingsManager.proxyEnabled.value) {
      return (false, 'Proxy is disabled');
    }

    final host = SettingsManager.proxyHost.value.trim();
    final portStr = SettingsManager.proxyPort.value.trim();
    final port = int.tryParse(portStr) ?? 0;

    if (host.isEmpty || port <= 0) {
      return (false, 'Host or port is empty');
    }

    applyFromSettings();

    _proxyLog('Testing connection via $host:$port ...');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final request = await client.getUrl(
        Uri.parse('https://api-onyx.wardcore.com/health'),
      );
      request.headers.set('Connection', 'close');
      final response = await request.close();
      await response.drain<void>();
      client.close();

      _proxyLog('Test OK — HTTP ${response.statusCode} via $host:$port');
      return (true, 'Connected (HTTP ${response.statusCode})');
    } on SocketException catch (e) {
      _proxyLog('Test FAILED — SocketException: ${e.message}');
      return (false, 'Connection failed: ${e.message}');
    } on HandshakeException catch (e) {
      
      _proxyLog('Test OK (TLS handshake) — proxy tunnel reachable via $host:$port');
      return (true, 'Proxy reachable (TLS: ${e.message})');
    } catch (e) {
      _proxyLog('Test ERROR — $e');
      return (false, e.toString());
    }
  }
}

class _ProxyHttpOverrides extends HttpOverrides {
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;

  _ProxyHttpOverrides({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    switch (type) {
      case ProxyType.http:
        client.findProxy = (uri) {
          debugPrint('[proxy] → ${uri.scheme.toUpperCase()} ${uri.host} via PROXY $host:$port');
          return 'PROXY $host:$port';
        };
        if (username != null && username!.isNotEmpty) {
          client.addProxyCredentials(
            host,
            port,
            'Basic',
            HttpClientBasicCredentials(username!, password ?? ''),
          );
        }
      case ProxyType.socks5:
        final proxyAddr = InternetAddress.tryParse(host) ?? InternetAddress.loopbackIPv4;
        SocksTCPClient.assignToHttpClient(client, [
          ProxySettings(proxyAddr, port),
        ]);
        debugPrint('[proxy] SOCKS5 assigned to HttpClient: $host:$port');
      case ProxyType.none:
        client.findProxy = (uri) => 'DIRECT';
    }

    return client;
  }
}