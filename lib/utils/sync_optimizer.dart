// lib/utils/sync_optimizer.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class SyncOptimizer {
  static final SyncOptimizer _instance = SyncOptimizer._internal();
  
  static final Map<String, _CachedResponse> _responseCache = {};
  
  static final Map<String, Future<http.Response>> _inFlightRequests = {};
  
  static final Map<String, List<Map<String, dynamic>>> _requestBatches = {};
  static final Map<String, Timer> _batchTimers = {};
  
  static const int _cacheExpirationMs = 2000; 
  static const int _batchDelayMs = 50; 
  static const int _maxBatchSize = 50; 

  factory SyncOptimizer() => _instance;

  SyncOptimizer._internal();

  static Future<http.Response> deduplicatedGet(
    String url, {
    Map<String, String>? headers,
  }) async {
    
    final cached = _responseCache[url];
    if (cached != null && !cached.isExpired) {
      return cached.response;
    }

    final inFlight = _inFlightRequests[url];
    if (inFlight != null) {
      return await inFlight;
    }

    final future = http.get(
      Uri.parse(url),
      headers: headers,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => http.Response('Timeout', 408),
    );

    _inFlightRequests[url] = future;

    try {
      final response = await future;
      
      if (response.statusCode == 200) {
        _responseCache[url] = _CachedResponse(
          response: response,
          timestamp: DateTime.now(),
        );
      }
      
      return response;
    } finally {
      _inFlightRequests.remove(url);
    }
  }

  static Future<http.Response> batchedPost(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
    int delayMs = _batchDelayMs,
  }) async {
    final batchKey = '$url:${headers.toString()}';
    
    _requestBatches.putIfAbsent(batchKey, () => []);
    _requestBatches[batchKey]!.add(body);

    if (_requestBatches[batchKey]!.length >= _maxBatchSize) {
      return _flushBatch(url, batchKey, headers);
    }

    _batchTimers[batchKey]?.cancel();
    _batchTimers[batchKey] = Timer(
      Duration(milliseconds: delayMs),
      () => _flushBatch(url, batchKey, headers),
    );

    return http.Response('Batched', 200);
  }

  static Future<http.Response> _flushBatch(
    String url,
    String batchKey,
    Map<String, String>? headers,
  ) async {
    final batch = _requestBatches.remove(batchKey);
    _batchTimers.remove(batchKey);

    if (batch == null || batch.isEmpty) {
      return http.Response('Empty batch', 400);
    }

    try {
      return await http.post(
        Uri.parse(url),
        headers: headers ?? {},
        body: jsonEncode({'batch': batch}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('Timeout', 408),
      );
    } catch (e) {
      return http.Response('Error: $e', 500);
    }
  }

  static void clearCache() {
    _responseCache.clear();
  }

  static void cleanupExpiredCache() {
    _responseCache.removeWhere((_, cached) => cached.isExpired);
  }

  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedItems': _responseCache.length,
      'inFlightRequests': _inFlightRequests.length,
      'pendingBatches': _requestBatches.length,
    };
  }
}

class _CachedResponse {
  final http.Response response;
  final DateTime timestamp;

  _CachedResponse({
    required this.response,
    required this.timestamp,
  });

  bool get isExpired {
    final now = DateTime.now();
    final age = now.difference(timestamp).inMilliseconds;
    return age > 2000; 
  }
}

class BatchProfileLoader {
  static final BatchProfileLoader _instance = BatchProfileLoader._internal();
  
  final Map<String, Future<Map<String, dynamic>>> _profileCache = {};
  final List<String> _pendingUsernames = [];
  Timer? _batchTimer;
  
  static const int _batchDelayMs = 100; 
  static const int _maxBatchSize = 20; 

  factory BatchProfileLoader() => _instance;

  BatchProfileLoader._internal();

  Future<Map<String, dynamic>?> getProfile(
    String username,
    String Function(List<String>) batchFetcher,
  ) async {
    
    if (_profileCache.containsKey(username)) {
      return await _profileCache[username];
    }

    if (!_pendingUsernames.contains(username)) {
      _pendingUsernames.add(username);
    }

    if (_pendingUsernames.length >= _maxBatchSize) {
      await _flushProfileBatch(batchFetcher);
    } else {
      
      _batchTimer?.cancel();
      _batchTimer = Timer(
        Duration(milliseconds: _batchDelayMs),
        () => _flushProfileBatch(batchFetcher),
      );
    }

    return _profileCache[username];
  }

  Future<void> _flushProfileBatch(
    String Function(List<String>) batchFetcher,
  ) async {
    if (_pendingUsernames.isEmpty) return;

    final toFetch = List<String>.from(_pendingUsernames);
    _pendingUsernames.clear();
    _batchTimer?.cancel();
    _batchTimer = null;

    try {
      final json = batchFetcher(toFetch);
      
    } catch (e) {
      debugPrint('[err] $e');
    }
  }

  void clearCache() {
    _profileCache.clear();
  }
}