import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/timer/timer.dart';
import 'package:pomo/pages/tracker/view/tag_create_dialog.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Multi-select activity tags that receive Pomodoro hourly credit.
class TimerTagBar extends StatefulWidget {
  const TimerTagBar({super.key});

  @override
  State<TimerTagBar> createState() => _TimerTagBarState();
}

class _TimerTagBarState extends State<TimerTagBar> {
  late List<TrackerTag> _tags;

  @override
  void initState() {
    super.initState();
    _tags = Prefs.trackerTags;
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _createTag() async {
    final created = await showDialog<TrackerTag>(
      context: context,
      builder: (ctx) => const TagCreateDialog(),
    );
    if (!mounted || created == null) {
      return;
    }
    setState(() => _tags = Prefs.trackerTags);
    final cubit = context.read<TimerCubit>();
    if (!cubit.state.activeTags.any((tag) => tag.id == created.id)) {
      cubit.toggleTag(created);
    }
  }

  Future<void> _deleteTag(TrackerTag tag) async {
    if (tag.isDefault) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
          'Remove "${tag.icon} ${tag.name}" from your tags list? '
          'Past hourly logs keep their names.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if ((confirm ?? false) && mounted) {
      await NotionSyncService().deleteActivityTag(tag);
      if (!mounted) {
        return;
      }
      context.read<TimerCubit>().removeActiveTag(tag.id);
      setState(() => _tags = Prefs.trackerTags);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = context.select(
      (TimerCubit cubit) => cubit.state.activeTags,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ..._tags.map((tag) {
                final isSelected = selected.any((item) => item.id == tag.id);
                final color = _parseHexColor(tag.colorHex);
                return Material(
                  color: isSelected
                      ? color.withValues(alpha: 0.22)
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.read<TimerCubit>().toggleTag(tag),
                    onLongPress: tag.isDefault ? null : () => _deleteTag(tag),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tag.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            tag.name,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? color
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add tag'),
                onPressed: _createTag,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
