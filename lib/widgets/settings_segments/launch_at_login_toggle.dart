import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class LaunchAtLoginToggle extends StatelessWidget {
  const LaunchAtLoginToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (kIsWeb || !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return SwitchListTile(
          value: state.launchAtLogin,
          title: Text(l10n.launchAtLogin),
          subtitle: Text(l10n.launchAtLoginDescription),
          onChanged: (val) =>
              context.read<SettingsCubit>().setLaunchAtLogin(val),
        );
      },
    );
  }
}
