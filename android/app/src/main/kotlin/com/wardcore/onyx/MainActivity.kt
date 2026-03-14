package com.wardcore.onyx

import android.content.ClipboardManager
import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "onyx/audio"
    private val CLIPBOARD_CHANNEL = "onyx/clipboard"
    private val TAG = "ONYX_AUDIO"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine called")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                Log.d(TAG, "MethodChannel.onMethodCall -> ${call.method} args=${call.arguments}")
                when (call.method) {
                    "setSpeakerOn" -> {
                        val on = (call.argument<Boolean>("on") ?: false)
                        val ok = setSpeakerphoneOn(on)
                        result.success(ok)
                    }
                    "resetAudioMode" -> {
                        val ok = resetAudioMode()
                        result.success(ok)
                    }
                    else -> {
                        Log.d(TAG, "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getClipboardImage" -> result.success(getClipboardImageBytes())
                    "getClipboardFilePaths" -> result.success(getClipboardFilePaths())
                    "readContentUri" -> {
                        val uri = call.argument<String>("uri")
                        result.success(readContentUri(uri))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getClipboardFilePaths(): List<String> {
        return try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = cm.primaryClip ?: return emptyList()
            if (clip.itemCount == 0) return emptyList()

            val paths = mutableListOf<String>()
            for (i in 0 until clip.itemCount) {
                val item = clip.getItemAt(i)
                val uri = item.uri
                if (uri != null && uri.scheme == "file") {
                    uri.path?.let { paths.add(it) }
                } else {
                    // Try text representation for file:// URIs
                    val text = item.coerceToText(this)?.toString()?.trim()
                    if (text != null) {
                        val parsed = try { Uri.parse(text) } catch (e: Exception) { null }
                        if (parsed?.scheme == "file") {
                            parsed.path?.let { paths.add(it) }
                        }
                    }
                }
            }
            paths
        } catch (e: Exception) {
            Log.e(TAG, "getClipboardFilePaths: $e")
            emptyList()
        }
    }

    private fun getClipboardImageBytes(): ByteArray? {
        return try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = cm.primaryClip ?: return null
            if (clip.itemCount == 0) return null
            val uri = clip.getItemAt(0).uri ?: return null
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            Log.e(TAG, "getClipboardImageBytes: $e")
            null
        }
    }

    private fun readContentUri(uriStr: String?): ByteArray? {
        if (uriStr == null) return null
        return try {
            val uri = Uri.parse(uriStr)
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            Log.e(TAG, "readContentUri: $e")
            null
        }
    }

    private fun setSpeakerphoneOn(on: Boolean): Boolean {
        try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager

            Log.d(TAG, "setSpeakerphoneOn(start) on=$on; current mode=${audioManager.mode}, speaker=${audioManager.isSpeakerphoneOn}")

            if (on) {
                try {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                } catch (e: Exception) {
                    Log.w(TAG, "setSpeakerphoneOn: cannot set mode MODE_IN_COMMUNICATION: $e")
                }
                audioManager.isSpeakerphoneOn = true

                if (audioManager.isBluetoothScoOn) {
                    try {
                        audioManager.stopBluetoothSco()
                        audioManager.isBluetoothScoOn = false
                    } catch (e: Exception) {
                        Log.w(TAG, "stopBluetoothSco failed: $e")
                    }
                }

                Log.d(TAG, "setSpeakerphoneOn -> requested speaker ON; now speaker=${audioManager.isSpeakerphoneOn}, mode=${audioManager.mode}")
            } else {
                try {
                    audioManager.isSpeakerphoneOn = false
                    audioManager.mode = AudioManager.MODE_NORMAL
                } catch (e: Exception) {
                    Log.w(TAG, "setSpeakerphoneOff error: $e")
                }
                Log.d(TAG, "setSpeakerphoneOn -> requested speaker OFF; now speaker=${audioManager.isSpeakerphoneOn}, mode=${audioManager.mode}")
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "setSpeakerphoneOn exception: $e")
            return false
        }
    }

    private fun resetAudioMode(): Boolean {
        try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            Log.d(TAG, "resetAudioMode called. Current mode=${audioManager.mode}, speaker=${audioManager.isSpeakerphoneOn}")

            // Сбрасываем в нормальный режим и выключаем громкую связь
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = false

            // Опционально: отключаем SCO, если вдруг активен
            if (audioManager.isBluetoothScoOn) {
                try {
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                } catch (e: Exception) {
                    Log.w(TAG, "resetAudioMode: stopBluetoothSco failed: $e")
                }
            }

            Log.d(TAG, "resetAudioMode completed. Now mode=${audioManager.mode}, speaker=${audioManager.isSpeakerphoneOn}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "resetAudioMode exception: $e")
            return false
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume")
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        super.onDestroy()
    }
}