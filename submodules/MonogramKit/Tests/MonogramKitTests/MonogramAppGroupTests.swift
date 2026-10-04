import XCTest
import MonogramKit

final class MonogramAppGroupTests: XCTestCase {
    func testMainAppUsesItsOwnBundleId() {
        XCTAssertEqual(
            MonogramAppGroup.name(bundleIdentifier: "org.monogram.Monogram", bundlePath: "/private/var/containers/Bundle/Application/1/Telegram.app"),
            "group.org.monogram.Monogram"
        )
    }

    func testExtensionDropsItsOwnComponent() {
        XCTAssertEqual(
            MonogramAppGroup.name(bundleIdentifier: "org.monogram.Monogram.Share", bundlePath: "/private/var/containers/Bundle/Application/1/Telegram.app/PlugIns/ShareExtension.appex"),
            "group.org.monogram.Monogram"
        )
        XCTAssertEqual(
            MonogramAppGroup.name(bundleIdentifier: "org.monogram.Monogram.NotificationService", bundlePath: "/Telegram.app/PlugIns/NotificationServiceExtension.appex"),
            "group.org.monogram.Monogram"
        )
    }

    func testMainAppAndItsExtensionsShareOneGroup() {
        let app = MonogramAppGroup.name(bundleIdentifier: "com.example.app", bundlePath: "/a/Telegram.app")
        let share = MonogramAppGroup.name(bundleIdentifier: "com.example.app.Share", bundlePath: "/a/Telegram.app/PlugIns/Share.appex")
        XCTAssertNotNil(app)
        XCTAssertEqual(app, share)
    }

    func testMissingBundleIdGivesNoGroup() {
        XCTAssertNil(MonogramAppGroup.name(bundleIdentifier: nil, bundlePath: "/a/Telegram.app"))
        XCTAssertNil(MonogramAppGroup.name(bundleIdentifier: "", bundlePath: "/a/Telegram.app"))
    }

    func testExtensionWithoutParentComponentGivesNoGroup() {
        XCTAssertNil(MonogramAppGroup.name(bundleIdentifier: "Share", bundlePath: "/a/Telegram.app/PlugIns/Share.appex"))
        XCTAssertNil(MonogramAppGroup.name(bundleIdentifier: ".Share", bundlePath: "/a/Telegram.app/PlugIns/Share.appex"))
    }

    func testExtensionIsRecognizedByBundlePath() {
        XCTAssertTrue(MonogramAppGroup.isExtension(bundlePath: "/a/Telegram.app/PlugIns/Share.appex"))
        XCTAssertFalse(MonogramAppGroup.isExtension(bundlePath: "/a/Telegram.app"))
    }
}
