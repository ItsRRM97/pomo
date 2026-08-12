import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/services/android_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidNotificationService notification tap', () {
    test('onNotificationTap routes hourly payload via parsePayload', () {
      final action = AndroidNotificationService.actionFromNotificationTap(
        'hourly:14:2026-08-12',
      );
      expect(action, isA<HourlyLogAction>());
      final hourly = action! as HourlyLogAction;
      expect(hourly.hour, 14);
      expect(hourly.date, DateTime(2026, 8, 12));
    });

    test('actionFromNotificationTap returns null for empty payload', () {
      expect(
        AndroidNotificationService.actionFromNotificationTap(null),
        isNull,
      );
      expect(AndroidNotificationService.actionFromNotificationTap(''), isNull);
    });

    test('onNotificationTap routes hourly action suffixes', () {
      expect(
        AndroidNotificationService.actionFromNotificationTap(
          'hourly:14:2026-08-12:log_work',
        ),
        isA<HourlyLogAction>(),
      );
      expect(
        AndroidNotificationService.actionFromNotificationTap(
          'hourly:14:2026-08-12:switch_tag',
        ),
        isA<HourlyLogAction>(),
      );
      expect(
        AndroidNotificationService.actionFromNotificationTap(
          'hourly:14:2026-08-12:open_grid',
        ),
        isA<OpenTrackerAction>(),
      );
    });
  });

  group('AndroidNotificationService pending pull', () {
    const channel = MethodChannel('com.recoskyler.pomo/timer_notification');

    late List<String> channelCalls;
    String? pendingPayload;

    setUp(() {
      channelCalls = [];
      pendingPayload = 'hourly:14:2026-08-12';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        channelCalls.add(call.method);
        if (call.method == 'getPendingNotificationPayload') {
          final value = pendingPayload;
          pendingPayload = null;
          return value;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('actionFromPendingPull routes and clears pending payload', () async {
      final action =
          await AndroidNotificationService.actionFromPendingPull(channel);
      expect(action, isA<HourlyLogAction>());
      final hourly = action! as HourlyLogAction;
      expect(hourly.hour, 14);
      expect(hourly.date, DateTime(2026, 8, 12));
      expect(
        channelCalls,
        contains('getPendingNotificationPayload'),
      );

      final second =
          await AndroidNotificationService.actionFromPendingPull(channel);
      expect(second, isNull);
    });

    test('actionFromPendingPull returns null when native has none', () async {
      pendingPayload = null;
      final action =
          await AndroidNotificationService.actionFromPendingPull(channel);
      expect(action, isNull);
    });
  });

  group('AndroidNotificationService hourly notification args', () {
    test('includes pomo payload for completed hour block', () {
      final args = AndroidNotificationService.hourlyNotificationArgs(
        hour: 14,
        date: DateTime(2026, 8, 12),
      );
      expect(args['payload'], 'hourly:14:2026-08-12');
      expect(args['title'], 'Time Tracker: Check-in Required');
      expect(
        args['text'],
        'Log what you did between 14:00 and 15:00.',
      );
    });

    test('hourlyStartForegroundArgs keeps isHourly for legacy callers', () {
      final args = AndroidNotificationService.hourlyStartForegroundArgs(
        hour: 14,
        date: DateTime(2026, 8, 12),
      );
      expect(args['isHourly'], isTrue);
      expect(args['isRunning'], isFalse);
      expect(args['payload'], 'hourly:14:2026-08-12');
    });
  });

  group('AndroidNotificationService scheduleNextHourlyAlarm args', () {
    test('passes epoch millis for next hour boundary', () {
      final args = AndroidNotificationService.scheduleNextHourlyAlarmArgs(
        DateTime(2026, 8, 12, 14, 37),
        enableTimeTracker: true,
        enableQuietHours: true,
        quietHoursStart: '23:00',
        quietHoursEnd: '07:00',
      );
      expect(
        args['triggerAtMillis'],
        DateTime(2026, 8, 12, 15).millisecondsSinceEpoch,
      );
      expect(args['enableTimeTracker'], isTrue);
      expect(args['quietHoursStart'], '23:00');
      expect(args['quietHoursEnd'], '07:00');
    });
  });
}
