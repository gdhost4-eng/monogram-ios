import Foundation
import Postbox

public struct MonogramBookmark: Codable, Equatable {
    public let id: UUID
    public let messageId: MessageId
    public let note: String?
    public let tags: [String]
    public let createdAt: Int64
    public let updatedAt: Int64

    private enum CodingKeys: String, CodingKey {
        case id, messageId, note, tags, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid bookmark UUID")
        }
        self.id = uuid
        self.messageId = try container.decode(MessageId.self, forKey: .messageId)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.tags = try container.decode([String].self, forKey: .tags)
        self.createdAt = try container.decode(Int64.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Int64.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Postbox does not support UUID's single-value Codable container.
        try container.encode(self.id.uuidString, forKey: .id)
        try container.encode(self.messageId, forKey: .messageId)
        try container.encodeIfPresent(self.note, forKey: .note)
        try container.encode(self.tags, forKey: .tags)
        try container.encode(self.createdAt, forKey: .createdAt)
        try container.encode(self.updatedAt, forKey: .updatedAt)
    }

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
