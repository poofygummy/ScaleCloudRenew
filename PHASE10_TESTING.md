# Phase 10: Testing - NOT STARTED

**Goal**: Validate all functionality in realistic scenarios

**Device**: Non-jailbroken with free Apple ID

### Setup Flow (Phase 6 + Phase 9)
- [ ] First launch onboarding
- [ ] Apple ID credential entry
- [ ] First signing completes successfully
- [ ] Certificate expiry stored
- [ ] Developer Mode guidance (iOS 16+)
- [ ] Certificate trust guidance
- [ ] Anisette server connectivity test
- [ ] Setup completion persists

#### Debug Channel Credential Handoff (Phase 9)
**Computer-Side Installer Testing**:
- [ ] Python test script with `eciespy` library
- [ ] Launch app via `ios-deploy` or `debugserver`
- [ ] Capture stdout and parse `SCALECLOUD_PUBKEY:`
- [ ] Encrypt test password using P-256 ECIES
- [ ] Send credential lines to stdin
- [ ] Verify `SCALECLOUD_CREDENTIALS_OK` response
- [ ] Measure round-trip latency
- [ ] Test invalid public key handling
- [ ] Test decryption failure scenarios (wrong key, corrupted data)

**Simulator Testing** (Limited - Secure Enclave unavailable):
- [ ] `DebuggerUtils.isDebuggerAttached()` returns true when launched via Xcode debugger
- [ ] `DebuggerUtils.isDebuggerAttached()` returns false on normal launch
- [ ] Stdin/stdout protocol parsing with mock encrypted data
- [ ] Fallback to manual entry when debugger not attached
- [ ] Fallback to manual entry when handoff fails (invalid data)

**Device Testing** (Required - Secure Enclave only on physical devices):
- [ ] Test on iPhone/iPad with A7+ chip (Secure Enclave availability)
- [ ] `SecureEnclaveManager.generateKeyPair()` succeeds
- [ ] Public key export verification (65 bytes for P-256 uncompressed format)
- [ ] ECIES decryption with real encrypted data
- [ ] Measure handoff latency (key generation + decryption)
- [ ] Test with physical debugserver connection over USB

**Integration Testing**:
- [ ] Full debug channel flow end-to-end with computer-side script
- [ ] Credentials persist to Keychain after handoff
- [ ] Anisette URL persists to UserDefaults after handoff
- [ ] Setup flow auto-completes with pre-configured data (skips credential input screen)
- [ ] ValidationViewController auto-triggers after successful handoff
- [ ] App restart behavior (setup remains completed, credentials accessible)
- [ ] Verify setup coordinator conditional entry point logic

### Background Tasks (Phase 4)
- [ ] BGTask registration verified
- [ ] Trigger `com.scalecloud.refresh` manually: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.scalecloud.refresh"]`
- [ ] Verify < 4 days check logic
- [ ] Verify signing completes in background
- [ ] Verify app survives refresh
- [ ] Verify rescheduling after completion
- [ ] Test foreground fallback (applicationDidBecomeActive)
- [ ] Monitor iOS delays (hours/days)

### State Machine (Phase 3)
- [ ] Sync → verify Syncing state
- [ ] BGTask during sync → verify RefreshPending
- [ ] Verify signing after sync completes
- [ ] Concurrent operation prevention
- [ ] State persistence across launches

### Network Routing (Phase 2)
- [ ] Traffic routes through Tailscale
- [ ] Anisette server connectivity
- [ ] Apple API calls through proxy
- [ ] Behavior when Tailscale disconnected

### Extensions (Phase 7)
- [ ] All 7 extensions sign correctly
- [ ] Share extension works after refresh
- [ ] File Provider works after refresh
- [ ] Notification Service works after refresh
- [ ] Widget works after refresh
- [ ] IntentHandler works after refresh
- [ ] Action Assistant works after refresh
- [ ] App Groups preserved
- [ ] Keychain sharing preserved

### Credentials (Phase 5 + Phase 9)
- [ ] Keychain stores credentials
- [ ] Background access works (.afterFirstUnlock)
- [ ] Certificate expiry parsed from DER
- [ ] Provisioning profiles fetched per-extension
- [ ] Anisette server URL configuration

#### Phase 9: Secure Enclave Integration
- [ ] Transient P-256 key generation in Secure Enclave
- [ ] Private key never leaves Secure Enclave hardware
- [ ] Public key exports as 65-byte X9.63 format
- [ ] ECIES decryption (kSecKeyAlgorithmECIESEncryptionStandardVariableIVX963SHA256AESGCM)
- [ ] Encrypted password decryption success
- [ ] Decrypted password stored to Keychain service `com.scalecloud`
- [ ] Email stored to Keychain (plaintext transmission acceptable)
- [ ] Anisette URL stored to UserDefaults

### Error Handling
- [ ] Incorrect Apple ID credentials
- [ ] Network interruption during signing
- [ ] Expired Apple ID session
- [ ] BGTask expiration/interruption
- [ ] User notifications on failures
- [ ] Certificate renewal failures
- [ ] Profile fetch failures

### Build System (Phase 8)
- [ ] testbuildSCSign.yml completes
- [ ] xcframework created with all architectures
- [ ] testbuildSCApp.yml detects Sign prebuilt
- [ ] Archive build includes all frameworks
- [ ] No duplicate symbols
- [ ] No missing symbols

### Long-term Validation
- [ ] Monitor 7+ days
- [ ] Multiple automatic refreshes
- [ ] No expiry-related terminations
- [ ] Behavior across iOS updates
- [ ] Logging/diagnostics verification

---

## Install-Over-Itself Risk

**Critical unknown**: SideStore achieves headless install from background tasks. NOT officially documented.

### Early Prototype (BEFORE full integration)
- [ ] Create minimal test app with signing
- [ ] Verify install-over-itself iOS 16.x
- [ ] Verify install-over-itself iOS 17.x
- [ ] Verify install-over-itself iOS 18.x
- [ ] Test from BGProcessingTask context
- [ ] Document system prompts/failures

### Testing Matrix
- [ ] iPhone iOS 16.0-16.6
- [ ] iPhone iOS 17.0-17.4
- [ ] iPhone iOS 18.0+
- [ ] Developer Mode enabled
- [ ] Developer Mode disabled
- [ ] Free Apple ID
- [ ] Paid Apple Developer Account

### Fallback Planning
If headless install unreliable:
- [ ] Design notification-based flow
- [ ] Local web server for installation
- [ ] "Complete update" prompt on app open
- [ ] Alternative installation mechanisms

### Verification
- [ ] Prototype proves concept
- [ ] Install succeeds from background task
- [ ] No user prompts interrupt
- [ ] App relaunches after install
- [ ] Extensions work after install
- [ ] Keychain persists after install
- [ ] State machine recovers correctly

**DECISION POINT**: Only proceed after prototype validation

---

## Dependencies

**Requires**:
- Phases 0-8 complete
- testbuildSCSign.yml workflow success
- testbuildSCApp.yml workflow success
- iPhone 7 with TrollStore (9a)
- Non-jailbroken device with free Apple ID (9b)

**Blocks**: App Store submission

---

## Success Criteria

### Technical
- All network traffic routes through Tailscale
- Signing workflow completes end-to-end
- Background tasks fire reliably
- State machine prevents conflicts
- All extensions sign correctly
- Install-over-itself works headlessly

### User Experience
- Setup flow completable
- App refreshes before expiry
- No unexpected terminations
- Error states handled gracefully
- No external signing service needed

### Quality
- Comprehensive logging for diagnostics
- Error recovery tested
- No regressions in Nextcloud/Tailscale
- CI/CD pipeline builds successfully
- Troubleshooting documented
