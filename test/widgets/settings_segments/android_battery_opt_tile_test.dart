import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomo/widgets/settings_segments/android_battery_opt_tile.dart';

void main() {
  const channel = MethodChannel('com.recoskyler.pomo/timer_notification');

  late List<String> channelCalls;
  late bool ignoringStatus;

  setUp(() {
    channelCalls = [];
    ignoringStatus = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      channelCalls.add(call.method);
      if (call.method == 'isIgnoringBatteryOptimizations') {
        return ignoringStatus;
      }
      if (call.method == 'requestIgnoreBatteryOptimizations') {
        ignoringStatus = true;
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<bool> fetchIgnoringStatus() async {
    final result =
        await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? false;
  }

  Future<bool> requestIgnore() async {
    final result =
        await channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    return result ?? false;
  }

  testWidgets('shows status and requests ignore on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AndroidBatteryOptTile(
            isAndroidOverride: true,
            isIgnoringBatteryOptimizations: fetchIgnoringStatus,
            requestIgnoreBatteryOptimizations: requestIgnore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('battery'), findsOneWidget);
    expect(find.textContaining('Not optimized'), findsOneWidget);
    expect(
      channelCalls.where((call) => call == 'isIgnoringBatteryOptimizations'),
      hasLength(1),
    );
    expect(channelCalls.contains('requestIgnoreBatteryOptimizations'), isFalse);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(channelCalls.contains('requestIgnoreBatteryOptimizations'), isTrue);
    expect(
      channelCalls.where((call) => call == 'isIgnoringBatteryOptimizations'),
      hasLength(2),
    );
    expect(find.textContaining('Allowed'), findsOneWidget);
    expect(find.textContaining('Not optimized'), findsNothing);
  });
}
