import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/lap_helper.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

part 'timer_state.dart';

class TimerCubit extends Cubit<TimerState> {
  TimerCubit()
      : super(
          TimerState(
            duration: Prefs.duration,
            status: Prefs.timerStatus,
            lap: Prefs.timerLap,
            lapNumber: Prefs.lapNumber,
            activeTask: Prefs.activeTask,
          ),
        );

  void _syncActiveTaskIfEligible() {
    if (state.lap == TimerLap.work &&
        state.duration.inMinutes >= 1 &&
        state.activeTask != null) {
      final taskToSync = state.activeTask!;
      final durationToSync = state.duration;
      NotionSyncService()
          .syncSession(
        task: taskToSync,
        duration: durationToSync,
        endedAt: DateTime.now(),
      )
          .then((success) {
        if (success && state.activeTask?.id == taskToSync.id) {
          final updated = Prefs.activeTask;
          if (updated != null) {
            emit(state.copyWith(activeTask: () => updated));
          }
        }
      });
    }
  }

  Future<bool> syncNow() async {
    if (state.activeTask == null) return false;
    final minutes = state.duration.inMinutes;
    if (minutes < 1) return false;

    final taskToSync = state.activeTask!;
    final success = await NotionSyncService().syncSession(
      task: taskToSync,
      duration: state.duration,
      endedAt: DateTime.now(),
    );

    if (success) {
      final remainingDuration = state.duration - Duration(minutes: minutes);
      Prefs.duration = remainingDuration;
      final updatedTask = Prefs.activeTask;
      emit(
        state.copyWith(
          duration: () => remainingDuration,
          activeTask: () => updatedTask ?? taskToSync,
        ),
      );
    }
    return success;
  }

  void start() {
    emit(
      state.copyWith(
        status: () => TimerStatus.running,
      ),
    );

    Prefs.timerStatus = TimerStatus.running;
  }

  void stop() {
    emit(
      state.copyWith(
        status: () => TimerStatus.stopped,
      ),
    );

    Prefs.timerStatus = TimerStatus.stopped;
  }

  void reset() {
    _syncActiveTaskIfEligible();
    final currentTask = state.activeTask;
    emit(TimerState(activeTask: currentTask));

    Prefs.resetTimer();
  }

  void selectTask(NotionTask? task) {
    if (state.activeTask?.id != task?.id) {
      _syncActiveTaskIfEligible();
      Prefs.duration = Duration.zero;
      Prefs.activeTask = task;
      emit(
        state.copyWith(
          activeTask: () => task,
          duration: () => Duration.zero,
        ),
      );
    }
  }

  void clearTask() {
    _syncActiveTaskIfEligible();
    Prefs.duration = Duration.zero;
    Prefs.activeTask = null;
    emit(
      state.copyWith(
        activeTask: () => null,
        duration: () => Duration.zero,
      ),
    );
  }

  void lap({required SettingsState settingsState, bool autoAdvance = true}) {
    _syncActiveTaskIfEligible();
    final nextLap = LapHelper.getNextLap(
      state.lap,
      state.lapNumber,
      settingsState.lapCount,
    );

    final nextLapNumber = (state.lapNumber + 1) % (settingsState.lapCount * 2);

    emit(
      state.copyWith(
        duration: () => Duration.zero,
        lapNumber: () => nextLapNumber,
        lap: () => nextLap,
        status: !autoAdvance ? () => TimerStatus.stopped : null,
      ),
    );

    Prefs.timerLap = nextLap;
    Prefs.duration = Duration.zero;
    Prefs.lapNumber = nextLapNumber;
    Prefs.timerStatus = !autoAdvance ? TimerStatus.stopped : state.status;
  }

  /// Adds the given [duration] to the current [TimerState.duration].
  /// If no [duration] is provided, it defaults to 1 second.
  void tick(
    SettingsState settingsState, [
    Duration duration = const Duration(seconds: 1),
  ]) {
    if (state.status != TimerStatus.running) {
      return;
    }

    final newDuration = state.duration + duration;

    if (DurationHelper.isLapComplete(
          duration: newDuration,
          lap: state.lap,
          settingsState: settingsState,
        ) &&
        settingsState.autoAdvance) {
      lap(settingsState: settingsState);

      return;
    } else if (DurationHelper.isLapComplete(
      duration: newDuration,
      lap: state.lap,
      settingsState: settingsState,
    )) {
      stop();
      lap(settingsState: settingsState);

      return;
    }

    emit(state.copyWith(duration: () => newDuration));

    Prefs.duration = newDuration;
  }

  void toggle() {
    if (state.status == TimerStatus.running) {
      stop();
    } else {
      start();
    }
  }
}
