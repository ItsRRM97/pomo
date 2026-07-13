import 'package:flutter/material.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/pages/tracker/view/hourly_log_dialog.dart';
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
    final dayLogsMap = <int, HourlyLog>{};
    for (final log in _allLogs) {
      if (log.dateStr == targetDateStr) {
        dayLogsMap[log.hour] = log;
      }
    }

    final timeframeLogs = _getLogsForTimeframe();
    final tagHoursMap =
        <String, ({String name, String icon, String color, int hours})>{};
    var totalTimeframeHours = 0;
    for (final l in timeframeLogs) {
      totalTimeframeHours += 1;
      final current = tagHoursMap[l.tagId] ??
          (name: l.tagName, icon: l.tagIcon, color: l.tagColorHex, hours: 0);
      tagHoursMap[l.tagId] = (
        name: current.name,
        icon: current.icon,
        color: current.color,
        hours: current.hours + 1,
      );
    }

    final sortedStats = tagHoursMap.values.toList()
      ..sort((a, b) => b.hours.compareTo(a.hours));

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
                            '$totalTimeframeHours / ${_timeframe == 'daily' ? '24' : _timeframe == 'weekly' ? '168' : _timeframe == '14d' ? '336' : _timeframe == 'monthly' ? '720' : '2160'} hrs',
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
                                            final flex = stat.hours;
                                            final color =
                                                _parseHexColor(stat.color);
                                            return Expanded(
                                              flex: flex,
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
                                      final pct = totalTimeframeHours > 0
                                          ? ((stat.hours /
                                                      totalTimeframeHours) *
                                                  100)
                                              .toStringAsFixed(0)
                                          : '0';
                                      final n = stat.name;
                                      final h = stat.hours;
                                      final statText = '$n: ${h}h ($pct%)';
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
              Row(
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
                              () => _selectedDate =
                                  _selectedDate.add(const Duration(days: 1)),
                            ),
                    tooltip: 'Next Day',
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
              final log = dayLogsMap[hour];
              final isCurrentHour = _selectedDate.day == DateTime.now().day &&
                  _selectedDate.month == DateTime.now().month &&
                  _selectedDate.year == DateTime.now().year &&
                  hour == DateTime.now().hour;

              if (log == null) {
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

              final badgeColor = _parseHexColor(log.tagColorHex);
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                color: badgeColor.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: badgeColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: InkWell(
                  onTap: () => _openLogDialog(hour, log),
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
                        Text(log.tagIcon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    log.tagName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: badgeColor,
                                    ),
                                  ),
                                  if (log.projectTitle != null &&
                                      log.projectTitle!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        log.projectTitle!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme
                                              .colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (log.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  log.notes,
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
                          color: badgeColor,
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
