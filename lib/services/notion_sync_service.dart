import 'dart:async';
import 'package:logger/logger.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

class NotionSyncService {
  factory NotionSyncService() => _instance;
  NotionSyncService._internal();

  static final NotionSyncService _instance = NotionSyncService._internal();

  /// Synchronizes a completed or partial focus session to Notion if sync is enabled
  /// and the duration is at least 1 minute.
  Future<bool> syncSession({
    required NotionTask? task,
    required Duration duration,
    DateTime? endedAt,
  }) async {
    if (task == null || task.id.isEmpty) {
      Logger().d('NotionSyncService: No active NotionTask assigned.');
      return false;
    }

    if (!Prefs.enableNotionSync) {
      Logger().d('NotionSyncService: Notion sync disabled in Settings.');
      return false;
    }

    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) {
      Logger().w('NotionSyncService: Notion API Key is empty.');
      return false;
    }

    final minutes = duration.inMinutes;
    if (minutes < 1) {
      Logger().i(
          'NotionSyncService: Session duration ($minutes m) under 1 minute threshold. Not syncing.');
      return false;
    }

    final timestamp = endedAt ?? DateTime.now();
    Logger().i(
        'NotionSyncService: Syncing ${minutes}m session on "${task.title}" to Notion...');

    try {
      final success = await NotionService().logSession(
        task: task,
        durationMinutes: minutes,
        endedAt: timestamp,
      );

      if (success) {
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

      return success;
    } catch (e, st) {
      Logger()
          .e('NotionSyncService: Sync failed ($e)', error: e, stackTrace: st);
      return false;
    }
  }
}
