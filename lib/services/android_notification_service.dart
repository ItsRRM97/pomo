import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/app_navigation_controller.dart';

class AndroidNotificationService {
  factory AndroidNotificationService() => _instance;
  AndroidNotificationService._internal();
  static final AndroidNotificationService _instance =
      AndroidNotificationService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.recoskyler.pomo/timer_notification');
  bool _isServiceActive = false;
  TimerCubit? _timerCubit;

  /// Parses a native `onNotificationTap` argument into a [NotificationAction].
  @visibleForTesting
  static NotificationAction? actionFromNotificationTap(Object? arguments) {
    final payload = arguments as String?;
    return NotificationHelper.parsePayload(payload);
  }

  /// Pulls and clears any cold-start launch payload stored in MainActivity.
  @visibleForTesting
  static Future<String?> pullPendingNotificationPayload(
    MethodChannel channel,
  ) async {
    return channel.invokeMethod<String>('getPendingNotificationPayload');
  }

  /// Pulls pending payload and parses it (used by init + unit tests).
  @visibleForTesting
  static Future<NotificationAction?> actionFromPendingPull(
    MethodChannel channel,
  ) async {
    final payload = await pullPendingNotificationPayload(channel);
    return actionFromNotificationTap(payload);
  }

  /// Arguments passed to native `startForeground` for an hourly reminder.
  @visibleForTesting
  static Map<String, Object?> hourlyStartForegroundArgs({
    required int hour,
    required DateTime date,
  }) {
    return {
      'title': NotificationHelper.hourlyNotificationTitle(),
      'text': NotificationHelper.hourlyNotificationBody(hour),
      'isRunning': false,
      'isHourly': true,
      'payload': NotificationHelper.hourlyPayload(hour: hour, date: date),
    };
  }

  void init(TimerCubit timerCubit) {
    if (kIsWeb || !Platform.isAndroid) return;
    _timerCubit = timerCubit;
    _channel
      ..invokeMethod<bool>('requestPermission')
      ..setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onPlay':
            if (_timerCubit?.state.status != TimerStatus.running) {
              _timerCubit?.start();
            }
          case 'onPause':
            if (_timerCubit?.state.status == TimerStatus.running) {
              _timerCubit?.stop();
            }
          case 'onStop':
            _timerCubit?.reset();
          case 'onNotificationTap':
            await _routeNotificationPayload(call.arguments);
        }
      });
    // Cold start: pull after the handler is registered (do not rely on a
    // fixed native delay alone).
    unawaited(_consumePendingLaunchPayload());
  }

  Future<void> _routeNotificationPayload(Object? arguments) async {
    final action = actionFromNotificationTap(arguments);
    await AppNavigationController.instance.handleNotificationAction(action);
  }

  Future<void> _consumePendingLaunchPayload() async {
    try {
      final payload = await pullPendingNotificationPayload(_channel);
      if (payload == null || payload.isEmpty) {
        return;
      }
      // Give navigator / HomeShell a beat on cold start before dialog.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _routeNotificationPayload(payload);
    } catch (_) {
      // Ignore channel exceptions
    }
  }

  Future<void> updateTimerState({
    required TimerState timerState,
    required SettingsState settingsState,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final formattedTime = DurationHelper.negativeFormat(
      duration: timerState.duration,
      lap: timerState.lap,
      settingsState: settingsState,
    );

    final isRunning = timerState.status == TimerStatus.running;
    final isZero = timerState.duration == Duration.zero;

    if (!isRunning && isZero) {
      if (_isServiceActive) {
        _isServiceActive = false;
        try {
          await _channel.invokeMethod<bool>('stopForeground');
        } catch (_) {}
      }
      return;
    }

    final lapText = timerState.lap == TimerLap.work
        ? 'Work Session'
        : (timerState.lap == TimerLap.shortBreak
            ? 'Short Break'
            : 'Long Break');
    final titleText = (timerState.activeTask?.title.isNotEmpty ?? false)
        ? '$lapText: ${timerState.activeTask!.title}'
        : lapText;

    try {
      if (!_isServiceActive && (isRunning || !isZero)) {
        _isServiceActive = true;
        await _channel.invokeMethod<bool>('startForeground', {
          'title': titleText,
          'text': formattedTime,
          'isRunning': isRunning,
          'isHourly': false,
        });
      } else if (_isServiceActive) {
        await _channel.invokeMethod<bool>('updateNotification', {
          'title': titleText,
          'text': formattedTime,
          'isRunning': isRunning,
          'isHourly': false,
        });
      }
    } catch (e) {
      // Ignore channel exceptions if native service fails
    }
  }

  Future<void> stopForeground() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      _isServiceActive = false;
      await _channel.invokeMethod<bool>('stopForeground');
    } catch (e) {
      // Ignore channel exceptions
    }
  }

  Future<void> showHourlyReminderNotification({
    required int hour,
    required DateTime date,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>(
        'startForeground',
        hourlyStartForegroundArgs(hour: hour, date: date),
      );
    } catch (e) {
      // Ignore channel exceptions
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final result = await _channel
          .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
