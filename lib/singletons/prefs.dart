import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pomo/helpers/hook_helper.dart';
import 'package:pomo/models/hourly_log.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/models/tracker_tag.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Legacy compile-time Notion integration token for desktop builds.
// Web builds should not auto-seed; users enter the shared access code.
const String _kNotionTokenEnv = String.fromEnvironment('NOTION_TOKEN');

enum TimerFont {
  mono,
  fancyMono,
  boldMono,
  bold,
  regular,
  custom,
}

/// Singleton class for SharedPreferences
class Prefs {
  /// Factory constructor
  factory Prefs() {
    return _singleton;
  }

  Prefs._internal();

  /// Singleton instance
  static final Prefs _singleton = Prefs._internal();

  /// SharedPreferences instance
  late SharedPreferences sharedPreferences;

  /// Get the SharedPreferences instance
  Future<void> init() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  /// Get a value from SharedPreferences
  static dynamic get(String key) {
    return Prefs().sharedPreferences.get(key);
  }

  /// Set a value in SharedPreferences
  static Future<bool> set(String key, dynamic value) {
    switch (value.runtimeType) {
      case bool:
        return Prefs().sharedPreferences.setBool(key, value as bool);
      case int:
        return Prefs().sharedPreferences.setInt(key, value as int);
      case double:
        return Prefs().sharedPreferences.setDouble(key, value as double);
      case String:
        return Prefs().sharedPreferences.setString(key, value as String);
      default:
        if (value is List<String>) {
          return Prefs().sharedPreferences.setStringList(key, value);
        }

        throw Exception('Invalid value type');
    }
  }

  /// Remove a value from SharedPreferences
  static Future<bool> remove(String key) {
    return Prefs().sharedPreferences.remove(key);
  }

  /// Clear all values from SharedPreferences
  static Future<bool> clear() {
    return Prefs().sharedPreferences.clear();
  }

  /// Check if a key exists in SharedPreferences
  static bool containsKey(String key) {
    return Prefs().sharedPreferences.containsKey(key);
  }

  /// Get all keys in SharedPreferences
  static Set<String> getKeys() {
    return Prefs().sharedPreferences.getKeys();
  }

  //* Custom methods

  //* Var names

  static const String _themeModeVarName = 'pomo_theme_mode';
  static const String _localeVarName = 'pomo_locale';
  static const String _lapCountVarName = 'pomo_lap_count';
  static const String _autoAdvanceVarName = 'pomo_auto_advance';
  static const String _longBreakMinutesVarName = 'pomo_long_break_minutes';
  static const String _shortBreakMinutesVarName = 'pomo_short_break_minutes';
  static const String _workMinutesVarName = 'pomo_work_minutes';
  static const String _workStartWebHookVarName = 'pomo_work_start_webhook';
  static const String _workEndWebHookVarName = 'pomo_work_end_webhook';
  static const String _shortBreakStartWebHookVarName =
      'pomo_short_break_start_webhook';
  static const String _shortBreakEndWebHookVarName =
      'pomo_short_break_end_webhook';
  static const String _longBreakStartWebHookVarName =
      'pomo_long_break_start_webhook';
  static const String _longBreakEndWebHookVarName =
      'pomo_long_break_end_webhook';
  static const String _startTimerWebHookVarName = 'pomo_start_timer_webhook';
  static const String _stopTimerWebHookVarName = 'pomo_stop_timer_webhook';
  static const String _resetTimerWebHookVarName = 'pomo_reset_timer_webhook';
  static const String _tickWebHookVarName = 'pomo_tick_webhook';
  static const String _alwaysOnTopVarName = 'pomo_always_on_top';
  static const String _enableWebhooksVarName = 'pomo_enable_webhooks';
  static const String _enableSoundVarName = 'pomo_enable_sound';
  static const String _triggerMethodVarName = 'pomo_trigger_method';
  static const String _timerFontVarName = 'pomo_timer_font';
  static const String _timerCustomFontVarName = 'pomo_timer_custom_font';
  static const String _colorSeedVarName = 'pomo_color_seed';
  static const String _customShortBreakStartSoundVarName =
      'pomo_custom_short_break_start_sound';
  static const String _customLongBreakStartSoundVarName =
      'pomo_custom_long_break_start_sound';
  static const String _customWorkStartSoundVarName =
      'pomo_custom_work_start_sound';
  static const String _customShortBreakEndSoundVarName =
      'pomo_custom_short_break_end_sound';
  static const String _customLongBreakEndSoundVarName =
      'pomo_custom_long_break_end_sound';
  static const String _customWorkEndSoundVarName = 'pomo_custom_work_end_sound';
  static const String _lapNumberVarName = 'pomo_lap_number';
  static const String _timerStatusVarName = 'pomo_timer_status';
  static const String _durationVarName = 'pomo_duration';
  static const String _timerLapVarName = 'pomo_timer_lap';
  static const String _showFloatingTimerVarName = 'pomo_show_floating_timer';
  static const String _overlayCornerVarName = 'pomo_overlay_corner';
  static const String _notionApiKeyVarName = 'pomo_notion_api_key';
  static const String _enableNotionSyncVarName = 'pomo_enable_notion_sync';
  static const String _notionProxyUrlVarName = 'pomo_notion_proxy_url';
  static const String _notionDatabaseIdVarName = 'pomo_notion_database_id';
  static const String _activeTaskJsonVarName = 'pomo_active_task_json';
  static const String _syncedMinutesVarName = 'pomo_synced_minutes';
  static const String _activeLogPageIdVarName = 'pomo_active_log_page_id';
  static const String _pendingTimeLogsVarName = 'pomo_pending_time_logs';
  static const String _enableTimeTrackerVarName = 'pomo_enable_time_tracker';
  static const String _quietHoursStartVarName = 'pomo_quiet_hours_start';
  static const String _quietHoursEndVarName = 'pomo_quiet_hours_end';
  static const String _trackerTagsVarName = 'pomo_tracker_tags';
  static const String _hourlyLogsVarName = 'pomo_hourly_logs';

  //* Getters

  static String get notionApiKey {
    final stored =
        Prefs().sharedPreferences.getString(_notionApiKeyVarName) ?? '';
    if (stored.isNotEmpty) return stored;
    // Do not auto-seed during flutter test runs so unit tests can test missing
    // API key.
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return '';
    }
    // Desktop / CLI only: seed from compile-time or system Notion token.
    // Web requires an explicit access-code prompt for new sessions.
    if (!kIsWeb) {
      if (_kNotionTokenEnv.isNotEmpty) {
        Prefs().sharedPreferences.setString(
              _notionApiKeyVarName,
              _kNotionTokenEnv,
            );
        return _kNotionTokenEnv;
      }
      final envToken = Platform.environment['NOTION_TOKEN'] ?? '';
      if (envToken.isNotEmpty) {
        Prefs().sharedPreferences.setString(
              _notionApiKeyVarName,
              envToken,
            );
        return envToken;
      }
    }
    return '';
  }

  static bool get enableNotionSync {
    // If the user has never explicitly toggled the setting, default to true
    // whenever a token is available (either stored or injected via dart-define/env).
    if (!Prefs().sharedPreferences.containsKey(_enableNotionSyncVarName)) {
      return notionApiKey.isNotEmpty;
    }
    return Prefs().sharedPreferences.getBool(_enableNotionSyncVarName) ?? false;
  }

  static String get notionProxyUrl {
    return Prefs().sharedPreferences.getString(_notionProxyUrlVarName) ?? '';
  }

  static bool get enableTimeTracker {
    return Prefs().sharedPreferences.getBool(_enableTimeTrackerVarName) ?? true;
  }

  static String get quietHoursStart {
    return Prefs().sharedPreferences.getString(_quietHoursStartVarName) ??
        '23:00';
  }

  static String get quietHoursEnd {
    return Prefs().sharedPreferences.getString(_quietHoursEndVarName) ??
        '07:00';
  }

  static String get notionDatabaseId {
    return Prefs().sharedPreferences.getString(_notionDatabaseIdVarName) ??
        '1d33dffe-a139-81c6-8ce5-ee843fbf3579';
  }

  static String get activeTaskJson {
    return Prefs().sharedPreferences.getString(_activeTaskJsonVarName) ?? '';
  }

  static NotionTask? get activeTask {
    final jsonStr = activeTaskJson;
    if (jsonStr.isEmpty) return null;
    try {
      return NotionTask.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  //* Getters
  static ThemeMode get themeMode {
    return ThemeMode.values
            .where(
              (e) =>
                  e.name ==
                  (Prefs().sharedPreferences.getString(_themeModeVarName) ??
                      'system'),
            )
            .firstOrNull ??
        ThemeMode.system;
  }

  static TimerFont get timerFont {
    return TimerFont.values
            .where(
              (e) =>
                  e.name ==
                  (Prefs().sharedPreferences.getString(_timerFontVarName) ??
                      'TimerFont.boldMono'),
            )
            .firstOrNull ??
        TimerFont.boldMono;
  }

  static Locale get locale {
    return Locale.fromSubtags(
      languageCode: Prefs().sharedPreferences.getString(_localeVarName) ?? 'en',
    );
  }

  static int get longBreakMinutes {
    return Prefs().sharedPreferences.getInt(_longBreakMinutesVarName) ?? 15;
  }

  static int get shortBreakMinutes {
    return Prefs().sharedPreferences.getInt(_shortBreakMinutesVarName) ?? 5;
  }

  static int get workMinutes {
    return Prefs().sharedPreferences.getInt(_workMinutesVarName) ?? 25;
  }

  static String get workStartWebHook {
    return Prefs().sharedPreferences.getString(_workStartWebHookVarName) ?? '';
  }

  static String get workEndWebHook {
    return Prefs().sharedPreferences.getString(_workEndWebHookVarName) ?? '';
  }

  static String get shortBreakStartWebHook {
    return Prefs()
            .sharedPreferences
            .getString(_shortBreakStartWebHookVarName) ??
        '';
  }

  static String get shortBreakEndWebHook {
    return Prefs().sharedPreferences.getString(_shortBreakEndWebHookVarName) ??
        '';
  }

  static String get longBreakStartWebHook {
    return Prefs().sharedPreferences.getString(_longBreakStartWebHookVarName) ??
        '';
  }

  static String get longBreakEndWebHook {
    return Prefs().sharedPreferences.getString(_longBreakEndWebHookVarName) ??
        '';
  }

  static String get startTimerWebHook {
    return Prefs().sharedPreferences.getString(_startTimerWebHookVarName) ?? '';
  }

  static String get stopTimerWebHook {
    return Prefs().sharedPreferences.getString(_stopTimerWebHookVarName) ?? '';
  }

  static String get resetTimerWebHook {
    return Prefs().sharedPreferences.getString(_resetTimerWebHookVarName) ?? '';
  }

  static String get tickWebHook {
    return Prefs().sharedPreferences.getString(_tickWebHookVarName) ?? '';
  }

  static int get lapCount {
    return Prefs().sharedPreferences.getInt(_lapCountVarName) ?? 4;
  }

  static bool get autoAdvance {
    return Prefs().sharedPreferences.getBool(_autoAdvanceVarName) ?? false;
  }

  static bool get alwaysOnTop {
    return Prefs().sharedPreferences.getBool(_alwaysOnTopVarName) ?? false;
  }

  static bool get enableWebhooks {
    return Prefs().sharedPreferences.getBool(_enableWebhooksVarName) ?? false;
  }

  static bool get enableSound {
    return Prefs().sharedPreferences.getBool(_enableSoundVarName) ?? true;
  }

  static TriggerMethod get triggerMethod {
    return TriggerMethod.values
            .where(
              (e) =>
                  e.toString() ==
                  (Prefs().sharedPreferences.getString(_triggerMethodVarName) ??
                      'TriggerMethod.post'),
            )
            .firstOrNull ??
        TriggerMethod.post;
  }

  static String get timerCustomFont {
    return Prefs().sharedPreferences.getString(_timerCustomFontVarName) ?? '';
  }

  static Color? get colorSeed {
    final val = Prefs().sharedPreferences.getInt(_colorSeedVarName);

    return val != null ? Color(val) : null;
  }

  static String get customShortBreakStartSound {
    return Prefs()
            .sharedPreferences
            .getString(_customShortBreakStartSoundVarName) ??
        '';
  }

  static String get customLongBreakStartSound {
    return Prefs()
            .sharedPreferences
            .getString(_customLongBreakStartSoundVarName) ??
        '';
  }

  static String get customWorkStartSound {
    return Prefs().sharedPreferences.getString(_customWorkStartSoundVarName) ??
        '';
  }

  static String get customShortBreakEndSound {
    return Prefs()
            .sharedPreferences
            .getString(_customShortBreakEndSoundVarName) ??
        '';
  }

  static String get customLongBreakEndSound {
    return Prefs()
            .sharedPreferences
            .getString(_customLongBreakEndSoundVarName) ??
        '';
  }

  static String get customWorkEndSound {
    return Prefs().sharedPreferences.getString(_customWorkEndSoundVarName) ??
        '';
  }

  static TimerStatus get timerStatus {
    return TimerStatus.values
        .elementAt(Prefs().sharedPreferences.getInt(_timerStatusVarName) ?? 1);
  }

  static int get lapNumber {
    return Prefs().sharedPreferences.getInt(_lapNumberVarName) ?? 0;
  }

  static Duration get duration {
    final storedVal = Prefs().sharedPreferences.getInt(_durationVarName) ?? 0;

    if (storedVal == 0) {
      return Duration.zero;
    }

    return Duration(seconds: storedVal);
  }

  static TimerLap get timerLap {
    final storedVal = Prefs().sharedPreferences.getInt(_timerLapVarName);

    return TimerLap.values[storedVal ?? 0];
  }

  static bool get showFloatingTimer {
    return Prefs().sharedPreferences.getBool(_showFloatingTimerVarName) ?? true;
  }

  static String get overlayCorner {
    return Prefs().sharedPreferences.getString(_overlayCornerVarName) ??
        'topRight';
  }

  static int get syncedMinutes {
    return Prefs().sharedPreferences.getInt(_syncedMinutesVarName) ?? 0;
  }

  static String? get activeLogPageId {
    return Prefs().sharedPreferences.getString(_activeLogPageIdVarName);
  }

  static List<String> get pendingTimeLogs {
    return Prefs().sharedPreferences.getStringList(_pendingTimeLogsVarName) ??
        <String>[];
  }

  //* Setters

  static set themeMode(ThemeMode value) {
    Prefs().sharedPreferences.setString(_themeModeVarName, value.name);
  }

  static set locale(Locale value) {
    Prefs().sharedPreferences.setString(_localeVarName, value.languageCode);
  }

  static set longBreakMinutes(int value) {
    Prefs().sharedPreferences.setInt(_longBreakMinutesVarName, value);
  }

  static set shortBreakMinutes(int value) {
    Prefs().sharedPreferences.setInt(_shortBreakMinutesVarName, value);
  }

  static set workMinutes(int value) {
    Prefs().sharedPreferences.setInt(_workMinutesVarName, value);
  }

  static set workStartWebHook(String value) {
    Prefs().sharedPreferences.setString(_workStartWebHookVarName, value);
  }

  static set workEndWebHook(String value) {
    Prefs().sharedPreferences.setString(_workEndWebHookVarName, value);
  }

  static set shortBreakStartWebHook(String value) {
    Prefs().sharedPreferences.setString(_shortBreakStartWebHookVarName, value);
  }

  static set shortBreakEndWebHook(String value) {
    Prefs().sharedPreferences.setString(_shortBreakEndWebHookVarName, value);
  }

  static set longBreakStartWebHook(String value) {
    Prefs().sharedPreferences.setString(_longBreakStartWebHookVarName, value);
  }

  static set longBreakEndWebHook(String value) {
    Prefs().sharedPreferences.setString(_longBreakEndWebHookVarName, value);
  }

  static set startTimerWebHook(String value) {
    Prefs().sharedPreferences.setString(_startTimerWebHookVarName, value);
  }

  static set stopTimerWebHook(String value) {
    Prefs().sharedPreferences.setString(_stopTimerWebHookVarName, value);
  }

  static set resetTimerWebHook(String value) {
    Prefs().sharedPreferences.setString(_resetTimerWebHookVarName, value);
  }

  static set tickWebHook(String value) {
    Prefs().sharedPreferences.setString(_tickWebHookVarName, value);
  }

  static set lapCount(int value) {
    Prefs().sharedPreferences.setInt(_lapCountVarName, value);
  }

  static set autoAdvance(bool value) {
    Prefs().sharedPreferences.setBool(_autoAdvanceVarName, value);
  }

  static set alwaysOnTop(bool value) {
    Prefs().sharedPreferences.setBool(_alwaysOnTopVarName, value);
  }

  static set enableWebhooks(bool value) {
    Prefs().sharedPreferences.setBool(_enableWebhooksVarName, value);
  }

  static set enableSound(bool value) {
    Prefs().sharedPreferences.setBool(_enableSoundVarName, value);
  }

  static set triggerMethod(TriggerMethod value) {
    Prefs()
        .sharedPreferences
        .setString(_triggerMethodVarName, value.toString());
  }

  static set timerFont(TimerFont value) {
    Prefs().sharedPreferences.setString(_timerFontVarName, value.name);
  }

  static set timerCustomFont(String value) {
    Prefs().sharedPreferences.setString(_timerCustomFontVarName, value);
  }

  static set colorSeed(Color? value) {
    if (value == null) {
      Prefs().sharedPreferences.remove(_colorSeedVarName);
      return;
    }

    Prefs().sharedPreferences.setInt(_colorSeedVarName, value.toARGB32());
  }

  static set customShortBreakStartSound(String value) {
    Prefs()
        .sharedPreferences
        .setString(_customShortBreakStartSoundVarName, value);
  }

  static set customLongBreakStartSound(String value) {
    Prefs()
        .sharedPreferences
        .setString(_customLongBreakStartSoundVarName, value);
  }

  static set customWorkStartSound(String value) {
    Prefs().sharedPreferences.setString(_customWorkStartSoundVarName, value);
  }

  static set customShortBreakEndSound(String value) {
    Prefs()
        .sharedPreferences
        .setString(_customShortBreakEndSoundVarName, value);
  }

  static set customLongBreakEndSound(String value) {
    Prefs().sharedPreferences.setString(_customLongBreakEndSoundVarName, value);
  }

  static set customWorkEndSound(String value) {
    Prefs().sharedPreferences.setString(_customWorkEndSoundVarName, value);
  }

  static set timerStatus(TimerStatus value) {
    Prefs().sharedPreferences.setInt(_timerStatusVarName, value.index);
  }

  static set lapNumber(int value) {
    Prefs().sharedPreferences.setInt(_lapNumberVarName, value);
  }

  static set timerLap(TimerLap value) {
    Prefs().sharedPreferences.setInt(_timerLapVarName, value.index);
  }

  static set duration(Duration value) {
    Prefs().sharedPreferences.setInt(_durationVarName, value.inSeconds);
  }

  static set showFloatingTimer(bool value) {
    Prefs().sharedPreferences.setBool(_showFloatingTimerVarName, value);
  }

  static set overlayCorner(String value) {
    Prefs().sharedPreferences.setString(_overlayCornerVarName, value);
  }

  static set notionApiKey(String value) {
    Prefs().sharedPreferences.setString(_notionApiKeyVarName, value);
  }

  static set enableNotionSync(bool value) {
    Prefs().sharedPreferences.setBool(_enableNotionSyncVarName, value);
  }

  static set enableTimeTracker(bool value) {
    Prefs().sharedPreferences.setBool(_enableTimeTrackerVarName, value);
  }

  static set quietHoursStart(String value) {
    Prefs().sharedPreferences.setString(_quietHoursStartVarName, value);
  }

  static set quietHoursEnd(String value) {
    Prefs().sharedPreferences.setString(_quietHoursEndVarName, value);
  }

  static set notionProxyUrl(String value) {
    Prefs().sharedPreferences.setString(_notionProxyUrlVarName, value);
  }

  static set notionDatabaseId(String value) {
    Prefs().sharedPreferences.setString(_notionDatabaseIdVarName, value);
  }

  static set activeTaskJson(String value) {
    Prefs().sharedPreferences.setString(_activeTaskJsonVarName, value);
  }

  static set activeTask(NotionTask? value) {
    if (value == null) {
      Prefs().sharedPreferences.remove(_activeTaskJsonVarName);
    } else {
      activeTaskJson = jsonEncode(value.toJson());
    }
  }

  static set syncedMinutes(int value) {
    Prefs().sharedPreferences.setInt(_syncedMinutesVarName, value);
  }

  static set activeLogPageId(String? value) {
    if (value == null || value.isEmpty) {
      Prefs().sharedPreferences.remove(_activeLogPageIdVarName);
    } else {
      Prefs().sharedPreferences.setString(_activeLogPageIdVarName, value);
    }
  }

  static set pendingTimeLogs(List<String> value) {
    Prefs().sharedPreferences.setStringList(_pendingTimeLogsVarName, value);
  }

  static List<TrackerTag> get trackerTags {
    final rawList =
        Prefs().sharedPreferences.getStringList(_trackerTagsVarName);
    if (rawList == null || rawList.isEmpty) {
      return TrackerTag.defaults;
    }
    return rawList
        .map((e) => TrackerTag.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  static set trackerTags(List<TrackerTag> value) {
    final encoded = value.map((e) => jsonEncode(e.toJson())).toList();
    Prefs().sharedPreferences.setStringList(_trackerTagsVarName, encoded);
  }

  static Future<void> saveTrackerTag(TrackerTag tag) async {
    final current = List<TrackerTag>.from(trackerTags);
    final idx = current.indexWhere((e) => e.id == tag.id);
    if (idx != -1) {
      current[idx] = tag;
    } else {
      current.add(tag);
    }
    trackerTags = current;
  }

  static Future<void> deleteTrackerTag(String tagId) async {
    final current = List<TrackerTag>.from(trackerTags);
    current.removeWhere((e) => e.id == tagId);
    trackerTags = current;
  }

  static List<HourlyLog> get hourlyLogs {
    final rawList =
        Prefs().sharedPreferences.getStringList(_hourlyLogsVarName) ?? [];
    return rawList
        .map((e) => HourlyLog.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  static set hourlyLogs(List<HourlyLog> value) {
    final encoded = value.map((e) => jsonEncode(e.toJson())).toList();
    Prefs().sharedPreferences.setStringList(_hourlyLogsVarName, encoded);
  }

  static Future<void> saveHourlyLog(HourlyLog log) async {
    final current = List<HourlyLog>.from(hourlyLogs);
    final idx = current.indexWhere((e) => e.id == log.id);
    if (idx != -1) {
      current[idx] = log;
    } else {
      current.add(log);
    }
    hourlyLogs = current;
  }

  static Future<void> replaceHourlyLogsForHour(
    String dateStr,
    int hour,
    List<HourlyLog> newLogs,
  ) async {
    final current = List<HourlyLog>.from(hourlyLogs)
      ..removeWhere((e) => e.dateStr == dateStr && e.hour == hour)
      ..addAll(newLogs);
    hourlyLogs = current;
  }

  static void resetTimer() {
    Prefs().sharedPreferences.remove(_timerStatusVarName);
    Prefs().sharedPreferences.remove(_durationVarName);
    Prefs().sharedPreferences.remove(_lapNumberVarName);
    Prefs().sharedPreferences.remove(_timerLapVarName);
    Prefs().sharedPreferences.remove(_syncedMinutesVarName);
    Prefs().sharedPreferences.remove(_activeLogPageIdVarName);
  }
}
