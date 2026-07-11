import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/notion_task.dart';

void main() {
  group('NotionTask', () {
    const testTask = NotionTask(
      id: 'task-123',
      title: 'Finish Pomo Web App',
      status: 'In Progress',
      priority: 'High',
      projectId: 'proj-456',
      projectTitle: 'PARA Dashboard',
      timeHours: 2,
      timeMinutes: 30,
    );

    test('supports value comparisons via Equatable', () {
      expect(
        testTask,
        equals(
          const NotionTask(
            id: 'task-123',
            title: 'Finish Pomo Web App',
            status: 'In Progress',
            priority: 'High',
            projectId: 'proj-456',
            projectTitle: 'PARA Dashboard',
            timeHours: 2,
            timeMinutes: 30,
          ),
        ),
      );
    });

    test('timeTotalMin calculates correctly', () {
      expect(testTask.timeTotalMin, equals(150));
    });

    test('timeLoggedFormatted formats duration cleanly', () {
      expect(testTask.timeLoggedFormatted, equals('2h 30m'));

      const zeroTask = NotionTask(id: '1', title: 'Zero');
      expect(zeroTask.timeLoggedFormatted, equals('0m'));

      const hoursOnly = NotionTask(id: '2', title: 'Hours', timeHours: 3);
      expect(hoursOnly.timeLoggedFormatted, equals('3h'));

      const minsOnly = NotionTask(id: '3', title: 'Mins', timeMinutes: 45);
      expect(minsOnly.timeLoggedFormatted, equals('45m'));
    });

    test('copyWith updates fields via function-based parameters', () {
      final updated = testTask.copyWith(
        title: () => 'Updated Title',
        timeHours: () => 3,
        projectId: () => null,
      );

      expect(updated.title, equals('Updated Title'));
      expect(updated.timeHours, equals(3));
      expect(updated.projectId, isNull);
      expect(updated.status, equals(testTask.status));
    });

    test('toJson and fromJson serialize and deserialize accurately', () {
      final json = testTask.toJson();
      final deserialized = NotionTask.fromJson(json);
      expect(deserialized, equals(testTask));
    });

    test('fromNotionApi parses Notion API payload', () {
      final payload = {
        'id': 'notion-id-789',
        'properties': {
          'Name': {
            'title': [
              {
                'text': {'content': 'Refactor Cubits'},
              },
            ],
          },
          'Done': {
            'status': {'name': 'To Do'},
          },
          'Priority': {
            'select': {'name': 'Critical'},
          },
          'Due': {
            'date': {'start': '2026-07-11'},
          },
          'Project': {
            'relation': [
              {'id': 'proj-id-999'},
            ],
          },
          'Time (hours)': {'number': 1},
          'Time (minutes)': {'number': 15},
        },
      };

      final parsed = NotionTask.fromNotionApi(payload);
      expect(parsed.id, equals('notion-id-789'));
      expect(parsed.title, equals('Refactor Cubits'));
      expect(parsed.status, equals('To Do'));
      expect(parsed.priority, equals('Critical'));
      expect(parsed.due, equals(DateTime(2026, 7, 11)));
      expect(parsed.projectId, equals('proj-id-999'));
      expect(parsed.timeHours, equals(1));
      expect(parsed.timeMinutes, equals(15));
    });
  });
}
