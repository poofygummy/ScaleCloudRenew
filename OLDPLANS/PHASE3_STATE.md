# Phase 3: State Machine - COMPLETE

**Goal**: Prevent signing process and Nextcloud sync from colliding in background

## Architecture

### State Enum
```swift
enum AppOperationState {
    case idle
    case syncing          // Nextcloud file operations active
    case refreshPending   // BGTask fired during sync, deferred
    case refreshing       // Signing operation running
}
```

### State Manager Location
`/ScaleCloudApp/iOSClient/AppOperationCoordinator.swift`
- Singleton shared instance
- Thread-safe with NSLock
- NotificationCenter state change broadcasts
- State persistence via UserDefaults + Keychain

### State Transitions
- `idle → syncing`: ScaleCloudKit sync begins
- `idle → refreshing`: BGTask fires, no sync active
- `syncing → refreshPending`: BGTask fires during sync
- `refreshPending → refreshing`: Sync completes, execute deferred refresh
- `syncing → idle`: Sync completes, no pending refresh
- `refreshing → idle`: Signing operation completes

## Tasks

### 3.1 Core State Machine ✅
- [x] Create `AppOperationCoordinator.swift` in ScaleCloudApp/iOSClient
- [x] Implement state enum and properties
- [x] Implement transition methods with validation
- [x] Add NSLock for thread safety
- [x] Add state change NotificationCenter notifications
- [x] Add comprehensive logging for all transitions

### 3.2 State Persistence ✅
- [x] Store current state in UserDefaults
- [x] Store certificate expiry date in Keychain (ISO8601 string)
- [x] Implement state restoration on app launch
- [x] Handle stale state recovery (if crashed during operation)

### 3.3 Certificate Expiry Tracking ✅
- [x] Add Keychain storage for expiry date
- [x] Implement expiry urgency calculation (days until expiry)
- [x] Add method to check if refresh needed (< 3 days until expiry)
- [x] Update expiry date after successful signing

### 3.4 ScaleCloudApp Sync Integration ✅
- [x] Identify sync start/end points (NCService.synchronize)
- [x] Call coordinator on sync begin: `attemptTransition(to: .syncing)`
- [x] Call coordinator on sync end: handle refreshPending or idle
- [x] Execute deferred refresh when transitioning refreshPending → refreshing

### 3.5 ScaleCloudRenew Integration ✅
- [x] Update BackgroundRefreshAppsOperation with callback pattern
- [x] Add `refreshCompletionHandler` property
- [x] Report success/failure and certificate expiry to caller
- [x] Remove direct coordinator dependency (called by ScaleCloudApp BGTask handlers)

### 3.6 BGTask Handlers ✅
- [x] Create `AppDelegate+SigningRefresh.swift`
- [x] Implement `handleRefreshCheckTask` (BGAppRefreshTask)
- [x] Implement `handleSigningTask` (BGProcessingTask)
- [x] Implement `executeSigningOperation` with coordinator state checks
- [x] Handle deferred refresh when sync active
- [x] Update certificate expiry after successful refresh
- [x] Implement `scheduleNextRefreshCheck`
- [x] Register tasks in AppDelegate.didFinishLaunchingWithOptions
- [x] Initialize coordinator early in app lifecycle

## Implementation

**Files created**:
- `AppOperationCoordinator.swift` (258 lines) - state machine singleton
- `AppDelegate+SigningRefresh.swift` (186 lines) - BGTask handlers

**Files modified**:
- `NCService.swift` - sync start/end integration
- `AppDelegate.swift` - initialization + task registration
- `BackgroundRefreshAppsOperation.swift` - callback pattern

**Coordinator API**:
```swift
class AppOperationCoordinator {
    static let shared: AppOperationCoordinator
    var currentState: AppOperationState { get }
    func attemptTransition(to: AppOperationState) -> Bool
    func canStartRefresh() -> Bool
    func deferRefresh(completion: @escaping (Bool) -> Void)
    func setCertificateExpiry(_ date: Date)
    func getCertificateExpiry() -> Date?
    func daysUntilExpiry() -> Int?
    func isRefreshNeeded() -> Bool
}
```

**BGTask identifiers** (need Info.plist):
- `com.scalecloud.refresh` (BGAppRefreshTask)
- `com.scalecloud.sign` (BGProcessingTask)

**State persistence**:
- Current state: UserDefaults `"appOperationState"`
- Certificate expiry: Keychain `"com.scalecloud.cert.expiry"` (ISO8601)
- Stale states reset to `.idle` on launch

**Integration flow**:
1. NCService.synchronize() → coordinator.attemptTransition(.syncing)
2. BGTask fires → handler checks coordinator.canStartRefresh()
3. If syncing → coordinator.deferRefresh() queues operation
4. Sync completes → coordinator transitions to .refreshing, executes deferred
5. Operation completes → reports success + expiry via callback
6. Coordinator updates Keychain, transitions to .idle, schedules next check

## Known Limitations

**InstalledApp placeholder**: BGTask handlers use empty array. Phase 6 will populate from ScaleCloudApp database.

**Certificate expiry hardcoded**: BackgroundRefreshAppsOperation uses +7 days. Phase 4/5 will extract actual expiry from signed certificate.

**Info.plist required**:
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.scalecloud.refresh</string>
    <string>com.scalecloud.sign</string>
</array>
```

## Next: Phase 5 (Credential Storage)
