import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/notification_helper.dart';

void main() {
  group('NotificationHelper.shouldShowDesktopLapNotification', () {
    test('returns false when master toggle is off', () {
      final result = NotificationHelper.shouldShowDesktopLapNotification(
        type: NotificationType.workEnd,
        enableDesktopNotifications: false,
      );
      expect(result, isFalse);
    });

    test('returns true for all lap lifecycle events by default', () {
      for (final type in [
        NotificationType.workStart,
        NotificationType.workEnd,
        NotificationType.shortBreakStart,
        NotificationType.shortBreakEnd,
        NotificationType.longBreakStart,
        NotificationType.longBreakEnd,
        NotificationType.startStop,
      ]) {
        final result = NotificationHelper.shouldShowDesktopLapNotification(
          type: type,
          enableDesktopNotifications: true,
        );
        expect(result, isTrue, reason: '$type should notify by default');
      }
    });

    test('returns false for tick and nextLap', () {
      for (final type in [
        NotificationType.tick,
        NotificationType.nextLap,
      ]) {
        final result = NotificationHelper.shouldShowDesktopLapNotification(
          type: type,
          enableDesktopNotifications: true,
        );
        expect(result, isFalse, reason: '$type should not notify by default');
      }
    });
  });

  group('NotificationHelper.shouldShowDesktopHourlyNotification', () {
    test('requires both desktop notifications and time tracker', () {
      expect(
        NotificationHelper.shouldShowDesktopHourlyNotification(
          enableDesktopNotifications: true,
          enableTimeTracker: false,
          enableQuietHours: true,
          quietHoursStart: '23:00',
          quietHoursEnd: '07:00',
          now: DateTime(2026, 7, 19, 12),
        ),
        isFalse,
      );
      expect(
        NotificationHelper.shouldShowDesktopHourlyNotification(
          enableDesktopNotifications: false,
          enableTimeTracker: true,
          enableQuietHours: true,
          quietHoursStart: '23:00',
          quietHoursEnd: '07:00',
          now: DateTime(2026, 7, 19, 12),
        ),
        isFalse,
      );
      expect(
        NotificationHelper.shouldShowDesktopHourlyNotification(
          enableDesktopNotifications: true,
          enableTimeTracker: true,
          enableQuietHours: true,
          quietHoursStart: '23:00',
          quietHoursEnd: '07:00',
          now: DateTime(2026, 7, 19, 12),
        ),
        isTrue,
      );
    });

    test('respects quiet hours', () {
      expect(
        NotificationHelper.shouldShowDesktopHourlyNotification(
          enableDesktopNotifications: true,
          enableTimeTracker: true,
          enableQuietHours: true,
          quietHoursStart: '23:00',
          quietHoursEnd: '07:00',
          now: DateTime(2026, 7, 19, 2),
        ),
        isFalse,
      );
    });

    test('does not suppress reminders when quiet hours are disabled', () {
      expect(
        NotificationHelper.shouldShowDesktopHourlyNotification(
          enableDesktopNotifications: true,
          enableTimeTracker: true,
          enableQuietHours: false,
          quietHoursStart: '23:00',
          quietHoursEnd: '07:00',
          now: DateTime(2026, 7, 19, 2),
        ),
        isTrue,
      );
    });
  });

  group('NotificationHelper.crossedHourBoundary', () {
    test('false within the same hour', () {
      expect(
        NotificationHelper.crossedHourBoundary(
          now: DateTime(2026, 7, 19, 15, 59),
          lastHandled: DateTime(2026, 7, 19, 15),
        ),
        isFalse,
      );
    });

    test('true on the first tick of a new hour, even a late one', () {
      expect(
        NotificationHelper.crossedHourBoundary(
          now: DateTime(2026, 7, 19, 15, 37),
          lastHandled: DateTime(2026, 7, 19, 14, 52),
        ),
        isTrue,
      );
    });

    test('true across midnight even with equal hour values', () {
      expect(
        NotificationHelper.crossedHourBoundary(
          now: DateTime(2026, 7, 20, 14, 5),
          lastHandled: DateTime(2026, 7, 19, 14, 30),
        ),
        isTrue,
      );
    });

    test('false when nothing was handled yet', () {
      expect(
        NotificationHelper.crossedHourBoundary(
          now: DateTime(2026, 7, 19, 15),
          lastHandled: null,
        ),
        isFalse,
      );
    });
  });

  group('NotificationHelper.completedHourBlock', () {
    test('returns the previous hour of the same day mid-day', () {
      final block =
          NotificationHelper.completedHourBlock(DateTime(2026, 7, 19, 15, 4));
      expect(block.hour, 14);
      expect(block.date, DateTime(2026, 7, 19));
    });

    test('wraps to hour 23 of the previous day just after midnight', () {
      final block =
          NotificationHelper.completedHourBlock(DateTime(2026, 7, 20, 0, 10));
      expect(block.hour, 23);
      expect(block.date, DateTime(2026, 7, 19));
    });
  });

  group('NotificationHelper payloads', () {
    test('round-trips hourly payload', () {
      final payload = NotificationHelper.hourlyPayload(
        hour: 14,
        date: DateTime(2026, 7, 19),
      );
      expect(payload, 'hourly:14:2026-07-19');

      final action = NotificationHelper.parsePayload(payload);
      expect(action, isA<HourlyLogAction>());
      final hourly = action! as HourlyLogAction;
      expect(hourly.hour, 14);
      expect(hourly.date.year, 2026);
      expect(hourly.date.month, 7);
      expect(hourly.date.day, 19);
    });

    test('parses timer payload as focus main window', () {
      final payload = NotificationHelper.lapPayload(NotificationType.workEnd);
      expect(payload, 'timer:workEnd');
      expect(
        NotificationHelper.parsePayload(payload),
        isA<FocusMainWindowAction>(),
      );
    });

    test('returns null for unknown payload', () {
      expect(NotificationHelper.parsePayload(null), isNull);
      expect(NotificationHelper.parsePayload(''), isNull);
      expect(NotificationHelper.parsePayload('junk'), isNull);
    });
  });

  group('NotificationHelper.lapNotificationCopy', () {
    test('returns copy for lap events and pause, null for tick', () {
      expect(
        NotificationHelper.lapNotificationCopy(NotificationType.workEnd)?.title,
        'Work Session Finished',
      );
      expect(
        NotificationHelper.lapNotificationCopy(NotificationType.startStop)
            ?.title,
        'Timer Paused',
      );
      expect(
        NotificationHelper.lapNotificationCopy(NotificationType.tick),
        isNull,
      );
    });
  });
}
