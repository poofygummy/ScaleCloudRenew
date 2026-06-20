# Phase 2: Network Routing - COMPLETE

**Goal**: Route signing traffic through shared Tailscale proxy

## Completed

### 2.1 Strip UI Dependencies ✅
- [x] Remove UIKit from FetchAnisetteDataOperation.swift
- [x] Remove UIKit from BackgroundRefreshAppsOperation.swift
- [x] Auto-accept V1 anisette servers (headless)

### 2.2 Strip minimuxer/em_proxy ✅
- [x] Remove minimuxer/em_proxy/autoMounter from BackgroundRefreshAppsOperation.swift
- [x] Remove notification scheduling

### 2.3 Inject Tailscale Proxy ✅
- [x] Use SCKSession.applyProxySettings() (shared with ScaleCloudKit)
- [x] Use SCKSession.registerSession() for lifecycle tracking
- [x] ALTAppleAPI uses shared proxy
- [x] FetchAnisetteDataOperation uses shared proxy
- [x] Single Tailscale node instance across both modules

## Implementation

**Shared proxy lifecycle**: ScaleCloudRenew depends on ScaleCloudKit framework and uses its static proxy management methods:
- `SCKSession.applyProxySettings()` - Returns proxy dict, starts proxy on first call
- `SCKSession.registerSession(URLSession)` - Registers session for lifecycle tracking
- Single Tailscale node at `Application Support/tailscale` with hostname `"ios-scalecloud-client"`
- Weak reference tracking + 60s cleanup timer
- Proxy stops when all sessions (from both modules) are released

**Files modified**:
- `project.yml` - Added ScaleCloudKit dependency
- `ScaleCloudKit/Sources/ScaleCloudKit/SCKSession.swift` - Made applyProxySettings() and registerSession() public
- `Sources/Anisette/FetchAnisetteDataOperation.swift` - UI stripped, uses SCKSession proxy
- `Sources/Operations/BackgroundRefreshAppsOperation.swift` - UI/minimuxer stripped
- `Sources/AltSign/AppleAPI/ALTAppleAPI.m` - Uses SCKSession proxy

## Next: Phase 3 (State Machine)
