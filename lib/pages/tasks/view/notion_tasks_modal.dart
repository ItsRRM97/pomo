import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/pages/tasks/cubit/notion_tasks_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';

class NotionTasksModal extends StatelessWidget {
  const NotionTasksModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => BlocProvider<NotionTasksCubit>(
        create: (context) => NotionTasksCubit()..fetchTasks(),
        child: const NotionTasksModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.selectTask,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SearchBar(),
              const SizedBox(height: 16),
              _TabSelector(),
              const SizedBox(height: 16),
              const Expanded(child: _TaskList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: l10n.searchTasks,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  context.read<NotionTasksCubit>().search('');
                },
              )
            : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onSubmitted: (value) => context.read<NotionTasksCubit>().search(value),
      onChanged: (value) {
        setState(() {});
        if (value.isEmpty) {
          context.read<NotionTasksCubit>().search('');
        }
      },
    );
  }
}

class _TabSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeTab = context.select((NotionTasksCubit c) => c.state.activeTab);

    return SegmentedButton<String>(
      segments: [
        ButtonSegment<String>(
          value: 'today',
          label: Text(l10n.dueToday),
          icon: const Icon(Icons.today, size: 18),
        ),
        ButtonSegment<String>(
          value: 'week',
          label: Text(l10n.dueThisWeek),
          icon: const Icon(Icons.date_range, size: 18),
        ),
        const ButtonSegment<String>(
          value: 'all',
          label: Text('All'),
          icon: Icon(Icons.list, size: 18),
        ),
      ],
      selected: {activeTab},
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) {
          context.read<NotionTasksCubit>().setTab(selected.first);
        }
      },
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = context.watch<NotionTasksCubit>().state;

    if (state.status == NotionTasksStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == NotionTasksStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? l10n.notionNotConfigured,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (state.tasks.isEmpty) {
      return Center(
        child: Text(
          l10n.noTasksFound,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = state.tasks[index];
        return _TaskTile(task: task);
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final NotionTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTask = context.select((TimerCubit c) => c.state.activeTask);
    final isSelected = activeTask?.id == task.id;

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.4)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.read<TimerCubit>().selectTask(task);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (task.status.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              task.status,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (task.due != null) ...[
                          Icon(
                            Icons.event,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.due!.year}-${task.due!.month.toString().padLeft(2, '0')}-${task.due!.day.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (task.timeHours > 0 || task.timeMinutes > 0)
                          Text(
                            'Logged: ${task.timeLoggedFormatted}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
