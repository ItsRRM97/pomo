import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TimerCubit (Notion integration)', () {
    const testTask = NotionTask(
      id: 'task-101',
      title: 'Build Web Feature',
      status: 'In Progress',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    blocTest<TimerCubit, TimerState>(
      'selectTask updates activeTask in state and Prefs',
      build: TimerCubit.new,
      act: (cubit) => cubit.selectTask(testTask),
      expect: () => [
        const TimerState(activeTask: testTask),
      ],
      verify: (_) {
        expect(Prefs.activeTask, equals(testTask));
      },
    );

    blocTest<TimerCubit, TimerState>(
      'clearTask clears activeTask and session sync state from state and Prefs',
      build: () {
        Prefs.activeTask = testTask;
        Prefs.activeLogPageId = 'page-123';
        Prefs.syncedMinutes = 7;
        Prefs.activeSessionExternalId = 'sess_clear';
        return TimerCubit();
      },
      act: (cubit) => cubit.clearTask(),
      expect: () => [
        const TimerState(),
      ],
      verify: (_) {
        expect(Prefs.activeTask, isNull);
        expect(Prefs.activeLogPageId, isNull);
        expect(Prefs.syncedMinutes, equals(0));
        expect(Prefs.activeSessionExternalId, isNull);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'selectTask resets session sync state when switching tasks',
      build: () {
        Prefs.activeTask = testTask;
        Prefs.activeLogPageId = 'page-abc';
        Prefs.syncedMinutes = 5;
        Prefs.activeSessionExternalId = 'sess_old';
        return TimerCubit();
      },
      act: (cubit) => cubit.selectTask(
        const NotionTask(id: 'task-102', title: 'New Task'),
      ),
      expect: () => [
        const TimerState(
          activeTask: NotionTask(id: 'task-102', title: 'New Task'),
        ),
      ],
      verify: (_) {
        expect(Prefs.activeLogPageId, isNull);
        expect(Prefs.syncedMinutes, equals(0));
        expect(Prefs.activeSessionExternalId, isNull);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'selectTask while running keeps running and clears prior session state',
      build: () {
        Prefs.enableTimeTracker = true;
        Prefs.enableNotionSync = false;
        Prefs.activeTask = testTask;
        Prefs.activeLogPageId = 'page-abc';
        Prefs.syncedMinutes = 10;
        Prefs.activeSessionExternalId = 'sess_old';
        Prefs.timerStatus = TimerStatus.running;
        Prefs.duration = const Duration(minutes: 12);
        return TimerCubit();
      },
      act: (cubit) => cubit.selectTask(
        const NotionTask(id: 'task-102', title: 'New Task'),
      ),
      verify: (cubit) {
        expect(cubit.state.status, equals(TimerStatus.running));
        expect(cubit.state.duration, equals(Duration.zero));
        expect(
          cubit.state.activeTask,
          equals(const NotionTask(id: 'task-102', title: 'New Task')),
        );
        expect(Prefs.activeLogPageId, isNull);
        expect(Prefs.syncedMinutes, equals(0));
        expect(Prefs.activeSessionExternalId, isNull);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'reset preserves current activeTask',
      build: () {
        Prefs.activeTask = testTask;
        return TimerCubit();
      },
      act: (cubit) => cubit
        ..start()
        ..reset(),
      expect: () => [
        const TimerState(status: TimerStatus.running, activeTask: testTask),
        const TimerState(activeTask: testTask),
      ],
    );
  });
}
