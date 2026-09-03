import Foundation
import XCTest
import Postbox
import TelegramCore
import MonogramCore

final class MonogramCoreTests: XCTestCase {
    func testFeatureRegistryContainsEveryIdentifierExactlyOnce() {
        let identifiers = MonogramFeatureRegistry.all.map(\.id)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertEqual(Set(identifiers), Set(MonogramFeatureId.allCases))
    }

    func testDefaultsComeFromRegistry() {
        let settings = MonogramSettings()
        XCTAssertTrue(settings.isEnabled(.advancedSettings))
        XCTAssertFalse(settings.isEnabled(.localBookmarks))
        XCTAssertFalse(settings.isEnabled(.ghostMode))
    }

    func testRegularAndExperimentalOverridesRoundTrip() throws {
        var settings = MonogramSettings()
        settings.setEnabled(true, for: .localBookmarks)
        settings.setEnabled(true, for: .preserveDeletedMessages)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MonogramSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
        XCTAssertTrue(decoded.isEnabled(.localBookmarks))
        XCTAssertTrue(decoded.isEnabled(.preserveDeletedMessages))
    }

    func testLegacyMissingFieldsDecodeWithSafeDefaults() throws {
        let data = Data("{\"schemaVersion\":0}".utf8)
        let decoded = try JSONDecoder().decode(MonogramSettings.self, from: data)
        let migrated = decoded.migratedToCurrentSchema()

        XCTAssertEqual(migrated.schemaVersion, MonogramSettings.currentSchemaVersion)
        XCTAssertTrue(migrated.featureOverrides.isEmpty)
        XCTAssertTrue(migrated.experimentalFeatureOverrides.isEmpty)
        XCTAssertTrue(migrated.isEnabled(.advancedSettings))
    }

    func testAccountPolicyHasNoApplicationMaximum() {
        XCTAssertNil(MonogramAccountPolicy.applicationAccountLimit)
        XCTAssertTrue(MonogramAccountPolicy.allowsAddingAnotherAccount)
    }

    func testBookmarkNormalizesNoteAndTags() {
        let bookmark = MonogramBookmark(
            messageId: MessageId(peerId: PeerId(100), namespace: 0, id: 5),
            note: "  Useful message  ",
            tags: [" Work ", "#Important", "work", "##"],
            createdAt: 10,
            updatedAt: 11
        )

        XCTAssertEqual(bookmark.note, "Useful message")
        XCTAssertEqual(bookmark.tags, ["work", "important"])
    }

    func testTagParserSupportsEditorSeparators() {
        XCTAssertEqual(
            MonogramTag.parse("#Work, ios;important\nrelease work"),
            ["work", "ios", "important", "release"]
        )
    }

    func testBookmarkSearchMatchesNotesAndRequiredTags() {
        let bookmark = MonogramBookmark(
            messageId: MessageId(peerId: PeerId(100), namespace: 0, id: 5),
            note: "Résumé for launch",
            tags: ["Project", "iOS"],
            createdAt: 10,
            updatedAt: 11
        )

        XCTAssertTrue(bookmark.matches(query: "resume"))
        XCTAssertTrue(bookmark.matches(query: "launch", tags: ["#PROJECT"]))
        XCTAssertTrue(bookmark.matches(query: "#ios"))
        XCTAssertFalse(bookmark.matches(query: "launch", tags: ["android"]))
    }

    func testBookmarkCodableEntryRoundTrip() {
        let bookmark = MonogramBookmark(
            messageId: MessageId(peerId: PeerId(100), namespace: 1, id: 7),
            note: nil,
            tags: ["saved"],
            createdAt: 10,
            updatedAt: 11
        )

        let entry = CodableEntry(bookmark)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.get(MonogramBookmark.self), bookmark)
    }

    func testLocalDataPolicyRejectsSensitiveMessageReferences() {
        let cloudMessageId = MessageId(peerId: PeerId(100), namespace: Namespaces.Message.Cloud, id: 5)
        let secretMessageId = MessageId(
            peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(100)),
            namespace: Namespaces.Message.SecretIncoming,
            id: 5
        )
        let ephemeralMessageId = MessageId(peerId: PeerId(100), namespace: Namespaces.Message.EphemeralLocal, id: 5)

        XCTAssertNil(MonogramLocalDataPolicy.bookmarkDenialReason(messageId: cloudMessageId, isCopyProtected: false, isEphemeral: false))
        XCTAssertEqual(MonogramLocalDataPolicy.bookmarkDenialReason(messageId: secretMessageId, isCopyProtected: false, isEphemeral: false), .secretChat)
        XCTAssertEqual(MonogramLocalDataPolicy.bookmarkDenialReason(messageId: ephemeralMessageId, isCopyProtected: false, isEphemeral: false), .ephemeralMessage)
        XCTAssertEqual(MonogramLocalDataPolicy.bookmarkDenialReason(messageId: cloudMessageId, isCopyProtected: true, isEphemeral: false), .copyProtectedMessage)
        XCTAssertEqual(MonogramLocalDataPolicy.bookmarkDenialReason(messageId: cloudMessageId, isCopyProtected: false, isEphemeral: true), .ephemeralMessage)
    }

    func testPeerAnnotationNormalizesAndSearchesLocalMetadata() {
        let annotation = MonogramPeerAnnotation(
            peerId: PeerId(100),
            note: "  Design résumé  ",
            tags: ["#Work", " IOS ", "work"],
            createdAt: 10,
            updatedAt: 11
        )

        XCTAssertEqual(annotation.note, "Design résumé")
        XCTAssertEqual(annotation.tags, ["work", "ios"])
        XCTAssertTrue(annotation.matches(query: "resume", tags: ["#WORK"]))
        XCTAssertFalse(annotation.matches(query: "resume", tags: ["android"]))
        XCTAssertFalse(annotation.isEmpty)
    }

    func testEmptyPeerAnnotationIsDetected() {
        let annotation = MonogramPeerAnnotation(
            peerId: PeerId(100),
            note: "   ",
            tags: ["#"],
            createdAt: 10,
            updatedAt: 11
        )

        XCTAssertTrue(annotation.isEmpty)
    }
}
