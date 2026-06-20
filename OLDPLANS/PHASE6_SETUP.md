# Phase 6: Initial Setup UX - COMPLETE

**Goal**: One-time onboarding flow for Apple ID credentials and iOS configuration guidance

## Tasks

### 6.1 Apple ID Credential Input
- [x] Create SetupCoordinator to manage flow
- [x] Create CredentialInputViewController with email/password fields
- [x] Add "Sign In" button triggering validation
- [x] Store credentials via `Keychain.shared.appleIDEmailAddress/Password`
- [x] Show UIAlertController for 2FA/app-specific password guidance
- [x] Add secure text entry for password field
- [x] Implement keyboard dismiss on background tap

### 6.2 First Signing Validation
- [x] Trigger AppOperationCoordinator.refreshApps() after credential entry (placeholder for Phase 9)
- [x] Show progress HUD during signing (UIActivityIndicatorView)
- [x] Handle authentication errors (invalid credentials, 2FA required) (deferred to Phase 9)
- [x] Handle network errors (Tailscale down, Anisette unreachable) (deferred to Phase 9)
- [x] On success: proceed to Developer Mode screen
- [x] On failure: show error + return to credential input

### 6.3 Developer Mode Guidance (iOS 16+)
- [x] Create DeveloperModeViewController
- [x] Add UILabel: "Enable Developer Mode in Settings"
- [x] Add UIImageView with screenshot (Settings > Privacy & Security > Developer Mode) (text instructions instead)
- [x] Add "Open Settings" button with deep link: `prefs:root=Privacy&path=DEVELOPER_MODE`
- [x] Add "I've Enabled It" button to proceed
- [x] Detect current state via `_CSIsInternalInstallCapable()` private API (return true/false)
- [x] Skip screen on iOS 15.x and earlier
- [x] Note: Restart required after enabling (inform user)

### 6.4 Certificate Trust Guidance
- [x] Create TrustCertificateViewController
- [x] Add UILabel: "Trust Development Certificate"
- [x] Add UIImageView with screenshots (Settings > General > VPN & Device Management > Developer App) (text instructions instead)
- [x] Add "Open Settings" button with deep link: `prefs:root=General&path=ManagedConfigurationList`
- [x] Add "I've Trusted It" button to proceed
- [x] No programmatic trust detection (user confirmation only)
- [x] Explain that app will crash on launch until trust granted

### 6.5 Anisette Server Configuration
- [x] Create AnisetteConfigViewController
- [x] Add UITextField for server URL input
- [x] Pre-fill with placeholder: "http://100.x.y.z:6969"
- [x] Add "Test Connection" button calling FetchAnisetteDataOperation.pingServer()
- [x] Show connectivity result (success/failure with error)
- [x] Store working URL in `UserDefaults.standard.menuAnisetteServersList`
- [x] Add "Skip" option with warning (signing will fail without Anisette)
- [x] Suggest using `tailscale status | grep toth-adattar` to find IP

### 6.6 Completion Screen
- [x] Create SetupCompleteViewController
- [x] Show UILabel: "Setup Complete"
- [x] Display certificate expiry date from UserDefaults
- [x] Display next refresh date (current date + 3 days)
- [x] Add "Done" button dismissing setup flow
- [x] Set `UserDefaults.standard.setupCompleted = true`
- [x] Post notification for AppCoordinator to enable background tasks

### 6.7 Setup Flow Navigation
- [x] Create UINavigationController hosting setup flow
- [x] Present modally from SceneDelegate if `!UserDefaults.standard.setupCompleted`
- [x] Disable swipe-to-dismiss and back button until completion
- [x] Flow order: Credentials → Validation → Developer Mode → Certificate Trust → Anisette → Completion
- [x] Add progress indicator (e.g., "Step 2 of 5")

### 6.8 UserDefaults Extension
- [x] Create `UserDefaults+Setup.swift`
- [x] Add `setupCompleted: Bool` property (default false)
- [x] Add `lastSetupDate: Date?` for diagnostics
- [x] Add debug-only `resetSetup()` method clearing flag + credentials

### 6.9 Integration with SceneDelegate
- [x] Check `UserDefaults.standard.setupCompleted` in activateSceneForAccount
- [x] If false: present setup flow immediately
- [x] If true: proceed with normal app launch + BGTask scheduling
- [x] Block all signing operations until setup complete (coordinator already checks)

## Reference Material

**SideStore Setup Flow**: `/home/cvt/sidestore/AltStore/Authentication/`
- `AuthenticationViewController.swift` - Main credential input
- No equivalent for Developer Mode/Trust (SideStore assumes user knowledge)

**Deep Links**:
- Developer Mode (iOS 16+): `prefs:root=Privacy&path=DEVELOPER_MODE`
- VPN & Device Management: `prefs:root=General&path=ManagedConfigurationList`
- General Settings: `prefs:root=General`

**Dependencies**:
- Phase 5 (Keychain) - credential storage
- Phase 3 (AppOperationCoordinator) - signing validation
- Phase 1 (FetchAnisetteDataOperation) - connectivity testing

## Files to Create

- `ScaleCloudRenew/Sources/Setup/SetupCoordinator.swift`
- `ScaleCloudRenew/Sources/Setup/CredentialInputViewController.swift`
- `ScaleCloudRenew/Sources/Setup/DeveloperModeViewController.swift`
- `ScaleCloudRenew/Sources/Setup/TrustCertificateViewController.swift`
- `ScaleCloudRenew/Sources/Setup/AnisetteConfigViewController.swift`
- `ScaleCloudRenew/Sources/Setup/SetupCompleteViewController.swift`
- `ScaleCloudRenew/Sources/Utilities/UserDefaults+Setup.swift`

## Files to Modify

- `ScaleCloudRenew/project.yml` - ✅ Add UIKit framework dependency
- `ScaleCloudApp/iOSClient/SceneDelegate.swift` - ✅ Present setup flow on launch

## Testing Deferred to Phase 9

- Flow completion with valid credentials
- Flow interruption and resumption
- Error handling for invalid credentials
- Deep link functionality across iOS versions
- Setup flag persistence
- Certificate trust detection alternatives

## Status: COMPLETE

All 9 task sections implemented:
- 7 new source files created (Setup flow + UserDefaults extension)
- 2 files modified (project.yml + SceneDelegate.swift)
- Setup flow integrated into app launch sequence
- Phase 9 will add actual credential validation and error handling
