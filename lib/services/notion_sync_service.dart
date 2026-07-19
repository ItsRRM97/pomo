import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

class NotionSyncService {
  factory NotionSyncService() => _instance;
  NotionSyncService._internal();

  static final NotionSyncService _instance = NotionSyncService._internal();

  /// Minutes to ADD to the parent task for a session update.
  /// [totalMinutes] is absolute elapsed; [alreadySynced] is prior credit.
  static int sessionCreditMinutes({
    required int totalMinutes,
    required int alreadySynced,
  }) {
    if (totalMinutes < 1) return 0;
    return totalMinutes > alreadySynced ? totalMinutes - alreadySynced : 0;
  }

  /// Synchronizes a completed or partial focus session to Notion if sync is
  /// enabled and the duration is at least 1 minute.
  Future<({bool success, String? logPageId})> syncSession({
    required NotionTask? task,
    required Duration duration,
    Duration? totalDuration,
    String? existingLogPageId,
    DateTime? endedAt,
  }) async {
    if (task == null || task.id.isEmpty) {
      Logger().d('NotionSyncService: No active NotionTask assigned.');
      return (success: false, logPageId: null);
    }

    if (!Prefs.enableNotionSync) {
      Logger().d('NotionSyncService: Notion sync disabled in Settings.');
      return (success: false, logPageId: null);
    }

    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      Logger().w('NotionSyncService: Notion API Key is empty.');
      return (success: false, logPageId: null);
    }

    final minutes = duration.inMinutes;
    if (minutes < 1) {
      Logger().i(
        'NotionSyncService: Session duration ($minutes m) under threshold.',
      );
      return (success: false, logPageId: null);
    }

    final totalMinutes = (totalDuration ?? duration).inMinutes;
    final timestamp = endedAt ?? DateTime.now();
    Logger().i(
      'NotionSyncService: Syncing ${minutes}m increment '
      '(${totalMinutes}m total) on "${task.title}" to Notion...',
    );

    try {
      await moveToInProgressIfNeeded(task);

      final result = await NotionService().logSession(
        task: task,
        creditMinutes: minutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
      );

      if (result.success) {
        // Update active task local state if it's the currently selected task
        final currentActive = Prefs.activeTask;
        if (currentActive != null && currentActive.id == task.id) {
          final newMath = NotionService.addDuration(
            currentHours: currentActive.timeHours,
            currentMinutes: currentActive.timeMinutes,
            addMin: minutes,
          );
          Prefs.activeTask = currentActive.copyWith(
            timeHours: () => newMath.hours,
            timeMinutes: () => newMath.minutes,
          );
        }
        if (Prefs.pendingTimeLogs.isNotEmpty) {
          unawaited(flushPendingLogs());
        }
      }

      return (success: result.success, logPageId: result.pageId);
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      _enqueuePendingLog(
        task: task,
        durationMinutes: minutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
      );
      return (success: false, logPageId: null);
    }
  }

  /// Creates a brand-new Time Log row in Notion for a freshly started session.
  /// Returns the Notion page ID of the created row, or null on failure.
  /// Fires-and-forgets the move-to-in-progress call.
  ///
  /// Persists a stable [Prefs.activeSessionExternalId] so retries do not create
  /// duplicate rows. Does not credit task cumulative time (credit = 0).
  Future<String?> createSessionRecord({
    required NotionTask task,
    required DateTime startedAt,
  }) async {
    if (task.id.isEmpty) return null;
    if (!Prefs.enableNotionSync) return null;
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) return null;

    final externalId = Prefs.activeSessionExternalId ??
        'sess_${task.id}_${startedAt.millisecondsSinceEpoch}';
    Prefs.activeSessionExternalId = externalId;
    Prefs.syncedMinutes = 0;

    Logger().i(
      'NotionSyncService: Creating session record for '
      '"${task.title}" (${task.id}) externalId=$externalId...',
    );

    try {
      unawaited(moveToInProgressIfNeeded(task));

      final result = await NotionService().logSession(
        task: task,
        creditMinutes: 0,
        totalDurationMinutes: 0,
        endedAt: startedAt,
        customExternalId: externalId,
      );

      if (result.success && result.pageId != null) {
        Logger().i(
          'NotionSyncService: Created session record ${result.pageId}',
        );
        return result.pageId;
      }
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Failed to create session record ($e)',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  /// Updates an existing Time Log row with the latest elapsed time.
  /// If [existingLogPageId] is null, falls back to creating a new record.
  ///
  /// Task cumulative time receives only the delta
  /// (`totalElapsed.inMinutes - previouslySyncedMinutes`).
  /// Pass [previouslySyncedMinutes] when clearing Prefs before the async call
  /// completes (e.g. task switch).
  Future<({bool success, String? logPageId})> updateSessionRecord({
    required NotionTask task,
    required Duration totalElapsed,
    required String? existingLogPageId,
    DateTime? endedAt,
    int? previouslySyncedMinutes,
  }) async {
    if (task.id.isEmpty) {
      return (success: false, logPageId: null);
    }
    if (!Prefs.enableNotionSync) {
      return (success: false, logPageId: null);
    }
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      return (success: false, logPageId: null);
    }

    final totalMinutes = totalElapsed.inMinutes;
    if (totalMinutes < 1) {
      return (success: false, logPageId: existingLogPageId);
    }

    final alreadySynced = previouslySyncedMinutes ?? Prefs.syncedMinutes;
    final creditMinutes = sessionCreditMinutes(
      totalMinutes: totalMinutes,
      alreadySynced: alreadySynced,
    );
    final timestamp = endedAt ?? DateTime.now();

    Logger().i(
      'NotionSyncService: Updating session record '
      '(${totalMinutes}m total, +${creditMinutes}m credit) '
      'for "${task.title}"...',
    );

    try {
      final result = await NotionService().logSession(
        task: task,
        creditMinutes: creditMinutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
        customExternalId: Prefs.activeSessionExternalId,
      );

      if (result.success) {
        // Only advance the baseline when this is still the same open session.
        if (Prefs.activeLogPageId == existingLogPageId ||
            existingLogPageId == null) {
          Prefs.syncedMinutes = totalMinutes;
        }
        final currentActive = Prefs.activeTask;
        if (currentActive != null &&
            currentActive.id == task.id &&
            creditMinutes > 0) {
          final newMath = NotionService.addDuration(
            currentHours: currentActive.timeHours,
            currentMinutes: currentActive.timeMinutes,
            addMin: creditMinutes,
          );
          Prefs.activeTask = currentActive.copyWith(
            timeHours: () => newMath.hours,
            timeMinutes: () => newMath.minutes,
          );
        }
        if (Prefs.pendingTimeLogs.isNotEmpty) {
          unawaited(flushPendingLogs());
        }
      }

      return (success: result.success, logPageId: result.pageId);
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Update session failed ($e)',
        error: e,
        stackTrace: st,
      );
      _enqueuePendingLog(
        task: task,
        durationMinutes: creditMinutes,
        totalDurationMinutes: totalMinutes,
        endedAt: timestamp,
        existingLogPageId: existingLogPageId,
      );
      return (success: false, logPageId: null);
    }
  }

  /// Deletes a Time Log record in Notion.
  Future<bool> deleteSessionRecord(String pageId) async {
    if (pageId.isEmpty) return false;
    if (!Prefs.enableNotionSync) return false;
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) return false;

    Logger().i('NotionSyncService: Deleting session record $pageId...');
    try {
      return await NotionService().deletePage(pageId);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to delete session record $pageId: $e',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Synchronizes a single [HourlyLog] to the separate Hourly Timeline Notion
  /// DB. Respects [Prefs.enableNotionSync], the API key guard, and enqueues to
  /// a pending queue on failure.
  Future<({bool success, String? pageId, HourlyLog log})> syncHourlyLog(
    HourlyLog log,
  ) async {
    if (!Prefs.enableNotionSync) {
      Logger().d('NotionSyncService: Notion sync disabled in Settings.');
      return (success: false, pageId: null, log: log);
    }

    if (Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty) {
      Logger().w(
        'NotionSyncService: Hourly Timeline Database ID is empty.',
      );
      return (success: false, pageId: null, log: log);
    }

    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      Logger().w('NotionSyncService: Notion API Key is empty.');
      return (success: false, pageId: null, log: log);
    }

    try {
      final result = await NotionService().syncHourlyLog(log);
      if (result.success) {
        if (Prefs.pendingHourlyLogs.isNotEmpty) {
          unawaited(flushPendingHourlyLogs());
        }
      }
      return (
        success: result.success,
        pageId: result.pageId,
        log: result.log,
      );
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Hourly sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      _enqueuePendingHourlyLog(log);
      return (success: false, pageId: null, log: log);
    }
  }

  /// Pulls hourly logs from the Notion Hourly Timeline DB and merges them
  /// into local storage. This is how logs created on other devices (e.g. the
  /// PWA) appear on this install. Local entries win when they are newer or
  /// still pending upload. Returns the number of logs added or updated.
  Future<int> pullHourlyLogs({int daysBack = 90}) async {
    if (!Prefs.enableNotionSync) {
      return 0;
    }
    if (Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty) {
      return 0;
    }
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      return 0;
    }

    try {
      final remote = await NotionService().fetchHourlyLogs(daysBack: daysBack);
      if (remote.isEmpty) {
        return 0;
      }

      final pendingIds = Prefs.pendingHourlyLogs
          .map((e) {
            try {
              final data = jsonDecode(e) as Map<String, dynamic>;
              return data['id'] as String? ?? '';
            } catch (_) {
              return '';
            }
          })
          .where((id) => id.isNotEmpty)
          .toSet();

      final local = List<HourlyLog>.from(Prefs.hourlyLogs);
      final localById = {for (final l in local) l.id: l};
      var changed = 0;

      for (final remoteLog in remote) {
        final existing = localById[remoteLog.id];
        if (existing == null) {
          local.add(remoteLog);
          localById[remoteLog.id] = remoteLog;
          changed++;
          continue;
        }

        // Never clobber a local edit that has not been uploaded yet.
        if (pendingIds.contains(existing.id)) {
          continue;
        }

        if (remoteLog.loggedAt.isAfter(existing.loggedAt)) {
          final merged = remoteLog.copyWith(
            // Keep richer local tag identity when names match.
            tagId: existing.tagName.toLowerCase() ==
                    remoteLog.tagName.toLowerCase()
                ? existing.tagId
                : null,
            tagColorHex: existing.tagName.toLowerCase() ==
                    remoteLog.tagName.toLowerCase()
                ? existing.tagColorHex
                : null,
          );
          local[local.indexWhere((l) => l.id == existing.id)] = merged;
          localById[existing.id] = merged;
          changed++;
        } else if (existing.notionPageId == null &&
            remoteLog.notionPageId != null) {
          // Same content; just link the local copy to its Notion row.
          final linked =
              existing.copyWith(notionPageId: remoteLog.notionPageId);
          local[local.indexWhere((l) => l.id == existing.id)] = linked;
          localById[existing.id] = linked;
          changed++;
        }
      }

      if (changed > 0) {
        Prefs.hourlyLogs = local;
      }
      Logger().i(
        'NotionSyncService: Pulled ${remote.length} hourly logs from Notion '
        '($changed added/updated locally).',
      );
      return changed;
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Hourly pull failed ($e)',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  /// Reconciles custom activity tags with the Notion-backed registry.
  ///
  /// Existing local tags that predate tag sync are uploaded as a migration.
  /// Remote tags and deletion tombstones are then applied locally.
  Future<int> syncActivityTags() async {
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      return 0;
    }

    try {
      final remote = await NotionService().fetchActivityTagRecords();
      final latestRemote =
          <String, ({TrackerTag tag, bool deleted, DateTime updatedAt})>{};
      for (final record in remote) {
        final existing = latestRemote[record.tag.id];
        if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
          latestRemote[record.tag.id] = record;
        }
      }

      final local = List<TrackerTag>.from(Prefs.trackerTags);
      final localCustom = local.where((tag) => !tag.isDefault).toList();
      var changed = 0;

      // Upload legacy local-only custom tags before applying remote state.
      for (final tag in localCustom) {
        if (!latestRemote.containsKey(tag.id)) {
          if (await NotionService().syncActivityTag(tag)) {
            changed++;
          }
        }
      }

      for (final record in latestRemote.values) {
        final index = local.indexWhere((tag) => tag.id == record.tag.id);
        if (record.deleted) {
          if (index != -1 && !local[index].isDefault) {
            local.removeAt(index);
            changed++;
          }
          continue;
        }

        if (index == -1) {
          local.add(record.tag);
          changed++;
        } else if (!local[index].isDefault && local[index] != record.tag) {
          local[index] = record.tag;
          changed++;
        }
      }

      if (local != Prefs.trackerTags) {
        Prefs.trackerTags = local;
      }
      Logger().i(
        'NotionSyncService: Reconciled activity tags '
        '(${latestRemote.length} remote, $changed changes).',
      );
      return changed;
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Activity tag sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  /// Saves a custom tag locally and publishes it to the shared registry.
  Future<void> saveActivityTag(TrackerTag tag) async {
    await Prefs.saveTrackerTag(tag);
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      return;
    }
    try {
      await NotionService().syncActivityTag(tag);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to publish activity tag ($e)',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Deletes a custom tag locally and publishes a tombstone to all devices.
  Future<void> deleteActivityTag(TrackerTag tag) async {
    await Prefs.deleteTrackerTag(tag.id);
    if (!Prefs.enableNotionSync ||
        Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty ||
        Prefs.notionApiKey.isEmpty) {
      return;
    }
    try {
      await NotionService().syncActivityTag(tag, deleted: true);
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to publish activity tag deletion ($e)',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _enqueuePendingHourlyLog(HourlyLog log) {
    try {
      final payload = jsonEncode(log.toJson());
      final queue = List<String>.from(Prefs.pendingHourlyLogs)..add(payload);
      Prefs.pendingHourlyLogs = queue;
      Logger().i(
        'NotionSyncService: Enqueued pending hourly log offline '
        '(${queue.length} items).',
      );
    } catch (e) {
      Logger().e('NotionSyncService: Failed to enqueue pending hourly log: $e');
    }
  }

  /// Attempts to retry syncing all offline pending hourly logs stored in
  /// [Prefs.pendingHourlyLogs].
  Future<int> flushPendingHourlyLogs() async {
    if (!Prefs.enableNotionSync || Prefs.notionApiKey.isEmpty) {
      return 0;
    }

    if (Prefs.notionHourlyTimelineDatabaseId.trim().isEmpty) {
      return 0;
    }

    final queue = List<String>.from(Prefs.pendingHourlyLogs);
    if (queue.isEmpty) return 0;

    Logger().i(
      'NotionSyncService: Flushing ${queue.length} pending hourly logs...',
    );
    final remainingQueue = <String>[];
    var flushedCount = 0;

    for (final item in queue) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final log = HourlyLog.fromJson(data);

        final result = await NotionService().syncHourlyLog(log);
        if (result.success) {
          flushedCount++;
          if (result.log.notionPageId != null) {
            await Prefs.saveHourlyLog(result.log);
          }
        } else {
          remainingQueue.add(item);
        }
      } catch (e) {
        Logger()
            .w('NotionSyncService: Failed to flush pending hourly log ($e)');
        remainingQueue.add(item);
      }
    }

    Prefs.pendingHourlyLogs = remainingQueue;
    Logger().i(
      'NotionSyncService: Flushed $flushedCount pending hourly logs '
      '(${remainingQueue.length} remaining).',
    );
    return flushedCount;
  }

  void _enqueuePendingLog({
    required NotionTask task,
    required int durationMinutes,
    required int totalDurationMinutes,
    required DateTime endedAt,
    String? existingLogPageId,
  }) {
    try {
      final payload = jsonEncode({
        'taskId': task.id,
        'taskTitle': task.title,
        'durationMinutes': durationMinutes,
        'totalDurationMinutes': totalDurationMinutes,
        'endedAt': endedAt.toUtc().toIso8601String(),
        'existingLogPageId': existingLogPageId,
      });
      final queue = List<String>.from(Prefs.pendingTimeLogs)..add(payload);
      Prefs.pendingTimeLogs = queue;
      Logger().i(
        'NotionSyncService: Enqueued pending time log offline '
        '(${queue.length} items).',
      );
    } catch (e) {
      Logger().e('NotionSyncService: Failed to enqueue pending time log: $e');
    }
  }

  /// Attempts to retry logging all offline pending time logs stored in
  /// [Prefs.pendingTimeLogs].
  Future<int> flushPendingLogs() async {
    if (!Prefs.enableNotionSync || Prefs.notionApiKey.isEmpty) {
      return 0;
    }

    final queue = List<String>.from(Prefs.pendingTimeLogs);
    if (queue.isEmpty) return 0;

    Logger()
        .i('NotionSyncService: Flushing ${queue.length} pending time logs...');
    final remainingQueue = <String>[];
    var flushedCount = 0;

    for (final item in queue) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final taskId = data['taskId'] as String? ?? '';
        final taskTitle = data['taskTitle'] as String? ?? '';
        final durationMin = data['durationMinutes'] as int? ?? 0;
        final totalMin = data['totalDurationMinutes'] as int? ?? durationMin;
        final endedAtStr = data['endedAt'] as String?;
        final existingPageId = data['existingLogPageId'] as String?;

        if (taskId.isEmpty || durationMin < 1) continue;

        final endedAt = endedAtStr != null
            ? DateTime.tryParse(endedAtStr) ?? DateTime.now()
            : DateTime.now();

        final task = NotionTask(id: taskId, title: taskTitle);

        final result = await NotionService().logSession(
          task: task,
          creditMinutes: durationMin,
          totalDurationMinutes: totalMin,
          endedAt: endedAt,
          existingLogPageId: existingPageId,
        );

        if (result.success) {
          flushedCount++;
          final currentActive = Prefs.activeTask;
          if (currentActive != null && currentActive.id == task.id) {
            final newMath = NotionService.addDuration(
              currentHours: currentActive.timeHours,
              currentMinutes: currentActive.timeMinutes,
              addMin: durationMin,
            );
            Prefs.activeTask = currentActive.copyWith(
              timeHours: () => newMath.hours,
              timeMinutes: () => newMath.minutes,
            );
          }
        } else {
          remainingQueue.add(item);
        }
      } catch (e) {
        Logger().w('NotionSyncService: Failed to flush pending item ($e)');
        remainingQueue.add(item);
      }
    }

    Prefs.pendingTimeLogs = remainingQueue;
    Logger().i(
      'NotionSyncService: Flushed $flushedCount pending logs '
      '(${remainingQueue.length} remaining).',
    );
    return flushedCount;
  }

  /// Moves a task from 'To Do' to 'In Progress' in Notion and updates local
  /// state if needed.
  Future<NotionTask?> moveToInProgressIfNeeded(NotionTask? task) async {
    if (task == null || task.id.isEmpty) return task;
    final currentStatus = task.status.trim().toLowerCase();
    if (currentStatus != 'to do' &&
        currentStatus != 'todo' &&
        currentStatus != 'to-do') {
      return task;
    }

    if (!Prefs.enableNotionSync && !kIsWeb && Prefs.notionApiKey.isEmpty) {
      return task;
    }

    Logger().i(
      'NotionSyncService: Moving task "${task.title}" (${task.id}) '
      'from "${task.status}" to "In Progress"...',
    );

    try {
      final success = await NotionService().updateTaskStatus(
        taskId: task.id,
        newStatus: 'In Progress',
      );

      if (success) {
        final updatedTask = task.copyWith(status: () => 'In Progress');
        final currentActive = Prefs.activeTask;
        if (currentActive != null && currentActive.id == task.id) {
          Prefs.activeTask =
              currentActive.copyWith(status: () => 'In Progress');
        }
        return updatedTask;
      }
    } catch (e, st) {
      Logger().w(
        'NotionSyncService: Failed to move task to In Progress ($e)',
        error: e,
        stackTrace: st,
      );
    }

    return task;
  }
}
