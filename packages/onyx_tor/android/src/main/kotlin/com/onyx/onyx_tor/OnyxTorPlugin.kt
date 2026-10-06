package com.onyx.onyx_tor

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The tor daemon itself now runs as a real Android subprocess (the prebuilt
 * binary from the info.guardianproject:tor-android dependency, the same one
 * Orbot ships), controlled from Dart over the standard Tor control-port
 * protocol -- see packages/onyx_tor/lib/src/tor_process_manager.dart. A
 * subprocess can't touch this app's own UI thread's CPU time the way an
 * in-process Tor client could, which is what this rewrite is for.
 *
 * The only thing pure Dart genuinely cannot do on Android is find the
 * on-disk path of the bundled libtor.so: Gradle unpacks native dependencies
 * into ApplicationInfo.nativeLibraryDir, a path only the Android Context
 * knows. Everything else (writing the tor config, Process.start, talking to
 * the control port) is the exact same Dart code Windows/Linux/macOS use.
 */
class OnyxTorPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "onyx_tor")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "getNativeLibraryDir" -> {
                result.success(binding.applicationContext.applicationInfo.nativeLibraryDir)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
