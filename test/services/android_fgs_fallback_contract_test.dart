import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final serviceFile = File(
    'android/app/src/main/kotlin/com/recoskyler/pomo/TimerForegroundService.kt',
  );

  test('D5 fallback notification includes Play/Pause and Stop actions', () {
    final src = serviceFile.readAsStringSync();
    final start = src.indexOf('fun postTimerFallbackNotification');
    final end = src.indexOf('private fun pendingHourlyAction');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final fallback = src.substring(start, end);
    expect(fallback, contains('addAction'));
    expect(fallback, contains('"Stop"'));
    expect(
      fallback.contains('"Pause"') || fallback.contains('"Play"'),
      isTrue,
    );
    expect(fallback, contains('PendingIntent.getService'));
  });
}
