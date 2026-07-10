import 'dart:io';

import 'package:flutter/foundation.dart';
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

  static bool _initialized = false;
  BuildContext? _context;

  static Future<void> init(BuildContext context) async {
    if (kIsWeb || !Platform.isMacOS || _initialized) {
      return;
    }

    _initialized = true;
    instance._context = context;

    await trayManager.setIcon('assets/images/pomo_logo.png');
    trayManager.addListener(instance);
    await instance._rebuildMenu();
  }

  static void attachContext(BuildContext context) {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    instance._context = context;
  }

  Future<void> updateFromState({
    required TimerState timerState,
    required SettingsState settingsState,
  }) async {
    if (kIsWeb || !Platform.isMacOS) {
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

    await _rebuildMenu(timerState: timerState);
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

  Future<void> _rebuildMenu({TimerState? timerState}) async {
    final context = _context;
    if (context == null || !context.mounted) {
      return;
    }

    final state = timerState ?? context.read<TimerCubit>().state;
    final isRunning = state.status == TimerStatus.running;
    final sessionActive = SessionHelper.isSessionActive(state);

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
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    DesktopWindowService.showMainWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final context = _context;
    if (context == null || !context.mounted) {
      return;
    }

    switch (menuItem.key) {
      case 'toggle':
        context.read<TimerCubit>().toggle();
      case 'reset':
        context.read<TimerCubit>().reset();
      case 'open':
        DesktopWindowService.showMainWindow();
      case 'settings':
        DesktopWindowService.showMainWindow();
        App.navigatorKey.currentState?.pushNamed('/settings');
      case 'quit':
        DesktopWindowService.quit();
    }
  }
}
