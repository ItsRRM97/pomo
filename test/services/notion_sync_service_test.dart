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
