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
      'clearTask clears activeTask from state and Prefs',
      build: () {
        Prefs.activeTask = testTask;
        return TimerCubit();
      },
      act: (cubit) => cubit.clearTask(),
      expect: () => [
        const TimerState(activeTask: null),
      ],
      verify: (_) {
        expect(Prefs.activeTask, isNull);
      },
    );

    blocTest<TimerCubit, TimerState>(
      'reset preserves current activeTask',
      build: () {
        Prefs.activeTask = testTask;
        return TimerCubit();
      },
      act: (cubit) {
        cubit.start();
        cubit.reset();
      },
      expect: () => [
        const TimerState(status: TimerStatus.running, activeTask: testTask),
        const TimerState(status: TimerStatus.stopped, activeTask: testTask),
      ],
    );
  });
}
