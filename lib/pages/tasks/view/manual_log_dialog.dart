import 'package:flutter/material.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/services/notion_sync_service.dart';

class ManualLogDialog extends StatefulWidget {
  const ManualLogDialog({required this.task, super.key});

  final NotionTask task;

  static Future<bool?> show(BuildContext context, NotionTask task) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ManualLogDialog(task: task),
    );
  }

  @override
  State<ManualLogDialog> createState() => _ManualLogDialogState();
}

class _ManualLogDialogState extends State<ManualLogDialog> {
  int _hours = 1;
  int _minutes = 0;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  void _addQuickTime(int h, int m) {
    setState(() {
      final totalMin = (_hours * 60 + _minutes) + (h * 60 + m);
      _hours = totalMin ~/ 60;
      _minutes = totalMin % 60;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    final duration = Duration(hours: _hours, minutes: _minutes);
    if (duration.inMinutes < 1) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await NotionSyncService().syncSession(
        task: widget.task,
        duration: duration,
        endedAt: _selectedDate,
      );
      if (!mounted) return;
      final hPart = duration.inHours > 0 ? '${duration.inHours}h ' : '';
      final mPart = '${duration.inMinutes % 60}m';
      final formatted = '$hPart$mPart'.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.timeLoggedSuccess(formatted, widget.task.title),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dateStr = '${_selectedDate.year}-'
        '${_selectedDate.month.toString().padLeft(2, '0')}-'
        '${_selectedDate.day.toString().padLeft(2, '0')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.logPastTimeTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.task.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.hoursLabel,
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _hours > 0
                                  ? () => setState(() => _hours--)
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                '$_hours',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(() => _hours++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.minutesLabel,
                          style: theme.textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: _minutes >= 15
                                  ? () => setState(() => _minutes -= 15)
                                  : (_minutes > 0
                                      ? () => setState(() => _minutes = 0)
                                      : null),
                            ),
                            Expanded(
                              child: Text(
                                '$_minutes',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setState(
                                () => _minutes = (_minutes + 15) % 60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.quickAdd,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('+15m'),
                    onPressed: () => _addQuickTime(0, 15),
                  ),
                  ActionChip(
                    label: const Text('+30m'),
                    onPressed: () => _addQuickTime(0, 30),
                  ),
                  ActionChip(
                    label: const Text('+1h'),
                    onPressed: () => _addQuickTime(1, 0),
                  ),
                  ActionChip(
                    label: const Text('+2h'),
                    onPressed: () => _addQuickTime(2, 0),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.dateLabel}: $dateStr',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Change Date'),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting || (_hours == 0 && _minutes == 0)
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.logPastTime),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
