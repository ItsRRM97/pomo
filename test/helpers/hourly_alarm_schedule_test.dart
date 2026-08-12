import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/hourly_alarm_schedule.dart';

void main() {
  group('nextHourBoundary', () {
    test('nextHourBoundary snaps to upcoming hour', () {
      expect(
        nextHourBoundary(DateTime(2026, 8, 12, 14, 37)),
        DateTime(2026, 8, 12, 15),
      );
    });

    test('snaps from exact hour to next hour', () {
      expect(
        nextHourBoundary(DateTime(2026, 8, 12, 15)),
        DateTime(2026, 8, 12, 16),
      );
    });

    test('crosses midnight into the next day', () {
      expect(
        nextHourBoundary(DateTime(2026, 8, 12, 23, 5)),
        DateTime(2026, 8, 13),
      );
    });
  });
}
