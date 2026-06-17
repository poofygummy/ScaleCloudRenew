# Phase 1: Extraction Complete

**Status**: All bridge files extracted - Ready for build test
**Files**: 65 extracted + ldid source tree + corecrypto headers + Silence.m4a asset + 102 Roxas files + 103 AltStoreCore files

## Source
- SideStore 0.6.4: `/home/cvt/sidestore/`
- ScaleCloudSign: `a48493283bd676ad3a4d5b65dc7c039cebf7749e`
- ldid: Full source copied to `Sources/AltSign/ldid/`
- corecrypto: Headers copied to `Sources/AltSign/corecrypto/`

## Extracted (Local - Modified)

### ScaleCloudSign (40+ files)
`Sources/AltSign/` - URLSession proxy injection needed

### Anisette (1 file)
`Sources/Anisette/FetchAnisetteDataOperation.swift` - Strip UI, inject proxy

### Operations (3 files)
`Sources/Operations/` - Strip minimuxer/em_proxy/UI

### Utilities (2 files)
`Sources/Utilities/BackgroundTaskManager.swift` - Silent audio protection during signing

### Resources (1 asset)
`Resources/Silence.m4a` - Silent audio file for background execution extension

## Dependencies

### SPM Package: Starscream
WebSocket for Anisette V3 - Public package dependency

### Local Sources: Roxas (102 files)
Riley Testut utilities (ResultOperation, data sources, UI helpers)
Copied from `/home/cvt/sidestore/Dependencies/Roxas/Roxas/` to `Sources/Roxas/`
- Objective-C utility library with UIKit extensions
- File count includes .h/.m pairs, .xib files
- No package manager dependency - compiled directly into framework

### Local Sources: AltStoreCore (103 files)
CoreData models (InstalledApp, DatabaseManager, RefreshAttempt), extensions, types
Copied from `/home/cvt/sidestore/AltStoreCore/` to `Sources/AltStoreCore/`
- Swift framework with Core Data models and utilities
- Includes .xcdatamodeld directories with multiple model versions
- No package manager dependency - compiled directly into framework

**Rationale**: Original SideStore uses these as local framework targets, not Swift packages. The GitHub repositories (rileytestut/Roxas, SideStore/AltStoreCore) are either private or inaccessible, causing SPM fetch failures in CI/CD workflows. Copying as local sources matches SideStore's architecture and avoids authentication issues.

## ldid Resolution
✅ Full source tree copied to `Sources/AltSign/ldid/`
- ldid.cpp (115KB)
- ldid.hpp
- lookup2.c, sha1.h
- libplist/ (entire directory)

Build settings configured in project.yml

## corecrypto Resolution
✅ Headers copied from `/home/cvt/sidestore/Dependencies/AltSign/Dependencies/corecrypto/`
- `Sources/AltSign/corecrypto/include/corecrypto/` - SRP crypto headers (ccsrp.h, ccsha2.h, etc.)
- `Sources/AltSign/corecrypto/include/module.modulemap` - CoreCrypto module
- Used by GSAContext.swift for Apple authentication
- Added to HEADER_SEARCH_PATHS in project.yml


# ADDENDUM -------------------------------

# Phase 1 Addendum: Silent Audio Protection

**Status**: Complete  
**Integration**: BackgroundRefreshAppsOperation  

## Overview

SideStore uses a defensive mechanism to extend execution time during signing operations: silent audio playback. This protection is now integrated into ScaleCloudRenew as part of Phase 1 extraction.

## Mechanism

**AVAudioEngine** plays a looping silent audio file (Silence.m4a) at zero volume. This:
- Extends app execution time beyond normal background limits
- Prevents iOS from suspending the app during signing
- Works in both foreground and background contexts

**Critical Architecture Point**: The signing operation itself (`BackgroundRefreshAppsOperation`) includes this protection. The calling context (BGTask vs foreground) doesn't matter — the operation is always protected.

## Implementation

### Files Extracted

**`Sources/Utilities/BackgroundTaskManager.swift`** (from `/home/cvt/sidestore/AltStore/Components/BackgroundTaskManager.swift`)
- Singleton manager for silent audio lifecycle
- `performExtendedBackgroundTask()` wraps operations in audio protection
- Modified bundle lookup for framework context

**`Resources/Silence.m4a`** (from `/home/cvt/sidestore/AltStore/Resources/Silence.m4a`)
- Silent audio file played in loop
- Zero-volume playback (.mixWithOthers audio session)

### Integration Points

**`BackgroundRefreshAppsOperation.swift`**:
```swift
override func main() {
    // Wrap entire signing operation in silent audio
    BackgroundTaskManager.shared.performExtendedBackgroundTask { (taskResult, taskCompletionHandler) in
        // ... perform signing ...
        group.completionHandler = { (results) in
            taskCompletionHandler()  // Stop audio after signing
            self.finish(.success(results))
        }
    }
}
```

**Called from**:
- `AppDelegate+SigningRefresh.swift`: BGProcessingTask handler
- `AppDelegate.swift`: Foreground fallback (applicationDidBecomeActive)

Both paths execute the same protected operation.

## Build Configuration

**`project.yml`**:
```yaml
sources:
  - path: Sources
  - path: Resources
    type: folder
    buildPhase: resources
```

Resources directory includes Silence.m4a as bundle resource.

## Technical Details

**Audio Session Configuration**:
- Category: `.playback`
- Options: `.mixWithOthers` (doesn't interrupt other audio)
- Volume: 0.0 (silent)

**Looping Logic**:
- Two buffers scheduled initially
- Each buffer completion reschedules itself
- Continues until `taskCompletionHandler()` called

**Thread Safety**:
- Operations run on dedicated `DispatchQueue` (`com.scalecloud.BackgroundTaskManager`)
- Prevents audio engine race conditions

## Testing Notes

- Audio protection applies regardless of foreground/background state
- No user-visible or audible impact
- Error handling: if audio fails to start, signing operation aborts safely
- Completion handler MUST be called to stop audio (prevents battery drain)

## Phase 1 Status Update

**Original extraction**: 47 files + ldid  
**Updated extraction**: 49 files + ldid + Silence.m4a  

**New files**:
- `Sources/Utilities/BackgroundTaskManager.swift`
- `Resources/Silence.m4a`

**Modified files**:
- `Sources/Operations/BackgroundRefreshAppsOperation.swift` (wrapped in audio protection)
- `project.yml` (added Resources build phase)
- `PHASE1_EXTRACTION.md` (updated file count and manifest)
------------------


## Build Configuration Update

**`project.yml`** dependency changes:
- **Removed**: `Roxas` and `AltStoreCore` from `packages:` section
- **Kept**: `Starscream` as only external SPM dependency
- Local sources automatically compiled from `Sources/` directory
- All three dependencies now link directly into ScaleCloudRenew.framework

## Swift Bridge Files (Phase 1 Completion)

### Swift Bridge Files (Operations)
✅ `/home/cvt/sidestore/AltStore/Operations/Operation.swift` → `Sources/Operations/`
✅ `/home/cvt/sidestore/AltStore/Operations/OperationContexts.swift` → `Sources/Operations/`
✅ `/home/cvt/sidestore/Shared/Errors/ALTLocalizedError.swift` → `Sources/AltStoreCore/Extensions/`

### Shared Files (AltStoreCore.h dependencies)
✅ `/home/cvt/sidestore/Shared/ALTConstants.{h,m}` → `Sources/AltStoreCore/Shared/`
✅ `/home/cvt/sidestore/Shared/Categories/NSError+ALTServerError.{h,m}` → `Sources/AltStoreCore/Shared/Categories/`
✅ `/home/cvt/sidestore/Shared/Categories/CFNotificationName+AltStore.{h,m}` → `Sources/AltStoreCore/Shared/Categories/`
✅ `/home/cvt/sidestore/Shared/Connections/ALTConnection.h` → `Sources/AltStoreCore/Shared/Connections/`
✅ `/home/cvt/sidestore/Shared/Errors/ALTWrappedError.{h,m}` → `Sources/AltStoreCore/Shared/Errors/`
✅ `/home/cvt/sidestore/Shared/Errors/UserInfoValue.swift` → `Sources/AltStoreCore/Shared/Errors/`
✅ `/home/cvt/sidestore/Shared/Errors/ProcessError.swift` → `Sources/AltStoreCore/Shared/Errors/`

**File count**: 49 + 3 Swift + 11 Shared = 63 extracted files

## Additional Files Copied

### Critical Missing Files (Now Added)
✅ `/home/cvt/sidestore/AltStore/Operations/AuthenticationOperation.swift` → `Sources/Operations/`
✅ `/home/cvt/sidestore/Shared/Extensions/Bundle+AltStore.swift` → `Sources/AltStoreCore/Extensions/`

### Crypto Headers (Now Added)
✅ `/home/cvt/sidestore/Dependencies/AltSign/Dependencies/corecrypto/` → `Sources/AltSign/corecrypto/`

## Next: Phase 2
- Verify compilation succeeds
- Strip UI from FetchAnisetteDataOperation
- Strip minimuxer/em_proxy from Operations
- Inject Tailscale proxy into URLSession creation points
