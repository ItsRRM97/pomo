import 'package:flutter/foundation.dart';
import 'package:pomo/services/web_pwa_service.dart';

class WebPwaServiceStub implements WebPwaService {
  factory WebPwaServiceStub() => _instance;
  WebPwaServiceStub._internal();
  static final WebPwaServiceStub _instance = WebPwaServiceStub._internal();

  @override
  bool get isPipActive => false;

  @override
  void init() {}

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  void showNotification(String title, String body) {}

  @override
  bool isDocumentPipSupported() => false;

  @override
  Future<bool> openPip({
    required String initialTime,
    required bool isRunning,
    required VoidCallback onPauseToggle,
    required VoidCallback onSkip,
  }) async =>
      false;

  @override
  void updatePip(String timeStr, {required bool isRunning}) {}

  @override
  void closePip() {}

  @override
  Future<bool> triggerServiceWorkerNotification(
    String title,
    String body,
  ) async =>
      false;
}

WebPwaService getWebPwaService() => WebPwaServiceStub();
