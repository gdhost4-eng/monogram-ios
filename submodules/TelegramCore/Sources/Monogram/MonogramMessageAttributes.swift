import Foundation
import Postbox
import SwiftSignalKit

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

/// History validation found that `id` is gone from the server: it was deleted while this device was not
/// receiving the updates of the chat. If Monogram keeps deleted messages, marks it as deleted and stamps it
/// with the validated channel state, so that it is not validated again; returns false when the message has
/// to be removed as usual.
func monogramKeepMessageRemovedByValidation(transaction: Transaction, id: MessageId, channelPts: Int32?) -> Bool {
    guard MonogramSettings.get(.saveDeletedMessages), id.namespace == Namespaces.Message.Cloud, id.peerId.namespace != Namespaces.Peer.SecretChat, transaction.getMessage(id) != nil else {
        return false
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    transaction.updateMessage(id, update: { currentMessage in
        var attributes = currentMessage.attributes
        if let channelPts = channelPts {
            attributes.removeAll(where: { $0 is ChannelMessageStateVersionAttribute })
            attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
        }
        if !attributes.contains(where: { $0 is MonogramDeletedMessageAttribute }) {
            attributes.append(MonogramDeletedMessageAttribute(date: timestamp))
        }
        return .update(monogramStoreMessage(currentMessage, attributes: attributes))
    })
    return true
}

/// The auto-delete timer of a cloud chat ran out for `message` (the server removes its copy at the same
/// moment). If Monogram keeps deleted messages, marks it as deleted and drops the timer, so that the removal
/// is not scheduled again; returns false when the message has to be removed as usual.
func monogramKeepAutoremovedMessage(transaction: Transaction, message: Message) -> Bool {
    guard MonogramSettings.get(.saveDeletedMessages), message.id.namespace == Namespaces.Message.Cloud, message.id.peerId.namespace != Namespaces.Peer.SecretChat else {
        return false
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    transaction.updateMessage(message.id, update: { currentMessage in
        var attributes = currentMessage.attributes
        attributes.removeAll(where: { $0 is AutoremoveTimeoutMessageAttribute })
        if !attributes.contains(where: { $0 is MonogramDeletedMessageAttribute }) {
            attributes.append(MonogramDeletedMessageAttribute(date: timestamp))
        }
        return .update(monogramStoreMessage(currentMessage, attributes: attributes))
    })
    return true
}

// A chat is scanned from the newest message down; older kept messages than this are not listed.
private let monogramDeletedMessagesScanLimit: Int = 50000

/// The messages of the chat that were deleted on the server and kept by Monogram, newest first.
func _internal_monogramDeletedMessages(postbox: Postbox, peerId: PeerId) -> Signal<[Message], NoError> {
    return postbox.transaction { transaction -> [Message] in
        var ids: [MessageId] = []
        transaction.scanMessageAttributes(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: monogramDeletedMessagesScanLimit, { id, attributes in
            if attributes.contains(where: { $0 is MonogramDeletedMessageAttribute }) {
                ids.append(id)
            }
            return true
        })
        var result: [Message] = []
        for id in ids {
            if let message = transaction.getMessage(id) {
                result.append(message)
            }
        }
        return result
    }
}

/// The Postbox seed hook `mergeMessageAttributes`: whenever a stored message is overwritten with another
/// copy of it (a history refetch, a validation pass, an update that rebuilds the message from the server
/// response), the markers Monogram keeps only locally are carried over from the previous version.
func monogramMergeLocalMessageAttributes(previous: [MessageAttribute], updated: inout [MessageAttribute]) {
    for attribute in previous {
        if attribute is MonogramDeletedMessageAttribute {
            if !updated.contains(where: { $0 is MonogramDeletedMessageAttribute }) {
                updated.append(attribute)
            }
        } else if attribute is MonogramEditHistoryMessageAttribute {
            if !updated.contains(where: { $0 is MonogramEditHistoryMessageAttribute }) {
                updated.append(attribute)
            }
        }
    }
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
