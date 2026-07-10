import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/session_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/singletons/prefs.dart';

/// Manages the small floating overlay window on macOS.
class FloatingOverlayController {
  FloatingOverlayController._();

  static final FloatingOverlayController instance =
      FloatingOverlayController._();

  static const _channel = MethodChannel('pomo/overlay');

  WindowController? _controller;
  bool _visible = false;

  static void initMainWindowHandler() {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'showMainWindow') {
        await DesktopWindowService.showMainWindow();
      }
      return null;
    });
  }

  Future<void> sync(TimerState state) async {
    if (kIsWeb || !Platform.isMacOS || !Prefs.showFloatingTimer) {
      if (_visible) {
        await _hide();
      }
      return;
    }

    final shouldShow = SessionHelper.isSessionActive(state);

    if (shouldShow && !_visible) {
      await _show();
    } else if (!shouldShow && _visible) {
      await _hide();
    }

    if (_visible) {
      final controller = _controller;
      if (controller != null) {
        final settings = SettingsState(
          workMinutes: Prefs.workMinutes,
          shortBreakMinutes: Prefs.shortBreakMinutes,
          longBreakMinutes: Prefs.longBreakMinutes,
          colorSeed: Prefs.colorSeed,
        );
        final time = DurationHelper.negativeFormat(
          duration: state.duration,
          lap: state.lap,
          settingsState: settings,
        );
        try {
          await DesktopMultiWindow.invokeMethod(
            controller.windowId,
            'updateTimer',
            {
              'time': time,
              'lap': state.lap.index,
              'status': state.status.index,
              'colorSeed': Prefs.colorSeed?.toARGB32(),
              'timerFont': Prefs.timerFont.name,
              'timerCustomFont': Prefs.timerCustomFont,
            },
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _show() async {
    try {
      _controller ??= await DesktopMultiWindow.createWindow(
        jsonEncode({'route': 'overlay'}),
      );

      await _channel.invokeMethod<void>('configureOverlayWindow', {
        'corner': Prefs.overlayCorner,
      });
      await _controller!.show();
      _visible = true;
    } catch (_) {
      _visible = false;
    }
  }

  Future<void> _hide() async {
    try {
      await _controller?.hide();
      await _channel.invokeMethod<void>('hideOverlay');
    } catch (_) {
      // Ignore overlay teardown errors.
    }

    _visible = false;
  }

  static Future<void> requestMainWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    try {
      await DesktopMultiWindow.invokeMethod(0, 'showMainWindow');
    } catch (_) {}

    try {
      await const MethodChannel('pomo/overlay')
          .invokeMethod<void>('showMainWindow');
    } catch (_) {}
  }
}
