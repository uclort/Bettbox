import Cocoa
import FlutterMacOS
import window_manager
import LaunchAtLogin

class MainFlutterWindow: NSWindow {
    private var appMethodChannel: FlutterMethodChannel?
    private var systemDidWakeObserver: NSObjectProtocol?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        appMethodChannel = FlutterMethodChannel(
            name: "app",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        setupSystemWakeNotification()

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }

    deinit {
        if let observer = systemDidWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }

    private func setupSystemWakeNotification() {
        systemDidWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.appMethodChannel?.invokeMethod("systemDidWake", arguments: nil)
        }
    }

}
