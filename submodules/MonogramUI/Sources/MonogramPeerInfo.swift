import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import PromptUI

/// Peer identifiers in the form bots and other clients use: users as is, basic groups
/// with a minus, channels and supergroups with -100.
public func monogramPeerIdString(_ peerId: EnginePeer.Id) -> String {
    let id = peerId.id._internalGetInt64Value()
    switch peerId.namespace {
    case Namespaces.Peer.CloudGroup:
        return "-\(id)"
    case Namespaces.Peer.CloudChannel:
        return "-100\(id)"
    default:
        return "\(id)"
    }
}

// Known (user id -> account creation time) points, ascending by id.
// The creation time grows roughly monotonically with the id.
private let monogramKnownRegistrationPoints: [(id: Int64, date: Int32)] = [
    (2768409, 1383264000), // Nov 2013
    (7679610, 1388448000),
    (11538514, 1391212000),
    (15835244, 1392940000),
    (23646077, 1393459000),
    (38015510, 1393632000),
    (44634663, 1399334000),
    (54845238, 1411257000),
    (63263518, 1414454000),
    (101260938, 1425600000),
    (109393468, 1439078000),
    (143445125, 1448928000),
    (171295414, 1457481000),
    (222021233, 1465344000),
    (278941742, 1473465000),
    (328594461, 1482969000),
    (369669043, 1490918000),
    (400169472, 1501459000),
    (805158066, 1563208000), // Jul 2019
    (1974255900, 1634000000), // Oct 2021
    (5000000000, 1641000000), // ~ Jan 2022, 64-bit ids
    (7000000000, 1712000000) // ~ Apr 2024
]

// After this id only the year is shown, the points are rougher there.
private let monogramPreciseRegistrationTill: Int64 = 1974255900

private func monogramEstimateRegistration(userId: Int64) -> Int32 {
    let points = monogramKnownRegistrationPoints
    if userId <= points[0].id {
        return points[0].date
    }
    for i in 1 ..< points.count {
        let a = points[i - 1]
        let b = points[i]
        if userId <= b.id {
            let part = Double(userId - a.id) / Double(b.id - a.id)
            return a.date + Int32(part * Double(b.date - a.date))
        }
    }
    // Extrapolate with the speed of the last segment.
    let a = points[points.count - 2]
    let b = points[points.count - 1]
    let speed = Double(b.date - a.date) / Double(b.id - a.id)
    let result = Double(b.date) + speed * Double(userId - b.id)
    return Int32(min(result, Date().timeIntervalSince1970))
}

/// Approximate account registration date, e.g. "~ март 2016" or "~ 2023 год".
public func monogramApproximateRegistrationText(userId: EnginePeer.Id) -> String? {
    guard userId.namespace == Namespaces.Peer.CloudUser else {
        return nil
    }
    let id = userId.id._internalGetInt64Value()
    let date = Date(timeIntervalSince1970: TimeInterval(monogramEstimateRegistration(userId: id)))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let components = calendar.dateComponents([.year, .month], from: date)
    let year = components.year ?? 2013
    if id > monogramPreciseRegistrationTill {
        return "~ \(year) год"
    }
    let months = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]
    let month = max(1, min(12, components.month ?? 1))
    return "~ \(months[month - 1]) \(year)"
}

/// Local notes on users, bots, groups and channels. Visible only on this device.
public enum MonogramPeerNotes {
    private static func key(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id) -> String {
        return "monogram.note.\(accountPeerId.toInt64()).\(peerId.toInt64())"
    }

    private static let version = ValuePromise<Int>(0, ignoreRepeated: false)
    private static var currentVersion: Int = 0

    public static func note(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id) -> String? {
        let value = UserDefaults.standard.string(forKey: self.key(accountPeerId: accountPeerId, peerId: peerId))
        if let value, !value.isEmpty {
            return value
        }
        return nil
    }

    public static func setNote(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id, note: String?) {
        let key = self.key(accountPeerId: accountPeerId, peerId: peerId)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
        Queue.mainQueue().async {
            self.currentVersion += 1
            self.version.set(self.currentVersion)
        }
    }

    /// Fires immediately on subscription and whenever the note of `peerId` may have changed.
    public static func noteSignal(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id) -> Signal<String?, NoError> {
        return self.version.get()
        |> map { _ -> String? in
            return MonogramPeerNotes.note(accountPeerId: accountPeerId, peerId: peerId)
        }
        |> distinctUntilChanged
    }
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
        characterLimit: 4096,
        apply: { value in
            if let value {
                MonogramPeerNotes.setNote(accountPeerId: accountPeerId, peerId: peerId, note: value)
                completion()
            }
        }
    )
}
