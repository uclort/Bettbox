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

        // 配置应用方法通道与系统唤醒监听
        setupAppMethodChannel(flutterViewController: flutterViewController)
        setupSystemWakeNotification()

        RegisterGeneratedPlugins(registry: flutterViewController)

        // 网络面板使用独立 Dock 图标
        if CommandLine.arguments.contains("--network-panel") {
            _ = setDockIcon(named: "network_monitor_icon")
        }

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

    // MARK: - 应用方法通道

    private func setupAppMethodChannel(flutterViewController: FlutterViewController) {
        appMethodChannel = FlutterMethodChannel(
            name: "app",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        
        appMethodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "Window unavailable", details: nil))
                return
            }
            
            switch call.method {
            case "getPackageIcon":
                let arguments = call.arguments as? [String: Any]
                let processPath = arguments?["processPath"] as? String ?? ""
                let processName = arguments?["packageName"] as? String ?? ""
                result(self.processIconData(processPath: processPath, processName: processName))
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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

    // MARK: - 图标管理

    private func setDockIcon(named iconName: String) -> Bool {
        guard let iconPath = Bundle.main.privateFrameworksURL?
            .appendingPathComponent("App.framework/Resources/flutter_assets/assets/images/\(iconName).png").path,
              let image = NSImage(contentsOfFile: iconPath) else {
            if let appIcon = NSImage(named: "AppIcon") {
                NSApp.applicationIconImage = appIcon
            }
            return false
        }
        
        NSApp.applicationIconImage = image
        return true
    }

    private func processIconData(processPath: String, processName: String) -> FlutterStandardTypedData? {
        return autoreleasepool {
            let image: NSImage?
            if processPath.isEmpty {
                if processName.isEmpty {
                    image = NSApp.applicationIconImage
                } else {
                    let application = NSWorkspace.shared.runningApplications.first { application in
                        let names = [
                            application.localizedName,
                            application.executableURL?.lastPathComponent,
                            application.bundleURL?.deletingPathExtension().lastPathComponent,
                        ].compactMap { $0 }
                        return names.contains { $0.caseInsensitiveCompare(processName) == .orderedSame }
                    }
                    let iconPath = application?.bundleURL?.path ?? application?.executableURL?.path
                    image = iconPath.map { NSWorkspace.shared.icon(forFile: $0) }
                }
            } else {
                var iconPath = processPath
                if let range = processPath.range(of: ".app/", options: .caseInsensitive) {
                    iconPath = String(processPath[..<range.upperBound].dropLast())
                }
                image = NSWorkspace.shared.icon(forFile: iconPath)
            }
            guard let image else { return nil }

            let size = NSSize(width: 64, height: 64)
            let resized = NSImage(size: size)
            resized.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect(origin: .zero, size: size))
            resized.unlockFocus()

            guard let tiff = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }
            return FlutterStandardTypedData(bytes: data)
        }
    }
}
