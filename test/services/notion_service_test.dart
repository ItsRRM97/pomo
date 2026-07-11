import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotionService.addDuration', () {
    test('normalizes minutes into hours and remaining minutes accurately', () {
      final res1 = NotionService.addDuration(
        currentHours: 1,
        currentMinutes: 45,
        addMin: 30,
      );
      expect(res1.hours, equals(2));
      expect(res1.minutes, equals(15));

      final res2 = NotionService.addDuration(
        currentHours: 0,
        currentMinutes: 10,
        addMin: 120,
      );
      expect(res2.hours, equals(2));
      expect(res2.minutes, equals(10));

      final res3 = NotionService.addDuration(
        currentHours: 3,
        currentMinutes: 59,
        addMin: 1,
      );
      expect(res3.hours, equals(4));
      expect(res3.minutes, equals(0));
    });
  });

  group('NotionSyncService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    test('skips sync when task is null', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';

      final result = await NotionSyncService().syncSession(
        task: null,
        duration: const Duration(minutes: 25),
      );
      expect(result.success, isFalse);
    });

    test('skips sync when enableNotionSync is false', () async {
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = 'secret_token';

      final result = await NotionSyncService().syncSession(
        task: const NotionTask(id: 'task-1', title: 'Test'),
        duration: const Duration(minutes: 25),
      );
      expect(result.success, isFalse);
    });

    test('skips sync when duration is less than 1 minute', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';

      final result = await NotionSyncService().syncSession(
        task: const NotionTask(id: 'task-1', title: 'Test'),
        duration: const Duration(seconds: 45),
      );
      expect(result.success, isFalse);
    });

    test(
        'moveToInProgressIfNeeded returns unchanged task when already In Progress or Done',
        () async {
      const task = NotionTask(id: 't-1', title: 'Test', status: 'In Progress');
      final res = await NotionSyncService().moveToInProgressIfNeeded(task);
      expect(res, equals(task));
    });

    test('moveToInProgressIfNeeded returns null when task is null', () async {
      final res = await NotionSyncService().moveToInProgressIfNeeded(null);
      expect(res, isNull);
    });
  });
}
