import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/quiet_hours_helper.dart';

void main() {
  group('QuietHoursHelper.isQuietHourIndex', () {
    test('returns false when quiet hours are disabled', () {
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 23,
          enableQuietHours: false,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 2,
          enableQuietHours: false,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
    });

    test('treats overnight window as sleep hours when enabled', () {
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 23,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 0,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 6,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 7,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 22,
          enableQuietHours: true,
          start: '23:00',
          end: '07:00',
        ),
        isFalse,
      );
    });

    test('treats same-day window as sleep hours when enabled', () {
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 13,
          enableQuietHours: true,
          start: '12:00',
          end: '14:00',
        ),
        isTrue,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 14,
          enableQuietHours: true,
          start: '12:00',
          end: '14:00',
        ),
        isFalse,
      );
      expect(
        QuietHoursHelper.isQuietHourIndex(
          hour: 11,
          enableQuietHours: true,
          start: '12:00',
          end: '14:00',
        ),
        isFalse,
      );
    });
  });
}
