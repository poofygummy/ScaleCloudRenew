//
//  BackgroundRefreshAppsOperation.swift
//  AltStore
//
//  Created by Riley Testut on 7/6/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import CoreData
import os.log
import ScaleCloudSign


typealias RefreshError = RefreshErrorCode.Error
enum RefreshErrorCode: Int, ALTErrorEnum, CaseIterable
{
    case noInstalledApps
    
    var errorFailureReason: String {
        switch self
        {
        case .noInstalledApps: return NSLocalizedString("No active apps require refreshing.", comment: "")
        }
    }
}

private extension CFNotificationName
{
    static let requestAppState = CFNotificationName("com.altstore.RequestAppState" as CFString)
    static let appIsRunning = CFNotificationName("com.altstore.AppState.Running" as CFString)
    
    static func requestAppState(for appID: String) -> CFNotificationName
    {
        let name = String(CFNotificationName.requestAppState.rawValue) + "." + appID
        return CFNotificationName(name as CFString)
    }
    
    static func appIsRunning(for appID: String) -> CFNotificationName
    {
        let name = String(CFNotificationName.appIsRunning.rawValue) + "." + appID
        return CFNotificationName(name as CFString)
    }
}

private let ReceivedApplicationState: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    guard let name = name, let observer = observer else { return }
    
    let operation = unsafeBitCast(observer, to: BackgroundRefreshAppsOperation.self)
    operation.receivedApplicationState(notification: name)
}

@objc(BackgroundRefreshAppsOperation)
final class BackgroundRefreshAppsOperation: ResultOperation<[String: Result<InstalledApp, Error>]>
{
    let installedApps: [InstalledApp]
    private let managedObjectContext: NSManagedObjectContext
    
    var presentsFinishedNotification: Bool = true
    var ignoresServerNotFoundError: Bool = true
    
    private let refreshIdentifier: String = UUID().uuidString
    private var runningApplications: Set<String> = []
    private let log = OSLog(subsystem: "com.scalecloud.sign", category: "refresh")
    
    // Completion handler to report signing results back to caller (BGTask handler)
    var refreshCompletionHandler: ((Bool, Date?) -> Void)?
    
    init(installedApps: [InstalledApp])
    {
        self.installedApps = installedApps
        self.managedObjectContext = installedApps.compactMap({ $0.managedObjectContext }).first ?? DatabaseManager.shared.persistentContainer.newBackgroundContext()
        
        super.init()
    }
    
    override func finish(_ result: Result<[String: Result<InstalledApp, Error>], Error>)
    {
        // Report result to caller (BGTask handler)
        switch result {
        case .success(let results):
            // Check if any apps failed
            let failed = results.values.contains { result in
                if case .failure = result { return true }
                return false
            }
            
            if !failed {
                // Extract certificate expiry from Keychain
                var expiryDate: Date?
                if let certData = Keychain.shared.signingCertificate {
                    do {
                        try Keychain.shared.updateCertificateExpiry(from: certData)
                        expiryDate = UserDefaults.standard.object(forKey: "com.scalecloud.cert.expiry") as? Date
                        os_log("Certificate expires: %{public}@", log: log, type: .info, expiryDate?.description ?? "unknown")
                    } catch {
                        os_log("Failed to parse certificate expiry: %{public}@", log: log, type: .error, error.localizedDescription)
                    }
                }
                os_log("Refresh completed successfully", log: log, type: .info)
                refreshCompletionHandler?(true, expiryDate)
            } else {
                os_log("Refresh completed with failures", log: log, type: .error)
                refreshCompletionHandler?(false, nil)
            }
            
        case .failure(let error):
            os_log("Refresh failed: %{public}@", log: log, type: .error, error.localizedDescription)
            refreshCompletionHandler?(false, nil)
        }
        
        super.finish(result)
        
        self.managedObjectContext.perform {
            self.stopListeningForRunningApps()
        }
    }
    
    override func main()
    {
        super.main()
        
        guard !self.installedApps.isEmpty else {
            self.finish(.failure(RefreshError(.noInstalledApps)))
            return
        }

        os_log("BackgroundRefreshAppsOperation starting with silent audio protection", log: log, type: .info)
        
        // Wrap entire signing operation in silent audio playback (SideStore defensive mechanism)
        // This extends execution time and prevents iOS from suspending during signing
        BackgroundTaskManager.shared.performExtendedBackgroundTask { (taskResult, taskCompletionHandler) in
            
            if let error = taskResult.error
            {
                os_log("Error starting silent audio protection: %{public}@", log: self.log, type: .error, error.localizedDescription)
                self.finish(.failure(error))
                taskCompletionHandler()
                return
            }
            
            self.managedObjectContext.perform {
                Logger.sideload.notice("Refreshing apps in background: \(self.installedApps.map(\.bundleIdentifier), privacy: .public)")
                
                self.startListeningForRunningApps()
                
                // Wait for 2 seconds (1 now, 1 later in FindServerOperation) to:
                // a) give us time to discover AltServers
                // b) give other processes a chance to respond to requestAppState notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.managedObjectContext.perform {
                        
                        let filteredApps = self.installedApps.filter { !self.runningApplications.contains($0.bundleIdentifier) }
                        if !self.runningApplications.isEmpty
                        {
                            Logger.sideload.notice("Skipping refreshing running apps: \(self.runningApplications, privacy: .public)")
                        }
                        
                        let group = AppManager.shared.refresh(filteredApps, presentingViewController: nil)
                        // Installation handler removed - notifications handled by ScaleCloudApp
                        group.completionHandler = { (results) in
                            // Stop silent audio after signing completes
                            taskCompletionHandler()
                            self.finish(.success(results))
                        }
                        
                        self.progress.addChild(group.progress, withPendingUnitCount: 1)
                    }
                }
            }
        }
    }
}

private extension BackgroundRefreshAppsOperation
{
    func startListeningForRunningApps()
    {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        for installedApp in self.installedApps
        {
            let appIsRunningNotification = CFNotificationName.appIsRunning(for: installedApp.bundleIdentifier)
            CFNotificationCenterAddObserver(notificationCenter, observer, ReceivedApplicationState, appIsRunningNotification.rawValue, nil, .deliverImmediately)
            
            let requestAppStateNotification = CFNotificationName.requestAppState(for: installedApp.bundleIdentifier)
            CFNotificationCenterPostNotification(notificationCenter, requestAppStateNotification, nil, nil, true)
        }
    }
    
    func stopListeningForRunningApps()
    {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        for installedApp in self.installedApps
        {
            let appIsRunningNotification = CFNotificationName.appIsRunning(for: installedApp.bundleIdentifier)
            CFNotificationCenterRemoveObserver(notificationCenter, observer, appIsRunningNotification, nil)
        }
    }
    
    func receivedApplicationState(notification: CFNotificationName)
    {
        let baseName = String(CFNotificationName.appIsRunning.rawValue)
        
        let appID = String(notification.rawValue).replacingOccurrences(of: baseName + ".", with: "")
        self.runningApplications.insert(appID)
    }
    
    // Notification scheduling removed - handled by ScaleCloudApp
}
