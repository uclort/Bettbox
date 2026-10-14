import Cocoa
import FlutterMacOS

// BETTBOX-CUSTOM: Dock 图标只跟随应用窗口是否存在，不再受持久化开关控制。
public enum DockIconVisibility {
    public static func activationPolicy(hasWindow: Bool) -> NSApplication.ActivationPolicy {
        hasWindow ? .regular : .accessory
    }

    @MainActor
    public static func update(hasWindow: Bool) {
        let policy = activationPolicy(hasWindow: hasWindow)
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }

    @MainActor
    public static func synchronize() {
        let hasWindow = NSApp.windows.contains { window in
            guard !(window is NSPanel), window.canBecomeKey else {
                return false
            }
            return window.isVisible || window.isMiniaturized
        }
        update(hasWindow: hasWindow)
    }
}

public class WindowExtPlugin: NSObject, FlutterPlugin {
    public static var instance:WindowExtPlugin?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "window_ext", binaryMessenger: registrar.messenger)
        instance = WindowExtPlugin(registrar, channel)
        registrar.addMethodCallDelegate(instance!, channel: channel)
    }
    
    private var registrar: FlutterPluginRegistrar!
    private var channel: FlutterMethodChannel!
    
    public init(_ registrar: FlutterPluginRegistrar, _ channel: FlutterMethodChannel) {
        super.init()
        self.registrar = registrar
        self.channel = channel
    }
    
    public func handleShouldTerminate(){
        channel.invokeMethod("shouldTerminate", arguments: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getFileIcon":
            guard let arguments = call.arguments as? [String: Any],
                  let path = arguments["path"] as? String,
                  let size = arguments["size"] as? Int,
                  size > 0,
                  FileManager.default.fileExists(atPath: path) else {
                result(nil)
                return
            }
            DispatchQueue.main.async {
                let data = self.getFileIcon(path, size)
                result(data.map { FlutterStandardTypedData(bytes: $0) })
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getFileIcon(_ path: String, _ size: Int) -> Data? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.draw(
            in: NSRect(x: 0, y: 0, width: size, height: size),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

}
