import Foundation

/// The local notes of one account in memory: the text by peer and the words to search by.
/// Peers are identified by `PeerId.toInt64()`.
public struct MonogramNotesIndex {
    public static let maximumNoteLength: Int = 4096

    public private(set) var notes: [Int64: String]
    private var words: [Int64: [String]]

    public init(notes: [Int64: String] = [:]) {
        self.notes = [:]
        self.words = [:]
        for (peer, note) in notes {
            self.set(note, for: peer)
        }
    }

    /// What is actually stored for `note`: trimmed and cut to the maximum length; nil removes the note.
    public static func normalized(_ note: String?) -> String? {
        guard let note = note else {
            return nil
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return String(trimmed.prefix(self.maximumNoteLength))
    }

    public func note(for peer: Int64) -> String? {
        return self.notes[peer]
    }

    /// Returns what was stored (see `normalized`).
    @discardableResult
    public mutating func set(_ note: String?, for peer: Int64) -> String? {
        if let normalized = MonogramNotesIndex.normalized(note) {
            self.notes[peer] = normalized
            self.words[peer] = MonogramSearch.words(normalized)
            return normalized
        } else {
            self.notes.removeValue(forKey: peer)
            self.words.removeValue(forKey: peer)
            return nil
        }
    }

    /// Peers whose note has every word of the query, in ascending order of the id.
    public func peers(matching query: String) -> [Int64] {
        let queryWords = MonogramSearch.words(query)
        if queryWords.isEmpty {
            return []
        }
        var result: [Int64] = []
        for (peer, noteWords) in self.words {
            if MonogramSearch.matches(textWords: noteWords, queryWords: queryWords) {
                result.append(peer)
            }
        }
        result.sort()
        return result
    }

    /// The `UserDefaults` key of a note.
    public static func storageKey(account: Int64, peer: Int64) -> String {
        return "monogram.note.\(account).\(peer)"
    }

    /// The peer of a note stored for `account` under `key`, nil for any other key.
    public static func peer(fromStorageKey key: String, account: Int64) -> Int64? {
        let prefix = "monogram.note.\(account)."
        guard key.hasPrefix(prefix) else {
            return nil
        }
        return Int64(key[key.index(key.startIndex, offsetBy: prefix.count)...])
    }
}
