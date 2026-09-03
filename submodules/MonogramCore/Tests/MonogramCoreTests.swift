import Foundation
import XCTest
import Postbox
import TelegramCore
import MonogramCore

final class MonogramCoreTests: XCTestCase {
    func testBookmarkRoundTripsThroughPostboxIncludingUUID() throws {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(123))
        for tags in [[], ["tag"]] as [[String]] {
            let bookmark = MonogramBookmark(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 42), note: "note", tags: tags, createdAt: 100, updatedAt: 200)
            let entry = try XCTUnwrap(CodableEntry(bookmark))
            XCTAssertEqual(entry.get(MonogramBookmark.self), bookmark)
            let json = try JSONEncoder().encode(bookmark)
            XCTAssertEqual(try JSONDecoder().decode(MonogramBookmark.self, from: json), bookmark)
        }
    }

    func testAnnotationAndEditHistoryRoundTripThroughPostbox() throws {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(123))
        for tags in [[], ["tag"]] as [[String]] {
            let annotation = MonogramPeerAnnotation(peerId: peerId, note: "note", tags: tags, createdAt: 100, updatedAt: 200)
            let entry = try XCTUnwrap(CodableEntry(annotation))
            XCTAssertEqual(entry.get(MonogramPeerAnnotation.self), annotation)
        }
        let history = MonogramEditHistory(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 42), revisions: [MonogramMessageRevision(text: "before", capturedAt: 100), MonogramMessageRevision(text: "after", capturedAt: 200)])
        let entry = try XCTUnwrap(CodableEntry(history))
        XCTAssertEqual(entry.get(MonogramEditHistory.self), history)
    }

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

    func testEveryFeaturePersistsThroughPostboxPreferences() throws {
        for id in MonogramFeatureId.allCases {
            var settings = MonogramSettings()
            for enabled in [true, false] {
                settings.setEnabled(enabled, for: id)
                let entry = try XCTUnwrap(PreferencesEntry(settings))
                let reloaded = try XCTUnwrap(PreferencesEntry(data: entry.data).get(MonogramSettings.self))
                XCTAssertEqual(reloaded, settings)
                XCTAssertEqual(reloaded.isEnabled(id), enabled)
            }
        }
    }

    func testSettingsPostboxRoundTripPreservesAllFields() throws {
        let settings = MonogramSettings(
            featureOverrides: ["localBookmarks": true, "futureFeature": false],
            experimentalFeatureOverrides: ["futureExperiment": true],
            ghostModeExpiresAt: 2_000_000_000,
            ghostModeExcludedPeerIds: [100, 200]
        )
        let entry = try XCTUnwrap(SharedPreferencesEntry(settings))
        XCTAssertEqual(entry.get(MonogramSettings.self), settings)
        let emptyEntry = try XCTUnwrap(PreferencesEntry(MonogramSettings()))
        XCTAssertEqual(emptyEntry.get(MonogramSettings.self), MonogramSettings())
    }

    func testLegacyPostboxDictionariesDecodeWithoutEnumeratingKeys() throws {
        struct LegacySettings: Encodable {
            let schemaVersion: Int32 = 2
            let featureOverrides: [String: Bool] = [:]
            let experimentalFeatureOverrides: [String: Bool] = [:]
        }
        let entry = try XCTUnwrap(PreferencesEntry(LegacySettings()))
        XCTAssertEqual(entry.get(MonogramSettings.self), MonogramSettings())
    }

    func testAccountPolicyHasNoApplicationMaximum() {
        XCTAssertNil(MonogramAccountPolicy.applicationAccountLimit)
        XCTAssertTrue(MonogramAccountPolicy.allowsAddingAnotherAccount)
    }

    func testEveryFeatureCanBeToggledAndResetIndependently() {
        for id in MonogramFeatureId.allCases {
            var settings = MonogramSettings()
            let defaultValue = settings.isEnabled(id)
            settings.setEnabled(!defaultValue, for: id)
            XCTAssertEqual(settings.isEnabled(id), !defaultValue)
            for otherId in MonogramFeatureId.allCases where otherId != id {
                XCTAssertEqual(settings.isEnabled(otherId), MonogramSettings().isEnabled(otherId))
            }
            settings.reset(id)
            XCTAssertEqual(settings, MonogramSettings())
        }
    }

    func testGhostModeExpiresAtTheDeadline() {
        var settings = MonogramSettings()
        XCTAssertFalse(settings.isGhostModeActive(at: 100))
        settings.setGhostModeDuration(900, at: 100)
        XCTAssertTrue(settings.isGhostModeActive(at: 100))
        XCTAssertTrue(settings.isGhostModeActive(at: 999))
        XCTAssertFalse(settings.isGhostModeActive(at: 1000))
        XCTAssertFalse(settings.isGhostModeActive(at: 1001))
        // Reading effective state must not change persisted preferences.
        XCTAssertTrue(settings.isEnabled(.ghostMode))
        XCTAssertEqual(settings.ghostModeExpiresAt, 1000)
    }

    func testGhostModeToggleAndResetClearTheOldDeadline() {
        for enabled in [false, true] {
            var settings = MonogramSettings()
            settings.setGhostModeDuration(900, at: 100)
            settings.setEnabled(enabled, for: .ghostMode)
            XCTAssertNil(settings.ghostModeExpiresAt)
            XCTAssertEqual(settings.isGhostModeActive(at: 2000), enabled)
        }
        var settings = MonogramSettings()
        settings.setGhostModeDuration(900, at: 100)
        settings.reset(.ghostMode)
        XCTAssertEqual(settings, MonogramSettings())
    }

    func testGhostModeDurationPreservesSubsettingsAndExclusions() {
        var settings = MonogramSettings(ghostModeExcludedPeerIds: [100, 200])
        settings.setEnabled(false, for: .ghostReadReceipts)
        settings.setGhostModeDuration(900, at: 100)
        settings.setEnabled(true, for: .localBookmarks)
        XCTAssertEqual(settings.ghostModeExpiresAt, 1000)
        settings.setGhostModeDuration(nil, at: 2000)
        XCTAssertNil(settings.ghostModeExpiresAt)
        XCTAssertTrue(settings.isGhostModeActive(at: 3000))
        XCTAssertFalse(settings.isEnabled(.ghostReadReceipts))
        XCTAssertTrue(settings.isEnabled(.ghostTypingActivity))
        XCTAssertEqual(settings.ghostModeExcludedPeerIds, [100, 200])
    }

    func testRuntimeGhostPolicyRespectsExpirationAndAccountIsolation() {
        let accountId = PeerId(101)
        let otherAccountId = PeerId(102)
        let excludedPeerId = PeerId(200)
        defer {
            MonogramRuntimePolicy.remove(accountPeerId: accountId)
            MonogramRuntimePolicy.remove(accountPeerId: otherAccountId)
        }
        var settings = MonogramSettings(ghostModeExcludedPeerIds: [excludedPeerId.toInt64()])
        settings.setGhostModeDuration(nil)
        MonogramRuntimePolicy.update(accountPeerId: accountId, settings: settings)
        MonogramRuntimePolicy.update(accountPeerId: otherAccountId, settings: MonogramSettings())
        XCTAssertTrue(MonogramRuntimePolicy.suppressesReadReceipts(accountPeerId: accountId))
        XCTAssertTrue(MonogramRuntimePolicy.suppressesInputActivity(accountPeerId: accountId))
        XCTAssertFalse(MonogramRuntimePolicy.suppressesReadReceipts(accountPeerId: accountId, peerId: excludedPeerId))
        XCTAssertFalse(MonogramRuntimePolicy.suppressesInputActivity(accountPeerId: accountId, peerId: excludedPeerId))
        XCTAssertFalse(MonogramRuntimePolicy.suppressesReadReceipts(accountPeerId: otherAccountId))
        settings.setGhostModeDuration(900, at: 100)
        MonogramRuntimePolicy.update(accountPeerId: accountId, settings: settings)
        XCTAssertFalse(MonogramRuntimePolicy.suppressesReadReceipts(accountPeerId: accountId))
        XCTAssertFalse(MonogramRuntimePolicy.suppressesInputActivity(accountPeerId: accountId))
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
