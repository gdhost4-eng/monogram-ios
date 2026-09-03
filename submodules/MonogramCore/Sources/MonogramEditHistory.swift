import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

public struct MonogramMessageRevision: Codable, Equatable {
    public let text: String
    public let capturedAt: Int64

    public init(text: String, capturedAt: Int64) {
        self.text = text
        self.capturedAt = capturedAt
    }
}

public struct MonogramEditHistory: Codable, Equatable {
    public let messageId: MessageId
    public var revisions: [MonogramMessageRevision]

    public init(messageId: MessageId, revisions: [MonogramMessageRevision]) {
        self.messageId = messageId
        self.revisions = revisions
    }
}

private let monogramEditHistoryCollectionId: Int32 = 0x4d4f4203

private func monogramEditHistoryItemId(_ messageId: MessageId) -> MemoryBuffer {
    return MemoryBuffer(data: MessageId.encodeArrayToData([messageId]))
}

private func decodeMonogramEditHistory(_ entry: OrderedItemListEntry) -> MonogramEditHistory? {
    return entry.contents.get(MonogramEditHistory.self)
}

public func monogramEditHistory(postbox: Postbox, messageId: MessageId) -> Signal<MonogramEditHistory?, NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: monogramEditHistoryCollectionId)
    return postbox.combinedView(keys: [viewKey])
    |> map { view -> MonogramEditHistory? in
        guard let orderedView = view.views[viewKey] as? OrderedItemListView else {
            return nil
        }
        return orderedView.items.compactMap(decodeMonogramEditHistory).first(where: { $0.messageId == messageId })
    }
}

public func captureMonogramMessageEdits(
    transaction: Transaction,
    updates: [(Message, StoreMessage)],
    accountPeerId: PeerId,
    timestamp: Int64 = Int64(Date().timeIntervalSince1970)
) {
    guard monogramAccountSettings(transaction: transaction).isEnabled(.preserveEditHistory) else {
        return
    }
    for (previous, updated) in updates {
        guard case let .Id(updatedId) = updated.id, updatedId == previous.id else {
            continue
        }
        guard previous.id.namespace == Namespaces.Message.Cloud,
              previous.id.peerId.namespace != Namespaces.Peer.SecretChat,
              !previous.flags.contains(.CopyProtected),
              !previous.attributes.contains(where: { $0 is AutoremoveTimeoutMessageAttribute || $0 is AutoclearTimeoutMessageAttribute }),
              previous.text != updated.text else {
            continue
        }

        let itemId = monogramEditHistoryItemId(previous.id)
        let existingEntry = transaction.getOrderedItemListItem(collectionId: monogramEditHistoryCollectionId, itemId: itemId)
        var history = existingEntry.flatMap(decodeMonogramEditHistory) ?? MonogramEditHistory(messageId: previous.id, revisions: [])
        if history.revisions.last?.text != previous.text {
            history.revisions.append(MonogramMessageRevision(text: previous.text, capturedAt: timestamp))
        }
        if history.revisions.count > 50 {
            history.revisions.removeFirst(history.revisions.count - 50)
        }
        if let contents = CodableEntry(history) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(
                collectionId: monogramEditHistoryCollectionId,
                item: OrderedItemListEntry(id: itemId, contents: contents),
                removeTailIfCountExceeds: nil
            )
        }
    }
}

public func removeMonogramEditHistory(postbox: Postbox, messageId: MessageId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.removeOrderedItemListItem(collectionId: monogramEditHistoryCollectionId, itemId: monogramEditHistoryItemId(messageId))
    }
}
