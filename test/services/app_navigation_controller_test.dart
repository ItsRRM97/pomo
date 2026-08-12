import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/services/app_navigation_controller.dart';

void main() {
  group('AppNavigationController.handleNotificationAction', () {
    tearDown(() {
      AppNavigationController.instance.tabIndex.value = null;
    });

    test('OpenTrackerAction sets tabIndex to 1 only', () async {
      await AppNavigationController.instance.handleNotificationAction(
        const OpenTrackerAction(),
      );
      expect(AppNavigationController.instance.tabIndex.value, 1);
    });

    test('FocusMainWindowAction sets tabIndex to 0', () async {
      await AppNavigationController.instance.handleNotificationAction(
        const FocusMainWindowAction(),
      );
      expect(AppNavigationController.instance.tabIndex.value, 0);
    });
  });
}
