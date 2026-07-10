import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

mixin SessionHelper {
  /// True when a Pomodoro session is in progress (running or paused mid-lap).
  static bool isSessionActive(TimerState state) {
    return state.status == TimerStatus.running ||
        state.duration > Duration.zero;
  }
}
