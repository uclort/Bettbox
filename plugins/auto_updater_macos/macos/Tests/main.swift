import Cocoa
import Sparkle

// 测试同短版本不同构建号，以及已包含构建号时不重复拼接。
assert(FullVersionDisplayer.fullVersion("1.19.3", build: "2090000183") == "1.19.3+2090000183")
assert(FullVersionDisplayer.fullVersion("1.19.3+2090000183", build: "2090000183") == "1.19.3+2090000183")
assert(FullVersionDisplayer.fullVersion("1.19.3", build: "") == "1.19.3")

// 仅测试展示格式，不使用该初始化器参与实际更新判断。
let update = SUAppcastItem(dictionary: [
    "enclosure": [
        "url": "https://example.com/Bettbox.dmg",
        "sparkle:version": "2090000184",
        "sparkle:shortVersionString": "1.19.3+2090000184"
    ]
])!
let formatter = FullVersionDisplayer()
var current: NSString = "1.19.3"
let latest = formatter.formatUpdateVersion(
    fromUpdate: update,
    andBundleDisplayVersion: &current,
    withBundleVersion: "2090000183"
)
assert(current == "1.19.3+2090000183")
assert(latest == "1.19.3+2090000184")
assert(formatter.formatBundleDisplayVersion(
    "1.19.3", withBundleVersion: "2090000184", matchingUpdate: update
) == "1.19.3+2090000184")
print("Sparkle full version formatting: PASS")
