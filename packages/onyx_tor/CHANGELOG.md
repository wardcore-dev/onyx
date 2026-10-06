## 0.0.2

* Replaced the in-process arti-client/FFI/cargokit implementation with a
  real tor daemon controlled over the standard control-port protocol --
  subprocess on Windows/Linux/macOS/Android, Tor.framework (in-process,
  since iOS forbids subprocesses) on iOS. Fixes the multi-second UI freeze
  the old design caused by running Tor's bootstrap crypto on the same
  process as the Flutter engine. Public `OnyxTor` API is unchanged.

## 0.0.1

* TODO: Describe initial release.
