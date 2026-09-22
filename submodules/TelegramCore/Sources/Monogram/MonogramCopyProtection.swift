import Foundation
import Postbox

/// Monogram: "restrict saving content" is lifted locally (copying, saving, screenshots).
public enum MonogramCopyProtection {
    public static var isBypassed: Bool {
        return MonogramSettings.get(.bypassCopyProtection)
    }
}

private func monogramIsSourceCopyProtected(transaction: Transaction, message: Message) -> Bool {
    if message.flags.contains(.CopyProtected) {
        return true
    }
    let peerId = message.id.peerId
    if let group = transaction.getPeer(peerId) as? TelegramGroup {
        return group.flags.contains(.copyProtectionEnabled)
    } else if let channel = transaction.getPeer(peerId) as? TelegramChannel {
        return channel.flags.contains(.copyProtectionEnabled)
    } else if peerId.namespace == Namespaces.Peer.CloudUser, let cachedUserData = transaction.getPeerCachedData(peerId: peerId) as? CachedUserData {
        return cachedUserData.flags.contains(.copyProtectionEnabled)
    }
    return false
}

/// The server refuses a real forward of a protected message, so with the bypass on
/// such a forward is sent as a copy: the same text, entities and media.
func monogramConvertProtectedForwards(transaction: Transaction, messages: [(Bool, EnqueueMessage)]) -> [(Bool, EnqueueMessage)] {
    if !MonogramCopyProtection.isBypassed {
        return messages
    }
    return messages.map { item -> (Bool, EnqueueMessage) in
        guard case let .forward(sourceId, threadId, _, attributes, correlationId) = item.1, let source = transaction.getMessage(sourceId) else {
            return item
        }
        if !monogramIsSourceCopyProtected(transaction: transaction, message: source) {
            return item
        }
        var updatedAttributes = attributes
        updatedAttributes.removeAll(where: { $0 is ForwardOptionsMessageAttribute || $0 is TextEntitiesMessageAttribute })
        if let entities = source.textEntitiesAttribute {
            updatedAttributes.append(entities)
        }
        let mediaReference = source.media.first(where: { !($0 is TelegramMediaWebpage) }).map { media -> AnyMediaReference in
            return .message(message: MessageReference(source), media: media)
        }
        return (item.0, .message(text: source.text, attributes: updatedAttributes, inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: source.groupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: []))
    }
}
