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
    final minutesToSync = state.duration.inMinutes - state.syncedMinutes;
    if (state.lap == TimerLap.work &&
        minutesToSync >= 1 &&
        state.activeTask != null) {
      final taskToSync = state.activeTask!;
      NotionSyncService()
          .syncSession(
        task: taskToSync,
        duration: Duration(minutes: minutesToSync),
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
    final minutesToSync = state.duration.inMinutes - state.syncedMinutes;
    if (minutesToSync < 1) return false;

    final taskToSync = state.activeTask!;
    final success = await NotionSyncService().syncSession(
      task: taskToSync,
      duration: Duration(minutes: minutesToSync),
      endedAt: DateTime.now(),
    );

    if (success) {
      final newSyncedMinutes = state.syncedMinutes + minutesToSync;
      final updatedTask = Prefs.activeTask;
      emit(
        state.copyWith(
          syncedMinutes: () => newSyncedMinutes,
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
          syncedMinutes: () => 0,
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
        syncedMinutes: () => 0,
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
        syncedMinutes: () => 0,
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
