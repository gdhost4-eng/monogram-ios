import Postbox
import TelegramCore

public enum MonogramLocalDataDenialReason: Equatable {
    case secretChat
    case ephemeralMessage
    case copyProtectedMessage
}

public enum MonogramLocalDataPolicy {
    /// Deletion and edit history capture must use the same eligibility rules.
    public static func allowsMessagePreservation(_ message: Message) -> Bool {
        return message.id.namespace == Namespaces.Message.Cloud
            && message.id.peerId.namespace != Namespaces.Peer.SecretChat
            && !message.flags.contains(.CopyProtected)
            && !message.attributes.contains(where: {
                $0 is AutoremoveTimeoutMessageAttribute || $0 is AutoclearTimeoutMessageAttribute
            })
    }

    public static func bookmarkDenialReason(
        messageId: MessageId,
        isCopyProtected: Bool,
        isEphemeral: Bool
    ) -> MonogramLocalDataDenialReason? {
        if messageId.peerId.namespace == Namespaces.Peer.SecretChat {
            return .secretChat
        }
        if isEphemeral || Namespaces.Message.allEphemeral.contains(messageId.namespace) {
            return .ephemeralMessage
        }
        if isCopyProtected {
            return .copyProtectedMessage
        }
        return nil
    }

    public static func allowsPeerAnnotation(peerId: PeerId) -> Bool {
        return peerId.namespace != Namespaces.Peer.SecretChat
    }
}
