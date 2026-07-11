part of 'timer_cubit.dart';

enum TimerStatus {
  running,
  stopped,
}

enum TimerLap {
  work,
  shortBreak,
  longBreak,
}

class TimerState extends Equatable {
  const TimerState({
    this.status = TimerStatus.stopped,
    this.duration = Duration.zero,
    this.syncedMinutes = 0,
    this.lapNumber = 0,
    this.lap = TimerLap.work,
    this.activeTask,
  });

  final TimerStatus status;
  final Duration duration;
  final int syncedMinutes;
  final int lapNumber;
  final TimerLap lap;
  final NotionTask? activeTask;

  TimerState copyWith({
    TimerStatus Function()? status,
    Duration Function()? duration,
    int Function()? syncedMinutes,
    int Function()? lapNumber,
    TimerLap Function()? lap,
    NotionTask? Function()? activeTask,
  }) {
    return TimerState(
      status: status != null ? status() : this.status,
      duration: duration != null ? duration() : this.duration,
      syncedMinutes:
          syncedMinutes != null ? syncedMinutes() : this.syncedMinutes,
      lapNumber: lapNumber != null ? lapNumber() : this.lapNumber,
      lap: lap != null ? lap() : this.lap,
      activeTask: activeTask != null ? activeTask() : this.activeTask,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        duration,
        status,
        syncedMinutes,
        lapNumber,
        lap,
        activeTask,
      ];
}
