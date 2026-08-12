package com.recoskyler.pomo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * After reboot, AlarmManager exact alarms are cleared. Reschedule when the
 * time tracker preference is enabled (A19).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED &&
            intent?.action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            intent?.action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }
        if (HourlyAlarmScheduler.isTimeTrackerEnabled(context)) {
            HourlyAlarmScheduler.scheduleNextHour(context)
        } else {
            HourlyAlarmScheduler.cancel(context)
        }
    }
}
