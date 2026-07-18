import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/helpers/notion_url_helper.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

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
            const SizedBox(height: 16),
            Text(
              'Tasks Database ID',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'e.g., 1d33dffe-a139-81c6-8ce5-ee843fbf3579',
                border: OutlineInputBorder(),
              ),
              initialValue: state.notionDatabaseId,
              onChanged: (value) =>
                  context.read<SettingsCubit>().setNotionDatabaseId(value),
            ),
            const SizedBox(height: 16),
            Text(
              'Time Logs Database ID',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'e.g., acd9cab4-5560-456c-b9b5-586d9a5b391c',
                border: OutlineInputBorder(),
              ),
              initialValue: state.notionTimeLogsDatabaseId,
              onChanged: (value) => context
                  .read<SettingsCubit>()
                  .setNotionTimeLogsDatabaseId(value),
            ),
            const SizedBox(height: 16),
            Text(
              'PARA Projects Database ID',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'e.g., 1d33dffe-a139-8160-b230-f2cdb7317b26',
                border: OutlineInputBorder(),
              ),
              initialValue: state.notionProjectsDatabaseId,
              onChanged: (value) => context
                  .read<SettingsCubit>()
                  .setNotionProjectsDatabaseId(value),
            ),
            const SizedBox(height: 16),
            Text(
              'PARA Areas Database ID',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'e.g., 1d33dffe-a139-8152-9ed2-f3eddc9bd5f8',
                border: OutlineInputBorder(),
              ),
              initialValue: state.notionAreasDatabaseId,
              onChanged: (value) =>
                  context.read<SettingsCubit>().setNotionAreasDatabaseId(value),
            ),
            const SizedBox(height: 16),
            Text(
              'Hourly Timeline Database ID',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'e.g., 39d3dffe-a139-8190-9176-d98e3475c5ec',
                border: OutlineInputBorder(),
              ),
              initialValue: state.notionHourlyTimelineDatabaseId,
              onChanged: (value) => context
                  .read<SettingsCubit>()
                  .setNotionHourlyTimelineDatabaseId(value),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final url = NotionUrlHelper.timeLogsDatabaseUrl;
                launchUrl(Uri.parse(url));
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Notion Time Logs'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                if (!NotionUrlHelper.hasHourlyTimelineDatabaseId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Set Hourly Timeline Database ID in Settings',
                      ),
                    ),
                  );
                  return;
                }
                final url = NotionUrlHelper.hourlyTimelineDatabaseUrl;
                launchUrl(Uri.parse(url));
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Notion Hourly Timeline'),
            ),
          ],
        );
      },
    );
  }
}
