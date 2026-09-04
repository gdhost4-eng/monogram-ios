import Foundation
import SwiftSignalKit
import AccountContext
import MonogramCore

struct MonogramGhostModePresentation: Equatable {
    let isActive: Bool
    let durationLabel: String
    let nextRefreshInterval: Int64?

    init(settings: MonogramSettings, timestamp: Int64) {
        self.isActive = settings.isGhostModeActive(at: timestamp)
        guard self.isActive, let expiresAt = settings.ghostModeExpiresAt else {
            self.durationLabel = self.isActive ? "Постоянно" : ""
            self.nextRefreshInterval = nil
            return
        }

        let remaining = expiresAt - timestamp
        self.durationLabel = remaining >= 3600 ? "\((remaining + 3599) / 3600) ч" : "\((remaining + 59) / 60) мин"
        // Refresh at the next rounded label change, including the exact expiry.
        let unit: Int64 = remaining > 3600 ? 3600 : 60
        self.nextRefreshInterval = remaining == 3600 ? 1 : (remaining - 1) % unit + 1
    }
}

struct MonogramAdvancedSettingsState {
    let accountSettings: MonogramSettings
    let ghostMode: MonogramGhostModePresentation
    let bookmarksCount: Int
    let annotationsCount: Int
    let deletedCount: Int

    func isEnabled(_ id: MonogramFeatureId) -> Bool {
        return id == .ghostMode ? self.ghostMode.isActive : self.accountSettings.isEnabled(id)
    }
}

func monogramAdvancedSettingsState(context: AccountContext) -> Signal<MonogramAdvancedSettingsState, NoError> {
    let postbox = context.account.postbox
    let settings = monogramAccountSettings(postbox: postbox)
    |> mapToSignal { settings in
        return monogramGhostModePresentation(settings: settings)
        |> map { (settings, $0) }
    }
    let bookmarksCount = monogramBookmarks(postbox: postbox)
    |> map { $0.filter { $0.isLocallyPinned }.count }
    |> distinctUntilChanged
    let annotationsCount = monogramPeerAnnotations(postbox: postbox)
    |> map { $0.filter { $0.note != nil }.count }
    |> distinctUntilChanged
    let deletedCount = MonogramDeletedMessageTransform.records(postbox: postbox)
    |> map { $0.count }
    |> distinctUntilChanged

    return combineLatest(queue: .mainQueue(), settings, bookmarksCount, annotationsCount, deletedCount)
    |> map { settingsAndGhostMode, bookmarksCount, annotationsCount, deletedCount in
        return MonogramAdvancedSettingsState(
            accountSettings: settingsAndGhostMode.0,
            ghostMode: settingsAndGhostMode.1,
            bookmarksCount: bookmarksCount,
            annotationsCount: annotationsCount,
            deletedCount: deletedCount
        )
    }
}

private func monogramGhostModePresentation(settings: MonogramSettings) -> Signal<MonogramGhostModePresentation, NoError> {
    return deferred {
        let presentation = MonogramGhostModePresentation(settings: settings, timestamp: Int64(Date().timeIntervalSince1970))
        guard let interval = presentation.nextRefreshInterval else {
            return .single(presentation)
        }
        return .single(presentation)
        |> then(monogramGhostModePresentation(settings: settings)
            |> suspendAwareDelay(Double(interval), granularity: 1.0, queue: .mainQueue()))
    }
}
