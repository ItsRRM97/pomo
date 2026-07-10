import Cocoa
import FlutterMacOS

/// Native macOS menu bar integration.
///
/// tray_manager attaches a zero-frame NSView to NSStatusBarButton and reads
/// button.window.frame for bounds. In release builds AppKit often has not laid
/// out the status item yet, so the tray never becomes visible. This controller
/// uses the standard NSStatusItem button API and installs the item from
/// AppDelegate before the Flutter engine starts.
final class MenuBarController: NSObject, NSMenuDelegate {
  static let shared = MenuBarController()

  private var statusItem: NSStatusItem?
  private var channel: FlutterMethodChannel?
  private var contextMenu: NSMenu?
  private var menuKeyByTag: [Int: String] = [:]
  private var nextMenuTag = 1

  private override init() {
    super.init()
  }

  func attachChannel(_ channel: FlutterMethodChannel) {
    if self.channel == nil {
      self.channel = channel
    }
  }

  func installEarlyIfNeeded() {
    guard statusItem == nil else {
      return
    }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.isVisible = true
    guard let button = item.button else {
      NSLog("Pomo MenuBar: failed to create NSStatusItem button")
      return
    }

    button.imagePosition = .imageLeading
    button.title = "Pomo"
    button.toolTip = "Pomo - Pomodoro timer"
    button.target = self
    button.action = #selector(handleStatusItemClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])

    statusItem = item
    setDefaultIconIfAvailable()

    let frame = button.frame
    NSLog(
      "Pomo MenuBar: installed early (button=%.0fx%.0f visible=%d)",
      frame.width,
      frame.height,
      button.isHidden ? 0 : 1
    )
  }

  private func setDefaultIconIfAvailable() {
    guard let button = statusItem?.button else {
      return
    }

    if let image = loadFlutterAssetImage(named: "assets/images/pomo_splash_64.png") {
      image.size = NSSize(width: 22, height: 22)
      image.isTemplate = false
      button.image = image
    }
  }

  private func loadFlutterAssetImage(named assetPath: String) -> NSImage? {
    let appFramework = Bundle.main.privateFrameworksPath?
      .appending("/App.framework/Resources/flutter_assets/\(assetPath)")
    if let appFramework, FileManager.default.fileExists(atPath: appFramework),
       let image = NSImage(contentsOfFile: appFramework) {
      return image
    }

    if let resourcePath = Bundle.main.resourcePath {
      let bundleAsset = (resourcePath as NSString).appendingPathComponent("flutter_assets/\(assetPath)")
      if FileManager.default.fileExists(atPath: bundleAsset),
         let image = NSImage(contentsOfFile: bundleAsset) {
        return image
      }
    }

    return nil
  }

  @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else {
      channel?.invokeMethod("onTrayIconMouseDown", arguments: nil)
      return
    }

    switch event.type {
    case .rightMouseUp:
      channel?.invokeMethod("onTrayIconRightMouseDown", arguments: nil)
    default:
      channel?.invokeMethod("onTrayIconMouseDown", arguments: nil)
    }
  }

  func setIcon(base64Icon: String, iconSize: Int, isTemplate: Bool) {
    installEarlyIfNeeded()

    guard let data = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters),
          let image = NSImage(data: data),
          let button = statusItem?.button else {
      NSLog("Pomo MenuBar: setIcon failed")
      return
    }

    image.size = NSSize(width: iconSize, height: iconSize)
    image.isTemplate = isTemplate
    button.image = image
    statusItem?.length = NSStatusItem.variableLength
    statusItem?.isVisible = true
    button.needsLayout = true
    button.needsDisplay = true
  }

  func setTitle(_ title: String) {
    installEarlyIfNeeded()
    statusItem?.button?.title = title
    statusItem?.length = NSStatusItem.variableLength
    statusItem?.isVisible = true
    statusItem?.button?.needsLayout = true
    statusItem?.button?.needsDisplay = true
  }

  func setToolTip(_ toolTip: String) {
    installEarlyIfNeeded()
    statusItem?.button?.toolTip = toolTip
  }

  func setContextMenu(_ args: [String: Any]) {
    installEarlyIfNeeded()

    let menu = NSMenu()
    menu.delegate = self
    menuKeyByTag.removeAll()
    nextMenuTag = 1

    if let items = args["items"] as? [[String: Any]] {
      for item in items {
        let type = item["type"] as? String ?? "normal"
        if type == "separator" {
          menu.addItem(.separator())
          continue
        }

        let menuItem = NSMenuItem()
        menuItem.title = item["label"] as? String ?? ""
        menuItem.isEnabled = !(item["disabled"] as? Bool ?? false)
        if let key = item["key"] as? String {
          let tag = nextMenuTag
          nextMenuTag += 1
          menuItem.tag = tag
          menuKeyByTag[tag] = key
          menuItem.target = self
          menuItem.action = #selector(handleMenuItemClick(_:))
        }
        menu.addItem(menuItem)
      }
    }

    contextMenu = menu
  }

  @objc private func handleMenuItemClick(_ sender: NSMenuItem) {
    guard let key = menuKeyByTag[sender.tag] else {
      return
    }
    channel?.invokeMethod("onTrayMenuItemClick", arguments: ["key": key])
  }

  func popUpContextMenu() {
    guard let button = statusItem?.button, let menu = contextMenu else {
      return
    }

    statusItem?.menu = menu
    button.performClick(nil)
    statusItem?.menu = nil
  }

  func getBounds() -> [String: Double]? {
    guard let button = statusItem?.button else {
      return nil
    }

    let frameInWindow = button.convert(button.bounds, to: nil)
    guard let screen = button.window?.screen ?? NSScreen.main else {
      return nil
    }

    let screenFrame = screen.frame
    var height = frameInWindow.size.height
    var width = frameInWindow.size.width

    if width <= 0 || height <= 0 {
      let buttonFrame = button.frame
      width = buttonFrame.size.width > 0 ? buttonFrame.size.width : 22.0
      height = buttonFrame.size.height > 0 ? buttonFrame.size.height : 22.0
    }

    return [
      "x": Double(frameInWindow.origin.x),
      "y": Double(screenFrame.height - frameInWindow.origin.y - height),
      "width": Double(width),
      "height": Double(height),
    ]
  }

  func menuDidClose(_ menu: NSMenu) {
    statusItem?.menu = nil
  }
}

class MenuBarPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pomo/menu_bar",
      binaryMessenger: registrar.messenger
    )
    let instance = MenuBarPlugin()
    MenuBarController.shared.attachChannel(channel)
    MenuBarController.shared.installEarlyIfNeeded()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "install":
      MenuBarController.shared.installEarlyIfNeeded()
      result(true)
    case "setIcon":
      guard let args = call.arguments as? [String: Any],
            let base64Icon = args["base64Icon"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing base64Icon", details: nil))
        return
      }
      let iconSize = args["iconSize"] as? Int ?? 22
      let isTemplate = args["isTemplate"] as? Bool ?? false
      MenuBarController.shared.setIcon(
        base64Icon: base64Icon,
        iconSize: iconSize,
        isTemplate: isTemplate
      )
      result(true)
    case "setTitle":
      guard let args = call.arguments as? [String: Any],
            let title = args["title"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing title", details: nil))
        return
      }
      MenuBarController.shared.setTitle(title)
      result(true)
    case "setToolTip":
      guard let args = call.arguments as? [String: Any],
            let toolTip = args["toolTip"] as? String else {
        result(FlutterError(code: "bad_args", message: "Missing toolTip", details: nil))
        return
      }
      MenuBarController.shared.setToolTip(toolTip)
      result(true)
    case "setContextMenu":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing menu args", details: nil))
        return
      }
      MenuBarController.shared.setContextMenu(args)
      result(true)
    case "popUpContextMenu":
      MenuBarController.shared.popUpContextMenu()
      result(true)
    case "getBounds":
      result(MenuBarController.shared.getBounds())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
