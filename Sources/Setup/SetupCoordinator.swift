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
    private weak var presentingViewController: UIViewController?
    
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
        // Start with the credential VC as the nav root. When a debugger is attached
        // we never present this immediately — the modal is only shown if the debug
        // channel handoff fails (fallback) or when there is no debugger attached.
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
        self.presentingViewController = presentingViewController
        
        // Two-phase launch-args injection protocol.
        // idevicedebug on iOS 15 does not relay stdin to the app, so we use launch
        // arguments instead:
        //
        // Phase 1 — no payload args present (first idevicedebug launch):
        //   • Generate + persist a Secure Enclave keypair.
        //   • Print public key + SCALECLOUD_PUBKEY_READY to stdout.
        //   • Block this thread so the process stays alive while iloader reads stdout.
        //   • iloader kills the process, encrypts the password, re-launches with args.
        //
        // Phase 2 — payload args present (second idevicedebug launch):
        //   • Decrypt with the persisted private key.
        //   • Store credentials, print SCALECLOUD_CREDENTIALS_OK.
        //   • Proceed to validation UI.
        //
        // DVT warmup (certtrust probe, no debugger / no args):
        //   • isDebuggerAttached() == false, no payload args → wait 20 s then show
        //     manual UI. The DVT process is killed in ~10 s so UI never appears.

        let args = CommandLine.arguments
        let hasPayload = args.contains(where: { $0.hasPrefix("--scalecloud-payload=") })

        if hasPayload {
            // Phase 2 — payload delivered via launch args
            print("[Setup] Phase 2: payload args detected, running credential delivery on background thread")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let success = self.performDebugChannelHandoff()
                DispatchQueue.main.async {
                    if success {
                        print("[Setup] Phase 2 handoff successful, transitioning to validation")
                        self.currentStep = .validation
                        let validationVC = ValidationViewController()
                        validationVC.coordinator = self
                        self.navigationController.setViewControllers([validationVC], animated: false)
                        self.presentingViewController?.present(self.navigationController, animated: true) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                validationVC.startValidation()
                            }
                        }
                    } else {
                        print("[Setup] Phase 2 handoff failed, showing manual credential entry")
                        self.presentingViewController?.present(self.navigationController, animated: true)
                    }
                }
            }
            return
        }

        guard DebuggerUtils.isDebuggerAttached() else {
            // No debugger, no payload args — either a real user launch or a DVT warmup.
            // Wait 20 s: DVT kills the process in ~10 s so UI never appears during
            // injection; a genuine user launch just sees a brief delay.
            print("[Setup] No debugger, no payload — waiting 20 s before showing manual credential UI")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                Thread.sleep(forTimeInterval: 20)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    print("[Setup] 20 s elapsed, showing manual credential entry")
                    presentingViewController.present(self.navigationController, animated: true)
                }
            }
            return
        }

        // Phase 1 — debugger attached, no payload args yet.
        // Generate + persist keypair, advertise pubkey, then block until killed.
        print("[Setup] Phase 1: debugger attached, advertising public key")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.performPhase1KeyAdvertisement()
            // iloader kills us after reading the pubkey — we never reach here.
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

    /// Phase 1: generate + persist keypair, print pubkey, block until iloader kills us.
    /// Never returns under normal operation.
    private func performPhase1KeyAdvertisement() {
        do {
            print("[DebugChannel] Phase 1: generating persistent Secure Enclave keypair")
            let (publicKeyBytes, _) = try SecureEnclaveManager.loadOrGenerateKeyPair()
            let publicKeyBase64 = publicKeyBytes.base64EncodedString()
            print(publicKeyBase64)
            print("SCALECLOUD_PUBKEY_READY")
            fflush(stdout)
            print("[DebugChannel] Phase 1: pubkey advertised, blocking until iloader kills this process")
            // Block indefinitely — iloader will kill this process after reading the pubkey
            // and then re-launch with the encrypted payload as launch args.
            Thread.sleep(forTimeInterval: 300)
        } catch {
            print("[DebugChannel] Phase 1 ERROR: \(error.localizedDescription)")
        }
    }

    /// Phase 2: read payload from launch args, decrypt password, store credentials.
    /// Returns true on success.
    private func performDebugChannelHandoff() -> Bool {
        do {
            print("[DebugChannel] Phase 2: reading payload from launch args")

            let args = CommandLine.arguments
            func argValue(_ prefix: String) -> String? {
                args.first(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) }
            }

            guard let encryptedPasswordBase64 = argValue("--scalecloud-payload="),
                  let appleID = argValue("--scalecloud-email="),
                  !appleID.isEmpty,
                  let encryptedPasswordData = Data(base64Encoded: encryptedPasswordBase64) else {
                print("[DebugChannel] ERROR: Missing or invalid payload args")
                return false
            }
            let anisetteURL  = argValue("--scalecloud-anisette=")
            let tailscaleHost = argValue("--scalecloud-tailscale=")

            print("[DebugChannel] Received encrypted password (\(encryptedPasswordBase64.count) chars)")
            print("[DebugChannel] Received Apple ID: \(appleID)")

            // Load the private key that was persisted in Phase 1
            let (_, privateKey) = try SecureEnclaveManager.loadOrGenerateKeyPair()

            // Decrypt password
            let passwordData = try SecureEnclaveManager.decrypt(encryptedData: encryptedPasswordData, using: privateKey)
            guard let password = String(data: passwordData, encoding: .utf8), !password.isEmpty else {
                print("[DebugChannel] ERROR: Decrypted password is invalid")
                return false
            }
            print("[DebugChannel] Successfully decrypted password")

            // Store credentials
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password
            print("[DebugChannel] Stored credentials in Keychain")

            // Mark setup as complete immediately so that any subsequent
            // sceneWillEnterForeground / activateSceneForAccount call does NOT
            // re-present the credential modal while Phase 2 validation is running.
            UserDefaults.standard.setupCompleted = true
            UserDefaults.standard.lastSetupDate = Date()

            // Store Anisette URL
            if let anisetteURL = anisetteURL, !anisetteURL.isEmpty {
                var servers = UserDefaults.standard.menuAnisetteServersList
                if !servers.contains(anisetteURL) {
                    servers.append(anisetteURL)
                    UserDefaults.standard.menuAnisetteServersList = servers
                }
                UserDefaults.standard.menuAnisetteURL = anisetteURL
                print("[DebugChannel] Stored Anisette URL: \(anisetteURL)")
            }

            // Store IPA source URL
            if let tailscaleHost = tailscaleHost, !tailscaleHost.isEmpty {
                let ipaURL = "http://\(tailscaleHost)/ScaleCloud.ipa"
                UserDefaults.standard.ipaSourceURL = ipaURL
                print("[DebugChannel] Stored IPA source URL: \(ipaURL)")
            }

            // Confirm to iloader
            print("SCALECLOUD_CREDENTIALS_OK")
            fflush(stdout)

            // Clean up the ephemeral keypair — it served its purpose
            SecureEnclaveManager.deleteStoredKeyPair()

            print("[DebugChannel] Phase 2 complete")
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
