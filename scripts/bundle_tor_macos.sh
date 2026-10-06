#!/usr/bin/env bash
# Puts the Tor Expert Bundle into a built ONYX.app and re-signs it.
#
#   scripts/bundle_tor_macos.sh <path/to/ONYX.app> [codesign identity]
#
# Run it after `flutter build macos` (the .app is under
# build/macos/Build/Products/Release/). The identity defaults to "-" (ad-hoc,
# fine for local use); for distribution pass your "Developer ID Application: ..."
# identity, then notarize the result as usual.
#
# Expects macos/tor/arm64/ and macos/tor/x86_64/ -- one extracted Expert Bundle
# "tor" folder per architecture (the "tor" binary plus the libevent dylib and
# pluggable_transports/ that ship next to it). Both go into the app; the app
# picks the one that fits the Mac at run time (see packages/onyx_tor/README.md).
# It deliberately isn't an Xcode build phase: a binary dropped into Resources
# after the app was signed breaks the signature, so the app has to be signed
# again once Tor is inside it, and that is this script's last step.
set -euo pipefail

APP="${1:?usage: $0 <path/to/ONYX.app> [codesign identity]}"
IDENT="${2:--}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/macos/tor"
DEST="$APP/Contents/Resources/tor"
ENTITLEMENTS="$ROOT/macos/Runner/Release.entitlements"

[ -d "$APP" ] || { echo "error: $APP is not an app bundle" >&2; exit 1; }
[ -f "$SRC/arm64/tor" ] || [ -f "$SRC/x86_64/tor" ] || { echo "error: no tor under $SRC/arm64 or $SRC/x86_64 -- see packages/onyx_tor/README.md" >&2; exit 1; }

# A timestamp is only available for real identities, not ad-hoc signing.
TS="--timestamp"
[ "$IDENT" = "-" ] && TS="--timestamp=none"

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$SRC" "$DEST"
find "$DEST" -type f -name tor -exec chmod +x {} \;
# Downloaded files carry a quarantine flag that makes Gatekeeper refuse them.
xattr -cr "$DEST" || true

# Nested code first (libraries, then executables), the app last.
find "$DEST" -type f -name '*.dylib' -print0 |
  while IFS= read -r -d '' f; do
    codesign --force --options runtime $TS -s "$IDENT" "$f"
  done
find "$DEST" -type f -perm -u+x ! -name '*.dylib' -print0 |
  while IFS= read -r -d '' f; do
    codesign --force --options runtime $TS -s "$IDENT" "$f"
  done

# Putting files into Resources invalidated the app's own signature.
codesign --force --deep --options runtime $TS \
  --entitlements "$ENTITLEMENTS" -s "$IDENT" "$APP"

codesign --verify --deep --strict "$APP"
echo "ok: Tor bundled into $APP and the app was re-signed ($IDENT)"
