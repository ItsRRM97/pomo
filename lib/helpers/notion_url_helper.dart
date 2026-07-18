import 'package:pomo/singletons/prefs.dart';

/// Builds URLs for opening Notion pages and databases in the browser.
class NotionUrlHelper {
  NotionUrlHelper._();

  /// Converts a Notion UUID (with or without dashes) to the dash-less format
  /// that Notion URLs use.
  static String _stripDashes(String id) => id.replaceAll('-', '');

  /// Returns the Notion URL for the Time Logs database configured in Prefs.
  static String get timeLogsDatabaseUrl {
    final dbId = _stripDashes(Prefs.notionTimeLogsDatabaseId);
    return 'https://www.notion.so/$dbId';
  }

  /// Returns the Notion URL for the Tasks database configured in Prefs.
  static String get tasksDatabaseUrl {
    final dbId = _stripDashes(Prefs.notionDatabaseId);
    return 'https://www.notion.so/$dbId';
  }

  /// Whether an Hourly Timeline database ID is configured in Prefs.
  static bool get hasHourlyTimelineDatabaseId =>
      Prefs.notionHourlyTimelineDatabaseId.trim().isNotEmpty;

  /// Returns the Notion URL for the Hourly Timeline database configured in Prefs.
  ///
  /// Returns an empty string when no database ID is set.
  static String get hourlyTimelineDatabaseUrl {
    final raw = Prefs.notionHourlyTimelineDatabaseId.trim();
    if (raw.isEmpty) return '';
    final dbId = _stripDashes(raw);
    return 'https://www.notion.so/$dbId';
  }
}
