import Foundation
import Postbox

public struct MonogramPeerAnnotation: Codable, Equatable {
    public let peerId: PeerId
    public let note: String?
    public let tags: [String]
    public let createdAt: Int64
    public let updatedAt: Int64

    public init(
        peerId: PeerId,
        note: String?,
        tags: [String],
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.peerId = peerId

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = trimmedNote?.isEmpty == false ? trimmedNote : nil
        self.tags = MonogramTag.normalize(tags)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool {
        return self.note == nil && self.tags.isEmpty
    }

    public func matches(query: String, tags requiredTags: [String] = []) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedRequiredTags = MonogramTag.normalize(requiredTags)

        if !normalizedRequiredTags.allSatisfy({ self.tags.contains($0) }) {
            return false
        }
        if normalizedQuery.isEmpty {
            return true
        }

        let searchableValues = [self.note ?? ""] + self.tags + self.tags.map { "#\($0)" }
        return searchableValues.contains(where: { value in
            return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(normalizedQuery)
        })
    }
}
