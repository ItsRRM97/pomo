import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @pomo.
  ///
  /// In en, this message translates to:
  /// **'Pomo'**
  String get pomo;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Pomo'**
  String get title;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap #{lap}'**
  String lap(num lap);

  /// No description provided for @shortBreak.
  ///
  /// In en, this message translates to:
  /// **'Short break #{lap}'**
  String shortBreak(num lap);

  /// No description provided for @longBreak.
  ///
  /// In en, this message translates to:
  /// **'Long break'**
  String get longBreak;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @workDuration.
  ///
  /// In en, this message translates to:
  /// **'Work duration ({minutes} minutes)'**
  String workDuration(num minutes);

  /// No description provided for @shortBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Short break duration ({minutes} minutes)'**
  String shortBreakDuration(num minutes);

  /// No description provided for @longBreakDuration.
  ///
  /// In en, this message translates to:
  /// **'Long break duration ({minutes} minutes)'**
  String longBreakDuration(num minutes);

  /// No description provided for @lapCount.
  ///
  /// In en, this message translates to:
  /// **'Lap count ({count} work laps)'**
  String lapCount(num count);

  /// No description provided for @autoAdvance.
  ///
  /// In en, this message translates to:
  /// **'Auto advance'**
  String get autoAdvance;

  /// No description provided for @alwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get alwaysOnTop;

  /// No description provided for @startWorkWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start work webhook URL'**
  String get startWorkWebHookUrl;

  /// No description provided for @startShortBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start short break webhook URL'**
  String get startShortBreakWebHookUrl;

  /// No description provided for @startLongBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start long break webhook URL'**
  String get startLongBreakWebHookUrl;

  /// No description provided for @endWorkWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'End work webhook URL'**
  String get endWorkWebHookUrl;

  /// No description provided for @endShortBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'End short break webhook URL'**
  String get endShortBreakWebHookUrl;

  /// No description provided for @endLongBreakWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'End long break webhook URL'**
  String get endLongBreakWebHookUrl;

  /// No description provided for @startTimerWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Start timer webhook URL'**
  String get startTimerWebHookUrl;

  /// No description provided for @stopTimerWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Stop timer webhook URL'**
  String get stopTimerWebHookUrl;

  /// No description provided for @resetTimerWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Reset timer webhook URL'**
  String get resetTimerWebHookUrl;

  /// No description provided for @stateChangeWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'State change webhook URL'**
  String get stateChangeWebHookUrl;

  /// No description provided for @tickWebHookUrl.
  ///
  /// In en, this message translates to:
  /// **'Timer tick webhook URL'**
  String get tickWebHookUrl;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @requiresRestart.
  ///
  /// In en, this message translates to:
  /// **'Requires restart'**
  String get requiresRestart;

  /// No description provided for @webhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get webhooks;

  /// No description provided for @enableWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Enable Webhooks'**
  String get enableWebhooks;

  /// No description provided for @toggleSound.
  ///
  /// In en, this message translates to:
  /// **'Toggle sound'**
  String get toggleSound;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get startTimer;

  /// No description provided for @pauseTimer.
  ///
  /// In en, this message translates to:
  /// **'Pause timer'**
  String get pauseTimer;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @skipLap.
  ///
  /// In en, this message translates to:
  /// **'Skip lap'**
  String get skipLap;

  /// No description provided for @triggerMethod.
  ///
  /// In en, this message translates to:
  /// **'Trigger method'**
  String get triggerMethod;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @madeBy1.
  ///
  /// In en, this message translates to:
  /// **'Made by '**
  String get madeBy1;

  /// No description provided for @madeBy2.
  ///
  /// In en, this message translates to:
  /// **' - 2024'**
  String get madeBy2;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @autoAdvanceDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically advance to the next lap after the current lap is over'**
  String get autoAdvanceDescription;

  /// No description provided for @webhooksDescription.
  ///
  /// In en, this message translates to:
  /// **'Send a webhook request when the timer state changes. You can trigger multiple webhooks for the same event if you separate the URLs with a comma (,)'**
  String get webhooksDescription;

  /// No description provided for @timerFont.
  ///
  /// In en, this message translates to:
  /// **'Timer font'**
  String get timerFont;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get regular;

  /// No description provided for @mono.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get mono;

  /// No description provided for @boldMono.
  ///
  /// In en, this message translates to:
  /// **'Bold monospace'**
  String get boldMono;

  /// No description provided for @fancyMono.
  ///
  /// In en, this message translates to:
  /// **'Fancy monospace'**
  String get fancyMono;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customFontName.
  ///
  /// In en, this message translates to:
  /// **'Custom font name'**
  String get customFontName;

  /// No description provided for @workEndSound.
  ///
  /// In en, this message translates to:
  /// **'Work end sound'**
  String get workEndSound;

  /// No description provided for @shortBreakEndSound.
  ///
  /// In en, this message translates to:
  /// **'Short break end sound'**
  String get shortBreakEndSound;

  /// No description provided for @longBreakEndSound.
  ///
  /// In en, this message translates to:
  /// **'Long break end sound'**
  String get longBreakEndSound;

  /// No description provided for @workStartSound.
  ///
  /// In en, this message translates to:
  /// **'Work start sound'**
  String get workStartSound;

  /// No description provided for @shortBreakStartSound.
  ///
  /// In en, this message translates to:
  /// **'Short break start sound'**
  String get shortBreakStartSound;

  /// No description provided for @longBreakStartSound.
  ///
  /// In en, this message translates to:
  /// **'Long break start sound'**
  String get longBreakStartSound;

  /// No description provided for @customSounds.
  ///
  /// In en, this message translates to:
  /// **'Custom sounds'**
  String get customSounds;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'{time} {stoppedEmoji} | Pomo - Pomodoro timer'**
  String timerTitle(String time, String stoppedEmoji);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
