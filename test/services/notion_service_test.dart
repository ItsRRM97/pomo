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

    tearDown(() {
      Prefs.enableNotionSync = false;
      Prefs.notionApiKey = '';
      Prefs.notionProxyUrl = '';
      Prefs.pendingTimeLogs = [];
      NotionService.clearTaskFetchCache();
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
      'moveToInProgressIfNeeded returns unchanged task when already '
      'In Progress or Done',
      () async {
        const task =
            NotionTask(id: 't-1', title: 'Test', status: 'In Progress');
        final res = await NotionSyncService().moveToInProgressIfNeeded(task);
        expect(res, equals(task));
      },
    );

    test('moveToInProgressIfNeeded returns null when task is null', () async {
      final res = await NotionSyncService().moveToInProgressIfNeeded(null);
      expect(res, isNull);
    });

    test('flushPendingLogs returns 0 when enableNotionSync is false', () async {
      Prefs.enableNotionSync = false;
      Prefs.pendingTimeLogs = ['{"taskId":"1","durationMinutes":25}'];
      final flushed = await NotionSyncService().flushPendingLogs();
      expect(flushed, equals(0));
    });

    test('flushPendingLogs returns 0 when queue is empty', () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.pendingTimeLogs = [];
      final flushed = await NotionSyncService().flushPendingLogs();
      expect(flushed, equals(0));
    });

    test('syncSession queues to Prefs.pendingTimeLogs on network/API failure',
        () async {
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'secret_token';
      Prefs.notionProxyUrl = 'http://invalid.domain.test:12345/api/notion/';
      Prefs.pendingTimeLogs = [];

      final result = await NotionSyncService().syncSession(
        task: const NotionTask(
          id: 'task-fail-1',
          title: 'Network Fail Task',
          status: 'In Progress',
        ),
        duration: const Duration(minutes: 25),
      );

      expect(result.success, isFalse);
      expect(Prefs.pendingTimeLogs, isNotEmpty);
      expect(Prefs.pendingTimeLogs.first, contains('task-fail-1'));
    });
  });

  group('NotionService cache guard and idempotency checks', () {
    test('checkIdempotency returns null when apiKey is empty', () async {
      Prefs.notionApiKey = '';
      final res = await NotionService().checkIdempotency('ext-123');
      expect(res, isNull);
    });

    test('clearTaskFetchCache resets cache without throwing', () {
      expect(NotionService.clearTaskFetchCache, returnsNormally);
    });
  });
}
