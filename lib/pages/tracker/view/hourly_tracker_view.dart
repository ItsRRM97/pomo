import 'package:flutter/material.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/pages/tracker/view/hourly_log_dialog.dart';
import 'package:pomo/services/notion_service.dart';
import 'package:pomo/singletons/prefs.dart';

/// Main 24-Hour Timeline Grid and Multi-timeframe Analytics Dashboard.
class HourlyTrackerView extends StatefulWidget {
  const HourlyTrackerView({super.key});

  @override
  State<HourlyTrackerView> createState() => _HourlyTrackerViewState();
}

class _HourlyTrackerViewState extends State<HourlyTrackerView> {
  DateTime _selectedDate = DateTime.now();
  String _timeframe = 'daily'; // daily, weekly, 14d, monthly, quarterly

  List<HourlyLog> _allLogs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _allLogs = Prefs.hourlyLogs;
    });
    NotionService().resolveLogTitles(Prefs.hourlyLogs).then((updated) {
      if (mounted &&
          updated.any(
            (l) =>
                l.projectTitle != null &&
                !l.projectTitle!.startsWith('Project '),
          )) {
        setState(() {
          _allLogs = Prefs.hourlyLogs;
        });
      }
    });
  }

  String _formatDateStr(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatDateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today (${_formatDateStr(d)})';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday (${_formatDateStr(d)})';
    }
    return _formatDateStr(d);
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _openLogDialog(int hour, HourlyLog? existing) async {
    final updated = await showDialog<HourlyLog>(
      context: context,
      builder: (context) => HourlyLogDialog(
        selectedDate: _selectedDate,
        hour: hour,
        existingLog: existing,
      ),
    );
    if (updated != null && mounted) {
      _loadLogs();
    }
  }

  List<HourlyLog> _getLogsForTimeframe() {
    final now = DateTime.now();
    var daysBack = 1;
    switch (_timeframe) {
      case 'weekly':
        daysBack = 7;
      case '14d':
        daysBack = 14;
      case 'monthly':
        daysBack = 30;
      case 'quarterly':
        daysBack = 90;
      default:
        daysBack = 1;
    }

    if (daysBack == 1) {
      final targetStr = _formatDateStr(_selectedDate);
      return _allLogs.where((l) => l.dateStr == targetStr).toList();
    } else {
      final cutoff = now.subtract(Duration(days: daysBack));
      final cutoffStr = _formatDateStr(cutoff);
      return _allLogs
          .where((l) => l.dateStr.compareTo(cutoffStr) >= 0)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetDateStr = _formatDateStr(_selectedDate);
    final dayLogsMap = <int, List<HourlyLog>>{};
    for (final log in _allLogs) {
      if (log.dateStr == targetDateStr) {
        dayLogsMap.putIfAbsent(log.hour, () => []).add(log);
      }
    }

    final timeframeLogs = _getLogsForTimeframe();
    final tagMinutesMap =
        <String, ({String name, String icon, String color, int minutes})>{};
    var totalTimeframeMinutes = 0;
    for (final l in timeframeLogs) {
      final mins = l.durationMinutes;
      totalTimeframeMinutes += mins;
      final current = tagMinutesMap[l.tagId] ??
          (name: l.tagName, icon: l.tagIcon, color: l.tagColorHex, minutes: 0);
      tagMinutesMap[l.tagId] = (
        name: current.name,
        icon: current.icon,
        color: current.color,
        minutes: current.minutes + mins,
      );
    }

    final sortedStats = tagMinutesMap.values.toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    return Column(
      children: [
        // Top Multi-timeframe Analytics Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity Analytics',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: _timeframe,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('Daily (24h Stats)'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('Weekly (7 Days)'),
                      ),
                      DropdownMenuItem(
                        value: '14d',
                        child: Text('14-Day Stats'),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly (30 Days)'),
                      ),
                      DropdownMenuItem(
                        value: 'quarterly',
                        child: Text('Quarterly (90 Days)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _timeframe = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Logged',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(totalTimeframeMinutes / 60.0).toStringAsFixed(1)} / ${_timeframe == 'daily' ? '24' : _timeframe == 'weekly' ? '168' : _timeframe == '14d' ? '336' : _timeframe == 'monthly' ? '720' : '2160'} hrs',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: sortedStats.isEmpty
                          ? const Center(
                              child: Text(
                                'No activity logged for this period yet.',
                                style: TextStyle(fontSize: 12),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Row(
                                          children: sortedStats.map((stat) {
                                            final flex = stat.minutes;
                                            final color =
                                                _parseHexColor(stat.color);
                                            return Expanded(
                                              flex: flex.clamp(1, 10000),
                                              child: Container(
                                                height: 8,
                                                color: color,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: sortedStats.take(4).map((stat) {
                                      final pct = totalTimeframeMinutes > 0
                                          ? ((stat.minutes /
                                                      totalTimeframeMinutes) *
                                                  100)
                                              .toStringAsFixed(0)
                                          : '0';
                                      final n = stat.name;
                                      final hStr = (stat.minutes / 60.0)
                                          .toStringAsFixed(1);
                                      final statText = '$n: ${hStr}h ($pct%)';
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              stat.icon,
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Date Picker Bar for 24-Hour Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.view_timeline_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '24-Hour Grid: ${_formatDateLabel(_selectedDate)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => _openLogDialog(0, null),
                    icon: const Icon(Icons.date_range, size: 16),
                    label: const Text('Bulk Log Range'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: () => setState(
                          () => _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1)),
                        ),
                        tooltip: 'Previous Day',
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        onPressed: _pickDate,
                        tooltip: 'Pick Date',
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _selectedDate.day == DateTime.now().day &&
                                _selectedDate.month == DateTime.now().month &&
                                _selectedDate.year == DateTime.now().year
                            ? null
                            : () => setState(
                                  () => _selectedDate = _selectedDate
                                      .add(const Duration(days: 1)),
                                ),
                        tooltip: 'Next Day',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 24-Hour Timeline Grid List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: 24,
            itemBuilder: (context, hour) {
              final logs = dayLogsMap[hour];
              final isCurrentHour = _selectedDate.day == DateTime.now().day &&
                  _selectedDate.month == DateTime.now().month &&
                  _selectedDate.year == DateTime.now().year &&
                  hour == DateTime.now().hour;

              if (logs == null || logs.isEmpty) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isCurrentHour
                      ? theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3)
                      : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isCurrentHour
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                      width: isCurrentHour ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _openLogDialog(hour, null),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    fontWeight: isCurrentHour
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isCurrentHour
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isCurrentHour
                                    ? 'Current Hour (Tap to Log)'
                                    : 'Unlogged Hour Block',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final firstLog = logs.first;
              final primaryColor = _parseHexColor(firstLog.tagColorHex);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: primaryColor.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: primaryColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: InkWell(
                  onTap: () => _openLogDialog(hour, firstLog),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: logs.map((log) {
                                  final tagColor =
                                      _parseHexColor(log.tagColorHex);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tagColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: tagColor.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          log.tagIcon,
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${log.tagName} (${log.durationMinutes}m)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: tagColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (firstLog.projectTitle != null &&
                                  firstLog.projectTitle!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    (() {
                                      if (firstLog.projectTitle == null ||
                                          firstLog.projectTitle!.isEmpty)
                                        return '';
                                      if (firstLog.projectId == null ||
                                          firstLog.projectId!.isEmpty) {
                                        return firstLog.projectTitle!;
                                      }
                                      // If title contains "Project " placeholder prefix, resolve from cache
                                      if (firstLog.projectTitle!
                                              .startsWith('Project ') ||
                                          firstLog.projectTitle!
                                              .contains('Project ')) {
                                        final ids = firstLog.projectId!
                                            .split(',')
                                            .where((s) => s.isNotEmpty)
                                            .toList();
                                        final titles = <String>[];
                                        for (final id in ids) {
                                          final cached = NotionService()
                                              .getCachedPageTitle(id);
                                          if (cached != null &&
                                              cached.isNotEmpty) {
                                            titles.add(cached);
                                          }
                                        }
                                        if (titles.isNotEmpty) {
                                          return titles.join(', ');
                                        }
                                      }
                                      return firstLog.projectTitle!;
                                    })(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme
                                          .colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (firstLog.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  firstLog.notes,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
