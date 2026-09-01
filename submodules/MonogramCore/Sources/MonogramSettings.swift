import Foundation

public struct MonogramSettings: Codable, Equatable {
    public static let currentSchemaVersion: Int32 = 1

    public var schemaVersion: Int32
    public var featureOverrides: [String: Bool]
    public var experimentalFeatureOverrides: [String: Bool]

    public init(
        schemaVersion: Int32 = MonogramSettings.currentSchemaVersion,
        featureOverrides: [String: Bool] = [:],
        experimentalFeatureOverrides: [String: Bool] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.featureOverrides = featureOverrides
        self.experimentalFeatureOverrides = experimentalFeatureOverrides
    }

    public func isEnabled(_ id: MonogramFeatureId) -> Bool {
        let descriptor = MonogramFeatureRegistry.descriptor(for: id)
        let overrides = descriptor.isExperimental ? self.experimentalFeatureOverrides : self.featureOverrides
        return overrides[id.rawValue] ?? descriptor.defaultValue
    }

    public mutating func setEnabled(_ value: Bool, for id: MonogramFeatureId) {
        let descriptor = MonogramFeatureRegistry.descriptor(for: id)
        if descriptor.isExperimental {
            self.experimentalFeatureOverrides[id.rawValue] = value
        } else {
            self.featureOverrides[id.rawValue] = value
        }
    }

    public mutating func reset(_ id: MonogramFeatureId) {
        self.featureOverrides.removeValue(forKey: id.rawValue)
        self.experimentalFeatureOverrides.removeValue(forKey: id.rawValue)
    }

    public func migratedToCurrentSchema() -> MonogramSettings {
        guard self.schemaVersion < MonogramSettings.currentSchemaVersion else {
            return self
        }

        var result = self
        result.schemaVersion = MonogramSettings.currentSchemaVersion
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case featureOverrides
        case experimentalFeatureOverrides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int32.self, forKey: .schemaVersion) ?? 0
        self.featureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .featureOverrides) ?? [:]
        self.experimentalFeatureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .experimentalFeatureOverrides) ?? [:]
    }
}

