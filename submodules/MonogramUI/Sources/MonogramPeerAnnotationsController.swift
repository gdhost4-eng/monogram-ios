import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ItemListUI
import MonogramCore

private final class MonogramPeerAnnotationsArguments {
    let updateQuery: (String) -> Void
    let open: (MonogramPeerAnnotation) -> Void

    init(updateQuery: @escaping (String) -> Void, open: @escaping (MonogramPeerAnnotation) -> Void) {
        self.updateQuery = updateQuery
        self.open = open
    }
}

private enum MonogramPeerAnnotationsEntryId: Hashable {
    case search
    case empty
    case annotation(PeerId)
}

private enum MonogramPeerAnnotationsEntry: ItemListNodeEntry {
    case search(String)
    case empty(String)
    case annotation(Int, MonogramPeerAnnotation)

    var section: ItemListSectionId {
        switch self {
        case .search:
            return 0
        case .empty, .annotation:
            return 1
        }
    }

    var stableId: MonogramPeerAnnotationsEntryId {
        switch self {
        case .search:
            return .search
        case .empty:
            return .empty
        case let .annotation(_, value):
            return .annotation(value.peerId)
        }
    }

    private var order: Int {
        switch self {
        case .search:
            return 0
        case .empty:
            return 1
        case let .annotation(index, _):
            return index + 2
        }
    }

    static func < (lhs: MonogramPeerAnnotationsEntry, rhs: MonogramPeerAnnotationsEntry) -> Bool {
        return lhs.order < rhs.order
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramPeerAnnotationsArguments
        switch self {
        case let .search(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: value, placeholder: "Поиск по заметкам", type: .regular(capitalization: false, autocorrection: false), returnKeyType: .done, clearType: .always, sectionId: self.section, textUpdated: arguments.updateQuery, action: {})
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .annotation(_, value):
            let label = value.note ?? ""
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Чат \(value.peerId.toInt64())", label: label, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, action: { arguments.open(value) })
        }
    }
}

private func monogramPeerAnnotationsEntries(query: String, annotations: [MonogramPeerAnnotation]) -> [MonogramPeerAnnotationsEntry] {
    var entries: [MonogramPeerAnnotationsEntry] = [.search(query)]
    if annotations.isEmpty {
        entries.append(.empty(query.isEmpty ? "Локальных заметок пока нет." : "Ничего не найдено."))
    } else {
        entries.append(contentsOf: annotations.enumerated().map { .annotation($0.offset, $0.element) })
    }
    return entries
}

public func monogramPeerAnnotationsController(context: AccountContext) -> ViewController {
    let navigation = MonogramControllerNavigation()
    let query = ValuePromise<String>("", ignoreRepeated: true)
    let values = query.get()
    |> mapToSignal { query in
        return searchMonogramPeerAnnotations(postbox: context.account.postbox, query: query)
        |> map { (query, $0) }
    }
    let arguments = MonogramPeerAnnotationsArguments(updateQuery: { query.set($0) }, open: { annotation in
        navigation.push(monogramPeerAnnotationEditorController(
            context: context,
            peerId: annotation.peerId,
            annotation: annotation
        ))
    })
    let signal = combineLatest(context.sharedContext.presentationData, values)
    |> deliverOnMainQueue
    |> map { presentationData, searchResult -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = monogramPeerAnnotationsEntries(query: searchResult.0, annotations: searchResult.1)
        return (
            ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Локальные заметки"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)),
            (ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true), arguments)
        )
    }
    let controller = ItemListController(context: context, state: signal)
    navigation.controller = controller
    return controller
}
