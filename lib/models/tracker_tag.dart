import 'package:equatable/equatable.dart';

/// Represents a pre-defined or custom activity category/tag for hourly logging.
class TrackerTag extends Equatable {
  const TrackerTag({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    this.isDefault = false,
  });

  /// Creates a [TrackerTag] from JSON map.
  factory TrackerTag.fromJson(Map<String, dynamic> json) {
    return TrackerTag(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Activity',
      icon: json['icon'] as String? ?? '⏱️',
      colorHex: json['colorHex'] as String? ?? '#4285F4',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Unique ID for the tag.
  final String id;

  /// Display name (`e.g., Coding`, `Meetings`, `Workout`).
  final String name;

  /// Emoji string or icon representation (`e.g., 💻`, `📅`).
  final String icon;

  /// Hex color code string (`e.g., #4285F4`).
  final String colorHex;

  /// Whether this is one of the built-in default tags.
  final bool isDefault;

  /// Converts this [TrackerTag] to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorHex': colorHex,
      'isDefault': isDefault,
    };
  }

  @override
  List<Object?> get props => [id, name, icon, colorHex, isDefault];

  /// Default pre-defined tags provided out of the box.
  static const List<TrackerTag> defaults = [
    TrackerTag(
      id: 'tag_coding',
      name: 'Coding & Dev',
      icon: '💻',
      colorHex: '#4285F4',
      isDefault: true,
    ),
    TrackerTag(
      id: 'tag_meetings',
      name: 'Meetings & Calls',
      icon: '📞',
      colorHex: '#FBBC05',
      isDefault: true,
    ),
    TrackerTag(
      id: 'tag_deep_work',
      name: 'Deep Work',
      icon: '🧠',
      colorHex: '#34A853',
      isDefault: true,
    ),
    TrackerTag(
      id: 'tag_reading',
      name: 'Reading & Learning',
      icon: '📚',
      colorHex: '#AB47BC',
      isDefault: true,
    ),
    TrackerTag(
      id: 'tag_workout',
      name: 'Fitness & Health',
      icon: '🏋️',
      colorHex: '#EA4335',
      isDefault: true,
    ),
    TrackerTag(
      id: 'tag_admin',
      name: 'Admin & Errands',
      icon: '📝',
      colorHex: '#78909C',
      isDefault: true,
    ),
    TrackerTag(
      id: 'tag_sleep',
      name: 'Sleep & Rest',
      icon: '😴',
      colorHex: '#5C6BC0',
      isDefault: true,
    ),
  ];
}
