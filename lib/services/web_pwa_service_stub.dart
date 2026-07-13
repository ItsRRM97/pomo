import 'package:flutter/foundation.dart';
import 'web_pwa_service.dart';

class WebPwaServiceStub implements WebPwaService {
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
  void updatePip(String timeStr, bool isRunning) {}

  @override
  void closePip() {}
}

WebPwaService getWebPwaService() => WebPwaServiceStub();
