// lib/utils/cert_pinning.dart
import 'dart:io';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:flutter/foundation.dart';
import 'proxy_manager.dart';

const String kPinnedHost = 'api-onyx.wardcore.com';

const String kPinnedCertSha256 = ''; 

void applyCertPinning() {
  if (kPinnedCertSha256.isEmpty) {
    debugPrint('[cert-pin] DISABLED — fill in kPinnedCertSha256 to enable');
    return;
  }
  
  HttpOverrides.global = _CertPinningOverrides(ProxyManager.lastApplied);
  debugPrint('[cert-pin] Enabled — pinning $kPinnedHost');
}

class _CertPinningOverrides extends HttpOverrides {
  final HttpOverrides? _wrapped;
  _CertPinningOverrides(this._wrapped);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    
    final pinnedCtx = SecurityContext(withTrustedRoots: false);

    final wrapped = _wrapped;
    final HttpClient client = wrapped != null
        ? wrapped.createHttpClient(pinnedCtx)
        : super.createHttpClient(pinnedCtx);

    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      
      if (host != kPinnedHost) return true;

      final actualFp =
          dart_crypto.sha256.convert(cert.der).toString();

      if (actualFp == kPinnedCertSha256) {
        return true; 
      }

      debugPrint('[cert-pin]  REJECTED connection to $host:$port');
      debugPrint('[cert-pin]    Expected : $kPinnedCertSha256');
      debugPrint('[cert-pin]    Got      : $actualFp');
      debugPrint('[cert-pin]    → Update kPinnedCertSha256 if cert was renewed.');
      return false; 
    };

    return client;
  }
}