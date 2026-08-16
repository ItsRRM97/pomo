import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hourly channel uses a dedicated sound and bumped id', () {
    final src = File(
      'android/app/src/main/kotlin/com/recoskyler/pomo/TimerForegroundService.kt',
    ).readAsStringSync();
    expect(src, contains('hourly_tracker_v2'));
    expect(src, contains('setSound'));
    expect(src, contains('R.raw.digital_beep'));
  });

  test('HourlyAlarmReceiver holds a WakeLock and plays the chime', () {
    final src = File(
      'android/app/src/main/kotlin/com/recoskyler/pomo/HourlyAlarmReceiver.kt',
    ).readAsStringSync();
    expect(src, contains('PARTIAL_WAKE_LOCK'));
    expect(src, contains('MediaPlayer'));
    expect(src, contains('requestAudioFocus'));
  });

  test('raw digital_beep asset exists for the hourly channel', () {
    expect(
      File('android/app/src/main/res/raw/digital_beep.wav').existsSync(),
      isTrue,
    );
  });
}
