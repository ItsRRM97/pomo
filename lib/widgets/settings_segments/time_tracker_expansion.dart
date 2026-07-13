import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class TimeTrackerExpansion extends StatelessWidget {
  const TimeTrackerExpansion({super.key});

  Future<void> _pickTime(
    BuildContext context,
    String currentValue,
    ValueChanged<String> onSelected,
  ) async {
    final parts = currentValue.split(':');
    final initialHour = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
    final initialMinute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      onSelected('$h:$m');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ExpansionTile(
          enabled: state.enableTimeTracker,
          title: Text(l10n.timeTrackerAndAutomation),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.quietHoursStart,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('quietHoursStart_${state.quietHoursStart}'),
              decoration: InputDecoration(
                hintText: '23:00',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _pickTime(
                    context,
                    state.quietHoursStart,
                    (val) =>
                        context.read<SettingsCubit>().setQuietHoursStart(val),
                  ),
                ),
              ),
              initialValue: state.quietHoursStart,
              onChanged: (value) =>
                  context.read<SettingsCubit>().setQuietHoursStart(value),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.quietHoursEnd,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('quietHoursEnd_${state.quietHoursEnd}'),
              decoration: InputDecoration(
                hintText: '07:00',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _pickTime(
                    context,
                    state.quietHoursEnd,
                    (val) =>
                        context.read<SettingsCubit>().setQuietHoursEnd(val),
                  ),
                ),
              ),
              initialValue: state.quietHoursEnd,
              onChanged: (value) =>
                  context.read<SettingsCubit>().setQuietHoursEnd(value),
            ),
          ],
        );
      },
    );
  }
}
