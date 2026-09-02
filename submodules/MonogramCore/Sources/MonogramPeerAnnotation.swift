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

        self.note = MonogramLocalMetadata.normalizedNote(note)
        self.tags = MonogramTag.normalize(tags)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool {
        return self.note == nil && self.tags.isEmpty
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
