//
//  UserDefaults+Anisette.swift
//  ScaleCloudRenew
//
//  Anisette server URL configuration via UserDefaults
//

import Foundation

extension UserDefaults {
    
    /// Anisette server URL list
    /// **MANUAL CONFIGURATION REQUIRED**: User must add toth-adattar Tailscale address to this list
    /// Example: ["http://100.x.y.z:6969"] where IP is from `tailscale status | grep toth-adattar`
    @objc dynamic var menuAnisetteServersList: [String] {
        get {
            return array(forKey: "menuAnisetteServersList") as? [String] ?? []
        }
        set {
            set(newValue, forKey: "menuAnisetteServersList")
        }
    }
    
    /// Currently selected Anisette server URL
    /// Set automatically by FetchAnisetteDataOperation after testing server connectivity
    @objc dynamic var menuAnisetteURL: String {
        get {
            return string(forKey: "menuAnisetteURL") ?? ""
        }
        set {
            set(newValue, forKey: "menuAnisetteURL")
        }
    }
}
