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
        result(FlutterMethodNotImplemented)
    }
}
