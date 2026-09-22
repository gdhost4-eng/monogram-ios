import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

/// Sends a real read receipt (visible to the other side) up to the locally read message,
/// even while ghost mode suppresses regular read receipts.
func _internal_monogramReadHistoryVisibly(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Never, NoError> {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        return .complete()
    }
    return postbox.transaction { transaction -> (Peer, Int32)? in
        guard let peer = transaction.getPeer(peerId), let readStates = transaction.getPeerReadStates(peerId) else {
            return nil
        }
        for (namespace, state) in readStates where namespace == Namespaces.Message.Cloud {
            if case let .idBased(maxIncomingReadId, _, _, _, _) = state, maxIncomingReadId > 0 {
                return (peer, maxIncomingReadId)
            }
        }
        return nil
    }
    |> mapToSignal { peerAndMaxId -> Signal<Never, NoError> in
        guard let (peer, maxId) = peerAndMaxId else {
            return .complete()
        }
        if let inputChannel = apiInputChannel(peer) {
            let function = Api.functions.channels.readHistory(channel: inputChannel, maxId: maxId)
            MonogramGhost.allowRequest(function.0)
            return network.request(function)
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .complete()
            }
            |> ignoreValues
        } else if let inputPeer = apiInputPeer(peer) {
            let function = Api.functions.messages.readHistory(peer: inputPeer, maxId: maxId)
            MonogramGhost.allowRequest(function.0)
            return network.request(function)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                if let result {
                    switch result {
                    case let .affectedMessages(affectedMessagesData):
                        stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                }
                return .complete()
            }
        } else {
            return .complete()
        }
    }
}

/// The server marks the account online (and, for "read on send", nothing else) when a message is sent,
/// so in ghost mode we immediately report offline again and, if asked, read the chat for real.
func monogramGhostDidSendMessage(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId) {
    if !MonogramGhost.isActive {
        return
    }
    if messageId.namespace == Namespaces.Message.Local && MonogramGhost.readsOnSend {
        let _ = _internal_monogramReadHistoryVisibly(postbox: postbox, network: network, stateManager: stateManager, peerId: messageId.peerId).start()
    }
    if MonogramGhost.blocksOnline {
        let _ = (network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .complete()
        }).start()
    }
}
