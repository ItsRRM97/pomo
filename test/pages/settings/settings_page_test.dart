import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/settings/view/settings_page.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:pomo/widgets/settings_segments/settings_segments.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
  });

  tearDown(() {
    Prefs.enableTimeTracker = false;
    Prefs.enableNotionSync = false;
    Prefs.notionApiKey = '';
    Prefs.notionProxyUrl = '';
    Prefs.pendingTimeLogs = [];
  });

  testWidgets('SettingsPage renders TimeTrackerToggle and TimeTrackerExpansion',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => SettingsCubit()),
            BlocProvider(create: (_) => TimerCubit()),
          ],
          child: const Scaffold(body: SettingsPage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TimeTrackerToggle), findsOneWidget);
    expect(find.byType(TimeTrackerExpansion), findsOneWidget);
    expect(find.text('Time Tracker & Automation'), findsOneWidget);
  });
}
