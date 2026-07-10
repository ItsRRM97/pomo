import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Handles main-window lifecycle on macOS: hide to menu bar instead of quit.
class DesktopWindowService with WindowListener {
  DesktopWindowService._();

  static final DesktopWindowService instance = DesktopWindowService._();
  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || !Platform.isMacOS || _initialized) {
      return;
    }

    _initialized = true;
    await windowManager.setPreventClose(true);
    windowManager.addListener(instance);
  }

  static Future<void> showMainWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    try {
      await const MethodChannel('pomo/overlay')
          .invokeMethod<void>('showMainWindow');
    } catch (_) {}

    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> hideMainWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    await windowManager.hide();
  }

  static Future<void> quit() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    await windowManager.destroy();
    exit(0);
  }

  @override
  void onWindowClose() {
    hideMainWindow();
  }
}
