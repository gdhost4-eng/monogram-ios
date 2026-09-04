import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum MonogramDeletedMessageTransform {
    public static let marker = "🗑 Удалено локально"
    private static let collectionId: Int32 = 0x4d4f4204

    private struct Record: Codable {
        let messageId: MessageId
    }

    private static func itemId(_ messageId: MessageId) -> MemoryBuffer {
        return MemoryBuffer(data: MessageId.encodeArrayToData([messageId]))
    }

    public static func transform(messages: [Message], transaction: Transaction, accountPeerId: PeerId, mediaBox: MediaBox) -> [MessageId: StoreMessage] {
        for message in messages where message.id.namespace == Namespaces.Message.MonogramLocal {
            transaction.removeOrderedItemListItem(collectionId: self.collectionId, itemId: self.itemId(message.id))
        }
        guard monogramAccountSettings(transaction: transaction).isEnabled(.preserveDeletedMessages) else {
            return [:]
        }

        var result: [MessageId: StoreMessage] = [:]
        for message in messages {
            guard MonogramLocalDataPolicy.allowsMessagePreservation(message) else {
                continue
            }
            guard message.text != self.marker && !message.text.hasSuffix("\n\n" + self.marker) else {
                // A second local deletion is the explicit way to remove a
                // previously preserved bubble.
                continue
            }
            // The namespace already isolates these IDs from server messages.
            // History lookups use nonnegative ID bounds.
            let localIdValue = max(1, message.id.id)
            let localId = MessageId(peerId: message.id.peerId, namespace: Namespaces.Message.MonogramLocal, id: localIdValue)
            result[message.id] = self.localCopy(of: message, id: localId, mediaBox: mediaBox)
            if let contents = CodableEntry(Record(messageId: localId)) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(
                    collectionId: self.collectionId,
                    item: OrderedItemListEntry(id: self.itemId(localId), contents: contents),
                    removeTailIfCountExceeds: nil
                )
            }
        }
        return result
    }

    private static func localCopy(of message: Message, id: MessageId, mediaBox: MediaBox) -> StoreMessage {
        var flags = StoreMessageFlags(message.flags)
        flags.remove(.TopIndexable)
        flags.remove(.CountedAsIncoming)
        flags.remove(.Unsent)
        flags.remove(.Sending)
        flags.remove(.Failed)
        flags.remove(.ReactionsArePossible)
        return StoreMessage(
            id: id,
            customStableId: nil,
            globallyUniqueId: nil,
            groupingKey: nil,
            threadId: message.threadId,
            timestamp: message.timestamp,
            flags: flags,
            tags: message.tags,
            globalTags: message.globalTags,
            localTags: message.localTags,
            forwardInfo: message.forwardInfo.map { StoreMessageForwardInfo($0) },
            authorId: message.author?.id,
            text: message.text.isEmpty ? self.marker : message.text + "\n\n" + self.marker,
            attributes: message.attributes,
            media: message.media.compactMap { self.locallyAvailableMedia($0, mediaBox: mediaBox) }
        )
    }

    private static func locallyAvailableMedia(_ media: Media, mediaBox: MediaBox) -> Media? {
        if let file = media as? TelegramMediaFile {
            return mediaBox.completedResourcePath(file.resource) == nil ? nil : file
        } else if let image = media as? TelegramMediaImage {
            let hasLocalRepresentation = image.representations.contains(where: {
                mediaBox.completedResourcePath($0.resource) != nil
            })
            return hasLocalRepresentation ? image : nil
        } else {
            return media
        }
    }

    public static func records(postbox: Postbox) -> Signal<[MessageId], NoError> {
        let key: PostboxViewKey = .orderedItemList(id: self.collectionId)
        return postbox.combinedView(keys: [key])
        |> map { view in
            guard let value = view.views[key] as? OrderedItemListView else {
                return []
            }
            return value.items.compactMap { $0.contents.get(Record.self)?.messageId }
        }
    }

    public static func clear(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            let entries = transaction.getOrderedListItems(collectionId: self.collectionId)
            let ids = entries.compactMap { $0.contents.get(Record.self)?.messageId }
            transaction.deleteMessages(ids, forEachMedia: nil)
            for entry in entries {
                transaction.removeOrderedItemListItem(collectionId: self.collectionId, itemId: entry.id)
            }
        }
    }
}
