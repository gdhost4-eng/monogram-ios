import Foundation
import Postbox
import SwiftSignalKit
import MonogramKit

/// Local notes on users, bots, groups and channels. Visible only on this device.
///
/// The notes live in `UserDefaults.standard`, one key per note (`MonogramNotesIndex.storageKey`), and are
/// mirrored in memory per account, so that the chat list search can go through all of them on every keystroke.
public enum MonogramPeerNotes {
    private static let lock = NSLock()
    private static var indices: [Int64: MonogramNotesIndex] = [:]
    private static let version = ValuePromise<Int>(0, ignoreRepeated: false)
    private static var currentVersion: Int = 0

    /// The notes of the account, read from `UserDefaults` on the first use.
    private static func withIndex<T>(account: Int64, _ f: (inout MonogramNotesIndex) -> T) -> T {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        var index: MonogramNotesIndex
        if let current = self.indices[account] {
            index = current
        } else {
            var notes: [Int64: String] = [:]
            for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
                if let peer = MonogramNotesIndex.peer(fromStorageKey: key, account: account), let note = value as? String {
                    notes[peer] = note
                }
            }
            index = MonogramNotesIndex(notes: notes)
        }
        let result = f(&index)
        self.indices[account] = index
        return result
    }

    public static func note(accountPeerId: PeerId, peerId: PeerId) -> String? {
        let peer = peerId.toInt64()
        return self.withIndex(account: accountPeerId.toInt64(), { index -> String? in
            return index.note(for: peer)
        })
    }

    /// An empty note removes the note.
    public static func setNote(accountPeerId: PeerId, peerId: PeerId, note: String?) {
        let account = accountPeerId.toInt64()
        let peer = peerId.toInt64()
        let stored = self.withIndex(account: account, { index -> String? in
            return index.set(note, for: peer)
        })
        let key = MonogramNotesIndex.storageKey(account: account, peer: peer)
        if let stored = stored {
            UserDefaults.standard.set(stored, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        Queue.mainQueue().async {
            self.currentVersion += 1
            self.version.set(self.currentVersion)
        }
    }

    /// Fires immediately on subscription and whenever the note of `peerId` may have changed.
    public static func noteSignal(accountPeerId: PeerId, peerId: PeerId) -> Signal<String?, NoError> {
        return self.version.get()
        |> map { _ -> String? in
            return MonogramPeerNotes.note(accountPeerId: accountPeerId, peerId: peerId)
        }
        |> distinctUntilChanged
    }

    /// Peers whose note has every word of the query, see `MonogramSearch`.
    public static func search(accountPeerId: PeerId, query: String) -> [PeerId] {
        let peers = self.withIndex(account: accountPeerId.toInt64(), { index -> [Int64] in
            return index.peers(matching: query)
        })
        return peers.map { PeerId($0) }
    }
}

/// The local peer search with the chats found by the text of their local note added to the end.
func monogramSearchPeersIncludingNotes(postbox: Postbox, accountPeerId: PeerId, query: String, predicate: ChatListFilterPredicate?) -> Signal<[RenderedPeer], NoError> {
    let foundPeers = postbox.searchPeers(query: query, predicate: predicate)
    // A search inside a folder stays inside the folder.
    if predicate != nil || !MonogramSettings.get(.localNotes) {
        return foundPeers
    }
    let notePeerIds = MonogramPeerNotes.search(accountPeerId: accountPeerId, query: query)
    if notePeerIds.isEmpty {
        return foundPeers
    }
    return foundPeers
    |> mapToSignal { peers -> Signal<[RenderedPeer], NoError> in
        return postbox.transaction { transaction -> [RenderedPeer] in
            var result = peers
            var knownPeerIds = Set(peers.map { $0.peerId })
            for peerId in notePeerIds {
                if knownPeerIds.contains(peerId) {
                    continue
                }
                if let peer = transaction.getPeer(peerId) {
                    knownPeerIds.insert(peerId)
                    result.append(RenderedPeer(peer: peer))
                }
            }
            return result
        }
    }
}
