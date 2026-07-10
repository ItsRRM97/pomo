// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get pomo => 'Pomo';

  @override
  String get title => 'Pomo';

  @override
  String lap(num lap) {
    return 'Lap #$lap';
  }

  @override
  String shortBreak(num lap) {
    return 'Short break #$lap';
  }

  @override
  String get longBreak => 'Long break';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String workDuration(num minutes) {
    return 'Work duration ($minutes minutes)';
  }

  @override
  String shortBreakDuration(num minutes) {
    return 'Short break duration ($minutes minutes)';
  }

  @override
  String longBreakDuration(num minutes) {
    return 'Long break duration ($minutes minutes)';
  }

  @override
  String lapCount(num count) {
    return 'Lap count ($count work laps)';
  }

  @override
  String get autoAdvance => 'Auto advance';

  @override
  String get alwaysOnTop => 'Always on top';

  @override
  String get startWorkWebHookUrl => 'Start work webhook URL';

  @override
  String get startShortBreakWebHookUrl => 'Start short break webhook URL';

  @override
  String get startLongBreakWebHookUrl => 'Start long break webhook URL';

  @override
  String get endWorkWebHookUrl => 'End work webhook URL';

  @override
  String get endShortBreakWebHookUrl => 'End short break webhook URL';

  @override
  String get endLongBreakWebHookUrl => 'End long break webhook URL';

  @override
  String get startTimerWebHookUrl => 'Start timer webhook URL';

  @override
  String get stopTimerWebHookUrl => 'Stop timer webhook URL';

  @override
  String get resetTimerWebHookUrl => 'Reset timer webhook URL';

  @override
  String get stateChangeWebHookUrl => 'State change webhook URL';

  @override
  String get tickWebHookUrl => 'Timer tick webhook URL';

  @override
  String get language => 'Language';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get english => 'English';

  @override
  String get requiresRestart => 'Requires restart';

  @override
  String get webhooks => 'Webhooks';

  @override
  String get enableWebhooks => 'Enable Webhooks';

  @override
  String get toggleSound => 'Toggle sound';

  @override
  String get startTimer => 'Start timer';

  @override
  String get pauseTimer => 'Pause timer';

  @override
  String get reset => 'Reset';

  @override
  String get skipLap => 'Skip lap';

  @override
  String get triggerMethod => 'Trigger method';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get madeBy1 => 'Made by ';

  @override
  String get madeBy2 => ' - 2024';

  @override
  String get timer => 'Timer';

  @override
  String get autoAdvanceDescription =>
      'Automatically advance to the next lap after the current lap is over';

  @override
  String get webhooksDescription =>
      'Send a webhook request when the timer state changes. You can trigger multiple webhooks for the same event if you separate the URLs with a comma (,)';

  @override
  String get timerFont => 'Timer font';

  @override
  String get bold => 'Bold';

  @override
  String get regular => 'Regular';

  @override
  String get mono => 'Monospace';

  @override
  String get boldMono => 'Bold monospace';

  @override
  String get fancyMono => 'Fancy monospace';

  @override
  String get custom => 'Custom';

  @override
  String get customFontName => 'Custom font name';

  @override
  String get workEndSound => 'Work end sound';

  @override
  String get shortBreakEndSound => 'Short break end sound';

  @override
  String get longBreakEndSound => 'Long break end sound';

  @override
  String get workStartSound => 'Work start sound';

  @override
  String get shortBreakStartSound => 'Short break start sound';

  @override
  String get longBreakStartSound => 'Long break start sound';

  @override
  String get customSounds => 'Custom sounds';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get sourceCode => 'Source code';

  @override
  String timerTitle(String time, String stoppedEmoji) {
    return '$time $stoppedEmoji | Pomo - Pomodoro timer';
  }
}
