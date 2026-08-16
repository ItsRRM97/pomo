/// Quiet-hours window checks for missed-hour scans and Resting auto-logs.
///
/// Kept free of [BuildContext] so unit tests can cover enable/disable and
/// overnight wrap without a widget tree.
class QuietHoursHelper {
  /// Whether hour index `[0, 23]` sits in the configured quiet-hours window.
  ///
  /// When [enableQuietHours] is false, always returns false so those hours
  /// remain visible as missed/untracked.
  static bool isQuietHourIndex({
    required int hour,
    required bool enableQuietHours,
    required String start,
    required String end,
  }) {
    if (!enableQuietHours) {
      return false;
    }
    try {
      final startH = int.parse(start.split(':')[0]);
      final endH = int.parse(end.split(':')[0]);
      if (startH > endH) {
        return hour >= startH || hour < endH;
      }
      return hour >= startH && hour < endH;
    } on FormatException {
      return false;
    }
  }

  /// ISO date `YYYY-MM-DD` for [date].
  static String dateStr(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
