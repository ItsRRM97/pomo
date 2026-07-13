import 'package:flutter/foundation.dart';
import 'web_pwa_service_stub.dart'
    if (dart.library.js_interop) 'web_pwa_service_web.dart';

abstract class WebPwaService {
  factory WebPwaService() => getWebPwaService();

  bool get isPipActive;
  void init();
  Future<bool> requestNotificationPermission();
  void showNotification(String title, String body);
  bool isDocumentPipSupported();
  Future<bool> openPip({
    required String initialTime,
    required bool isRunning,
    required VoidCallback onPauseToggle,
    required VoidCallback onSkip,
  });
  void updatePip(String timeStr, bool isRunning);
  void closePip();
}
