import 'package:pomo/helpers/tag_reassign_helper.dart';
import 'package:pomo/helpers/tag_registry_writer.dart';
import 'package:pomo/helpers/tracker_tag_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// One-time migration that collapses duplicate tag names into canonical tags.
class TagDedupMigration {
  static const int currentVersion = 1;

  static Future<void> runIfNeeded({
    NotionSyncService? notionSync,
  }) async {
    if (Prefs.activityTagDedupMigrationVersion >= currentVersion) {
      return;
    }

    final sync = notionSync ?? NotionSyncService();
    final logs = List<HourlyLog>.from(Prefs.hourlyLogs);
    final tags = List<TrackerTag>.from(Prefs.trackerTags);
    final previousLastTimerTagIds = List<String>.from(Prefs.lastTimerTagIds);
    final groups = <String, List<TrackerTag>>{};

    for (final tag in tags) {
      final key = TrackerTagHelper.normalizeName(tag.name);
      groups.putIfAbsent(key, () => []).add(tag);
    }

    final idRemap = <String, String>{};
    for (final group in groups.values) {
      if (group.length < 2) {
        continue;
      }
      final canonical = _pickCanonical(group, logs);
      for (final tag in group) {
        if (tag.id == canonical.id) {
          continue;
        }
        await TagReassignHelper.reassignTagId(
          fromId: tag.id,
          toTag: canonical,
          notionSync: sync,
        );
        await sync.deleteActivityTag(tag);
        idRemap[tag.id] = canonical.id;
        tags.removeWhere((item) => item.id == tag.id);
      }
    }

    Prefs.trackerTags = tags;
    _remapLastTimerTagIds(
      idRemap,
      previousLastTimerTagIds: previousLastTimerTagIds,
    );
    Prefs.activityTagDedupMigrationVersion = currentVersion;
    await TagRegistryWriter.writeIfPossible();
  }

  static TrackerTag _pickCanonical(
    List<TrackerTag> group,
    List<HourlyLog> logs,
  ) {
    final defaultTag = group.where((tag) => tag.isDefault).firstOrNull;
    if (defaultTag != null) {
      return defaultTag;
    }

    TrackerTag? earliestTag;
    DateTime? earliestAt;
    for (final tag in group) {
      for (final log in logs.where((item) => item.tagId == tag.id)) {
        if (earliestAt == null || log.loggedAt.isBefore(earliestAt)) {
          earliestAt = log.loggedAt;
          earliestTag = tag;
        }
      }
    }
    if (earliestTag != null) {
      return earliestTag;
    }

    final sorted = List<TrackerTag>.from(group)
      ..sort((a, b) => a.id.compareTo(b.id));
    return sorted.first;
  }

  static void _remapLastTimerTagIds(
    Map<String, String> idRemap, {
    List<String>? previousLastTimerTagIds,
  }) {
    if (idRemap.isEmpty) {
      return;
    }
    final source = previousLastTimerTagIds ?? Prefs.lastTimerTagIds;
    final seen = <String>{};
    Prefs.lastTimerTagIds = [
      for (final id in source)
        if (seen.add(idRemap[id] ?? id)) idRemap[id] ?? id,
    ];
  }
}
