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

        self.note = MonogramLocalMetadata.normalizedNote(note)
        self.tags = MonogramTag.normalize(tags)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func matches(query: String, tags requiredTags: [String] = []) -> Bool {
        return MonogramLocalMetadata.matches(
            note: self.note,
            tags: self.tags,
            query: query,
            requiredTags: requiredTags
        )
    }
}
