import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import TextFormat

private final class MonogramEditHistoryControllerArguments {
    let copy: (String) -> Void

    init(copy: @escaping (String) -> Void) {
        self.copy = copy
    }
}

private enum MonogramEditHistoryEntry: ItemListNodeEntry {
    case version(index: Int32, label: String, text: String, isCurrent: Bool)
    case footer(index: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case .version:
            return 0
        case .footer:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case let .version(index, _, _, _), let .footer(index, _):
            return index
        }
    }

    static func <(lhs: MonogramEditHistoryEntry, rhs: MonogramEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramEditHistoryControllerArguments
        switch self {
        case let .version(_, label, text, isCurrent):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: label, text: text.isEmpty ? "(без текста)" : text, style: .blocks, labelColor: isCurrent ? .accent : .primary, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: {
                arguments.copy(text)
            })
        case let .footer(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

func monogramFormatDate(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
}

/// All known versions of an edited message: the previous ones (oldest first) and the current one.
public func monogramEditHistoryController(context: AccountContext, message: EngineMessage) -> ViewController {
    var entries: [MonogramEditHistoryEntry] = []
    var index: Int32 = 0
    for entry in message.monogramEditHistory {
        entries.append(.version(index: index, label: "Изменено \(monogramFormatDate(entry.date))", text: entry.text, isCurrent: false))
        index += 1
    }
    entries.append(.version(index: index, label: "Сейчас", text: message.text, isCurrent: true))
    index += 1
    entries.append(.footer(index: index, text: "Сверху — отправленная версия, у каждой подписано, когда её заменили. Нажмите на версию, чтобы скопировать текст."))

    var presentUndoImpl: ((UndoOverlayContent) -> Void)?
    let arguments = MonogramEditHistoryControllerArguments(copy: { text in
        UIPasteboard.general.string = text
        presentUndoImpl?(.copy(text: "Текст скопирован"))
    })

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("История изменений"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentUndoImpl = { [weak controller] content in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, action: { _ in
            return false
        }), in: .current)
    }
    return controller
}
