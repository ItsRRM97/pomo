package com.recoskyler.pomo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.recoskyler.pomo/timer_notification"
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkAndRequestNotificationPermission()
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    val granted = checkAndRequestNotificationPermission()
                    result.success(granted)
                }
                "startForeground" -> {
                    checkAndRequestNotificationPermission()
                    val title = call.argument<String>("title") ?: "Focus Timer"
                    val text = call.argument<String>("text") ?: "25:00"
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    TimerForegroundService.startService(this, title, text, isRunning)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Focus Timer"
                    val text = call.argument<String>("text") ?: "25:00"
                    val isRunning = call.argument<Boolean>("isRunning") ?: true
                    TimerForegroundService.updateService(this, title, text, isRunning)
                    result.success(true)
                }
                "stopForeground" -> {
                    TimerForegroundService.stopService(this)
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
    }

    override fun onDestroy() {
        TimerForegroundService.actionListener = null
        methodChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
