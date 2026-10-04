import XCTest
import MonogramKit

final class MonogramGhostRequestsTests: XCTestCase {
    func testReadReceiptsOfEveryKindOfChat() {
        for name in ["messages.readHistory", "channels.readHistory", "messages.readDiscussion", "messages.readSavedHistory", "messages.readEncryptedHistory"] {
            XCTAssertEqual(MonogramGhostRequests.kind(ofRequestNamed: name), .readReceipt, name)
        }
    }

    func testStoryViews() {
        XCTAssertEqual(MonogramGhostRequests.kind(ofRequestNamed: "stories.readStories"), .storyView)
        XCTAssertEqual(MonogramGhostRequests.kind(ofRequestNamed: "stories.incrementStoryViews"), .storyView)
    }

    func testEverythingElseGoesThrough() {
        for name in ["messages.sendMessage", "messages.getHistory", "account.updateStatus", "messages.setTyping", "stories.getAllStories", ""] {
            XCTAssertNil(MonogramGhostRequests.kind(ofRequestNamed: name), name)
        }
    }

    func testContentReadIsNotBlockedByName() {
        // The same request clears mention and reaction counters; "listened / viewed" is stopped
        // where the request is created (ManagedSynchronizeConsumeMessageContentsOperations).
        XCTAssertNil(MonogramGhostRequests.kind(ofRequestNamed: "messages.readMessageContents"))
        XCTAssertNil(MonogramGhostRequests.kind(ofRequestNamed: "channels.readMessageContents"))
    }

    func testNamesAreCaseSensitive() {
        XCTAssertNil(MonogramGhostRequests.kind(ofRequestNamed: "Messages.ReadHistory"))
    }
}
