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
            syncedMinutes: Prefs.syncedMinutes,
            activeLogPageId: Prefs.activeLogPageId,
          ),
        );
  bool _isMovingToInProgress = false;

  void _checkAndMoveActiveTaskToInProgress() {
    final currentTask = state.activeTask;
    if (currentTask != null &&
        !_isMovingToInProgress &&
        (currentTask.status.trim().toLowerCase() == 'to do' ||
            currentTask.status.trim().toLowerCase() == 'todo' ||
            currentTask.status.trim().toLowerCase() == 'to-do')) {
      _isMovingToInProgress = true;
      NotionSyncService().moveToInProgressIfNeeded(currentTask).then((updated) {
        _isMovingToInProgress = false;
        if (updated != null &&
            state.activeTask?.id == updated.id &&
            updated.status == 'In Progress') {
          emit(state.copyWith(activeTask: () => updated));
        }
      }).catchError((_) {
        _isMovingToInProgress = false;
      });
    }
  }

  void _syncActiveTaskIfEligible() {
    final totalMinutes = state.duration.inMinutes;
    final minutesToSync = totalMinutes - state.syncedMinutes;
    if (state.lap == TimerLap.work &&
        minutesToSync >= 1 &&
        state.activeTask != null) {
      final taskToSync = state.activeTask!;
      final logPageId = state.activeLogPageId;
      NotionSyncService()
          .syncSession(
        task: taskToSync,
        duration: Duration(minutes: minutesToSync),
        totalDuration: Duration(minutes: totalMinutes),
        existingLogPageId: logPageId,
        endedAt: DateTime.now(),
      )
          .then((result) {
        if (result.success && state.activeTask?.id == taskToSync.id) {
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
    final totalMinutes = state.duration.inMinutes;
    final minutesToSync = totalMinutes - state.syncedMinutes;
    if (minutesToSync < 1) return false;

    final taskToSync = state.activeTask!;
    final result = await NotionSyncService().syncSession(
      task: taskToSync,
      duration: Duration(minutes: minutesToSync),
      totalDuration: Duration(minutes: totalMinutes),
      existingLogPageId: state.activeLogPageId,
      endedAt: DateTime.now(),
    );

    if (result.success) {
      final newSyncedMinutes = state.syncedMinutes + minutesToSync;
      final updatedTask = Prefs.activeTask;
      final newPageId = result.logPageId ?? state.activeLogPageId;
      Prefs.syncedMinutes = newSyncedMinutes;
      Prefs.activeLogPageId = newPageId;
      emit(
        state.copyWith(
          syncedMinutes: () => newSyncedMinutes,
          activeTask: () => updatedTask ?? taskToSync,
          activeLogPageId: () => newPageId,
        ),
      );
    }
    return result.success;
  }

  void start() {
    emit(
      state.copyWith(
        status: () => TimerStatus.running,
      ),
    );

    Prefs.timerStatus = TimerStatus.running;

    if (state.lap == TimerLap.work && state.activeTask != null) {
      _checkAndMoveActiveTaskToInProgress();
    }
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
      Prefs.syncedMinutes = 0;
      Prefs.activeLogPageId = null;
      Prefs.activeTask = task;
      emit(
        state.copyWith(
          activeTask: () => task,
          duration: () => Duration.zero,
          syncedMinutes: () => 0,
          activeLogPageId: () => null,
        ),
      );
      if (task != null && state.lap == TimerLap.work) {
        _checkAndMoveActiveTaskToInProgress();
      }
    }
  }

  void clearTask() {
    _syncActiveTaskIfEligible();
    Prefs.duration = Duration.zero;
    Prefs.syncedMinutes = 0;
    Prefs.activeLogPageId = null;
    Prefs.activeTask = null;
    emit(
      state.copyWith(
        activeTask: () => null,
        duration: () => Duration.zero,
        syncedMinutes: () => 0,
        activeLogPageId: () => null,
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
        activeLogPageId: () => null,
        lapNumber: () => nextLapNumber,
        lap: () => nextLap,
        status: !autoAdvance ? () => TimerStatus.stopped : null,
      ),
    );

    Prefs.timerLap = nextLap;
    Prefs.duration = Duration.zero;
    Prefs.syncedMinutes = 0;
    Prefs.activeLogPageId = null;
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

    if (state.lap == TimerLap.work && state.activeTask != null) {
      _checkAndMoveActiveTaskToInProgress();
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
