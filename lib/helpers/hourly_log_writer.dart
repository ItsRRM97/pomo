import 'dart:async';

import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Builds and persists hourly logs without a [BuildContext].
class HourlyLogWriter {
  /// Instant 60-minute log for [hour] on [date] using [tag].
  static HourlyLog build({
    required DateTime date,
    required int hour,
    required TrackerTag tag,
    DateTime? loggedAt,
    String notes = '',
  }) {
    final ds = QuietHoursHelper.dateStr(date);
    return HourlyLog(
      id: QuietHoursHelper.logId(dateStr: ds, hour: hour, tagId: tag.id),
      dateStr: ds,
      hour: hour,
      tagId: tag.id,
      tagName: tag.name,
      tagIcon: tag.icon,
      tagColorHex: tag.colorHex,
      notes: notes,
      loggedAt: loggedAt ?? DateTime.now(),
    );
  }

  /// Saves [logs] locally. Optionally queues Notion sync when enabled.
  static Future<int> persist(
    Iterable<HourlyLog> logs, {
    bool syncToNotion = true,
  }) async {
    var count = 0;
    for (final log in logs) {
      await Prefs.saveHourlyLog(log);
      count++;
      if (syncToNotion &&
          Prefs.enableNotionSync &&
          Prefs.notionApiKey.isNotEmpty &&
          Prefs.notionHourlyTimelineDatabaseId.isNotEmpty) {
        unawaited(NotionSyncService().syncHourlyLog(log));
      }
    }
    return count;
  }

  /// Writes missing quiet-hour Resting logs for the recent lookback.
  static Future<int> reconcileResting({DateTime? now}) async {
    if (!Prefs.enableTimeTracker) {
      return 0;
    }
    final missing = QuietHoursHelper.missingRestingLogs(
      now: now ?? DateTime.now(),
      existing: Prefs.hourlyLogs,
      enableQuietHours: Prefs.enableQuietHours,
      start: Prefs.quietHoursStart,
      end: Prefs.quietHoursEnd,
    );
    return persist(missing);
  }
}
