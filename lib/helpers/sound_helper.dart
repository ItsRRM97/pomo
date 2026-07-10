import 'package:audioplayers/audioplayers.dart';

/// Bundled timer alert sounds. All royalty-free generated tones or existing assets.
class TimerSoundPreset {
  const TimerSoundPreset({
    required this.id,
    required this.label,
    this.assetPath,
  });

  /// Value stored in preferences. Empty string means default ding dong.
  final String id;
  final String label;

  /// Asset path relative to the assets folder, if bundled.
  final String? assetPath;

  static const defaultId = '';

  static const List<TimerSoundPreset> presets = [
    TimerSoundPreset(
      id: defaultId,
      label: 'None',
    ),
    TimerSoundPreset(
      id: 'sounds/ding_dong.aac',
      label: 'Ding Dong',
      assetPath: 'sounds/ding_dong.aac',
    ),
    TimerSoundPreset(
      id: 'sounds/pop.aac',
      label: 'Pop',
      assetPath: 'sounds/pop.aac',
    ),
    TimerSoundPreset(
      id: 'sounds/click.aac',
      label: 'Click',
      assetPath: 'sounds/click.aac',
    ),
    TimerSoundPreset(
      id: 'sounds/chime.wav',
      label: 'Soft Chime',
      assetPath: 'sounds/chime.wav',
    ),
    TimerSoundPreset(
      id: 'sounds/bell.wav',
      label: 'Bell',
      assetPath: 'sounds/bell.wav',
    ),
    TimerSoundPreset(
      id: 'sounds/digital_beep.wav',
      label: 'Digital Beep',
      assetPath: 'sounds/digital_beep.wav',
    ),
  ];

  static TimerSoundPreset presetFor(String storedValue) {
    if (storedValue.isEmpty) {
      return presets.first;
    }

    return presets.firstWhere(
      (preset) => preset.id == storedValue,
      orElse: () => TimerSoundPreset(
        id: storedValue,
        label: storedValue.split('/').last,
      ),
    );
  }

  static bool isBundledAsset(String storedValue) {
    return storedValue.isEmpty ||
        presets.any(
          (preset) => preset.id == storedValue && preset.assetPath != null,
        );
  }
}

class SoundHelper {
  static const defaultAsset = 'sounds/ding_dong.aac';

  static Source resolveSource(String storedValue) {
    if (storedValue.isEmpty) {
      return AssetSource(defaultAsset);
    }

    if (storedValue.startsWith('sounds/')) {
      return AssetSource(storedValue);
    }

    return DeviceFileSource(storedValue);
  }

  static Future<void> playPreview(AudioPlayer player, String storedValue) async {
    await player.stop();
    await player.play(resolveSource(storedValue));
  }
}
