import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/lap_color_helper.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

void main() {
  group('LapColorHelper', () {
    test('lapColor returns primaryContainer when work lap is running', () {
      final color = LapColorHelper.lapColor(
        lap: TimerLap.work,
        status: TimerStatus.running,
        colorSeed: Colors.blue,
        brightness: Brightness.light,
      );
      final expectedScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
      );
      expect(color, expectedScheme.primaryContainer);
    });

    test('lapColor returns secondaryContainer when timer is stopped', () {
      final color = LapColorHelper.lapColor(
        lap: TimerLap.work,
        status: TimerStatus.stopped,
        colorSeed: Colors.green,
        brightness: Brightness.dark,
      );
      final expectedScheme = ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      );
      expect(color, expectedScheme.secondaryContainer);
    });

    test('lapColor returns secondary/tertiary for break laps when running', () {
      final expectedScheme = ColorScheme.fromSeed(
        seedColor: Colors.purple,
      );

      final shortBreakColor = LapColorHelper.lapColor(
        lap: TimerLap.shortBreak,
        status: TimerStatus.running,
        colorSeed: Colors.purple,
        brightness: Brightness.light,
      );
      expect(shortBreakColor, expectedScheme.secondary);

      final longBreakColor = LapColorHelper.lapColor(
        lap: TimerLap.longBreak,
        status: TimerStatus.running,
        colorSeed: Colors.purple,
        brightness: Brightness.light,
      );
      expect(longBreakColor, expectedScheme.tertiary);
    });
  });
}
