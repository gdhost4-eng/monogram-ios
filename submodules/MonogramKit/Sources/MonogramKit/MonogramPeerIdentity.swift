import Foundation

/// Peer identifiers and the approximate registration date shown in profiles,
/// the same rules as in Monogram for desktop (`monogram_info`).
public enum MonogramPeerIdentity {
    public enum Kind {
        case user
        case group
        case channel
    }

    /// The identifier in the form bots and other clients use: users as is, basic groups
    /// with a minus, channels and supergroups as -100 followed by the id padded to ten digits.
    public static func idString(kind: Kind, id: Int64) -> String {
        switch kind {
        case .user:
            return "\(id)"
        case .group:
            return "-\(id)"
        case .channel:
            return "\(-1000000000000 - id)"
        }
    }

    // Known (user id -> account creation time) points, ascending by id.
    // The creation time grows roughly monotonically with the id.
    private static let knownRegistrationPoints: [(id: Int64, date: Int32)] = [
        (2768409, 1383264000), // Nov 2013
        (7679610, 1388448000),
        (11538514, 1391212000),
        (15835244, 1392940000),
        (23646077, 1393459000),
        (38015510, 1393632000),
        (44634663, 1399334000),
        (54845238, 1411257000),
        (63263518, 1414454000),
        (101260938, 1425600000),
        (109393468, 1439078000),
        (143445125, 1448928000),
        (171295414, 1457481000),
        (222021233, 1465344000),
        (278941742, 1473465000),
        (328594461, 1482969000),
        (369669043, 1490918000),
        (400169472, 1501459000),
        (805158066, 1563208000), // Jul 2019
        (1974255900, 1634000000), // Oct 2021
        (5000000000, 1641000000), // ~ Jan 2022, 64-bit ids
        (7000000000, 1712000000) // ~ Apr 2024
    ]

    // After this id only the year is shown, the points are rougher there.
    private static let preciseRegistrationTill: Int64 = 1974255900

    /// Whether the estimate for `userId` is good enough to show the month, not only the year.
    public static func isRegistrationEstimatePrecise(userId: Int64) -> Bool {
        return userId <= self.preciseRegistrationTill
    }

    /// Approximate account creation time. Ids above the last known point are extrapolated
    /// with the speed of the last segment and never land after `now`.
    public static func estimatedRegistrationDate(userId: Int64, now: Int32) -> Int32 {
        let points = self.knownRegistrationPoints
        if userId <= points[0].id {
            return points[0].date
        }
        for i in 1 ..< points.count {
            let a = points[i - 1]
            let b = points[i]
            if userId <= b.id {
                let part = Double(userId - a.id) / Double(b.id - a.id)
                return a.date + Int32(part * Double(b.date - a.date))
            }
        }
        let a = points[points.count - 2]
        let b = points[points.count - 1]
        let speed = Double(b.date - a.date) / Double(b.id - a.id)
        let result = Double(b.date) + speed * Double(userId - b.id)
        return Int32(min(result, Double(now)))
    }
}
