import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/singletons/prefs.dart';

class NotionService {
  factory NotionService() => _instance;
  NotionService._internal() : _dio = Dio();

  static final NotionService _instance = NotionService._internal();

  final Dio _dio;
  static String get timeLogsDbId => Prefs.notionTimeLogsDatabaseId;

  /// Hourly Timeline database ID for 24-hour daily activity tracking.
  static String get hourlyTimelineDbId => Prefs.notionHourlyTimelineDatabaseId;

  static DateTime? _lastTaskFetchTime;
  static String? _lastFetchedTaskId;
  static final Map<String, String> _pageTitleCache = {};

  /// Returns the cached project or page title for [pageId], if available.
  String? getCachedPageTitle(String pageId) => _pageTitleCache[pageId];

  /// Manually stores a project or page title in the cache.
  void cachePageTitle(String pageId, String title) =>
      _pageTitleCache[pageId] = title;

  /// Clears the TTL cache for task property fetches (useful for testing).
  static void clearTaskFetchCache() {
    _lastTaskFetchTime = null;
    _lastFetchedTaskId = null;
    _pageTitleCache.clear();
  }

  String _getBaseUrl() {
    var proxy = Prefs.notionProxyUrl.trim();
    // Auto-migrate any stored proxy pointing to the unaliased vercel domain
    if (proxy.contains('pomo-focus.vercel.app')) {
      proxy = proxy.replaceAll(
        'pomo-focus.vercel.app',
        'pomo-focus-sand.vercel.app',
      );
    }
    if (proxy.isNotEmpty) {
      if (proxy.startsWith('http')) {
        return proxy.endsWith('/') ? proxy : '$proxy/';
      } else if (proxy.startsWith('/')) {
        return 'https://pomo-focus-sand.vercel.app'
            '${proxy.endsWith('/') ? proxy : '$proxy/'}';
      }
    }
    // Default universally across Web and native macOS platforms to our
    // Vercel proxy.
    return 'https://pomo-focus-sand.vercel.app/api/notion/';
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

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
    if (apiKey.isEmpty) {
      throw Exception('Focus access code not configured.');
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
    final todayStr = _formatDate(now);

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

      final startStr = _formatDate(startOfWeek);
      final endStr = _formatDate(endOfWeek);

      filters
        ..add({
          'property': 'Due',
          'date': {
            'on_or_after': startStr,
          },
        })
        ..add({
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
      final parsed = results
          .whereType<Map<String, dynamic>>()
          .map(NotionTask.fromNotionApi)
          .toList();
      return resolveProjectTitles(parsed);
    } on DioException catch (e) {
      Logger().e('Notion queryTasks error: ${e.message}', error: e);
      rethrow;
    }
  }

  /// Queries Notion for PARA Projects, Areas, and Resources while skipping
  /// archived (`Archive == true` or `Status == Done`) items and tasks.
  Future<List<NotionTask>> queryProjectsAndAreas(
      {String? searchKeyword}) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) {
      return [];
    }

    final projectsDbId = Prefs.notionProjectsDatabaseId;
    final areasDbId = Prefs.notionAreasDatabaseId;

    final results = <NotionTask>[];

    Future<void> fetchFromDb(String dbId) async {
      try {
        final url = '${_getBaseUrl()}databases/$dbId/query';
        final payload = <String, dynamic>{
          'page_size': 100,
        };
        final response = await _dio.post<Map<String, dynamic>>(
          url,
          data: payload,
          options: Options(headers: _getHeaders(apiKey)),
        );
        final rawList = response.data?['results'] as List? ?? [];
        for (final item in rawList.whereType<Map<String, dynamic>>()) {
          final parsed = NotionTask.fromNotionApi(item);
          if (!parsed.isArchived) {
            if (searchKeyword == null ||
                searchKeyword.trim().isEmpty ||
                parsed.title
                    .toLowerCase()
                    .contains(searchKeyword.trim().toLowerCase())) {
              results.add(parsed);
            }
          }
        }
      } catch (e) {
        Logger().w('Notion queryProjectsAndAreas ($dbId) warning: $e');
      }
    }

    await Future.wait([
      fetchFromDb(projectsDbId),
      fetchFromDb(areasDbId),
    ]);

    results.sort((a, b) => a.title.compareTo(b.title));
    return results;
  }

  /// Resolves Project titles for a list of [NotionTask]s by fetching the title
  /// of any related `projectId` page from the Notion API if not already known.
  Future<List<NotionTask>> resolveProjectTitles(List<NotionTask> tasks) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return tasks;

    final missingIds = <String>{};
    for (final t in tasks) {
      if (t.projectId != null &&
          t.projectId!.isNotEmpty &&
          (t.projectTitle == null ||
              (t.projectTitle?.startsWith('Project ') ?? false))) {
        if (!_pageTitleCache.containsKey(t.projectId)) {
          missingIds.add(t.projectId!);
        }
      }
    }

    if (missingIds.isNotEmpty) {
      await Future.wait(
        missingIds.map((id) async {
          try {
            await resolvePageTitle(id);
          } catch (e) {
            Logger().w('Failed to resolve project title for $id: $e');
          }
        }),
      );
    }

    return tasks.map((t) {
      if (t.projectId != null &&
          t.projectId!.isNotEmpty &&
          (t.projectTitle == null ||
              (t.projectTitle?.startsWith('Project ') ?? false))) {
        final cachedTitle = _pageTitleCache[t.projectId];
        if (cachedTitle != null && cachedTitle.isNotEmpty) {
          return t.copyWith(projectTitle: () => cachedTitle);
        }
      }
      return t;
    }).toList();
  }

  /// Fetches and caches the page title for [pageId] from the Notion API.
  Future<String?> resolvePageTitle(String pageId) async {
    if (_pageTitleCache.containsKey(pageId)) {
      return _pageTitleCache[pageId];
    }
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return null;

    try {
      final url = '${_getBaseUrl()}pages/$pageId';
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(headers: _getHeaders(apiKey)),
      );
      final page = response.data;
      if (page != null) {
        final props = page['properties'] as Map<String, dynamic>? ?? {};
        for (final prop in props.values) {
          if (prop is Map<String, dynamic> && prop['type'] == 'title') {
            final titleList = prop['title'] as List? ?? [];
            if (titleList.isNotEmpty && titleList.first is Map) {
              final textMap = (titleList.first as Map)['text'] as Map?;
              final titleStr = textMap?['content'] as String? ??
                  (titleList.first as Map)['plain_text'] as String?;
              if (titleStr != null &&
                  titleStr.isNotEmpty &&
                  titleStr != 'Untitled') {
                _pageTitleCache[pageId] = titleStr;
                return titleStr;
              }
            }
          }
        }
      }
    } catch (e) {
      Logger().w('NotionService.resolvePageTitle error: $e');
    }
    return null;
  }

  Future<List<HourlyLog>> resolveLogTitles(List<HourlyLog> logs) async {
    final missingIds = <String>{};
    for (final log in logs) {
      if (log.projectId != null && log.projectId!.isNotEmpty) {
        final ids = log.projectId!.split(',').where((s) => s.isNotEmpty);
        for (final id in ids) {
          if (!_pageTitleCache.containsKey(id)) {
            missingIds.add(id);
          }
        }
      }
    }

    if (missingIds.isNotEmpty) {
      await Future.wait(
        missingIds.map((id) async {
          try {
            await resolvePageTitle(id);
          } catch (e) {
            Logger().w('Failed to resolve project title for log $id: $e');
          }
        }),
      );
    }

    var anyChanged = false;
    final updated = logs.map((log) {
      if (log.projectId != null && log.projectId!.isNotEmpty) {
        final ids =
            log.projectId!.split(',').where((s) => s.isNotEmpty).toList();
        final titles = <String>[];
        var resolvedAll = true;

        for (final id in ids) {
          final cachedTitle = _pageTitleCache[id];
          if (cachedTitle != null && cachedTitle.isNotEmpty) {
            titles.add(cachedTitle);
          } else {
            resolvedAll = false;
          }
        }

        if (resolvedAll && titles.isNotEmpty) {
          final newTitle = titles.join(', ');
          if (log.projectTitle != newTitle) {
            anyChanged = true;
            return log.copyWith(projectTitle: newTitle);
          }
        }
      }
      return log;
    }).toList();

    if (anyChanged) {
      for (final log in updated) {
        await Prefs.saveHourlyLog(log);
      }
    }

    return updated;
  }

  /// Checks if a session with [externalId] is already logged in `Time Logs`.
  /// Returns the existing row's page ID if found, or null otherwise.
  Future<String?> checkIdempotency(String externalId) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return null;

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
      if (results.isNotEmpty && results.first is Map) {
        return (results.first as Map<String, dynamic>)['id'] as String?;
      }
      return null;
    } catch (e) {
      Logger().w('Idempotency check failed: $e');
      return null;
    }
  }

  /// Checks if an hourly log with [externalId] is already synced in the
  /// Hourly Timeline DB. Returns the existing row's page ID if found, or null.
  Future<String?> checkHourlyIdempotency(String externalId) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return null;

    final url = '${_getBaseUrl()}databases/$hourlyTimelineDbId/query';
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
      if (results.isNotEmpty && results.first is Map) {
        return (results.first as Map<String, dynamic>)['id'] as String?;
      }
      return null;
    } catch (e) {
      Logger().w('Hourly idempotency check failed: $e');
      return null;
    }
  }

  /// Syncs a single [HourlyLog] to the separate Hourly Timeline Notion DB.
  /// Performs an idempotency check on `External ID` = `log.id`, creates a row
  /// if absent, or patches it if present. Sets [log.notionPageId] on success.
  Future<({bool success, String? pageId, HourlyLog log})> syncHourlyLog(
    HourlyLog log,
  ) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Focus access code not set.');
    }

    final name =
        '${log.hour.toString().padLeft(2, '0')}:00 - ${log.tagIcon} ${log.tagName}';
    var pageId = log.notionPageId;

    if (pageId != null && pageId.isNotEmpty) {
      try {
        final patchUrl = '${_getBaseUrl()}pages/$pageId';
        await _dio.patch<Map<String, dynamic>>(
          patchUrl,
          data: {'properties': _hourlyProperties(log, name)},
          options: Options(headers: _getHeaders(apiKey)),
        );
        Logger().i('Updated existing Hourly Timeline row $pageId');
        return (
          success: true,
          pageId: pageId,
          log: log.copyWith(notionPageId: pageId)
        );
      } on DioException catch (e) {
        Logger().w('Failed to update hourly row $pageId (${e.message}).');
        if (e.response?.statusCode == 404) {
          pageId = null;
        } else {
          rethrow;
        }
      }
    }

    if (pageId == null || pageId.isEmpty) {
      final existingPageId = await checkHourlyIdempotency(log.id);
      if (existingPageId != null && existingPageId.isNotEmpty) {
        pageId = existingPageId;
        try {
          final patchUrl = '${_getBaseUrl()}pages/$pageId';
          await _dio.patch<Map<String, dynamic>>(
            patchUrl,
            data: {'properties': _hourlyProperties(log, name)},
            options: Options(headers: _getHeaders(apiKey)),
          );
          Logger().i(
              'Updated existing Hourly Timeline row $pageId via idempotency');
          return (
            success: true,
            pageId: pageId,
            log: log.copyWith(notionPageId: pageId)
          );
        } on DioException catch (e) {
          Logger().w('Failed to patch hourly row $pageId (${e.message}).');
          if (e.response?.statusCode != 404) rethrow;
          pageId = null;
        }
      }
    }

    if (pageId == null || pageId.isEmpty) {
      final url = '${_getBaseUrl()}pages';
      final payload = {
        'parent': {'database_id': hourlyTimelineDbId},
        'properties': _hourlyProperties(log, name),
      };

      try {
        final response = await _dio.post<Map<String, dynamic>>(
          url,
          data: payload,
          options: Options(headers: _getHeaders(apiKey)),
        );
        pageId = response.data?['id'] as String?;
        Logger().i('Created Hourly Timeline row $pageId ($hourlyTimelineDbId)');
        return (
          success: true,
          pageId: pageId,
          log: log.copyWith(notionPageId: pageId)
        );
      } on DioException catch (e) {
        Logger()
            .e('Failed to create Hourly Timeline row: ${e.message}', error: e);
        throw Exception(
          'Failed to create Notion Hourly Timeline row: '
          '${e.response?.data ?? e.message}',
        );
      }
    }

    return (
      success: true,
      pageId: pageId,
      log: log.copyWith(notionPageId: pageId)
    );
  }

  Map<String, dynamic> _hourlyProperties(HourlyLog log, String name) {
    return {
      'Name': {
        'title': [
          {
            'text': {'content': name}
          },
        ],
      },
      'Date': {
        'date': {'start': log.dateStr},
      },
      'Hour': {'number': log.hour},
      'Tag': {
        'rich_text': [
          {
            'text': {'content': log.tagName}
          },
        ],
      },
      'Tag Icon': {
        'rich_text': [
          {
            'text': {'content': log.tagIcon}
          },
        ],
      },
      'Project': {
        'rich_text': [
          {
            'text': {'content': log.projectTitle ?? ''}
          },
        ],
      },
      'Notes': {
        'rich_text': [
          {
            'text': {'content': log.notes}
          },
        ],
      },
      'Duration (min)': {'number': log.durationMinutes},
      'Source': {
        'rich_text': [
          {
            'text': {'content': 'pomo-hourly'}
          },
        ],
      },
      'External ID': {
        'rich_text': [
          {
            'text': {'content': log.id}
          },
        ],
      },
      'Logged At': {
        'date': {'start': log.loggedAt.toUtc().toIso8601String()},
      },
    };
  }

  /// Logs a completed or partial session to the PARA dashboard `Time Logs` DB
  /// and increments the task's `Time (hours)` and `Time (minutes)`.
  Future<({bool success, String? pageId})> logSession({
    required NotionTask task,
    required int durationMinutes,
    required DateTime endedAt,
    String? customExternalId,
    String? existingLogPageId,
    int? totalDurationMinutes,
  }) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Focus access code not set.');
    }

    final totalDuration = totalDurationMinutes ?? durationMinutes;
    var pageId = existingLogPageId;

    if (pageId != null && pageId.isNotEmpty) {
      try {
        final patchUrl = '${_getBaseUrl()}pages/$pageId';
        final updatePayload = {
          'properties': {
            'Name': {
              'title': [
                {
                  'text': {'content': '${totalDuration}m - ${task.title}'},
                },
              ],
            },
            'Duration (min)': {'number': totalDuration},
          },
        };
        await _dio.patch<Map<String, dynamic>>(
          patchUrl,
          data: updatePayload,
          options: Options(headers: _getHeaders(apiKey)),
        );
        Logger().i(
          'Successfully updated existing row $pageId in Time Logs to '
          '${totalDuration}m',
        );
      } on DioException catch (e) {
        Logger().w(
          'Failed to update existing row $pageId (${e.message}). '
          'Will create a new row.',
        );
        if (e.response?.statusCode == 404) {
          pageId = null;
        } else {
          rethrow;
        }
      }
    }

    if (pageId == null || pageId.isEmpty) {
      final externalId = customExternalId ??
          'sess_${task.id}_${endedAt.millisecondsSinceEpoch}';

      // 1. Idempotency check
      final existingPageId = await checkIdempotency(externalId);
      if (existingPageId != null && existingPageId.isNotEmpty) {
        Logger().i(
          'Session $externalId already logged ($existingPageId). '
          'Proceeding to update task cumulative time.',
        );
        pageId = existingPageId;
      } else {
        // 2. Create Time Logs row
        final timeLogsUrl = '${_getBaseUrl()}pages';
        final logPayload = {
          'parent': {'database_id': timeLogsDbId},
          'properties': {
            'Name': {
              'title': [
                {
                  'text': {'content': '${totalDuration}m - ${task.title}'},
                },
              ],
            },
            'Task': {
              'relation': [
                {'id': task.id},
              ],
            },
            'Duration (min)': {'number': totalDuration},
            'Logged At': {
              'date': {'start': endedAt.toUtc().toIso8601String()},
            },
            'Source': {
              'rich_text': [
                {
                  'text': {'content': 'pomo'},
                },
              ],
            },
            'External ID': {
              'rich_text': [
                {
                  'text': {'content': externalId},
                },
              ],
            },
          },
        };

        try {
          final response = await _dio.post<Map<String, dynamic>>(
            timeLogsUrl,
            data: logPayload,
            options: Options(headers: _getHeaders(apiKey)),
          );
          pageId = response.data?['id'] as String?;
          Logger().i(
            'Successfully created row $pageId in Time Logs ($timeLogsDbId)',
          );
        } on DioException catch (e) {
          Logger().e('Failed to create Time Logs row: ${e.message}', error: e);
          throw Exception(
            'Failed to create Notion Time Log: '
            '${e.response?.data ?? e.message}',
          );
        }
      }
    }

    // 3. Fetch latest task page properties to avoid concurrent overwrites
    var currentHours = task.timeHours;
    var currentMinutes = task.timeMinutes;

    final now = DateTime.now();
    final isCacheValid = _lastFetchedTaskId == task.id &&
        _lastTaskFetchTime != null &&
        now.difference(_lastTaskFetchTime!).inMinutes < 5 &&
        (task.timeHours != 0 || task.timeMinutes != 0);

    if (!isCacheValid) {
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
          _lastFetchedTaskId = task.id;
          _lastTaskFetchTime = now;
        }
      } catch (e) {
        Logger().w('Failed to fetch latest task properties, using local: $e');
      }
    } else {
      Logger().i(
        'Skipping GET task ${task.id} (within 5-minute TTL cache guard).',
      );
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
      _lastFetchedTaskId = task.id;
      _lastTaskFetchTime = DateTime.now();
      Logger().i(
        'Updated Task ${task.id} cumulative time: '
        '${newTime.hours}h ${newTime.minutes}m',
      );
      return (success: true, pageId: pageId);
    } on DioException catch (e) {
      Logger().e('Failed to update task time: ${e.message}', error: e);
      throw Exception(
        'Failed to update task time: ${e.response?.data ?? e.message}',
      );
    }
  }

  /// Updates the status property of a task page in Notion.
  Future<bool> updateTaskStatus({
    required String taskId,
    required String newStatus,
  }) async {
    final apiKey = Prefs.notionApiKey;
    if (apiKey.isEmpty) return false;

    final url = '${_getBaseUrl()}pages/$taskId';
    final payload = {
      'properties': {
        'Done': {
          'status': {
            'name': newStatus,
          },
        },
      },
    };

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        url,
        data: payload,
        options: Options(headers: _getHeaders(apiKey)),
      );
      Logger().i('Updated Task $taskId status to $newStatus');
      return response.statusCode == 200;
    } on DioException catch (e) {
      Logger().e('Failed to update task status: ${e.message}', error: e);
      return false;
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
