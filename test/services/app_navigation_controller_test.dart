import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/app_navigation_controller.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppNavigationController.handleNotificationAction', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
      AppNavigationController.instance.tabIndex.value = null;
    });

    tearDown(() {
      AppNavigationController.instance.tabIndex.value = null;
    });

    test('OpenTrackerAction sets tabIndex to 1 only', () async {
      await AppNavigationController.instance.handleNotificationAction(
        const OpenTrackerAction(),
      );
      expect(AppNavigationController.instance.tabIndex.value, 1);
    });

    test('FocusMainWindowAction sets tabIndex to 0', () async {
      await AppNavigationController.instance.handleNotificationAction(
        const FocusMainWindowAction(),
      );
      expect(AppNavigationController.instance.tabIndex.value, 0);
    });

    test('HourlyInstantWriteAction writes Deep Work without a dialog',
        () async {
      await AppNavigationController.instance.handleNotificationAction(
        HourlyInstantWriteAction(
          hour: 14,
          date: DateTime(2026, 8, 17),
        ),
      );

      expect(AppNavigationController.instance.tabIndex.value, 1);
      expect(Prefs.hourlyLogs, hasLength(1));
      final log = Prefs.hourlyLogs.first;
      expect(log.hour, 14);
      expect(log.tagId, 'tag_deep_work');
      expect(log.durationMinutes, 60);
      expect(log.id, 'hlog_2026-08-17_14_tag_deep_work');
    });

    test('HourlyInstantWriteAction skips when the hour is already logged',
        () async {
      final existing = HourlyLogWriter.build(
        date: DateTime(2026, 8, 17),
        hour: 14,
        tag: TrackerTag.defaults.firstWhere((t) => t.id == 'tag_coding'),
      );
      await HourlyLogWriter.persist([existing], syncToNotion: false);

      await AppNavigationController.instance.handleNotificationAction(
        HourlyInstantWriteAction(
          hour: 14,
          date: DateTime(2026, 8, 17),
        ),
      );

      expect(Prefs.hourlyLogs, hasLength(1));
      expect(Prefs.hourlyLogs.first.tagId, 'tag_coding');
    });
  });
}
