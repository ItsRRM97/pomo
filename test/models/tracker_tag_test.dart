import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/models/tracker_tag.dart';

void main() {
  group('TrackerTag', () {
    test('supports value equality', () {
      const tagA = TrackerTag(
        id: 'tag_1',
        name: 'Coding',
        icon: '💻',
        colorHex: '#4285F4',
        isDefault: true,
      );
      const tagB = TrackerTag(
        id: 'tag_1',
        name: 'Coding',
        icon: '💻',
        colorHex: '#4285F4',
        isDefault: true,
      );
      expect(tagA, equals(tagB));
    });

    test('toJson and fromJson correctly serialize and deserialize', () {
      const tag = TrackerTag(
        id: 'tag_custom_1',
        name: 'Reading',
        icon: '📚',
        colorHex: '#34A853',
      );

      final json = tag.toJson();
      final fromJsonTag = TrackerTag.fromJson(json);

      expect(fromJsonTag, equals(tag));
    });

    test('defaults contains predefined categories', () {
      expect(TrackerTag.defaults, isNotEmpty);
      expect(
        TrackerTag.defaults.any((tag) => tag.id == 'tag_coding'),
        isTrue,
      );
    });
  });
}
