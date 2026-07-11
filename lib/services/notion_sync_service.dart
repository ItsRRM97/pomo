import 'dart:async';
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
      }

      return (success: result.success, logPageId: result.pageId);
    } catch (e, st) {
      Logger().e(
        'NotionSyncService: Sync failed ($e)',
        error: e,
        stackTrace: st,
      );
      return (success: false, logPageId: null);
    }
  }
}
