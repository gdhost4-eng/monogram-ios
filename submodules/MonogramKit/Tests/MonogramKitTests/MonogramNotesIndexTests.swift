import XCTest
import MonogramKit

final class MonogramNotesIndexTests: XCTestCase {
    func testNoteIsTrimmed() {
        var index = MonogramNotesIndex()
        XCTAssertEqual(index.set("  коллега из отдела продаж \n", for: 10), "коллега из отдела продаж")
        XCTAssertEqual(index.note(for: 10), "коллега из отдела продаж")
    }

    func testEmptyNoteRemovesTheNote() {
        var index = MonogramNotesIndex(notes: [10: "заметка"])
        XCTAssertNil(index.set("   ", for: 10))
        XCTAssertNil(index.note(for: 10))
        XCTAssertTrue(index.peers(matching: "заметка").isEmpty)

        index.set("ещё одна", for: 11)
        XCTAssertNil(index.set(nil, for: 11))
        XCTAssertTrue(index.notes.isEmpty)
    }

    func testNoteIsCutToMaximumLength() {
        let long = String(repeating: "я", count: MonogramNotesIndex.maximumNoteLength + 100)
        XCTAssertEqual(MonogramNotesIndex.normalized(long)?.count, MonogramNotesIndex.maximumNoteLength)
    }

    func testSearchFindsPeersByWordsOfTheNote() {
        let index = MonogramNotesIndex(notes: [
            3: "Сантехник, приходил в марте",
            1: "Коллега из отдела продаж",
            2: "сосед, отдел кадров"
        ])
        XCTAssertEqual(index.peers(matching: "отдел"), [1, 2])
        XCTAssertEqual(index.peers(matching: "ОТДЕЛ продаж"), [1])
        XCTAssertEqual(index.peers(matching: "март"), [3])
        XCTAssertEqual(index.peers(matching: "дел"), [])
        XCTAssertEqual(index.peers(matching: ""), [])
    }

    func testSearchFollowsEdits() {
        var index = MonogramNotesIndex(notes: [1: "первый вариант"])
        index.set("второй вариант", for: 1)
        XCTAssertEqual(index.peers(matching: "первый"), [])
        XCTAssertEqual(index.peers(matching: "второй"), [1])
    }

    func testStorageKeyRoundTrip() {
        let key = MonogramNotesIndex.storageKey(account: 123, peer: 456)
        XCTAssertEqual(key, "monogram.note.123.456")
        XCTAssertEqual(MonogramNotesIndex.peer(fromStorageKey: key, account: 123), 456)
    }

    func testStorageKeyOfAnotherAccountIsIgnored() {
        let key = MonogramNotesIndex.storageKey(account: 123, peer: 456)
        XCTAssertNil(MonogramNotesIndex.peer(fromStorageKey: key, account: 12))
        XCTAssertNil(MonogramNotesIndex.peer(fromStorageKey: key, account: 1234))
        XCTAssertNil(MonogramNotesIndex.peer(fromStorageKey: "monogram.ghostMode", account: 123))
        XCTAssertNil(MonogramNotesIndex.peer(fromStorageKey: "monogram.note.123.abc", account: 123))
    }

    func testStorageKeyKeepsNegativeIds() {
        let key = MonogramNotesIndex.storageKey(account: 123, peer: -456)
        XCTAssertEqual(MonogramNotesIndex.peer(fromStorageKey: key, account: 123), -456)
    }
}
