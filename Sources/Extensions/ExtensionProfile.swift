// SPDX-FileCopyrightText: 2025 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Represents an app extension within the main application bundle
public struct AppExtension: Codable, Equatable {
    /// The display name of the extension (e.g., "Share", "Widget")
    public let name: String
    
    /// The bundle identifier of the extension
    public let bundleIdentifier: String
    
    /// The extension type (appex, etc.)
    public let type: ExtensionType
    
    /// The relative path within the app bundle's PlugIns directory
    public let relativePath: String
    
    /// Creates an app extension
    public init(name: String, bundleIdentifier: String, type: ExtensionType, relativePath: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.type = type
        self.relativePath = relativePath
    }
    
    /// Known extensions for ScaleCloudApp
    public static let knownExtensions: [AppExtension] = [
        AppExtension(
            name: "Share",
            bundleIdentifier: "it.twsweb.Nextcloud.Share",
            type: .share,
            relativePath: "PlugIns/Share.appex"
        ),
        AppExtension(
            name: "File Provider Extension",
            bundleIdentifier: "it.twsweb.Nextcloud.File-Provider-Extension",
            type: .fileProvider,
            relativePath: "PlugIns/File Provider Extension.appex"
        ),
        AppExtension(
            name: "File Provider Extension UI",
            bundleIdentifier: "it.twsweb.Nextcloud.File-Provider-Extension-UI",
            type: .fileProviderUI,
            relativePath: "PlugIns/File Provider Extension UI.appex"
        ),
        AppExtension(
            name: "Notification Service Extension",
            bundleIdentifier: "it.twsweb.Nextcloud.Notification-Service-Extension",
            type: .notificationService,
            relativePath: "PlugIns/Notification Service Extension.appex"
        ),
        AppExtension(
            name: "Widget",
            bundleIdentifier: "it.twsweb.Nextcloud.Widget",
            type: .widget,
            relativePath: "PlugIns/Widget.appex"
        ),
        AppExtension(
            name: "WidgetDashboardIntentHandler",
            bundleIdentifier: "it.twsweb.Nextcloud.WidgetDashboardIntentHandler",
            type: .intents,
            relativePath: "PlugIns/WidgetDashboardIntentHandler.appex"
        ),
        AppExtension(
            name: "Action Assistant",
            bundleIdentifier: "it.twsweb.Nextcloud.Action-Assistant",
            type: .action,
            relativePath: "PlugIns/Action Assistant.appex"
        )
    ]
}

/// Extension types supported by ScaleCloudApp
public enum ExtensionType: String, Codable {
    case share = "com.apple.share-services"
    case fileProvider = "com.apple.fileprovider-nonreplicated"
    case fileProviderUI = "com.apple.fileprovider-ui"
    case notificationService = "com.apple.usernotifications.service"
    case widget = "com.apple.widgetkit-extension"
    case intents = "com.apple.intents-service"
    case action = "com.apple.services"
}

/// Stores provisioning profile data for an extension
public struct ExtensionProvisioningProfile: Codable {
    /// The extension bundle identifier this profile is for
    public let bundleIdentifier: String
    
    /// The raw provisioning profile data
    public let profileData: Data
    
    /// The expiration date of the profile
    public let expirationDate: Date
    
    /// The team identifier
    public let teamIdentifier: String
    
    /// Creates an extension provisioning profile
    public init(bundleIdentifier: String, profileData: Data, expirationDate: Date, teamIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        self.profileData = profileData
        self.expirationDate = expirationDate
        self.teamIdentifier = teamIdentifier
    }
    
    /// Check if the profile is expired
    public var isExpired: Bool {
        return expirationDate < Date()
    }
}
