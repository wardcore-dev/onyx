// lib/utils/image_loader.dart
//
// Global image loading service. Solves the root causes of slow image display:
//
//   1. Deduplication — if multiple widgets request the same filename
//      concurrently they share one Future instead of doing the work twice.
//
//   2. No platform-channel per call — uses AppPaths (resolved once at startup)
//      instead of getOnyxSupportDirectory() / getOnyxDocumentsDirectory()
//      inside every widget.
//
// Visible loads (load()) are NOT concurrency-capped: an album's thumbnails must
// download as freely as a tapped single photo, or the newest albums sit blurred
// in "preload" on chat open until scrolled. Only bulk background warming
// (preloadOnly()) is throttled, via its own low-concurrency queue.
//
// Usage (widgets):
//   ImageLoader.load(filename, peerUsername: ...).then((entry) { ... });
//
// Usage (preloader — no download):
//   ImageLoader.preloadOnly(filename);
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../managers/external_server_manager.dart';
import '../utils/app_paths.dart';
import '../utils/image_file_cache.dart';
import '../utils/image_size_cache.dart';

class ImageLoader {
  // Bumped every time an entry lands in imageFileCache. A widget still showing
  // the placeholder can listen and re-check the cache, so it displays the file
  // the moment it's available even if its own post-await setState was starved
  // (which happened in favorites with hundreds of thumbnails loading at once).
  static final ValueNotifier<int> cacheRevision = ValueNotifier<int>(0);

  // Pending real-load futures (downloadIfMissing:true) — widgets that need the
  // same file share one Future.
  static final Map<String, Future<ImageFileCacheEntry?>> _pending = {};

  // Concurrency gate for visible load() calls. Opening a chat/favorite with
  // many albums can build hundreds of thumbnails at once; without a cap, all of
  // them run _resolve simultaneously and the event loop is so swamped that the
  // widgets' post-await setState continuations are starved — thumbs sit on the
  // placeholder forever even though the file resolved. The cap is high enough
  // that loads stay fast (each resolve is cheap now) but low enough to leave
  // the event loop free to paint and run those setStates. Preloads are NOT
  // gated here — they have their own _maxPreloadConcurrent queue.
  static const int _maxConcurrent = 8;
  static int _inFlight = 0;
  static final Queue<Completer<void>> _waitQueue = Queue();

  static Future<void> _acquire() async {
    if (_inFlight >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waitQueue.addLast(waiter);
      await waiter.future;
    }
    _inFlight++;
  }

  static void _release() {
    _inFlight--;
    if (_waitQueue.isNotEmpty) _waitQueue.removeFirst().complete();
  }

  // Per-filename listeners. A placeholder widget waiting on one specific file
  // registers here; when that file lands in imageFileCache only its own
  // listeners are invoked. This replaces a global ValueNotifier broadcast that
  // woke EVERY pending widget on every cache insert — O(N²) on a screen with
  // hundreds of thumbnails (favorites, big albums).
  static final Map<String, Set<void Function()>> _fileWaiters = {};

  static void addFileListener(String filename, void Function() cb) {
    (_fileWaiters[filename] ??= <void Function()>{}).add(cb);
  }

  static void removeFileListener(String filename, void Function() cb) {
    final set = _fileWaiters[filename];
    if (set == null) return;
    set.remove(cb);
    if (set.isEmpty) _fileWaiters.remove(filename);
  }

  static void _notifyFile(String filename) {
    final set = _fileWaiters[filename];
    if (set == null || set.isEmpty) return;
    // Copy first — a callback may remove itself (or others) during iteration.
    for (final cb in set.toList()) {
      cb();
    }
  }

  // Filenames with an in-flight/queued preload (downloadIfMissing:false). Kept
  // separate from [_pending] so a real load() never reuses a no-download preload
  // future and mistakenly reports a not-yet-downloaded file as unavailable.
  static final Set<String> _preloadInFlight = {};

  // Background preloads run at a low concurrency through their own queue so they
  // can never flood the event loop / main thread (a chat with 1000 photos would
  // otherwise fire 1000 resolves at once) nor starve the visible images' loads,
  // which run unthrottled on the fast local path.
  static const int _maxPreloadConcurrent = 3;
  static int _preloadRunning = 0;
  // Each queued preload carries whether it needs the metadata header read.
  // Album images render at a fixed size and don't, so they skip it — otherwise
  // opening a chat with a big album reads a 64 KB header per image (thousands
  // at once) and floods the event loop. peer/owner/key are unused for preload
  // (it never downloads) so the filename is enough.
  static final Queue<({String fn, bool meta})> _preloadQueue = Queue();

  // Background WARMING (download+decrypt ahead of view). Unlike preloadOnly,
  // this DOES fetch from the network, so each job carries the peer/owner/key
  // needed to download and decrypt. Runs at a low concurrency of its own so it
  // never starves the visible images' loads. Gated by the caller
  // (ChatImagePreloader) on the user's MediaPreloadMode + connectivity.
  static const int _maxWarmConcurrent = 2;
  static int _warmRunning = 0;
  static final Set<String> _warmInFlight = {};
  static final Queue<
      ({
        String fn,
        String peer,
        String? owner,
        String? key,
        bool meta
      })> _warmQueue = Queue();

  /// Returns true if [filename] is already cached in memory or currently
  /// being loaded / downloaded. Used by ensureMediaCached* to skip duplicates.
  static bool isKnown(String filename) {
    return imageFileCache.containsKey(filename) ||
        _pending.containsKey(filename) ||
        _preloadInFlight.contains(filename) ||
        _warmInFlight.contains(filename);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Full load: resolves from local disk, or downloads if necessary.
  /// Returns the cache entry, or null if the file is unavailable.
  ///
  /// [computeMetadata] reads the image header for the aspect ratio and the file
  /// length. Single photos need the aspect ratio to size their bubble; album
  /// thumbnails render at a fixed size with BoxFit.cover and don't, so they
  /// pass false — otherwise opening a chat fires a 64 KB header read per album
  /// image (often 100+ at once), thrashing storage and leaving the first
  /// albums stuck on the placeholder.
  static Future<ImageFileCacheEntry?> load(
    String filename, {
    String peerUsername = '',
    String? owner,
    String? mediaKeyB64,
    bool computeMetadata = true,
  }) {
    final cached = imageFileCache[filename];
    if (cached != null && cached.file.existsSync()) return Future.value(cached);

    return _pending[filename] ??= _resolve(
      filename,
      peerUsername: peerUsername,
      owner: owner,
      mediaKeyB64: mediaKeyB64,
      downloadIfMissing: true,
      computeMetadata: computeMetadata,
      gated: true,
    ).whenComplete(() => _pending.remove(filename));
  }

  /// Preload: local disk only — never triggers a download.
  /// Fire-and-forget; call from ChatImagePreloader. Queued at low concurrency so
  /// preloading a huge chat never blocks the UI or the visible images' loads.
  /// [computeMetadata] should be false for album images (fixed-size thumbnails
  /// that never use the aspect ratio) so a big album doesn't trigger a header
  /// read per image on chat open.
  static void preloadOnly(String filename, {bool computeMetadata = true}) {
    if (imageFileCache.containsKey(filename)) return;
    if (_pending.containsKey(filename)) return;
    if (_preloadInFlight.contains(filename)) return;
    _preloadInFlight.add(filename);
    _preloadQueue.addLast((fn: filename, meta: computeMetadata));
    _pumpPreload();
  }

  /// Warm: download + decrypt ahead of the widget being built, so the image is
  /// already in [imageFileCache] by the time it scrolls into view. Fire-and-
  /// forget. The caller decides whether warming is allowed (MediaPreloadMode +
  /// connectivity); this just runs the work at a low concurrency.
  static void warm(
    String filename, {
    String peerUsername = '',
    String? owner,
    String? mediaKeyB64,
    bool computeMetadata = true,
  }) {
    // Local-only schemes never download — nothing to warm.
    if (filename.startsWith('fav://') || filename.startsWith('lan://')) return;
    if (isKnown(filename)) return;
    _warmInFlight.add(filename);
    _warmQueue.addLast((
      fn: filename,
      peer: peerUsername,
      owner: owner,
      key: mediaKeyB64,
      meta: computeMetadata,
    ));
    _pumpWarm();
  }

  static void _pumpWarm() {
    while (_warmRunning < _maxWarmConcurrent && _warmQueue.isNotEmpty) {
      final job = _warmQueue.removeFirst();
      // A visible load() may have cached/started it while it sat in the queue.
      if (imageFileCache.containsKey(job.fn) || _pending.containsKey(job.fn)) {
        _warmInFlight.remove(job.fn);
        continue;
      }
      _warmRunning++;
      _resolve(
        job.fn,
        peerUsername: job.peer,
        owner: job.owner,
        mediaKeyB64: job.key,
        downloadIfMissing: true,
        computeMetadata: job.meta,
        gated: false,
      ).whenComplete(() {
        _warmInFlight.remove(job.fn);
        _warmRunning--;
        _pumpWarm();
      });
    }
  }

  static void _pumpPreload() {
    while (_preloadRunning < _maxPreloadConcurrent && _preloadQueue.isNotEmpty) {
      final job = _preloadQueue.removeFirst();
      // A visible load() may have cached it while it sat in the queue.
      if (imageFileCache.containsKey(job.fn)) {
        _preloadInFlight.remove(job.fn);
        continue;
      }
      _preloadRunning++;
      _resolve(job.fn,
              downloadIfMissing: false, computeMetadata: job.meta, gated: false)
          .whenComplete(() {
        _preloadInFlight.remove(job.fn);
        _preloadRunning--;
        _pumpPreload();
      });
    }
  }

  // ── Implementation ────────────────────────────────────────────────────────

  static Future<ImageFileCacheEntry?> _resolve(
    String filename, {
    String peerUsername = '',
    String? owner,
    String? mediaKeyB64,
    required bool downloadIfMissing,
    required bool computeMetadata,
    bool gated = false,
  }) async {
    try {
      await AppPaths.ensureInit();

      // 1) Fast local lookup. Favorites, LAN, already decrypted/cached and
      //    outgoing images resolve instantly. This is ungated on purpose: a
      //    local file resolves in microseconds and must never queue behind a
      //    slow network download. (Previously the whole resolve held the gate,
      //    so on a busy screen cached/local thumbnails sat blurred waiting for
      //    8 downloads+decrypts to finish — that's why even local Favorites
      //    felt slow.)
      File? file = await _resolveLocal(filename);

      // 2) Network download + decrypt — the only expensive part, so ONLY this
      //    runs under the [_acquire]/[_release] gate (visible load()s). Dedup
      //    ([_pending]) still prevents the same file being fetched twice; bulk
      //    background warming stays on the separate preload queue
      //    (downloadIfMissing:false).
      if (file == null && downloadIfMissing) {
        if (gated) await _acquire();
        try {
          file = await _download(
            filename,
            peerUsername: peerUsername,
            owner: owner,
            mediaKeyB64: mediaKeyB64,
          );
        } finally {
          if (gated) _release();
        }
      }

      if (file == null || !await file.exists()) return null;

      // Album thumbnails skip the header read + length stat: they render at a
      // fixed size and never use these, and doing them for every album image on
      // chat open is what choked the load. Single photos (computeMetadata:true)
      // still get an accurate aspect ratio for bubble sizing.
      final double ar = computeMetadata
          ? await ImageSizeCache().getOrComputeAspectRatio(file)
          : 1.0;
      final int size = computeMetadata ? await file.length() : 0;
      final entry = (file: file, size: size, aspectRatio: ar);
      imageFileCache[filename] = entry;
      // Wake only the widgets waiting on THIS file (not every pending widget).
      cacheRevision.value++; // kept for any external listeners (cheap, no-op now)
      _notifyFile(filename);
      // NOTE: BlurHash warming is intentionally NOT done here. This path is also
      // used by the preloader, which warms EVERY image in the chat on open —
      // doing a full decode per image here froze chat opening. BlurHash is now
      // computed only by the visible widgets (bounded by what's actually built).
      return entry;
    } catch (_) {
      return null;
    }
  }

  /// Resolves a file that already exists locally. Returns null if it isn't on
  /// disk yet (caller decides whether to download). Uses async exists() (not
  /// existsSync) so a burst of preloads never blocks the main isolate with
  /// synchronous stat() calls.
  static Future<File?> _resolveLocal(String filename) async {
    if (filename.startsWith('fav://')) {
      final f = File('${AppPaths.favMedia}/${filename.substring(6)}');
      return await f.exists() ? f : null;

    } else if (filename.startsWith('lan://')) {
      final f = File('${AppPaths.lanMedia}/${filename.substring(6)}');
      return await f.exists() ? f : null;

    } else if (filename.startsWith('onion://')) {
      final f = File('${AppPaths.onionMedia}/${filename.substring(8)}');
      return await f.exists() ? f : null;

    } else if (filename.startsWith('file://')) {
      final f = File(filename.substring(7));
      return await f.exists() ? f : null;

    } else if (filename.startsWith('http')) {
      final uri = Uri.parse(filename);
      final rawName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (rawName.isEmpty) return null;
      final safeName = rawName.replaceAll(RegExp(r'[^\w\-.]'), '_');
      final ext = _guessExt(filename) ?? '';
      final f = File('${AppPaths.imageCache}/$safeName$ext');
      return await f.exists() ? f : null;

    } else {
      // Already decrypted to display dir (survives until temp is cleared).
      final displayF = File('${AppPaths.imageDisplay}/$filename');
      if (await displayF.exists()) return displayF;
      // Locally-stored plaintext image (Favorites images, and the sender's own
      // outgoing copies, are written straight into image_cache/<basename>).
      final plainF = File('${AppPaths.imageCache}/$filename');
      if (await plainF.exists()) return plainF;
      return null;
    }
  }

  /// Downloads (and decrypts) a missing image. Ungated — dedup via [_pending]
  /// is the only coordination, so visible album thumbs download as promptly as
  /// single photos instead of queuing behind a global concurrency cap.
  static Future<File?> _download(
    String filename, {
    String peerUsername = '',
    String? owner,
    String? mediaKeyB64,
  }) async {
    if (filename.startsWith('http')) {
      return await _downloadHttp(filename);
    }
    // fav:// / lan:// / file:// never download — they're local-only.
    if (filename.startsWith('fav://') || filename.startsWith('lan://') || filename.startsWith('file://')) {
      return null;
    }
    if (filename.startsWith('onion://')) {
      // Onion media arrives inline over its own Tor stream, sent separately
      // from (and not strictly ordered with) the pointer message that names
      // it -- poll briefly instead of failing immediately, mirroring
      // ImageMessageWidget's onion handling.
      final f = File('${AppPaths.onionMedia}/${filename.substring(8)}');
      for (var i = 0; i < 10 && !(await f.exists()); i++) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return await f.exists() ? f : null;
    }
    final root = rootScreenKey.currentState;
    if (root == null) return null;
    return await root.downloadImageToCache(
      filename,
      peerUsername: peerUsername,
      owner: owner,
      mediaKeyB64: mediaKeyB64,
    );
  }

  static Future<File?> _downloadHttp(String filename) async {
    final uri = Uri.parse(filename);
    final rawName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (rawName.isEmpty) return null;
    final safeName = rawName.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final ext = _guessExt(filename) ?? '';
    final file = File('${AppPaths.imageCache}/$safeName$ext');
    if (file.existsSync()) return file;

    var url = filename;
    if (!url.contains('?token=') && !url.contains('&token=')) {
      final servers = ExternalServerManager.servers.value;
      final match = servers
          .where((s) => s.host == uri.host && s.port == uri.port)
          .firstOrNull;
      if (match != null) url = '$url?token=${Uri.encodeComponent(match.token)}';
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;
    await file.writeAsBytes(res.bodyBytes);
    return file;
  }

  static String? _guessExt(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.gif')) return '.gif';
    if (path.endsWith('.webp')) return '.webp';
    return null;
  }
}
