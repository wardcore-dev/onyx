package com.wardcore.onyx

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Incoming-call notification like Telegram's: Android's CallStyle (12+) with
 * big Accept / Decline buttons, full-screen over the lock screen -- but
 * silent (no ringtone, no vibration on phones). Only used while the app is in the background -- in the
 * foreground the in-app call screen handles it.
 *
 * Accept / tap open MainActivity (a call needs the UI and the mic anyway);
 * Decline goes to [CallActionReceiver] and never brings the app up. Both end
 * up in Dart over [channel] ("onyx/call_notification").
 */
object CallNotifications {
    private const val TAG = "ONYX_CALL"
    const val CHANNEL_ID = "calls_channel_v2"
    const val NOTIF_ID = 47_001

    const val ACTION_ACCEPT = "com.wardcore.onyx.CALL_ACCEPT"
    const val ACTION_DECLINE = "com.wardcore.onyx.CALL_DECLINE"
    const val ACTION_OPEN = "com.wardcore.onyx.CALL_OPEN"
    const val EXTRA_CALL_ID = "call_id"

    /** Set by MainActivity once the Flutter engine is up. */
    @Volatile
    var channel: MethodChannel? = null

    /** An action that arrived before Dart was listening (cold activity). */
    @Volatile
    var pending: Pair<String, String>? = null

    fun deliver(context: Context, action: String, callId: String) {
        val ch = channel
        if (ch == null) {
            pending = action to callId
            return
        }
        android.os.Handler(context.mainLooper).post {
            // Dart may not have registered its handler yet (activity was
            // just created): then it's kept for Dart's 'takePending'.
            pending = action to callId
            try {
                ch.invokeMethod(action, mapOf("callId" to callId),
                    object : MethodChannel.Result {
                        override fun success(r: Any?) {
                            if (pending == action to callId) pending = null
                        }
                        override fun error(c: String, m: String?, d: Any?) {}
                        override fun notImplemented() {}
                    })
            } catch (e: Exception) {
                Log.w(TAG, "deliver $action failed: $e")
            }
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // v1 rang and vibrated; a channel's sound can't be changed once
        // created, so it's replaced rather than edited.
        nm.deleteNotificationChannel("calls_channel_v1")
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        // Silent on purpose (product decision: no ringtone or vibration on
        // phones). Still IMPORTANCE_HIGH, so it pops up as a heads-up with
        // the Accept / Decline buttons and goes full screen when locked.
        val ch = NotificationChannel(CHANNEL_ID, "Calls", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Incoming calls"
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(ch)
    }

    private fun circle(src: Bitmap): Bitmap {
        val size = minOf(src.width, src.height)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawOval(RectF(0f, 0f, size.toFloat(), size.toFloat()), paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val left = (src.width - size) / 2
        val top = (src.height - size) / 2
        canvas.drawBitmap(src, Rect(left, top, left + size, top + size),
            Rect(0, 0, size, size), paint)
        return out
    }

    private fun flags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun show(context: Context, callId: String, name: String, subtitle: String,
             avatar: ByteArray?) {
        ensureChannel(context)

        fun activityIntent(action: String, req: Int): PendingIntent {
            val i = Intent(context, MainActivity::class.java).apply {
                this.action = action
                putExtra(EXTRA_CALL_ID, callId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            return PendingIntent.getActivity(context, req, i, flags())
        }
        val open = activityIntent(ACTION_OPEN, 1)
        val accept = activityIntent(ACTION_ACCEPT, 2)
        val decline = PendingIntent.getBroadcast(
            context, 3,
            Intent(context, CallActionReceiver::class.java).apply {
                action = ACTION_DECLINE
                putExtra(EXTRA_CALL_ID, callId)
            },
            flags()
        )

        val bmp = try {
            avatar?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }?.let { circle(it) }
        } catch (e: Exception) { null }
        val person = Person.Builder()
            .setName(name)
            .setImportant(true)
            .apply { if (bmp != null) setIcon(IconCompat.createWithBitmap(bmp)) }
            .build()

        val b = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(name)
            .setContentText(subtitle)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .setTimeoutAfter(60_000)
            .setStyle(NotificationCompat.CallStyle.forIncomingCall(person, decline, accept))
            .addPerson(person)
        if (bmp != null) b.setLargeIcon(bmp)

        val n = b.build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, n)
        } catch (e: SecurityException) {
            Log.w(TAG, "notify denied: $e") // POST_NOTIFICATIONS not granted
        } catch (e: Exception) {
            Log.w(TAG, "CallStyle notify failed, plain fallback: $e")
            showPlain(context, name, subtitle, open, accept, decline, bmp)
        }
    }

    /** Older devices / OEMs that reject CallStyle: same thing, plain buttons. */
    private fun showPlain(context: Context, name: String, subtitle: String,
                          open: PendingIntent, accept: PendingIntent,
                          decline: PendingIntent, bmp: Bitmap?) {
        val b = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(name)
            .setContentText(subtitle)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .setTimeoutAfter(60_000)
            .addAction(0, "Decline", decline)
            .addAction(0, "Accept", accept)
        if (bmp != null) b.setLargeIcon(bmp)
        val n = b.build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, n)
        } catch (e: Exception) {
            Log.w(TAG, "plain call notify failed: $e")
        }
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIF_ID)
    }
}

/** Decline button: tells Dart and drops the notification, app stays put. */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != CallNotifications.ACTION_DECLINE) return
        CallNotifications.cancel(context)
        val id = intent.getStringExtra(CallNotifications.EXTRA_CALL_ID) ?: ""
        CallNotifications.deliver(context, "decline", id)
    }
}
