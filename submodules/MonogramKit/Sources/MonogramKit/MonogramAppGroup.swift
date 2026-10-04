import Foundation

/// The App Group the app shares with its extensions. Its name is derived the same way the app
/// and the extensions derive it for the account data: `group.` plus the bundle id of the main app.
public enum MonogramAppGroup {
    /// App extensions live in `.appex` bundles inside the app.
    public static func isExtension(bundlePath: String) -> Bool {
        return bundlePath.hasSuffix(".appex")
    }

    /// Nil when the bundle id is missing or, for an extension, has no parent component.
    public static func name(bundleIdentifier: String?, bundlePath: String) -> String? {
        guard let bundleIdentifier = bundleIdentifier, !bundleIdentifier.isEmpty else {
            return nil
        }
        if self.isExtension(bundlePath: bundlePath) {
            // An extension's bundle id is the app's one plus the last component.
            guard let lastDotRange = bundleIdentifier.range(of: ".", options: [.backwards]) else {
                return nil
            }
            let baseBundleIdentifier = String(bundleIdentifier[..<lastDotRange.lowerBound])
            if baseBundleIdentifier.isEmpty {
                return nil
            }
            return "group.\(baseBundleIdentifier)"
        } else {
            return "group.\(bundleIdentifier)"
        }
    }
}
