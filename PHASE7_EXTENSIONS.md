# Phase 7: App Extensions Handling - IN PROGRESS

**Goal**: Sign all app extensions with correct provisioning profiles and entitlements

## Tasks

### 7.1 Extension Discovery
- [x] Map ScaleCloudApp extensions and bundle IDs
- [x] Document extension types (Share, FileProvider, NotificationService, Widget, IntentHandler)
- [x] Verify extension entitlements requirements
- [x] Document App Groups shared between main app and extensions

### 7.2 Provisioning Profile Management
- [x] Verify ALTAppID handles extension bundle IDs (supports any bundle ID pattern)
- [x] Verify ALTProvisioningProfile.fetchAllForTeam() returns extension profiles (fetched per AppID)
- [ ] Test profile fetching for extension identifiers
- [ ] Document profile renewal flow for extensions
- [x] Add extension profile storage to Keychain (alongside main app profile)

### 7.3 Multi-Target Signing
- [x] Verify AltSign handles embedded app bundles (Plugins directory) - RefreshAppOperation already handles appExtensions
- [ ] Test ALTSigner.signApp() with extensions present
- [ ] Verify embedded.mobileprovision placement in each extension bundle
- [ ] Test entitlements preservation for each extension
- [ ] Verify code signature validity after signing

### 7.4 Extension-Specific Handling
- [ ] Test Share extension signing and launch
- [ ] Test File Provider extension signing and activation
- [ ] Test Notification Service extension signing and delivery
- [ ] Test Widget extension signing and updates
- [ ] Test IntentHandler extension signing and Siri integration

### 7.5 Error Handling
- [x] Add extension-specific error cases to BackgroundRefreshAppsOperation (already exists in RefreshAppOperation)
- [x] Log extension signing failures separately (already exists in RefreshAppOperation)
- [ ] Add retry logic for extension profile fetch failures
- [ ] Document common extension signing errors

### 7.6 Integration Testing
- [ ] Verify all extensions launch after signing
- [ ] Test App Groups data sharing after signing
- [ ] Verify keychain sharing works after signing
- [ ] Test extension background tasks after signing

## Files to Modify

- [ ] `Sources/Operations/BackgroundRefreshAppsOperation.swift` - Add extension discovery logging
- [x] `Sources/Security/Keychain.swift` - Add extension profile storage
- [x] `Sources/AltSign/Model/ALTAppID.swift` - No changes needed (already supports extensions)
- [x] `Sources/AltSign/Model/ALTProvisioningProfile.swift` - No changes needed (already supports extensions)

## Files to Create

- [x] `Sources/Extensions/ExtensionManager.swift` - Extension discovery and validation
- [x] `Sources/Extensions/ExtensionProfile.swift` - Extension profile model

## Implementation Notes

**Discovery**: RefreshAppOperation already handles extension profiles via `installedApp.appExtensions` and `profiles[bundleIdentifier]` dictionary. The AltStoreCore infrastructure supports multi-target signing out of the box.

**Key Insight**: The signing flow already supports extensions! We need to:
1. Ensure extension AppIDs are registered with Apple Developer portal
2. Fetch provisioning profiles for each extension bundle ID
3. The existing signing code will automatically sign each extension

**Next Steps**: 
1. Verify that extension AppIDs are created and profiles are fetched in the refresh flow
2. The key work is in `AppManager` (from AltStoreCore) which orchestrates:
   - `RegisterAppIDsOperation` - Creates AppIDs for main app + extensions
   - `FetchProvisioningProfilesOperation` - Fetches profiles for all bundle IDs
   - `RefreshAppOperation` - Signs main app + extensions with fetched profiles
3. Current implementation from SideStore already handles this flow
4. Our task: Add logging/monitoring to verify extensions are being signed correctly

## Dependencies

**Required**: Phase 5 (Keychain storage for profiles)  
**Blocks**: Phase 9b (full signing path testing)

## Testing Checklist

- [ ] Main app signs successfully
- [ ] All 7 extensions sign successfully
- [ ] Extensions launch without crashes
- [ ] App Groups entitlements preserved
- [ ] Keychain sharing entitlements preserved
- [ ] Extension background capabilities work
- [ ] No code signature validation errors
- [ ] Install-over-itself preserves extension functionality

## Extension Bundle IDs

**Main App**: `it.twsweb.Nextcloud`

**Extensions** (7 total):
1. **Share Extension**: `it.twsweb.Nextcloud.Share` - Share sheet integration
2. **File Provider Extension**: `it.twsweb.Nextcloud.File-Provider-Extension` - Files app integration
3. **File Provider Extension UI**: `it.twsweb.Nextcloud.File-Provider-Extension-UI` - File picker UI
4. **Notification Service Extension**: `it.twsweb.Nextcloud.Notification-Service-Extension` - Push notifications
5. **Widget Extension**: `it.twsweb.Nextcloud.Widget` - Home screen widgets
6. **WidgetDashboardIntentHandler Extension**: `it.twsweb.Nextcloud.WidgetDashboardIntentHandler` - Widget intents
7. **Action Assistant Extension**: `it.twsweb.Nextcloud.Action-Assistant` - Action extension

**Extension Bundle Path**: `Nextcloud.app/PlugIns/{ExtensionName}.appex`

**Shared Entitlements**:
- **App Group**: `group.it.twsweb.Crypto-Cloud` (all extensions)
- **Keychain Access Group**: `$(AppIdentifierPrefix)it.twsweb.Crypto-Cloud` (Share, others)
- **Network Client**: `com.apple.security.network.client` (Share extension)
- **App Sandbox**: `com.apple.security.app-sandbox` (most extensions)

**Extension-Specific Requirements**:
- File Provider Extension: Requires `com.apple.security.application-groups` for file coordination
- Notification Service Extension: Requires `com.apple.security.app-sandbox` for secure execution
- Widget Extension: Requires `com.apple.security.application-groups` for data sharing
- IntentHandler Extension: Requires `com.apple.security.application-groups` for Siri data access

## Status: IN PROGRESS
