import Foundation
import Postbox

/// A tiny synchronous mirror of the reactive account settings. Hot UI paths such
/// as read tracking and input activity cannot wait for an asynchronous Postbox
/// transaction every time they are invoked.
public enum MonogramRuntimePolicy {
    private static let lock = NSLock()
    private static var accountSettings: [PeerId: MonogramSettings] = [:]

    public static func update(accountPeerId: PeerId, settings: MonogramSettings) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.accountSettings[accountPeerId] = settings
    }

    public static func remove(accountPeerId: PeerId) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.accountSettings.removeValue(forKey: accountPeerId)
    }

    public static func isEnabled(_ id: MonogramFeatureId, accountPeerId: PeerId) -> Bool {
        return self.settings(accountPeerId: accountPeerId).isEnabled(id)
    }

    public static func settings(accountPeerId: PeerId) -> MonogramSettings {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.accountSettings[accountPeerId] ?? MonogramSettings()
    }

    private static func activeGhostSettings(_ settings: MonogramSettings, peerId: PeerId?) -> MonogramSettings? {
        guard settings.isGhostModeActive() else {
            return nil
        }
        if let peerId, settings.ghostModeExcludedPeerIds.contains(peerId.toInt64()) {
            return nil
        }
        return settings
    }

    public static func readsHistoryLocally(accountPeerId: PeerId, peerId: PeerId? = nil) -> Bool {
        return self.activeGhostSettings(self.settings(accountPeerId: accountPeerId), peerId: peerId)?.isEnabled(.ghostReadReceipts) == true
    }

    public static func suppressesReadReceipts(accountPeerId: PeerId, peerId: PeerId? = nil) -> Bool {
        return self.suppressesActivity(.ghostReadReceipts, accountPeerId: accountPeerId, peerId: peerId)
    }

    public static func suppressesInputActivity(accountPeerId: PeerId, peerId: PeerId? = nil) -> Bool {
        return self.suppressesActivity(.ghostTypingActivity, accountPeerId: accountPeerId, peerId: peerId)
    }

    private static func suppressesActivity(_ feature: MonogramFeatureId, accountPeerId: PeerId, peerId: PeerId?) -> Bool {
        let settings = self.settings(accountPeerId: accountPeerId)
        if MonogramOfflineEntry.isActive(accountPeerId: accountPeerId, settings: settings) {
            return true
        }
        return self.activeGhostSettings(settings, peerId: peerId)?.isEnabled(feature) == true
    }
}
