import Postbox
import TelegramCore

public enum MonogramLocalDataDenialReason: Equatable {
    case secretChat
    case ephemeralMessage
    case copyProtectedMessage
}

public enum MonogramLocalDataPolicy {
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
