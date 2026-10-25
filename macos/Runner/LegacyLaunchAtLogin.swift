import Foundation

// BETTBOX-CUSTOM: macOS 12 没有 SMAppService。LaunchAtLogin 的旧实现依赖
// Contents/Library/LoginItems 里的 Helper，正式包没有打进这个 Helper，
// SMLoginItemSetEnabled 会失败且被库吞掉。用户 LaunchAgent 不依赖商业签名。
enum LegacyLaunchAtLogin {
    static let label = "com.appshub.bettbox.login"

    static var defaultAgentDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    static func plistURL(agentDirectory: URL) -> URL {
        agentDirectory.appendingPathComponent("\(label).plist")
    }

    static func isEnabled(agentDirectory: URL, bundleURL: URL) -> Bool {
        guard let path = installedBundlePath(agentDirectory: agentDirectory) else {
            return false
        }
        return normalizedPath(path) == normalizedPath(bundleURL.path)
    }

    static func setEnabled(
        _ enabled: Bool,
        agentDirectory: URL,
        bundleURL: URL
    ) throws {
        let url = plistURL(agentDirectory: agentDirectory)
        if !enabled {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }

        try FileManager.default.createDirectory(
            at: agentDirectory,
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = [
            "Label": label,
            "LimitLoadToSessionType": "Aqua",
            "ProgramArguments": ["/usr/bin/open", bundleURL.path],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: url, options: .atomic)
        // launchd 拒绝其他用户可写的 plist。
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: url.path
        )
    }

    private static func installedBundlePath(agentDirectory: URL) -> String? {
        let url = plistURL(agentDirectory: agentDirectory)
        guard let data = try? Data(contentsOf: url) else { return nil }
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any],
            plist["Label"] as? String == label,
            plist["RunAtLoad"] as? Bool == true,
            let arguments = plist["ProgramArguments"] as? [String],
            arguments.count == 2,
            arguments[0] == "/usr/bin/open"
        else {
            return nil
        }
        return arguments[1]
    }

    private static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }
}
