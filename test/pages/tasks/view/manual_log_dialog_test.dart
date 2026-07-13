import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/l10n/l10n.dart';
import 'package:pomo/models/notion_task.dart';
import 'package:pomo/pages/tasks/view/manual_log_dialog.dart';

void main() {
  final testTask = NotionTask(
    id: 'test-id',
    title: 'Focus on Pomo App',
    status: 'In Progress',
  );

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(
        body: ManualLogDialog(task: testTask),
      ),
    );
  }

  group('ManualLogDialog', () {
    testWidgets('renders dialog correctly with task title and quick add chips',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Log Missed Time'), findsOneWidget);
      expect(find.text('Focus on Pomo App'), findsOneWidget);
      expect(find.text('+15m'), findsOneWidget);
      expect(find.text('+30m'), findsOneWidget);
      expect(find.text('+1h'), findsOneWidget);
      expect(find.text('+2h'), findsOneWidget);
    });

    testWidgets('updates hours and minutes when quick add chip is tapped',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Initial state is 1h 0m
      expect(find.text('1'), findsOneWidget); // hours

      // Tap +30m
      await tester.tap(find.text('+30m'));
      await tester.pump();

      expect(find.text('30'), findsOneWidget); // minutes
    });
  });
}
