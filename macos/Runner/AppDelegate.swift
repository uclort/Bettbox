import Cocoa
import FlutterMacOS
import window_ext

@main
class AppDelegate: FlutterAppDelegate {
    private var isNetworkPanel: Bool {
        CommandLine.arguments.contains("--network-panel")
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return isNetworkPanel
    }
    
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isNetworkPanel {
            return .terminateNow
        }
        WindowExtPlugin.instance?.handleShouldTerminate()
        return .terminateCancel
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
      return true
    }
    
    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                if !window.isVisible {
                    window.setIsVisible(true)
                }
                window.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }
}
