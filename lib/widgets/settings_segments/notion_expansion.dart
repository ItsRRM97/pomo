import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';

class NotionExpansion extends StatelessWidget {
  const NotionExpansion({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ExpansionTile(
          enabled: state.enableNotionSync,
          title: Text(l10n.notionIntegration),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.notionApiKey,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                hintText: l10n.notionApiKeyHint,
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              initialValue: state.notionApiKey,
              onChanged: (value) =>
                  context.read<SettingsCubit>().setNotionApiKey(value),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.notionProxyUrl,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                hintText: l10n.notionProxyUrlHint,
                border: const OutlineInputBorder(),
              ),
              initialValue: state.notionProxyUrl,
              onChanged: (value) =>
                  context.read<SettingsCubit>().setNotionProxyUrl(value),
            ),
          ],
        );
      },
    );
  }
}
