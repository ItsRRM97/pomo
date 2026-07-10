import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  static bool _iconReady = false;
  static bool _listenerAttached = false;
  TimerCubit? _timerCubit;
  bool? _menuIsRunning;
  bool? _menuSessionActive;

  static Future<void> init(BuildContext context) async {
    if (kIsWeb || !Platform.isMacOS || _iconReady) {
      return;
    }

    instance._timerCubit = context.read<TimerCubit>();

    try {
      await const MethodChannel('pomo/overlay')
          .invokeMethod<void>('ensureRegularActivation');
    } catch (error, stackTrace) {
      debugPrint(
        'MacosMenuBarService: ensureRegularActivation failed: $error',
      );
      debugPrint('$stackTrace');
    }

    try {
      // Use the 64x64 tray asset. The full pomo_logo.png is 4096x4096 (~5MB)
      // and exceeds the Flutter method channel payload when base64-encoded.
      await trayManager.setIcon(
        _trayIconAsset,
        iconSize: 22,
      );

      if (!_listenerAttached) {
        trayManager.addListener(instance);
        _listenerAttached = true;
      }

      await instance._syncMenuIfNeeded(force: true);
      _iconReady = true;
    } catch (error, stackTrace) {
      debugPrint('MacosMenuBarService.init failed: $error');
      debugPrint('$stackTrace');
    }
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
    final title = SessionHelper.isSessionActive(timerState) ? time : '';
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
