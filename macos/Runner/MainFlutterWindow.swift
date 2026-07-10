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
      with: flutterViewController.registrar(forPlugin: "OverlayPlugin")!
    )

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      OverlayPlugin.register(
        with: controller.registrar(forPlugin: "OverlayPlugin")!
      )

      if let window = controller.view?.window {
        OverlayPlugin.attachOverlayWindow(window)
      }
    }

    super.awakeFromNib()
  }
}
