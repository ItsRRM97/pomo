import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

class NotionSyncService {
  factory NotionSyncService() => _instance;
  NotionSyncService._internal();

  static final NotionSyncService _instance = NotionSyncService._internal();

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
        durationMinutes: minutes,
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
          durationMinutes: durationMin,
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
