import Foundation

public enum MonogramSettingScope: String, Codable, CaseIterable, Hashable {
    case global
    case account
    case chat
}

public enum MonogramFeatureId: String, Codable, CaseIterable, Hashable {
    case advancedSettings
    case appearanceEnhancements
    case localBookmarks
    case localNotes
    case customTags
    case searchEnhancements
    case translationControls
    case powerUserInformation
    case mediaEnhancements
    case storageEnhancements
    case developerTools
}

public struct MonogramFeatureDescriptor: Codable, Equatable {
    public let id: MonogramFeatureId
    public let defaultValue: Bool
    public let isExperimental: Bool
    public let scopes: [MonogramSettingScope]

    public init(
        id: MonogramFeatureId,
        defaultValue: Bool,
        isExperimental: Bool,
        scopes: [MonogramSettingScope]
    ) {
        self.id = id
        self.defaultValue = defaultValue
        self.isExperimental = isExperimental
        self.scopes = scopes
    }
}

public enum MonogramFeatureRegistry {
    public static let all: [MonogramFeatureDescriptor] = [
        MonogramFeatureDescriptor(id: .advancedSettings, defaultValue: true, isExperimental: false, scopes: [.global]),
        MonogramFeatureDescriptor(id: .appearanceEnhancements, defaultValue: false, isExperimental: false, scopes: [.global, .account, .chat]),
        MonogramFeatureDescriptor(id: .localBookmarks, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .localNotes, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .customTags, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .searchEnhancements, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .translationControls, defaultValue: false, isExperimental: false, scopes: [.account, .chat]),
        MonogramFeatureDescriptor(id: .powerUserInformation, defaultValue: false, isExperimental: false, scopes: [.global, .account]),
        MonogramFeatureDescriptor(id: .mediaEnhancements, defaultValue: false, isExperimental: false, scopes: [.global, .account, .chat]),
        MonogramFeatureDescriptor(id: .storageEnhancements, defaultValue: false, isExperimental: false, scopes: [.global, .account]),
        MonogramFeatureDescriptor(id: .developerTools, defaultValue: false, isExperimental: true, scopes: [.global]),
    ]

    private static let descriptorsById: [MonogramFeatureId: MonogramFeatureDescriptor] = {
        return Dictionary(uniqueKeysWithValues: MonogramFeatureRegistry.all.map { descriptor in
            return (descriptor.id, descriptor)
        })
    }()

    public static func descriptor(for id: MonogramFeatureId) -> MonogramFeatureDescriptor {
        guard let descriptor = self.descriptorsById[id] else {
            preconditionFailure("Every Monogram feature identifier must be registered")
        }
        return descriptor
    }
}
