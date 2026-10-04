import Foundation

/// Which outgoing API requests ghost mode stops at the network level, by the name of the API function.
///
/// `messages.readMessageContents` is deliberately absent: the same request also clears mention and
/// reaction counters, so "listened / viewed" is stopped where that request is created instead.
public enum MonogramGhostRequests {
    public enum Kind {
        /// Tells the other side that the messages were read.
        case readReceipt
        /// Tells the author that the story was viewed.
        case storyView
    }

    private static let readRequestNames: Set<String> = [
        "messages.readHistory",
        "channels.readHistory",
        "messages.readDiscussion",
        "messages.readSavedHistory",
        "messages.readEncryptedHistory"
    ]

    private static let storyRequestNames: Set<String> = [
        "stories.readStories",
        "stories.incrementStoryViews"
    ]

    /// Nil for the requests ghost mode never touches.
    public static func kind(ofRequestNamed name: String) -> Kind? {
        if self.readRequestNames.contains(name) {
            return .readReceipt
        } else if self.storyRequestNames.contains(name) {
            return .storyView
        } else {
            return nil
        }
    }
}
