import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:pomo/desktop/desktop_window_service.dart';
import 'package:pomo/helpers/notification_helper.dart';
import 'package:pomo/services/app_navigation_controller.dart';

/// macOS local notifications via flutter_local_notifications.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1000;

  static const int hourlyNotificationId = 1;
  static const DarwinNotificationDetails _macDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    // Required for foreground banners on macOS 11+; presentAlert only
    // covers macOS 10.14 through 11.
    presentBanner: true,
    presentList: true,
  );

  Future<void> init() async {
    if (kIsWeb || !Platform.isMacOS || _initialized) {
      return;
    }

    const initSettings = InitializationSettings(
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response != null) {
        // Defer until the widget tree is ready.
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          _handlePayload(response.payload);
        });
      }
    }

    _initialized = true;
    Logger().d('LocalNotificationService initialized');
  }

  Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isMacOS) {
      return false;
    }

    await init();
    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final granted = await mac?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
    Logger().d('LocalNotificationService permission granted=$granted');
    return granted;
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (kIsWeb || !Platform.isMacOS) {
      return;
    }

    await init();
    final notificationId = id ?? _nextId++;
    try {
      await _plugin.show(
        notificationId,
        title,
        body,
        const NotificationDetails(macOS: _macDetails),
        payload: payload,
      );
    } catch (e, s) {
      Logger().e(
        'LocalNotificationService.show failed',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> showHourlyReminder({
    required int hour,
    required DateTime date,
  }) async {
    await show(
      id: hourlyNotificationId,
      title: NotificationHelper.hourlyNotificationTitle(),
      body: NotificationHelper.hourlyNotificationBody(hour),
      payload: NotificationHelper.hourlyPayload(hour: hour, date: date),
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  Future<void> _handlePayload(String? payload) async {
    final action = NotificationHelper.parsePayload(payload);
    if (action == null) {
      return;
    }

    try {
      await DesktopWindowService.showMainWindow();
    } catch (e) {
      Logger().w('LocalNotificationService: showMainWindow failed: $e');
    }

    await AppNavigationController.instance.handleNotificationAction(action);
  }
}
