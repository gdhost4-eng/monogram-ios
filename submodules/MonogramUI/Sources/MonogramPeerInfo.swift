import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import PromptUI
import MonogramKit

/// Peer identifiers in the form bots and other clients use, see `MonogramPeerIdentity.idString`.
public func monogramPeerIdString(_ peerId: EnginePeer.Id) -> String {
    let id = peerId.id._internalGetInt64Value()
    switch peerId.namespace {
    case Namespaces.Peer.CloudGroup:
        return MonogramPeerIdentity.idString(kind: .group, id: id)
    case Namespaces.Peer.CloudChannel:
        return MonogramPeerIdentity.idString(kind: .channel, id: id)
    default:
        return MonogramPeerIdentity.idString(kind: .user, id: id)
    }
}

/// Approximate account registration date, e.g. "~ март 2016" or "~ 2023 год".
public func monogramApproximateRegistrationText(userId: EnginePeer.Id) -> String? {
    guard userId.namespace == Namespaces.Peer.CloudUser else {
        return nil
    }
    let id = userId.id._internalGetInt64Value()
    let timestamp = MonogramPeerIdentity.estimatedRegistrationDate(userId: id, now: Int32(Date().timeIntervalSince1970))
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let components = calendar.dateComponents([.year, .month], from: date)
    let year = components.year ?? 2013
    if !MonogramPeerIdentity.isRegistrationEstimatePrecise(userId: id) {
        return "~ \(year) год"
    }
    let months = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]
    let month = max(1, min(12, components.month ?? 1))
    return "~ \(months[month - 1]) \(year)"
}

/// Opens a prompt that edits the local note of `peerId`.
public func monogramPeerNoteEditorController(context: AccountContext, peerId: EnginePeer.Id, completion: @escaping () -> Void = {}) -> ViewController {
    let accountPeerId = context.account.peerId
    return promptController(
        context: context,
        text: "Локальная заметка",
        subtitle: "Видна только вам и хранится на этом устройстве.",
        value: MonogramPeerNotes.note(accountPeerId: accountPeerId, peerId: peerId),
        placeholder: "Заметка",
        characterLimit: MonogramNotesIndex.maximumNoteLength,
        apply: { value in
            if let value {
                MonogramPeerNotes.setNote(accountPeerId: accountPeerId, peerId: peerId, note: value)
                completion()
            }
        }
    )
}
