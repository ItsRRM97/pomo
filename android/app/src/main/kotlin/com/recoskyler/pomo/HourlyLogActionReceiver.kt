package com.recoskyler.pomo

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/**
 * One-tap shade action for `Log 60m Work` (A21).
 *
 * Queues the payload so Dart can persist the hourly log even if the UI is not
 * in the foreground, then forwards to Flutter when a MethodChannel is live.
 */
class HourlyLogActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION) return
        val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: return
        HourlyAlarmScheduler.enqueuePendingInstantWrite(context, payload)
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(TimerForegroundService.HOURLY_NOTIFICATION_ID)
        Handler(Looper.getMainLooper()).post {
            MainActivity.notifyDartNotificationTap(payload)
        }
    }

    companion object {
        const val ACTION = "com.recoskyler.pomo.ACTION_HOURLY_INSTANT_WRITE"
        const val EXTRA_PAYLOAD = "pomo_notification_payload"
    }
}
