import Foundation

public enum MonogramAccountPolicy {
    /// Monogram does not impose an application-level maximum. Device, iOS and
    /// Telegram API resource constraints are handled independently.
    public static let applicationAccountLimit: Int? = nil

    public static var allowsAddingAnotherAccount: Bool {
        return self.applicationAccountLimit == nil
    }
}

