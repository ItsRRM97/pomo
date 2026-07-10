import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/app/view/app.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/duration_helper.dart';
import 'package:pomo/helpers/session_helper.dart';
import 'package:pomo/pages/settings/cubit/settings_cubit.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:tray_manager/tray_manager.dart';

class MacosMenuBarService with TrayListener {
  MacosMenuBarService._();

  static final MacosMenuBarService instance = MacosMenuBarService._();

  static const _trayIconAsset = 'assets/images/pomo_splash_64.png';
  static const _idleTrayTitle = 'Pomo';
  static const _maxTrayInitAttempts = 6;

  static bool _iconReady = false;
  static bool _listenerAttached = false;
  TimerCubit? _timerCubit;
  bool? _menuIsRunning;
  bool? _menuSessionActive;

  static Future<void> init(BuildContext context) async {
    if (kIsWeb || !Platform.isMacOS || _iconReady) {
      return;
    }

    try {
      await const MethodChannel('pomo/overlay')
          .invokeMethod<void>('ensureRegularActivation');
    } catch (error, stackTrace) {
      developer.log(
        'ensureRegularActivation failed: $error',
        name: 'MacosMenuBarService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      // Release builds can initialize faster than AppKit lays out status items.
      // Showing the tray synchronously on the first frame leaves a 0-height item.
      await _installTrayIconWithRetry();

      if (!_listenerAttached) {
        trayManager.addListener(instance);
        _listenerAttached = true;
      }

      _iconReady = true;
    } catch (error, stackTrace) {
      developer.log(
        'tray icon setup failed: $error',
        name: 'MacosMenuBarService',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    try {
      instance._timerCubit = context.read<TimerCubit>();
      await instance._syncMenuIfNeeded(force: true);
    } catch (error, stackTrace) {
      developer.log(
        'tray menu setup failed: $error',
        name: 'MacosMenuBarService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _installTrayIconWithRetry() async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt < _maxTrayInitAttempts; attempt++) {
      if (attempt == 0) {
        await Future<void>.delayed(Duration.zero);
        await SchedulerBinding.instance.endOfFrame;
      } else {
        await Future<void>.delayed(Duration(milliseconds: 80 * attempt));
      }

      try {
        // Use the 64x64 tray asset. The full pomo_logo.png is 4096x4096 (~5MB)
        // and exceeds the Flutter method channel payload when base64-encoded.
        await trayManager.setIcon(
          _trayIconAsset,
          iconSize: 22,
        );
        await trayManager.setTitle(_idleTrayTitle);
        await trayManager.setToolTip('Pomo - Pomodoro timer');

        final bounds = await trayManager.getBounds();
        if (bounds != null && bounds.width > 0) {
          return;
        }
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    Error.throwWithStackTrace(
      lastError ?? StateError('Tray icon never received valid bounds'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  static void attachContext(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    instance._timerCubit = context.read<TimerCubit>();
  }

  Future<void> updateFromState({
    required TimerState timerState,
    required SettingsState settingsState,
  }) async {
    if (kIsWeb || !Platform.isMacOS || !_iconReady) {
      return;
    }

    final tooltip = _tooltip(timerState, settingsState);
    await trayManager.setToolTip(tooltip);

    final time = DurationHelper.negativeFormat(
      duration: timerState.duration,
      lap: timerState.lap,
      settingsState: settingsState,
    );
    final title =
        SessionHelper.isSessionActive(timerState) ? time : _idleTrayTitle;
    await trayManager.setTitle(title);

    await _syncMenuIfNeeded(timerState: timerState);
  }

  String _tooltip(TimerState timerState, SettingsState settingsState) {
    if (!SessionHelper.isSessionActive(timerState)) {
      return 'Pomo - Pomodoro timer';
    }

    final time = DurationHelper.negativeFormat(
      duration: timerState.duration,
      lap: timerState.lap,
      settingsState: settingsState,
    );
    final emoji = _lapEmoji(timerState.lap);
    final status =
        timerState.status == TimerStatus.running ? 'Running' : 'Paused';

    return '$emoji $time ($status)';
  }

  String _lapEmoji(TimerLap lap) {
    switch (lap) {
      case TimerLap.work:
        return '💼';
      case TimerLap.shortBreak:
        return '☕';
      case TimerLap.longBreak:
        return '🏖';
    }
  }

  Future<void> _syncMenuIfNeeded({
    TimerState? timerState,
    bool force = false,
  }) async {
    final timerCubit = _timerCubit;
    if (timerCubit == null) {
      return;
    }

    final state = timerState ?? timerCubit.state;
    final isRunning = state.status == TimerStatus.running;
    final sessionActive = SessionHelper.isSessionActive(state);

    if (!force &&
        _menuIsRunning == isRunning &&
        _menuSessionActive == sessionActive) {
      return;
    }

    _menuIsRunning = isRunning;
    _menuSessionActive = sessionActive;

    final menu = Menu(
      items: [
        MenuItem(
          key: 'toggle',
          label: isRunning ? 'Pause timer' : 'Start timer',
        ),
        MenuItem(
          key: 'reset',
          label: 'Reset',
          disabled: !sessionActive,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'open',
          label: 'Open Pomo',
        ),
        MenuItem(
          key: 'settings',
          label: 'Settings',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'Quit',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_popUpContextMenu());
  }

  Future<void> _popUpContextMenu() async {
    await _syncMenuIfNeeded(force: _menuIsRunning == null);
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(DesktopWindowService.showMainWindow());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final timerCubit = _timerCubit;
    if (timerCubit == null) {
      return;
    }

    switch (menuItem.key) {
      case 'toggle':
        timerCubit.toggle();
      case 'reset':
        timerCubit.reset();
      case 'open':
        unawaited(DesktopWindowService.showMainWindow());
      case 'settings':
        unawaited(DesktopWindowService.showMainWindow());
        App.navigatorKey.currentState?.pushNamed('/settings');
      case 'quit':
        unawaited(DesktopWindowService.quit());
    }
  }
}
