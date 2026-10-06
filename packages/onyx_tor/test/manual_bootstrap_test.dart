// Manual, network-touching smoke test -- not part of CI, just used to
// verify the hand-rolled control-port/SOCKS5 client actually round-trips
// against a real tor binary before wiring it into the app. Run with:
//   flutter test test/manual_bootstrap_test.dart
// with a `tor` binary reachable per tor_bootstrap.dart's _resolveBinaryPath
// (i.e. next to the flutter_tester executable, or just rely on it finding
// nothing and skip -- this file is deliberately not part of the default
// `flutter test` run for that reason, see the directory it lives in).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyx_tor/onyx_tor.dart';

void main() {
  test('hidden service self round-trip over a real tor daemon', () async {
    final tmp = await Directory.systemTemp.createTemp('onyx_tor_test_');
    addTearDown(() => tmp.delete(recursive: true));

    final tor = OnyxTor();
    final logs = <String>[];
    final inboundHandles = <int>[];
    // Subscribed before startHiddenService, not after dialing -- the
    // broadcast events stream drops anything emitted before a listener is
    // attached, and an inbound connection can arrive as soon as the hidden
    // service is up.
    tor.events.listen((e) {
      if (e['type'] == 'log') logs.add('${e['message']}');
      if (e['type'] == 'inbound') inboundHandles.add(e['handle'] as int);
    });

    print('starting hidden service (state_dir=${tmp.path})...');
    final rc = await tor.startHiddenService(tmp.path, 9191).timeout(
      const Duration(seconds: 120),
    );
    print('startHiddenService rc=$rc');
    for (final l in logs) {
      print('  $l');
    }
    expect(rc, 0);

    final address = await tor.hsAddress();
    print('my address: $address');
    expect(address, isNotNull);
    expect(address, endsWith('.onion'));

    // Descriptor propagation can take a little while even after bootstrap.
    int? handle;
    for (var attempt = 0; attempt < 8 && handle == null; attempt++) {
      if (attempt > 0) {
        print('dial attempt $attempt failed, retrying...');
        await Future.delayed(const Duration(seconds: 10));
      }
      handle = await tor.dial(address!, 9191);
      if (handle != null && handle < 1) handle = null;
    }
    expect(handle, isNotNull, reason: 'could not dial our own onion address');

    final message = utf8.encode('hello over tor');
    final written = await tor.streamWrite(handle!, Uint8List.fromList(message));
    print('wrote $written bytes');
    expect(written, message.length);

    // Wait for the inbound event on our own listener and read it back --
    // it may already have arrived (collected into inboundHandles above)
    // by the time we get here, since it can land as early as the SOCKS
    // CONNECT reply itself.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (inboundHandles.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    expect(inboundHandles, isNotEmpty, reason: 'no inbound event arrived');
    final inboundHandle = inboundHandles.first;

    final result = await tor.streamRead(inboundHandle, 65536, 10000);
    print('read n=${result.n}');
    expect(result.n, message.length);
    expect(utf8.decode(result.data!), 'hello over tor');

    await tor.streamClose(handle);
    await tor.streamClose(inboundHandle);
    await tor.stopHiddenService();
    print('done, state dir was ${tmp.path}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
