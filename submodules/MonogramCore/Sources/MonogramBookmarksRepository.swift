import Foundation
import Postbox
import SwiftSignalKit

private let monogramBookmarksCollectionId: Int32 = 0x4d4f4201

private func monogramBookmarkItemId(_ id: UUID) -> MemoryBuffer {
    return MemoryBuffer(data: Data(id.uuidString.utf8))
}

private func monogramBookmark(from entry: OrderedItemListEntry) -> MonogramBookmark? {
    return entry.contents.get(MonogramBookmark.self)
}

public func monogramBookmarks(postbox: Postbox) -> Signal<[MonogramBookmark], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: monogramBookmarksCollectionId)
    return postbox.combinedView(keys: [viewKey])
    |> map { view -> [MonogramBookmark] in
        guard let orderedView = view.views[viewKey] as? OrderedItemListView else {
            return []
        }
        return orderedView.items.compactMap { monogramBookmark(from: $0) }
    }
}

public func monogramBookmark(postbox: Postbox, messageId: MessageId) -> Signal<MonogramBookmark?, NoError> {
    return monogramBookmarks(postbox: postbox)
    |> map { bookmarks in
        return bookmarks.first(where: { $0.messageId == messageId })
    }
}

public func searchMonogramBookmarks(
    postbox: Postbox,
    query: String,
    tags: [String] = []
) -> Signal<[MonogramBookmark], NoError> {
    return monogramBookmarks(postbox: postbox)
    |> map { bookmarks in
        return bookmarks.filter { bookmark in
            return bookmark.matches(query: query, tags: tags)
        }
    }
}

public func setMonogramBookmark(
    postbox: Postbox,
    messageId: MessageId,
    note: String?,
    tags: [String],
    isCopyProtected: Bool,
    isEphemeral: Bool,
    timestamp: Int64 = Int64(Date().timeIntervalSince1970)
) -> Signal<MonogramBookmark?, NoError> {
    if MonogramLocalDataPolicy.bookmarkDenialReason(messageId: messageId, isCopyProtected: isCopyProtected, isEphemeral: isEphemeral) != nil {
        return .single(nil)
    }
    return postbox.transaction { transaction -> MonogramBookmark? in
        let existing = transaction.getOrderedListItems(collectionId: monogramBookmarksCollectionId).compactMap { monogramBookmark(from: $0) }.first(where: { bookmark in
            return bookmark.messageId == messageId
        })
        let bookmark = MonogramBookmark(
            id: existing?.id ?? UUID(),
            messageId: messageId,
            note: note,
            tags: tags,
            createdAt: existing?.createdAt ?? timestamp,
            updatedAt: timestamp
        )
        guard let contents = CodableEntry(bookmark) else {
            return nil
        }
        transaction.addOrMoveToFirstPositionOrderedItemListItem(
            collectionId: monogramBookmarksCollectionId,
            item: OrderedItemListEntry(id: monogramBookmarkItemId(bookmark.id), contents: contents),
            removeTailIfCountExceeds: nil
        )
        return bookmark
    }
}

public func removeMonogramBookmark(postbox: Postbox, id: UUID) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.removeOrderedItemListItem(collectionId: monogramBookmarksCollectionId, itemId: monogramBookmarkItemId(id))
    }
}

public func removeMonogramBookmark(postbox: Postbox, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        for entry in transaction.getOrderedListItems(collectionId: monogramBookmarksCollectionId) {
            if monogramBookmark(from: entry)?.messageId == messageId {
                transaction.removeOrderedItemListItem(collectionId: monogramBookmarksCollectionId, itemId: entry.id)
            }
        }
    }
}
