import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/services/notion_sync_service.dart';

HourlyLog _log({
  required String id,
  required String tagId,
  required int minutes,
  required DateTime loggedAt,
}) {
  return HourlyLog(
    id: id,
    dateStr: '2026-07-19',
    hour: 14,
    tagId: tagId,
    tagName: tagId,
    tagIcon: '⏱️',
    tagColorHex: '#4285F4',
    durationMinutes: minutes,
    loggedAt: loggedAt,
  );
}

void main() {
  group('currentHourlySlotRevision', () {
    test('keeps all tags from the latest 60-minute revision', () {
      final latest = DateTime.utc(2026, 7, 19, 14, 30);
      final logs = [
        _log(
          id: 'old',
          tagId: 'old',
          minutes: 60,
          loggedAt: latest.subtract(const Duration(minutes: 5)),
        ),
        _log(
          id: 'new-a',
          tagId: 'new-a',
          minutes: 30,
          loggedAt: latest,
        ),
        _log(
          id: 'new-b',
          tagId: 'new-b',
          minutes: 30,
          loggedAt: latest,
        ),
      ];

      final current = NotionSyncService.currentHourlySlotRevision(logs);

      expect(current.map((log) => log.id), containsAll(['new-a', 'new-b']));
      expect(current, hasLength(2));
      expect(
        current.fold<int>(0, (total, log) => total + log.durationMinutes),
        60,
      );
    });

    test('does not double-count two full-hour device writes', () {
      final latest = DateTime.utc(2026, 7, 19, 14, 30);
      final logs = [
        _log(
          id: 'pwa',
          tagId: 'pwa-status',
          minutes: 60,
          loggedAt: latest.subtract(const Duration(minutes: 1)),
        ),
        _log(
          id: 'macos',
          tagId: 'macos-status',
          minutes: 60,
          loggedAt: latest,
        ),
      ];

      final current = NotionSyncService.currentHourlySlotRevision(logs);

      expect(current, hasLength(1));
      expect(current.single.id, 'macos');
      expect(current.single.durationMinutes, 60);
    });

    test('user Work wins over newer auto-Resting for the same full hour', () {
      final workAt = DateTime.utc(2026, 8, 16, 23, 5);
      final logs = [
        _log(
          id: 'hlog_2026-08-16_23_tag_deep_work',
          tagId: 'tag_deep_work',
          minutes: 60,
          loggedAt: workAt,
        ).copyWith(
          dateStr: '2026-08-16',
          hour: 23,
          tagName: 'Deep Work',
        ),
        _log(
          id: 'hlog_2026-08-16_23_tag_sleep',
          tagId: 'tag_sleep',
          minutes: 60,
          loggedAt: workAt.add(const Duration(hours: 11)),
        ).copyWith(
          dateStr: '2026-08-16',
          hour: 23,
          tagName: 'Sleep & Rest',
          notes: 'Resting',
        ),
      ];

      final current = NotionSyncService.currentHourlySlotRevision(logs);

      expect(current, hasLength(1));
      expect(current.single.tagId, 'tag_deep_work');
    });

    test('newer remote Work replaces local Resting in a combined slot', () {
      final restingAt = DateTime.utc(2026, 8, 16, 23, 1);
      final workAt = DateTime.utc(2026, 8, 16, 23, 30);
      final logs = [
        _log(
          id: 'hlog_2026-08-16_23_tag_sleep',
          tagId: 'tag_sleep',
          minutes: 60,
          loggedAt: restingAt,
        ).copyWith(
          dateStr: '2026-08-16',
          hour: 23,
          tagName: 'Sleep & Rest',
          notes: 'Resting',
        ),
        _log(
          id: 'hlog_2026-08-16_23_tag_deep_work',
          tagId: 'tag_deep_work',
          minutes: 60,
          loggedAt: workAt,
        ).copyWith(
          dateStr: '2026-08-16',
          hour: 23,
          tagName: 'Deep Work',
        ),
      ];

      final current = NotionSyncService.currentHourlySlotRevision(logs);

      expect(current, hasLength(1));
      expect(current.single.tagId, 'tag_deep_work');
    });

    test('supports legacy multi-tag writes timestamped seconds apart', () {
      final latest = DateTime.utc(2026, 7, 19, 14, 30, 4);
      final logs = [
        _log(
          id: 'tag-a',
          tagId: 'tag-a',
          minutes: 20,
          loggedAt: latest.subtract(const Duration(seconds: 4)),
        ),
        _log(
          id: 'tag-b',
          tagId: 'tag-b',
          minutes: 20,
          loggedAt: latest.subtract(const Duration(seconds: 2)),
        ),
        _log(
          id: 'tag-c',
          tagId: 'tag-c',
          minutes: 20,
          loggedAt: latest,
        ),
      ];

      final current = NotionSyncService.currentHourlySlotRevision(logs);

      expect(current, hasLength(3));
      expect(
        current.fold<int>(0, (total, log) => total + log.durationMinutes),
        60,
      );
    });
  });
}
