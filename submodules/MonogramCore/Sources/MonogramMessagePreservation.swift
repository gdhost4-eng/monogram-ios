import Postbox

public func setupMonogramMessagePreservation(postbox: Postbox, accountPeerId: PeerId) {
    let mediaBox = postbox.mediaBox
    postbox.setMessageDeletionTransform { messages, transaction in
        return MonogramDeletedMessageTransform.transform(messages: messages, transaction: transaction, accountPeerId: accountPeerId, mediaBox: mediaBox)
    }
    postbox.setMessageUpdateObserver { updates, transaction in
        captureMonogramMessageEdits(transaction: transaction, updates: updates, accountPeerId: accountPeerId)
    }
}
