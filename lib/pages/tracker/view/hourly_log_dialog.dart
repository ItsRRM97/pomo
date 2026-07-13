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

  List<NotionTask> _projects = [];
  NotionTask? _selectedProject;
  bool _isLoadingProjects = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
    final logId = widget.existingLog?.id ?? 'hlog_${dateStr}_${widget.hour}';

    final tag = _selectedTag ??
        const TrackerTag(
          id: 'tag_custom_note',
          name: 'Custom Note',
          icon: '✍️',
          colorHex: '#78909C',
        );

    var notionPageId = widget.existingLog?.notionPageId;

    // Optional background Notion sync if a project or task is selected
    if (_selectedProject != null) {
      try {
        final result = await NotionService().logSession(
          task: _selectedProject!,
          durationMinutes: 60,
          totalDurationMinutes: 60,
          endedAt: DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            widget.hour,
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

    final newLog = HourlyLog(
      id: logId,
      dateStr: dateStr,
      hour: widget.hour,
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

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(newLog);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Log Hour: ${_formatHourWindow(widget.hour)}',
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
                return InkWell(
                  onTap: () => setState(() => _selectedTag = tag),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                        Text(tag.icon, style: const TextStyle(fontSize: 16)),
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
          label: Text(_isSaving ? 'Saving...' : 'Save 1h Block'),
        ),
      ],
    );
  }
}
