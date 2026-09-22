import Foundation
import UIKit
import TelegramPresentationData
import DeviceAccess

enum ApplicationShortcutItemType: String {
    case search
    case compose
    case camera
    case savedMessages
    case account
    case appIcon
    case ghostOn
    case ghostOff
}

struct ApplicationShortcutItem: Equatable {
    let type: ApplicationShortcutItemType
    let title: String
    let subtitle: String?
}

@available(iOS 9.1, *)
extension ApplicationShortcutItem {
    func shortcutItem() -> UIApplicationShortcutItem {
        let icon: UIApplicationShortcutIcon
        switch self.type {
            case .search:
                icon = UIApplicationShortcutIcon(type: .search)
            case .compose:
                icon = UIApplicationShortcutIcon(type: .compose)
            case .camera:
                icon = UIApplicationShortcutIcon(templateImageName: "Shortcuts/Camera")
            case .savedMessages:
                icon = UIApplicationShortcutIcon(templateImageName: "Shortcuts/SavedMessages")
            case .account:
                icon = UIApplicationShortcutIcon(templateImageName: "Shortcuts/Account")
            case .appIcon:
                icon = UIApplicationShortcutIcon(templateImageName: "Shortcuts/AppIcon")
            case .ghostOn:
                icon = UIApplicationShortcutIcon(systemImageName: "eye.slash")
            case .ghostOff:
                icon = UIApplicationShortcutIcon(systemImageName: "eye")
        }
        return UIApplicationShortcutItem(type: self.type.rawValue, localizedTitle: self.title, localizedSubtitle: self.subtitle, icon: icon, userInfo: nil)
    }
}

func applicationShortcutItems(strings: PresentationStrings, otherAccountName: String?, isGhostModeActive: Bool) -> [ApplicationShortcutItem] {
    // Monogram: entering ghost mode right from the home screen, before the app reports being online.
    let ghostItem: ApplicationShortcutItem
    if isGhostModeActive {
        ghostItem = ApplicationShortcutItem(type: .ghostOff, title: "Выключить режим призрака", subtitle: nil)
    } else {
        ghostItem = ApplicationShortcutItem(type: .ghostOn, title: "Войти призраком", subtitle: "Без «в сети» и «прочитано»")
    }
    if let otherAccountName = otherAccountName {
        return [
            ghostItem,
            ApplicationShortcutItem(type: .compose, title: strings.Compose_NewMessage, subtitle: nil),
            ApplicationShortcutItem(type: .savedMessages, title: strings.Conversation_SavedMessages, subtitle: nil),
            ApplicationShortcutItem(type: .account, title: strings.Shortcut_SwitchAccount, subtitle: otherAccountName)
        ]
    } else {
        return [
            ghostItem,
            ApplicationShortcutItem(type: .search, title: strings.Common_Search, subtitle: nil),
            ApplicationShortcutItem(type: .compose, title: strings.Compose_NewMessage, subtitle: nil),
            ApplicationShortcutItem(type: .savedMessages, title: strings.Conversation_SavedMessages, subtitle: nil)
        ]
    }
}
