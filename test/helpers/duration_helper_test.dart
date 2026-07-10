import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

void main() {
  group('DurationHelper', () {
    test('format formats positive durations cleanly into MM:SS', () {
      expect(DurationHelper.format(const Duration(minutes: 25)), '25:00');
      expect(
        DurationHelper.format(const Duration(minutes: 4, seconds: 5)),
        '04:05',
      );
      expect(DurationHelper.format(const Duration(seconds: 59)), '00:59');
    });

    test('format handles negative durations with minus sign', () {
      expect(
        DurationHelper.format(const Duration(minutes: -1, seconds: -30)),
        '-01:30',
      );
    });

    test('isLapComplete accurately detects completed work laps', () {
      const settings = SettingsState();
      expect(
        DurationHelper.isLapComplete(
          duration: const Duration(minutes: 24, seconds: 59),
          lap: TimerLap.work,
          settingsState: settings,
        ),
        isFalse,
      );
      expect(
        DurationHelper.isLapComplete(
          duration: const Duration(minutes: 25),
          lap: TimerLap.work,
          settingsState: settings,
        ),
        isTrue,
      );
    });

    test('isLapComplete detects completed shortBreak and longBreak', () {
      const settings = SettingsState();
      expect(
        DurationHelper.isLapComplete(
          duration: const Duration(minutes: 5),
          lap: TimerLap.shortBreak,
          settingsState: settings,
        ),
        isTrue,
      );
      expect(
        DurationHelper.isLapComplete(
          duration: const Duration(minutes: 15),
          lap: TimerLap.longBreak,
          settingsState: settings,
        ),
        isTrue,
      );
    });

    test('getProgress calculates percentage between 1.0 and 0.0', () {
      const settings = SettingsState(workMinutes: 20);
      expect(
        DurationHelper.getProgress(
          duration: Duration.zero,
          lap: TimerLap.work,
          settingsState: settings,
        ),
        1.0,
      );
      expect(
        DurationHelper.getProgress(
          duration: const Duration(minutes: 10),
          lap: TimerLap.work,
          settingsState: settings,
        ),
        0.5,
      );
      expect(
        DurationHelper.getProgress(
          duration: const Duration(minutes: 20),
          lap: TimerLap.work,
          settingsState: settings,
        ),
        0.0,
      );
    });
  });
}
