import 'package:pomo/helpers/notification_type.dart';
import 'package:pomo/helpers/sound_helper.dart';

export 'package:pomo/helpers/notification_type.dart';

/// Pure gating + copy helpers for desktop/macOS notifications.
///
/// Kept free of Flutter platform channels so unit tests can cover quiet hours,
/// master toggles, and the default event set without a device.
mixin NotificationHelper {
  /// Lap events that fire macOS notifications by default.
  ///
  /// Timer events are user-initiated (the user started or paused the timer),
  /// so they intentionally ignore quiet hours; only the unattended hourly
  /// reminder respects them.
  static const Set<NotificationType> defaultDesktopLapTypes = {
    NotificationType.workStart,
    NotificationType.workEnd,
    NotificationType.shortBreakStart,
    NotificationType.shortBreakEnd,
    NotificationType.longBreakStart,
    NotificationType.longBreakEnd,
    NotificationType.startStop,
  };

  /// Whether a lap lifecycle notification should be shown on desktop.
  static bool shouldShowDesktopLapNotification({
    required NotificationType type,
    required bool enableDesktopNotifications,
  }) {
    if (!enableDesktopNotifications) {
      return false;
    }
    return defaultDesktopLapTypes.contains(type);
  }

  /// Whether the hourly "log the hour" reminder should notify on desktop.
  static bool shouldShowDesktopHourlyNotification({
    required bool enableDesktopNotifications,
    required bool enableTimeTracker,
    required bool enableQuietHours,
    required String quietHoursStart,
    required String quietHoursEnd,
    DateTime? now,
  }) {
    if (!enableDesktopNotifications || !enableTimeTracker) {
      return false;
    }
    if (enableQuietHours &&
        SoundHelper.isQuietHours(
          start: quietHoursStart,
          end: quietHoursEnd,
          now: now,
        )) {
      return false;
    }
    return true;
  }

  /// Title/body for a lap notification. Returns null when the type is skipped.
  static ({String title, String body})? lapNotificationCopy(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.workStart:
        return (title: 'Work Session Started', body: 'Time to focus!');
      case NotificationType.workEnd:
        return (
          title: 'Work Session Finished',
          body: 'Take a break!',
        );
      case NotificationType.shortBreakStart:
        return (title: 'Short Break Started', body: 'Rest and recharge!');
      case NotificationType.shortBreakEnd:
        return (
          title: 'Short Break Finished',
          body: "Break's over - back to work!"
        );
      case NotificationType.longBreakStart:
        return (title: 'Long Break Started', body: 'Relax for a bit!');
      case NotificationType.longBreakEnd:
        return (
          title: 'Long Break Finished',
          body: "Break's over - back to work!"
        );
      case NotificationType.nextLap:
        return (title: 'Next Lap', body: 'Moving to next lap.');
      case NotificationType.startStop:
        return (title: 'Timer Paused', body: 'Resume when you are ready.');
      case NotificationType.tick:
        return null;
    }
  }

  /// True when [now] sits in a different clock hour than [lastHandled].
  ///
  /// Used by the hourly reminder loop as a catch-up trigger: even if App Nap
  /// delays the periodic tick well past the top of the hour, the first tick
  /// that lands in a new hour still fires exactly one reminder.
  static bool crossedHourBoundary({
    required DateTime now,
    required DateTime? lastHandled,
  }) {
    if (lastHandled == null) {
      return false;
    }
    return now.year != lastHandled.year ||
        now.month != lastHandled.month ||
        now.day != lastHandled.day ||
        now.hour != lastHandled.hour;
  }

  /// The 1-hour block that just finished before [now].
  ///
  /// At 15:05 this is hour 14 of the same day; at 00:10 it is hour 23 of the
  /// previous day. The hourly reminder asks the user to log this block, not
  /// the hour that just started.
  static ({int hour, DateTime date}) completedHourBlock(DateTime now) {
    final blockStart = DateTime(now.year, now.month, now.day, now.hour)
        .subtract(const Duration(hours: 1));
    return (
      hour: blockStart.hour,
      date: DateTime(blockStart.year, blockStart.month, blockStart.day),
    );
  }

  static String hourlyNotificationTitle() => 'Time Tracker: Check-in Required';

  static String hourlyNotificationBody(int hour) {
    final start = hour.toString().padLeft(2, '0');
    final end = ((hour + 1) % 24).toString().padLeft(2, '0');
    return 'Log what you did between $start:00 and $end:00.';
  }

  /// Payload for an hourly check-in notification.
  static String hourlyPayload({required int hour, required DateTime date}) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'hourly:$hour:$y-$m-$d';
  }

  /// Payload for a timer lap notification.
  static String lapPayload(NotificationType type) => 'timer:${type.name}';

  /// Parse a notification payload into a typed action, or null if unknown.
  static NotificationAction? parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    if (payload.startsWith('hourly:')) {
      final parts = payload.split(':');
      if (parts.length < 3) {
        return null;
      }
      final hour = int.tryParse(parts[1]);
      if (hour == null || hour < 0 || hour > 23) {
        return null;
      }
      final date = DateTime.tryParse(parts.sublist(2).join(':'));
      if (date == null) {
        return null;
      }
      return HourlyLogAction(hour: hour, date: date);
    }
    if (payload.startsWith('timer:')) {
      return const FocusMainWindowAction();
    }
    return null;
  }
}

/// Result of parsing a notification tap payload.
sealed class NotificationAction {
  const NotificationAction();
}

/// Open the tracker and prompt logging for [hour] on [date].
final class HourlyLogAction extends NotificationAction {
  const HourlyLogAction({required this.hour, required this.date});

  final int hour;
  final DateTime date;
}

/// Bring the main window to the front (timer events).
final class FocusMainWindowAction extends NotificationAction {
  const FocusMainWindowAction();
}
