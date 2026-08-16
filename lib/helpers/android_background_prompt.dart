/// Pure gating for the Android battery / notification soft prompt (A8).
class AndroidBackgroundPrompt {
  static bool dismissedThisSession = false;

  /// Whether to show a rationale dialog for unrestricted battery / alerts.
  static bool shouldPrompt({
    required bool isAndroid,
    required bool trackerEnabled,
    required bool ignoringBatteryOptimizations,
    required bool notificationsEnabled,
    bool? dismissedThisSession,
  }) {
    final dismissed =
        dismissedThisSession ?? AndroidBackgroundPrompt.dismissedThisSession;
    if (!isAndroid || !trackerEnabled || dismissed) {
      return false;
    }
    return !ignoringBatteryOptimizations || !notificationsEnabled;
  }
}
