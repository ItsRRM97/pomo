import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/lap_helper.dart';
import 'package:pomo/helpers/sound_helper.dart';
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
            activeLogPageId: Prefs.activeLogPageId,
          ),
        );
  bool _isMovingToInProgress = false;
  bool _isCreatingRecord = false;

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

  /// Creates a new Notion Time Log record for the current session.
  /// Called when the timer starts for the first time in a work lap with a task.
  void _createNotionRecord() {
    if (!Prefs.enableTimeTracker) return;
    if (state.activeTask == null) return;
    if (state.lap != TimerLap.work) return;
    if (state.activeLogPageId != null) return; // Already has a record
    if (_isCreatingRecord) return;

    _isCreatingRecord = true;
    final taskToSync = state.activeTask!;
    final startedAt = DateTime.now();

    NotionSyncService()
        .createSessionRecord(task: taskToSync, startedAt: startedAt)
        .then((pageId) {
      _isCreatingRecord = false;
      if (pageId != null && state.activeTask?.id == taskToSync.id) {
        Prefs.activeLogPageId = pageId;
        emit(state.copyWith(activeLogPageId: () => pageId));
        Logger().i('TimerCubit: Session record created: $pageId');
      }
    }).catchError((Object e) {
      _isCreatingRecord = false;
      Logger().w('TimerCubit: Failed to create session record: $e');
    });
  }

  /// Updates the existing Notion Time Log record with current elapsed time.
  /// Called on pause, lap transition, and reset.
  void _updateNotionRecord() {
    if (!Prefs.enableTimeTracker) return;
    if (state.activeTask == null) return;
    if (state.lap != TimerLap.work) return;

    final totalMinutes = state.duration.inMinutes;
    if (totalMinutes < 1) return; // Skip update if less than 1 minute

    final taskToSync = state.activeTask!;
    final logPageId = state.activeLogPageId;

    NotionSyncService()
        .updateSessionRecord(
      task: taskToSync,
      totalElapsed: state.duration,
      existingLogPageId: logPageId,
      endedAt: DateTime.now(),
    )
        .then((result) {
      if (result.success && state.activeTask?.id == taskToSync.id) {
        // Update page ID if it was created as a fallback
        if (result.logPageId != null &&
            result.logPageId != state.activeLogPageId) {
          Prefs.activeLogPageId = result.logPageId;
          emit(state.copyWith(activeLogPageId: () => result.logPageId));
        }
        final updated = Prefs.activeTask;
        if (updated != null) {
          emit(state.copyWith(activeTask: () => updated));
        }
      }
    });
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
      // Create a Notion record on first start of this session
      _createNotionRecord();
    }
  }

  void stop() {
    // Update the Notion record with current elapsed time
    _updateNotionRecord();

    emit(
      state.copyWith(
        status: () => TimerStatus.stopped,
      ),
    );

    Prefs.timerStatus = TimerStatus.stopped;
  }

  void reset() {
    // Finalize the current Notion record before resetting
    _updateNotionRecord();

    final currentTask = state.activeTask;
    emit(TimerState(activeTask: currentTask));

    Prefs.resetTimer();
  }

  void selectTask(NotionTask? task) {
    if (state.activeTask?.id != task?.id) {
      // Finalize any existing session before switching
      _updateNotionRecord();

      Prefs.duration = Duration.zero;
      Prefs.activeLogPageId = null;
      Prefs.activeTask = task;
      emit(
        state.copyWith(
          activeTask: () => task,
          duration: () => Duration.zero,
          activeLogPageId: () => null,
        ),
      );
      if (task != null && state.lap == TimerLap.work) {
        _checkAndMoveActiveTaskToInProgress();
      }
    }
  }

  void clearTask() {
    // Finalize any existing session before clearing
    _updateNotionRecord();

    Prefs.duration = Duration.zero;
    Prefs.activeLogPageId = null;
    Prefs.activeTask = null;
    emit(
      state.copyWith(
        activeTask: () => null,
        duration: () => Duration.zero,
        activeLogPageId: () => null,
      ),
    );
  }

  void lap({required SettingsState settingsState, bool autoAdvance = true}) {
    // Finalize the current Notion record before transitioning laps
    _updateNotionRecord();

    final nextLap = LapHelper.getNextLap(
      state.lap,
      state.lapNumber,
      settingsState.lapCount,
    );

    final nextLapNumber = (state.lapNumber + 1) % (settingsState.lapCount * 2);

    emit(
      state.copyWith(
        duration: () => Duration.zero,
        activeLogPageId: () => null,
        lapNumber: () => nextLapNumber,
        lap: () => nextLap,
        status: !autoAdvance ? () => TimerStatus.stopped : null,
      ),
    );

    Prefs.timerLap = nextLap;
    Prefs.duration = Duration.zero;
    Prefs.activeLogPageId = null;
    Prefs.lapNumber = nextLapNumber;
    Prefs.timerStatus = !autoAdvance ? TimerStatus.stopped : state.status;

    // If auto-advancing into a new work lap with a task, create a new record
    if (autoAdvance &&
        nextLap == TimerLap.work &&
        state.activeTask != null &&
        state.status == TimerStatus.running) {
      _createNotionRecord();
    }
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
    emit(state.copyWith(duration: () => newDuration));
    Prefs.duration = newDuration;

    final isLapComplete = DurationHelper.isLapComplete(
      duration: newDuration,
      lap: state.lap,
      settingsState: settingsState,
    );

    if (isLapComplete) {
      if (!settingsState.autoAdvance) {
        stop();
      }
      lap(settingsState: settingsState);
      return;
    }
  }

  void toggle() {
    if (state.status == TimerStatus.running) {
      stop();
    } else {
      start();
    }
  }

  bool checkAndPlaySound({
    required SettingsState settingsState,
    DateTime? now,
  }) {
    if (!settingsState.enableSound) return false;
    if (SoundHelper.isQuietHours(
      start: settingsState.quietHoursStart,
      end: settingsState.quietHoursEnd,
      now: now,
    )) {
      return false;
    }
    return true;
  }
}
