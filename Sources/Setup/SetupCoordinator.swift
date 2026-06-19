//
//  SetupCoordinator.swift
//  ScaleCloudRenew
//
//  Orchestrates the initial setup flow for ScaleCloud signing
//

import UIKit

/// Notification posted when setup flow completes successfully
public extension Notification.Name {
    static let setupFlowCompleted = Notification.Name("com.scalecloud.setupFlowCompleted")
}

/// Manages the multi-step setup flow for initial configuration
public class SetupCoordinator {
    
    // MARK: - Properties
    
    private let navigationController: UINavigationController
    private var currentStep: SetupStep = .credentials
    
    /// Completion handler called when setup finishes
    public var onCompletion: (() -> Void)?
    
    // MARK: - Setup Steps
    
    private enum SetupStep {
        case credentials
        case validation
        case developerMode
        case certificateTrust
        case anisette
        case complete
    }
    
    // MARK: - Initialization
    
    public init() {
        // Initialize navigationController first so all stored properties are set before self is used
        let credentialVC = CredentialInputViewController()
        navigationController = UINavigationController(rootViewController: credentialVC)
        
        // Now self is fully initialized, safe to use
        if DebuggerUtils.isDebuggerAttached() {
            print("[Setup] Debugger detected, attempting debug channel credential handoff")
            if performDebugChannelHandoff() {
                // Credentials successfully received via debug channel
                print("[Setup] Debug channel handoff successful, starting with validation")
                let validationVC = ValidationViewController()
                validationVC.coordinator = self
                navigationController.setViewControllers([validationVC], animated: false)
                currentStep = .validation
            } else {
                // Fallback to manual entry
                print("[Setup] Debug channel handoff failed, falling back to manual entry")
                credentialVC.coordinator = self
            }
        } else {
            // No debugger - use manual credential entry
            print("[Setup] No debugger attached, using manual credential entry")
            credentialVC.coordinator = self
        }
        
        navigationController.isModalInPresentation = true // Disable swipe-to-dismiss
        navigationController.navigationBar.prefersLargeTitles = true
    }
    
    // MARK: - Public Interface
    
    /// Present setup flow modally
    public func start(from presentingViewController: UIViewController) {
        presentingViewController.present(navigationController, animated: true)
        
        // If we started with validation (credentials from debug channel), auto-trigger it
        if currentStep == .validation {
            if let validationVC = navigationController.topViewController as? ValidationViewController {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    validationVC.startValidation()
                }
            }
        }
    }
    
    // MARK: - Flow Navigation
    
    func credentialsEntered(email: String, password: String) {
        // Store credentials immediately
        Keychain.shared.appleIDEmailAddress = email
        Keychain.shared.appleIDPassword = password
        
        // Move to validation step
        currentStep = .validation
        let validationVC = ValidationViewController()
        validationVC.coordinator = self
        navigationController.pushViewController(validationVC, animated: true)
        
        // Trigger signing validation
        validationVC.startValidation()
    }
    
    func validationSucceeded() {
        currentStep = .developerMode
        
        // Check iOS version - Developer Mode only exists on iOS 16+
        if #available(iOS 16.0, *) {
            // Check if already enabled
            if isDeveloperModeEnabled() {
                print("[Setup] Developer Mode already enabled, skipping screen")
                developerModeConfirmed()
            } else {
                let developerModeVC = DeveloperModeViewController()
                developerModeVC.coordinator = self
                navigationController.pushViewController(developerModeVC, animated: true)
            }
        } else {
            // iOS 15 or earlier - skip Developer Mode screen
            print("[Setup] iOS < 16, skipping Developer Mode screen")
            developerModeConfirmed()
        }
    }
    
    func validationFailed(error: Error) {
        // Show error alert and return to credentials
        let alert = UIAlertController(
            title: "Validation Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController.popViewController(animated: true)
        })
        navigationController.topViewController?.present(alert, animated: true)
    }
    
    func developerModeConfirmed() {
        currentStep = .certificateTrust
        let trustVC = TrustCertificateViewController()
        trustVC.coordinator = self
        navigationController.pushViewController(trustVC, animated: true)
    }
    
    func certificateTrustConfirmed() {
        currentStep = .anisette
        let anisetteVC = AnisetteConfigViewController()
        anisetteVC.coordinator = self
        navigationController.pushViewController(anisetteVC, animated: true)
    }
    
    func anisetteConfigured(serverURL: String?) {
        // Store Anisette server if provided
        if let serverURL = serverURL, !serverURL.isEmpty {
            var servers = UserDefaults.standard.menuAnisetteServersList
            if !servers.contains(serverURL) {
                servers.append(serverURL)
                UserDefaults.standard.menuAnisetteServersList = servers
            }
            UserDefaults.standard.menuAnisetteURL = serverURL
        }
        
        currentStep = .complete
        let completeVC = SetupCompleteViewController()
        completeVC.coordinator = self
        navigationController.pushViewController(completeVC, animated: true)
    }
    
    func setupCompleted() {
        // Mark setup as complete
        UserDefaults.standard.setupCompleted = true
        UserDefaults.standard.lastSetupDate = Date()
        
        // Post notification
        NotificationCenter.default.post(name: .setupFlowCompleted, object: nil)
        
        // Dismiss flow
        navigationController.dismiss(animated: true) {
            self.onCompletion?()
        }
    }
    
    // MARK: - Developer Mode Detection
    
    /// Check if Developer Mode is enabled (iOS 16+)
    /// Uses private API _CSIsInternalInstallCapable() which returns true when Developer Mode is on
    @available(iOS 16.0, *)
    private func isDeveloperModeEnabled() -> Bool {
        // Try to call private API via dlsym
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "_CSIsInternalInstallCapable") else {
            // If private API unavailable, assume not enabled
            return false
        }
        
        typealias CheckFunction = @convention(c) () -> Bool
        let checkFunc = unsafeBitCast(symbol, to: CheckFunction.self)
        return checkFunc()
    }
    
    // MARK: - Debug Channel Handoff
    
    /// Perform credential handoff via debug channel (stdin/stdout)
    /// Returns true if credentials successfully received and stored
    private func performDebugChannelHandoff() -> Bool {
        do {
            print("[DebugChannel] Starting credential handoff")
            
            // Step 1: Generate Secure Enclave key pair
            let (publicKeyBytes, privateKey) = try SecureEnclaveManager.generateKeyPair()
            
            // Step 2: Send public key to computer via stdout
            let publicKeyBase64 = publicKeyBytes.base64EncodedString()
            print("SCALECLOUD_PUBKEY:\(publicKeyBase64)")
            print("SCALECLOUD_PUBKEY_READY")
            fflush(stdout)
            
            print("[DebugChannel] Sent public key, waiting for encrypted payload...")
            
            // Step 3: Read encrypted payload from stdin
            var encryptedPasswordBase64: String?
            var appleID: String?
            var anisetteURL: String?
            
            while let line = readLine() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmed.hasPrefix("SCALECLOUD_PASSWORD:") {
                    encryptedPasswordBase64 = String(trimmed.dropFirst("SCALECLOUD_PASSWORD:".count))
                    print("[DebugChannel] Received encrypted password (\(encryptedPasswordBase64?.count ?? 0) chars)")
                } else if trimmed.hasPrefix("SCALECLOUD_APPLEID:") {
                    appleID = String(trimmed.dropFirst("SCALECLOUD_APPLEID:".count))
                    print("[DebugChannel] Received Apple ID: \(appleID ?? "(none)")")
                } else if trimmed.hasPrefix("SCALECLOUD_ANISETTE:") {
                    anisetteURL = String(trimmed.dropFirst("SCALECLOUD_ANISETTE:".count))
                    print("[DebugChannel] Received Anisette URL: \(anisetteURL ?? "(none)")")
                } else if trimmed == "SCALECLOUD_PAYLOAD_COMPLETE" {
                    print("[DebugChannel] Payload transmission complete")
                    break
                }
            }
            
            // Step 4: Validate received data
            guard let encryptedPasswordBase64 = encryptedPasswordBase64,
                  let appleID = appleID,
                  !appleID.isEmpty,
                  let encryptedPasswordData = Data(base64Encoded: encryptedPasswordBase64) else {
                print("[DebugChannel] ERROR: Missing or invalid payload data")
                return false
            }
            
            // Step 5: Decrypt password using Secure Enclave
            let passwordData = try SecureEnclaveManager.decrypt(encryptedData: encryptedPasswordData, using: privateKey)
            guard let password = String(data: passwordData, encoding: .utf8), !password.isEmpty else {
                print("[DebugChannel] ERROR: Decrypted password is invalid")
                return false
            }
            
            print("[DebugChannel] Successfully decrypted password")
            
            // Step 6: Store credentials in Keychain
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password
            print("[DebugChannel] Stored credentials in Keychain")
            
            // Step 7: Store Anisette URL if provided
            if let anisetteURL = anisetteURL, !anisetteURL.isEmpty {
                var servers = UserDefaults.standard.menuAnisetteServersList
                if !servers.contains(anisetteURL) {
                    servers.append(anisetteURL)
                    UserDefaults.standard.menuAnisetteServersList = servers
                }
                UserDefaults.standard.menuAnisetteURL = anisetteURL
                print("[DebugChannel] Stored Anisette URL: \(anisetteURL)")
            }
            
            // Step 8: Send success confirmation
            print("SCALECLOUD_CREDENTIALS_OK")
            fflush(stdout)
            
            print("[DebugChannel] Handoff complete")
            return true
            
        } catch {
            print("[DebugChannel] ERROR: \(error.localizedDescription)")
            return false
        }
    }
}

/// Base class for setup view controllers with step progress
class SetupViewController: UIViewController {
    weak var coordinator: SetupCoordinator?
    
    /// Current step number (1-indexed)
    var stepNumber: Int = 1
    
    /// Total number of steps
    var totalSteps: Int = 5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Disable back button until step is complete
        navigationItem.hidesBackButton = true
        
        // Add step indicator to navigation title
        navigationItem.prompt = "Step \(stepNumber) of \(totalSteps)"
    }
}
