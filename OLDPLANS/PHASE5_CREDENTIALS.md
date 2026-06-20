# Phase 5: Credential Storage

**Status**: ✅ COMPLETE  
**Goal**: Secure storage for authentication materials and configuration

---

## SideStore Reference

**Keychain wrapper**: `/home/cvt/sidestore/AltStoreCore/Components/Keychain.swift`  
**Dependencies**: `KeychainAccess` library (already in SPM)  
**Accessibility**: `.afterFirstUnlock` + `.synchronizable(true)`  
**Service**: Bundle identifier based

---

## Implementation Tasks

### 1. Extract Keychain Wrapper ✅
- [x] Copy Keychain.swift to `ScaleCloudRenew/Sources/Security/`
- [x] Update service identifier to `com.scalecloud`
- [x] Add to project.yml sources (auto-detected)
- [x] Verify KeychainAccess dependency in Package.swift

### 2. Credential Storage

**Properties from SideStore Keychain.swift**:
```swift
appleIDEmailAddress: String?
appleIDPassword: String?
appleIDAdsid: String?  // Used for session management
appleIDXcodeToken: String?  // Session token
signingCertificatePrivateKey: Data?
signingCertificateSerialNumber: String?
signingCertificate: Data?  // DER format
signingCertificatePassword: String?
```

**In-memory session cache**:
```swift
certificate: ALTCertificate?
session: ALTAppleAPISession?
team: ALTTeam?
```

Tasks:
- [x] Keep all properties as-is from SideStore
- [x] Verify kSecAttrAccessible = .afterFirstUnlock (allows background access)
- [x] Verify synchronizable flag (iCloud Keychain sync)
- [x] Add reset() method for logout
- [x] Add hasValidCredentials() validation method

### 3. Provisioning Profile Storage

**Decision**: Provisioning profiles NOT stored in Keychain (per SideStore)

Profiles are:
- Fetched on-demand during signing from Apple API
- Embedded directly into IPA during resign operation
- Managed by FetchProvisioningProfilesOperation

Tasks:
- [x] Document that profiles are transient/fetched per-operation
- [x] Verify profile caching not needed
- [x] Note: Each extension gets separate profile (see FetchProvisioningProfilesOperation.swift)

### 4. Certificate Expiry Integration

**Existing**: Phase 3 stored expiry in Keychain at `com.scalecloud.cert.expiry`  
**New**: Use `signingCertificate` Data to parse actual X.509 expiry

Tasks:
- [x] Keep existing UserDefaults key for BGTask scheduling
- [x] Add method: `func updateCertificateExpiry(from certificate: Data)`
- [x] Parse DER certificate for notAfter field (via ALTCertificate)
- [x] Update `com.scalecloud.cert.expiry` after successful signing
- [x] Integrated into BackgroundRefreshAppsOperation

### 5. Configuration

**Anisette Server URL**: Located in FetchAnisetteDataOperation (MANUAL CONFIGURATION REQUIRED)

Tasks:
- [x] Created UserDefaults extension for menuAnisetteURL and menuAnisetteServersList
- [x] Documented manual configuration requirement in UserDefaults+Anisette.swift
- [x] FetchAnisetteDataOperation uses UserDefaults.standard.menuAnisetteServersList
- [x] User must add toth-adattar Tailscale address to list manually

### 6. Integration Points

**AuthenticationOperation** (Phase 1 extracted):
```swift
// Reads: appleIDEmailAddress, appleIDPassword
// Writes: session, team, certificate (in-memory)
// Writes: appleIDAdsid, appleIDXcodeToken (persisted)
```

**BackgroundRefreshAppsOperation** (Phase 1 + Phase 4):
```swift
// Reads: signingCertificate for expiry check
// Writes: signingCertificate, signingCertificatePrivateKey after renewal
// Updates: com.scalecloud.cert.expiry in UserDefaults
```

**FetchAnisetteDataOperation** (Phase 1):
```swift
// Contains Anisette server URL string (MANUAL CONFIGURATION POINT)
```

**AppOperationCoordinator** (Phase 3):
```swift
// Reads: signingCertificate for state machine expiry logic
```

Tasks:
- [x] Keychain.shared already used in FetchAnisetteDataOperation (Phase 1)
- [x] Integrated into BackgroundRefreshAppsOperation for expiry parsing
- [x] Background task Keychain access configured (.afterFirstUnlock)
- [x] URL configuration documented in UserDefaults+Anisette.swift

### 7. Validation

Tasks:
- [x] Add credential presence check: `hasValidCredentials() -> Bool`
- [x] Check Apple ID email + password non-nil and non-empty
- [x] Ready for use by setup flow (Phase 6) and operations
- [x] Returns boolean (errors handled at call site)

### 8. Security Considerations

**Access Control**:
- kSecAttrAccessible = `.afterFirstUnlock` (set by KeychainAccess)
- Allows background task access after first device unlock
- Syncs via iCloud Keychain (.synchronizable = true)

**Password Storage**:
- Store plaintext (required for Apple API authentication)
- iOS Keychain encryption handles security
- Recommend app-specific passwords in setup UI (Phase 6)

Tasks:
- [x] Document security model in code comments (see Keychain.swift header)
- [x] Add warnings about credential sensitivity
- [x] Verify no logging of passwords/tokens (FetchAnisetteDataOperation uses printOut)

---

## File Changes

### New Files
```
ScaleCloudRenew/Sources/Security/Keychain.swift (adapted from SideStore)
ScaleCloudRenew/Sources/Utilities/UserDefaults+Anisette.swift (new)
```

### Modified Files
```
ScaleCloudRenew/Sources/Operations/BackgroundRefreshAppsOperation.swift (added expiry parsing)
```

### No Changes Required
```
ScaleCloudRenew/Sources/Anisette/FetchAnisetteDataOperation.swift (already uses Keychain.shared)
ScaleCloudRenew/project.yml (Security/ auto-detected by XcodeGen)
```

---

## Implementation Details

**Keychain.swift** (186 lines):
- Service: `com.scalecloud`
- Accessibility: `.afterFirstUnlock` + `.synchronizable(true)`
- Added methods: `hasValidCredentials()`, `updateCertificateExpiry(from:)`, `reset()`
- All SideStore properties preserved

**UserDefaults+Anisette.swift** (36 lines):
- `menuAnisetteServersList: [String]` - user adds Tailscale address here
- `menuAnisetteURL: String` - auto-selected working server
- Used by FetchAnisetteDataOperation

**BackgroundRefreshAppsOperation.swift** changes:
- Removed hardcoded 7-day expiry
- Reads `Keychain.shared.signingCertificate`
- Calls `updateCertificateExpiry(from:)` after success
- Parses via `ALTCertificate.expirationDate`
- Updates UserDefaults key `com.scalecloud.cert.expiry`

**Provisioning profiles**: NOT stored (fetched on-demand per SideStore)

**Testing**: Deferred to Phase 9

**Dependencies**: KeychainAccess (already present), Security.framework (implicit)

**Manual config required**: User must populate `menuAnisetteServersList` with toth-adattar Tailscale address
