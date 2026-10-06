// Opens a UDP port on the home router (UPnP IGD) so a direct call can get
// through when the other side is behind a mobile carrier's NAT.
//
// Why this is needed: mobile carriers put phones behind carrier-grade NAT
// that hands out a new public port for every destination ("symmetric" NAT).
// The port a phone learns from a STUN server is then useless to anyone
// else, and the usual hole punching between it and a home router fails --
// WebRTC falls back to the relay (Tor). A normal app fixes that with its
// own TURN server; we have none. But if the *home* side asks its router to
// forward a fixed public port to WebRTC's socket, that port accepts packets
// from anywhere, so the phone can reach it whatever its NAT does, and the
// replies go back along the path the phone's own packets opened.
//
// Only IGD v1/v2 WANIPConnection / WANPPPConnection over SSDP + SOAP: what
// practically every consumer router speaks (when UPnP is on, which it
// usually is by default). Everything here is best-effort and silent.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;

class UpnpMapping {
  final String externalIp;
  final int externalPort;
  final String internalIp;
  final int internalPort;
  const UpnpMapping(
      this.externalIp, this.externalPort, this.internalIp, this.internalPort);
}

class _Gateway {
  final Uri controlUrl;
  final String serviceType;
  final String localIp; // our address on the router's LAN
  const _Gateway(this.controlUrl, this.serviceType, this.localIp);
}

class UpnpPortMapper {
  UpnpPortMapper._();
  static final UpnpPortMapper instance = UpnpPortMapper._();

  // The gateway rarely changes; one discovery per few minutes is plenty.
  Future<_Gateway?>? _gateway;
  DateTime _gatewayAt = DateTime.fromMillisecondsSinceEpoch(0);

  final _rng = Random();

  /// Forwards a public UDP port on the router to [internalIp]:[internalPort] and
  /// returns the mapping, or null if there's no UPnP router, it refused, or
  /// the router's own WAN address isn't public (double NAT / CGNAT at home
  /// too -- a mapping wouldn't be reachable from outside then).
  Future<UpnpMapping?> map(String internalIp, int internalPort) async {
    try {
      final gw = await _discover();
      if (gw == null) return null;
      if (gw.localIp != internalIp) return null; // not the router's LAN
      final ext = await _externalIp(gw);
      if (ext == null || !_isPublic(ext)) {
        debugPrint('[upnp] router WAN address $ext is not public, skipping');
        return null;
      }
      // Same port first (some routers only allow that), then random ones.
      final ports = [
        internalPort,
        for (var i = 0; i < 3; i++) 20000 + _rng.nextInt(40000),
      ];
      for (final port in ports) {
        for (final lease in const [3600, 0]) {
          final code = await _addMapping(gw, port, internalPort, lease);
          if (code == 0) {
            debugPrint('[upnp] mapped $ext:$port -> $internalIp:$internalPort');
            return UpnpMapping(ext, port, internalIp, internalPort);
          }
          // 725 OnlyPermanentLeasesSupported -> retry with lease 0.
          if (code != 725) break;
        }
      }
    } catch (e) {
      debugPrint('[upnp] map failed: $e');
    }
    return null;
  }

  Future<void> unmap(UpnpMapping m) async {
    try {
      final gw = await _discover();
      if (gw == null) return;
      await _soap(gw, 'DeletePortMapping', {
        'NewRemoteHost': '',
        'NewExternalPort': '${m.externalPort}',
        'NewProtocol': 'UDP',
      });
    } catch (_) {}
  }

  Future<_Gateway?> _discover() {
    final now = DateTime.now();
    if (_gateway == null || now.difference(_gatewayAt).inMinutes >= 5) {
      _gatewayAt = now;
      _gateway = _discoverNow().catchError((_) => null);
    }
    return _gateway!;
  }

  Future<_Gateway?> _discoverNow() async {
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final locations = <String>{};
    final done = Completer<void>();
    final sub = sock.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final dg = sock.receive();
      if (dg == null) return;
      final text = latin1.decode(dg.data, allowInvalid: true);
      final m = RegExp(r'^location:\s*(\S+)', caseSensitive: false, multiLine: true)
          .firstMatch(text);
      if (m != null && locations.add(m.group(1)!) && !done.isCompleted) {
        // Give other answers a moment, then go.
        Timer(const Duration(milliseconds: 300), () {
          if (!done.isCompleted) done.complete();
        });
      }
    });
    final dest = InternetAddress('239.255.255.250');
    for (final st in const [
      'urn:schemas-upnp-org:device:InternetGatewayDevice:1',
      'urn:schemas-upnp-org:device:InternetGatewayDevice:2',
    ]) {
      final msg = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: $st\r\n\r\n';
      sock.send(latin1.encode(msg), dest, 1900);
    }
    await done.future
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    await sub.cancel();
    sock.close();

    for (final loc in locations) {
      final gw = await _gatewayFrom(Uri.parse(loc));
      if (gw != null) return gw;
    }
    debugPrint('[upnp] no IGD found');
    return null;
  }

  Future<_Gateway?> _gatewayFrom(Uri location) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      try {
        final req = await client.getUrl(location);
        final res = await req.close().timeout(const Duration(seconds: 3));
        final xml = await res
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 3));
        // Our own LAN address as the router sees it: the local end of the
        // connection we just made to it.
        final local = await _localIpTowards(location);
        if (local == null) return null;
        final base = RegExp(r'<URLBase>\s*([^<\s]+)\s*</URLBase>')
                .firstMatch(xml)
                ?.group(1) ??
            location.toString();
        for (final svc in RegExp(r'<service>([\s\S]*?)</service>')
            .allMatches(xml)) {
          final body = svc.group(1)!;
          final type = RegExp(r'<serviceType>\s*([^<\s]+)\s*</serviceType>')
              .firstMatch(body)
              ?.group(1);
          if (type == null ||
              !(type.contains('WANIPConnection') ||
                  type.contains('WANPPPConnection'))) {
            continue;
          }
          final ctl = RegExp(r'<controlURL>\s*([^<\s]+)\s*</controlURL>')
              .firstMatch(body)
              ?.group(1);
          if (ctl == null) continue;
          return _Gateway(Uri.parse(base).resolve(ctl), type, local);
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('[upnp] bad IGD description at $location: $e');
    }
    return null;
  }

  static Future<String?> _localIpTowards(Uri location) async {
    try {
      final s = await Socket.connect(location.host, location.port,
          timeout: const Duration(seconds: 2));
      final ip = s.address.address;
      s.destroy();
      return ip;
    } catch (_) {}
    // Fallback: our interface on the router's /24.
    try {
      final target = InternetAddress(location.host);
      for (final ni in await NetworkInterface.list(
          type: InternetAddressType.IPv4)) {
        for (final a in ni.addresses) {
          final x = a.rawAddress, t = target.rawAddress;
          if (x[0] == t[0] && x[1] == t[1] && x[2] == t[2]) return a.address;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _externalIp(_Gateway gw) async {
    final res = await _soap(gw, 'GetExternalIPAddress', const {});
    if (res == null || res.$1 != 200) return null;
    return RegExp(r'<NewExternalIPAddress>\s*([^<\s]+)\s*<')
        .firstMatch(res.$2)
        ?.group(1);
  }

  /// 0 on success, the UPnP error code otherwise (-1 if unknown).
  Future<int> _addMapping(
      _Gateway gw, int extPort, int intPort, int lease) async {
    final res = await _soap(gw, 'AddPortMapping', {
      'NewRemoteHost': '',
      'NewExternalPort': '$extPort',
      'NewProtocol': 'UDP',
      'NewInternalPort': '$intPort',
      'NewInternalClient': gw.localIp,
      'NewEnabled': '1',
      'NewPortMappingDescription': 'Onyx call',
      'NewLeaseDuration': '$lease',
    });
    if (res == null) return -1;
    if (res.$1 == 200) return 0;
    final code = RegExp(r'<errorCode>\s*(\d+)\s*<').firstMatch(res.$2)?.group(1);
    return int.tryParse(code ?? '') ?? -1;
  }

  Future<(int, String)?> _soap(
      _Gateway gw, String action, Map<String, String> args) async {
    final params = args.entries
        .map((e) => '<${e.key}>${_xmlEscape(e.value)}</${e.key}>')
        .join();
    final body = '<?xml version="1.0"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="${gw.serviceType}">$params</u:$action>'
        '</s:Body></s:Envelope>';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.postUrl(gw.controlUrl);
      req.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      req.headers.set('SOAPAction', '"${gw.serviceType}#$action"');
      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);
      final res = await req.close().timeout(const Duration(seconds: 4));
      final text = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 4));
      return (res.statusCode, text);
    } catch (e) {
      debugPrint('[upnp] $action failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static bool _isPublic(String ip) {
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((x) => x == null)) return false;
    final a = p[0]!, b = p[1]!;
    if (a == 10 || a == 127 || a == 0) return false;
    if (a == 172 && b >= 16 && b <= 31) return false;
    if (a == 192 && b == 168) return false;
    if (a == 169 && b == 254) return false;
    if (a == 100 && b >= 64 && b <= 127) return false; // CGNAT
    return true;
  }
}
