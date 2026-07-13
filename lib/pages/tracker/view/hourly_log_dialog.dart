import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/tracker/view/tag_create_dialog.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Interactive modal allowing users to log activity for a 1-hour block.
class HourlyLogDialog extends StatefulWidget {
  const HourlyLogDialog({
    required this.selectedDate,
    required this.hour,
    this.existingLog,
    super.key,
  });

  final DateTime selectedDate;
  final int hour;
  final HourlyLog? existingLog;

  @override
  State<HourlyLogDialog> createState() => _HourlyLogDialogState();
}

class _HourlyLogDialogState extends State<HourlyLogDialog> {
  late List<TrackerTag> _tags;
  TrackerTag? _selectedTag;
  final TextEditingController _notesController = TextEditingController();

  late int _startHour;
  late int _endHour;

  List<NotionTask> _projects = [];
  NotionTask? _selectedProject;
  bool _isLoadingProjects = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startHour = widget.hour;
    _endHour = (widget.hour + 1).clamp(1, 24);
    _tags = Prefs.trackerTags;
    if (widget.existingLog != null) {
      final existingId = widget.existingLog!.tagId;
      _selectedTag = _tags.cast<TrackerTag?>().firstWhere(
            (t) => t?.id == existingId,
            orElse: () => _tags.isNotEmpty ? _tags.first : null,
          );
      _notesController.text = widget.existingLog!.notes;
    } else if (_tags.isNotEmpty) {
      _selectedTag = _tags.first;
    }
    _fetchProjects();
  }

  Future<void> _deleteTag(TrackerTag tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
          'Are you sure you want to remove "${tag.icon} ${tag.name}" from your tags list?',
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
    if (confirm == true && mounted) {
      await Prefs.deleteTrackerTag(tag.id);
      setState(() {
        _tags = Prefs.trackerTags;
        if (_selectedTag?.id == tag.id) {
          _selectedTag = _tags.isNotEmpty ? _tags.first : null;
        }
      });
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final tasks = await NotionService().queryTasks();
      // Group unique project IDs or high-level tasks acting as projects
      final uniqueProjects = <String, NotionTask>{};
      for (final t in tasks) {
        if (t.projectId != null && t.projectId!.isNotEmpty) {
          final titleStr = (t.projectTitle != null &&
                  t.projectTitle!.isNotEmpty &&
                  !t.projectTitle!.startsWith('Project '))
              ? t.projectTitle!
              : 'Project ${t.projectId}';
          uniqueProjects['proj_${t.projectId!}'] = NotionTask(
            id: t.projectId!,
            title: titleStr,
          );
        }
        uniqueProjects[t.id] = t;
      }
      if (mounted) {
        setState(() {
          _projects = uniqueProjects.values.toList()
            ..sort((a, b) => a.title.compareTo(b.title));
          if (widget.existingLog?.projectId != null) {
            _selectedProject = _projects.cast<NotionTask?>().firstWhere(
                  (p) => p?.id == widget.existingLog!.projectId,
                  orElse: () => null,
                );
          }
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      Logger().w('HourlyLogDialog: Failed to load projects ($e)');
      if (mounted) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<void> _openCreateTag() async {
    final created = await showDialog<TrackerTag>(
      context: context,
      builder: (context) => const TagCreateDialog(),
    );
    if (created != null && mounted) {
      setState(() {
        _tags = Prefs.trackerTags;
        _selectedTag = created;
      });
    }
  }

  String _formatHourWindow(int h) {
    final start = h.toString().padLeft(2, '0');
    final end = ((h + 1) % 24).toString().padLeft(2, '0');
    return '$start:00 - $end:00';
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _saveLog() async {
    if (_selectedTag == null && _notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a tag or enter activity notes.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final y = widget.selectedDate.year;
    final m = widget.selectedDate.month.toString().padLeft(2, '0');
    final d = widget.selectedDate.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    final tag = _selectedTag ??
        const TrackerTag(
          id: 'tag_custom_note',
          name: 'Custom Note',
          icon: '✍️',
          colorHex: '#78909C',
        );

    var notionPageId = widget.existingLog?.notionPageId;

    final hoursCount = (_endHour - _startHour).clamp(1, 24);

    if (_selectedProject != null) {
      try {
        final result = await NotionService().logSession(
          task: _selectedProject!,
          durationMinutes: hoursCount * 60,
          totalDurationMinutes: hoursCount * 60,
          endedAt: DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            _endHour == 24 ? 23 : _endHour,
            _endHour == 24 ? 59 : 0,
          ),
          existingLogPageId: notionPageId,
        );
        if (result.success && result.pageId != null) {
          notionPageId = result.pageId;
        }
      } catch (e) {
        Logger().w('HourlyLogDialog: Notion sync warning ($e)');
      }
    }

    HourlyLog? firstOrExisting;
    for (var h = _startHour; h < _endHour; h++) {
      final logId = (h == widget.hour && widget.existingLog != null)
          ? widget.existingLog!.id
          : 'hlog_${dateStr}_$h';

      final newLog = HourlyLog(
        id: logId,
        dateStr: dateStr,
        hour: h,
        tagId: tag.id,
        tagName: tag.name,
        tagIcon: tag.icon,
        tagColorHex: tag.colorHex,
        projectId: _selectedProject?.id,
        projectTitle: _selectedProject?.title,
        notes: _notesController.text.trim(),
        notionPageId: notionPageId,
        loggedAt: DateTime.now(),
      );

      await Prefs.saveHourlyLog(newLog);
      if (h == _startHour) {
        firstOrExisting = newLog;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(firstOrExisting);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rangeText =
        '${_startHour.toString().padLeft(2, '0')}:00 - ${_endHour.toString().padLeft(2, '0')}:00';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (_endHour - _startHour) > 1
                  ? 'Log Time Range ($rangeText)'
                  : 'Log Hour: ${_formatHourWindow(_startHour)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Time Range (Bulk Logging)',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _startHour,
                          decoration: const InputDecoration(
                            labelText: 'Start Hour',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: List.generate(24, (i) => i).map((h) {
                            return DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _startHour = val;
                                if (_endHour <= _startHour) {
                                  _endHour = (_startHour + 1).clamp(1, 24);
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to'),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _endHour,
                          decoration: const InputDecoration(
                            labelText: 'End Hour',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: List.generate(24, (i) => i + 1).map((h) {
                            return DropdownMenuItem(
                              value: h,
                              child: Text('${h.toString().padLeft(2, '0')}:00'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _endHour = val;
                                if (_startHour >= _endHour) {
                                  _startHour = (_endHour - 1).clamp(0, 23);
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Logging ${_endHour - _startHour} hour block${(_endHour - _startHour) > 1 ? 's' : ''} ($rangeText)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Activity Tag',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _openCreateTag,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Tag'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final isSelected = _selectedTag?.id == tag.id;
                final badgeColor = _parseHexColor(tag.colorHex);
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? badgeColor.withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: badgeColor, width: 2)
                        : Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _selectedTag = tag),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tag.icon,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? badgeColor
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _deleteTag(tag),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 8,
                            top: 6,
                            bottom: 6,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: isSelected
                                ? badgeColor
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'PARA Project (Optional)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (_isLoadingProjects)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<NotionTask>(
                initialValue: _selectedProject,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select a project from PARA Dashboard',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: [
                  const DropdownMenuItem<NotionTask>(
                    child: Text('No Project Attached'),
                  ),
                  ..._projects.map((proj) {
                    return DropdownMenuItem<NotionTask>(
                      value: proj,
                      child: Text(
                        proj.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedProject = val),
              ),
            const SizedBox(height: 18),
            Text(
              'Custom Notes / Description',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type custom details of what you worked on...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveLog,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(
            _isSaving
                ? 'Saving...'
                : (_endHour - _startHour) > 1
                    ? 'Save ${_endHour - _startHour}h Range'
                    : 'Save 1h Block',
          ),
        ),
      ],
    );
  }
}
