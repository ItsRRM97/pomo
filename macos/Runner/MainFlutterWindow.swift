import Cocoa
import FlutterMacOS
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
}
