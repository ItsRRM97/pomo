import Cocoa
import FlutterMacOS
import ServiceManagement
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MenuBarPlugin.register(
      with: flutterViewController.registrar(forPlugin: "MenuBarPlugin")
    )
    OverlayPlugin.register(
      with: flutterViewController.registrar(forPlugin: "OverlayPlugin")
    )
    Self.registerLaunchAtStartupChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      // Note: MenuBarPlugin is intentionally NOT registered for secondary windows.
      // The menu bar communicates only with the main Flutter engine.
      // Registering it for sub-windows would overwrite the main channel and
      // break menu bar callbacks after a floating overlay window opens.
      OverlayPlugin.register(
        with: controller.registrar(forPlugin: "OverlayPlugin")
      )

      let attachOverlay: (NSWindow?) -> Void = { window in
        guard let window else { return }
        OverlayPlugin.attachOverlayWindow(window)
      }

      if let window = controller.view.window {
        attachOverlay(window)
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          attachOverlay(
            controller.view.window
              ?? NSApp.windows.first(where: { $0 != NSApp.mainWindow && $0 != self })
          )
        }
      }
    }

    super.awakeFromNib()
  }

  /// Bridges `package:launch_at_startup` to `SMAppService.mainApp` (macOS 13+).
  private static func registerLaunchAtStartupChannel(
    messenger: FlutterBinaryMessenger
  ) {
    FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      guard #available(macOS 13.0, *) else {
        if call.method == "launchAtStartupIsEnabled" {
          result(false)
        } else {
          result(
            FlutterError(
              code: "unsupported",
              message: "Launch at login requires macOS 13 or later",
              details: nil
            )
          )
        }
        return
      }

      switch call.method {
      case "launchAtStartupIsEnabled":
        result(SMAppService.mainApp.status == .enabled)
      case "launchAtStartupSetEnabled":
        guard
          let arguments = call.arguments as? [String: Any],
          let enabled = arguments["setEnabledValue"] as? Bool
        else {
          result(
            FlutterError(
              code: "bad_args",
              message: "Expected setEnabledValue: Bool",
              details: nil
            )
          )
          return
        }
        do {
          if enabled {
            try SMAppService.mainApp.register()
          } else if SMAppService.mainApp.status == .enabled
            || SMAppService.mainApp.status == .requiresApproval
          {
            try SMAppService.mainApp.unregister()
          }
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "sm_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
