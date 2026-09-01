import Foundation
import Postbox

public struct MonogramBookmark: Codable, Equatable {
    public let id: UUID
    public let messageId: MessageId
    public let note: String?
    public let tags: [String]
    public let createdAt: Int64
    public let updatedAt: Int64

    public init(
        id: UUID = UUID(),
        messageId: MessageId,
        note: String?,
        tags: [String],
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.messageId = messageId

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = trimmedNote?.isEmpty == false ? trimmedNote : nil
        self.tags = MonogramTag.normalize(tags)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
