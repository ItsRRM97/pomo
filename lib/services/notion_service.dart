import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/singletons/prefs.dart';

class NotionService {
  factory NotionService() => _instance;
  NotionService._internal() : _dio = Dio();

  static final NotionService _instance = NotionService._internal();

  final Dio _dio;
  static const String timeLogsDbId = 'acd9cab4-5560-456c-b9b5-86d9a5b391c';

  String _getBaseUrl() {
    var proxy = Prefs.notionProxyUrl.trim();
    // Auto-migrate any stored proxy pointing to the unaliased vercel domain
    if (proxy.contains('pomo-focus.vercel.app')) {
      proxy = proxy.replaceAll(
        'pomo-focus.vercel.app',
        'pomo-focus-sand.vercel.app',
      );
    }
    if (kIsWeb) {
      if (proxy.isNotEmpty) {
        return proxy.endsWith('/') ? proxy : '$proxy/';
      }
      return 'https://pomo-focus-sand.vercel.app/api/notion/';
    }
    if (proxy.isNotEmpty) {
      if (proxy.startsWith('http')) {
        return proxy.endsWith('/') ? proxy : '$proxy/';
      } else if (proxy.startsWith('/')) {
        return 'https://pomo-focus-sand.vercel.app${proxy.endsWith('/') ? proxy : '$proxy/'}';
      }
    }
    return 'https://api.notion.com/v1/';
  }

  Map<String, String> _getHeaders(String apiKey) {
    final headers = <String, String>{
      'Notion-Version': '2022-06-28',
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  /// Calculates normalized `(newHours, newMinutes)` after adding [addMin]
  /// to [currentHours] and [currentMinutes].
  static ({int hours, int minutes}) addDuration({
    required int currentHours,
    required int currentMinutes,
    required int addMin,
  }) {
    final totalMin = (currentHours * 60) + currentMinutes + addMin;
    final hours = totalMin ~/ 60;
    final minutes = totalMin % 60;
    return (hours: hours, minutes: minutes);
  }

  /// Convenience wrapper for tasks due today.
  Future<List<NotionTask>> getTasksDueToday() => queryTasks(dueToday: true);

  /// Convenience wrapper for tasks due this week.
  Future<List<NotionTask>> getTasksDueThisWeek() =>
      queryTasks(dueThisWeek: true);

  /// Convenience wrapper for searching tasks by name/keyword.
  Future<List<NotionTask>> searchTasks({String? query}) =>
      queryTasks(searchKeyword: query);

  /// Queries the Notion Tasks database for tasks matching filter criteria.
  Future<List<NotionTask>> queryTasks({
    String? searchKeyword,
    bool dueToday = false,
    bool dueThisWeek = false,
  }) async {
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      throw Exception('Notion API key not configured in Settings.');
    }

    final dbId = Prefs.notionDatabaseId;
    final url = '${_getBaseUrl()}databases/$dbId/query';

    final filters = <Map<String, dynamic>>[
      // Filter out completed tasks
      {
        'property': 'Done',
        'status': {
          'does_not_equal': 'Done',
        },
      },
    ];

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (dueToday) {
      filters.add({
        'property': 'Due',
        'date': {
          'equals': todayStr,
        },
      });
    } else if (dueThisWeek) {
      // Mon-Sun calculation
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      final startOfWeek = now.subtract(Duration(days: weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final startStr =
          '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
      final endStr =
          '${endOfWeek.year}-${endOfWeek.month.toString().padLeft(2, '0')}-${endOfWeek.day.toString().padLeft(2, '0')}';

      filters.add({
        'property': 'Due',
        'date': {
          'on_or_after': startStr,
        },
      });
      filters.add({
        'property': 'Due',
        'date': {
          'on_or_before': endStr,
        },
      });
    } else if (searchKeyword != null && searchKeyword.trim().isNotEmpty) {
      filters.add({
        'property': 'Name',
        'title': {
          'contains': searchKeyword.trim(),
        },
      });
    }

    final payload = <String, dynamic>{
      'filter': {
        'and': filters,
      },
      'page_size': 30,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
        options: Options(headers: _getHeaders(apiKey)),
      );

      final results = response.data?['results'] as List? ?? [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(NotionTask.fromNotionApi)
          .toList();
    } on DioException catch (e) {
      Logger().e('Notion queryTasks error: ${e.message}', error: e);
      rethrow;
    }
  }

  /// Checks if a session with [externalId] is already logged in `Time Logs`.
  Future<bool> checkIdempotency(String externalId) async {
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) return false;

    final url = '${_getBaseUrl()}databases/$timeLogsDbId/query';
    final payload = {
      'filter': {
        'property': 'External ID',
        'rich_text': {
          'equals': externalId,
        },
      },
      'page_size': 1,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: payload,
        options: Options(headers: _getHeaders(apiKey)),
      );
      final results = response.data?['results'] as List? ?? [];
      return results.isNotEmpty;
    } catch (e) {
      Logger().w('Idempotency check failed: $e');
      return false;
    }
  }

  /// Logs a completed or partial session to the PARA dashboard `Time Logs` DB
  /// and increments the task's `Time (hours)` and `Time (minutes)`.
  Future<bool> logSession({
    required NotionTask task,
    required int durationMinutes,
    required DateTime endedAt,
    String? customExternalId,
  }) async {
    final apiKey = Prefs.notionApiKey;
    if (!kIsWeb && apiKey.isEmpty) {
      throw Exception('Notion API key not set.');
    }

    final externalId =
        customExternalId ?? 'sess_${task.id}_${endedAt.millisecondsSinceEpoch}';

    // 1. Idempotency check
    if (await checkIdempotency(externalId)) {
      Logger().i('Session $externalId already logged to Notion. Skipping.');
      return true;
    }

    // 2. Create Time Logs row
    final timeLogsUrl = '${_getBaseUrl()}pages';
    final logPayload = {
      'parent': {'database_id': timeLogsDbId},
      'properties': {
        'Name': {
          'title': [
            {
              'text': {'content': '${durationMinutes}m - ${task.title}'}
            }
          ]
        },
        'Task': {
          'relation': [
            {'id': task.id}
          ]
        },
        'Duration (min)': {'number': durationMinutes},
        'Logged At': {
          'date': {'start': endedAt.toUtc().toIso8601String()}
        },
        'Source': {
          'select': {'name': 'pomo'}
        },
        'External ID': {
          'rich_text': [
            {
              'text': {'content': externalId}
            }
          ]
        },
      },
    };

    try {
      await _dio.post<Map<String, dynamic>>(
        timeLogsUrl,
        data: logPayload,
        options: Options(headers: _getHeaders(apiKey)),
      );
      Logger().i('Successfully created row in Time Logs ($timeLogsDbId)');
    } on DioException catch (e) {
      Logger().e('Failed to create Time Logs row: ${e.message}', error: e);
      throw Exception(
          'Failed to create Notion Time Log: ${e.response?.data ?? e.message}');
    }

    // 3. Fetch latest task page properties to avoid concurrent overwrites
    var currentHours = task.timeHours;
    var currentMinutes = task.timeMinutes;

    try {
      final taskGetUrl = '${_getBaseUrl()}pages/${task.id}';
      final taskGetResponse = await _dio.get<Map<String, dynamic>>(
        taskGetUrl,
        options: Options(headers: _getHeaders(apiKey)),
      );
      if (taskGetResponse.data != null) {
        final latestTask = NotionTask.fromNotionApi(taskGetResponse.data!);
        currentHours = latestTask.timeHours;
        currentMinutes = latestTask.timeMinutes;
      }
    } catch (e) {
      Logger().w('Failed to fetch latest task properties, using local: $e');
    }

    // 4. Calculate normalized time increment and issue PATCH request
    final newTime = addDuration(
      currentHours: currentHours,
      currentMinutes: currentMinutes,
      addMin: durationMinutes,
    );

    final taskPatchUrl = '${_getBaseUrl()}pages/${task.id}';
    final patchPayload = {
      'properties': {
        'Time (hours)': {'number': newTime.hours},
        'Time (minutes)': {'number': newTime.minutes},
      },
    };

    try {
      await _dio.patch<Map<String, dynamic>>(
        taskPatchUrl,
        data: patchPayload,
        options: Options(headers: _getHeaders(apiKey)),
      );
      Logger().i(
          'Updated Task ${task.id} cumulative time: ${newTime.hours}h ${newTime.minutes}m');
      return true;
    } on DioException catch (e) {
      Logger().e('Failed to update task time: ${e.message}', error: e);
      throw Exception(
          'Failed to update task time: ${e.response?.data ?? e.message}');
    }
  }

  /// Tests connection using the provided [apiKey] by querying 1 task.
  Future<bool> testConnection(String apiKey) async {
    final dbId = Prefs.notionDatabaseId;
    final url = '${_getBaseUrl()}databases/$dbId/query';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: {'page_size': 1},
        options: Options(headers: _getHeaders(apiKey)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
