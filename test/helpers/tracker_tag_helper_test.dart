import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/tracker_tag_helper.dart';
import 'package:pomo/models/tracker_tag.dart';

void main() {
  group('TrackerTagHelper', () {
    test('normalizeName trims and lowercases', () {
      expect(TrackerTagHelper.normalizeName('  Deep Work  '), 'deep work');
    });

    test('findDuplicate matches ignoring case and spaces', () {
      const existing = TrackerTag(
        id: 'tag_deep_work',
        name: 'Deep Work',
        icon: '🧠',
        colorHex: '#34A853',
        isDefault: true,
      );
      expect(
        TrackerTagHelper.findDuplicate(
          'deep work',
          existing: [existing],
        ),
        existing,
      );
      expect(
        TrackerTagHelper.findDuplicate(
          'Coding',
          existing: [existing],
        ),
        isNull,
      );
    });
  });
}
