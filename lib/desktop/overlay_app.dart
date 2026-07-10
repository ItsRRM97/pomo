import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pomo/desktop/floating_overlay_controller.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/lap_color_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:window_manager/window_manager.dart';

/// Minimal Flutter UI for the floating overlay sub-window.
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  late Timer _timer;
  String _time = '00:00';
  TimerLap _lap = TimerLap.work;
  TimerStatus _status = TimerStatus.stopped;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _initWindow();
  }

  Future<void> _initWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(148, 52),
      minimumSize: Size(148, 52),
      maximumSize: Size(148, 52),
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
    });
  }

  void _refresh() {
    final settings = SettingsState(
      workMinutes: Prefs.workMinutes,
      shortBreakMinutes: Prefs.shortBreakMinutes,
      longBreakMinutes: Prefs.longBreakMinutes,
      colorSeed: Prefs.colorSeed,
    );

    final lap = Prefs.timerLap;
    final status = Prefs.timerStatus;
    final duration = Prefs.duration;

    setState(() {
      _lap = lap;
      _status = status;
      _time = DurationHelper.negativeFormat(
        duration: duration,
        lap: lap,
        settingsState: settings,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final lapColor = LapColorHelper.lapColor(
      lap: _lap,
      status: _status,
      colorSeed: Prefs.colorSeed,
      brightness: brightness,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: FloatingOverlayController.requestMainWindow,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: brightness == Brightness.dark
                    ? const Color(0xE61C1C1E)
                    : const Color(0xE6F5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: lapColor.withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: lapColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _time,
                      style: const TextStyle(
                        fontFamily: 'Major Mono Display',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
