# onyx_tor

Onion-mode transport for Onyx: a real tor daemon controlled over the
standard [Tor control-port protocol](https://spec.torproject.org/control-spec/index.html),
the same protocol Tor Browser, Orbot, and Briar have driven their bundled
tor binaries through for years.

This replaced an earlier design that embedded `arti-client` (Rust) directly
into the app process via FFI. That design made the Tor bootstrap's
genuinely CPU-heavy cryptography (consensus verification, per-hop ntor
handshakes) compete with Flutter's own UI/raster threads for CPU on the
*same process*, which is what caused the multi-second full-app freeze this
rewrite exists to fix. Now:

- **Windows / Linux / macOS / Android**: `tor` runs as a real, separate OS
  process (`Process.start`), so it physically cannot starve this app's UI
  thread of CPU the way an in-process client could.
- **iOS**: the only platform where a subprocess is impossible at all (the
  sandbox forbids it, for every app, regardless of implementation) --
  `Tor.framework` runs the tor implementation in-process on its own
  background thread instead, the same approach Onion Browser and Orbot's
  iOS app ship in production.

Once tor is listening, every platform is driven through the exact same
Dart control-port client (`lib/src/tor_control_client.dart`) and SOCKS5
dial (`lib/src/tor_socks_client.dart`) -- there is no more per-platform
Dart logic beyond "how do I get a tor process/thread running."

## Bundling the `tor` binary (Windows / Linux / macOS)

This package deliberately does **not** download a `tor` binary at build or
run time. A tor binary is security-sensitive supply-chain material (it's
what actually anonymizes your users) and belongs under the same
code-signing/review process as the rest of the app, not fetched silently.

1. Download the official **Tor Expert Bundle** for your platform from
   <https://www.torproject.org/download/tor/> (or
   `https://archive.torproject.org/tor-package-archive/torbrowser/<version>/`
   for a specific pinned version).
2. Verify it against the signed checksum file Tor Project publishes
   alongside it (`sha256sums-signed-build.txt`) before doing anything else
   with it.
3. Place the extracted `tor` folder (containing `tor`/`tor.exe` and its
   `pluggable_transports/` directory) next to the built app executable:
   - **Windows**: `<build output dir>\tor\tor.exe`
     (i.e. sits next to `ONYX.exe`, so e.g.
     `build\windows\x64\runner\Release\tor\tor.exe`). Wire this into the
     Windows packaging/installer step so it ends up there in every build,
     not just a local dev copy.
   - **Linux**: put the whole extracted `tor` folder at `linux/tor/`
     (the `tor` binary AND the libraries and `pluggable_transports/` next to
     it; keep them together). `linux/CMakeLists.txt` then copies it to
     `<bundle>/tor/tor` on every build (a CMake warning tells you if it is
     missing). Without it the app falls back to a system-installed `tor`
     (`/usr/bin/tor`, `/usr/sbin/tor`). Prefer bundling: distro packages of
     tor can be confined by AppArmor (Debian/Ubuntu's `system_tor` profile)
     and then refuse to run with ONYX's own data directory.
   - **macOS**: the Expert Bundle is per architecture, so extract the
     `tor` folder of each into `macos/tor/arm64/` and `macos/tor/x86_64/`
     (each with its libevent dylib and `pluggable_transports/`). After
     `flutter build macos` run
     `scripts/bundle_tor_macos.sh <path to ONYX.app> [codesign identity]`:
     it copies both into `Contents/Resources/tor/`, signs every binary and
     then re-signs the app (copying files in invalidates the app's own
     signature, which is why this isn't an Xcode build phase). At run time
     the app picks `arm64` on Apple Silicon and `x86_64` otherwise. Use your
     "Developer ID Application" identity for anything you distribute, then
     notarize as usual.

     Currently vendored: Tor Browser **15.0.24** Expert Bundles (Linux
     x86_64, macOS arm64 + x86_64; tor 0.4.9.13), fetched from
     dist.torproject.org and verified against `sha256sums-signed-build.txt`,
     whose signature was checked with the Tor Browser Developers signing key
     (EF6E 286D DA85 EA2A 4BA7 DE68 4E2C 6E87 9329 8290) obtained from
     torproject.org's own WKD. All three platforms now carry the same tor (0.4.9.13).
     Linux ARM64 has no Expert Bundle: those machines need a system `tor`.

## Android

No manual step: `android/build.gradle` depends on
`info.guardianproject:tor-android` (the same prebuilt tor binary Orbot
itself ships), and Gradle unpacks its `libtor.so` into this app's
`ApplicationInfo.nativeLibraryDir` automatically like any other native
dependency. `OnyxTorPlugin.kt` only reports that directory back to Dart.

## iOS

`ios/onyx_tor.podspec` depends on the `Tor` CocoaPod
([iCepa/Tor.framework](https://github.com/iCepa/Tor.framework)) -- running
`pod install` in `ios/` (which `flutter pub get` triggers automatically)
pulls in the precompiled `tor.xcframework`. No manual binary handling
needed here either.

## Persistent `.onion` identity

The hidden service's Ed25519 private key is written to
`<stateDir>/hs_ed25519_key_blob` on first `startHiddenService` call and
reused on every later call with the same `stateDir`, so the `.onion`
address stays stable across app restarts. It is **not** currently folded
into `BackupService`'s account-export zip (`lib/services/backup/backup_service.dart`)
-- reinstalling the app or restoring a backup on a new device currently
mints a fresh `.onion` address and paired contacts would need to re-pair.
Wiring this file into the existing backup format is a deliberate follow-up,
not done as part of this rewrite.

## Manual smoke test

`test/manual_bootstrap_test.dart` starts a real hidden service, dials its
own address over the live Tor network, and confirms a message round-trips
byte-for-byte. It needs a real network connection and a `tor` binary
reachable per the rules above (e.g. next to whichever `flutter_tester`
binary `flutter test` uses), and can take 1-2 minutes (Tor bootstrap +
descriptor propagation), so it isn't part of the default `flutter test`
run:

```sh
flutter test test/manual_bootstrap_test.dart
```
