//
//  Keychain.swift
//  ScaleCloudRenew
//
//  Adapted from SideStore AltStoreCore/Components/Keychain.swift
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import KeychainAccess

/// Property wrapper for Keychain items supporting Data and String types
@propertyWrapper
public struct KeychainItem<Value>
{
    public let key: String
    
    public var wrappedValue: Value? {
        get {
            switch Value.self
            {
            case is Data.Type: return try? Keychain.shared.keychain.getData(self.key) as? Value
            case is String.Type: return try? Keychain.shared.keychain.getString(self.key) as? Value
            default: return nil
            }
        }
        set {
            switch Value.self
            {
            case is Data.Type: Keychain.shared.keychain[data: self.key] = newValue as? Data
            case is String.Type: Keychain.shared.keychain[self.key] = newValue as? String
            default: break
            }
        }
    }
    
    public init(key: String)
    {
        self.key = key
    }
}

/// Secure storage for authentication credentials and signing materials
///
/// **Security Model**:
/// - Service identifier: `com.scalecloud` (shared across all targets)
/// - Accessibility: `.afterFirstUnlock` (allows background task access after device unlock)
/// - Synchronizable: `true` (syncs via iCloud Keychain)
///
/// **WARNING**: Never log password, token, or private key values. Handle with care.
public class Keychain
{
    public static let shared = Keychain()
    
    // Service identifier changed from Bundle.Info.appbundleIdentifier to com.scalecloud
    fileprivate let keychain = KeychainAccess.Keychain(service: "com.scalecloud")
        .accessibility(.afterFirstUnlock)
        .synchronizable(true)
    
    // MARK: - Apple ID Credentials
    
    @KeychainItem(key: "appleIDEmailAddress")
    public var appleIDEmailAddress: String?
    
    @KeychainItem(key: "appleIDPassword")
    public var appleIDPassword: String?
    
    @KeychainItem(key: "appleIDAdsid")
    public var appleIDAdsid: String?
    
    @KeychainItem(key: "appleIDXcodeToken")
    public var appleIDXcodeToken: String?
    
    // MARK: - Signing Certificate & Keys
    
    @KeychainItem(key: "signingCertificatePrivateKey")
    public var signingCertificatePrivateKey: Data?
    
    @KeychainItem(key: "signingCertificateSerialNumber")
    public var signingCertificateSerialNumber: String?
    
    /// DER-encoded X.509 certificate data
    @KeychainItem(key: "signingCertificate")
    public var signingCertificate: Data?
    
    @KeychainItem(key: "signingCertificatePassword")
    public var signingCertificatePassword: String?
    
    // MARK: - Anisette Provisioning
    
    @KeychainItem(key: "identifier")
    public var identifier: String?
    
    @KeychainItem(key: "adiPb")
    public var adiPb: String?
    
    // MARK: - Extension Provisioning Profiles
    
    /// Store provisioning profile data for an extension
    /// - Parameters:
    ///   - profileData: Raw .mobileprovision data
    ///   - bundleIdentifier: Extension bundle identifier
    public func setExtensionProvisioningProfile(_ profileData: Data, forBundleID bundleIdentifier: String) {
        let key = "provisioningProfile.\(bundleIdentifier)"
        keychain[data: key] = profileData
    }
    
    /// Retrieve provisioning profile data for an extension
    /// - Parameter bundleIdentifier: Extension bundle identifier
    /// - Returns: Raw .mobileprovision data, or nil if not found
    public func extensionProvisioningProfile(forBundleID bundleIdentifier: String) -> Data? {
        let key = "provisioningProfile.\(bundleIdentifier)"
        return try? keychain.getData(key)
    }
    
    /// Remove provisioning profile for an extension
    /// - Parameter bundleIdentifier: Extension bundle identifier
    public func removeExtensionProvisioningProfile(forBundleID bundleIdentifier: String) {
        let key = "provisioningProfile.\(bundleIdentifier)"
        try? keychain.remove(key)
    }
    
    /// Remove all extension provisioning profiles
    public func removeAllExtensionProvisioningProfiles() {
        // Get all keys from keychain
        let allKeys = keychain.allKeys()
        for key in allKeys where key.hasPrefix("provisioningProfile.") {
            try? keychain.remove(key)
        }
    }
    
    // MARK: - In-Memory Session Cache
    
    /// Cached certificate object (not persisted to Keychain)
    /// Cleared on logout via reset()
    public var certificate: ALTCertificate? = nil
    
    /// Cached Apple API session (not persisted to Keychain)
    /// Cleared on logout via reset()
    public var session: ALTAppleAPISession? = nil
    
    /// Cached developer team (not persisted to Keychain)
    /// Cleared on logout via reset()
    public var team: ALTTeam? = nil
    
    private init()
    {
    }
    
    // MARK: - Credential Validation
    
    /// Check if valid Apple ID credentials are present
    /// - Returns: `true` if email and password are both non-nil and non-empty
    public func hasValidCredentials() -> Bool
    {
        guard let email = appleIDEmailAddress, !email.isEmpty,
              let password = appleIDPassword, !password.isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Certificate Expiry Management
    
    /// Parse certificate expiry from DER data and update UserDefaults
    /// - Parameter certificateData: DER-encoded X.509 certificate
    /// - Throws: Certificate parsing errors
    public func updateCertificateExpiry(from certificateData: Data) throws
    {
        let certificate = try ALTCertificate(p12Data: certificateData, password: signingCertificatePassword ?? "")
        
        // Store expiry date in UserDefaults for BGTask scheduling (Phase 4 integration)
        UserDefaults.standard.set(certificate.expirationDate, forKey: "com.scalecloud.cert.expiry")
    }
    
    // MARK: - Logout
    
    /// Clear all credentials and cached session objects
    /// Call this on user logout or when switching accounts
    public func reset()
    {
        // Clear Apple ID credentials
        self.appleIDEmailAddress = nil
        self.appleIDPassword = nil
        self.appleIDAdsid = nil
        self.appleIDXcodeToken = nil
        
        // Clear signing materials
        self.signingCertificatePrivateKey = nil
        self.signingCertificateSerialNumber = nil
        self.signingCertificate = nil
        self.signingCertificatePassword = nil
        
        // Clear Anisette data
        self.identifier = nil
        self.adiPb = nil
        
        // Clear in-memory session cache
        self.certificate = nil
        self.session = nil
        self.team = nil
        
        // Clear UserDefaults expiry
        UserDefaults.standard.removeObject(forKey: "com.scalecloud.cert.expiry")
        
        // Clear all extension provisioning profiles
        self.removeAllExtensionProvisioningProfiles()
    }
}
