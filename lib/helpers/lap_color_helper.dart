import 'package:flutter/material.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

mixin LapColorHelper {
  static Color lapColor({
    required TimerLap lap,
    required TimerStatus status,
    required Color? colorSeed,
    required Brightness brightness,
  }) {
    final seed = colorSeed ?? Colors.redAccent;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    if (status == TimerStatus.running) {
      switch (lap) {
        case TimerLap.work:
          return scheme.primaryContainer;
        case TimerLap.shortBreak:
          return scheme.secondary;
        case TimerLap.longBreak:
          return scheme.tertiary;
      }
    }

    return scheme.secondaryContainer;
  }
}
