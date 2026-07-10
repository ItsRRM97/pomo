import Cocoa
import FlutterMacOS

/// Non-activating panel that can join full-screen Spaces on any monitor.
final class OverlayPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    isFloatingPanel = true
    becomesKeyOnlyIfNeeded = false
    hidesOnDeactivate = false
  }
}

class OverlayPlugin: NSObject, FlutterPlugin {
  private static weak var overlayWindow: NSWindow?
  private static weak var hostWindow: NSWindow?
  private static var spaceObserver: NSObjectProtocol?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pomo/overlay",
      binaryMessenger: registrar.messenger
    )
    let instance = OverlayPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  static func attachOverlayWindow(_ window: NSWindow) {
    if overlayWindow != nil {
      return
    }

    hostWindow = window

    if let flutterViewController = window.contentViewController as? FlutterViewController,
       !(window is OverlayPanel) {
      let panel = OverlayPanel(contentRect: window.frame)
      window.contentViewController = nil
      panel.contentViewController = flutterViewController
      panel.setFrame(window.frame, display: false)
      window.orderOut(nil)
      overlayWindow = panel
    } else {
      overlayWindow = window
    }

    if let overlayWindow {
      configure(window: overlayWindow)
      startObservingWorkspace()
    }
  }

  static func startObservingWorkspace() {
    guard spaceObserver == nil else {
      return
    }

    spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      bringOverlayToFront()
    }
  }

  static func showMainWindow() {
    DispatchQueue.main.async {
      ensureRegularActivationPolicy()
      NSApp.unhide(nil)
      NSApp.activate(ignoringOtherApps: true)

      let overlay = overlayWindow
      if let mainWindow = NSApp.windows.first(where: {
        $0 !== overlay && $0.canBecomeKey
      }) ?? NSApp.windows.first(where: { $0 !== overlay }) ?? NSApp.mainWindow {
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.orderFrontRegardless()
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configureOverlayWindow":
      resolveOverlayWindowIfNeeded()
      if let window = OverlayPlugin.overlayWindow {
        OverlayPlugin.configure(window: window)
        let corner = (call.arguments as? [String: Any])?["corner"] as? String
          ?? UserDefaults.standard.string(forKey: "flutter.pomo_overlay_corner")
          ?? "topRight"
        positionOverlay(corner: corner)
      }
      result(nil)
    case "showOverlay":
      resolveOverlayWindowIfNeeded()
      let corner = (call.arguments as? [String: Any])?["corner"] as? String
        ?? UserDefaults.standard.string(forKey: "flutter.pomo_overlay_corner")
        ?? "topRight"
      OverlayPlugin.showOverlay(corner: corner)
      result(nil)
    case "ensureRegularActivation":
      OverlayPlugin.ensureRegularActivationPolicy()
      result(nil)
    case "showMainWindow":
      OverlayPlugin.showMainWindow()
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

  private func resolveOverlayWindowIfNeeded() {
    if OverlayPlugin.overlayWindow == nil {
      if let host = OverlayPlugin.hostWindow {
        OverlayPlugin.attachOverlayWindow(host)
      } else if let window = NSApp.windows.first(where: {
        $0 !== NSApp.mainWindow && $0.canBecomeKey == false
      }) ?? NSApp.windows.first(where: { $0 !== NSApp.mainWindow }) {
        OverlayPlugin.attachOverlayWindow(window)
      }
    }
  }

  static func showOverlay(corner: String) {
    guard let window = overlayWindow else {
      return
    }

    configure(window: window)
    DispatchQueue.main.async {
      positionOverlayOnActiveScreen(
        corner: corner,
        window: window,
        screenProvider: activeScreen
      )
      window.orderFrontRegardless()
    }
  }

  private static func activeScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: {
      NSMouseInRect(mouseLocation, $0.frame, false)
    }) {
      return screen
    }

    if let keyWindow = NSApp.keyWindow?.screen {
      return keyWindow
    }

    return NSScreen.main
  }

  static func ensureRegularActivationPolicy() {
    if NSApp.activationPolicy() != .regular {
      NSApp.setActivationPolicy(.regular)
    }
  }

  private static func bringOverlayToFront() {
    guard let window = overlayWindow, window.isVisible else {
      return
    }

    configure(window: window)
    window.orderFrontRegardless()
  }

  private static func configure(window: NSWindow) {
    DispatchQueue.main.async {
      // .floating (3) can join full-screen Spaces on recent macOS releases.
      // Levels above ~25 are blocked from entering those Spaces.
      window.level = .floating
      window.collectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .ignoresCycle,
      ]
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = false
      window.isMovableByWindowBackground = true
      window.hidesOnDeactivate = false
      window.ignoresMouseEvents = false

      if let panel = window as? NSPanel {
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
      }

      ensureRegularActivationPolicy()
      window.orderFrontRegardless()
    }
  }

  private func activeScreen() -> NSScreen? {
    OverlayPlugin.activeScreen()
  }

  private func positionOverlay(corner: String) {
    DispatchQueue.main.async {
      guard let window = OverlayPlugin.overlayWindow else {
        return
      }
      OverlayPlugin.positionOverlayOnActiveScreen(
        corner: corner,
        window: window,
        screenProvider: self.activeScreen
      )
    }
  }

  private static func positionOverlayOnActiveScreen(
    corner: String,
    window: NSWindow,
    screenProvider: (() -> NSScreen?)? = nil
  ) {
    guard let screen = screenProvider?() ?? NSScreen.main else {
      return
    }

    let frame = screen.frame
    let size = NSSize(width: 148, height: 52)
    let margin: CGFloat = 16
    let menuBarHeight: CGFloat = NSApplication.shared.mainMenu != nil ? 28 : 0
    var origin = NSPoint.zero

    switch corner {
    case "topLeft":
      origin = NSPoint(
        x: frame.minX + margin,
        y: frame.maxY - size.height - margin - menuBarHeight
      )
    case "bottomLeft":
      origin = NSPoint(x: frame.minX + margin, y: frame.minY + margin)
    case "bottomRight":
      origin = NSPoint(
        x: frame.maxX - size.width - margin,
        y: frame.minY + margin
      )
    default:
      origin = NSPoint(
        x: frame.maxX - size.width - margin,
        y: frame.maxY - size.height - margin - menuBarHeight
      )
    }

    window.setFrame(NSRect(origin: origin, size: size), display: true)
    configure(window: window)
  }
}
