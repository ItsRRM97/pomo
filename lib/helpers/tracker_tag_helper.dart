import 'package:pomo/models/tracker_tag.dart';

/// Name normalization and duplicate lookup for activity tags.
class TrackerTagHelper {
  /// Trim + lowercase so "Deep Work" matches "deep work".
  static String normalizeName(String name) {
    return name.trim().toLowerCase();
  }

  /// First tag whose normalized name matches [name], or null.
  static TrackerTag? findDuplicate(
    String name, {
    required Iterable<TrackerTag> existing,
  }) {
    final normalized = normalizeName(name);
    if (normalized.isEmpty) {
      return null;
    }
    for (final tag in existing) {
      if (normalizeName(tag.name) == normalized) {
        return tag;
      }
    }
    return null;
  }
}
