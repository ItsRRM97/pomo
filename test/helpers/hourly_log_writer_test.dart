import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/models/tracker_tag.dart';
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
}
