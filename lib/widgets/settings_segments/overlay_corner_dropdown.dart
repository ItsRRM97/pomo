import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class OverlayCornerDropdown extends StatelessWidget {
  const OverlayCornerDropdown({super.key});

  static const _corners = {
    'topLeft': 'Top left',
    'topRight': 'Top right',
    'bottomLeft': 'Bottom left',
    'bottomRight': 'Bottom right',
  };

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ListTile(
          title: Text(l10n.overlayCorner),
          subtitle: Text(l10n.overlayCornerDescription),
          trailing: DropdownButton<String>(
            value: state.overlayCorner,
            items: _corners.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                context.read<SettingsCubit>().setOverlayCorner(value);
              }
            },
          ),
        );
      },
    );
  }
}
