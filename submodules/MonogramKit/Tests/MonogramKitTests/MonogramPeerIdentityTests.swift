import XCTest
import MonogramKit

final class MonogramPeerIdentityTests: XCTestCase {
    func testUserAndGroupIds() {
        XCTAssertEqual(MonogramPeerIdentity.idString(kind: .user, id: 777000), "777000")
        XCTAssertEqual(MonogramPeerIdentity.idString(kind: .group, id: 123456), "-123456")
    }

    func testChannelIdIsPaddedToTenDigitsAfterMinus100() {
        XCTAssertEqual(MonogramPeerIdentity.idString(kind: .channel, id: 1234567890), "-1001234567890")
        // Old channels have shorter ids; "-100" + id would give a different, wrong chat.
        XCTAssertEqual(MonogramPeerIdentity.idString(kind: .channel, id: 123456789), "-1000123456789")
        XCTAssertEqual(MonogramPeerIdentity.idString(kind: .channel, id: 1), "-1000000000001")
    }

    func testRegistrationOfKnownPointsIsExact() {
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 2768409, now: 2000000000), 1383264000)
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 805158066, now: 2000000000), 1563208000)
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 7000000000, now: 2000000000), 1712000000)
    }

    func testRegistrationBeforeFirstPointIsClamped() {
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 1, now: 2000000000), 1383264000)
    }

    func testRegistrationIsInterpolatedBetweenPoints() {
        // Halfway between (5000000000, 1641000000) and (7000000000, 1712000000).
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 6000000000, now: 2000000000), 1676500000)
    }

    func testRegistrationGrowsWithId() {
        var previous: Int32 = 0
        for userId in stride(from: Int64(1000000), through: Int64(9000000000), by: 37000000) {
            let date = MonogramPeerIdentity.estimatedRegistrationDate(userId: userId, now: 2000000000)
            XCTAssertGreaterThanOrEqual(date, previous, "id \(userId)")
            previous = date
        }
    }

    func testRegistrationIsExtrapolatedButNeverInTheFuture() {
        // One more segment of the same length after the last point: +71000000 seconds.
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 9000000000, now: 2000000000), 1783000000)
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: 9000000000, now: 1750000000), 1750000000)
        XCTAssertEqual(MonogramPeerIdentity.estimatedRegistrationDate(userId: Int64.max / 2, now: 1750000000), 1750000000)
    }

    func testOnlyOldIdsHavePreciseEstimate() {
        XCTAssertTrue(MonogramPeerIdentity.isRegistrationEstimatePrecise(userId: 1974255900))
        XCTAssertFalse(MonogramPeerIdentity.isRegistrationEstimatePrecise(userId: 1974255901))
    }
}
