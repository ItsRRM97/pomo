import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class RequestNotificationPermissionToggle extends StatelessWidget {
  const RequestNotificationPermissionToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (BuildContext context, SettingsState state) {
        return SwitchListTile(
          title: const Text('Request Notification Permission'),
          subtitle: const Text('Allow PWA notifications'),
          value: state.requestNotificationPermission,
          onChanged: (bool value) {
            context
                .read<SettingsCubit>()
                .setRequestNotificationPermission(value);
          },
        );
      },
    );
  }
}
