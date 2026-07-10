import 'dart:async';

import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

/// App-level timer tick loop so the Pomodoro clock keeps running when the
/// main window is hidden or the timer page is not mounted.
class TimerTickService {
  TimerTickService._();

  static Timer? _timer;

  static void start({
    required TimerCubit timerCubit,
    required SettingsCubit settingsCubit,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      timerCubit.tick(settingsCubit.state);
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
