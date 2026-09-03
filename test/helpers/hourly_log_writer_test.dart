import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
  });

  test('reconcileResting writes Sleep & Rest logs for quiet hours', () async {
    Prefs.enableTimeTracker = true;
    Prefs.enableQuietHours = true;
    Prefs.quietHoursStart = '23:00';
    Prefs.quietHoursEnd = '07:00';
    Prefs.enableNotionSync = false;

    final written = await HourlyLogWriter.reconcileResting(
      now: DateTime(2026, 8, 17, 10),
    );

    expect(written, greaterThan(0));
    expect(
      Prefs.hourlyLogs.every((log) => log.tagId == 'tag_sleep'),
      isTrue,
    );
    expect(
      Prefs.hourlyLogs.map((log) => '${log.dateStr}_${log.hour}'),
      contains('2026-08-16_23'),
    );
  });

  test('reconcileResting is a no-op when tracker is disabled', () async {
    Prefs.enableTimeTracker = false;
    Prefs.enableQuietHours = true;

    final written = await HourlyLogWriter.reconcileResting(
      now: DateTime(2026, 8, 17, 10),
    );

    expect(written, 0);
    expect(Prefs.hourlyLogs, isEmpty);
  });

  test(
    'pull then reconcile keeps remote Work; Resting-first merge yields Work',
    () async {
      Prefs.enableTimeTracker = true;
      Prefs.enableQuietHours = true;
      Prefs.quietHoursStart = '23:00';
      Prefs.quietHoursEnd = '07:00';
      Prefs.enableNotionSync = false;

      const workTag = TrackerTag(
        id: 'tag_deep_work',
        name: 'Deep Work',
        icon: '🧠',
        colorHex: '#34A853',
        isDefault: true,
      );
      final loggedAt = DateTime(2026, 8, 16, 23, 5);
      final now = DateTime(2026, 8, 17, 10);
      final work = HourlyLogWriter.build(
        date: DateTime(2026, 8, 16),
        hour: 23,
        tag: workTag,
        loggedAt: loggedAt,
      );

      await Prefs.replaceHourlyLogsForHour(work.dateStr, work.hour, [work]);
      final afterPull = await HourlyLogWriter.reconcileResting(now: now);
      expect(afterPull, greaterThan(0));
      expect(
        Prefs.hourlyLogs
            .where((log) => log.dateStr == '2026-08-16' && log.hour == 23)
            .map((log) => log.tagId),
        ['tag_deep_work'],
      );

      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
      Prefs.enableTimeTracker = true;
      Prefs.enableQuietHours = true;
      Prefs.quietHoursStart = '23:00';
      Prefs.quietHoursEnd = '07:00';
      Prefs.enableNotionSync = false;

      await HourlyLogWriter.reconcileResting(now: now);
      final merged = NotionSyncService.currentHourlySlotRevision([
        ...Prefs.hourlyLogs.where(
          (log) => log.dateStr == '2026-08-16' && log.hour == 23,
        ),
        work,
      ]);
      expect(merged, hasLength(1));
      expect(merged.single.tagId, 'tag_deep_work');
    },
  );

  test(
    'reconcileResting after local Work writes 0 and does not add Resting',
    () async {
      Prefs.enableTimeTracker = true;
      Prefs.enableQuietHours = true;
      Prefs.quietHoursStart = '23:00';
      Prefs.quietHoursEnd = '07:00';
      Prefs.enableNotionSync = true;
      Prefs.notionApiKey = 'test-key';
      Prefs.notionHourlyTimelineDatabaseId = 'db';

      const workTag = TrackerTag(
        id: 'tag_deep_work',
        name: 'Deep Work',
        icon: '🧠',
        colorHex: '#34A853',
        isDefault: true,
      );
      final work = HourlyLogWriter.build(
        date: DateTime(2026, 8, 16),
        hour: 23,
        tag: workTag,
        loggedAt: DateTime(2026, 8, 16, 23, 5),
      );
      await HourlyLogWriter.persist([work], syncToNotion: false);

      await HourlyLogWriter.reconcileResting(
        now: DateTime(2026, 8, 17, 10),
      );

      final slot = Prefs.hourlyLogs
          .where((log) => log.dateStr == '2026-08-16' && log.hour == 23)
          .toList();
      expect(
        slot.where((log) => log.tagId == 'tag_deep_work'),
        hasLength(1),
      );
      expect(
        slot.any(
          (log) => log.tagId == 'tag_sleep' && log.notes == 'Resting',
        ),
        isFalse,
      );
      expect(Prefs.pendingHourlyLogs, isEmpty);
    },
  );

  test('persist does not append Resting beside a user Work log', () async {
    const workTag = TrackerTag(
      id: 'tag_deep_work',
      name: 'Deep Work',
      icon: '🧠',
      colorHex: '#34A853',
      isDefault: true,
    );
    final work = HourlyLogWriter.build(
      date: DateTime(2026, 8, 16),
      hour: 23,
      tag: workTag,
      loggedAt: DateTime(2026, 8, 16, 23, 5),
    );
    final resting = QuietHoursHelper.restingLog(
      date: DateTime(2026, 8, 16),
      hour: 23,
      loggedAt: DateTime(2026, 8, 17, 10),
    );
    await HourlyLogWriter.persist([work], syncToNotion: false);
    await HourlyLogWriter.persist([resting], syncToNotion: false);

    final slot = Prefs.hourlyLogs
        .where((log) => log.dateStr == '2026-08-16' && log.hour == 23)
        .toList();
    expect(slot, hasLength(1));
    expect(slot.single.tagId, 'tag_deep_work');
  });

  test('persist saves a one-tap work log', () async {
    const tag = TrackerTag(
      id: 'tag_deep_work',
      name: 'Deep Work',
      icon: '🧠',
      colorHex: '#34A853',
      isDefault: true,
    );
    final log = HourlyLogWriter.build(
      date: DateTime(2026, 8, 17),
      hour: 14,
      tag: tag,
    );
    await HourlyLogWriter.persist([log], syncToNotion: false);

    expect(Prefs.hourlyLogs, hasLength(1));
    expect(Prefs.hourlyLogs.first.id, 'hlog_2026-08-17_14_tag_deep_work');
    expect(Prefs.hourlyLogs.first.durationMinutes, 60);
  });

  test('creditTimerMinutes splits two tags and stays additive', () async {
    Prefs.enableNotionSync = false;
    const deep = TrackerTag(
      id: 'tag_deep_work',
      name: 'Deep Work',
      icon: '🧠',
      colorHex: '#34A853',
      isDefault: true,
    );
    const coding = TrackerTag(
      id: 'tag_coding',
      name: 'Coding & Dev',
      icon: '💻',
      colorHex: '#4285F4',
      isDefault: true,
    );
    await HourlyLogWriter.creditTimerMinutes(
      tags: const [deep, coding],
      from: DateTime(2026, 9, 3, 14, 52),
      to: DateTime(2026, 9, 3, 15, 17),
      totalMinutes: 25,
      loggedAt: DateTime(2026, 9, 3, 15, 17),
      syncToNotion: false,
    );

    final hour14 = Prefs.hourlyLogs.where((log) => log.hour == 14).toList();
    final hour15 = Prefs.hourlyLogs.where((log) => log.hour == 15).toList();
    expect(
      hour14.fold<int>(0, (sum, log) => sum + log.durationMinutes),
      8,
    );
    expect(
      hour15.fold<int>(0, (sum, log) => sum + log.durationMinutes),
      17,
    );
    expect(hour14, hasLength(2));
  });
}
