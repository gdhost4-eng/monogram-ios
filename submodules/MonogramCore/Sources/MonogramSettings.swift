import Foundation

public struct MonogramSettings: Codable, Equatable {
    public static let currentSchemaVersion: Int32 = 2

    public var schemaVersion: Int32
    public var featureOverrides: [String: Bool]
    public var experimentalFeatureOverrides: [String: Bool]
    public var ghostModeExpiresAt: Int64?
    public var ghostModeExcludedPeerIds: [Int64]

    public init(
        schemaVersion: Int32 = MonogramSettings.currentSchemaVersion,
        featureOverrides: [String: Bool] = [:],
        experimentalFeatureOverrides: [String: Bool] = [:],
        ghostModeExpiresAt: Int64? = nil,
        ghostModeExcludedPeerIds: [Int64] = []
    ) {
        self.schemaVersion = schemaVersion
        self.featureOverrides = featureOverrides
        self.experimentalFeatureOverrides = experimentalFeatureOverrides
        self.ghostModeExpiresAt = ghostModeExpiresAt
        self.ghostModeExcludedPeerIds = ghostModeExcludedPeerIds
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
        case ghostModeExpiresAt
        case ghostModeExcludedPeerIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int32.self, forKey: .schemaVersion) ?? 0
        self.featureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .featureOverrides) ?? [:]
        self.experimentalFeatureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .experimentalFeatureOverrides) ?? [:]
        self.ghostModeExpiresAt = try container.decodeIfPresent(Int64.self, forKey: .ghostModeExpiresAt)
        self.ghostModeExcludedPeerIds = try container.decodeIfPresent([Int64].self, forKey: .ghostModeExcludedPeerIds) ?? []
    }
}

