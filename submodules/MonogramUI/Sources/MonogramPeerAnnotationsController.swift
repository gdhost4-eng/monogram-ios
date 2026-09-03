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

    static func == (lhs: MonogramPeerAnnotationsEntry, rhs: MonogramPeerAnnotationsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.search(lhsValue), .search(rhsValue)):
            return lhsValue == rhsValue
        case let (.empty(lhsValue), .empty(rhsValue)):
            return lhsValue == rhsValue
        case let (.annotation(lhsIndex, lhsValue), .annotation(rhsIndex, rhsValue)):
            return lhsIndex == rhsIndex && lhsValue == rhsValue
        default:
            return false
        }
    }

    static func < (lhs: MonogramPeerAnnotationsEntry, rhs: MonogramPeerAnnotationsEntry) -> Bool {
        return lhs.order < rhs.order
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramPeerAnnotationsArguments
        switch self {
        case let .search(value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: value, placeholder: "Поиск по заметкам и тегам", type: .regular(capitalization: false, autocorrection: false), returnKeyType: .done, clearType: .always, sectionId: self.section, textUpdated: arguments.updateQuery, action: {})
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .annotation(_, value):
            let label = value.note ?? value.tags.map { "#\($0)" }.joined(separator: " ")
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Чат \(value.peerId.toInt64())", label: label, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, action: { arguments.open(value) })
        }
    }
}

public func monogramPeerAnnotationsController(context: AccountContext) -> ViewController {
    var pushController: ((ViewController) -> Void)?
    let query = ValuePromise<String>("", ignoreRepeated: true)
    let values = query.get() |> mapToSignal { searchMonogramPeerAnnotations(postbox: context.account.postbox, query: $0) }
    let arguments = MonogramPeerAnnotationsArguments(updateQuery: { query.set($0) }, open: { annotation in
        pushController?(monogramPeerAnnotationEditorController(
            context: context,
            peerId: annotation.peerId,
            annotation: annotation,
            allowsNote: true,
            allowsTags: MonogramRuntimePolicy.isEnabled(.customTags, accountPeerId: context.account.peerId)
        ))
    })
    let signal = combineLatest(context.sharedContext.presentationData, query.get(), values)
    |> deliverOnMainQueue
    |> map { presentationData, queryValue, annotations -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [MonogramPeerAnnotationsEntry] = [.search(queryValue)]
        if annotations.isEmpty {
            entries.append(.empty(queryValue.isEmpty ? "Локальных заметок пока нет." : "Ничего не найдено."))
        } else {
            entries.append(contentsOf: annotations.enumerated().map { .annotation($0.offset, $0.element) })
        }
        return (
            ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Заметки и теги"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)),
            (ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true), arguments)
        )
    }
    let controller = ItemListController(context: context, state: signal)
    pushController = { [weak controller] in controller?.push($0) }
    return controller
}
