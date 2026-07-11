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
  });
}
