import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/android_background_prompt.dart';

void main() {
  group('AndroidBackgroundPrompt.shouldPrompt', () {
    test('is false off Android or when tracker is disabled', () {
      expect(
        AndroidBackgroundPrompt.shouldPrompt(
          isAndroid: false,
          trackerEnabled: true,
          ignoringBatteryOptimizations: false,
          notificationsEnabled: false,
        ),
        isFalse,
      );
      expect(
        AndroidBackgroundPrompt.shouldPrompt(
          isAndroid: true,
          trackerEnabled: false,
          ignoringBatteryOptimizations: false,
          notificationsEnabled: false,
        ),
        isFalse,
      );
    });

    test('is true when battery is optimized or notifications are off', () {
      expect(
        AndroidBackgroundPrompt.shouldPrompt(
          isAndroid: true,
          trackerEnabled: true,
          ignoringBatteryOptimizations: false,
          notificationsEnabled: true,
        ),
        isTrue,
      );
      expect(
        AndroidBackgroundPrompt.shouldPrompt(
          isAndroid: true,
          trackerEnabled: true,
          ignoringBatteryOptimizations: true,
          notificationsEnabled: false,
        ),
        isTrue,
      );
    });

    test('is false when both unrestricted and notifications granted', () {
      expect(
        AndroidBackgroundPrompt.shouldPrompt(
          isAndroid: true,
          trackerEnabled: true,
          ignoringBatteryOptimizations: true,
          notificationsEnabled: true,
        ),
        isFalse,
      );
    });

    test('is false after the user dismissed this session', () {
      expect(
        AndroidBackgroundPrompt.shouldPrompt(
          isAndroid: true,
          trackerEnabled: true,
          ignoringBatteryOptimizations: false,
          notificationsEnabled: false,
          dismissedThisSession: true,
        ),
        isFalse,
      );
    });
  });
}
