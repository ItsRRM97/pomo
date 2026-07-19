import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pomo/singletons/prefs.dart';
import 'package:window_manager/window_manager.dart';

/// Handles main-window lifecycle on macOS: hide to menu bar instead of quit.
class DesktopWindowService with WindowListener {
  DesktopWindowService._();

  static final DesktopWindowService instance = DesktopWindowService._();
  static bool _initialized = false;
  static const MethodChannel _overlayChannel = MethodChannel('pomo/overlay');

  static Future<void> init() async {
    if (kIsWeb || !Platform.isMacOS || _initialized) {
      return;
    }

    _initialized = true;
    await windowManager.setPreventClose(true);
    windowManager.addListener(instance);
  }

  /// Whether AppDelegate decided this launch should stay menu-bar only.
  static Future<bool> shouldStartHidden() async {
    if (kIsWeb || !Platform.isMacOS) {
      return false;
    }

    try {
      final result =
          await _overlayChannel.invokeMethod<bool>('shouldStartHidden');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAccessoryActivation() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    try {
      await _overlayChannel.invokeMethod<void>('setAccessoryActivation');
    } catch (_) {}
  }

  static Future<void> showMainWindow() async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    try {
      await _overlayChannel.invokeMethod<void>('ensureRegularActivation');
      await _overlayChannel.invokeMethod<void>('showMainWindow');
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

  @override
  void onWindowResized() {
    // Remember the size the user chose so the next launch restores it.
    windowManager.getSize().then((size) => Prefs.windowSize = size);
  }
}
