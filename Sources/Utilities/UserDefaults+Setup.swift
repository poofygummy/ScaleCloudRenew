//
//  UserDefaults+Setup.swift
//  ScaleCloudRenew
//
//  Initial setup completion tracking
//

import Foundation

public extension UserDefaults {
    
    /// Flag indicating Apple ID signing credentials have been injected via the debug channel.
    /// Stored as a plain bool in UserDefaults. Reset automatically by
    /// presentSetupFlowIfNeeded whenever signing credentials are absent from Keychain,
    /// so a fresh iloader run always triggers the injection flow again.
    @objc dynamic public var signCredentialsInjected: Bool {
        get {
            return bool(forKey: "com.scalecloud.credentialsInjected")
        }
        set {
            set(newValue, forKey: "com.scalecloud.credentialsInjected")
        }
    }
    
    /// Timestamp when setup was last completed
    /// Used for diagnostics only
    @objc dynamic public var lastSetupDate: Date? {
        get {
            return object(forKey: "com.scalecloud.lastSetupDate") as? Date
        }
        set {
            set(newValue, forKey: "com.scalecloud.lastSetupDate")
        }
    }
    
    /// The IPA download URL received from iloader via the debug channel.
    /// Derived from the Tailscale host: http://<tailscale-host>/ScaleCloud.ipa
    ///
    /// This is a persistent staging value. On every launch, DatabaseManager.prepareDatabase()
    /// reads it and writes it into the StoreApp's AppVersion.downloadURL in CoreData — which is
    /// the authoritative location the signing engine reads when it needs to re-fetch the IPA.
    @objc dynamic public var ipaSourceURL: String? {
        get {
            return string(forKey: "com.scalecloud.ipaSourceURL")
        }
        set {
            set(newValue, forKey: "com.scalecloud.ipaSourceURL")
        }
    }

    #if DEBUG
    /// Debug-only method to reset setup state and credentials
    /// Useful for testing setup flow without reinstalling app
    func resetSetup() {
        removeObject(forKey: "com.scalecloud.credentialsInjected") // signCredentialsInjected
        removeObject(forKey: "com.scalecloud.lastSetupDate")
        removeObject(forKey: "menuAnisetteServersList")
        removeObject(forKey: "menuAnisetteURL")
        removeObject(forKey: "com.scalecloud.ipaSourceURL")
        
        // Clear credentials from Keychain
        ScaleCloudRenew.Keychain.shared.reset()
        
        print("[Setup] Reset setup state and sign credentials")
    }
    #endif
}
