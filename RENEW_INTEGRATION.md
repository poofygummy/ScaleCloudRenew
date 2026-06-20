# ScaleCloudRenew — Integration Reference

## What is ScaleCloudRenew?

ScaleCloudRenew is a headless iOS framework extracted and refactored from [SideStore](https://github.com/SideStore/SideStore). It contains the complete app-signing and management engine — authentication against Apple's developer APIs, certificate management, provisioning profile fetching, app resigning, installation via minimuxer, and background refresh — but with every UI/UIKit interaction stripped out and replaced with callback-based or headless logic.

The framework is a dependency of **ScaleCloudApp**, which is the main app target that hosts the signing engine. ScaleCloudApp provides all the UI; ScaleCloudRenew provides all the signing logic.

---

## Repository Structure

```
ScaleCloudRenew/
├── project.yml                     # XcodeGen spec (generates .xcodeproj)
├── Sources/
│   ├── ScaleCloudRenew.h           # Umbrella ObjC header
│   ├── module.modulemap            # Module map for C interop
│   ├── AltStoreCore/               # Core data model, DB, shared types (from SideStore AltStoreCore)
│   ├── Anisette/                   # Anisette v1/v3 data fetching
│   ├── Extensions/                 # App extension discovery, OSLog macros
│   ├── Minimuxer/                  # minimuxer Rust bridge wrappers (wifi install, provisioning, JIT)
│   ├── Operations/                 # All signing operations (AppManager, AuthenticationOperation, etc.)
│   ├── Roxas/                      # RST ObjC utility library (from SideStore)
│   ├── RustBridge/                 # Swift bindings + prebuilt RustBridge.xcframework
│   ├── Security/                   # Keychain wrapper
│   ├── Setup/                      # Setup flow UI (credentials, validation, anisette, dev mode)
│   ├── Utilities/                  # BackgroundTaskManager, UserDefaults extensions, SecureEnclaveManager
│   ├── em_proxy/                   # Prebuilt libem_proxy-ios.a static library
│   ├── libimobiledevice/           # C sources for libimobiledevice (built as static lib target)
│   ├── libimobiledevice-glue/      # C sources for glue layer
│   ├── libplist/                   # C/C++ plist library
│   └── libusbmuxd/                 # C sources for usbmuxd
├── prebuilt/
│   └── ScaleCloudRenew.framework/  # Last known-good prebuilt binary (arm64 only)
└── OLDPLANS/                       # Historical planning docs (not code)
```

### Sibling Submodules Required at Build Time

| Submodule | Provides |
|-----------|----------|
| `ScaleCloudSign` | `ScaleCloudSign.framework` (AltSign fork) — all `ALT*` types, signing logic, Apple API client |
| `ScaleCloudKit` | `ScaleCloudKit.framework` — proxy session management (`SCKSession`), loopback VPN support |
| `ScaleCloudGo` | `ScaleCloudGo.xcframework` — Go-based minimuxer helper binary |

These are referenced with relative `../` paths in `project.yml` and must be checked out as siblings.

---

## How This Differs from the SideStore Reference

### 1. Library Identity

| | SideStore | ScaleCloudRenew |
|---|---|---|
| Module name | `AltStore` (app) + `AltStoreCore` (framework) | `ScaleCloudRenew` (single framework) |
| AltSign import | `import AltSign` | `import ScaleCloudSign` |
| Bundle ID (Keychain service) | `Bundle.Info.appbundleIdentifier` | `"com.scalecloud"` (hardcoded) |
| Build output | App `.app` | Framework `.framework` |

The rename from `AltSign` → `ScaleCloudSign` is pervasive. Every file that uses ALT types carries `import ScaleCloudSign`.

### 2. All UI Removed (Headless Mode)

Every user-facing interaction in the SideStore original has been stripped. The changes are clearly marked with `/* HEADLESS: ... */` block comments throughout the source. Key removals:

#### `AuthenticationOperation.swift`
- No `UINavigationController`, no storyboard.
- No 2FA code entry alert — `verificationHandler` is always `nil`. This means **accounts with 2FA prompts cannot complete login via password/email path**. (Token-based login bypasses this.)
- No `SelectTeamViewController` — when multiple teams exist, the **first team is auto-selected**.
- No certificate revocation confirmation alert — when no locally-stored cert is valid, **all existing SideStore/AltStore certs are automatically revoked** and a new one is requested.
- No `InstructionsViewController`, no `RefreshAltStoreViewController`.
- New token-based login path: if `Keychain.shared.appleIDAdsid` and `appleIDXcodeToken` are populated, login uses `ALTAppleAPI.fetchAccount2` with a pre-built `ALTAppleAPISession` instead of password.

#### `AppManager.swift`
- `deactivateApps(for:presentingViewController:completion:)` always calls `completion(.success(()))` immediately — the slot-limit deactivation dialog is gone.
- `add(_:presentingViewController:)` (add source with confirmation alert) is commented out.
- `remove(_:presentingViewController:)` (remove source with confirmation alert) is commented out.
- `installAsync` path that handles adding a source before install is commented out.
- Bundle ID override dialog (`resolveBundleID`, `_presentBundleIDOverrideDialog`) is commented out.
- `UIApplication.isIdleTimerDisabled` calls are commented out (no `UIApplication.shared` available in framework context).

#### `VerifyAppOperation.swift`
- `review(_:for:mode:presentingViewController:)` (shows `ReviewPermissionsViewController`) is commented out. Permission checking still happens silently, but the user is never shown the review sheet. For `.added` mode, if there is no `presentingViewController`, it throws `VerificationError.addedPermissions` as before; if there is one, it silently skips.

#### `BackgroundRefreshAppsOperation.swift`
- Push notification scheduling for refresh results removed — the framework does not schedule local notifications. That responsibility moves to ScaleCloudApp.
- `refreshCompletionHandler` callback added so the BGTask host (ScaleCloudApp) gets the result and expiry date.

### 3. Keychain Changes

The `Keychain` class is completely rewritten (not just moved):
- Service identifier: `"com.scalecloud"` (was `Bundle.Info.appbundleIdentifier` which evaluated to the SideStore bundle ID). This means keychain items are stored under a fixed shared identifier — usable by any app or extension with the same keychain access group.
- Added: `extensionProvisioningProfile(forBundleID:)` / `setExtensionProvisioningProfile(_:forBundleID:)` / `removeExtensionProvisioningProfile(forBundleID:)` — stores per-extension provisioning profile data.
- Added: `hasValidCredentials()` helper.
- `reset()` now also clears `signingCertificate`, `signingCertificatePassword`, the cert expiry UserDefault, and all stored extension profiles. The SideStore original did not clear those.
- The `AltStoreCore/Components/Keychain.swift` file is explicitly excluded from the XcodeGen sources (`"AltStoreCore/Components/Keychain.swift"`) so the new version at `Sources/Security/Keychain.swift` wins.

### 4. New: Setup Flow (`Sources/Setup/`)

SideStore has no equivalent. ScaleCloudRenew adds a full onboarding UI flow managed by `SetupCoordinator`:

1. **Credentials** (`CredentialInputViewController`) — email + password entry.
2. **Validation** (`ValidationViewController`) — calls Apple API to verify credentials.
3. **Developer Mode** (`DeveloperModeViewController`) — iOS 16+ only; skipped on iOS 15.
4. **Certificate Trust** (`TrustCertificateViewController`) — instructs user to trust the signing cert.
5. **Anisette** (`AnisetteConfigViewController`) — optionally configure a custom anisette server URL.
6. **Complete** (`SetupCompleteViewController`) — shows cert expiry date, marks setup done.

`SetupCoordinator` also has a **debug channel credential handoff** path: when a debugger is attached, it tries to receive credentials over stdin/stdout using Secure Enclave ECIES encryption (`SecureEnclaveManager`). This is designed for headless CI provisioning from a Mac.

### 5. New: `BackgroundTaskManager` (Silent Audio)

The `BackgroundTaskManager` (from SideStore) is retained but adapted. It plays a silent `.m4a` file from the framework bundle to extend background execution time during signing. Crucially, it now resolves the audio file from `Bundle(for: type(of: self))` (the framework bundle) rather than `Bundle.main`.

### 6. Minimuxer Layer (`Sources/Minimuxer/`)

The Minimuxer sources are copied verbatim from SideStore. `MinimuxerWrapper.swift` is new — it wraps all Minimuxer calls in `#if targetEnvironment(simulator)` guards and adds verbose logging. Several functions are left unused/commented (`bindTunnelConfig`, `retargetUsbmuxdAddr`, `minimuxerStartWithLogger`, etc.) — these were not needed for the headless path.

The `isMinimuxerReady` global function queries `Minimuxer.ready()` and is used throughout operations to gate WiFi-install paths.

### 7. Anisette (`Sources/Anisette/`)

`FetchAnisetteDataOperation` is essentially the SideStore version but with:
- UI removed (no server trust alert).
- `createProxySession()` uses `SCKSession.applyProxySettings()` from `ScaleCloudKit` — this applies the proxy/VPN routing needed for the loopback tunnel when the device is in LocalDevVPN mode.
- Outdated V1 servers are **auto-trusted** with a warning log rather than presenting a trust dialog.

`AnisetteManager` is copied from SideStore with minor changes (no UI dependencies).

### 8. `AppDelegate.swift` — Stub Only

In SideStore, `AppDelegate` is the full app entry point. In ScaleCloudRenew it is a near-empty stub class (not annotated `@UIApplicationMain`) that only carries the two backup notification name constants that are referenced by `BackupAppOperation`:
```swift
class AppDelegate {
    static let appBackupDidFinish = Notification.Name(...)
    static let appBackupResultKey = "result"
}
```
The full `AppDelegate` implementation is commented out entirely.

### 9. Build System: XcodeGen + Static libimobiledevice

SideStore builds `libimobiledevice` etc. as SPM dependencies. ScaleCloudRenew bundles the C sources directly and defines a `libimobiledevice` static library target in `project.yml`. This avoids SPM's build system and allows explicit control over compiler flags needed for iOS cross-compilation. The link is done via `OTHER_LDFLAGS: -force_load $(BUILT_PRODUCTS_DIR)/libimobiledevice.a`.

### 10. `SemanticVersion` Downgraded to 0.3.8

SideStore uses `SemanticVersion` from SwiftPackageIndex. This project pins it to `exactVersion: 0.3.8` to avoid a `swiftinterface` binary compatibility bug in 0.4.0 that prevented the prebuilt framework from loading correctly.

### 11. `OSLog+SideStore.swift` (Macros `ELOG`, `ILOG`, `DLOG`)

SideStore defines `ELOG`, `ILOG`, `DLOG` macros in an app-level file. Because ScaleCloudRenew is a framework without a bridging header, the file is copied into `Sources/Extensions/OSLog+SideStore.swift` to provide these logging helpers.

---

## Known Workarounds and Issues

### `alt_setUserInfoValueProviderForDomain` (ObjC Forward Declaration)

`AppManagerErrors.swift` calls a class method on `AuthenticationOperation` from ObjC context. Because `AuthenticationOperation` is a Swift class in a framework, the generated `-Swift.h` header cannot be imported back into ObjC source in the same module. The workaround is a manual ObjC forward declaration (`@class AuthenticationOperation;`) in the `.m` file.

### OpenSSL Linking (`-framework OpenSSL`)

`libimobiledevice` requires OpenSSL for TLS. Rather than linking it as an XCFramework dependency (which triggers Xcode's signature verification for embedded frameworks), it is linked as `-framework OpenSSL` via `OTHER_LDFLAGS`. The framework search path points to `ScaleCloudSign/Dependencies/OpenSSL.xcframework/ios-arm64/` where the actual `.framework` lives.

### `em_proxy` Linked via `force_load`

The `libem_proxy-ios.a` static library (the EM-proxy needed for WireGuard loopback) is at `Sources/em_proxy/libem_proxy-ios.a`. It is linked via `OTHER_LDFLAGS: -force_load` because the Swift linker would otherwise dead-strip symbols that Rust expects at link time. The C API functions are declared in Swift using `@_silgen_name` rather than a module map, to avoid clang module conflicts.

### `@_silgen_name` for `em_proxy` C Functions

Since a module map approach for `em_proxy` conflicted with other C modules, the C functions `startEMProxy(bind_addr:)` and `stopEMProxy()` are declared in Swift with `@_silgen_name` matching their C symbol names.

### `CLANG_ENABLE_MODULES` for Roxas

The Roxas ObjC sources use `@import` syntax. `CLANG_ENABLE_MODULES = YES` is set for the main framework target. Additionally `-fobjc-arc` is added via `OTHER_CFLAGS` because Roxas files do not have ARC enabled by default.

### `RSTDefines.h` Must Be Explicitly Imported

Several Roxas ObjC headers use `RST_EXTERN` and `DLog`/`ELog` macros defined in `RSTDefines.h`. These headers do not import it themselves, so `#import "RSTDefines.h"` was manually added to the affected `.h` and `.m` files.

### `UIViewController?` for Headless Contexts

Many operations accept `presentingViewController: UIViewController?` but never use it. This is intentional — the parameter is kept to preserve API compatibility with SideStore's operation chain, but is always passed as `nil` in headless calls. In a few cases (e.g. `VerifyAppOperation.verifyPermissions` with `.added` mode), a missing `presentingViewController` causes a thrown error instead of showing a UI.

### 2FA / Multi-Team Accounts

- **2FA during email+password login**: Not supported. If Apple requires a verification code, the login will fail with an `incorrectCredentials` or similar error. The only workaround is to use token-based login (ADSID + Xcode token) which does not trigger 2FA.
- **Multiple teams**: The first team in the list is selected automatically. There is no way to choose a specific team in headless mode other than ensuring only one team is active in the Apple developer portal.

### `validateAppExtensionsOperation` Commented Out

In `AppManager._refresh`, a `validateAppExtensionsOperation` is defined but its dependency chain is commented out (see the `// fetchProvisioningProfilesOperation.addDependency(validateAppExtensionsOperation)` line). The validation logic runs but does not block the operation — it prints an error and finishes without failing. This is intentional for robustness but means mismatches between DB and disk app extensions will not abort a refresh.

### `AltBackup.ipa` Bundle Resource

`_installBackupApp(for:...)` calls `Bundle.main.url(forResource: "AltBackup", withExtension: "ipa")`. In the framework context, `Bundle.main` refers to the host app bundle (ScaleCloudApp). ScaleCloudApp must bundle `AltBackup.ipa` for this to work. If it is absent, the backup/activate/deactivate flows will fail.

---

## Credential Flow (How to Authenticate)

### Option A: Email + Password (No 2FA)

1. Store credentials in Keychain **before** any operation runs:
   ```swift
   Keychain.shared.appleIDEmailAddress = "user@example.com"
   Keychain.shared.appleIDPassword     = "appspecificpassword"
   ```
2. Call any `AppManager` operation. `AuthenticationOperation` will use these on first run.
3. On success, `Keychain.shared.appleIDAdsid` and `appleIDXcodeToken` are automatically saved. Subsequent calls use the cached session or token login.

### Option B: ADSID + Xcode Token (Preferred for Headless)

1. Obtain the ADSID and Xcode auth token from a SideStore/AltStore installation (or any prior login).
2. Store:
   ```swift
   Keychain.shared.appleIDAdsid       = "..."
   Keychain.shared.appleIDXcodeToken  = "..."
   ```
3. `AuthenticationOperation.signIn` will use these first, before trying email+password.

### Option C: Setup Flow Debug Channel

During development/CI, with a debugger attached to the device:
1. `SetupCoordinator.init()` detects the debugger via `DebuggerUtils.isDebuggerAttached()`.
2. It generates a Secure Enclave ECDH key pair, prints `SCALECLOUD_PUBKEY:<base64>` to stdout.
3. The Mac-side tool reads the public key, encrypts the Apple ID password with ECIES, and writes back:
   ```
   SCALECLOUD_APPLEID:<email>
   SCALECLOUD_PASSWORD:<encrypted_base64>
   SCALECLOUD_ANISETTE:<url>       # optional
   SCALECLOUD_PAYLOAD_COMPLETE
   ```
4. The framework decrypts with the Secure Enclave private key and stores credentials.
5. Sends `SCALECLOUD_CREDENTIALS_OK` to confirm.

---

## Anisette Configuration

Anisette data is required for every Apple API call. ScaleCloudRenew supports anisette v1 (legacy) and v3 (WebSocket provisioning).

### Setting a Server

```swift
// Set a list of candidate servers
UserDefaults.standard.menuAnisetteServersList = ["http://192.168.1.x:6969"]

// Or set a specific active server
UserDefaults.standard.menuAnisetteURL = "http://192.168.1.x:6969"
```

`FetchAnisetteDataOperation.getAnisetteServerUrl` will try each server in the list in order, pinging it first. The first reachable one is used and saved as `menuAnisetteURL`.

**Important**: There is no built-in default server. `AnisetteManager.defaultURL` reads from `Info.plist` key `ALTAnisetteURL`. The host app (ScaleCloudApp) must either set an `Info.plist` value or populate `UserDefaults.standard.menuAnisetteServersList` at startup.

---

## How to Trigger a Refresh

```swift
import ScaleCloudRenew

// 1. Start the database
DatabaseManager.shared.start { error in
    guard error == nil else { return }

    // 2. Fetch installed apps from CoreData
    let context = DatabaseManager.shared.viewContext
    let apps = InstalledApp.fetchAppsForBackgroundRefresh(in: context)

    // 3. Kick off background refresh
    let op = AppManager.shared.backgroundRefresh(apps, presentsNotifications: false) { result in
        switch result {
        case .success(let results):
            print("Refreshed:", results.keys)
        case .failure(let error):
            print("Failed:", error)
        }
    }
    
    // 4. Optionally capture expiry via BackgroundRefreshAppsOperation.refreshCompletionHandler
    op.refreshCompletionHandler = { success, expiryDate in
        // expiryDate is also written to UserDefaults key "com.scalecloud.cert.expiry"
    }
}
```

Refresh requires:
- minimuxer to be running and ready (`isMinimuxerReady == true`)
- A valid anisette server in `menuAnisetteServersList`
- Apple credentials in Keychain

---

## UserDefaults Keys Used

| Key | Type | Description |
|-----|------|-------------|
| `com.scalecloud.setupCompleted` | `Bool` | Set by `SetupCoordinator.setupCompleted()` |
| `com.scalecloud.lastSetupDate` | `Date` | Timestamp of last completed setup |
| `com.scalecloud.cert.expiry` | `Date` | Certificate expiry, written by `BackgroundRefreshAppsOperation` |
| `menuAnisetteServersList` | `[String]` | Candidate anisette server URLs |
| `menuAnisetteURL` | `String` | Currently active anisette server URL |

---

## Operations Logging Control

Individual operations have verbose logging that can be toggled via `UserDefaults`:

```swift
OperationsLoggingControl.updateDatabase(for: SomeOperation.self, value: true)
```

The key is `"<OperationClassName>LoggingEnabled"` in `UserDefaults.standard`. `ANISETTE_VERBOSITY` (a dummy class) controls `FetchAnisetteDataOperation` output.

---

## Readiness for Headless Operation

| Capability | Status | Notes |
|-----------|--------|-------|
| Email+password login (no 2FA) | ✅ Works | Requires app-specific password; 2FA prompts will fail |
| Token-based login (ADSID/XcodeToken) | ✅ Works | Best path for headless use |
| Multi-team accounts | ⚠️ Auto-picks first | No way to select a specific team |
| Anisette v3 provisioning | ✅ Works | Requires reachable anisette server |
| Certificate management (request/revoke) | ✅ Works | Auto-revokes; no confirmation |
| App install (IPA → resign → device) | ✅ Works | Requires minimuxer ready |
| App refresh (provisioning profile) | ✅ Works | Requires minimuxer ready |
| Background refresh | ✅ Works | Silent audio workaround included |
| Setup UI flow | ✅ Functional | Still requires UIKit host (ScaleCloudApp) |
| Debug channel credential handoff | ✅ Implemented | Requires attached debugger (LLDB) |
| 2FA / verification code input | ❌ Not supported | Would need stdin/callback mechanism |
| Selective team choice | ❌ Not supported | Always picks first |
| Source management UI (add/remove) | ❌ Removed | Must be done programmatically if needed |
| Permission review UI | ❌ Removed | Permissions verified silently; may throw on added perms |
| AltBackup restore flow | ⚠️ Requires `AltBackup.ipa` in host app bundle | |
| XCFramework/prebuilt binary | ✅ Available | `prebuilt/ScaleCloudRenew.framework` (arm64) |
| `.xcodeproj` generation | ✅ Via XcodeGen | Run `xcodegen generate` in submodule root |
| Build on Xcode (macOS runner) | ✅ Via GitHub Actions | Requires sibling submodules checked out |

### Summary

The submodule is functionally complete for its intended role as a headless signing engine. The biggest outstanding limitation for fully unattended operation is **2FA**. For production use, Apple IDs should use an app-specific password (which does not trigger 2FA) or pre-extracted ADSID/Xcode tokens.

The prebuilt framework (`prebuilt/ScaleCloudRenew.framework`) is available for integration without rebuilding from source. The framework binary is arm64-only and was built with `BUILD_LIBRARY_FOR_DISTRIBUTION = YES` for ABI stability.
