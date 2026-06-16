// SPDX-FileCopyrightText: 2025 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os.log

/// Manages app extension discovery and validation
public final class ExtensionManager {
    private static let logger = Logger(subsystem: "com.scalecloud.sign", category: "ExtensionManager")
    
    /// Discovers extensions within an app bundle
    /// - Parameter appBundleURL: The URL to the .app bundle
    /// - Returns: Array of discovered AppExtension objects
    public static func discoverExtensions(in appBundleURL: URL) throws -> [AppExtension] {
        let pluginsURL = appBundleURL.appendingPathComponent("PlugIns")
        
        guard FileManager.default.fileExists(atPath: pluginsURL.path) else {
            logger.info("No PlugIns directory found in app bundle")
            return []
        }
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: pluginsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        let extensionURLs = contents.filter { $0.pathExtension == "appex" }
        logger.info("Found \(extensionURLs.count) extension bundles")
        
        var discoveredExtensions: [AppExtension] = []
        
        for extensionURL in extensionURLs {
            if let appExtension = try? extractExtensionInfo(from: extensionURL) {
                discoveredExtensions.append(appExtension)
                logger.info("Discovered extension: \(appExtension.name) (\(appExtension.bundleIdentifier))")
            } else {
                logger.warning("Failed to extract info from extension at \(extensionURL.path)")
            }
        }
        
        return discoveredExtensions
    }
    
    /// Extracts extension information from a bundle
    private static func extractExtensionInfo(from extensionURL: URL) throws -> AppExtension {
        let infoPlistURL = extensionURL.appendingPathComponent("Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw ExtensionError.missingInfoPlist(path: extensionURL.path)
        }
        
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        guard let infoPlist = try PropertyListSerialization.propertyList(
            from: infoPlistData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw ExtensionError.invalidInfoPlist(path: infoPlistURL.path)
        }
        
        guard let bundleIdentifier = infoPlist["CFBundleIdentifier"] as? String else {
            throw ExtensionError.missingBundleIdentifier(path: infoPlistURL.path)
        }
        
        let extensionName = extensionURL.deletingPathExtension().lastPathComponent
        let relativePath = "PlugIns/\(extensionURL.lastPathComponent)"
        
        // Determine extension type from bundle identifier or extension points
        let type = determineExtensionType(from: infoPlist, bundleIdentifier: bundleIdentifier)
        
        return AppExtension(
            name: extensionName,
            bundleIdentifier: bundleIdentifier,
            type: type,
            relativePath: relativePath
        )
    }
    
    /// Determines the extension type from Info.plist
    private static func determineExtensionType(from infoPlist: [String: Any], bundleIdentifier: String) -> ExtensionType {
        // Check for NSExtension dictionary
        if let nsExtension = infoPlist["NSExtension"] as? [String: Any],
           let extensionPointIdentifier = nsExtension["NSExtensionPointIdentifier"] as? String {
            switch extensionPointIdentifier {
            case "com.apple.share-services":
                return .share
            case "com.apple.fileprovider-nonreplicated":
                return .fileProvider
            case "com.apple.fileprovider-ui":
                return .fileProviderUI
            case "com.apple.usernotifications.service":
                return .notificationService
            case "com.apple.widgetkit-extension":
                return .widget
            case "com.apple.intents-service":
                return .intents
            case "com.apple.services":
                return .action
            default:
                break
            }
        }
        
        // Fallback: determine from bundle identifier suffix
        if bundleIdentifier.contains("Share") {
            return .share
        } else if bundleIdentifier.contains("File-Provider") {
            return bundleIdentifier.contains("-UI") ? .fileProviderUI : .fileProvider
        } else if bundleIdentifier.contains("Notification") {
            return .notificationService
        } else if bundleIdentifier.contains("Widget") || bundleIdentifier.contains("Intent") {
            return bundleIdentifier.contains("Intent") ? .intents : .widget
        } else if bundleIdentifier.contains("Action") {
            return .action
        }
        
        logger.warning("Could not determine extension type for \(bundleIdentifier), defaulting to share")
        return .share
    }
    
    /// Validates that all expected extensions are present
    /// - Parameters:
    ///   - discovered: Array of discovered extensions
    ///   - expected: Array of expected extensions
    /// - Returns: Array of missing extension bundle identifiers
    public static func validateExtensions(
        discovered: [AppExtension],
        expected: [AppExtension]
    ) -> [String] {
        let discoveredIDs = Set(discovered.map { $0.bundleIdentifier })
        let expectedIDs = Set(expected.map { $0.bundleIdentifier })
        let missingIDs = expectedIDs.subtracting(discoveredIDs)
        
        if !missingIDs.isEmpty {
            logger.warning("Missing extensions: \(missingIDs.joined(separator: ", "))")
        }
        
        return Array(missingIDs)
    }
    
    /// Verifies that an extension bundle contains required files
    /// - Parameter extensionURL: URL to the extension bundle
    /// - Returns: True if valid, false otherwise
    public static func verifyExtensionBundle(at extensionURL: URL) -> Bool {
        let infoPlistURL = extensionURL.appendingPathComponent("Info.plist")
        let hasInfoPlist = FileManager.default.fileExists(atPath: infoPlistURL.path)
        
        if !hasInfoPlist {
            logger.error("Extension at \(extensionURL.path) missing Info.plist")
            return false
        }
        
        // Check for executable (should match bundle name without extension)
        let executableName = extensionURL.deletingPathExtension().lastPathComponent
        let executableURL = extensionURL.appendingPathComponent(executableName)
        let hasExecutable = FileManager.default.fileExists(atPath: executableURL.path)
        
        if !hasExecutable {
            logger.warning("Extension at \(extensionURL.path) missing executable: \(executableName)")
            // Don't fail, as the executable name might be different
        }
        
        return true
    }
}

/// Errors that can occur during extension management
public enum ExtensionError: LocalizedError {
    case missingInfoPlist(path: String)
    case invalidInfoPlist(path: String)
    case missingBundleIdentifier(path: String)
    case extensionNotFound(bundleIdentifier: String)
    
    public var errorDescription: String? {
        switch self {
        case .missingInfoPlist(let path):
            return "Info.plist not found at \(path)"
        case .invalidInfoPlist(let path):
            return "Invalid Info.plist at \(path)"
        case .missingBundleIdentifier(let path):
            return "CFBundleIdentifier not found in Info.plist at \(path)"
        case .extensionNotFound(let bundleIdentifier):
            return "Extension not found: \(bundleIdentifier)"
        }
    }
}
