import Foundation

func expect(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("开机启动回归失败：\(message)\n", stderr)
        exit(1)
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let agents = root.appendingPathComponent("LaunchAgents", isDirectory: true)
let app = URL(fileURLWithPath: "/Applications/Bettbox.app")
let moved = URL(fileURLWithPath: "/Users/tester/Applications/Bettbox.app")

expect(
    !LegacyLaunchAtLogin.isEnabled(agentDirectory: agents, bundleURL: app),
    "缺少 plist 时不应视为已启用"
)
try LegacyLaunchAtLogin.setEnabled(true, agentDirectory: agents, bundleURL: app)
expect(
    LegacyLaunchAtLogin.isEnabled(agentDirectory: agents, bundleURL: app),
    "写入后应启用当前 App"
)
expect(
    !LegacyLaunchAtLogin.isEnabled(agentDirectory: agents, bundleURL: moved),
    "路径不同不得视为同一个启动项"
)

let plistURL = LegacyLaunchAtLogin.plistURL(agentDirectory: agents)
let attributes = try FileManager.default.attributesOfItem(atPath: plistURL.path)
let mode = attributes[.posixPermissions] as? NSNumber
expect(mode?.intValue == 0o644, "plist 权限必须是 644")

let data = try Data(contentsOf: plistURL)
var format = PropertyListSerialization.PropertyListFormat.xml
let plist = try PropertyListSerialization.propertyList(
    from: data,
    options: [],
    format: &format
) as? [String: Any]
expect(plist?["Label"] as? String == LegacyLaunchAtLogin.label, "Label 不正确")
expect(
    plist?["ProgramArguments"] as? [String] == ["/usr/bin/open", app.path],
    "应通过 open 启动 App 包"
)

try LegacyLaunchAtLogin.setEnabled(true, agentDirectory: agents, bundleURL: moved)
expect(
    LegacyLaunchAtLogin.isEnabled(agentDirectory: agents, bundleURL: moved),
    "重复启用应改写到新路径"
)
try LegacyLaunchAtLogin.setEnabled(false, agentDirectory: agents, bundleURL: moved)
expect(!FileManager.default.fileExists(atPath: plistURL.path), "关闭后应删除 plist")
try LegacyLaunchAtLogin.setEnabled(false, agentDirectory: agents, bundleURL: moved)

try Data("not a plist".utf8).write(to: plistURL)
expect(
    !LegacyLaunchAtLogin.isEnabled(agentDirectory: agents, bundleURL: app),
    "损坏的 plist 不得视为已启用"
)
try LegacyLaunchAtLogin.setEnabled(true, agentDirectory: agents, bundleURL: app)
expect(
    LegacyLaunchAtLogin.isEnabled(agentDirectory: agents, bundleURL: app),
    "损坏的 plist 应可被重新写入"
)

print("macOS 12 开机启动回归通过")
