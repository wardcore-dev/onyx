import Flutter
import UIKit
import Tor

/// iOS is the one platform in this app where tor genuinely cannot run as a
/// subprocess -- the sandbox forbids spawning arbitrary executables, full
/// stop. Tor.framework instead links the real C tor implementation into
/// this process and runs it on its own background thread (TORThread), which
/// is exactly what Onion Browser and Orbot's iOS app already ship in
/// production. This plugin's only job is booting that thread with the same
/// ControlPort/SocksPort/DataDirectory flags the desktop subprocess uses --
/// once it's listening on 127.0.0.1, the Dart-side control-port client is
/// byte-for-byte the same code as every other platform.
public class OnyxTorPlugin: NSObject, FlutterPlugin {
  private var thread: TORThread?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "onyx_tor", binaryMessenger: registrar.messenger())
    let instance = OnyxTorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "startEmbeddedTor":
      guard let args = call.arguments as? [String: Any],
            let dataDir = args["dataDir"] as? String,
            let socksPort = args["socksPort"] as? Int,
            let controlPort = args["controlPort"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "dataDir/socksPort/controlPort required", details: nil))
        return
      }

      if thread != nil {
        // Already started for this process lifetime; tor doesn't support a
        // clean re-start once its background thread is running, and the app
        // process is what actually goes away on iOS backgrounding limits
        // anyway (see the offline-queue design, not this plugin).
        result(true)
        return
      }

      let config = TORConfiguration()
      config.cookieAuthentication = true
      config.dataDirectory = URL(fileURLWithPath: dataDir)
      config.arguments = [
        "--ignore-missing-torrc",
        "--ControlPort", "127.0.0.1:\(controlPort)",
        "--SocksPort", "127.0.0.1:\(socksPort)",
        "--ClientOnly", "0",
      ]

      let newThread = TORThread(configuration: config)
      newThread.start()
      thread = newThread
      // Dart connects to the control port itself and waits for the
      // bootstrap events (SETEVENTS STATUS_CLIENT) -- there is nothing
      // further to await here, starting the thread is fire-and-forget just
      // like Process.start on desktop.
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
