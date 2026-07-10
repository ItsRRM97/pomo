import Cocoa
import FlutterMacOS

class OverlayPlugin: NSObject, FlutterPlugin {
  private static weak var overlayWindow: NSWindow?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pomo/overlay",
      binaryMessenger: registrar.messenger
    )
    let instance = OverlayPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  static func attachOverlayWindow(_ window: NSWindow) {
    overlayWindow = window
    configure(window: window)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configureOverlayWindow":
      if let window = OverlayPlugin.overlayWindow {
        OverlayPlugin.configure(window: window)
        let corner = (call.arguments as? [String: Any])?["corner"] as? String
          ?? UserDefaults.standard.string(forKey: "flutter.pomo_overlay_corner")
          ?? "topRight"
        positionOverlay(corner: corner)
      }
      result(nil)
    case "hideOverlay":
      OverlayPlugin.overlayWindow?.orderOut(nil)
      result(nil)
    case "positionOverlay":
      if let args = call.arguments as? [String: Any],
         let corner = args["corner"] as? String {
        UserDefaults.standard.set(corner, forKey: "pomo_overlay_corner")
        positionOverlay(corner: corner)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func configure(window: NSWindow) {
    DispatchQueue.main.async {
      window.level = .floating
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = true
      window.styleMask = [.borderless, .nonactivatingPanel]
      window.isMovableByWindowBackground = true
      window.hidesOnDeactivate = false
      if let panel = window as? NSPanel {
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
      }
    }
  }

  private func positionOverlay(corner: String) {
    DispatchQueue.main.async {
      guard let window = OverlayPlugin.overlayWindow,
            let screen = NSScreen.main else {
        return
      }

      let frame = screen.visibleFrame
      let size = NSSize(width: 148, height: 52)
      let margin: CGFloat = 16
      var origin = NSPoint.zero

      switch corner {
      case "topLeft":
        origin = NSPoint(x: frame.minX + margin, y: frame.maxY - size.height - margin)
      case "bottomLeft":
        origin = NSPoint(x: frame.minX + margin, y: frame.minY + margin)
      case "bottomRight":
        origin = NSPoint(x: frame.maxX - size.width - margin, y: frame.minY + margin)
      default:
        origin = NSPoint(x: frame.maxX - size.width - margin, y: frame.maxY - size.height - margin)
      }

      window.setFrame(NSRect(origin: origin, size: size), display: true)
      window.orderFrontRegardless()
    }
  }
}
