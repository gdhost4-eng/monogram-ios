import Foundation
import Postbox

/// Marks a message that was deleted on the server but kept locally by Monogram.
public final class MonogramDeletedMessageAttribute: MessageAttribute {
    /// When the deletion arrived.
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

/// Previous versions of an edited message, oldest first.
public final class MonogramEditHistoryMessageAttribute: MessageAttribute {
    public struct Entry: Equatable {
        public let text: String
        /// When this version stopped being current (the edit date).
        public let date: Int32

        public init(text: String, date: Int32) {
            self.text = text
            self.date = date
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    required public init(decoder: PostboxDecoder) {
        let texts = decoder.decodeStringArrayForKey("t")
        let dates = decoder.decodeInt32ArrayForKey("d")
        var entries: [Entry] = []
        for i in 0 ..< min(texts.count, dates.count) {
            entries.append(Entry(text: texts[i], date: dates[i]))
        }
        self.entries = entries
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeStringArray(self.entries.map { $0.text }, forKey: "t")
        encoder.encodeInt32Array(self.entries.map { $0.date }, forKey: "d")
    }
}

public extension Message {
    /// Deleted on the server, kept by Monogram.
    var monogramIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is MonogramDeletedMessageAttribute })
    }

    /// Previous versions of the message text, oldest first.
    var monogramEditHistory: [MonogramEditHistoryMessageAttribute.Entry] {
        for attribute in self.attributes {
            if let attribute = attribute as? MonogramEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

public extension EngineMessage {
    var monogramIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is MonogramDeletedMessageAttribute })
    }

    var monogramEditHistory: [MonogramEditHistoryMessageAttribute.Entry] {
        for attribute in self.attributes {
            if let attribute = attribute as? MonogramEditHistoryMessageAttribute {
                return attribute.entries
            }
        }
        return []
    }
}

private let monogramMaxEditHistoryEntries = 100

func monogramStoreMessage(_ message: Message, attributes: [MessageAttribute]) -> StoreMessage {
    var storeForwardInfo: StoreMessageForwardInfo?
    if let forwardInfo = message.forwardInfo {
        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
    }
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: attributes, media: message.media)
}

/// Server-side deletion of messages. The ones Monogram keeps are marked as deleted instead;
/// returns the ids that still have to be removed from the database.
func monogramKeepDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    if !MonogramSettings.get(.saveDeletedMessages) {
        return ids
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    var remaining: [MessageId] = []
    for id in ids {
        guard id.namespace == Namespaces.Message.Cloud, id.peerId.namespace != Namespaces.Peer.SecretChat, let message = transaction.getMessage(id) else {
            remaining.append(id)
            continue
        }
        if message.monogramIsDeleted {
            continue
        }
        transaction.updateMessage(id, update: { currentMessage in
            var attributes = currentMessage.attributes
            attributes.append(MonogramDeletedMessageAttribute(date: timestamp))
            return .update(monogramStoreMessage(currentMessage, attributes: attributes))
        })
    }
    return remaining
}

/// Applied to the attributes of an incoming edit of `previousMessage`: carries over what Monogram
/// stores locally and, if the text changed, remembers the previous version.
func monogramAttributesForEdit(previousMessage: Message, updatedText: String, updatedAttributes: [MessageAttribute]) -> [MessageAttribute] {
    var result = updatedAttributes
    result.removeAll(where: { $0 is MonogramEditHistoryMessageAttribute || $0 is MonogramDeletedMessageAttribute })

    var entries = previousMessage.monogramEditHistory
    if MonogramSettings.get(.saveEditHistory) && previousMessage.text != updatedText {
        let date = (updatedAttributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute)?.date ?? Int32(Date().timeIntervalSince1970)
        entries.append(MonogramEditHistoryMessageAttribute.Entry(text: previousMessage.text, date: date))
        if entries.count > monogramMaxEditHistoryEntries {
            entries.removeFirst(entries.count - monogramMaxEditHistoryEntries)
        }
    }
    if !entries.isEmpty {
        result.append(MonogramEditHistoryMessageAttribute(entries: entries))
    }
    if let deleted = previousMessage.attributes.first(where: { $0 is MonogramDeletedMessageAttribute }) {
        result.append(deleted)
    }
    return result
}
