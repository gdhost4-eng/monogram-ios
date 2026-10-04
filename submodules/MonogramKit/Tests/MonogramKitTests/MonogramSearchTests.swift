import XCTest
import MonogramKit

// The same cases as `TestSearch` in Monogram for desktop (`monogram/tests/monogram_tests.cpp`),
// so that both clients find the same things.
final class MonogramSearchTests: XCTestCase {
    func testWordsAreLowercasedAndSplitByPunctuation() {
        XCTAssertEqual(MonogramSearch.words("Привет, МИР! hello_world 42"), ["привет", "мир", "hello", "world", "42"])
    }

    func testWordsTreatYoAsYe() {
        XCTAssertEqual(MonogramSearch.words("ёлка Ёж"), ["елка", "еж"])
    }

    func testWordsTreatDecomposedYoAsYe() {
        // "е" followed by the combining diaeresis, as some keyboards and file systems produce it.
        XCTAssertEqual(MonogramSearch.words("е\u{0308}лка"), ["елка"])
    }

    func testWordsHaveNoDuplicates() {
        XCTAssertEqual(MonogramSearch.words("да да ДА"), ["да"])
    }

    func testWordsOfPunctuationAreEmpty() {
        XCTAssertTrue(MonogramSearch.words("  ...  ").isEmpty)
    }

    func testQueryWordMatchesPrefixOfTextWord() {
        XCTAssertTrue(MonogramSearch.matches(text: "Встречаемся завтра в 10", query: "встреч"))
        XCTAssertTrue(MonogramSearch.matches(text: "elka stoit", query: "STO"))
        XCTAssertTrue(MonogramSearch.matches(text: "Ёлка стоит", query: "елк"))
    }

    func testEveryQueryWordHasToMatchInAnyOrder() {
        XCTAssertTrue(MonogramSearch.matches(text: "Встречаемся завтра в 10", query: "ЗАВТРА встреча"))
        XCTAssertFalse(MonogramSearch.matches(text: "Встречаемся завтра", query: "завтра вечером"))
    }

    func testMiddleOfWordDoesNotMatch() {
        XCTAssertFalse(MonogramSearch.matches(text: "Встречаемся завтра", query: "треча"))
    }

    func testEmptyQueryMatchesNothing() {
        XCTAssertFalse(MonogramSearch.matches(text: "Что угодно", query: ""))
        XCTAssertFalse(MonogramSearch.matches(text: "Что угодно", query: "!!"))
    }
}
