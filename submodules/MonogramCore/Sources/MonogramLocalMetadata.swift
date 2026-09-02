import Foundation

enum MonogramLocalMetadata {
    static func normalizedNote(_ note: String?) -> String? {
        let value = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    static func matches(
        note: String?,
        tags: [String],
        query: String,
        requiredTags: [String]
    ) -> Bool {
        let normalizedRequiredTags = MonogramTag.normalize(requiredTags)
        guard normalizedRequiredTags.allSatisfy({ tags.contains($0) }) else {
            return false
        }

        let normalizedQuery = searchable(query)
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let values = [note ?? ""] + tags + tags.map { "#\($0)" }
        return values.contains { searchable($0).contains(normalizedQuery) }
    }

    private static func searchable(_ value: String) -> String {
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
    }
}
