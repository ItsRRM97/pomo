import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

class AndroidNotificationService {
  factory AndroidNotificationService() => _instance;
  AndroidNotificationService._internal();
  static final AndroidNotificationService _instance =
      AndroidNotificationService._internal();

  static const MethodChannel _channel =
      MethodChannel('com.recoskyler.pomo/timer_notification');
  bool _isServiceActive = false;
  TimerCubit? _timerCubit;

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
        }
      });
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
        });
      } else if (_isServiceActive) {
        await _channel.invokeMethod<bool>('updateNotification', {
          'title': titleText,
          'text': formattedTime,
          'isRunning': isRunning,
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

  Future<void> showHourlyReminderNotification(int hour) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final start = hour.toString().padLeft(2, '0');
      final end = ((hour + 1) % 24).toString().padLeft(2, '0');
      await _channel.invokeMethod<bool>('startForeground', {
        'title': 'Time Tracker: Check-in Required',
        'text': 'Log what you did between $start:00 and $end:00.',
        'isRunning': false,
      });
    } catch (e) {
      // Ignore channel exceptions
    }
  }
}
