# Phase 9: Polishing - COMPLETE ✅

**Goal**: Accept Anisette URL + Apple ID + Password from computer installer via debug channel, skip manual setup screens

**Status**: ✅ Implementation complete — debug channel credential handoff using Secure Enclave ECIES encryption

---

## 9.0 Remove Previous Implementation 🗑️

### Files Modified

- [x] **ScaleCloudApp/Brand/iOSClient.plist** — removed CFBundleURLTypes / scalecloud:// URL scheme entry entirely
- [x] **ScaleCloudApp/iOSClient/SceneDelegate.swift** — removed handleScaleCloudConfigURL(_:) method and scene(_:openURLContexts:) URL handling entirely
- [x] **ScaleCloudRenew/Sources/Setup/SetupCoordinator.swift** — removed anisettePreConfigured check in certificateTrustConfirmed(), removed credentialsPreConfigured skip in init() and start(from:)
- [x] **ScaleCloudRenew/Sources/Utilities/UserDefaults+Setup.swift** — removed anisettePreConfigured and credentialsPreConfigured properties

---

## 9.1 Debug Channel Credential + Config Handoff ✅

### Security Architecture
All configuration — Apple ID email, password, and Anisette URL — is transmitted from the computer to the app via a debug channel (debugserver over USB). The password is encrypted using Secure Enclave asymmetric ECIES encryption. Nothing is ever written to the filesystem. No URL scheme is used.

### App-Side Implementation

#### Step 1: Debugger Detection on First Launch

- [x] Add DebuggerUtils.swift to ScaleCloudRenew/Sources/Utilities/ (new file)
- [x] Implement isDebuggerAttached() -> Bool using sysctl + P_TRACED flag
- [x] In SetupCoordinator.init():
  - If isDebuggerAttached() → enter debug channel handoff flow
  - If not → show manual CredentialInputViewController as fallback

#### Step 2: Secure Enclave Key Generation

- [x] Add SecureEnclaveManager.swift to ScaleCloudRenew/Sources/Utilities/ (new file)
- [x] Implement generateKeyPair() -> (publicKeyBytes: Data, privateKeyRef: SecKey):
  - Use SecKeyCreateRandomKey with kSecAttrTokenIDSecureEnclave
  - Private key reference stays in Secure Enclave — never exported, used transiently
  - Export public key bytes using SecKeyCopyExternalRepresentation

#### Step 3: Public Key Handoff to Computer

- [x] Write public key bytes to stdout as Base64
- [x] Write sentinel line SCALECLOUD_PUBKEY_READY so computer knows transmission is complete
- [x] Block on stdin waiting for encrypted payload from computer

#### Step 4: Receive and Decrypt Credentials

- [x] Read encrypted blob from stdin (Base64-encoded, contains password only)
- [x] Read Apple ID email from stdin (plaintext — not a secret)
- [x] Read Anisette URL from stdin (plaintext — not a secret)
- [x] Read sentinel SCALECLOUD_PAYLOAD_COMPLETE confirming all values received
- [x] Decrypt password blob using SecKeyCreateDecryptedData with kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM
- [x] Plaintext password exists only as a Swift String in memory

#### Step 5: Keychain + UserDefaults Storage and Cleanup

- [x] Store decrypted password to Keychain.shared.appleIDPassword
- [x] Store Apple ID email to Keychain.shared.appleIDEmailAddress
- [x] Store Anisette URL to UserDefaults.standard.menuAnisetteServersList
- [x] Write sentinel SCALECLOUD_CREDENTIALS_OK to stdout so computer knows to close debug session

### Setup Flow Integration

- [x] SetupCoordinator.init() checks DebuggerUtils.isDebuggerAttached()
- [x] If debugger attached: call performDebugChannelHandoff()
- [x] If handoff succeeds: start with ValidationViewController, set currentStep = .validation
- [x] If handoff fails or no debugger: start with CredentialInputViewController (fallback to manual entry)
- [x] SetupCoordinator.start() auto-triggers validation if currentStep == .validation

### New Files Created

- [x] **ScaleCloudRenew/Sources/Utilities/DebuggerUtils.swift**
- [x] **ScaleCloudRenew/Sources/Utilities/SecureEnclaveManager.swift**

### Files Modified

- [x] **ScaleCloudApp/Brand/iOSClient.plist** — removed scalecloud:// URL scheme
- [x] **ScaleCloudApp/iOSClient/SceneDelegate.swift** — removed handleScaleCloudConfigURL() method
- [x] **ScaleCloudRenew/Sources/Setup/SetupCoordinator.swift** — added debugger detection + debug channel handoff flow
- [x] **ScaleCloudRenew/Sources/Utilities/UserDefaults+Setup.swift** — removed pre-configuration flags

---

## Testing Checklist

- [ ] Test isDebuggerAttached() returns true when launched via debugger
- [ ] Test isDebuggerAttached() returns false on normal launch
- [ ] Test Secure Enclave key pair generation (iOS device required - Secure Enclave unavailable in Simulator)
- [ ] Test public key export to stdout
- [ ] Test stdin blocking read
- [ ] Test ECIES decryption of password blob
- [ ] Test Keychain storage of decrypted password
- [ ] Test UserDefaults storage of email and Anisette URL
- [ ] Test full debug channel flow end-to-end with computer-side installer
- [ ] Test fallback to manual credential entry when debugger not attached
- [ ] Test fallback to manual credential entry when debug handoff fails

---

## Implementation Summary

**Date**: 2024

**Key Changes**:
- ✅ Removed URL scheme-based credential handoff (scalecloud:// scheme)
- ✅ Implemented Secure Enclave ECIES encryption for credential transmission
- ✅ Added debugger detection using sysctl P_TRACED flag
- ✅ Created debug channel protocol using stdin/stdout with sentinel markers
- ✅ Password encrypted on computer using public key, decrypted inside Secure Enclave on device
- ✅ Credentials stored directly to Keychain, never written to filesystem
- ✅ Setup flow automatically starts with validation when credentials received via debug channel
- ✅ Fallback to manual credential entry when debugger not attached or handoff fails

### Computer-Side Implementation Requirements

The computer-based installer must implement the following protocol:

1. Launch app via debugserver/lldb over USB
2. Listen for `SCALECLOUD_PUBKEY:<base64>` on stdout
3. Wait for `SCALECLOUD_PUBKEY_READY` sentinel
4. Parse public key from Base64
5. Encrypt user's Apple ID password using P-256 ECIES with public key
6. Send to stdin: `SCALECLOUD_PASSWORD:<base64_encrypted_password>`
7. Send to stdin: `SCALECLOUD_APPLEID:<email>`
8. Send to stdin: `SCALECLOUD_ANISETTE:<url>` (optional)
9. Send to stdin: `SCALECLOUD_PAYLOAD_COMPLETE`
10. Wait for `SCALECLOUD_CREDENTIALS_OK` confirmation on stdout
11. Close debug session

**Security Model**:
- Private key never leaves Secure Enclave chip
- Decryption happens inside Secure Enclave hardware
- Plaintext password only exists briefly in app memory (Swift String)
- Credentials immediately stored to iOS Keychain
- Debug channel only accessible via USB (not network)
- Computer-side script should wipe sensitive data after transmission

---

## Status: ✅ COMPLETE

**Next Phase**: Phase 10 - Testing (requires Phase 8 xcframework build first)
