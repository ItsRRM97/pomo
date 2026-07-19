import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/web.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/helpers/sound_helper.dart';
import 'package:pomo/services/android_notification_service.dart';
import 'package:pomo/services/local_notification_service.dart';
import 'package:pomo/services/web_pwa_service.dart';
import 'package:pomo/singletons/prefs.dart';

enum TriggerMethod {
  get,
  post,
  put,
  patch,
}

mixin HookHelper {
  static Future<void> postWebHook(
    String? urls, {
    TriggerMethod? method = TriggerMethod.post,
    dynamic data,
  }) async {
    if (!Prefs.enableWebhooks) {
      return;
    }
    if (urls == null || urls.isEmpty) {
      return;
    }

    final urlList = urls
        .split(',')
        .where((url) {
          if (url.isEmpty) {
            return false;
          }

          try {
            Uri.parse(url);
            return true;
          } catch (_) {
            return false;
          }
        })
        .map((e) => e.trim())
        .toList();

    for (final url in urlList) {
      try {
        Logger().d('POSTing webhook to $url');

        final dio = Dio();

        final options = RequestOptions(
          method: method.toString().split('.').last.toUpperCase(),
          baseUrl: url,
          data: data,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        );

        await dio.fetch<dynamic>(options);
      } catch (e, s) {
        Logger().e(
          'Failed to ${method.toString().toUpperCase()} webhook to $url',
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  static Timer? _hourlyCheckTimer;
  static int _lastTriggeredHour = -1;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static void startHourlyTrackerLoop() {
    _hourlyCheckTimer?.cancel();
    _hourlyCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndTriggerHourlyReminder();
    });
    // Run initial check right now
    _checkAndTriggerHourlyReminder();
  }

  static Future<void> _checkAndTriggerHourlyReminder() async {
    if (!Prefs.enableTimeTracker) return;

    final now = DateTime.now();
    // Trigger at the top of every new hour (minute 0 or 1) once per hour
    if (now.minute <= 1 && now.hour != _lastTriggeredHour) {
      if (Prefs.enableQuietHours &&
          SoundHelper.isQuietHours(
            start: Prefs.quietHoursStart,
            end: Prefs.quietHoursEnd,
            now: now,
          )) {
        return;
      }

      _lastTriggeredHour = now.hour;
      Logger().d(
        'HookHelper: Triggering hourly time check beep and '
        'notification for hour ${now.hour}',
      );

      // 1. Play chime/beep audio
      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('sounds/digital_beep.wav'));
      } catch (e) {
        Logger().w('HookHelper audio chime failed: $e');
      }

      // 2. Show native foreground notification on Android
      try {
        await AndroidNotificationService()
            .showHourlyReminderNotification(now.hour);
      } catch (e) {
        Logger().w('HookHelper android notification failed: $e');
      }

      // 3. Show browser notification on Web PWA
      if (kIsWeb) {
        try {
          WebPwaService().showNotification(
            NotificationHelper.hourlyNotificationTitle(),
            NotificationHelper.hourlyNotificationBody(now.hour),
          );
        } catch (e) {
          Logger().w('HookHelper web notification failed: $e');
        }
      }

      // 4. Show macOS local notification (tap opens hourly log dialog)
      if (!kIsWeb &&
          Platform.isMacOS &&
          NotificationHelper.shouldShowDesktopHourlyNotification(
            enableDesktopNotifications: Prefs.enableDesktopNotifications,
            enableTimeTracker: Prefs.enableTimeTracker,
            enableQuietHours: Prefs.enableQuietHours,
            quietHoursStart: Prefs.quietHoursStart,
            quietHoursEnd: Prefs.quietHoursEnd,
            now: now,
          )) {
        try {
          await LocalNotificationService.instance.showHourlyReminder(
            hour: now.hour,
            date: DateTime(now.year, now.month, now.day),
          );
        } catch (e) {
          Logger().w('HookHelper macOS notification failed: $e');
        }
      }
    }
  }
}
