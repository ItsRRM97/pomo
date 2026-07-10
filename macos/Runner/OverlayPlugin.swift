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
      if OverlayPlugin.overlayWindow == nil {
        OverlayPlugin.overlayWindow = NSApp.windows.first(where: { $0 != NSApp.mainWindow && $0.canBecomeKey == false })
          ?? NSApp.windows.first(where: { $0 != NSApp.mainWindow })
      }
      if let window = OverlayPlugin.overlayWindow {
        OverlayPlugin.configure(window: window)
        let corner = (call.arguments as? [String: Any])?["corner"] as? String
          ?? UserDefaults.standard.string(forKey: "flutter.pomo_overlay_corner")
          ?? "topRight"
        positionOverlay(corner: corner)
      }
      result(nil)
    case "showMainWindow":
      DispatchQueue.main.async {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.windows.first(where: { $0 != OverlayPlugin.overlayWindow && $0.canBecomeKey })
            ?? NSApp.windows.first(where: { $0 != OverlayPlugin.overlayWindow })
            ?? NSApp.mainWindow {
          mainWindow.makeKeyAndOrderFront(nil)
          mainWindow.orderFrontRegardless()
        }
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
      // Use .floating (level 3) - NOT a very high value like 1000.
      // On macOS Ventura/Sonoma/Sequoia, levels above ~25 are BLOCKED from
      // joining full-screen spaces. .floating is the correct level for widgets
      // that need to appear above normal windows AND inside full-screen spaces.
      window.level = .floating
      // fullScreenAuxiliary: appear inside full-screen spaces from other apps.
      // canJoinAllSpaces: appear in every Mission Control space.
      // Do NOT include .stationary here — it prevents the window from properly
      // entering Spaces managed by Mission Control (including full-screen ones).
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = false
      window.styleMask = [.borderless, .nonactivatingPanel]
      window.isMovableByWindowBackground = true
      window.hidesOnDeactivate = false
      if let panel = window as? NSPanel {
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
      }
      // Re-assert front position immediately after configuration.
      window.orderFrontRegardless()
    }
  }

  private func positionOverlay(corner: String) {
    DispatchQueue.main.async {
      guard let window = OverlayPlugin.overlayWindow,
            let screen = NSScreen.main else {
        return
      }

      // Use screen.frame (full physical bounds) not visibleFrame.
      // visibleFrame subtracts the menu bar and Dock, which means in full-screen
      // mode the overlay would be placed behind the full-screen content.
      let frame = screen.frame
      let size = NSSize(width: 148, height: 52)
      let margin: CGFloat = 16
      // Leave room for menu bar (roughly 28pt) when at the top edge.
      let menuBarHeight: CGFloat = NSApplication.shared.mainMenu != nil ? 28 : 0
      var origin = NSPoint.zero

      switch corner {
      case "topLeft":
        origin = NSPoint(x: frame.minX + margin, y: frame.maxY - size.height - margin - menuBarHeight)
      case "bottomLeft":
        origin = NSPoint(x: frame.minX + margin, y: frame.minY + margin)
      case "bottomRight":
        origin = NSPoint(x: frame.maxX - size.width - margin, y: frame.minY + margin)
      default: // topRight
        origin = NSPoint(x: frame.maxX - size.width - margin, y: frame.maxY - size.height - margin - menuBarHeight)
      }

      window.setFrame(NSRect(origin: origin, size: size), display: true)
      window.orderFrontRegardless()
    }
  }
}


