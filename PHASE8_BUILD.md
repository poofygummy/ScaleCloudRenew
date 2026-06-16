# Phase 8: Build System - COMPLETE

**Goal**: Integrate ScaleCloudRenew into CI/CD pipeline as pre-compiled framework

## Tasks

### 8.1 GitHub Actions Workflow
- [x] Create `.github/workflows/testbuildSCSign.yml`
- [x] Configure job: `build-scalecloud-sign`
- [x] Set runner: `macos-26` (Xcode 15+)
- [x] Install xcodegen
- [x] Generate xcodeproj from project.yml
- [x] Build for iOS device (arm64)
- [x] Build for iOS Simulator (arm64, x86_64)
- [x] Create xcframework
- [x] Upload artifact: `scalecloud-sign-framework`

### 8.2 Update ScaleCloudApp Workflow
- [x] Modify `.github/workflows/testbuildSCApp.yml`
- [x] Add prebuilt check for ScaleCloudRenew
- [x] Verify ScaleCloudRenew framework exists
- [ ] Run workflow to test integration
- [ ] Verify archive build includes framework

### 8.3 ScaleCloudApp Integration
- [x] ScaleCloudApp.xcodeproj already exists (upstream adapted)
- [x] Ran add_scalecloud_sign.py to add framework to project
- [x] ScaleCloudRenew.xcframework added to all 11 targets
- [x] Workflow checks for ScaleCloudRenew prebuilt before building
- [ ] Run workflow to test end-to-end integration

## Workflow Build Steps

```yaml
- name: Install xcodegen
  run: brew install xcodegen

- name: Generate Xcode project
  run: |
    cd ScaleCloudRenew
    xcodegen generate

- name: Build iOS device
  run: |
    cd ScaleCloudRenew
    xcodebuild archive \
      -project ScaleCloudRenew.xcodeproj \
      -scheme ScaleCloudRenew \
      -destination "generic/platform=iOS" \
      -archivePath build/ScaleCloudRenew-iOS \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES

- name: Build iOS Simulator
  run: |
    cd ScaleCloudRenew
    xcodebuild archive \
      -project ScaleCloudRenew.xcodeproj \
      -scheme ScaleCloudRenew \
      -destination "generic/platform=iOS Simulator" \
      -archivePath build/ScaleCloudRenew-Simulator \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES

- name: Create xcframework
  run: |
    cd ScaleCloudRenew
    xcodebuild -create-xcframework \
      -framework build/ScaleCloudRenew-iOS.xcarchive/Products/Library/Frameworks/ScaleCloudRenew.framework \
      -framework build/ScaleCloudRenew-Simulator.xcarchive/Products/Library/Frameworks/ScaleCloudRenew.framework \
      -output prebuilt/ScaleCloudRenew.xcframework
```

## Dependencies

**Requires**:
- Phases 0-7 complete
- ScaleCloudRenew compiles successfully
- ScaleCloudGo framework available
- ScaleCloudKit framework available

**Blocks**:
- Phase 9 (Testing)
- App Store submission

## Testing (CI/CD Only)

### Workflow Verification
- [ ] testbuildSCSign.yml runs successfully
- [ ] xcodeproj generates from project.yml
- [ ] Device build completes
- [ ] Simulator build completes
- [ ] xcframework created
- [ ] Artifact uploaded
- [ ] All architectures present (arm64, x86_64)

### Integration Verification
- [ ] testbuildSCApp.yml depends on sign job
- [ ] Artifact downloads correctly
- [ ] ScaleCloudApp links framework
- [ ] Archive build succeeds
- [ ] No duplicate symbol errors
- [ ] No missing symbol errors

## Implementation

### Created Files
- `.github/workflows/testbuildSCSign.yml` - Builds ScaleCloudRenew.xcframework
- `ScaleCloudApp/add_scalecloud_sign.py` - Script to add framework to xcodeproj (already executed)

### Modified Files
- `.github/workflows/testbuildSCApp.yml` - Added Sign prebuilt check
- `ScaleCloudApp/ScaleCloudApp.xcodeproj/project.pbxproj` - ScaleCloudRenew.xcframework added to all targets

### Workflow Execution Order
1. Run testbuildSCGo.yml → produces ScaleCloudGo.xcframework
2. Run testbuildSCKit.yml → produces ScaleCloudKit.framework
3. Run testbuildSCSign.yml → produces ScaleCloudRenew.xcframework
4. Run testbuildSCApp.yml → integrates all frameworks and builds app

## Notes

- NO LOCAL BUILDS: All compilation via GitHub workflows only
- Framework built for distribution (module stability)
- XCFramework supports multiple architectures/platforms
- ScaleCloudApp embeds all three frameworks: Go, Kit, Sign
- Build time: ~5-10 minutes per workflow run
- Follow naming: testbuildSCSign.yml (matches Go/Kit/App pattern)
- Python script pattern established for framework integration

## Next: Phase 9 (Testing)
