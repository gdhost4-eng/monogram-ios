import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import MonogramCore

private final class MonogramBookmarksControllerArguments {
    let updateQuery: (String) -> Void
    let editBookmark: (MonogramBookmark) -> Void

    init(updateQuery: @escaping (String) -> Void, editBookmark: @escaping (MonogramBookmark) -> Void) {
        self.updateQuery = updateQuery
        self.editBookmark = editBookmark
    }
}

private enum MonogramBookmarksEntryId: Hashable {
    case search
    case empty
    case bookmark(UUID)
}

private enum MonogramBookmarksEntry: ItemListNodeEntry {
    case search(text: String, placeholder: String)
    case empty(text: String)
    case bookmark(index: Int, value: MonogramBookmark, title: String, label: String)

    var section: ItemListSectionId {
        switch self {
        case .search:
            return 0
        case .empty, .bookmark:
            return 1
        }
    }

    var stableId: MonogramBookmarksEntryId {
        switch self {
        case .search:
            return .search
        case .empty:
            return .empty
        case let .bookmark(_, value, _, _):
            return .bookmark(value.id)
        }
    }

    private var sortIndex: Int {
        switch self {
        case .search:
            return 0
        case .empty:
            return 1
        case let .bookmark(index, _, _, _):
            return index + 2
        }
    }

    static func <(lhs: MonogramBookmarksEntry, rhs: MonogramBookmarksEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MonogramBookmarksControllerArguments
        switch self {
        case let .search(text, placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(),
                text: text,
                placeholder: placeholder,
                type: .regular(capitalization: false, autocorrection: false),
                returnKeyType: .done,
                clearType: .always,
                sectionId: self.section,
                textUpdated: arguments.updateQuery,
                action: {}
            )
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .bookmark(_, value, title, label):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                label: label,
                labelStyle: .multilineDetailText,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.editBookmark(value)
                }
            )
        }
    }
}

private func monogramBookmarksEntries(
    presentationData: PresentationData,
    query: String,
    bookmarks: [MonogramBookmark]
) -> [MonogramBookmarksEntry] {
    var entries: [MonogramBookmarksEntry] = [
        .search(text: query, placeholder: presentationData.strings.Monogram_Bookmarks_Search),
    ]
    if bookmarks.isEmpty {
        entries.append(.empty(text: query.isEmpty ? presentationData.strings.Monogram_Bookmarks_Empty : presentationData.strings.Monogram_Bookmarks_NoResults))
        return entries
    }

    entries.append(contentsOf: bookmarks.enumerated().map { index, bookmark in
        let title = "\(presentationData.strings.Monogram_Bookmarks_Message) #\(bookmark.messageId.id)"
        let label: String
        if let note = bookmark.note {
            label = note
        } else if !bookmark.tags.isEmpty {
            label = bookmark.tags.map { "#\($0)" }.joined(separator: " ")
        } else {
            label = "\(presentationData.strings.Monogram_Bookmarks_Peer) \(bookmark.messageId.peerId.toInt64())"
        }
        return .bookmark(index: index, value: bookmark, title: title, label: label)
    })
    return entries
}

public func monogramBookmarksController(
    context: AccountContext,
    openMessage: @escaping (MessageId) -> Void
) -> ViewController {
    var pushController: ((ViewController) -> Void)?
    let queryPromise = ValuePromise<String>("", ignoreRepeated: true)
    let filteredBookmarks = queryPromise.get()
    |> mapToSignal { query in
        return searchMonogramBookmarks(postbox: context.account.postbox, query: query)
        |> map { (query, $0) }
    }
    let arguments = MonogramBookmarksControllerArguments(updateQuery: { query in
        queryPromise.set(query)
    }, editBookmark: { bookmark in
        pushController?(monogramBookmarkEditorController(context: context, bookmark: bookmark, openMessage: {
            openMessage(bookmark.messageId)
        }))
    })
    let signal = combineLatest(
        context.sharedContext.presentationData,
        filteredBookmarks
    )
    |> deliverOnMainQueue
    |> map { presentationData, searchResult -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(presentationData.strings.Monogram_Bookmarks_Title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: monogramBookmarksEntries(presentationData: presentationData, query: searchResult.0, bookmarks: searchResult.1),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushController = { [weak controller] childController in
        controller?.push(childController)
    }
    return controller
}
