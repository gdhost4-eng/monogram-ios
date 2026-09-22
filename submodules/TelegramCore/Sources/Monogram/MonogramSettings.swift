import Foundation
import SwiftSignalKit
import TelegramApi
import MtProtoKit

/// Global (not per-account) Monogram client settings.
///
/// Values live in `UserDefaults.standard` under the `monogram.` prefix and are cached in memory,
/// so reads are cheap enough for hot paths (typing, read receipts, message layout).
public final class MonogramSettings {
    public enum Key: String, CaseIterable {
        // Ghost mode: the master switch and what exactly it hides.
        case ghostMode
        case ghostNoReadMessages
        case ghostReadOnSend
        case ghostNoOnline
        case ghostNoTyping
        case ghostNoOtherActions
        case ghostNoStoryViews

        // Keeping what the other side tries to take back.
        case saveDeletedMessages
        case saveEditHistory
        case bypassCopyProtection

        // Asking before a send that is easy to do by accident.
        case confirmStickers
        case confirmGifs
        case confirmVoice

        // Interface.
        case hideSponsored
        case showPeerIds
        case localNotes
        case hideStories

        public var defaultValue: Bool {
            switch self {
            case .ghostMode, .ghostReadOnSend:
                return false
            case .ghostNoReadMessages, .ghostNoOnline, .ghostNoTyping, .ghostNoOtherActions, .ghostNoStoryViews:
                return true
            case .saveDeletedMessages, .saveEditHistory, .bypassCopyProtection:
                return true
            case .confirmStickers, .confirmGifs, .confirmVoice:
                return false
            case .hideSponsored, .showPeerIds, .localNotes:
                return true
            case .hideStories:
                return false
            }
        }

        fileprivate var defaultsKey: String {
            return "monogram." + self.rawValue
        }
    }

    private static let lock = NSLock()
    private static var cache: [Key: Bool] = [:]
    private static let version = ValuePromise<Int>(0, ignoreRepeated: false)
    private static var currentVersion: Int = 0

    public static func get(_ key: Key) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let value = self.cache[key] {
            return value
        }
        let value: Bool
        if UserDefaults.standard.object(forKey: key.defaultsKey) != nil {
            value = UserDefaults.standard.bool(forKey: key.defaultsKey)
        } else {
            value = key.defaultValue
        }
        self.cache[key] = value
        return value
    }

    public static func set(_ key: Key, _ value: Bool) {
        self.lock.lock()
        let changed = self.cache[key] != value
        self.cache[key] = value
        UserDefaults.standard.set(value, forKey: key.defaultsKey)
        self.currentVersion += 1
        let version = self.currentVersion
        self.lock.unlock()

        if changed {
            self.version.set(version)
        }
    }

    /// Fires immediately on subscription and after every change of any setting.
    public static func updates() -> Signal<Void, NoError> {
        return self.version.get()
        |> map { _ -> Void in
            return Void()
        }
    }

    /// Fires immediately on subscription and whenever the value of `key` changes.
    public static func value(_ key: Key) -> Signal<Bool, NoError> {
        return self.updates()
        |> map { _ -> Bool in
            return MonogramSettings.get(key)
        }
        |> distinctUntilChanged
    }
}

/// Ghost mode checks. Every check already includes the master switch.
public enum MonogramGhost {
    public static var isActive: Bool {
        return MonogramSettings.get(.ghostMode)
    }

    public static func setActive(_ value: Bool) {
        MonogramSettings.set(.ghostMode, value)
    }

    private static func enabled(_ key: MonogramSettings.Key) -> Bool {
        return MonogramSettings.get(.ghostMode) && MonogramSettings.get(key)
    }

    public static var blocksReadReceipts: Bool {
        return self.enabled(.ghostNoReadMessages)
    }

    public static var readsOnSend: Bool {
        return self.enabled(.ghostNoReadMessages) && MonogramSettings.get(.ghostReadOnSend)
    }

    public static var blocksOnline: Bool {
        return self.enabled(.ghostNoOnline)
    }

    public static var blocksTyping: Bool {
        return self.enabled(.ghostNoTyping)
    }

    public static var blocksOtherActions: Bool {
        return self.enabled(.ghostNoOtherActions)
    }

    public static var blocksStoryViews: Bool {
        return self.enabled(.ghostNoStoryViews)
    }

    private static let bypassLock = NSLock()
    private static var bypassedRequests = Set<ObjectIdentifier>()

    /// Lets one specific request through even while ghost mode is on
    /// (an explicit "read for real" or "read on send").
    static func allowRequest(_ description: FunctionDescription) {
        self.bypassLock.lock()
        self.bypassedRequests.insert(ObjectIdentifier(description))
        self.bypassLock.unlock()
    }

    private static let readRequestNames: Set<String> = [
        "messages.readHistory",
        "channels.readHistory",
        "messages.readDiscussion",
        "messages.readSavedHistory",
        "messages.readEncryptedHistory"
    ]

    private static let storyRequestNames: Set<String> = [
        "stories.readStories",
        "stories.incrementStoryViews"
    ]

    /// Called by `Network` for every outgoing request. Returns true when the request must not reach the server.
    static func shouldSuppressRequest(_ description: FunctionDescription) -> Bool {
        let name = description.name
        let isRead = self.readRequestNames.contains(name)
        let isStory = !isRead && self.storyRequestNames.contains(name)
        if !isRead && !isStory {
            return false
        }

        self.bypassLock.lock()
        let bypassed = self.bypassedRequests.remove(ObjectIdentifier(description)) != nil
        self.bypassLock.unlock()
        if bypassed {
            return false
        }

        if isRead {
            return self.blocksReadReceipts
        } else {
            return self.blocksStoryViews
        }
    }
}

/// What a request suppressed by ghost mode reports back: a plain success where the caller
/// only expects an acknowledgement, and an error (which every read/story caller swallows) otherwise.
func monogramSuppressedRequestResult<T>() -> Signal<T, MTRpcError> {
    if let value = Api.Bool.boolTrue as? T {
        return .single(value)
    }
    if let value = [Int32]() as? T {
        return .single(value)
    }
    return .fail(MTRpcError(errorCode: 400, errorDescription: "MONOGRAM_GHOST_MODE"))
}
