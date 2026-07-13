import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/pages/tracker/view/hourly_tracker_view.dart';
import 'package:pomo/pages/tracker/view/missed_tracking_view.dart';
import 'package:pomo/pages/tracker/view/tracker_shell_page.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TrackerShellPage', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    testWidgets('renders both tabs and switches views', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrackerShellPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hourly Time Tracker'), findsOneWidget);
      expect(find.text('Activity Grid & Analytics'), findsOneWidget);
      expect(find.text('Missed Hours Check'), findsOneWidget);

      expect(find.byType(HourlyTrackerView), findsOneWidget);

      await tester.tap(find.text('Missed Hours Check'));
      await tester.pumpAndSettle();

      expect(find.byType(MissedTrackingView), findsOneWidget);
    });
  });
}
