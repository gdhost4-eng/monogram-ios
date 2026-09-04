import Foundation
import Postbox
import SwiftSignalKit

/// Session-only consent; never persisted with the regular Ghost Mode settings.
public enum MonogramOfflineEntry {
    private static let lock = NSLock()
    private static var admitted: Set<PeerId> = []
    private static var revision = 0
    private static let changes = ValuePromise<Int>(0, ignoreRepeated: true)

    public static var signal: Signal<Int, NoError> { return self.changes.get() }

    public static func isActive(accountPeerId: PeerId, settings: MonogramSettings) -> Bool {
        let ghostModeActive = settings.isGhostModeActive()
        self.lock.lock()
        // Choosing Ghost Mode also dismisses the warning for this session.
        // Keep that choice when Ghost Mode is subsequently disabled or expires.
        if settings.isEnabled(.offlineEntry) && ghostModeActive {
            self.admitted.insert(accountPeerId)
        }
        let admitted = self.admitted.contains(accountPeerId)
        self.lock.unlock()
        return settings.isEnabled(.offlineEntry) && !ghostModeActive && !admitted
    }

    public static func goOnline(accountPeerId: PeerId) {
        self.lock.lock()
        self.admitted.insert(accountPeerId)
        self.revision += 1
        let revision = self.revision
        self.lock.unlock()
        self.changes.set(revision)
    }

    public static func resetSession() {
        self.lock.lock()
        self.admitted.removeAll()
        self.revision += 1
        let revision = self.revision
        self.lock.unlock()
        self.changes.set(revision)
    }
}
