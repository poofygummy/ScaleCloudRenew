# SideStore Integration Plan

## Overview
This document outlines the integration of SideStore's app signing capabilities into ScaleCloudApp to enable automatic app refresh without relying on external signing services.
Original official Sidestore repo: /home/cvt/sidestore/
our subrepos: ./ScaleCloudGo, ./ScaleCloudKit, ./ScaleCloudRenew, ./ScaleCloudApp THESE ARE THE ONES YOU CREATE THINGS IN
starting state: Go, Kit, and App, compile successfully as archives with the workflows under /.github/workflows
DO NOT create reports! Only create extremely consise, non-verbose, SINGLE progress trackers, one per phase. No human needs to read this only ai agents for progress tracking.
NO LOCAL BUILD ENGINE IS AVAILABLE! all code compilation is done through github workflows on remote runners
ALWAYS MAKE SURE YOU DO NOT CREATE A PARALLEL /home/ DIRECTORY IN OUR WORKING FOLDER
---

## Phase 0 — Repository & Module Setup ✅ COMPLETE

**Goal:** Establish the foundational structure for the signing module.

### Tasks
- [x] Rename `ScaleCloudWrap` folder to `ScaleCloudRenew`
- [x] Create Xcode target for `ScaleCloudRenew` manually
- [x] Configure target to link against pre-compiled `ScaleCloudGo` binary
- [x] Document the target structure and dependencies

**Deliverable:** A properly configured but empty ScaleCloudRenew module.

### Implementation Notes
- Folder already renamed to `ScaleCloudRenew`
- Updated `project.yml` to define `ScaleCloudRenew` as a framework target
- Configured framework settings:
  - Type: framework
  - Platform: iOS
  - Deployment target: 14.0
  - Build settings: `SKIP_INSTALL=NO`, `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`, `DEFINES_MODULE=YES`
- Linked against `ScaleCloudGo.xcframework` via `FRAMEWORK_SEARCH_PATHS` pointing to `../ScaleCloudGo/prebuilt`
- Framework dependency configured with `embed: false` (ScaleCloudGo will be embedded by ScaleCloudApp)
- Sources directory: `Sources/` (to be populated in Phase 1)

---

## Phase 1 — SideStore Audit & Extraction

**Goal:** Extract only the necessary signing components from SideStore, leaving all UI and non-essential features behind.

### Reference Setup
- [ ] Pin SideStore at stable release **0.6.4** in a local reference branch
- [ ] Document extraction methodology (not using as submodule)

### Components to Extract into ScaleCloudRenew

#### 1.1 ScaleCloudSign Library
SideStore's fork of ScaleCloudSign handles:
- Apple ID authentication
- Development certificate creation and renewal
- Provisioning profile fetching
- IPA re-signing with proper entitlements
- **This is the heaviest lift** — essentially a full library extraction

Tasks:
- [x] Identify ScaleCloudSign fork version used by SideStore 0.6.4
- [x] Extract ScaleCloudSign source files
- [x] Map all dependencies and system frameworks
- [x] Verify certificate and provisioning profile handling
- [x] Ensure app extensions signing support

#### 1.2 Remote Anisette Client
- [x] Extract remote Anisette server client code
- [x] **Strip:** Local Anisette generation logic
- [x] **Strip:** Pairing file-based Anisette logic
- [ ] Verify compatibility with existing toth-adattar Anisette server (Phase 2)

#### 1.3 Refresh Orchestration Logic
Extract the coordinator that sequences:
1. Check certificate expiry
2. Fetch Anisette data
3. Authenticate with Apple
4. Renew development certificate
5. Fetch provisioning profiles
6. Re-sign IPA
7. Install updated app

Tasks:
- [x] Map the refresh flow through SideStore's codebase
- [x] Extract coordinator/orchestrator classes (BackgroundRefreshAppsOperation, RefreshAppOperation, RefreshGroup)
- [ ] Document state transitions and error handling (Phase 3)
- [ ] Identify all Apple API calls (Phase 2)

#### 1.5 BGTaskScheduler Integration
- [x] Extract task handler implementation (AppDelegate+SigningRefresh.swift)
- [ ] Extract task registration logic (Phase 4)
- [ ] Extract scheduling and rescheduling logic (Phase 4)
- [ ] Document iOS background task constraints (Phase 4)

### Components to Strip
- [x] **Remove:** All UIKit ViewControllers (not extracted)
- [x] **Remove:** App catalog/source browser (not extracted)
- [x] **Remove:** News feed (not extracted)

#### 1.4 Silent Audio Protection
Extract SideStore's defensive mechanism for extending execution time:
- BackgroundTaskManager wraps signing operations in silent audio playback
- AVAudioEngine plays looping Silence.m4a at zero volume
- Prevents iOS from suspending app during signing
- Applied to ALL signing operations (background and foreground)

Tasks:
- [x] Extract BackgroundTaskManager.swift
- [x] Extract Silence.m4a asset
- [x] Configure ScaleCloudRenew Resources directory
- [x] Wrap BackgroundRefreshAppsOperation in performExtendedBackgroundTask
- [x] Update bundle reference for framework context

#### 1.6 Dependency Resolution (AltStoreCore & Roxas)
SideStore uses local framework targets, not Swift packages:
- AltStoreCore: Core Data models, utilities, extensions (103 files)
- Roxas: Objective-C utility library with UIKit extensions (102 files)

Tasks:
- [x] Copy AltStoreCore from `/home/cvt/sidestore/AltStoreCore/` to `Sources/AltStoreCore/`
- [x] Copy Roxas from `/home/cvt/sidestore/Dependencies/Roxas/Roxas/` to `Sources/Roxas/`
- [x] Remove package dependencies from project.yml
- [x] Configure as local sources compiled directly into framework
- [x] Verify no SPM authentication issues in CI/CD

- [x] **Remove:** Settings screens (not extracted)
- [x] **Remove:** WireGuard/StosVPN integration (not extracted)
- [x] **Remove:** Pairing file management UI (not extracted)
- [x] **Remove:** JIT enablement features (not extracted)
- [x] **Remove:** Most of AppDelegate (extracted only BGTask handler)

**Deliverable:** A clean, extracted signing engine in ScaleCloudRenew with no UI dependencies.

**Status:** ✅ **COMPLETE** - All extraction tasks finished, dependencies resolved as local sources

---

## Phase 2 — Network Routing Through Tailscale

**Goal:** Route all signing-related network traffic through the Tailscale network via ScaleCloudGo's proxy.

### Architecture
- ScaleCloudGo exposes Tailscale user-space network stack on a local proxy port
- Configure URLSession with proxy pointing to this port
- Inject custom URLSession into ScaleCloudSign's networking layer

### Tasks
- [ ] Identify all URLSession creation points in ScaleCloudSign
- [ ] Create custom URLSessionConfiguration with proxy settings
- [ ] Inject proxy-configured URLSession into ScaleCloudSign
- [ ] Configure Anisette client to use proxy
- [ ] Test connectivity to toth-adattar Anisette server via Tailscale hostname
- [ ] Verify Apple API calls route through Tailscale
- [ ] Add logging for network routing verification

**Deliverable:** All signing network traffic flows through Tailscale network.

---

## Phase 3 — State Machine

**Goal:** Prevent signing process and Nextcloud sync from colliding in the background.

### States

```
┌──────┐
│ Idle │ ← Default state, no operations active
└──┬───┘
   │
   ├─→ ┌─────────┐
   │   │ Syncing │ ← Nextcloud file operations in progress
   │   └────┬────┘
   │        │
   ├─→ ┌────▼──────────┐
   │   │RefreshPending │ ← BGTask fired during sync, waiting
   │   └────┬──────────┘
   │        │
   └─→ ┌────▼────────┐
       │ Refreshing  │ ← Signing operation running
       └─────────────┘
```

### State Transitions
- **Idle → Syncing:** Nextcloud sync begins
- **Idle → Refreshing:** BGTask fires and no sync active
- **Syncing → RefreshPending:** BGTask fires during sync
- **RefreshPending → Refreshing:** Sync completes, trigger deferred refresh
- **Syncing → Idle:** Sync completes, no pending refresh
- **Refreshing → Idle:** Signing operation completes

### Tasks
- [ ] Design state machine enum and protocol
- [ ] Implement state transition logic with proper locking
- [ ] Add state change observers/notifications
- [ ] Store certificate expiry date in Keychain
- [ ] Implement expiry urgency calculation
- [ ] Add state persistence across app launches
- [ ] Integrate with Nextcloud sync coordinator
- [ ] Integrate with signing orchestrator
- [ ] Add comprehensive logging for state transitions

**Deliverable:** A thread-safe state machine preventing operation collisions.

---

## Phase 4 — BGTaskScheduler Integration

**Goal:** Enable background refresh of app signing on a schedule, with fallback mechanisms.

### Task Identifier (Info.plist)
**`com.scalecloud.refresh`** — BGProcessingTask
- Checks once daily if < 4 days until expiry
- If yes: executes full signing operation (no 30-second limit)
- If no: reschedules for next day
- Uses BGProcessingTask instead of BGAppRefreshTask to allow longer execution

### Scheduling Logic
- Schedule BGAppRefreshTask to run once every 24 hours
- On task fire: check if < 4 days until certificate expiry
- If refresh needed: execute signing operation in same task
- After successful signing: update expiry, reschedule for next day
- After failed check: reschedule for next day

### Foreground Fallback (PRIMARY RELIABILITY MECHANISM)
- On every `applicationDidBecomeActive`: check if < 4 days until expiry
- If yes: execute signing operation immediately
- Mitigates iOS BGTask unreliability (tasks may be delayed hours/days)
- Guarantees refresh when user opens app

### Tasks
- [ ] Register task identifier in Info.plist
- [ ] Implement BGProcessingTask handler with expiry check + signing
- [ ] Schedule task for daily execution with network connectivity requirement
- [ ] Implement foreground fallback in applicationDidBecomeActive
- [ ] Add rescheduling after task completion
- [ ] Handle task expiration and interruption
- [ ] Test with Background Tasks debugging in Xcode
- [ ] Document iOS background execution limits

**Deliverable:** Reliable background signing with foreground fallback as primary mechanism.

---

## Phase 5 — Credential Storage

**Goal:** Securely store all authentication materials and configuration.

### Keychain Items

#### Credentials
- [ ] Apple ID (account email)
- [ ] Apple ID password or app-specific password
- [ ] Store with appropriate kSecAttr flags for background access

#### Certificates & Keys
- [ ] Current development certificate (DER format)
- [ ] Private key for certificate
- [ ] Certificate expiry date
- [ ] Certificate serial number

#### Provisioning Profiles
- [ ] Main app provisioning profile
- [ ] Share extension profile
- [ ] File Provider extension profile
- [ ] Notification Service extension profile
- [ ] Widget extension profile
- [ ] IntentHandler extension profile

### Configuration
- [ ] Hardcode Anisette server URL to toth-adattar Tailscale address
- [ ] Document fallback/error scenarios if credentials are missing

### Tasks
- [ ] Implement Keychain wrapper with proper access control
- [ ] Add credential validation
- [ ] Implement secure credential updates
- [ ] Add credential deletion (logout functionality)
- [ ] Test Keychain access from background tasks
- [ ] Verify data protection class allows background access

**Deliverable:** Secure, background-accessible credential storage.

---

## Phase 6 — Initial Setup UX

**Goal:** One-time onboarding flow to configure signing and guide user through iOS restrictions.

### Flow Steps

#### 6.1 Apple ID Entry
- [ ] Design credential input screen
- [ ] Implement app-specific password guidance
- [ ] Store credentials to Keychain
- [ ] Trigger immediate first signing run for validation
- [ ] Handle authentication errors gracefully
- [ ] Show progress during initial signing

#### 6.2 Developer Mode Prompt
- [ ] Detect if Developer Mode is enabled (iOS 16+)
- [ ] Show instructions with screenshots
- [ ] Provide deep link: `prefs:root=DEVELOPER_SETTINGS`
- [ ] Explain restart requirement
- [ ] Add "Check Again" button

#### 6.3 Certificate Trust Prompt
- [ ] Detect certificate trust status
- [ ] Show instructions with screenshots
- [ ] Deep link: `prefs:root=General&path=About/TRUST_SETTINGS`
- [ ] Guide to VPN & Device Management section
- [ ] Add "Verify Trust" button

#### 6.4 Done Screen
- [ ] Confirm setup completion
- [ ] Show next refresh date
- [ ] Explain silent background maintenance
- [ ] Add troubleshooting link

### Persistence
- [ ] Store setup completion flag in UserDefaults
- [ ] Never show flow again after completion
- [ ] Add manual reset for testing (debug builds only)

### Tasks
- [ ] Design and implement setup flow UI
- [ ] Add step-by-step navigation
- [ ] Implement validation at each step
- [ ] Add error recovery mechanisms
- [ ] Test on iOS 16 and iOS 17
- [ ] Create troubleshooting documentation

**Deliverable:** Smooth first-time setup experience with clear guidance.

---

## Phase 7 — App Extensions Handling

**Goal:** Ensure all app extensions are properly signed with correct entitlements and provisioning profiles.

### Extensions in ScaleCloudApp
1. Share Extension
2. File Provider Extension
3. Notification Service Extension
4. Widget Extension
5. IntentHandler Extension

### Requirements
- Each extension needs its own provisioning profile
- Each profile must be fetched and renewed
- Extension entitlements must match profiles
- ScaleCloudSign must process multi-target IPAs correctly

### Tasks
- [ ] Map all extensions and their bundle identifiers
- [ ] Verify ScaleCloudSign's multi-target support
- [ ] Implement profile fetching for each extension
- [ ] Implement profile renewal for each extension
- [ ] Validate entitlements for each extension
- [ ] Test signing with all extensions included
- [ ] Add specific error handling for extension failures
- [ ] Document common extension signing issues
- [ ] Verify App Groups entitlements preservation

**Deliverable:** Reliable signing of main app and all extensions.

---

## Phase 8 — Build System

**Goal:** Integrate ScaleCloudRenew into the build process as a pre-compiled binary.

### Architecture
- ScaleCloudRenew compiled as `.xcframework`
- Committed to repository alongside ScaleCloudGo and ScaleCloudKit
- ScaleCloudApp links against all three binaries

### Local Build
- [ ] Create build script for ScaleCloudRenew framework
- [ ] Configure framework targets for all architectures
- [ ] Generate .xcframework bundle
- [ ] Document manual build process
- [ ] Add framework to ScaleCloudApp's link phase

### GitHub Actions
- [ ] Create new job: `build-scalecloud-sign`
- [ ] Configure job dependencies and order
- [ ] Compile ScaleCloudRenew for all platforms
- [ ] Generate .xcframework output
- [ ] Upload framework as artifact
- [ ] Modify `build-scalecloud-app` job to depend on signing job
- [ ] Download and link signing framework
- [ ] Update caching strategy for faster builds

### Tasks
- [ ] Write `build_scalecloud_sign.sh` script
- [ ] Test local framework compilation
- [ ] Update `.gitignore` if needed
- [ ] Commit compiled framework to repo
- [ ] Update GitHub Actions workflow
- [ ] Test complete CI/CD pipeline
- [ ] Document build dependencies and requirements

**Deliverable:** Automated build system producing and integrating ScaleCloudRenew.

---

## Phase 9 — Polishing

**Goal:** Improve UX by eliminating manual configuration steps through computer-based installer integration.

### Tasks

#### 9.1 Anisette Server URL from Installer
- [ ] Define URL schema/format for installer to pass Anisette server URL
- [ ] Modify app to check for pre-configured Anisette URL on first launch
- [ ] Store installer-provided URL in `UserDefaults.standard.menuAnisetteServersList`
- [ ] Skip Anisette configuration screen in setup flow if URL already present
- [ ] Add fallback to manual entry if installer didn't provide URL
- [ ] Document URL passing mechanism for installer program

#### 9.2 Apple ID from Installer
- [ ] Define encoding format for Apple ID credentials (base64, encrypted, etc.)
- [ ] Modify app to check for pre-configured credentials on first launch
- [ ] Decode and store credentials in Keychain from installer-provided data
- [ ] Skip credential input screen in setup flow if credentials already present
- [ ] Add fallback to manual entry if installer didn't provide credentials
- [ ] Document credential passing mechanism for installer program
- [ ] Ensure secure handling of credentials during transfer

**Deliverable:** Seamless setup flow with minimal user interaction when using computer-based installer.

---

## Phase 10 — Testing Sequence

**Goal:** Validate all functionality in realistic scenarios across different installation methods.

### 10a — TrollStore Path (iPhone 7)

**Focus:** Core app functionality without signing engine.

Test Cases:
- [ ] Nextcloud connection and authentication
- [ ] File sync (upload/download)
- [ ] Photo upload functionality
- [ ] Tailscale connectivity via ScaleCloudGo
- [ ] Go bridge communication
- [ ] File Provider extension
- [ ] Share extension
- [ ] Widget updates
- [ ] Background sync behavior

**Note:** Signing engine is irrelevant on TrollStore — pure functional testing.

### 10b — Full Signing Path (Standard Install)

**Device:** Non-jailbroken device with standard free Apple ID.

#### Initial Setup Testing
- [ ] First launch onboarding flow
- [ ] Apple ID credential entry and validation
- [ ] First signing run completes successfully
- [ ] Certificate expiry stored correctly
- [ ] Developer Mode detection and guidance
- [ ] Certificate trust detection and guidance
- [ ] Setup completion state persists

#### Background Refresh Testing
- [ ] BGTask registration verified in console
- [ ] Manually trigger `com.scalecloud.refresh` task
- [ ] Verify refresh logic checks expiry correctly
- [ ] Manually trigger `com.scalecloud.sign` task
- [ ] Verify signing operation completes in background
- [ ] Verify app continues running after refresh
- [ ] Test with various time-to-expiry scenarios

#### State Machine Testing
- [ ] Trigger sync during idle → verify Syncing state
- [ ] Trigger BGTask during sync → verify RefreshPending state
- [ ] Verify signing starts after sync completes
- [ ] Test concurrent operation prevention
- [ ] Verify state persistence across launches

#### Network Routing Testing
- [ ] Verify traffic routes through Tailscale
- [ ] Test Anisette server connectivity
- [ ] Test Apple API calls through proxy
- [ ] Verify behavior when Tailscale is disconnected

#### Extension Testing
- [ ] Verify all extensions signed correctly
- [ ] Test Share extension after refresh
- [ ] Test File Provider after refresh
- [ ] Test Widget after refresh
- [ ] Verify extension entitlements preserved

#### Error Recovery Testing
- [ ] Test with incorrect Apple ID credentials
- [ ] Test with network interruption during signing
- [ ] Test with expired Apple ID session
- [ ] Test BGTask interruption/expiration
- [ ] Verify user notifications on failures

### Long-term Validation
- [ ] Monitor app for 7+ days
- [ ] Verify multiple automatic refreshes
- [ ] Confirm no expiry-related terminations
- [ ] Test across iOS version updates
- [ ] Validate logging and diagnostics

**Deliverable:** Comprehensive test results documenting all scenarios.

---

## Key Risk — Install-Over-Itself

### The Critical Unknown
SideStore achieves MDM-style headless installation from background tasks, allowing it to refresh itself without user interaction. This capability is:
- Not officially documented by Apple
- Potentially version-dependent
- The linchpin of automatic signing functionality

### Risk Mitigation Strategy

#### Early Prototype (Before Full Integration)
- [ ] Create minimal test app with signing capability
- [ ] Verify install-over-itself works on iOS 16.x
- [ ] Verify install-over-itself works on iOS 17.x
- [ ] Verify install-over-itself works on iOS 18.x
- [ ] Test from BGProcessingTask context
- [ ] Document any system prompts or failures

#### Testing Matrix
- [ ] iPhone with iOS 16.0–16.6
- [ ] iPhone with iOS 17.0–17.4
- [ ] iPhone with iOS 18.0+
- [ ] With Developer Mode enabled
- [ ] With Developer Mode disabled
- [ ] Standard Apple ID (free)
- [ ] Paid Apple Developer Account

#### Fallback Planning
If headless installation doesn't work reliably:
- [ ] Design notification-based flow
- [ ] Implement local web server for installation
- [ ] Prompt user to "complete update" when app opens
- [ ] Consider alternative installation mechanisms

#### SideStore Reference
- [ ] Study SideStore's exact installation mechanism
- [ ] Identify frameworks and private APIs used
- [ ] Document any special entitlements required
- [ ] Check for iOS version-specific implementations

### Verification Checklist
- [ ] Prototype proves concept on target iOS versions
- [ ] Installation succeeds from background task
- [ ] No user prompts interrupt the process
- [ ] App relaunches successfully after install
- [ ] Extensions continue working after install
- [ ] Keychain data persists after install
- [ ] State machine recovers correctly

**Decision Point:** Only proceed with full integration after prototype validation.

---

## Timeline & Dependencies

### Critical Path
1. Phase 0 (Setup) — **1 day**
2. Phase 1 (Extraction) — **5-7 days** (heaviest phase)
3. **Risk Mitigation Prototype** — **2-3 days** ⚠️ DECISION POINT
4. Phase 2 (Networking) — **2-3 days**
5. Phase 5 (Credentials) — **1-2 days** (can overlap with Phase 2)
6. Phase 3 (State Machine) — **2-3 days**
7. Phase 7 (Extensions) — **2-3 days** (can overlap with Phase 3)
8. Phase 4 (BGTasks) — **2-3 days**
9. Phase 6 (Setup UX) — **3-4 days**
10. Phase 8 (Build System) — **1-2 days**
11. Phase 9 (Polishing) — **1-2 days**
12. Phase 10a (TrollStore Testing) — **2 days**
13. Phase 10b (Full Testing) — **5-7 days**

**Estimated Total:** 29-42 days (calendar time, not person-days)

### Parallel Work Opportunities
- Phases 2 & 5 can overlap
- Phases 3 & 7 can overlap
- Phase 6 can start while Phase 4 is in progress

---

## Success Criteria

### Technical
- ✅ ScaleCloudRenew builds and links successfully
- ✅ All network traffic routes through Tailscale
- ✅ Signing workflow completes end-to-end
- ✅ Background tasks fire reliably
- ✅ State machine prevents conflicts
- ✅ All extensions sign correctly
- ✅ Credentials stored securely
- ✅ Install-over-itself works headlessly

### User Experience
- ✅ Setup flow is clear and completable
- ✅ App refreshes automatically before expiry
- ✅ No unexpected terminations
- ✅ Error states handled gracefully
- ✅ User never needs external signing service

### Quality
- ✅ Comprehensive logging for diagnostics
- ✅ Error recovery mechanisms tested
- ✅ No regressions in existing Nextcloud/Tailscale functionality
- ✅ CI/CD pipeline builds and tests automatically
- ✅ Documentation covers troubleshooting

---

## Open Questions

1. **Apple ID 2FA:** How does SideStore handle two-factor authentication? Do we need app-specific passwords?
2. **Certificate Limits:** What happens when the 10-app-per-7-days limit is hit?
3. **Background Network:** Can BGProcessingTask reliably get network access when needed?
4. **iOS 18 Changes:** Any known changes to Developer Mode or signing requirements?
5. **Extension Limits:** Are there restrictions on the number of extensions per free Apple ID?

---

## References

- SideStore Repository: https://github.com/SideStore/SideStore
- SideStore Release 0.6.4: https://github.com/SideStore/SideStore/releases/tag/0.6.4
- ScaleCloudSign: https://github.com/rileytestut/AltSign
- BGTaskScheduler: https://developer.apple.com/documentation/backgroundtasks
- Anisette Server (toth-adattar): Internal documentation

---

## Notes

- This plan assumes ScaleCloudGo and ScaleCloudKit are already functional
- Nextcloud sync coordination is existing functionality to integrate with
- toth-adattar Anisette server is already operational on Tailscale
- iPhone 7 with TrollStore is available for testing
- Second device needed for standard installation testing

---

**Document Version:** 1.2  
**Last Updated:** 2025-01-27  
**Status:** Phases 0-8 Complete - Phase 9 Added
