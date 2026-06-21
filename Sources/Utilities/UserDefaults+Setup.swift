//
//  UserDefaults+Setup.swift
//  ScaleCloudRenew
//
//  Initial setup completion tracking
//

import Foundation

extension UserDefaults {
    
    /// Flag indicating setup flow has been completed
    /// Once true, app will not present setup flow on launch
    @objc dynamic var setupCompleted: Bool {
        get {
            return bool(forKey: "com.scalecloud.setupCompleted")
        }
        set {
            set(newValue, forKey: "com.scalecloud.setupCompleted")
        }
    }
    
    /// Timestamp when setup was last completed
    /// Used for diagnostics only
    @objc dynamic var lastSetupDate: Date? {
        get {
            return object(forKey: "com.scalecloud.lastSetupDate") as? Date
        }
        set {
            set(newValue, forKey: "com.scalecloud.lastSetupDate")
        }
    }
    
    /// The URL where the ScaleCloud IPA can be downloaded for re-signing.
    /// Set during debug channel handoff from the Tailscale host address sent by iloader.
    /// Used by InstalledApp bootstrap so BackgroundRefreshAppsOperation can re-fetch
    /// the IPA if the local cached copy is missing.
    @objc dynamic var ipaSourceURL: String? {
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
        removeObject(forKey: "com.scalecloud.setupCompleted")
        removeObject(forKey: "com.scalecloud.lastSetupDate")
        removeObject(forKey: "menuAnisetteServersList")
        removeObject(forKey: "menuAnisetteURL")
        removeObject(forKey: "com.scalecloud.ipaSourceURL")
        
        // Clear credentials from Keychain
        ScaleCloudRenew.Keychain.shared.reset()
        
        print("[Setup] Reset setup state and credentials")
    }
    #endif
}
