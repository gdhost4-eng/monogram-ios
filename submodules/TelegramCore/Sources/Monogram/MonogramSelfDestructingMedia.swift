import Foundation
import Postbox
import SwiftSignalKit

/// Monogram: view-once media and media with a timer stay in the chat after they "self-destruct".
///
/// Every way the media disappears ends up writing a `TelegramMediaExpiredContent` over a stored message
/// (the local timer, "viewed on another device", the server's edit, a history refetch), so the media is
/// kept in one place, the Postbox seed hook `preserveExistingMessageMedia`. Once the timer runs out the
/// timer attribute is dropped as usual and the message stays an ordinary photo/video that can be saved.
public enum MonogramSelfDestructingMedia {
    public static var isKept: Bool {
        return MonogramSettings.get(.saveSelfDestructingMedia)
    }
}

private func monogramIsKeepableMedia(_ media: Media) -> Bool {
    return media is TelegramMediaImage || media is TelegramMediaFile
}

/// The Postbox seed hook: when a stored message is about to get its media replaced with the "expired"
/// placeholder, keeps the photo/file it has now.
func monogramPreservedSelfDestructingMedia(updatedMedia: [Media], previousMedia: () -> [Media]) -> [Media]? {
    if !updatedMedia.contains(where: { $0 is TelegramMediaExpiredContent }) {
        return nil
    }
    if !MonogramSelfDestructingMedia.isKept {
        return nil
    }
    var result = previousMedia().filter(monogramIsKeepableMedia)
    if result.isEmpty {
        return nil
    }
    for media in updatedMedia {
        if media is TelegramMediaExpiredContent || result.contains(where: { $0.isEqual(to: media) }) {
            continue
        }
        result.append(media)
    }
    return result
}

/// A secret chat deletes the whole message when its timer runs out. With media, Monogram drops the timer
/// instead; returns false when the message has to be deleted as usual.
func monogramKeepExpiredSecretMessage(transaction: Transaction, message: Message) -> Bool {
    guard message.id.peerId.namespace == Namespaces.Peer.SecretChat, message.media.contains(where: monogramIsKeepableMedia), MonogramSelfDestructingMedia.isKept else {
        return false
    }
    transaction.updateMessage(message.id, update: { currentMessage in
        var attributes = currentMessage.attributes
        attributes.removeAll(where: { $0 is AutoremoveTimeoutMessageAttribute || $0 is AutoclearTimeoutMessageAttribute })
        return .update(monogramStoreMessage(currentMessage, attributes: attributes))
    })
    return true
}

/// Starts downloading the media of new self-destructing messages right away: once the media expires on the
/// server it can no longer be downloaded, and only what is already on the device can be kept.
func monogramPrefetchSelfDestructingMedia(transaction: Transaction, mediaBox: MediaBox, messages: [StoreMessage]) {
    if !MonogramSelfDestructingMedia.isKept {
        return
    }
    var fetches: [(MediaResourceUserLocation, MediaResourceUserContentType, MediaResourceReference)] = []
    for storeMessage in messages {
        guard case let .Id(id) = storeMessage.id, id.peerId.namespace != Namespaces.Peer.SecretChat else {
            continue
        }
        // The media timer; `AutoremoveTimeoutMessageAttribute` in a cloud chat is the chat-wide auto-delete.
        if !storeMessage.attributes.contains(where: { $0 is AutoclearTimeoutMessageAttribute }) {
            continue
        }
        guard let message = transaction.getMessage(id) else {
            continue
        }
        for media in message.media {
            let mediaReference = AnyMediaReference.message(message: MessageReference(message), media: media)
            if let image = media as? TelegramMediaImage, let representation = largestImageRepresentation(image.representations) {
                fetches.append((.peer(id.peerId), .image, mediaReference.resourceReference(representation.resource)))
            } else if let file = media as? TelegramMediaFile {
                fetches.append((.peer(id.peerId), MediaResourceUserContentType(file: file), mediaReference.resourceReference(file.resource)))
            }
        }
    }
    if fetches.isEmpty {
        return
    }
    Queue.concurrentDefaultQueue().async {
        for (userLocation, userContentType, reference) in fetches {
            let _ = fetchedMediaResource(mediaBox: mediaBox, userLocation: userLocation, userContentType: userContentType, reference: reference).start()
        }
    }
}
