import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/tracker/view/tag_create_dialog.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/services/notion_sync_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Interactive modal allowing users to log activity for a 1-hour block.
class HourlyLogDialog extends StatefulWidget {
  const HourlyLogDialog({
    required this.selectedDate,
    required this.hour,
    this.existingLog,
    this.existingLogsForHour,
    super.key,
  });

  final DateTime selectedDate;
  final int hour;
  final HourlyLog? existingLog;
  final List<HourlyLog>? existingLogsForHour;

  @override
  State<HourlyLogDialog> createState() => _HourlyLogDialogState();
}

class _HourlyLogDialogState extends State<HourlyLogDialog> {
  late List<TrackerTag> _tags;
  final List<TrackerTag> _selectedTags = [];
  final TextEditingController _notesController = TextEditingController();

  late int _startHour;
  late int _endHour;

  List<NotionTask> _projects = [];
  List<NotionTask> _selectedProjects = [];
  bool _isLoadingProjects = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startHour = widget.hour;
    _endHour = (widget.hour + 1).clamp(1, 24);
    _tags = Prefs.trackerTags;

    if (widget.existingLogsForHour != null &&
        widget.existingLogsForHour!.isNotEmpty) {
      for (final l in widget.existingLogsForHour!) {
        final tag = _tags.cast<TrackerTag?>().firstWhere(
              (t) => t?.id == l.tagId,
              orElse: () => null,
            );
        if (tag != null && !_selectedTags.any((t) => t.id == tag.id)) {
          _selectedTags.add(tag);
        }
      }
      _notesController.text = widget.existingLogsForHour!.first.notes;
    } else if (widget.existingLog != null) {
      final existingId = widget.existingLog!.tagId;
      final tag = _tags.cast<TrackerTag?>().firstWhere(
            (t) => t?.id == existingId,
            orElse: () => null,
          );
      if (tag != null) _selectedTags.add(tag);
      _notesController.text = widget.existingLog!.notes;
    } else if (_tags.isNotEmpty) {
      _selectedTags.add(_tags.first);
    }
    _fetchProjects();
  }

  void _toggleTag(TrackerTag tag) {
    setState(() {
      if (_selectedTags.any((t) => t.id == tag.id)) {
        _selectedTags.removeWhere((t) => t.id == tag.id);
      } else {
        _selectedTags.add(tag);
      }
    });
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
        _selectedTags.removeWhere((t) => t.id == tag.id);
      });
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final items = await NotionService().queryProjectsAndAreas();
      if (mounted) {
        setState(() {
          _projects = items;
          final List<String> existingIds = [];
          if (widget.existingLog?.projectId != null) {
            existingIds.addAll(
              widget.existingLog!.projectId!
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty),
            );
          } else if (widget.existingLogsForHour != null &&
              widget.existingLogsForHour!.isNotEmpty &&
              widget.existingLogsForHour!.first.projectId != null) {
            existingIds.addAll(
              widget.existingLogsForHour!.first.projectId!
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty),
            );
          }
          _selectedProjects =
              _projects.where((p) => existingIds.contains(p.id)).toList();
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      Logger().w('HourlyLogDialog: Failed to load PARA projects/areas ($e)');
      if (mounted) {
        setState(() => _isLoadingProjects = false);
      }
    }
  }

  Future<void> _showProjectPicker() async {
    final selected = await showDialog<List<NotionTask>?>(
      context: context,
      builder: (ctx) => _ProjectPickerDialog(
        projects: _projects,
        currentSelected: _selectedProjects,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedProjects = selected;
      });
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
        if (!_selectedTags.any((t) => t.id == created.id)) {
          _selectedTags.add(created);
        }
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
    if (_selectedTags.isEmpty && _notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one tag or enter notes.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final y = widget.selectedDate.year;
    final m = widget.selectedDate.month.toString().padLeft(2, '0');
    final d = widget.selectedDate.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    final tagsToSave = _selectedTags.isNotEmpty
        ? _selectedTags
        : [
            const TrackerTag(
              id: 'tag_custom_note',
              name: 'Custom Note',
              icon: '✍️',
              colorHex: '#78909C',
            ),
          ];

    final k = tagsToSave.length;
    final baseMins = 60 ~/ k;
    final firstMins = 60 - (baseMins * (k - 1));

    HourlyLog? firstOrExisting;
    for (var h = _startHour; h < _endHour; h++) {
      final newLogsForHour = <HourlyLog>[];
      for (var i = 0; i < k; i++) {
        final tag = tagsToSave[i];
        final mins = (i == 0) ? firstMins : baseMins;
        final logId = (k == 1 && h == widget.hour && widget.existingLog != null)
            ? widget.existingLog!.id
            : (k == 1)
                ? 'hlog_${dateStr}_$h'
                : 'hlog_${dateStr}_${h}_${tag.id}';

        final existingNotionPageId =
            (widget.existingLog != null && widget.existingLog!.id == logId)
                ? widget.existingLog!.notionPageId
                : null;

        final String? projectIds = _selectedProjects.isNotEmpty
            ? _selectedProjects.map((p) => p.id).join(',')
            : null;
        final String? projectTitles = _selectedProjects.isNotEmpty
            ? _selectedProjects.map((p) => p.title).join(', ')
            : null;

        var newLog = HourlyLog(
          id: logId,
          dateStr: dateStr,
          hour: h,
          tagId: tag.id,
          tagName: tag.name,
          tagIcon: tag.icon,
          tagColorHex: tag.colorHex,
          projectId: projectIds,
          projectTitle: projectTitles,
          notes: _notesController.text.trim(),
          notionPageId: existingNotionPageId,
          durationMinutes: mins,
          loggedAt: DateTime.now(),
        );

        try {
          final syncResult = await NotionSyncService().syncHourlyLog(newLog);
          if (syncResult.success) {
            newLog = syncResult.log;
          }
        } catch (e) {
          Logger().w(
            'HourlyLogDialog: Failed to sync hourly log to Notion: $e',
          );
        }

        newLogsForHour.add(newLog);
      }

      await Prefs.replaceHourlyLogsForHour(dateStr, h, newLogsForHour);
      if (h == _startHour) {
        firstOrExisting = newLogsForHour.first;
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
              children: [
                Expanded(
                  child: Text(
                    'Select Activity Tags (Multi-Select Enabled)',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openCreateTag,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Tag'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final isSelected = _selectedTags.any((t) => t.id == tag.id);
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
                        onTap: () => _toggleTag(tag),
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
            if (_selectedTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedTags.length == 1
                            ? 'Allocating 60 mins/hr to ${_selectedTags.first.icon} ${_selectedTags.first.name}'
                            : 'Divided equally: ${60 ~/ _selectedTags.length} mins/hr each across ${_selectedTags.length} tags (${_selectedTags.map((t) => t.icon).join(' ')})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'PARA Project / Area / Resource (Searchable)',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (_isLoadingProjects)
              const LinearProgressIndicator()
            else
              InkWell(
                onTap: _showProjectPicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _selectedProjects.isEmpty
                            ? Text(
                                'Select projects, areas, or resources...',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _selectedProjects.map((proj) {
                                  final Color badgeBg = proj.priority == 'Area'
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : proj.priority == 'Resource'
                                          ? Colors.purple.withValues(alpha: 0.2)
                                          : Colors.blue.withValues(alpha: 0.2);
                                  final String badgeText =
                                      proj.priority == 'Area'
                                          ? '🏔️ Area'
                                          : proj.priority == 'Resource'
                                              ? '🟣 Resource'
                                              : '📽️ Project';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          badgeText,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            proj.title,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
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

class _ProjectPickerDialog extends StatefulWidget {
  const _ProjectPickerDialog({
    required this.projects,
    required this.currentSelected,
  });

  final List<NotionTask> projects;
  final List<NotionTask> currentSelected;

  @override
  State<_ProjectPickerDialog> createState() => _ProjectPickerDialogState();
}

class _ProjectPickerDialogState extends State<_ProjectPickerDialog> {
  String _search = '';
  late TextEditingController _controller;
  final List<NotionTask> _selectedTasks = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _selectedTasks.addAll(widget.currentSelected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.projects.where((p) {
      if (_search.trim().isEmpty) return true;
      final q = _search.trim().toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          p.priority.toLowerCase().contains(q) ||
          p.status.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.folder_special, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Select Projects / Areas')),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search projects, areas & resources...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                setState(() {
                  _selectedTasks.clear();
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.clear, color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Clear All Selected',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No projects or areas match "$_search"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final isSelected =
                            _selectedTasks.any((t) => t.id == item.id);

                        String badgeText;
                        Color badgeBg;
                        if (item.priority == 'Area') {
                          badgeText = '🏔️ Area';
                          badgeBg = Colors.orange.withValues(alpha: 0.2);
                        } else if (item.priority == 'Resource') {
                          badgeText = '🟣 Resource';
                          badgeBg = Colors.purple.withValues(alpha: 0.2);
                        } else {
                          badgeText = '📽️ Project';
                          badgeBg = Colors.blue.withValues(alpha: 0.2);
                        }

                        return ListTile(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedTasks
                                    .removeWhere((t) => t.id == item.id);
                              } else {
                                _selectedTasks.add(item);
                              }
                            });
                          },
                          selected: isSelected,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: item.status.isNotEmpty &&
                                  item.status != 'Active' &&
                                  item.status != 'To Do'
                              ? Text(
                                  item.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  if (!isSelected) _selectedTasks.add(item);
                                } else {
                                  _selectedTasks
                                      .removeWhere((t) => t.id == item.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedTasks),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
