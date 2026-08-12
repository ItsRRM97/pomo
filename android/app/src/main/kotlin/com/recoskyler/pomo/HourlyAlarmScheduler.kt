package com.recoskyler.pomo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Schedules / cancels exact RTC_WAKEUP hourly alarms via AlarmManager.
 *
 * Dart [Timer.periodic] is an in-process backup; this is the source of truth
 * when the process is killed or Dozing. BootReceiver reschedules after reboot
 * when the time tracker pref is enabled.
 */
object HourlyAlarmScheduler {
    const val ACTION_HOURLY_ALARM = "com.recoskyler.pomo.ACTION_HOURLY_ALARM"
    private const val REQUEST_CODE = 4201
    /** Dedicated prefs mirrored from Dart (not Flutter SharedPreferences/DataStore). */
    private const val PREFS_NAME = "pomo_hourly_alarm_prefs"
    private const val KEY_ENABLE_TIME_TRACKER = "enable_time_tracker"
    private const val KEY_ENABLE_QUIET_HOURS = "enable_quiet_hours"
    private const val KEY_QUIET_START = "quiet_hours_start"
    private const val KEY_QUIET_END = "quiet_hours_end"

    fun syncTrackerPrefs(
        context: Context,
        enableTimeTracker: Boolean,
        enableQuietHours: Boolean,
        quietHoursStart: String,
        quietHoursEnd: String,
    ) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLE_TIME_TRACKER, enableTimeTracker)
            .putBoolean(KEY_ENABLE_QUIET_HOURS, enableQuietHours)
            .putString(KEY_QUIET_START, quietHoursStart)
            .putString(KEY_QUIET_END, quietHoursEnd)
            .apply()
    }

    fun setTimeTrackerEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_ENABLE_TIME_TRACKER, enabled)
            .apply()
    }

    fun schedule(context: Context, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pending,
            )
        } else {
            @Suppress("DEPRECATION")
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    fun scheduleNextHour(context: Context) {
        if (!isTimeTrackerEnabled(context)) {
            cancel(context)
            return
        }
        schedule(context, nextHourBoundaryMillis(System.currentTimeMillis()))
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context))
    }

    fun isTimeTrackerEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return if (prefs.contains(KEY_ENABLE_TIME_TRACKER)) {
            prefs.getBoolean(KEY_ENABLE_TIME_TRACKER, true)
        } else {
            true
        }
    }

    fun isInQuietHours(context: Context, nowMillis: Long = System.currentTimeMillis()): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = if (prefs.contains(KEY_ENABLE_QUIET_HOURS)) {
            prefs.getBoolean(KEY_ENABLE_QUIET_HOURS, true)
        } else {
            true
        }
        if (!enabled) return false
        val start = prefs.getString(KEY_QUIET_START, "23:00") ?: "23:00"
        val end = prefs.getString(KEY_QUIET_END, "07:00") ?: "07:00"
        return isQuietHours(start, end, nowMillis)
    }

    /** Mirrors SoundHelper.isQuietHours for native alarm gating. */
    fun isQuietHours(start: String, end: String, nowMillis: Long): Boolean {
        val startParts = start.split(":")
        val endParts = end.split(":")
        if (startParts.size != 2 || endParts.size != 2) return false
        val startHour = startParts[0].toIntOrNull() ?: return false
        val startMinute = startParts[1].toIntOrNull() ?: return false
        val endHour = endParts[0].toIntOrNull() ?: return false
        val endMinute = endParts[1].toIntOrNull() ?: return false
        val startMin = startHour * 60 + startMinute
        val endMin = endHour * 60 + endMinute
        if (startMin == endMin) return false
        val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
        val currentMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        return if (startMin < endMin) {
            currentMin >= startMin && currentMin < endMin
        } else {
            currentMin >= startMin || currentMin < endMin
        }
    }

    fun nextHourBoundaryMillis(nowMillis: Long): Long {
        val cal = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.HOUR_OF_DAY, 1)
        }
        return cal.timeInMillis
    }

    /**
     * Completed hour block before [nowMillis] (same as NotificationHelper).
     * Returns hour (0-23) and date yyyy-MM-dd.
     */
    fun completedHourBlock(nowMillis: Long): Pair<Int, String> {
        val cal = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.HOUR_OF_DAY, -1)
        }
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val y = cal.get(Calendar.YEAR)
        val m = (cal.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = cal.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        return hour to "$y-$m-$d"
    }

    fun hourlyPayload(hour: Int, dateYmd: String): String = "hourly:$hour:$dateYmd"

    fun hourlyBody(hour: Int): String {
        val start = hour.toString().padStart(2, '0')
        val end = ((hour + 1) % 24).toString().padStart(2, '0')
        return "Log what you did between $start:00 and $end:00."
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, HourlyAlarmReceiver::class.java).apply {
            action = ACTION_HOURLY_ALARM
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
