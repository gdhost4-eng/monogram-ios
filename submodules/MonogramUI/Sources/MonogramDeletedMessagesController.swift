import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class MonogramDeletedMessagesControllerArguments {
    let open: (EngineMessage.Id) -> Void

    init(open: @escaping (EngineMessage.Id) -> Void) {
        self.open = open
    }
}

private enum MonogramDeletedMessagesEntry: ItemListNodeEntry {
    case message(index: Int32, id: EngineMessage.Id, label: String, text: String)
    case footer(index: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case .message:
            return 0
        case .footer:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case let .message(index, _, _, _), let .footer(index, _):
            return index
        }
    }

    static func <(lhs: MonogramDeletedMessagesEntry, rhs: MonogramDeletedMessagesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramDeletedMessagesControllerArguments
        switch self {
        case let .message(_, id, label, text):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: label, text: text, style: .blocks, labelColor: .accent, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: {
                arguments.open(id)
            })
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// What a message without text is called in the list.
private func monogramDeletedMessageMediaTitle(_ message: EngineMessage) -> String? {
    for media in message.media {
        if media is TelegramMediaImage {
            return "Фото"
        } else if let file = media as? TelegramMediaFile {
            if file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                return "Стикер"
            } else if file.isInstantVideo {
                return "Кружок"
            } else if file.isVoice {
                return "Голосовое сообщение"
            } else if file.isAnimated {
                return "GIF"
            } else if file.isVideo {
                return "Видео"
            } else if file.isMusic {
                return "Музыка"
            } else if let fileName = file.fileName, !fileName.isEmpty {
                return fileName
            } else {
                return "Файл"
            }
        } else if media is TelegramMediaMap {
            return "Геопозиция"
        } else if media is TelegramMediaContact {
            return "Контакт"
        } else if media is TelegramMediaPoll {
            return "Опрос"
        }
    }
    return nil
}

private func monogramDeletedMessageText(_ message: EngineMessage) -> String {
    let mediaTitle = monogramDeletedMessageMediaTitle(message)
    if message.text.isEmpty {
        return mediaTitle ?? "(без текста)"
    } else if let mediaTitle {
        return "\(mediaTitle)\n\(message.text)"
    } else {
        return message.text
    }
}

/// The messages of the chat that were deleted on the server and kept by Monogram, newest first.
/// A tap opens the chat at the message.
public func monogramDeletedMessagesController(context: AccountContext, peerId: EnginePeer.Id) -> ViewController {
    var openImpl: ((EngineMessage.Id) -> Void)?
    let arguments = MonogramDeletedMessagesControllerArguments(open: { messageId in
        openImpl?(messageId)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.messages.monogramDeletedMessages(peerId: peerId)
    )
    |> map { presentationData, messages -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [MonogramDeletedMessagesEntry] = []
        var index: Int32 = 0
        for message in messages {
            var label = monogramFormatDate(message.timestamp)
            if let author = message.author {
                label = "\(author.debugDisplayTitle) · \(label)"
            }
            entries.append(.message(index: index, id: message.id, label: label, text: monogramDeletedMessageText(message)))
            index += 1
        }
        let title: String
        let footer: String
        if messages.isEmpty {
            title = "Удалённые сообщения"
            footer = "В этом чате нет сохранённых удалённых сообщений."
        } else {
            title = "Удалённые (\(messages.count))"
            footer = "Эти сообщения удалены на сервере и остались только на этом устройстве. Нажмите на сообщение, чтобы открыть его в чате."
        }
        entries.append(.footer(index: index, text: footer))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    openImpl = { [weak controller] messageId in
        guard let navigationController = controller?.navigationController as? NavigationController else {
            return
        }
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)))
        })
    }
    return controller
}
