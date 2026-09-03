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
import AlertUI

private enum MonogramSettingsNavigationAction: Equatable {
    case ghostDuration
    case bookmarks
    case annotations
    case clearDeleted
}

private final class MonogramAdvancedSettingsControllerArguments {
    let update: (MonogramSettingScope, MonogramFeatureId, Bool) -> Void
    let openBookmarks: () -> Void
    let configureGhostDuration: () -> Void
    let openAnnotations: () -> Void
    let clearDeleted: () -> Void

    init(
        update: @escaping (MonogramSettingScope, MonogramFeatureId, Bool) -> Void,
        openBookmarks: @escaping () -> Void,
        configureGhostDuration: @escaping () -> Void,
        openAnnotations: @escaping () -> Void,
        clearDeleted: @escaping () -> Void
    ) {
        self.update = update
        self.openBookmarks = openBookmarks
        self.configureGhostDuration = configureGhostDuration
        self.openAnnotations = openAnnotations
        self.clearDeleted = clearDeleted
    }
}

private enum MonogramAdvancedSettingsEntry: ItemListNodeEntry {
    case header(section: Int32, stableId: Int32, text: String)
    case toggle(section: Int32, stableId: Int32, scope: MonogramSettingScope, id: MonogramFeatureId, title: String, value: Bool)
    case navigation(section: Int32, stableId: Int32, title: String, label: String, action: MonogramSettingsNavigationAction)
    case footer(section: Int32, stableId: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .toggle(section, _, _, _, _, _), let .navigation(section, _, _, _, _), let .footer(section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(_, stableId, _), let .toggle(_, stableId, _, _, _, _), let .navigation(_, stableId, _, _, _), let .footer(_, stableId, _):
            return stableId
        }
    }

    static func ==(lhs: MonogramAdvancedSettingsEntry, rhs: MonogramAdvancedSettingsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(lhsSection, lhsId, lhsText), .header(rhsSection, rhsId, rhsText)):
            return lhsSection == rhsSection && lhsId == rhsId && lhsText == rhsText
        case let (.toggle(lhsSection, lhsStableId, lhsScope, lhsId, lhsTitle, lhsValue), .toggle(rhsSection, rhsStableId, rhsScope, rhsId, rhsTitle, rhsValue)):
            return lhsSection == rhsSection && lhsStableId == rhsStableId && lhsScope == rhsScope && lhsId == rhsId && lhsTitle == rhsTitle && lhsValue == rhsValue
        case let (.navigation(lhsSection, lhsStableId, lhsTitle, lhsLabel, lhsAction), .navigation(rhsSection, rhsStableId, rhsTitle, rhsLabel, rhsAction)):
            return lhsSection == rhsSection && lhsStableId == rhsStableId && lhsTitle == rhsTitle && lhsLabel == rhsLabel && lhsAction == rhsAction
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
        case let .navigation(_, _, title, label, action):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                switch action {
                case .ghostDuration:
                    arguments.configureGhostDuration()
                case .bookmarks:
                    arguments.openBookmarks()
                case .annotations:
                    arguments.openAnnotations()
                case .clearDeleted:
                    arguments.clearDeleted()
                }
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func monogramFeatureTitle(id: MonogramFeatureId, strings: PresentationStrings) -> String {
    switch id {
    case .advancedSettings:
        return "Monogram"
    case .ghostMode:
        return "Ghost Mode"
    case .ghostReadReceipts:
        return "Не отправлять отметки о прочтении"
    case .ghostTypingActivity:
        return "Скрывать набор текста и запись"
    case .preserveDeletedMessages:
        return "Сохранять удалённые сообщения"
    case .preserveEditHistory:
        return "История редактирования"
    case .localBookmarks:
        return strings.Monogram_AdvancedSettings_Bookmarks
    case .localNotes:
        return strings.Monogram_AdvancedSettings_Notes
    case .customTags:
        return strings.Monogram_AdvancedSettings_Tags
    case .powerUserInformation:
        return strings.Monogram_AdvancedSettings_PowerUser
    case .localMessagePins:
        return "Локальные закрепления"
    case .confirmVoiceMessages:
        return "Подтверждать голосовые сообщения"
    case .suppressAutomaticKeyboard:
        return "Не открывать клавиатуру автоматически"
    case .confirmAccountBeforeSending:
        return "Проверять аккаунт перед отправкой"
    case .suppressIncomingAutoScroll:
        return "Не прокручивать чат при новых сообщениях"
    }
}

private func monogramAdvancedSettingsEntries(
    presentationData: PresentationData,
    accountSettings: MonogramSettings,
    bookmarksCount: Int,
    annotationsCount: Int,
    deletedCount: Int
) -> [MonogramAdvancedSettingsEntry] {
    var entries: [MonogramAdvancedSettingsEntry] = []
    var stableId: Int32 = 0

    entries.append(.header(section: 0, stableId: stableId, text: "ПРИВАТНОСТЬ"))
    stableId += 1
    entries.append(.toggle(section: 0, stableId: stableId, scope: .account, id: .ghostMode, title: monogramFeatureTitle(id: .ghostMode, strings: presentationData.strings), value: accountSettings.isEnabled(.ghostMode)))
    stableId += 1
    if accountSettings.isEnabled(.ghostMode) {
        let durationLabel: String
        if let expiresAt = accountSettings.ghostModeExpiresAt {
            let remaining = max(0, expiresAt - Int64(Date().timeIntervalSince1970))
            durationLabel = remaining >= 3600 ? "\((remaining + 3599) / 3600) ч" : "\((remaining + 59) / 60) мин"
        } else {
            durationLabel = "Постоянно"
        }
        entries.append(.navigation(section: 0, stableId: stableId, title: "Продолжительность", label: durationLabel, action: .ghostDuration))
        stableId += 1
        entries.append(.toggle(section: 0, stableId: stableId, scope: .account, id: .ghostReadReceipts, title: monogramFeatureTitle(id: .ghostReadReceipts, strings: presentationData.strings), value: accountSettings.isEnabled(.ghostReadReceipts)))
        stableId += 1
        entries.append(.toggle(section: 0, stableId: stableId, scope: .account, id: .ghostTypingActivity, title: monogramFeatureTitle(id: .ghostTypingActivity, strings: presentationData.strings), value: accountSettings.isEnabled(.ghostTypingActivity)))
        stableId += 1
    }
    entries.append(.footer(section: 0, stableId: stableId, text: "Ghost Mode не меняет серверные настройки «Последняя активность», но при работе приложения не публикует статус «в сети» и не отправляет события прочтения, набора текста и записи из открытого чата."))
    stableId += 1

    entries.append(.header(section: 1, stableId: stableId, text: "ЛОКАЛЬНЫЕ ДАННЫЕ"))
    stableId += 1
    entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: .preserveDeletedMessages, title: monogramFeatureTitle(id: .preserveDeletedMessages, strings: presentationData.strings), value: accountSettings.isEnabled(.preserveDeletedMessages)))
    stableId += 1
    if deletedCount > 0 {
        entries.append(.navigation(section: 1, stableId: stableId, title: "Очистить сохранённые сообщения", label: "\(deletedCount)", action: .clearDeleted))
        stableId += 1
    }
    entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: .preserveEditHistory, title: monogramFeatureTitle(id: .preserveEditHistory, strings: presentationData.strings), value: accountSettings.isEnabled(.preserveEditHistory)))
    stableId += 1
    entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: .localBookmarks, title: monogramFeatureTitle(id: .localBookmarks, strings: presentationData.strings), value: accountSettings.isEnabled(.localBookmarks)))
    stableId += 1
    entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: .localMessagePins, title: monogramFeatureTitle(id: .localMessagePins, strings: presentationData.strings), value: accountSettings.isEnabled(.localMessagePins)))
    stableId += 1
    if accountSettings.isEnabled(.localBookmarks) || accountSettings.isEnabled(.localMessagePins) {
        entries.append(.navigation(section: 1, stableId: stableId, title: presentationData.strings.Monogram_Bookmarks_Manage, label: "\(bookmarksCount)", action: .bookmarks))
        stableId += 1
    }
    entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: .localNotes, title: monogramFeatureTitle(id: .localNotes, strings: presentationData.strings), value: accountSettings.isEnabled(.localNotes)))
    stableId += 1
    if accountSettings.isEnabled(.localNotes) {
        entries.append(.toggle(section: 1, stableId: stableId, scope: .account, id: .customTags, title: monogramFeatureTitle(id: .customTags, strings: presentationData.strings), value: accountSettings.isEnabled(.customTags)))
        stableId += 1
        entries.append(.navigation(section: 1, stableId: stableId, title: "Управление заметками", label: "\(annotationsCount)", action: .annotations))
        stableId += 1
    }
    entries.append(.footer(section: 1, stableId: stableId, text: "Удалённые сообщения остаются на прежнем месте с пометкой. Повторное локальное удаление убирает сохранённую копию. Секретные, исчезающие и защищённые сообщения не сохраняются."))
    stableId += 1

    entries.append(.header(section: 2, stableId: stableId, text: "ПОВЕДЕНИЕ ЧАТОВ"))
    stableId += 1
    entries.append(.toggle(section: 2, stableId: stableId, scope: .account, id: .powerUserInformation, title: monogramFeatureTitle(id: .powerUserInformation, strings: presentationData.strings), value: accountSettings.isEnabled(.powerUserInformation)))
    stableId += 1
    entries.append(.toggle(section: 2, stableId: stableId, scope: .account, id: .confirmVoiceMessages, title: monogramFeatureTitle(id: .confirmVoiceMessages, strings: presentationData.strings), value: accountSettings.isEnabled(.confirmVoiceMessages)))
    stableId += 1
    entries.append(.toggle(section: 2, stableId: stableId, scope: .account, id: .suppressAutomaticKeyboard, title: monogramFeatureTitle(id: .suppressAutomaticKeyboard, strings: presentationData.strings), value: accountSettings.isEnabled(.suppressAutomaticKeyboard)))
    stableId += 1
    entries.append(.toggle(section: 2, stableId: stableId, scope: .account, id: .confirmAccountBeforeSending, title: monogramFeatureTitle(id: .confirmAccountBeforeSending, strings: presentationData.strings), value: accountSettings.isEnabled(.confirmAccountBeforeSending)))
    stableId += 1
    entries.append(.toggle(section: 2, stableId: stableId, scope: .account, id: .suppressIncomingAutoScroll, title: monogramFeatureTitle(id: .suppressIncomingAutoScroll, strings: presentationData.strings), value: accountSettings.isEnabled(.suppressIncomingAutoScroll)))
    stableId += 1
    entries.append(.footer(section: 2, stableId: stableId, text: "Технические идентификаторы появляются в контекстном меню. Подтверждение записи открывает предпросмотр. Проверка аккаунта показывает имя активного аккаунта перед каждой отправкой. Блокировка автопрокрутки сохраняет текущую позицию при входящих сообщениях."))

    return entries
}

public func monogramAdvancedSettingsController(context: AccountContext) -> ViewController {
    var pushController: ((ViewController) -> Void)?
    var presentController: ((ViewController) -> Void)?
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
                if id == .ghostMode {
                    settings.ghostModeExpiresAt = nil
                }
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
    }, configureGhostDuration: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let setDuration: (Int64?) -> Void = { duration in
            let _ = updateMonogramAccountSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.ghostModeExpiresAt = duration.flatMap { Int64(Date().timeIntervalSince1970) + $0 }
                return settings
            }).start()
        }
        presentController?(textAlertController(
            context: context,
            title: "Продолжительность Ghost Mode",
            text: "После истечения времени обычная отправка статусов возобновится автоматически.",
            actions: [
                TextAlertAction(type: .genericAction, title: "15 минут", action: { setDuration(15 * 60) }),
                TextAlertAction(type: .genericAction, title: "1 час", action: { setDuration(60 * 60) }),
                TextAlertAction(type: .genericAction, title: "До отключения", action: { setDuration(nil) }),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})
            ],
            actionLayout: .vertical
        ))
    }, openAnnotations: {
        pushController?(monogramPeerAnnotationsController(context: context))
    }, clearDeleted: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentController?(textAlertController(
            context: context,
            title: "Очистить сохранённые сообщения?",
            text: "Локальные копии исчезнут из чатов. Это действие нельзя отменить.",
            actions: [
                TextAlertAction(type: .destructiveAction, title: "Очистить", action: {
                    let _ = MonogramDeletedMessageTransform.clear(postbox: context.account.postbox).start()
                }),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})
            ],
            actionLayout: .vertical
        ))
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        monogramAccountSettings(postbox: context.account.postbox),
        monogramBookmarks(postbox: context.account.postbox) |> map { $0.count },
        monogramPeerAnnotations(postbox: context.account.postbox) |> map { $0.count },
        MonogramDeletedMessageTransform.records(postbox: context.account.postbox) |> map { $0.count }
    )
    |> map { presentationData, accountSettings, bookmarksCount, annotationsCount, deletedCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Monogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramAdvancedSettingsEntries(presentationData: presentationData, accountSettings: accountSettings, bookmarksCount: bookmarksCount, annotationsCount: annotationsCount, deletedCount: deletedCount),
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
    presentController = { [weak controller] childController in
        controller?.present(childController, in: .window(.root))
    }
    currentNavigationController = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
