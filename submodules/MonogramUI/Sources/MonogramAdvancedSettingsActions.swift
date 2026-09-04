import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import MonogramCore

enum MonogramSettingsNavigationAction: Hashable {
    case ghostDuration
    case bookmarks
    case annotations
    case clearDeleted
}

private enum MonogramGhostDuration: CaseIterable {
    case fifteenMinutes
    case oneHour
    case untilDisabled

    var title: String {
        switch self {
        case .fifteenMinutes: return "15 минут"
        case .oneHour: return "1 час"
        case .untilDisabled: return "До отключения"
        }
    }

    var seconds: Int64? {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .oneHour: return 60 * 60
        case .untilDisabled: return nil
        }
    }
}

final class MonogramAdvancedSettingsActions {
    private let context: AccountContext
    let navigation = MonogramControllerNavigation()

    init(context: AccountContext) {
        self.context = context
    }

    func update(_ id: MonogramFeatureId, _ value: Bool) {
        self.updateSettings { $0.setEnabled(value, for: id) }
    }

    func open(_ action: MonogramSettingsNavigationAction) {
        switch action {
        case .ghostDuration:
            self.configureGhostDuration()
        case .bookmarks:
            self.navigation.push(monogramBookmarksController(context: self.context, openMessage: { [weak self] messageId in
                self?.openMessage(messageId)
            }))
        case .annotations:
            self.navigation.push(monogramPeerAnnotationsController(context: self.context))
        case .clearDeleted:
            self.clearDeleted()
        }
    }

    private func updateSettings(_ update: @escaping (inout MonogramSettings) -> Void) {
        let _ = updateMonogramAccountSettingsInteractively(postbox: self.context.account.postbox, { settings in
            var settings = settings
            update(&settings)
            return settings
        }).start()
    }

    private func openMessage(_ messageId: MessageId) {
        let context = self.context
        let navigation = self.navigation
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer, let navigationController = navigation.navigationController else {
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
    }

    private func configureGhostDuration() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var actions = MonogramGhostDuration.allCases.map { duration in
            return TextAlertAction(type: .genericAction, title: duration.title, action: {
                self.updateSettings { $0.setGhostModeDuration(duration.seconds) }
            })
        }
        actions.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}))
        self.navigation.present(textAlertController(
            context: self.context,
            title: "Продолжительность Ghost Mode",
            text: "После истечения времени обычная отправка статусов возобновится автоматически.",
            actions: actions,
            actionLayout: .vertical
        ))
    }

    private func clearDeleted() {
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.navigation.present(textAlertController(
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
    }
}
