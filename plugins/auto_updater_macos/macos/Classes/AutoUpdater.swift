import Cocoa
import FlutterMacOS
import Sparkle

extension SUAppcast {
    public func toDictionary() -> NSDictionary {
        let dict: NSDictionary = [
            "items": self.items.map({ item in
                return item.toDictionary()
            }),
        ]
        return dict;
    }
}

extension SUAppcastItem {
    
    
    public func toDictionary() -> NSDictionary {
        let dict: NSDictionary = [
            "versionString": self.versionString,
            "displayVersionString": self.displayVersionString,
            "fileURL": self.fileURL?.absoluteString ?? "",
            "contentLength": self.contentLength,
            "infoURL": self.infoURL?.absoluteString ?? "",
            "title":self.title ?? "",
            "dateString": self.dateString ?? "",
            "releaseNotesURL":self.releaseNotesURL?.absoluteString ?? "",
            "itemDescription":self.itemDescription ?? "",
            "itemDescriptionFormat": self.itemDescriptionFormat ?? "",
            "fullReleaseNotesURL": self.fullReleaseNotesURL ?? "",
            "minimumSystemVersion": self.minimumSystemVersion ?? "",
            "minimumOperatingSystemVersionIsOK": self.minimumOperatingSystemVersionIsOK,
            "maximumSystemVersion": self.maximumSystemVersion ?? "",
            "maximumOperatingSystemVersionIsOK": self.maximumOperatingSystemVersionIsOK,
            "channel": self.channel ?? "",
        ]
        return dict;
    }
}

// BETTBOX-CUSTOM: 只格式化更新界面，比较仍由 CFBundleVersion 完成。
public final class FullVersionDisplayer: NSObject, SUVersionDisplay {
    static func fullVersion(_ version: String, build: String) -> String {
        let short = version.components(separatedBy: "+")[0]
        return build.isEmpty ? version : "\(short)+\(build)"
    }

    public func formatUpdateVersion(
        fromUpdate update: SUAppcastItem,
        andBundleDisplayVersion version: AutoreleasingUnsafeMutablePointer<NSString>,
        withBundleVersion build: String
    ) -> String {
        version.pointee = Self.fullVersion(version.pointee as String, build: build) as NSString
        return Self.fullVersion(update.displayVersionString, build: update.versionString)
    }

    public func formatBundleDisplayVersion(
        _ version: String, withBundleVersion build: String,
        matchingUpdate: SUAppcastItem?
    ) -> String {
        Self.fullVersion(version, build: build)
    }
}

public class AutoUpdater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private let versionDisplayer = FullVersionDisplayer()
    var _userDriver: SPUStandardUserDriver?
    var _updater: SPUUpdater?
    var feedURL: URL?
    public var onEvent:((String, NSDictionary) -> Void)?
    
    override init() {
        super.init()
        let hostBundle: Bundle = Bundle.main
        
        _userDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: self)
        _updater = SPUUpdater(
            hostBundle: hostBundle,
            applicationBundle: hostBundle,
            userDriver: _userDriver!,
            delegate: self
        )
        _updater?.clearFeedURLFromUserDefaults()
        try? _updater?.start()
    }
    
    public func feedURLString(for updater: SPUUpdater) -> String? {
        return feedURL?.absoluteString
    }

    public func standardUserDriverRequestsVersionDisplayer() -> SUVersionDisplay? {
        versionDisplayer
    }

    public func setFeedURL(_ feedURL: URL?) {
        self.feedURL = feedURL
        try? _updater?.start()
    }
    
    public func checkForUpdates() {
        _updater?.checkForUpdates()
    }
    
    public func checkForUpdatesInBackground() {
        _updater?.checkForUpdatesInBackground()
    }
    
    public func setScheduledCheckInterval(_ interval: Int) {
        _updater?.updateCheckInterval = TimeInterval(interval)
    }
    
    // SPUUpdaterDelegate
    
    public func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let data: NSDictionary = [
            "error": error.localizedDescription,
        ]
        _emitEvent("error", data);
    }
    
    public func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        let data: NSDictionary = [
            "appcast": appcast.toDictionary()
        ]
        _emitEvent("checking-for-update", data)
    }
    
    public func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let data: NSDictionary = [
            "appcastItem": item.toDictionary()
        ]
        _emitEvent("update-available", data)
    }
    
    public func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let data: NSDictionary = [
            "error": error.localizedDescription,
        ]
        _emitEvent("update-not-available", data)
    }
    
    public func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        let data: NSDictionary = [
            "appcastItem": item.toDictionary()
        ]
        _emitEvent("update-downloaded", data)
    }
    
    public func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        let data: NSDictionary = [
            "appcastItem": item.toDictionary()
        ]
        _emitEvent("before-quit-for-update", data)
        return true
    }
    
    public func _emitEvent(_ eventName: String, _ data: NSDictionary) {
        if (onEvent != nil) {
            onEvent!(eventName, data)
        }
    }
}
