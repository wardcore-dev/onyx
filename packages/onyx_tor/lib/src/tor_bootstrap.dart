// Boots a real tor daemon and hands back its control/SOCKS ports plus a
// stream of bootstrap-progress events, in a way that's identical from the
// caller's point of view on every platform:
//   - Windows/Linux/macOS/Android: `tor` runs as a genuine OS subprocess
//     (Process.start), so it can never compete with this app's own UI
//     thread for CPU/scheduler time the way the old in-process
//     arti-client/FFI design did.
//   - iOS: subprocesses are forbidden by the sandbox, full stop -- Apple
//     gives no way around this, no matter the Tor implementation chosen.
//     Tor.framework instead runs the real C tor implementation in-process
//     on its own background thread (exactly what Onion Browser and
//     Orbot-apple already ship), configured with the same
//     ControlPort/SocksPort flags as everywhere else.
//
// Either way, once tor is listening, every platform is controlled through
// the exact same Tor control-port protocol over a plain TCP socket on
// 127.0.0.1 -- see tor_control_client.dart. That shared control layer, not
// "which binary", is what actually fixes the freeze: a separate OS process
// (or, on iOS, one background thread doing well-optimized, 20-years-tuned C
// crypto instead of a fresh Rust async runtime) simply cannot starve the
// Flutter engine's own threads of scheduler time the way the previous
// design did.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'tor_control_client.dart';
import 'windows_job_object.dart' as win_job;

class TorBootstrapException implements Exception {
  final String message;
  TorBootstrapException(this.message);
  @override
  String toString() => 'TorBootstrapException: $message';
}

class TorBootstrapResult {
  final int socksPort;
  final int controlPort;
  final TorControlClient control;
  final Process? process; // null on iOS (in-process, no subprocess exists)
  const TorBootstrapResult({
    required this.socksPort,
    required this.controlPort,
    required this.control,
    required this.process,
  });
}

class TorBootstrap {
  static const _channel = MethodChannel('onyx_tor');

  /// Starts (or, if already running under this [dataDir], reuses) tor and
  /// waits for it to finish talking to the network (`Bootstrapped 100%`,
  /// reported over the control port's STATUS_CLIENT events -- the same
  /// signal Tor Browser's own UI waits on). [onBootstrapProgress] is called
  /// with 0-100 as that percentage advances, so the caller can show real
  /// progress instead of an indefinite spinner.
  static Future<TorBootstrapResult> start({
    required String dataDir,
    void Function(int percent)? onBootstrapProgress,
    void Function(String line)? onLog,
  }) async {
    await Directory(dataDir).create(recursive: true);

    // Tor keeps a "state" file directly under DataDirectory and refuses to
    // start ("is not a file? Failing.") if something else already occupies
    // that name -- e.g. a stray directory left behind by an older, no
    // longer used on-disk layout for this same dataDir. Clear it so a
    // leftover from a previous version of this plugin can't permanently
    // brick tor for this install.
    final stateEntity = FileSystemEntity.typeSync(p.join(dataDir, 'state'));
    if (stateEntity != FileSystemEntityType.notFound &&
        stateEntity != FileSystemEntityType.file) {
      onLog?.call(
          'clearing stale non-file "state" entry ($stateEntity) in $dataDir');
      try {
        await Directory(p.join(dataDir, 'state')).delete(recursive: true);
      } catch (_) {}
    }

    final cookiePath = p.join(dataDir, 'control_auth_cookie');

    // A tor left over from an earlier run of the app (the app was swiped
    // away / killed, so nothing stopped its child) still holds the lock on
    // this data directory, and the new tor would die with "another Tor
    // process is running with the same data directory".
    await _killStaleTor(dataDir, onLog);

    final socksPort = await _findFreePort();
    final controlPort = await _findFreePort();

    Process? process;
    if (Platform.isIOS) {
      final ok = await _channel.invokeMethod<bool>('startEmbeddedTor', {
        'dataDir': dataDir,
        'socksPort': socksPort,
        'controlPort': controlPort,
      });
      if (ok != true) {
        throw TorBootstrapException('Tor.framework failed to start');
      }
    } else {
      final binaryPath = await _resolveBinaryPath();
      onLog?.call('launching tor: $binaryPath');
      // The Linux Expert Bundle's tor finds libssl/libcrypto/libevent only
      // through LD_LIBRARY_PATH (Tor Browser's own launcher script sets it);
      // they sit right next to the binary.
      final binDir = p.dirname(binaryPath);
      final env = <String, String>{};
      if (Platform.isLinux &&
          File(p.join(binDir, 'libevent-2.1.so.7')).existsSync()) {
        final old = Platform.environment['LD_LIBRARY_PATH'];
        env['LD_LIBRARY_PATH'] =
            (old == null || old.isEmpty) ? binDir : '$binDir:$old';
      }
      process = await Process.start(binaryPath, [
        // A pure CLI flag (no torrc, no value) -- unlike every other
        // option here, which are torrc-style "--Name value" config
        // overrides. Passing it as "--IgnoreMissingTorrc 1" (i.e. as if it
        // took a value) makes tor reject it outright as an unknown option.
        '--ignore-missing-torrc',
        '--SocksPort', '127.0.0.1:$socksPort',
        '--ControlPort', '127.0.0.1:$controlPort',
        '--CookieAuthentication', '1',
        '--CookieAuthFile', cookiePath,
        '--DataDirectory', dataDir,
        // tor exits by itself once this process is gone, so a killed app
        // can't leave an orphaned tor behind (Windows additionally has the
        // job object below; Android/Linux/macOS have nothing else).
        '--__OwningControllerProcess', '$pid',
        '--ClientOnly', '0',
        '--RunAsDaemon', '0',
      ], environment: env);
      // tor's own stdout is chatty -- 40-60+ lines during a single
      // bootstrap is normal. Piping every line through [onLog] (which
      // callers wire to a visible, synchronously-printed app log) used to
      // mean 40-60+ synchronous debugPrint calls on the UI isolate in the
      // few seconds it takes tor to bootstrap, which is exactly the kind
      // of many-small-synchronous-calls pattern that can visibly stutter
      // frame scheduling even though no single call blocks for long. tor's
      // raw output instead goes straight to its own log file -- still
      // fully available for diagnosing a stuck bootstrap, just off the
      // path that touches the UI isolate on every line.
      final rawLog = File(p.join(dataDir, 'tor.log')).openWrite(
        mode: FileMode.append,
      );
      // Errors/warnings also go through onLog (not just the file): stdout
      // is chatty (40-60+ lines/bootstrap, too much for the UI isolate --
      // see above), but a crash or bind failure is exactly what onLog's
      // caller needs to see live, and those lines are rare.
      final problemPattern = RegExp(r'\[(warn|err)\]', caseSensitive: false);
      process.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        rawLog.writeln('[out] $line');
        if (problemPattern.hasMatch(line)) onLog?.call('tor: $line');
      });
      process.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        rawLog.writeln('[err] $line');
        onLog?.call('tor stderr: $line');
      });
      unawaited(process.exitCode.then((_) => rawLog.close()));

      if (Platform.isWindows) {
        // Best-effort: guarantees tor.exe dies with us even if we're
        // killed abruptly (crash, Task Manager, logoff) and never get to
        // run our own graceful-shutdown code. Not fatal if it fails.
        if (!win_job.killChildOnParentExit(process.pid)) {
          onLog?.call(
              'warning: could not attach tor.exe to a job object -- it '
              'may survive an abrupt app exit');
        }
      }
    }

    final control = await TorControlClient.connect(controlPort);
    await control.authenticateWithCookie(cookiePath);
    await control.setEvents(['STATUS_CLIENT']);

    final bootstrapped = Completer<void>();
    String? lastTag;
    control.events.listen((reply) {
      for (final line in reply.lines) {
        if (!line.contains('BOOTSTRAP')) continue;
        // Which step it's on, and -- when it's stuck -- tor's own reason
        // (a "STATUS_CLIENT WARN BOOTSTRAP ... WARNING=... REASON=..."
        // event: clock skew, connection refused, no route...). Without this
        // a stalled bootstrap only ever showed up as "50%" and silence.
        final tag = RegExp(r'TAG=(\S+)').firstMatch(line)?.group(1);
        if (line.contains(' WARN ') || line.contains('REASON=')) {
          onLog?.call('bootstrap problem: $line');
        } else if (tag != null && tag != lastTag) {
          lastTag = tag;
          final summary =
              RegExp(r'SUMMARY="([^"]*)"').firstMatch(line)?.group(1) ?? '';
          onLog?.call('bootstrap step: $tag $summary');
        }
        final match = RegExp(r'PROGRESS=(\d+)').firstMatch(line);
        if (match != null) {
          final percent = int.parse(match.group(1)!);
          onBootstrapProgress?.call(percent);
          if (percent >= 100 && !bootstrapped.isCompleted) {
            bootstrapped.complete();
          }
        }
      }
    });

    // Bootstrap can legitimately take well over a minute on a cold cache,
    // a congested network, or a path needing several guard-node retries --
    // observed taking up to ~3 minutes in the field, which a 90s timeout
    // cut off right as it was about to succeed (bootstrap hit 100% moments
    // after the old timeout fired). 240s gives real slow-network bootstraps
    // room to finish instead of being killed right before completion.
    await bootstrapped.future.timeout(
      const Duration(seconds: 240),
      onTimeout: () =>
          throw TorBootstrapException('tor did not finish bootstrapping in time'),
    );

    return TorBootstrapResult(
      socksPort: socksPort,
      controlPort: controlPort,
      control: control,
      process: process,
    );
  }

  /// Stops any tor process that was started with [dataDir] as its
  /// DataDirectory (not ours: we haven't started one yet). Best-effort.
  static Future<void> _killStaleTor(
      String dataDir, void Function(String line)? log) async {
    if (Platform.isWindows || Platform.isIOS) return; // job object / in-process
    final victims = <int>[];
    try {
      if (Platform.isLinux || Platform.isAndroid) {
        await for (final entry in Directory('/proc').list(followLinks: false)) {
          final id = int.tryParse(p.basename(entry.path));
          if (id == null || id == pid) continue;
          try {
            final raw = await File('/proc/$id/cmdline').readAsBytes();
            final args = utf8.decode(raw, allowMalformed: true).split('\u0000');
            final i = args.indexOf('--DataDirectory');
            if (i >= 0 && i + 1 < args.length && args[i + 1] == dataDir) {
              victims.add(id);
            }
          } catch (_) {
            // Not ours / already gone / unreadable: not a leftover of ours.
          }
        }
      } else if (Platform.isMacOS) {
        final r = await Process.run('ps', ['-axo', 'pid=,command=']);
        for (final line in LineSplitter.split(r.stdout.toString())) {
          final t = line.trimLeft();
          final sp = t.indexOf(' ');
          if (sp < 0) continue;
          final id = int.tryParse(t.substring(0, sp));
          if (id == null || id == pid) continue;
          if (t.contains('--DataDirectory $dataDir')) victims.add(id);
        }
      }
    } catch (e) {
      log?.call('leftover tor scan failed: $e');
      return;
    }
    if (victims.isEmpty) return;

    for (final id in victims) {
      log?.call('stopping leftover tor (pid $id) still using $dataDir');
      Process.killPid(id, ProcessSignal.sigterm);
    }
    // Wait for them to go (sigcont only reports whether the pid still exists).
    var alive = List<int>.of(victims);
    for (var i = 0; i < 20 && alive.isNotEmpty; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      alive = [for (final id in alive) if (Process.killPid(id, ProcessSignal.sigcont)) id];
    }
    for (final id in alive) {
      log?.call('leftover tor (pid $id) ignored sigterm, killing it');
      Process.killPid(id, ProcessSignal.sigkill);
    }
    if (alive.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  static Future<int> _findFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  /// A checkout / archive that went through a filesystem without Unix modes
  /// (e.g. Windows) loses the execute bit; without it Process.start fails
  /// with EACCES. Best effort -- harmless if the file is already executable
  /// or lives somewhere read-only.
  static Future<void> _ensureExecutable(String path) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['u+x', path]);
    } catch (_) {}
  }

  static Future<String> _resolveBinaryPath() async {
    if (Platform.isAndroid) {
      final nativeLibDir =
          await _channel.invokeMethod<String>('getNativeLibraryDir');
      if (nativeLibDir == null) {
        throw TorBootstrapException(
            'could not determine Android nativeLibraryDir');
      }
      final dir = Directory(nativeLibDir);
      if (await dir.exists()) {
        await for (final entry in dir.list()) {
          final name = p.basename(entry.path).toLowerCase();
          if (entry is File && name.contains('tor') && name.endsWith('.so')) {
            return entry.path;
          }
        }
      }
      throw TorBootstrapException(
          'no libtor*.so found under $nativeLibDir -- check the '
          'info.guardianproject:tor-android dependency is applied');
    }

    // Desktop: a `tor` (or `tor.exe`) binary bundled alongside the app
    // executable -- see packages/onyx_tor/README.md for exactly where to
    // place it per platform and how to fetch/verify it. This deliberately
    // does not fall back to silently downloading a binary at runtime: a
    // tor binary is security-sensitive supply-chain material and belongs
    // under the same code-signing/review process as the rest of the app.
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = <String>[];
    if (Platform.isWindows) {
      candidates.add(p.join(exeDir, 'tor', 'tor.exe'));
    } else if (Platform.isMacOS) {
      // Contents/MacOS/<exe> -> Contents/Resources/tor/<arch>/tor. The Expert
      // Bundle is per-architecture, so both are shipped; an x86_64 tor also
      // runs on Apple Silicon (Rosetta), the other way round it can't.
      final res = p.join(exeDir, '..', 'Resources', 'tor');
      final appleSilicon = Platform.version.contains('arm64');
      if (appleSilicon) candidates.add(p.join(res, 'arm64', 'tor'));
      candidates.add(p.join(res, 'x86_64', 'tor'));
      candidates.add(p.join(res, 'tor'));
      candidates.add(p.join(exeDir, 'tor', 'tor'));
    } else if (Platform.isLinux) {
      candidates.add(p.join(exeDir, 'tor', 'tor'));
      candidates.add('/usr/bin/tor');
      candidates.add('/usr/sbin/tor');
    }
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        await _ensureExecutable(candidate);
        return candidate;
      }
    }
    throw TorBootstrapException(
        'no tor binary found (looked in: ${candidates.join(', ')}). '
        'See packages/onyx_tor/README.md to bundle one.');
  }
}
