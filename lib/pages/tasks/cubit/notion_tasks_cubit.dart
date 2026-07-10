import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

part 'notion_tasks_state.dart';

class NotionTasksCubit extends Cubit<NotionTasksState> {
  NotionTasksCubit({NotionService? notionService})
      : _notionService = notionService ?? NotionService(),
        super(const NotionTasksState());

  final NotionService _notionService;

  Future<void> fetchTasks() async {
    if (!kIsWeb && Prefs.notionApiKey.isEmpty) {
      emit(
        state.copyWith(
          status: () => NotionTasksStatus.failure,
          errorMessage: () =>
              'Please configure your Notion API token in Settings.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: () => NotionTasksStatus.loading,
        errorMessage: () => null,
      ),
    );

    try {
      List<NotionTask> tasks;
      if (state.searchQuery.trim().isNotEmpty) {
        tasks = await _notionService.searchTasks(
          query: state.searchQuery.trim(),
        );
      } else if (state.activeTab == 'today') {
        tasks = await _notionService.getTasksDueToday();
      } else if (state.activeTab == 'week') {
        tasks = await _notionService.getTasksDueThisWeek();
      } else {
        tasks = await _notionService.searchTasks();
      }

      emit(
        state.copyWith(
          status: () => NotionTasksStatus.success,
          tasks: () => tasks,
        ),
      );
    } catch (e) {
      String message = e.toString();
      if (e is DioException) {
        final uri = e.requestOptions.uri;
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          message =
              'Endpoint not found (404) at:\n$uri\n\nPlease verify that your Notion Proxy URL (`${Prefs.notionProxyUrl}`) or Database ID (`${Prefs.notionDatabaseId}`) in Settings are correct.';
        } else if (statusCode == 401) {
          message =
              'Unauthorized (401) from:\n$uri\n\nPlease check your Notion API Token (`${Prefs.notionApiKey.isNotEmpty ? "Configured" : "Empty"}`) in Settings.';
        } else {
          message =
              'Network Error (${statusCode ?? "Unknown"}) calling:\n$uri\n\n${e.message ?? e.toString()}';
        }
      }
      emit(
        state.copyWith(
          status: () => NotionTasksStatus.failure,
          errorMessage: () => message,
        ),
      );
    }
  }

  void setTab(String tab) {
    if (state.activeTab == tab && state.searchQuery.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        activeTab: () => tab,
        searchQuery: () => '',
      ),
    );
    fetchTasks();
  }

  void search(String query) {
    emit(
      state.copyWith(
        searchQuery: () => query,
      ),
    );
    fetchTasks();
  }
}
