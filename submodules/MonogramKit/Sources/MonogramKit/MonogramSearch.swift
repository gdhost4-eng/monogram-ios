import Foundation

/// Word matching for local searches, the same rules as in Monogram for desktop (`monogram_search`):
/// every word of the query starts some word of the text; case, "ё" / "е" and punctuation do not matter.
public enum MonogramSearch {
    /// Lowercased words of `text` without duplicates, in the order they first appear.
    public static func words(_ text: String) -> [String] {
        let normalized = text.precomposedStringWithCanonicalMapping.lowercased().replacingOccurrences(of: "ё", with: "е")
        var result: [String] = []
        var seen = Set<String>()
        var current = String.UnicodeScalarView()
        for scalar in normalized.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                current.append(scalar)
            } else if !current.isEmpty {
                let word = String(current)
                if seen.insert(word).inserted {
                    result.append(word)
                }
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty {
            let word = String(current)
            if seen.insert(word).inserted {
                result.append(word)
            }
        }
        return result
    }

    /// Both lists are expected from `words(_:)`. An empty query matches nothing.
    public static func matches(textWords: [String], queryWords: [String]) -> Bool {
        if queryWords.isEmpty {
            return false
        }
        for word in queryWords {
            if !textWords.contains(where: { $0.hasPrefix(word) }) {
                return false
            }
        }
        return true
    }

    public static func matches(text: String, query: String) -> Bool {
        return self.matches(textWords: self.words(text), queryWords: self.words(query))
    }
}
