import Foundation

public enum MonogramSettingScope: String, Codable, CaseIterable, Hashable {
    case global
    case account
    case chat
}

public enum MonogramFeatureId: String, Codable, CaseIterable, Hashable {
    case advancedSettings
    case ghostMode
    case offlineEntry
    case ghostReadReceipts
    case ghostTypingActivity
    case preserveDeletedMessages
    case preserveEditHistory
    case localNotes
    case powerUserInformation
    case localMessagePins
    case confirmVoiceMessages
    case suppressAutomaticKeyboard
    case suppressIncomingAutoScroll
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
        MonogramFeatureDescriptor(id: .offlineEntry, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .ghostMode, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .ghostReadReceipts, defaultValue: true, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .ghostTypingActivity, defaultValue: true, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .preserveDeletedMessages, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .preserveEditHistory, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .localNotes, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .powerUserInformation, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .localMessagePins, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .confirmVoiceMessages, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .suppressAutomaticKeyboard, defaultValue: false, isExperimental: false, scopes: [.account]),
        MonogramFeatureDescriptor(id: .suppressIncomingAutoScroll, defaultValue: false, isExperimental: false, scopes: [.account]),
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
