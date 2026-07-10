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
    OverlayPlugin.register(
      with: flutterViewController.registrar(forPlugin: "OverlayPlugin")
    )

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      OverlayPlugin.register(
        with: controller.registrar(forPlugin: "OverlayPlugin")
      )

      if let window = controller.view.window {
        OverlayPlugin.attachOverlayWindow(window)
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          if let window = controller.view.window ?? NSApp.windows.first(where: { $0 != NSApp.mainWindow && $0 != self }) {
            OverlayPlugin.attachOverlayWindow(window)
          }
        }
      }
    }

    super.awakeFromNib()
  }
}
