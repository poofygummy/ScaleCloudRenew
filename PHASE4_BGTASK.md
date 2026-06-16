# Phase 4: BGTaskScheduler Integration

**Status**: Complete (ready for testing)
**Goal**: Daily background check + foreground fallback for signing refresh

## SideStore Context

SideStore uses:
- Deprecated `UIBackgroundModes: fetch` + `application(_:performFetchWithCompletionHandler:)`
- Silent audio playback trick (BackgroundTaskManager) to extend execution time
- Manual Siri Shortcuts as fallback

We use modern BGTaskScheduler instead (deprecated API will die eventually).

## Task Identifier

- `com.scalecloud.refresh` - BGProcessingTask (daily check, runs signing if < 4 days to expiry)
  - Uses BGProcessingTask instead of BGAppRefreshTask to avoid 30-second limit
  - Requires network connectivity for signing operation
  - Can run as long as needed

## Implementation Status

### Completed in Phase 3
- [x] AppDelegate+SigningRefresh.swift created
- [x] AppOperationCoordinator.swift created with isRefreshNeeded() (< 4 days check)
- [x] State machine integration
- [x] Coordinator certificate expiry storage

### Completed in Phase 4

#### Info.plist
- [x] Add BGTaskSchedulerPermittedIdentifiers array
- [x] Add com.scalecloud.refresh identifier
- [x] Remove com.scalecloud.sign identifier (not used)

#### Background Task
- [x] Implement registerSigningBackgroundTasks() - single BGProcessingTask
- [x] Implement handleDailyRefreshCheck() - checks < 4 days, runs signing if needed
- [x] Implement scheduleDailyRefreshCheck() - BGProcessingTaskRequest for 24 hours later
- [x] Set requiresNetworkConnectivity = true
- [x] Set requiresExternalPower = false
- [x] Handle task expiration with rescheduling
- [x] Reschedule after completion (success or failure)
- [x] Initial schedule call in registerSigningBackgroundTasks()

#### Foreground Fallback (PRIMARY)
- [x] Add check in applicationDidBecomeActive(_:)
- [x] Check coordinator.isRefreshNeeded() (< 4 days to expiry)
- [x] If yes && idle: trigger immediate refresh
- [x] Log foreground refresh triggers
- [x] Import ScaleCloudRenew + AltStoreCore in AppDelegate
- [x] Reschedule daily check after foreground refresh

#### Coordinator
- [x] Update isRefreshNeeded() to check < 4 days (was 3 days)

#### Testing (Deferred - requires apps from Phase 6/7)
- [ ] Test Xcode BGTask simulation
- [ ] Verify daily rescheduling
- [ ] Verify expiration handling
- [ ] Test foreground fallback on app activation
- [ ] Monitor iOS delays (tasks may not fire for hours/days)

## Architecture

**Daily background check**:
- BGProcessingTask scheduled every 24 hours
- Checks if < 4 days until certificate expiry
- If yes: runs full signing operation (no 30-second limit)
- If no: just reschedules for next day
- iOS may delay task by hours/days (unreliable)

**Foreground fallback (PRIMARY)**:
- Every app activation checks < 4 days to expiry
- Immediately triggers signing if needed
- Guaranteed execution when user opens app
- Mitigates BGTask unreliability

## Files

### Modified
- AppDelegate.swift - coordinator init, registerSigningBackgroundTasks() call

### Created (Phase 3)
- AppDelegate+SigningRefresh.swift - all BGTask handlers
- AppOperationCoordinator.swift - state machine

### Modified (Phase 4)
- ScaleCloudApp/Brand/iOSClient.plist - added com.scalecloud.refresh/sign identifiers
- AppDelegate.swift - added applicationDidBecomeActive foreground fallback

## Testing Commands

```bash
# Trigger daily refresh check
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.scalecloud.refresh"]
```

## Completion Criteria

- [x] Info.plist updated (removed unused identifier)
- [x] Background task registered (single task)
- [x] Daily scheduling implemented
- [x] Foreground fallback implemented
- [x] Coordinator updated to 4-day threshold
- [ ] BGTask simulation tested (requires actual apps - Phase 6/7)
- [ ] Daily rescheduling verified (requires actual apps - Phase 6/7)

## Implementation Complete

Phase 4 is complete. Testing requires actual installed apps from Phase 6/7.

## Next: Phase 5

Credential Storage - Apple ID, certificates, profiles in Keychain
