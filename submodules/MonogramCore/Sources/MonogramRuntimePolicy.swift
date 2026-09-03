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
        self.accountSettings[accountPeerId] = settings
        self.lock.unlock()
    }

    public static func remove(accountPeerId: PeerId) {
        self.lock.lock()
        self.accountSettings.removeValue(forKey: accountPeerId)
        self.lock.unlock()
    }

    public static func isEnabled(_ id: MonogramFeatureId, accountPeerId: PeerId) -> Bool {
        self.lock.lock()
        let settings = self.accountSettings[accountPeerId]
        self.lock.unlock()
        return settings?.isEnabled(id) ?? MonogramFeatureRegistry.descriptor(for: id).defaultValue
    }

    public static func settings(accountPeerId: PeerId) -> MonogramSettings {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.accountSettings[accountPeerId] ?? MonogramSettings()
    }

    private static func activeGhostSettings(accountPeerId: PeerId, peerId: PeerId?) -> MonogramSettings? {
        self.lock.lock()
        let settings = self.accountSettings[accountPeerId]
        self.lock.unlock()
        guard let settings, settings.isGhostModeActive() else {
            return nil
        }
        if let peerId, settings.ghostModeExcludedPeerIds.contains(peerId.toInt64()) {
            return nil
        }
        return settings
    }

    public static func suppressesReadReceipts(accountPeerId: PeerId, peerId: PeerId? = nil) -> Bool {
        return self.activeGhostSettings(accountPeerId: accountPeerId, peerId: peerId)?.isEnabled(.ghostReadReceipts) == true
    }

    public static func suppressesInputActivity(accountPeerId: PeerId, peerId: PeerId? = nil) -> Bool {
        return self.activeGhostSettings(accountPeerId: accountPeerId, peerId: peerId)?.isEnabled(.ghostTypingActivity) == true
    }
}
