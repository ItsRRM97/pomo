import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/hourly_log.dart';

void main() {
  group('HourlyLog', () {
    test('supports value equality', () {
      final now = DateTime.utc(2026, 7, 13, 14);
      final logA = HourlyLog(
        id: 'hlog_1',
        dateStr: '2026-07-13',
        hour: 14,
        tagId: 'tag_coding',
        tagName: 'Coding & Dev',
        tagIcon: '💻',
        tagColorHex: '#4285F4',
        projectId: 'proj_1',
        projectTitle: 'Pomo App',
        notes: 'Refactoring UI',
        notionPageId: 'notion_1',
        loggedAt: now,
      );
      final logB = HourlyLog(
        id: 'hlog_1',
        dateStr: '2026-07-13',
        hour: 14,
        tagId: 'tag_coding',
        tagName: 'Coding & Dev',
        tagIcon: '💻',
        tagColorHex: '#4285F4',
        projectId: 'proj_1',
        projectTitle: 'Pomo App',
        notes: 'Refactoring UI',
        notionPageId: 'notion_1',
        loggedAt: now,
      );
      expect(logA, equals(logB));
    });

    test('toJson and fromJson correctly serialize and deserialize', () {
      final now = DateTime.utc(2026, 7, 13, 14);
      final log = HourlyLog(
        id: 'hlog_1',
        dateStr: '2026-07-13',
        hour: 14,
        tagId: 'tag_coding',
        tagName: 'Coding & Dev',
        tagIcon: '💻',
        tagColorHex: '#4285F4',
        projectId: 'proj_1',
        projectTitle: 'Pomo App',
        notes: 'Refactoring UI',
        notionPageId: 'notion_1',
        loggedAt: now,
      );

      final json = log.toJson();
      final fromJsonLog = HourlyLog.fromJson(json);

      expect(fromJsonLog.id, equals(log.id));
      expect(fromJsonLog.dateStr, equals(log.dateStr));
      expect(fromJsonLog.hour, equals(log.hour));
      expect(fromJsonLog.tagId, equals(log.tagId));
      expect(fromJsonLog.tagName, equals(log.tagName));
      expect(fromJsonLog.tagIcon, equals(log.tagIcon));
      expect(fromJsonLog.tagColorHex, equals(log.tagColorHex));
      expect(fromJsonLog.projectId, equals(log.projectId));
      expect(fromJsonLog.projectTitle, equals(log.projectTitle));
      expect(fromJsonLog.notes, equals(log.notes));
      expect(fromJsonLog.notionPageId, equals(log.notionPageId));
      expect(fromJsonLog.durationMinutes, equals(60));
    });

    test('supports custom durationMinutes and copyWith', () {
      final now = DateTime.utc(2026, 7, 13, 14);
      final log = HourlyLog(
        id: 'hlog_2',
        dateStr: '2026-07-13',
        hour: 15,
        tagId: 'tag_meeting',
        tagName: 'Meeting',
        tagIcon: '📞',
        tagColorHex: '#FF5722',
        durationMinutes: 30,
        loggedAt: now,
      );

      expect(log.durationMinutes, equals(30));
      final copied = log.copyWith(durationMinutes: 20);
      expect(copied.durationMinutes, equals(20));
      expect(HourlyLog.fromJson(log.toJson()).durationMinutes, equals(30));
    });
  });
}
