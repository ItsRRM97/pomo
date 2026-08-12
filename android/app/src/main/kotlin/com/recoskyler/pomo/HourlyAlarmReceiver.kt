package com.recoskyler.pomo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires at each exact hour boundary. Posts the hourly check-in shade
 * notification (ID 1002) with A4 payload + A3 actions unless quiet hours
 * apply, then reschedules the next hour.
 *
 * Does not require a running Dart isolate or timer FGS.
 */
class HourlyAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != HourlyAlarmScheduler.ACTION_HOURLY_ALARM) {
            return
        }
        if (!HourlyAlarmScheduler.isTimeTrackerEnabled(context)) {
            HourlyAlarmScheduler.cancel(context)
            return
        }

        val now = System.currentTimeMillis()
        if (!HourlyAlarmScheduler.isInQuietHours(context, now)) {
            val (hour, dateYmd) = HourlyAlarmScheduler.completedHourBlock(now)
            val payload = HourlyAlarmScheduler.hourlyPayload(hour, dateYmd)
            val title = "Time Tracker: Check-in Required"
            val text = HourlyAlarmScheduler.hourlyBody(hour)
            TimerForegroundService.postHourlyNotification(
                context,
                title,
                text,
                payload,
            )
        }
        // Always chain the next hour (quiet or not) so Doze does not drop us.
        HourlyAlarmScheduler.scheduleNextHour(context)
    }
}
