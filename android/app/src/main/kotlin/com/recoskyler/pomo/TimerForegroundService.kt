package com.recoskyler.pomo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.graphics.Color
import androidx.core.app.NotificationCompat

/**
 * Focus Timer foreground service (FGS) plus hourly shade helpers.
 *
 * Sticky policy:
 * - Timer FGS uses [TIMER_NOTIFICATION_ID] / [CHANNEL_ID], ongoing while a
 *   session is active. [START_NOT_STICKY]: if the OS kills the service, do not
 *   auto-restart without Dart session state.
 * - Hourly check-ins use [HOURLY_NOTIFICATION_ID] / [HOURLY_CHANNEL_ID]
 *   (IMPORTANCE_HIGH). They are shade notifications only (not FGS), so they
 *   never replace the timer tile and can be posted from [HourlyAlarmReceiver]
 *   without a running Dart isolate.
 */
class TimerForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "pomo_timer_channel_v2"
        const val HOURLY_CHANNEL_ID = "hourly_tracker"
        const val TIMER_NOTIFICATION_ID = 1001
        const val HOURLY_NOTIFICATION_ID = 1002

        /** @deprecated Prefer [TIMER_NOTIFICATION_ID]; kept for call-site clarity. */
        const val NOTIFICATION_ID = TIMER_NOTIFICATION_ID

        const val ACTION_START = "ACTION_START"
        const val ACTION_UPDATE = "ACTION_UPDATE"
        const val ACTION_STOP_SERVICE = "ACTION_STOP_SERVICE"
        const val ACTION_PLAY = "ACTION_PLAY"
        const val ACTION_PAUSE = "ACTION_PAUSE"
        const val ACTION_STOP = "ACTION_STOP"

        var actionListener: ((String) -> Unit)? = null

        fun startService(
            context: Context,
            title: String,
            text: String,
            isRunning: Boolean,
            isHourly: Boolean = false,
            payload: String? = null,
        ) {
            // Hourly is shade-only; never hijack the timer FGS notification.
            if (isHourly) {
                postHourlyNotification(context, title, text, payload)
                return
            }
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_START
                putExtra("title", title)
                putExtra("text", text)
                putExtra("isRunning", isRunning)
                putExtra("isHourly", false)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    context.startForegroundService(intent)
                } catch (e: Exception) {
                    // D5: Android 16 may throw ForegroundServiceStartNotAllowedException
                    // when starting from the background. Fall back to a plain notification.
                    postTimerFallbackNotification(context, title, text)
                }
            } else {
                context.startService(intent)
            }
        }

        /**
         * Posts the hourly check-in shade notification (ID 1002).
         * Safe from [HourlyAlarmReceiver] with no Dart isolate.
         */
        fun postHourlyNotification(
            context: Context,
            title: String,
            text: String,
            payload: String?,
        ) {
            ensureChannels(context)
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (payload != null) {
                    putExtra("pomo_notification_payload", payload)
                }
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 0, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val coffeeColor = Color.parseColor("#8D6E63")
            val builder = NotificationCompat.Builder(context, HOURLY_CHANNEL_ID)
                .setContentTitle(text)
                .setContentText(title)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setColor(coffeeColor)
                .setContentIntent(openAppPendingIntent)
                .setOngoing(false)
                .setAutoCancel(true)
                .setOnlyAlertOnce(false)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSubText("Hourly Tracker")
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
            if (payload != null) {
                builder.addAction(
                    0,
                    "Log 60m Work",
                    pendingHourlyAction(context, payload, "log_work", 10),
                )
                builder.addAction(
                    0,
                    "Switch Tag",
                    pendingHourlyAction(context, payload, "switch_tag", 11),
                )
                builder.addAction(
                    0,
                    "Open Grid",
                    pendingHourlyAction(context, payload, "open_grid", 12),
                )
            }
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(HOURLY_NOTIFICATION_ID, builder.build())
        }

        private fun postTimerFallbackNotification(
            context: Context,
            title: String,
            text: String,
        ) {
            ensureChannels(context)
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 0, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val coffeeColor = Color.parseColor("#8D6E63")
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(text)
                .setContentText(title)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setColor(coffeeColor)
                .setContentIntent(openAppPendingIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSubText("Focus Timer")
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(TIMER_NOTIFICATION_ID, builder.build())
        }

        private fun pendingHourlyAction(
            context: Context,
            basePayload: String,
            action: String,
            requestCode: Int,
        ): PendingIntent {
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("pomo_notification_payload", "$basePayload:$action")
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    ?: return
            manager.deleteNotificationChannel("pomo_timer_channel")
            val timerChannel = NotificationChannel(
                CHANNEL_ID,
                "Focus Timer",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows active Focus Pomodoro countdown"
                setShowBadge(true)
            }
            val hourlyChannel = NotificationChannel(
                HOURLY_CHANNEL_ID,
                "Hourly Tracker",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Hourly check-in reminders for time tracking"
                setShowBadge(true)
                enableVibration(true)
            }
            manager.createNotificationChannel(timerChannel)
            manager.createNotificationChannel(hourlyChannel)
        }

        fun updateService(
            context: Context,
            title: String,
            text: String,
            isRunning: Boolean,
            isHourly: Boolean = false,
            payload: String? = null,
        ) {
            if (isHourly) {
                postHourlyNotification(context, title, text, payload)
                return
            }
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra("title", title)
                putExtra("text", text)
                putExtra("isRunning", isRunning)
                putExtra("isHourly", false)
            }
            context.startService(intent)
        }

        fun stopService(context: Context) {
            val intent = Intent(context, TimerForegroundService::class.java).apply {
                action = ACTION_STOP_SERVICE
            }
            context.startService(intent)
        }
    }

    private var currentTitle: String = "Focus Timer"
    private var currentText: String = "25:00"
    private var isCurrentlyRunning: Boolean = true

    override fun onCreate() {
        super.onCreate()
        ensureChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_START -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentText = intent.getStringExtra("text") ?: currentText
                isCurrentlyRunning = intent.getBooleanExtra("isRunning", true)
                startForegroundNotification()
            }
            ACTION_UPDATE -> {
                currentTitle = intent.getStringExtra("title") ?: currentTitle
                currentText = intent.getStringExtra("text") ?: currentText
                isCurrentlyRunning = intent.getBooleanExtra("isRunning", true)
                updateNotification()
            }
            ACTION_PLAY -> {
                actionListener?.invoke("onPlay")
            }
            ACTION_PAUSE -> {
                actionListener?.invoke("onPause")
            }
            ACTION_STOP -> {
                actionListener?.invoke("onStop")
            }
            ACTION_STOP_SERVICE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }

        // Timer FGS is not sticky: restarting without Dart session state would
        // show a stale countdown. Hourly reminders use AlarmManager instead.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val toggleActionIntent = Intent(this, TimerForegroundService::class.java).apply {
            action = if (isCurrentlyRunning) ACTION_PAUSE else ACTION_PLAY
        }
        val togglePendingIntent = PendingIntent.getService(
            this, 1, toggleActionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopActionIntent = Intent(this, TimerForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 2, stopActionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val toggleActionTitle = if (isCurrentlyRunning) "Pause" else "Play"
        val toggleActionIcon = if (isCurrentlyRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play

        val coffeeColor = Color.parseColor("#8D6E63") // Warm coffee / mocha accent color

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentText)
            .setContentText(currentTitle)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setColor(coffeeColor)
            .setColorized(false)
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle(currentText)
                .bigText(currentTitle))
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSubText("Focus Timer")
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .addAction(toggleActionIcon, toggleActionTitle, togglePendingIntent)
            .addAction(android.R.drawable.ic_delete, "Stop", stopPendingIntent)
            .build()
    }

    private fun startForegroundNotification() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var fgsType = 0
            if (Build.VERSION.SDK_INT >= 34) { // Android 14+ / Android 16
                fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            }
            if (fgsType != 0) {
                startForeground(TIMER_NOTIFICATION_ID, notification, fgsType)
            } else {
                startForeground(TIMER_NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(TIMER_NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.notify(TIMER_NOTIFICATION_ID, buildNotification())
    }
}
