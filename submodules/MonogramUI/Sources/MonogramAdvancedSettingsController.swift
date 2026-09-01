import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import PresentationDataUtils
import MonogramCore

private final class MonogramAdvancedSettingsControllerArguments {
    let update: (MonogramSettingScope, MonogramFeatureId, Bool) -> Void
    let openBookmarks: () -> Void

    init(
        update: @escaping (MonogramSettingScope, MonogramFeatureId, Bool) -> Void,
        openBookmarks: @escaping () -> Void
    ) {
        self.update = update
        self.openBookmarks = openBookmarks
    }
}

private enum MonogramAdvancedSettingsEntry: ItemListNodeEntry {
    case header(section: Int32, stableId: Int32, text: String)
    case toggle(section: Int32, stableId: Int32, scope: MonogramSettingScope, id: MonogramFeatureId, title: String, value: Bool)
    case navigation(section: Int32, stableId: Int32, title: String, label: String)
    case footer(section: Int32, stableId: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .toggle(section, _, _, _, _, _), let .navigation(section, _, _, _), let .footer(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, stableId, _), let .toggle(_, stableId, _, _, _, _), let .navigation(_, stableId, _, _), let .footer(_, stableId, _):
            return stableId
        }
    }

    static func ==(lhs: MonogramAdvancedSettingsEntry, rhs: MonogramAdvancedSettingsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(lhsSection, lhsId, lhsText), .header(rhsSection, rhsId, rhsText)):
            return lhsSection == rhsSection && lhsId == rhsId && lhsText == rhsText
        case let (.toggle(lhsSection, lhsStableId, lhsScope, lhsId, lhsTitle, lhsValue), .toggle(rhsSection, rhsStableId, rhsScope, rhsId, rhsTitle, rhsValue)):
            return lhsSection == rhsSection && lhsStableId == rhsStableId && lhsScope == rhsScope && lhsId == rhsId && lhsTitle == rhsTitle && lhsValue == rhsValue
        case let (.navigation(lhsSection, lhsStableId, lhsTitle, lhsLabel), .navigation(rhsSection, rhsStableId, rhsTitle, rhsLabel)):
            return lhsSection == rhsSection && lhsStableId == rhsStableId && lhsTitle == rhsTitle && lhsLabel == rhsLabel
        case let (.footer(lhsSection, lhsId, lhsText), .footer(rhsSection, rhsId, rhsText)):
            return lhsSection == rhsSection && lhsId == rhsId && lhsText == rhsText
        default:
            return false
        }
    }

    static func <(lhs: MonogramAdvancedSettingsEntry, rhs: MonogramAdvancedSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramAdvancedSettingsControllerArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, scope, id, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.update(scope, id, value)
            })
        case let .navigation(_, _, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openBookmarks()
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func monogramFeatureTitle(id: MonogramFeatureId, strings: PresentationStrings) -> String {
    switch id {
    case .advancedSettings:
        return strings.Monogram_AdvancedSettings_Title
    case .appearanceEnhancements:
        return strings.Monogram_AdvancedSettings_Appearance
    case .localBookmarks:
        return strings.Monogram_AdvancedSettings_Bookmarks
    case .localNotes:
        return strings.Monogram_AdvancedSettings_Notes
    case .customTags:
        return strings.Monogram_AdvancedSettings_Tags
    case .searchEnhancements:
        return strings.Monogram_AdvancedSettings_Search
    case .translationControls:
        return strings.Monogram_AdvancedSettings_Translation
    case .powerUserInformation:
        return strings.Monogram_AdvancedSettings_PowerUser
    case .mediaEnhancements:
        return strings.Monogram_AdvancedSettings_Media
    case .storageEnhancements:
        return strings.Monogram_AdvancedSettings_Storage
    case .developerTools:
        return strings.Monogram_AdvancedSettings_DeveloperTools
    }
}

private func monogramAdvancedSettingsEntries(
    presentationData: PresentationData,
    globalSettings: MonogramSettings,
    accountSettings: MonogramSettings,
    bookmarksCount: Int
) -> [MonogramAdvancedSettingsEntry] {
    var entries: [MonogramAdvancedSettingsEntry] = []
    var stableId: Int32 = 0

    let globalFeatures = MonogramFeatureRegistry.all.filter { descriptor in
        return descriptor.id != .advancedSettings && !descriptor.isExperimental && descriptor.scopes.contains(.global)
    }
    let accountFeatures = MonogramFeatureRegistry.all.filter { descriptor in
        return !descriptor.isExperimental && !descriptor.scopes.contains(.global) && descriptor.scopes.contains(.account)
    }
    let experimentalFeatures = MonogramFeatureRegistry.all.filter { descriptor in
        return descriptor.isExperimental
    }

    if !globalFeatures.isEmpty {
        entries.append(.header(section: 0, stableId: stableId, text: presentationData.strings.Monogram_AdvancedSettings_GlobalHeader))
        stableId += 1
        for descriptor in globalFeatures {
            entries.append(.toggle(section: 0, stableId: stableId, scope: .global, id: descriptor.id, title: monogramFeatureTitle(id: descriptor.id, strings: presentationData.strings), value: globalSettings.isEnabled(descriptor.id)))
            stableId += 1
        }
        entries.append(.footer(section: 0, stableId: stableId, text: presentationData.strings.Monogram_AdvancedSettings_GlobalFooter))
        stableId += 1
    }

    if !accountFeatures.isEmpty {
        entries.append(.header(section: 1, stableId: stableId, text: presentationData.strings.Monogram_AdvancedSettings_AccountHeader))
        stableId += 1
        for descriptor in accountFeatures {
            entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: descriptor.id, title: monogramFeatureTitle(id: descriptor.id, strings: presentationData.strings), value: accountSettings.isEnabled(descriptor.id)))
            stableId += 1
        }
        if accountSettings.isEnabled(.localBookmarks) {
            entries.append(.navigation(section: 1, stableId: stableId, title: presentationData.strings.Monogram_Bookmarks_Manage, label: "\(bookmarksCount)"))
            stableId += 1
        }
        entries.append(.footer(section: 1, stableId: stableId, text: presentationData.strings.Monogram_AdvancedSettings_AccountFooter))
        stableId += 1
    }

    if !experimentalFeatures.isEmpty {
        entries.append(.header(section: 2, stableId: stableId, text: presentationData.strings.Monogram_AdvancedSettings_ExperimentalHeader))
        stableId += 1
        for descriptor in experimentalFeatures {
            entries.append(.toggle(section: 2, stableId: stableId, scope: .global, id: descriptor.id, title: monogramFeatureTitle(id: descriptor.id, strings: presentationData.strings), value: globalSettings.isEnabled(descriptor.id)))
            stableId += 1
        }
        entries.append(.footer(section: 2, stableId: stableId, text: presentationData.strings.Monogram_AdvancedSettings_ExperimentalFooter))
    }

    return entries
}

public func monogramAdvancedSettingsController(context: AccountContext) -> ViewController {
    var pushController: ((ViewController) -> Void)?
    var currentNavigationController: (() -> NavigationController?)?

    let arguments = MonogramAdvancedSettingsControllerArguments(update: { scope, id, value in
        switch scope {
        case .global:
            let _ = updateMonogramGlobalSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.setEnabled(value, for: id)
                return settings
            }).start()
        case .account:
            let _ = updateMonogramAccountSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.setEnabled(value, for: id)
                return settings
            }).start()
        case .chat:
            break
        }
    }, openBookmarks: {
        let bookmarksController = monogramBookmarksController(context: context, openMessage: { messageId in
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { peer in
                guard let peer, let navigationController = currentNavigationController?() else {
                    return
                }
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                    navigationController: navigationController,
                    context: context,
                    chatLocation: .peer(peer),
                    subject: .message(
                        id: .id(messageId),
                        highlight: ChatControllerSubject.MessageHighlight(quote: nil),
                        timecode: nil,
                        setupReply: false
                    ),
                    useExisting: true
                ))
            })
        })
        pushController?(bookmarksController)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        monogramGlobalSettings(accountManager: context.sharedContext.accountManager),
        monogramAccountSettings(postbox: context.account.postbox),
        monogramBookmarks(postbox: context.account.postbox) |> map { $0.count }
    )
    |> map { presentationData, globalSettings, accountSettings, bookmarksCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(presentationData.strings.Monogram_AdvancedSettings_Title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramAdvancedSettingsEntries(presentationData: presentationData, globalSettings: globalSettings, accountSettings: accountSettings, bookmarksCount: bookmarksCount),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    pushController = { [weak controller] childController in
        controller?.push(childController)
    }
    currentNavigationController = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
