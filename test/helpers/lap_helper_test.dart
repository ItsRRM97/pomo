import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/lap_helper.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

void main() {
  group('LapHelper', () {
    test('getNextLap transitions from work (lap 0) to shortBreak', () {
      expect(
        LapHelper.getNextLap(TimerLap.work, 0, 4),
        TimerLap.shortBreak,
      );
    });

    test('getNextLap transitions from shortBreak (odd lap) to work', () {
      expect(
        LapHelper.getNextLap(TimerLap.shortBreak, 1, 4),
        TimerLap.work,
      );
      expect(
        LapHelper.getNextLap(TimerLap.shortBreak, 3, 4),
        TimerLap.work,
      );
    });

    test('getNextLap transitions to longBreak before cycle end', () {
      // If lapCount = 4, longBreak triggers at lap (lapCount * 2) - 2 = 6
      expect(
        LapHelper.getNextLap(TimerLap.work, 6, 4),
        TimerLap.longBreak,
      );
    });
  });
}
