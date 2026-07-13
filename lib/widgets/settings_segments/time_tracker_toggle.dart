import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class TimeTrackerToggle extends StatelessWidget {
  const TimeTrackerToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return SwitchListTile(
          value: state.enableTimeTracker,
          title: Text(l10n.enableTimeTracker),
          subtitle: Text(l10n.enableTimeTrackerDescription),
          onChanged: (val) =>
              context.read<SettingsCubit>().setEnableTimeTracker(val),
        );
      },
    );
  }
}
