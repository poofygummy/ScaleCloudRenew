# ScaleCloudRenew — Integration Reference

> Last updated: reflects full file-by-file diff of every ScaleCloudRenew source against its SideStore counterpart. All functional differences are verified.

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

## ScaleCloudSign Submodule — Identity and History

### Name History

The name `ScaleCloudSign` has referred to **two different things** at different points in the repository history. Understanding this is critical to reading old commits.

| Era | What `ScaleCloudSign/` was |
|---|---|
| **Before Jun 16 2026** (`d0dc187901` → `9559767949`) | The signing *operations* framework — the code that is now called **ScaleCloudRenew**. It contained `AppManager.swift`, `AuthenticationOperation.swift`, the SideStore operations engine, etc. These ~50 commits were all committed **flat** directly into the main repo (no submodule). |
| **Jun 16 2026** (commit `452a669e2c`) | Rename commit: `ScaleCloudSign → ScaleCloudRenew` (operations framework renamed), and a **new** `ScaleCloudSign` submodule introduced pointing to `github.com/poofygummy/ScaleCloudSign.git` which contains the **AltSign fork** (ObjC Apple API client library). |
| **Jun 17 2026+** (commit `ce928ecfdc` onward) | The flat embedded files were stripped and replaced with a proper git submodule pointer. All subsequent commits on `ScaleCloudSign/` in the main repo are submodule pointer bumps. |

Commit `452a669e2c` in the main repo is the watershed: before it, `ScaleCloudSign/` = operations. After it, `ScaleCloudSign/` = AltSign ObjC library.

### What ScaleCloudSign Is Today

`ScaleCloudSign` is the **AltSign fork** — an ObjC/Swift library that handles the low-level Apple developer API communication and code signing. It is compiled as a dynamic framework and consumed by ScaleCloudRenew via `import ScaleCloudSign`.

**Package identity**: Swift Package Manager (`Package.swift`), not XcodeGen.

**Module layout** (4 SPM targets compiled into one framework product):

| SPM Target | Language | Role |
|---|---|---|
| `ScaleCloudSign` | Swift | Swift extensions: `ALTAppleAPI+Authentication`, `GSAContext`, `CoreCryptoMacros`, `Data+Encryption` |
| `CScaleCloudSign` | ObjC/ObjC++ | All ObjC sources: `ALTAppleAPI`, `ALTSigner`, all model files, categories |
| `CCoreCrypto` | C | Apple's corecrypto headers + `ccsrp.m` (SRP authentication) |
| `ldid` + `ldid-core` | C++ | Code signing: `alt_ldid.cpp` wrapper + full `ldid` + `libplist` C sources |

**Dependencies bundled inside the submodule**:
- `Dependencies/OpenSSL.xcframework` — multi-platform OpenSSL (ios-arm64, simulator, macOS, tvOS, watchOS, visionOS slices)
- `Dependencies/corecrypto/` — Apple corecrypto headers + `ccsrp.m`
- `Dependencies/ldid/` — full ldid source tree including `libplist`
- `Dependencies/minizip/` — minizip C sources
- `Dependencies/ldid` (git submodule, `rileytestut/ldid`) — nested submodule

**Prebuilt binary**: `ScaleCloudSign/prebuilt/ScaleCloudSign.framework/` — arm64 iOS dynamic framework built from this source tree. Contains:
- Binary: `ScaleCloudSign`
- `Headers/` — all public ObjC headers (`ALT*.h`, `NSError+ALTErrors.h`, etc.)
- `Modules/module.modulemap` — `framework module ScaleCloudSign { umbrella header ... }`
- `Modules/ScaleCloudSign.swiftmodule/` — Swift interface files (`arm64-apple-ios.swiftinterface`, `.abi.json`, `.swiftdoc`, `.swiftmodule`, `.private.swiftinterface`)

### ScaleCloudSign Rename: `AltSign → ScaleCloudSign`

Inside the submodule itself, the original upstream module name was `AltSign`. Commit `8016191` (in the submodule's own history) renamed everything: product name, module name, umbrella header, all public header paths. Commit `ff19013` fixed a double-rename artifact (`ScaleCloudSignoudSign` typo in three private headers).

The result:
- Umbrella header: `ScaleCloudSign/include/ScaleCloudSign.h` (was `AltSign.h`)
- All `#import <AltSign/...>` → `#import <ScaleCloudSign/...>`
- SPM product name: `ScaleCloudSign` (was `AltSign`)
- The CCoreCrypto/CScaleCloudSign module bundling was attempted then reverted (`6c66b67` then `1d271fd`); current HEAD `1d271fd` has the revert, meaning CCoreCrypto and CScaleCloudSign are separate SPM targets, not baked into the framework binary directly.

### CCoreCrypto / CScaleCloudSign Module Notes

Commit `6c66b67` attempted to bundle `CCoreCrypto` and `CScaleCloudSign` module descriptors into the prebuilt framework's `Modules/` directory so downstream consumers wouldn't need to re-import them. This was reverted by `1d271fd` (current HEAD). The implication: **consumers of the prebuilt `ScaleCloudSign.framework` must have `CCoreCrypto` and `CScaleCloudSign` available separately**, or compile from SPM source where those targets are resolved automatically.

In practice, ScaleCloudRenew's `project.yml` links `ScaleCloudSign.framework` as a prebuilt and separately declares `CCoreCrypto` / `CScaleCloudSign` availability via `FRAMEWORK_SEARCH_PATHS` pointing to the sibling submodule's source.

### Build Workflow for ScaleCloudSign

The `create-release.yml` workflow in the submodule builds the prebuilt:
1. Checks out `scalecloud-ios` (sparse, `ScaleCloudKit/prebuilt` only) for `ScaleCloudKit.framework`
2. Strips invalid OpenSSL code signatures (`find ... _CodeSignature ... rm -rf`)
3. Runs `xcodebuild build` with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` and `-no-verify-emitted-module-interface`
4. Manually copies the `.swiftmodule` folder from `DerivedData/Build/Intermediates.noindex` into `prebuilt/ScaleCloudSign.framework/Modules/` (SPM does not embed these in the framework automatically)
5. Copies all public headers from `ScaleCloudSign/include/` into `prebuilt/.../Headers/`
6. Writes a `module.modulemap` manually
7. Uploads as a GitHub Actions artifact (not a GitHub Release)

Trigger: push to a `v*` tag, or `workflow_dispatch`.

---

## How This Differs from the SideStore Reference

### 1. Library Identity

| | SideStore | ScaleCloudRenew |
|---|---|---|
| Module name | `AltStore` (app) + `AltStoreCore` (framework) | `ScaleCloudRenew` (single framework) |
| AltSign import | `import AltSign` | `import ScaleCloudSign` |
| Bundle ID (Keychain service) | `Bundle.Info.appbundleIdentifier` | `"com.scalecloud"` (hardcoded) |
| Build output | App `.app` | Framework `.framework` |

> **Historical note**: In the main repo's git history, `import AltSign` references in pre-`452a669e2c` commits referred to the old embedded `ScaleCloudSign/` source tree (the operations framework, now `ScaleCloudRenew`). After `452a669e2c`, `import ScaleCloudSign` refers to the dedicated AltSign-fork submodule. These are different things at different points in history.

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

`FetchAnisetteDataOperation` differs from SideStore in the following ways (verified by diff):

- **`viewContext: UIViewController?` parameter removed** from `getAnisetteServerUrl()` and `tryNextServer()`. The signature is now parameterless; all call sites updated.
- **Toast UI replaced with `logMessage()`** — `showToast(viewContext:message:)` is replaced by `private func logMessage(_ message: String)` which calls `print("[Anisette] \(message)")`.
- **Outdated V1 server alert removed** — SideStore presented a `UIAlertController` asking the user whether to continue with a V1 server. ScaleCloudRenew auto-accepts: logs `"WARNING: Outdated V1 server - auto-accepting"` and immediately calls `fetchAnisetteV1()`.
- **`createProxySession()` added** — all `URLSession.shared.dataTask(...)` calls are replaced with `createProxySession().dataTask(...)`. `createProxySession()` builds a `URLSessionConfiguration.default`, sets `connectionProxyDictionary = SCKSession.applyProxySettings()`, creates a session, and calls `SCKSession.registerSession(session)`. This routes anisette traffic through the ScaleCloudKit proxy/VPN when active.
- `import ScaleCloudKit` and `import ScaleCloudSign` replace `import AltStoreCore`, `import AltSign`, `import Roxas`.

`AnisetteManager` is **identical** to SideStore (no changes).

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

### `NSError+ALTServerError.m` — Import Block Replaced with Forward Declarations

SideStore's `NSError+ALTServerError.m` uses a three-way `#if ALTJIT / TARGET_OS_OSX / !TARGET_OS_OSX` conditional block to import the right generated Swift header and `@import AltSign`. None of those conditions apply in a framework target. The entire block is replaced with:
```objc
@import ScaleCloudSign;

// Forward-declare @objc Swift extensions — avoids circular import with
// the generated ScaleCloudRenew-Swift.h (ObjC compiles before Swift finishes).
typedef id _Nullable (^ALTUserInfoProvider)(NSError * _Nonnull, NSErrorUserInfoKey _Nonnull);
@interface NSError (AltStoreSwift)
@property (nonatomic, readonly, nullable) NSString *alt_localizedFailure;
@property (nonatomic, readonly, nullable) NSString *alt_localizedDebugDescription;
+ (void)alt_setUserInfoValueProviderForDomain:(NSErrorDomain)domain provider:(ALTUserInfoProvider _Nullable)provider;
@end
```

### `alt_setUserInfoValueProviderForDomain` (ObjC Forward Declaration)

`AppManagerErrors.swift` calls a class method on `AuthenticationOperation` from ObjC context. Because `AuthenticationOperation` is a Swift class in a framework, the generated `-Swift.h` header cannot be imported back into ObjC source in the same module. The workaround is a manual ObjC forward declaration (`@class AuthenticationOperation;`) in the `.m` file.

### OpenSSL Linking (`-framework OpenSSL`)

`libimobiledevice` requires OpenSSL for TLS. Rather than linking it as an XCFramework dependency (which triggers Xcode's signature verification for embedded frameworks), it is linked as `-framework OpenSSL` via `OTHER_LDFLAGS`. The framework search path points to `ScaleCloudSign/Dependencies/OpenSSL.xcframework/ios-arm64/` where the actual `.framework` lives.

The `ScaleCloudSign` build workflow also strips invalid OpenSSL code signatures before building (step: `find Dependencies/OpenSSL.xcframework -name '_CodeSignature' -type d -exec rm -rf {} +`). If building locally, this step must be run manually or Xcode will refuse to process the xcframework.

### `em_proxy` Linked via `force_load`

The `libem_proxy-ios.a` static library (the EM-proxy needed for WireGuard loopback) is at `Sources/em_proxy/libem_proxy-ios.a`. It is linked via `OTHER_LDFLAGS: -force_load` because the Swift linker would otherwise dead-strip symbols that Rust expects at link time. The C API functions are declared in Swift using `@_silgen_name` rather than a module map, to avoid clang module conflicts.

### `@_silgen_name` for `em_proxy` C Functions

Since a module map approach for `em_proxy` conflicted with other C modules, the C functions `startEMProxy(bind_addr:)` and `stopEMProxy()` are declared in Swift with `@_silgen_name` matching their C symbol names.

### `UIColor+AltStore.swift` — Completely Replaced

SideStore's version (added 2023) provides `UIColor.altBackground` and brightness helpers (`adjustedForDisplay`, `isTooBright`, `isTooDark`). ScaleCloudRenew replaces it with a different file (dated 2019) that loads named colors from the **framework bundle** (`Bundle(for: DatabaseManager.self)`):

```swift
public extension UIColor {
    private static let colorBundle = Bundle(for: DatabaseManager.self)
    static let altPrimary     = UIColor(named: "Primary",       in: colorBundle, compatibleWith: nil)!
    static let deltaPrimary   = UIColor(named: "DeltaPrimary",  in: colorBundle, compatibleWith: nil)
    static let clipPrimary    = UIColor(named: "ClipPrimary",   in: colorBundle, compatibleWith: nil)
    static let refreshRed     = UIColor(named: "RefreshRed",    in: colorBundle, compatibleWith: nil)!
    static let refreshOrange  = UIColor(named: "RefreshOrange", in: colorBundle, compatibleWith: nil)!
    static let refreshYellow  = UIColor(named: "RefreshYellow", in: colorBundle, compatibleWith: nil)!
    static let refreshGreen   = UIColor(named: "RefreshGreen",  in: colorBundle, compatibleWith: nil)!
}
```

The named colors are defined in `Sources/AltStoreCore/Resources/Colors.xcassets/`. The `altBackground`/`adjustedForDisplay`/`isTooBright`/`isTooDark` properties from the SideStore version are absent. The extension is `public` (the SideStore version was `internal`).

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

### Option C: Setup Flow Debug Channel (iloader)

During initial device provisioning, iloader launches the app via `idevicedebug` and performs a credential handoff over stdin/stdout:
1. `SetupCoordinator.init()` detects the debugger via `DebuggerUtils.isDebuggerAttached()`.
2. It generates a transient Secure Enclave P-256 key pair and prints to stdout:
   ```
   <base64-encoded public key>
   SCALECLOUD_PUBKEY_READY
   ```
   The public key line is **bare base64 with no prefix**. iloader captures the last non-empty line before the sentinel.
3. iloader encrypts the password using ECIES (`kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM`: X9.63 KDF → AES-128-GCM with 16-byte IV) and writes 5 positional lines to stdin:
   ```
   <base64-encrypted-password>
   <plaintext-email>
   <anisette-url>
   <tailscale-hostname>
   SCALECLOUD_PAYLOAD_COMPLETE
   ```
   Lines are **positional**, not key-value prefixed. The app reads them by line number.
4. The app decrypts with `SecureEnclaveManager` (using `eciesEncryptionStandardVariableIVX963SHA256AESGCM`) and stores credentials in Keychain. The anisette URL is stored in `menuAnisetteServersList`. The tailscale hostname (line 4) is logged but not stored — it belongs to ScaleCloudApp's Nextcloud login flow, not ScaleCloudRenew.
5. Sends `SCALECLOUD_CREDENTIALS_OK` to confirm. iloader waits 1 second then kills the debug process.

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

## Repository History Reference

### Key Commits in Main Repo That Touched `ScaleCloudSign/`

This is a reference for reading `git log` output in the main repo. The path `ScaleCloudSign/` means two different things depending on the era.

**Pre-rename era** (operations framework under `ScaleCloudSign/`, 50+ commits):

| Commit | What it did |
|--------|-------------|
| `d0dc187901` | First commit: added phase docs, `Keychain.swift`, `project.yml`, AltSign C sources into the flat `ScaleCloudSign/` directory |
| `2fb8f10f3f` → `ff0fc62a4b` | Long series adding AltStoreCore/Roxas as local sources, fixing header search paths and umbrella headers |
| `ed9dc74cc1` | Added corecrypto headers and `GSAContext` crypto functions |
| `0d12ed3d59` | Fixed duplicate `UserDefaults` declarations, added `CommonCrypto` import to `GSAContext` |
| `4d2fbde45c` | Removed internal module imports — all code compiled as single ScaleCloudSign module |
| `5786a13fd6` | Added `extern_c` attribute to CoreCrypto module map |
| `ea4fed5d60` → `b235f141ae` | Six attempts at fixing a `corecrypto` `!` assertion failure |
| `3f2dd9d3f3` | Toggled `!` operator in altsign (SRP authentication fix) |
| `8f59e74286`, `5df7296a78`, `ff9d362c0a` | Rebuilt prebuilt kit with different Xcode versions |

**Restructure commit** (watershed):

| Commit | What it did |
|--------|-------------|
| `452a669e2c` | **Renamed `ScaleCloudSign → ScaleCloudRenew`** (this framework). Simultaneously introduced new `ScaleCloudSign/` as the AltSign-fork submodule. Renamed workflow file `testbuildSCSign.yml → testbuildSCRenew.yml`. Updated all references in `ScaleCloudApp.xcodeproj`, `AppDelegate+SigningRefresh.swift`, `SceneDelegate.swift`, `SCKSession.swift`. |
| `ce928ecfdc` | Converted the remaining flat `ScaleCloudSign/` files to a proper git submodule (deleted ~500 tracked files, added the submodule pointer). |

**Post-submodule era** (submodule pointer bumps):

| Commit | What it did |
|--------|-------------|
| `ffc4555bf7` | Bump to commit after `rename AltSign > ScaleCloudSign` inside submodule |
| `0682c519da` | Bump submodule ref |
| `e141dd142b` | Bump to latest (renamed prebuilt) |
| `911d233dc8` | Fix: resolve CCoreCrypto/CScaleCloudSign module deps for ScaleCloudRenew |
| `24b988c04c` | Revert the above |
| `08f1b7c63e` | Fix: update submodule pointers for CCoreCrypto/CScaleCloudSign fix |

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
