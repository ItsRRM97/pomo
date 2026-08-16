import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pomo/app/view/app.dart';
import 'package:pomo/helpers/hourly_log_writer.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/tracker/view/hourly_log_dialog.dart';
import 'package:pomo/singletons/prefs.dart';

/// App-level navigation requests from desktop notification taps, etc.
class AppNavigationController {
  AppNavigationController._();

  static final AppNavigationController instance = AppNavigationController._();

  /// Default tag for shade "Log 60m Work" (DESIGN one-tap check-in).
  static TrackerTag get instantWorkTag => TrackerTag.defaults.firstWhere(
        (tag) => tag.id == 'tag_deep_work',
      );

  final ValueNotifier<int?> tabIndex = ValueNotifier<int?>(null);

  /// Handle a parsed notification action: show UI and route as needed.
  Future<void> handleNotificationAction(NotificationAction? action) async {
    if (action == null) {
      return;
    }

    switch (action) {
      case FocusMainWindowAction():
        tabIndex.value = 0;
      case OpenTrackerAction():
        tabIndex.value = 1;
      case HourlyInstantWriteAction(:final hour, :final date):
        tabIndex.value = 1;
        await _writeInstantHourlyLog(hour: hour, date: date);
      case HourlyLogAction(:final hour, :final date):
        tabIndex.value = 1;
        // Wait a beat so HomeShell can switch tabs before the dialog opens.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await _openHourlyLogDialog(hour: hour, date: date);
    }
  }

  Future<void> _writeInstantHourlyLog({
    required int hour,
    required DateTime date,
  }) async {
    final dateStr = QuietHoursHelper.dateStr(date);
    final alreadyLogged = Prefs.hourlyLogs.any(
      (log) => log.dateStr == dateStr && log.hour == hour,
    );
    if (alreadyLogged) {
      return;
    }

    final log = HourlyLogWriter.build(
      date: date,
      hour: hour,
      tag: instantWorkTag,
    );
    await HourlyLogWriter.persist([log]);

    try {
      final context = App.navigatorKey.currentContext;
      if (context == null || !context.mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${log.tagName} for $dateStr '
            '${hour.toString().padLeft(2, '0')}:00',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              Prefs.hourlyLogs = Prefs.hourlyLogs
                  .where((existing) => existing.id != log.id)
                  .toList();
            },
          ),
        ),
      );
    } catch (_) {
      // Unit tests may run without a WidgetsBinding / navigator.
    }
  }

  Future<void> _openHourlyLogDialog({
    required int hour,
    required DateTime date,
  }) async {
    final navigator = App.navigatorKey.currentState;
    final context = App.navigatorKey.currentContext;
    if (navigator == null || context == null || !context.mounted) {
      return;
    }

    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';
    final existing = Prefs.hourlyLogs
        .where((log) => log.dateStr == dateStr && log.hour == hour)
        .toList();

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => HourlyLogDialog(
        selectedDate: date,
        hour: hour,
        existingLog: existing.isEmpty ? null : existing.first,
        existingLogsForHour: existing.isEmpty ? null : existing,
      ),
    );
  }
}
