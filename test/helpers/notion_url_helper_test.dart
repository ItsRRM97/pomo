import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/notion_url_helper.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotionUrlHelper', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().init();
    });

    test('hourlyTimelineDatabaseUrl is empty when DB id unset', () {
      Prefs.notionHourlyTimelineDatabaseId = '';
      expect(NotionUrlHelper.hasHourlyTimelineDatabaseId, isFalse);
      expect(NotionUrlHelper.hourlyTimelineDatabaseUrl, isEmpty);
    });

    test('hourlyTimelineDatabaseUrl strips dashes from UUID', () {
      Prefs.notionHourlyTimelineDatabaseId =
          '39d3dffe-a139-8190-9176-d98e3475c5ec';
      expect(NotionUrlHelper.hasHourlyTimelineDatabaseId, isTrue);
      expect(
        NotionUrlHelper.hourlyTimelineDatabaseUrl,
        'https://www.notion.so/39d3dffea13981909176d98e3475c5ec',
      );
    });

    test('hourlyTimelineDatabaseUrl trims whitespace', () {
      Prefs.notionHourlyTimelineDatabaseId =
          '  39d3dffea13981909176d98e3475c5ec  ';
      expect(
        NotionUrlHelper.hourlyTimelineDatabaseUrl,
        'https://www.notion.so/39d3dffea13981909176d98e3475c5ec',
      );
    });
  });
}
