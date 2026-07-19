import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Registers / unregisters the app as a macOS login item.
class LaunchAtLoginService {
  LaunchAtLoginService._();

  static final LaunchAtLoginService instance = LaunchAtLoginService._();

  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (kIsWeb || !Platform.isMacOS || _configured) {
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      // Keep args empty; AppDelegate detects non-default (login) launches.
    );
    _configured = true;
  }

  Future<void> setEnabled({required bool enabled}) async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    try {
      await _ensureConfigured();
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      Logger().d('LaunchAtLoginService enabled=$enabled');
    } catch (e, s) {
      Logger().e(
        'LaunchAtLoginService.setEnabled failed',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<bool> isEnabled() async {
    if (kIsWeb || !Platform.isMacOS) {
      return false;
    }

    try {
      await _ensureConfigured();
      return await launchAtStartup.isEnabled();
    } catch (e) {
      Logger().w('LaunchAtLoginService.isEnabled failed: $e');
      return false;
    }
  }
}
