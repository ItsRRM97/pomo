import 'package:flutter/material.dart';
import 'package:pomo/pages/tracker/view/hourly_log_dialog.dart';
import 'package:pomo/singletons/prefs.dart';

/// Checklist view showing missed/unlogged 1-hour activity blocks.
class MissedTrackingView extends StatefulWidget {
  const MissedTrackingView({super.key});

  @override
  State<MissedTrackingView> createState() => _MissedTrackingViewState();
}

class _MissedTrackingViewState extends State<MissedTrackingView> {
  int _daysBack = 1; // 1 = 24h/Today, 7 = 7 days, 14 = 14 days
  List<({DateTime date, int hour})> _missedBlocks = [];

  @override
  void initState() {
    super.initState();
    _scanMissedBlocks();
  }

  void _scanMissedBlocks() {
    final now = DateTime.now();
    final allLogs = Prefs.hourlyLogs;
    final loggedSet = <String>{};
    for (final log in allLogs) {
      loggedSet.add('${log.dateStr}_${log.hour}');
    }

    final missed = <({DateTime date, int hour})>[];
    for (var d = 0; d < _daysBack; d++) {
      final targetDate = now.subtract(Duration(days: d));
      final y = targetDate.year;
      final m = targetDate.month.toString().padLeft(2, '0');
      final dDay = targetDate.day.toString().padLeft(2, '0');
      final dateStr = '$y-$m-$dDay';

      final maxHour = (d == 0) ? now.hour : 24;
      for (var h = 0; h < maxHour; h++) {
        // Skip user configured quiet hours if they fall in sleep window
        if (_isSleepHour(h)) continue;

        final key = '${dateStr}_$h';
        if (!loggedSet.contains(key)) {
          missed.add((date: targetDate, hour: h));
        }
      }
    }

    setState(() {
      _missedBlocks = missed;
    });
  }

  bool _isSleepHour(int h) {
    final quietStartStr = Prefs.quietHoursStart;
    final quietEndStr = Prefs.quietHoursEnd;
    try {
      final startH = int.parse(quietStartStr.split(':')[0]);
      final endH = int.parse(quietEndStr.split(':')[0]);
      if (startH > endH) {
        return h >= startH || h < endH;
      } else {
        return h >= startH && h < endH;
      }
    } catch (_) {
      return false;
    }
  }

  String _formatDateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday';
    }
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatHourWindow(int h) {
    final start = h.toString().padLeft(2, '0');
    final end = ((h + 1) % 24).toString().padLeft(2, '0');
    return '$start:00 - $end:00';
  }

  Future<void> _logMissedBlock(DateTime date, int hour) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => HourlyLogDialog(
        selectedDate: date,
        hour: hour,
      ),
    );
    if ((saved ?? false) && mounted) {
      _scanMissedBlocks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Unlogged Time Blocks (${_missedBlocks.length})',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: _daysBack,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Past 24h / Today')),
                  DropdownMenuItem(value: 7, child: Text('Past 7 Days')),
                  DropdownMenuItem(value: 14, child: Text('Past 14 Days')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _daysBack = val);
                    _scanMissedBlocks();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _missedBlocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All caught up!',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Quiet hours are excluded. All other hours in this '
                        'period are tracked.',
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _missedBlocks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _missedBlocks[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.error,
                          child: const Icon(Icons.timer_off_outlined),
                        ),
                        title: Text(
                          _formatHourWindow(item.hour),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_formatDateLabel(item.date)),
                        trailing: FilledButton.icon(
                          onPressed: () =>
                              _logMissedBlock(item.date, item.hour),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Log Now'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(88, 44),
                            tapTargetSize: MaterialTapTargetSize.padded,
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
