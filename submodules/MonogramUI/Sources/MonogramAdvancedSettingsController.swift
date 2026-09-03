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

enum MonogramSettingsNavigationAction: Hashable {
    case ghostDuration
    case bookmarks
    case annotations
    case clearDeleted
}

final class MonogramAdvancedSettingsControllerArguments {
    let update: (MonogramFeatureId, Bool) -> Void
    let openBookmarks: () -> Void
    let configureGhostDuration: () -> Void
    let openAnnotations: () -> Void
    let clearDeleted: () -> Void

    init(
        update: @escaping (MonogramFeatureId, Bool) -> Void,
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

public func monogramAdvancedSettingsController(context: AccountContext) -> ViewController {
    var pushController: ((ViewController) -> Void)?
    var presentController: ((ViewController) -> Void)?
    var currentNavigationController: (() -> NavigationController?)?

    let arguments = MonogramAdvancedSettingsControllerArguments(update: { id, value in
        let _ = updateMonogramAccountSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.setEnabled(value, for: id)
            return settings
        }).start()
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
                settings.setGhostModeDuration(duration)
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
        monogramAccountSettings(postbox: context.account.postbox)
        |> mapToSignal { settings in
            return monogramSettingsRefreshTimestamp(settings: settings)
            |> map { (settings, $0) }
        },
        monogramBookmarks(postbox: context.account.postbox) |> map { $0.count } |> distinctUntilChanged,
        monogramPeerAnnotations(postbox: context.account.postbox) |> map { $0.count } |> distinctUntilChanged,
        MonogramDeletedMessageTransform.records(postbox: context.account.postbox) |> map { $0.count } |> distinctUntilChanged
    )
    |> deliverOnMainQueue
    |> map { presentationData, settingsAndTimestamp, bookmarksCount, annotationsCount, deletedCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Monogram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramAdvancedSettingsEntries(presentationData: presentationData, accountSettings: settingsAndTimestamp.0, timestamp: settingsAndTimestamp.1, bookmarksCount: bookmarksCount, annotationsCount: annotationsCount, deletedCount: deletedCount),
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

private func monogramSettingsRefreshTimestamp(settings: MonogramSettings) -> Signal<Int64, NoError> {
    return deferred {
        let timestamp = Int64(Date().timeIntervalSince1970)
        guard settings.isGhostModeActive(at: timestamp), let expiresAt = settings.ghostModeExpiresAt else {
            return .single(timestamp)
        }
        let remaining = expiresAt - timestamp
        // Refresh when the rounded label changes, including the exact expiry.
        let unit: Int64 = remaining > 3600 ? 3600 : 60
        let interval = remaining == 3600 ? 1 : (remaining - 1) % unit + 1
        return .single(timestamp)
        |> then(monogramSettingsRefreshTimestamp(settings: settings)
            |> suspendAwareDelay(Double(interval), granularity: 1.0, queue: .mainQueue()))
    }
}
