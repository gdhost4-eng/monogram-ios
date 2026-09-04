import Foundation
import Postbox
import SwiftSignalKit

private let monogramPeerAnnotationsCollectionId: Int32 = 0x4d4f4202

private func monogramPeerAnnotationItemId(_ peerId: PeerId) -> MemoryBuffer {
    return MemoryBuffer(data: Data(String(peerId.toInt64()).utf8))
}

private func monogramPeerAnnotation(from entry: OrderedItemListEntry) -> MonogramPeerAnnotation? {
    return entry.contents.get(MonogramPeerAnnotation.self)
}

public func monogramPeerAnnotations(postbox: Postbox) -> Signal<[MonogramPeerAnnotation], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: monogramPeerAnnotationsCollectionId)
    return postbox.combinedView(keys: [viewKey])
    |> map { view -> [MonogramPeerAnnotation] in
        guard let orderedView = view.views[viewKey] as? OrderedItemListView else {
            return []
        }
        return orderedView.items.compactMap { monogramPeerAnnotation(from: $0) }
    }
}

public func monogramPeerAnnotation(postbox: Postbox, peerId: PeerId) -> Signal<MonogramPeerAnnotation?, NoError> {
    return monogramPeerAnnotations(postbox: postbox)
    |> map { annotations in
        return annotations.first(where: { $0.peerId == peerId })
    }
}

public func searchMonogramPeerAnnotations(
    postbox: Postbox,
    query: String
) -> Signal<[MonogramPeerAnnotation], NoError> {
    return monogramPeerAnnotations(postbox: postbox)
    |> map { annotations in
        return annotations.filter { annotation in
            guard annotation.note != nil else { return false }
            return MonogramLocalMetadata.matches(note: annotation.note, tags: [], query: query, requiredTags: [])
        }
    }
}

public func setMonogramPeerAnnotation(
    postbox: Postbox,
    peerId: PeerId,
    note: String?,
    tags: [String],
    timestamp: Int64 = Int64(Date().timeIntervalSince1970)
) -> Signal<MonogramPeerAnnotation?, NoError> {
    guard MonogramLocalDataPolicy.allowsPeerAnnotation(peerId: peerId) else {
        return .single(nil)
    }

    return postbox.transaction { transaction -> MonogramPeerAnnotation? in
        let itemId = monogramPeerAnnotationItemId(peerId)
        let existing = transaction.getOrderedListItems(collectionId: monogramPeerAnnotationsCollectionId).compactMap { monogramPeerAnnotation(from: $0) }.first(where: { $0.peerId == peerId })
        let annotation = MonogramPeerAnnotation(
            peerId: peerId,
            note: note,
            tags: tags,
            createdAt: existing?.createdAt ?? timestamp,
            updatedAt: timestamp
        )

        if annotation.isEmpty {
            transaction.removeOrderedItemListItem(collectionId: monogramPeerAnnotationsCollectionId, itemId: itemId)
            return nil
        }
        guard let contents = CodableEntry(annotation) else {
            return nil
        }
        transaction.addOrMoveToFirstPositionOrderedItemListItem(
            collectionId: monogramPeerAnnotationsCollectionId,
            item: OrderedItemListEntry(id: itemId, contents: contents),
            removeTailIfCountExceeds: nil
        )
        return annotation
    }
}

public func removeMonogramPeerAnnotation(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.removeOrderedItemListItem(collectionId: monogramPeerAnnotationsCollectionId, itemId: monogramPeerAnnotationItemId(peerId))
    }
}
