// lib/utils/onion_names.dart
//
// A contact whose nickname was never set advertises their username, which for
// onion identities is the onion address itself — 56 characters of noise in a
// chat list. These helpers recognise that case and shorten it.

final RegExp _addressLike = RegExp(r'^[a-z2-7]{16,56}(\.onion)?$');

// MasterIdentity.accountId: SHA-256 hex. It is what a peer advertises when it
// has no cached nickname, so it must not be mistaken for a real name.
final RegExp _accountIdLike = RegExp(r'^[0-9a-f]{32,64}$');

bool looksLikeAccountId(String s) =>
    _accountIdLike.hasMatch(s.trim().toLowerCase());

bool looksLikeOnionAddress(String s) =>
    _addressLike.hasMatch(s.trim().toLowerCase()) || looksLikeAccountId(s);

/// `abcdefgh…uvwxyz.onion` style short form of an onion address.
String compactAddress(String addr) {
  final a = addr.trim();
  if (looksLikeAccountId(a)) return '${a.substring(0, 8)}…${a.substring(a.length - 4)}';
  final host = a.endsWith('.onion') ? a.substring(0, a.length - 6) : a;
  if (host.length <= 16) return a;
  return '${host.substring(0, 8)}…${host.substring(host.length - 6)}.onion';
}

/// Name to show for a contact: their nickname, or a compact address when the
/// "name" is really just the address.
String friendlyContactName(String name) =>
    looksLikeOnionAddress(name) ? compactAddress(name) : name;
