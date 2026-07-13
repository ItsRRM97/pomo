import 'package:equatable/equatable.dart';

/// Represents a logged 1-hour activity session inside the 24-hour daily timeline.
class HourlyLog extends Equatable {
  const HourlyLog({
    required this.id,
    required this.dateStr,
    required this.hour,
    required this.tagId,
    required this.tagName,
    required this.tagIcon,
    required this.tagColorHex,
    this.projectId,
    this.projectTitle,
    this.notes = '',
    this.notionPageId,
    required this.loggedAt,
  });

  /// Creates an [HourlyLog] from JSON map.
  factory HourlyLog.fromJson(Map<String, dynamic> json) {
    return HourlyLog(
      id: json['id'] as String? ?? '',
      dateStr: json['dateStr'] as String? ?? '',
      hour: json['hour'] as int? ?? 0,
      tagId: json['tagId'] as String? ?? '',
      tagName: json['tagName'] as String? ?? 'Activity',
      tagIcon: json['tagIcon'] as String? ?? '⏱️',
      tagColorHex: json['tagColorHex'] as String? ?? '#4285F4',
      projectId: json['projectId'] as String?,
      projectTitle: json['projectTitle'] as String?,
      notes: json['notes'] as String? ?? '',
      notionPageId: json['notionPageId'] as String?,
      loggedAt: json['loggedAt'] != null
          ? DateTime.tryParse(json['loggedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Unique ID of this log (`e.g., log_2026-07-13_14`).
  final String id;

  /// ISO date string (`e.g., 2026-07-13`).
  final String dateStr;

  /// Hour index of the 24-hour day (`0` for 00:00-01:00 up to `23` for 23:00-24:00`).
  final int hour;

  /// Selected tag ID (`e.g., tag_coding` or custom tag ID).
  final String tagId;

  /// Tag display name (`e.g., Coding & Dev`).
  final String tagName;

  /// Tag emoji icon (`e.g., 💻`).
  final String tagIcon;

  /// Tag badge color hex code (`e.g., #4285F4`).
  final String tagColorHex;

  /// Attached PARA Project ID from Notion (optional).
  final String? projectId;

  /// Attached PARA Project title from Notion (optional).
  final String? projectTitle;

  /// Custom text note/description typed by the user.
  final String notes;

  /// Notion Time Logs database page ID if synced successfully.
  final String? notionPageId;

  /// Exact timestamp when this log was created or last modified.
  final DateTime loggedAt;

  /// Creates a copy of this log with updated properties.
  HourlyLog copyWith({
    String? id,
    String? dateStr,
    int? hour,
    String? tagId,
    String? tagName,
    String? tagIcon,
    String? tagColorHex,
    String? projectId,
    String? projectTitle,
    String? notes,
    String? notionPageId,
    DateTime? loggedAt,
  }) {
    return HourlyLog(
      id: id ?? this.id,
      dateStr: dateStr ?? this.dateStr,
      hour: hour ?? this.hour,
      tagId: tagId ?? this.tagId,
      tagName: tagName ?? this.tagName,
      tagIcon: tagIcon ?? this.tagIcon,
      tagColorHex: tagColorHex ?? this.tagColorHex,
      projectId: projectId ?? this.projectId,
      projectTitle: projectTitle ?? this.projectTitle,
      notes: notes ?? this.notes,
      notionPageId: notionPageId ?? this.notionPageId,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  /// Converts this [HourlyLog] to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateStr': dateStr,
      'hour': hour,
      'tagId': tagId,
      'tagName': tagName,
      'tagIcon': tagIcon,
      'tagColorHex': tagColorHex,
      if (projectId != null) 'projectId': projectId,
      if (projectTitle != null) 'projectTitle': projectTitle,
      'notes': notes,
      if (notionPageId != null) 'notionPageId': notionPageId,
      'loggedAt': loggedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        dateStr,
        hour,
        tagId,
        tagName,
        tagIcon,
        tagColorHex,
        projectId,
        projectTitle,
        notes,
        notionPageId,
        loggedAt,
      ];
}
