import Foundation

public enum MonogramTag {
    public static func parse(_ text: String) -> [String] {
        return self.normalize(text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;"))))
    }

    public static func normalize(_ tags: [String]) -> [String] {
        var result: [String] = []
        var existing = Set<String>()
        for tag in tags {
            var value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            while value.hasPrefix("#") {
                value.removeFirst()
            }
            value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !value.isEmpty && existing.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }
}
