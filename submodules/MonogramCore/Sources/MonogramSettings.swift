import Foundation

// Postbox does not support Dictionary's generic scalar encoding or allKeys.
// Encode Bool values through the typed keyed API and persist the key list.
private struct MonogramFeatureOverrides: Codable {
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { return nil }

        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    let values: [String: Bool]

    init(_ values: [String: Bool]) {
        self.values = values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let keys = try container.decodeIfPresent([String].self, forKey: Key(stringValue: "_keys"))
            ?? MonogramFeatureId.allCases.map { $0.rawValue }
        var values: [String: Bool] = [:]
        for key in keys {
            if let value = try container.decodeIfPresent(Bool.self, forKey: Key(stringValue: key)) {
                values[key] = value
            }
        }
        self.values = values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        let keys = self.values.keys.sorted()
        try container.encode(keys, forKey: Key(stringValue: "_keys"))
        for key in keys {
            if let value = self.values[key] {
                try container.encode(value, forKey: Key(stringValue: key))
            }
        }
    }
}

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
        if id == .ghostMode {
            self.ghostModeExpiresAt = nil
        }
    }

    public mutating func reset(_ id: MonogramFeatureId) {
        self.featureOverrides.removeValue(forKey: id.rawValue)
        self.experimentalFeatureOverrides.removeValue(forKey: id.rawValue)
        if id == .ghostMode {
            self.ghostModeExpiresAt = nil
        }
    }

    public func isGhostModeActive(at timestamp: Int64 = Int64(Date().timeIntervalSince1970)) -> Bool {
        return self.isEnabled(.ghostMode) && (self.ghostModeExpiresAt.map { $0 > timestamp } ?? true)
    }

    public mutating func setGhostModeDuration(_ duration: Int64?, at timestamp: Int64 = Int64(Date().timeIntervalSince1970)) {
        self.setEnabled(true, for: .ghostMode)
        self.ghostModeExpiresAt = duration.map { timestamp + max(0, $0) }
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
        self.featureOverrides = try container.decodeIfPresent(MonogramFeatureOverrides.self, forKey: .featureOverrides)?.values ?? [:]
        self.experimentalFeatureOverrides = try container.decodeIfPresent(MonogramFeatureOverrides.self, forKey: .experimentalFeatureOverrides)?.values ?? [:]
        self.ghostModeExpiresAt = try container.decodeIfPresent(Int64.self, forKey: .ghostModeExpiresAt)
        self.ghostModeExcludedPeerIds = try container.decodeIfPresent([Int64].self, forKey: .ghostModeExcludedPeerIds) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.schemaVersion, forKey: .schemaVersion)
        try container.encode(MonogramFeatureOverrides(self.featureOverrides), forKey: .featureOverrides)
        try container.encode(MonogramFeatureOverrides(self.experimentalFeatureOverrides), forKey: .experimentalFeatureOverrides)
        try container.encodeIfPresent(self.ghostModeExpiresAt, forKey: .ghostModeExpiresAt)
        try container.encode(self.ghostModeExcludedPeerIds, forKey: .ghostModeExcludedPeerIds)
    }
}

