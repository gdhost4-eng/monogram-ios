import Foundation
import TelegramCore

enum ApplicationStartupEnvironmentError: Error {
    case missingBundleIdentifier
    case missingApplicationSupportDirectory
    case unableToCreateFallbackContainer(Error)
}

extension ApplicationStartupEnvironmentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            return "The application bundle identifier is missing."
        case .missingApplicationSupportDirectory:
            return "The application support directory is unavailable."
        case let .unableToCreateFallbackContainer(error):
            return "The fallback storage container could not be created: \(error.localizedDescription)"
        }
    }
}

struct ApplicationStartupEnvironment {
    static let uiTestDataDirectoryName = "telegram-ui-tests-data"

    let baseAppBundleId: String
    let appGroupName: String
    let containerUrl: URL
    let rootPath: String
    let isUITest: Bool
    let usesFallbackContainer: Bool

    static func resolve(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        arguments: [String] = CommandLine.arguments
    ) throws -> ApplicationStartupEnvironment {
        guard let baseAppBundleId = bundle.bundleIdentifier else {
            throw ApplicationStartupEnvironmentError.missingBundleIdentifier
        }

        let appGroupName = "group.\(baseAppBundleId)"
        let appGroupUrl = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupName
        )

        let containerUrl: URL
        let usesFallbackContainer: Bool
        if let appGroupUrl {
            containerUrl = appGroupUrl
            usesFallbackContainer = false
        } else {
            guard let applicationSupportUrl = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw ApplicationStartupEnvironmentError.missingApplicationSupportDirectory
            }
            let fallbackUrl = applicationSupportUrl
                .appendingPathComponent("Monogram", isDirectory: true)
                .appendingPathComponent(baseAppBundleId, isDirectory: true)
            do {
                try fileManager.createDirectory(
                    at: fallbackUrl,
                    withIntermediateDirectories: true
                )
            } catch {
                throw ApplicationStartupEnvironmentError.unableToCreateFallbackContainer(error)
            }
            containerUrl = fallbackUrl
            usesFallbackContainer = true
        }

        let isUITest = arguments.contains("--ui-test")
        let basePath: String
        if isUITest {
            basePath = containerUrl
                .appendingPathComponent(Self.uiTestDataDirectoryName, isDirectory: true)
                .path
        } else {
            basePath = containerUrl.path
        }

        return ApplicationStartupEnvironment(
            baseAppBundleId: baseAppBundleId,
            appGroupName: appGroupName,
            containerUrl: containerUrl,
            rootPath: rootPathForBasePath(basePath),
            isUITest: isUITest,
            usesFallbackContainer: usesFallbackContainer
        )
    }

    func prepareFileSystem(fileManager: FileManager = .default) throws {
        if self.isUITest {
            let testDataUrl = self.containerUrl.appendingPathComponent(
                Self.uiTestDataDirectoryName,
                isDirectory: true
            )
            if fileManager.fileExists(atPath: testDataUrl.path) {
                try fileManager.removeItem(at: testDataUrl)
            }
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: self.rootPath, isDirectory: true),
                withIntermediateDirectories: true
            )
        } else {
            try performAppGroupUpgradesSynchronously(
                appGroupPath: self.containerUrl.path,
                rootPath: self.rootPath
            )
        }
    }

    static func configureSharedContainerIfAvailable(
        _ configuration: URLSessionConfiguration,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        guard let baseAppBundleId = bundle.bundleIdentifier else {
            return
        }
        let appGroupName = "group.\(baseAppBundleId)"
        if fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupName
        ) != nil {
            configuration.sharedContainerIdentifier = appGroupName
        }
    }
}
