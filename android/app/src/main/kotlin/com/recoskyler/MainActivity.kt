package com.recoskyler.pomo

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.recoskyler.pomo/timer_notification"
    private var methodChannel: MethodChannel? = null

    /// Cold-start safe store; Dart pulls via [getPendingNotificationPayload].
    private var pendingNotificationPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureNotificationPayload(intent)
        checkAndRequestNotificationPermission()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Warm path: handler is usually already registered.
        forwardNotificationPayload(intent)
    }

    private fun checkAndRequestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
                return false
            }
        }
        return true
    }

    private fun captureNotificationPayload(intent: Intent?) {
        val payload = intent?.getStringExtra("pomo_notification_payload") ?: return
        pendingNotificationPayload = payload
    }

    private fun forwardNotificationPayload(intent: Intent?) {
        val payload = intent?.getStringExtra("pomo_notification_payload") ?: return
        pendingNotificationPayload = payload
        Handler(Looper.getMainLooper()).post {
            methodChannel?.invokeMethod("onNotificationTap", payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureNotificationPayload(intent)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    val granted = checkAndRequestNotificationPermission()
                    result.success(granted)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val ignoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                        if (!ignoring) {
                            try {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "getPendingNotificationPayload" -> {
                    val payload = pendingNotificationPayload
                    pendingNotificationPayload = null
                    result.success(payload)
                }
                "startForeground" -> {
                    checkAndRequestNotificationPermission()
                    val title = call.argument<String>("title") ?: "Focus Timer"
                    val text = call.argument<String>("text") ?: "25:00"
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    val isHourly = call.argument<Boolean>("isHourly") ?: (title.contains("Time Tracker") || title.contains("Check-in"))
                    val payload = call.argument<String>("payload")
                    TimerForegroundService.startService(this, title, text, isRunning, isHourly, payload)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Focus Timer"
                    val text = call.argument<String>("text") ?: "25:00"
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    val isHourly = call.argument<Boolean>("isHourly") ?: (title.contains("Time Tracker") || title.contains("Check-in"))
                    val payload = call.argument<String>("payload")
                    TimerForegroundService.updateService(this, title, text, isRunning, isHourly, payload)
                    result.success(true)
                }
                "stopForeground" -> {
                    TimerForegroundService.stopService(this)
                    result.success(true)
                }
                "scheduleNextHourlyAlarm" -> {
                    val enableTracker = call.argument<Boolean>("enableTimeTracker") ?: true
                    val enableQuiet = call.argument<Boolean>("enableQuietHours") ?: true
                    val quietStart = call.argument<String>("quietHoursStart") ?: "23:00"
                    val quietEnd = call.argument<String>("quietHoursEnd") ?: "07:00"
                    HourlyAlarmScheduler.syncTrackerPrefs(
                        this,
                        enableTracker,
                        enableQuiet,
                        quietStart,
                        quietEnd,
                    )
                    if (!enableTracker) {
                        HourlyAlarmScheduler.cancel(this)
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    val triggerAt = call.argument<Number>("triggerAtMillis")?.toLong()
                    if (triggerAt != null) {
                        HourlyAlarmScheduler.schedule(this, triggerAt)
                    } else {
                        HourlyAlarmScheduler.scheduleNextHour(this)
                    }
                    result.success(true)
                }
                "cancelHourlyAlarms" -> {
                    HourlyAlarmScheduler.setTimeTrackerEnabled(this, false)
                    HourlyAlarmScheduler.cancel(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        TimerForegroundService.actionListener = { action ->
            Handler(Looper.getMainLooper()).post {
                methodChannel?.invokeMethod(action, null)
            }
        }
        // Cold start: do not push onNotificationTap on a fixed delay. Dart pulls
        // via getPendingNotificationPayload after setMethodCallHandler.
    }

    override fun onDestroy() {
        TimerForegroundService.actionListener = null
        methodChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
