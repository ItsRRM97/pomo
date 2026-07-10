import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:pomo/helpers/sound_helper.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/settings.dart';

class CustomSoundExpansion extends StatelessWidget {
  const CustomSoundExpansion({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return ExpansionTile(
          title: Text(l10n.customSounds),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          shape: const Border(),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            _SoundPresetField(
              value: state.customWorkStartSound,
              onChanged: (value) {
                context.read<SettingsCubit>().setCustomWorkStartSound(value);
              },
              title: l10n.workStartSound,
            ),
            const SizedBox(height: 16),
            _SoundPresetField(
              value: state.customShortBreakStartSound,
              onChanged: (value) {
                context
                    .read<SettingsCubit>()
                    .setCustomShortBreakStartSound(value);
              },
              title: l10n.shortBreakStartSound,
            ),
            const SizedBox(height: 16),
            _SoundPresetField(
              value: state.customLongBreakStartSound,
              onChanged: (value) {
                context
                    .read<SettingsCubit>()
                    .setCustomLongBreakStartSound(value);
              },
              title: l10n.longBreakStartSound,
            ),
            const SizedBox(height: 16),
            _SoundPresetField(
              value: state.customWorkEndSound,
              onChanged: (value) {
                context.read<SettingsCubit>().setCustomWorkEndSound(value);
              },
              title: l10n.workEndSound,
            ),
            const SizedBox(height: 16),
            _SoundPresetField(
              value: state.customShortBreakEndSound,
              onChanged: (value) {
                context
                    .read<SettingsCubit>()
                    .setCustomShortBreakEndSound(value);
              },
              title: l10n.shortBreakEndSound,
            ),
            const SizedBox(height: 16),
            _SoundPresetField(
              value: state.customLongBreakEndSound,
              onChanged: (value) {
                context.read<SettingsCubit>().setCustomLongBreakEndSound(value);
              },
              title: l10n.longBreakEndSound,
            ),
          ],
        );
      },
    );
  }
}

class _SoundPresetField extends StatefulWidget {
  const _SoundPresetField({
    required this.onChanged,
    required this.title,
    required this.value,
  });

  final String title;
  final String value;
  final void Function(String) onChanged;

  @override
  State<_SoundPresetField> createState() => _SoundPresetFieldState();
}

class _SoundPresetFieldState extends State<_SoundPresetField> {
  late AudioPlayer _player;
  static const _customFileId = '__custom_file__';

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String get _selectedId {
    if (widget.value.isEmpty || TimerSoundPreset.isBundledAsset(widget.value)) {
      return widget.value;
    }
    return _customFileId;
  }

  Future<void> _pickCustomFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null) {
      return;
    }

    final path = result.files.single.path;
    if (path == null) {
      return;
    }

    Logger().i('Selected file: $path');
    widget.onChanged(path);
  }

  Future<void> _previewSound() async {
    if (_player.state == PlayerState.playing) {
      await _player.stop();
      return;
    }

    await SoundHelper.playPreview(_player, widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        );
    final items = [
      ...TimerSoundPreset.presets.map(
        (preset) => DropdownMenuItem<String>(
          value: preset.id,
          child: Text(preset.label),
        ),
      ),
      if (!kIsWeb)
        DropdownMenuItem<String>(
          value: _customFileId,
          child: Text(l10n.customSoundFile),
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: labelStyle,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: _selectedId,
                isExpanded: true,
                items: items,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  if (value == _customFileId) {
                    _pickCustomFile();
                    return;
                  }
                  widget.onChanged(value);
                },
              ),
            ),
            IconButton(
              tooltip: l10n.previewSound,
              onPressed: widget.value.isEmpty ? null : _previewSound,
              icon: StreamBuilder<PlayerState>(
                stream: _player.onPlayerStateChanged,
                builder: (context, snapshot) {
                  final playing = snapshot.data == PlayerState.playing;
                  return Icon(playing ? Icons.stop : Icons.play_arrow);
                },
              ),
            ),
          ],
        ),
        if (!kIsWeb &&
            widget.value.isNotEmpty &&
            !TimerSoundPreset.isBundledAsset(widget.value))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
