import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimerCubit', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    tearDown(() {
      Prefs.enableTimeTracker = false;
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = '';
      Prefs.notionProxyUrl = '';
      Prefs.pendingTimeLogs = [];
    });

    test('initial state has stopped status, zero duration, and work lap', () {
      final cubit = TimerCubit();
      expect(cubit.state, const TimerState());
      cubit.close();
    });

    blocTest<TimerCubit, TimerState>(
      'start emits running status and updates Prefs',
      build: TimerCubit.new,
      act: (cubit) => cubit.start(),
      expect: () => [
        const TimerState(status: TimerStatus.running),
      ],
      verify: (cubit) {
        expect(Prefs.timerStatus, TimerStatus.running);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'stop emits stopped status and updates Prefs',
      build: () {
        final cubit = TimerCubit()..start();
        return cubit;
      },
      act: (cubit) => cubit.stop(),
      expect: () => [
        const TimerState(),
      ],
      verify: (cubit) {
        expect(Prefs.timerStatus, TimerStatus.stopped);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'reset returns state to default TimerState and resets Prefs',
      build: () {
        final cubit = TimerCubit()..start();
        return cubit;
      },
      act: (cubit) => cubit.reset(),
      expect: () => [
        const TimerState(),
      ],
      verify: (cubit) {
        expect(Prefs.duration, Duration.zero);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'toggle switches from stopped to running and back',
      build: TimerCubit.new,
      act: (cubit) => cubit
        ..toggle()
        ..toggle(),
      expect: () => [
        const TimerState(status: TimerStatus.running),
        const TimerState(),
      ],
    );

    blocTest<TimerCubit, TimerState>(
      'tick increments duration when status is running',
      build: () {
        final cubit = TimerCubit()..start();
        return cubit;
      },
      act: (cubit) => cubit.tick(const SettingsState()),
      expect: () => [
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(seconds: 1),
        ),
      ],
    );

    blocTest<TimerCubit, TimerState>(
      'tick emits full duration before lap transition when lap completes '
      '(autoAdvance false)',
      build: () {
        Prefs.duration = const Duration(minutes: 9, seconds: 59);
        Prefs.timerStatus = TimerStatus.running;
        return TimerCubit();
      },
      act: (cubit) => cubit.tick(
        const SettingsState(workMinutes: 10),
      ),
      expect: () => [
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(minutes: 10),
        ),
        const TimerState(
          duration: Duration(minutes: 10),
        ),
        const TimerState(
          lap: TimerLap.shortBreak,
          lapNumber: 1,
        ),
      ],
    );

    blocTest<TimerCubit, TimerState>(
      'tick emits full duration before lap transition when lap completes '
      '(autoAdvance true)',
      build: () {
        Prefs.duration = const Duration(minutes: 9, seconds: 59);
        Prefs.timerStatus = TimerStatus.running;
        return TimerCubit();
      },
      act: (cubit) => cubit.tick(
        const SettingsState(workMinutes: 10, autoAdvance: true),
      ),
      expect: () => [
        const TimerState(
          status: TimerStatus.running,
          duration: Duration(minutes: 10),
        ),
        const TimerState(
          status: TimerStatus.running,
          lap: TimerLap.shortBreak,
          lapNumber: 1,
        ),
      ],
    );

    test('checkAndPlaySound respects enableSound and quiet hours', () {
      final cubit = TimerCubit();
      const disabledSound = SettingsState(enableSound: false);
      expect(
        cubit.checkAndPlaySound(settingsState: disabledSound),
        isFalse,
      );

      const quietState = SettingsState(
        quietHoursStart: '22:00',
        quietHoursEnd: '06:00',
      );
      final nightTime = DateTime(2026, 7, 13, 23, 30);
      expect(
        cubit.checkAndPlaySound(
          settingsState: quietState,
          now: nightTime,
        ),
        isFalse,
      );

      final dayTime = DateTime(2026, 7, 13, 14);
      expect(
        cubit.checkAndPlaySound(
          settingsState: quietState,
          now: dayTime,
        ),
        isTrue,
      );
    });

    test(
      'syncNow returns false without calling Notion when '
      'enableTimeTracker is false',
      () async {
        final cubit = TimerCubit();
        Prefs.enableTimeTracker = false;
        final result = await cubit.syncNow();
        expect(result, isFalse);
      },
    );
  });
}
