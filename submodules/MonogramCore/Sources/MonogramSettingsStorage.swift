import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

private let monogramSettingsKeyValue: Int32 = 0x4d4f4e01

public enum MonogramSettingsKeys {
    public static let global: EngineDataBuffer = applicationSpecificSharedDataKey(monogramSettingsKeyValue)
    public static let account: EngineDataBuffer = applicationSpecificPreferencesKey(monogramSettingsKeyValue)
}

public func monogramGlobalSettings(
    accountManager: AccountManager<TelegramAccountManagerTypes>
) -> Signal<MonogramSettings, NoError> {
    return accountManager.sharedData(keys: [MonogramSettingsKeys.global])
    |> map { view -> MonogramSettings in
        let settings = view.entries[MonogramSettingsKeys.global]?.get(MonogramSettings.self) ?? MonogramSettings()
        return settings.migratedToCurrentSchema()
    }
    |> distinctUntilChanged
}

public func updateMonogramGlobalSettingsInteractively(
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    _ f: @escaping (MonogramSettings) -> MonogramSettings
) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(MonogramSettingsKeys.global, { entry in
            let current = (entry?.get(MonogramSettings.self) ?? MonogramSettings()).migratedToCurrentSchema()
            return SharedPreferencesEntry(f(current).migratedToCurrentSchema())
        })
    }
}

public func monogramAccountSettings(postbox: Postbox) -> Signal<MonogramSettings, NoError> {
    return postbox.preferencesView(keys: [MonogramSettingsKeys.account])
    |> map { view -> MonogramSettings in
        let settings = view.values[MonogramSettingsKeys.account]?.get(MonogramSettings.self) ?? MonogramSettings()
        return settings.migratedToCurrentSchema()
    }
    |> distinctUntilChanged
}

public func updateMonogramAccountSettingsInteractively(
    postbox: Postbox,
    _ f: @escaping (MonogramSettings) -> MonogramSettings
) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: MonogramSettingsKeys.account, { entry in
            let current = (entry?.get(MonogramSettings.self) ?? MonogramSettings()).migratedToCurrentSchema()
            return PreferencesEntry(f(current).migratedToCurrentSchema())
        })
    }
}

