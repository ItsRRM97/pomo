import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/tag_reassign_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';

void main() {
  group('TagReassignHelper', () {
    const deepWork = TrackerTag(
      id: 'tag_deep_work',
      name: 'Deep Work',
      icon: '🧠',
      colorHex: '#34A853',
      isDefault: true,
    );
    const recoveredDeepWork = TrackerTag(
      id: 'tag_custom_recovered_deep_work',
      name: 'Deep Work',
      icon: '🧠',
      colorHex: '#4285F4',
    );

    test('reassignLogsInMemory updates tag fields and ids', () {
      final logs = [
        HourlyLog(
          id: 'hlog_2026-09-03_14_tag_custom_recovered_deep_work',
          dateStr: '2026-09-03',
          hour: 14,
          tagId: recoveredDeepWork.id,
          tagName: recoveredDeepWork.name,
          tagIcon: recoveredDeepWork.icon,
          tagColorHex: recoveredDeepWork.colorHex,
          loggedAt: DateTime(2026, 9, 3, 14, 30),
        ),
      ];

      final result = TagReassignHelper.reassignLogsInMemory(
        logs: logs,
        fromId: recoveredDeepWork.id,
        toTag: deepWork,
      );

      expect(result, hasLength(1));
      expect(result.single.tagId, deepWork.id);
      expect(result.single.id, 'hlog_2026-09-03_14_tag_deep_work');
      expect(result.single.tagName, deepWork.name);
    });

    test('mergeDuplicatesInSlot sums minutes and joins notes', () {
      final merged = TagReassignHelper.mergeLogs(
        [
          HourlyLog(
            id: 'hlog_2026-09-03_14_tag_deep_work',
            dateStr: '2026-09-03',
            hour: 14,
            tagId: deepWork.id,
            tagName: deepWork.name,
            tagIcon: deepWork.icon,
            tagColorHex: deepWork.colorHex,
            notes: 'Focus',
            durationMinutes: 30,
            loggedAt: DateTime(2026, 9, 3, 14, 10),
          ),
          HourlyLog(
            id: 'hlog_2026-09-03_14_tag_custom_recovered_deep_work',
            dateStr: '2026-09-03',
            hour: 14,
            tagId: recoveredDeepWork.id,
            tagName: recoveredDeepWork.name,
            tagIcon: recoveredDeepWork.icon,
            tagColorHex: recoveredDeepWork.colorHex,
            notes: 'Reading',
            durationMinutes: 20,
            loggedAt: DateTime(2026, 9, 3, 14, 40),
          ),
        ],
        dateStr: '2026-09-03',
        hour: 14,
        tagId: deepWork.id,
      );

      expect(merged.durationMinutes, 50);
      expect(merged.notes, contains('Focus'));
      expect(merged.notes, contains('Reading'));
      expect(merged.id, 'hlog_2026-09-03_14_tag_deep_work');
    });
  });
}
