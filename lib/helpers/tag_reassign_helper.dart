import 'dart:convert';

import 'package:pomo/helpers/quiet_hours_helper.dart';
import 'package:pomo/helpers/tracker_tag_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Reassigns hourly logs from one activity tag to another and merges slots.
class TagReassignHelper {
  /// Counts hourly log rows referencing [tagId].
  static int countLogsForTag(String tagId, {List<HourlyLog>? logs}) {
    final source = logs ?? Prefs.hourlyLogs;
    return source.where((log) => log.tagId == tagId).length;
  }

  /// Rewrites logs in memory; does not persist.
  static List<HourlyLog> reassignLogsInMemory({
    required List<HourlyLog> logs,
    required String fromId,
    required TrackerTag toTag,
  }) {
    final hourGroups = <String, List<HourlyLog>>{};
    for (final log in logs) {
      final key = '${log.dateStr}|${log.hour}';
      hourGroups.putIfAbsent(key, () => []).add(log);
    }

    final result = <HourlyLog>[];
    for (final entry in hourGroups.entries) {
      final parts = entry.key.split('|');
      final dateStr = parts[0];
      final hour = int.parse(parts[1]);
      var slot = entry.value;

      if (!slot.any((log) => log.tagId == fromId)) {
        result.addAll(slot);
        continue;
      }

      slot = slot
          .map(
            (log) => log.tagId == fromId
                ? log.copyWith(
                    tagId: toTag.id,
                    tagName: toTag.name,
                    tagIcon: toTag.icon,
                    tagColorHex: toTag.colorHex,
                    id: QuietHoursHelper.logId(
                      dateStr: dateStr,
                      hour: hour,
                      tagId: toTag.id,
                    ),
                  )
                : log,
          )
          .toList();
      result.addAll(mergeDuplicatesInSlot(slot, dateStr: dateStr, hour: hour));
    }
    return result;
  }

  /// Merges rows that share the same tag within one hour slot.
  static List<HourlyLog> mergeDuplicatesInSlot(
    List<HourlyLog> slot, {
    required String dateStr,
    required int hour,
  }) {
    final byTagId = <String, List<HourlyLog>>{};
    for (final log in slot) {
      byTagId.putIfAbsent(log.tagId, () => []).add(log);
    }

    return [
      for (final group in byTagId.values)
        if (group.length == 1)
          group.single
        else
          mergeLogs(
            group,
            dateStr: dateStr,
            hour: hour,
            tagId: group.first.tagId,
          ),
    ];
  }

  /// Merges multiple rows for the same tag in one hour.
  static HourlyLog mergeLogs(
    List<HourlyLog> logs, {
    required String dateStr,
    required int hour,
    required String tagId,
  }) {
    final sorted = List<HourlyLog>.from(logs)
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final primary = sorted.first;

    var totalMinutes = 0;
    final notes = <String>{};
    final projectIds = <String>[];
    final projectTitles = <String>[];
    var latestLoggedAt = primary.loggedAt;

    for (final log in logs) {
      totalMinutes += log.durationMinutes;
      if (log.notes.trim().isNotEmpty) {
        notes.add(log.notes.trim());
      }
      if (log.loggedAt.isAfter(latestLoggedAt)) {
        latestLoggedAt = log.loggedAt;
      }
      _appendUnique(projectIds, log.projectId);
      _appendUnique(projectTitles, log.projectTitle);
    }

    return primary.copyWith(
      id: QuietHoursHelper.logId(
        dateStr: dateStr,
        hour: hour,
        tagId: tagId,
      ),
      durationMinutes: totalMinutes,
      notes: notes.join('; '),
      projectId: projectIds.isEmpty ? null : projectIds.join(','),
      projectTitle: projectTitles.isEmpty ? null : projectTitles.join(','),
      loggedAt: latestLoggedAt,
      notionPageId: primary.notionPageId,
    );
  }

  /// Reassigns all rows from [fromId] to [toTag], persists, and syncs Notion.
  static Future<int> reassignTagId({
    required String fromId,
    required TrackerTag toTag,
    NotionSyncService? notionSync,
  }) async {
    if (fromId == toTag.id) {
      return 0;
    }

    final before = List<HourlyLog>.from(Prefs.hourlyLogs);
    final touched = before.where((log) => log.tagId == fromId).length;
    final reassigned = reassignLogsInMemory(
      logs: before,
      fromId: fromId,
      toTag: toTag,
    );

    final modifiedHours = <(String, int)>{};
    final beforeByHour = <String, List<HourlyLog>>{};
    for (final log in before) {
      final key = '${log.dateStr}|${log.hour}';
      beforeByHour.putIfAbsent(key, () => []).add(log);
    }
    final afterByHour = <String, List<HourlyLog>>{};
    for (final log in reassigned) {
      final key = '${log.dateStr}|${log.hour}';
      afterByHour.putIfAbsent(key, () => []).add(log);
    }

    for (final key in {...beforeByHour.keys, ...afterByHour.keys}) {
      final parts = key.split('|');
      final beforeSlot = beforeByHour[key] ?? const [];
      final afterSlot = afterByHour[key] ?? const [];
      final hadFrom = beforeSlot.any((log) => log.tagId == fromId);
      if (!hadFrom && !_slotsDiffer(beforeSlot, afterSlot)) {
        continue;
      }
      modifiedHours.add((parts[0], int.parse(parts[1])));
    }

    Prefs.hourlyLogs = reassigned;
    _rewritePendingHourlyLogs(fromId, toTag);

    final sync = notionSync ?? NotionSyncService();
    for (final (dateStr, hour) in modifiedHours) {
      final slotLogs = reassigned
          .where((log) => log.dateStr == dateStr && log.hour == hour)
          .toList();
      await sync.replaceHourlyLogsForHour(
        dateStr: dateStr,
        hour: hour,
        logs: slotLogs,
      );
    }

    return touched;
  }

  /// Rewrites hourly logs that reference a name but the wrong tag id.
  static Future<int> rewriteOrphanLogsToCanonical({
    required TrackerTag canonical,
    NotionSyncService? notionSync,
  }) async {
    final normalized = TrackerTagHelper.normalizeName(canonical.name);
    final orphanIds = Prefs.hourlyLogs
        .where(
          (log) =>
              TrackerTagHelper.normalizeName(log.tagName) == normalized &&
              log.tagId != canonical.id,
        )
        .map((log) => log.tagId)
        .toSet();

    var total = 0;
    for (final orphanId in orphanIds) {
      total += await reassignTagId(
        fromId: orphanId,
        toTag: canonical,
        notionSync: notionSync,
      );
    }
    return total;
  }

  static bool _slotsDiffer(List<HourlyLog> before, List<HourlyLog> after) {
    if (before.length != after.length) {
      return true;
    }
    final beforeIds = before.map((log) => log.id).toSet();
    final afterIds = after.map((log) => log.id).toSet();
    return beforeIds.length != afterIds.length ||
        !beforeIds.containsAll(afterIds);
  }

  static void _rewritePendingHourlyLogs(String fromId, TrackerTag toTag) {
    final updated = <String>[];
    for (final item in Prefs.pendingHourlyLogs) {
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(item) as Map<String, dynamic>,
        );
        if (data['tagId'] == fromId) {
          data['tagId'] = toTag.id;
          data['tagName'] = toTag.name;
          data['tagIcon'] = toTag.icon;
          data['tagColorHex'] = toTag.colorHex;
          final dateStr = data['dateStr'] as String?;
          final hour = data['hour'] as int?;
          if (dateStr != null && hour != null) {
            data['id'] = QuietHoursHelper.logId(
              dateStr: dateStr,
              hour: hour,
              tagId: toTag.id,
            );
          }
        }
        updated.add(jsonEncode(data));
      } on Object {
        updated.add(item);
      }
    }
    Prefs.pendingHourlyLogs = updated;
  }

  static void _appendUnique(List<String> target, String? csv) {
    if (csv == null || csv.trim().isEmpty) {
      return;
    }
    for (final raw in csv.split(',')) {
      final value = raw.trim();
      if (value.isNotEmpty && !target.contains(value)) {
        target.add(value);
      }
    }
  }
}
