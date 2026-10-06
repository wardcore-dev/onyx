// lib/utils/tor_routing.dart
//
// Routes HTTP / WebSocket traffic through the local Tor daemon's SOCKS port
// for the hosts that must never see the user's real IP:
//   * every external group/channel server (ExternalServerManager.torHosts),
//   * any *.onion host.
// Everything else (LAN sync, update checks, ...) is left alone and goes
// through whatever HttpOverrides were installed before this one (cert
// pinning, if enabled), exactly as before.
//
// Fail-closed: if a Tor-routed host is requested while Tor isn't up yet, the
// request throws instead of silently going out directly.
//
// Hosts of the long-gone central server (and the public-IP lookup it used)
// are refused outright, so no leftover code path can reach them.
//
// Installed as HttpOverrides.global, so it also covers package:http, image
// loading and dart:io WebSocket connections, all of which create their
// HttpClient through the overrides.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:socks5_proxy/socks_client.dart';

import '../managers/external_server_manager.dart';
import '../services/onion/onion_identity.dart';

class TorRouting {
  TorRouting._();

  /// Hosts that must not be contacted at all.
  static const Set<String> blockedHosts = {
    'api-onyx.wardcore.com',
    'api.ipify.org',
  };

  /// Where Tor's SOCKS port comes from; swapped out in tests.
  @visibleForTesting
  static int? Function() socksPort = () => OnionIdentity.plugin.socksPort;

  static bool usesTor(String host) {
    final h = host.toLowerCase();
    if (h.endsWith('.onion')) return true;
    // A server on the user's own network (or this machine) can't be reached
    // from a Tor exit at all, and there's no real IP to hide from it.
    if (isLocalHost(h)) return false;
    return ExternalServerManager.torHosts.contains(h);
  }

  /// localhost, *.local, and IP literals in loopback / private / link-local
  /// ranges.
  static bool isLocalHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
      return true;
    }
    final addr = InternetAddress.tryParse(h);
    if (addr == null) return false;
    if (addr.isLoopback || addr.isLinkLocal) return true;
    final b = addr.rawAddress;
    if (addr.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168);
    }
    // IPv6 unique-local fc00::/7
    return b.isNotEmpty && (b[0] & 0xFE) == 0xFC;
  }

  static bool isBlocked(String host) =>
      blockedHosts.contains(host.toLowerCase());

  /// Wraps whatever HttpOverrides are currently installed. Safe to call any
  /// number of times; call it again after anything that replaces
  /// HttpOverrides.global (cert pinning does).
  static void install() {
    final current = HttpOverrides.current;
    if (current is _TorRoutingOverrides) return;
    HttpOverrides.global = _TorRoutingOverrides(current);
  }
}

/// Plain overrides: produces the stock dart:io client, never recursing into
/// the global overrides.
class _PlainOverrides extends HttpOverrides {}

class _TorRoutingOverrides extends HttpOverrides {
  final HttpOverrides? _inner;
  _TorRoutingOverrides(this._inner);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final direct = _inner != null
        ? _inner.createHttpClient(context)
        : _PlainOverrides().createHttpClient(context);
    return _RoutingHttpClient(direct, context);
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    final inner = _inner;
    if (inner != null) return inner.findProxyFromEnvironment(url, environment);
    return super.findProxyFromEnvironment(url, environment);
  }
}

/// An HttpClient that hands each request to either the normal ("direct")
/// client or a second client whose connections go through Tor's SOCKS port.
class _RoutingHttpClient implements HttpClient {
  final HttpClient _direct;
  final SecurityContext? _context;

  HttpClient? _tor;
  int? _torPort;

  // Client-wide settings, remembered so the Tor client gets the same ones.
  Duration _idleTimeout = const Duration(seconds: 15);
  Duration? _connectionTimeout;
  int? _maxConnectionsPerHost;
  bool _autoUncompress = true;
  String? _userAgent;

  _RoutingHttpClient(this._direct, this._context) {
    _idleTimeout = _direct.idleTimeout;
    _connectionTimeout = _direct.connectionTimeout;
    _maxConnectionsPerHost = _direct.maxConnectionsPerHost;
    _autoUncompress = _direct.autoUncompress;
    _userAgent = _direct.userAgent;
  }

  HttpClient _torClient() {
    final port = TorRouting.socksPort();
    if (port == null) {
      throw const SocketException('Tor is not ready yet');
    }
    var client = _tor;
    if (client == null || _torPort != port) {
      // First use, or tor restarted on a different port.
      client?.close();
      client = _PlainOverrides().createHttpClient(_context);
      SocksTCPClient.assignToHttpClient(
        client,
        [ProxySettings(InternetAddress.loopbackIPv4, port)],
      );
      client
        ..idleTimeout = _idleTimeout
        ..connectionTimeout = _connectionTimeout
        ..maxConnectionsPerHost = _maxConnectionsPerHost
        ..autoUncompress = _autoUncompress
        ..userAgent = _userAgent;
      _tor = client;
      _torPort = port;
    }
    return client;
  }

  HttpClient _pick(String host) {
    if (TorRouting.isBlocked(host)) {
      throw SocketException('Connections to $host are disabled');
    }
    return TorRouting.usesTor(host) ? _torClient() : _direct;
  }

  // ── requests ──────────────────────────────────────────────────────────────

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      _guard(host, (c) => c.open(method, host, port, path));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _guard(url.host, (c) => c.openUrl(method, url));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _guard(host, (c) => c.get(host, port, path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      _guard(url.host, (c) => c.getUrl(url));

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _guard(host, (c) => c.post(host, port, path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      _guard(url.host, (c) => c.postUrl(url));

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _guard(host, (c) => c.put(host, port, path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) =>
      _guard(url.host, (c) => c.putUrl(url));

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _guard(host, (c) => c.delete(host, port, path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) =>
      _guard(url.host, (c) => c.deleteUrl(url));

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _guard(host, (c) => c.patch(host, port, path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) =>
      _guard(url.host, (c) => c.patchUrl(url));

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _guard(host, (c) => c.head(host, port, path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) =>
      _guard(url.host, (c) => c.headUrl(url));

  /// Picks the client and turns a synchronous refusal (blocked host, Tor not
  /// up) into a failed Future, like any other connection error.
  Future<HttpClientRequest> _guard(
      String host, Future<HttpClientRequest> Function(HttpClient) run) async {
    final HttpClient client;
    try {
      client = _pick(host);
    } on SocketException catch (e) {
      return Future<HttpClientRequest>.error(e);
    }
    return run(client);
  }

  // ── settings ──────────────────────────────────────────────────────────────

  @override
  Duration get idleTimeout => _idleTimeout;
  @override
  set idleTimeout(Duration v) {
    _idleTimeout = v;
    _direct.idleTimeout = v;
    _tor?.idleTimeout = v;
  }

  @override
  Duration? get connectionTimeout => _connectionTimeout;
  @override
  set connectionTimeout(Duration? v) {
    _connectionTimeout = v;
    _direct.connectionTimeout = v;
    _tor?.connectionTimeout = v;
  }

  @override
  int? get maxConnectionsPerHost => _maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? v) {
    _maxConnectionsPerHost = v;
    _direct.maxConnectionsPerHost = v;
    _tor?.maxConnectionsPerHost = v;
  }

  @override
  bool get autoUncompress => _autoUncompress;
  @override
  set autoUncompress(bool v) {
    _autoUncompress = v;
    _direct.autoUncompress = v;
    _tor?.autoUncompress = v;
  }

  @override
  String? get userAgent => _userAgent;
  @override
  set userAgent(String? v) {
    _userAgent = v;
    _direct.userAgent = v;
    _tor?.userAgent = v;
  }

  // Proxy / auth / TLS hooks only concern the direct client: the Tor client
  // always tunnels through SOCKS and uses stock certificate checking.

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _direct.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _direct.authenticateProxy = f;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _direct.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _direct.addProxyCredentials(host, port, realm, credentials);

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      _direct.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _direct.findProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _direct.badCertificateCallback = callback;

  @override
  set keyLog(Function(String line)? callback) => _direct.keyLog = callback;

  @override
  void close({bool force = false}) {
    _direct.close(force: force);
    _tor?.close(force: force);
  }
}
