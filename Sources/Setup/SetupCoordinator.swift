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
        case complete
    }
    
    // MARK: - Initialization
    
    public init() {
        // Always start with the credential VC — it will be replaced if/when the debug
        // channel handshake succeeds, but UIKit needs a real root view controller
        // immediately so the main run loop keeps pumping.
        let credentialVC = CredentialInputViewController()
        navigationController = UINavigationController(rootViewController: credentialVC)
        credentialVC.coordinator = self
        
        navigationController.isModalInPresentation = true // Disable swipe-to-dismiss
        navigationController.navigationBar.prefersLargeTitles = true
    }
    
    // MARK: - Public Interface
    
    /// Present setup flow modally.
    /// If a debugger is attached (i.e. launched via idevicedebug), the credential handshake
    /// runs on a background thread so the main run loop is never blocked by readLine().
    public func start(from presentingViewController: UIViewController) {
        presentingViewController.present(navigationController, animated: true)
        
        guard DebuggerUtils.isDebuggerAttached() else {
            print("[Setup] No debugger attached, using manual credential entry")
            return
        }
        
        // Debugger is attached — perform the stdin/stdout handshake on a background thread.
        // readLine() is a blocking syscall; calling it on the main thread would freeze UIKit
        // and could deadlock the debug bridge's own run-loop pumping.
        print("[Setup] Debugger detected, starting debug channel handoff on background thread")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let success = self.performDebugChannelHandoff()
            
            DispatchQueue.main.async {
                if success {
                    print("[Setup] Debug channel handoff successful, transitioning to validation")
                    self.currentStep = .validation
                    let validationVC = ValidationViewController()
                    validationVC.coordinator = self
                    // Replace the credential VC with validation — no back button possible
                    self.navigationController.setViewControllers([validationVC], animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        validationVC.startValidation()
                    }
                } else {
                    print("[Setup] Debug channel handoff failed, staying on manual credential entry")
                    // credentialVC is already the root — nothing to do
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
        // Developer mode must already be on to sideload the app at all.
        // Certificate trust must be done before the app can run.
        // Anisette URL is already injected via the debug channel.
        // Nothing left to show — go straight to done.
        setupCompleted()
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
    
    // MARK: - Debug Channel Handoff
    
    /// Perform credential handoff via debug channel (stdin/stdout)
    /// Returns true if credentials successfully received and stored
    private func performDebugChannelHandoff() -> Bool {
        do {
            print("[DebugChannel] Starting credential handoff")
            
            // Step 1: Generate Secure Enclave key pair
            let (publicKeyBytes, privateKey) = try SecureEnclaveManager.generateKeyPair()
            
            // Step 2: Send public key to computer via stdout
            // Protocol: bare base64 line immediately followed by sentinel — no prefix on the key line.
            // iloader captures the last non-empty line before SCALECLOUD_PUBKEY_READY as the key.
            let publicKeyBase64 = publicKeyBytes.base64EncodedString()
            print(publicKeyBase64)
            print("SCALECLOUD_PUBKEY_READY")
            fflush(stdout)
            
            print("[DebugChannel] Sent public key, waiting for encrypted payload...")
            
            // Step 3: Read credential payload from stdin.
            // iloader sends 5 plain lines (no key: prefixes):
            //   Line 1: base64-encoded encrypted password
            //   Line 2: plaintext email
            //   Line 3: anisette server URL
            //   Line 4: tailscale hostname
            //   Line 5: SCALECLOUD_PAYLOAD_COMPLETE
            var encryptedPasswordBase64: String?
            var appleID: String?
            var anisetteURL: String?
            var tailscaleHost: String?
            var lineIndex = 0
            
            while let line = readLine() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmed == "SCALECLOUD_PAYLOAD_COMPLETE" {
                    print("[DebugChannel] Payload transmission complete")
                    break
                }
                
                switch lineIndex {
                case 0:
                    encryptedPasswordBase64 = trimmed
                    print("[DebugChannel] Received encrypted password (\(trimmed.count) chars)")
                case 1:
                    appleID = trimmed
                    print("[DebugChannel] Received Apple ID: \(trimmed)")
                case 2:
                    anisetteURL = trimmed
                    print("[DebugChannel] Received Anisette URL: \(trimmed)")
                case 3:
                    tailscaleHost = trimmed
                    print("[DebugChannel] Received Tailscale host: \(trimmed)")
                default:
                    break
                }
                lineIndex += 1
            }
            
            // Step 4: Validate received data
            guard let encryptedPasswordBase64 = encryptedPasswordBase64,
                  let appleID = appleID,
                  !appleID.isEmpty,
                  let encryptedPasswordData = Data(base64Encoded: encryptedPasswordBase64) else {
                print("[DebugChannel] ERROR: Missing or invalid payload data")
                return false
            }
            
            // Step 5: Decrypt password using Secure Enclave.
            // iloader encrypts with: X9.63 KDF (SHA-256) → AES-128-GCM, 16-byte IV, no AAD,
            // wire format: ephemeral_pubkey(65) || ciphertext || tag(16).
            // This matches exactly what Apple's eciesEncryptionStandardVariableIVX963SHA256AESGCM
            // expects — the "VariableIV" name indicates the non-standard 16-byte IV derived from
            // the KDF rather than a 12-byte counter IV. SecureEnclaveManager uses that algorithm.
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
            
            // Step 7b: Tailscale hostname is the machine where iloader lives and where
            // the ScaleCloud.ipa is served. Store it as the IPA source URL so that
            // InstalledApp bootstrap and BackgroundRefreshAppsOperation can re-download
            // the IPA if the local cached copy is ever deleted.
            // iloader serves the IPA at http://<host>/ScaleCloud.ipa by convention.
            if let tailscaleHost = tailscaleHost, !tailscaleHost.isEmpty {
                let ipaURL = "http://\(tailscaleHost)/ScaleCloud.ipa"
                UserDefaults.standard.ipaSourceURL = ipaURL
                print("[DebugChannel] Stored IPA source URL: \(ipaURL)")
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
