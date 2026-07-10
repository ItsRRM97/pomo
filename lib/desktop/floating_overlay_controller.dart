import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/session_helper.dart';
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

    await DesktopMultiWindow.invokeMethod(0, 'showMainWindow');
  }
}
