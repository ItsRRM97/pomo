import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:pomo/services/web_pwa_service.dart';

@JS('window.pwaManager')
external JSObject? get pwaManager;

@JS()
@staticInterop
class PwaManager {}

extension PwaManagerExtension on PwaManager {
  @JS('requestNotificationPermission')
  external JSPromise<JSBoolean> requestNotificationPermission();

  @JS('showNotification')
  external void showNotification(JSString title, JSString body);

  @JS('isDocumentPipSupported')
  external JSBoolean isDocumentPipSupported();

  @JS('openDocumentPip')
  external JSPromise<JSBoolean> openDocumentPip(
    JSString initialTime,
    JSBoolean isRunning,
    JSFunction onPauseToggle,
    JSFunction onSkip,
  );

  @JS('updatePip')
  external void updatePip(JSString timeStr, JSBoolean isRunning);

  @JS('closePip')
  external void closePip();
}

@JS('window.pwaManager.onPipClosedExternally')
external set jsOnPipClosedExternally(JSFunction? val);

@JS('window.pwaManager.showCustomNotification')
external JSPromise<JSBoolean> showCustomNotification(
  JSString title,
  JSString body,
);

class WebPwaServiceWeb implements WebPwaService {
  factory WebPwaServiceWeb() => _instance;
  WebPwaServiceWeb._internal();
  static final WebPwaServiceWeb _instance = WebPwaServiceWeb._internal();

  bool _isPipActive = false;

  @override
  bool get isPipActive => _isPipActive;

  @override
  void init() {}

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      if (pwaManager != null) {
        final result = await (pwaManager! as PwaManager)
            .requestNotificationPermission()
            .toDart;
        return result.toDart;
      }
    } catch (_) {}
    return false;
  }

  @override
  void showNotification(String title, String body) {
    try {
      final manager = pwaManager;
      if (manager == null) {
        _jsConsoleLog('[Focus] showNotification: pwaManager is null'.toJS);
        return;
      }
      _jsConsoleLog('[Focus] showNotification: calling JS -> $title'.toJS);
      (manager as PwaManager).showNotification(title.toJS, body.toJS);
    } catch (e) {
      _jsConsoleLog('[Focus] showNotification error: $e'.toJS);
    }
  }

  @override
  Future<bool> triggerServiceWorkerNotification(
    String title,
    String body,
  ) async {
    try {
      if (pwaManager == null) {
        _jsConsoleLog(
          '[Focus] triggerServiceWorkerNotification: pwaManager is null'.toJS,
        );
        return false;
      }
      _jsConsoleLog(
        '[Focus] triggerServiceWorkerNotification: calling JS -> $title'.toJS,
      );
      final result = await showCustomNotification(title.toJS, body.toJS).toDart;
      return result.toDart;
    } catch (e) {
      _jsConsoleLog('[Focus] triggerServiceWorkerNotification error: $e'.toJS);
      return false;
    }
  }

  @override
  bool isDocumentPipSupported() {
    try {
      final manager = pwaManager;
      if (manager != null) {
        return (manager as PwaManager).isDocumentPipSupported().toDart;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> openPip({
    required String initialTime,
    required bool isRunning,
    required VoidCallback onPauseToggle,
    required VoidCallback onSkip,
  }) async {
    try {
      final manager = pwaManager;
      if (manager == null) return false;

      final pwa = manager as PwaManager;
      if (!pwa.isDocumentPipSupported().toDart) return false;

      jsOnPipClosedExternally = () {
        _isPipActive = false;
      }.toJS;

      final jsOnPauseToggle = onPauseToggle.toJS;
      final jsOnSkip = onSkip.toJS;

      final result = await pwa
          .openDocumentPip(
            initialTime.toJS,
            isRunning.toJS,
            jsOnPauseToggle,
            jsOnSkip,
          )
          .toDart;

      return _isPipActive = result.toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  void updatePip(String timeStr, {required bool isRunning}) {
    if (!_isPipActive) return;
    try {
      final manager = pwaManager;
      if (manager != null) {
        (manager as PwaManager).updatePip(timeStr.toJS, isRunning.toJS);
      }
    } catch (_) {}
  }

  @override
  void closePip() {
    try {
      final manager = pwaManager;
      if (manager != null) {
        (manager as PwaManager).closePip();
      }
      jsOnPipClosedExternally = null;
      _isPipActive = false;
    } catch (_) {}
  }
}

@JS('console.log')
external void _jsConsoleLog(JSAny? msg);

WebPwaService getWebPwaService() => WebPwaServiceWeb();
