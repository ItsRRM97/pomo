import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let launchAtLogin = UserDefaults.standard.bool(forKey: "flutter.pomo_launch_at_login")
    // false when opened as a login item / agent; true for Finder/Dock double-click.
    let isDefaultLaunch =
      (notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool)
      ?? true
    let startHidden = launchAtLogin && !isDefaultLaunch
    OverlayPlugin.shouldStartHidden = startHidden

    if startHidden {
      // Menu-bar agent: no Dock bounce, no main window until the user opens it.
      NSApp.setActivationPolicy(.accessory)
    } else {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }

    MenuBarController.shared.installEarlyIfNeeded()
    OverlayPlugin.startObservingWorkspace()
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    OverlayPlugin.ensureRegularActivationPolicy()
    if !flag {
      OverlayPlugin.showMainWindow()
    }
    return true
  }
}
