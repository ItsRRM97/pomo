import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/tracker/view/hourly_tracker_view.dart';
import 'package:pomo/pages/tracker/view/missed_tracking_view.dart';
import 'package:pomo/pages/tracker/view/tracker_shell_page.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().init();
  });

  Future<void> pumpAtPhoneWidth(
    WidgetTester tester,
    Widget home,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('HourlyTrackerView does not overflow at 390 dp width',
      (tester) async {
    await pumpAtPhoneWidth(
      tester,
      const Scaffold(body: HourlyTrackerView()),
    );

    expect(find.byType(HourlyTrackerView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TrackerShellPage missed tab does not overflow at 390 dp',
      (tester) async {
    await pumpAtPhoneWidth(tester, const TrackerShellPage());

    await tester.tap(find.text('Missed Hours Check'));
    await tester.pumpAndSettle();

    expect(find.byType(MissedTrackingView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
