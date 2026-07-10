import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class ShowFloatingTimerToggle extends StatelessWidget {
  const ShowFloatingTimerToggle({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return SwitchListTile(
          value: state.showFloatingTimer,
          title: Text(l10n.showFloatingTimer),
          subtitle: Text(l10n.showFloatingTimerDescription),
          onChanged: (val) =>
              context.read<SettingsCubit>().setShowFloatingTimer(val),
        );
      },
    );
  }
}
