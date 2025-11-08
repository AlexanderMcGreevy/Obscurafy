# Fix Build Errors - Complete Guide

## Current Errors

```
lstat(...VaultEye.abi.json): No such file or directory
lstat(...VaultEye.swiftdoc): No such file or directory
lstat(...VaultEye.swiftmodule): No such file or directory
lstat(...VaultEye.swiftsourceinfo): No such file or directory
```

## Root Cause

These errors occur when Xcode's build cache gets corrupted or out of sync. The build system is looking for intermediate build files that don't exist yet.

## ✅ Solution (Step-by-Step)

### 1. Clean Everything in Xcode

**In Xcode:**
1. Open VaultEye.xcodeproj
2. Select **Product → Clean Build Folder** (or press `Cmd+Shift+K`)
3. Wait for it to complete
4. Close Xcode completely (Cmd+Q)

### 2. Clean Derived Data (Already Done)

I've already cleaned your DerivedData. But if you need to do it again:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/VaultEye-*
```

Or in Xcode:
- **Xcode → Settings → Locations tab**
- Click the arrow next to DerivedData path
- Delete the VaultEye folder

### 3. Reset Package Caches (if using SPM)

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
rm -rf ~/Library/Caches/org.swift.swiftpm
```

### 4. Verify Simulator Selection

**In Xcode:**
1. At the top, check the device selector (next to Play/Stop buttons)
2. Make sure you're targeting a valid simulator
3. Recommended: **iPhone 16** or **iPhone 15 Pro**
4. Make sure it says "iOS 16.0" or later

### 5. Rebuild from Scratch

**In Xcode:**
1. Reopen VaultEye.xcodeproj
2. Select a simulator from the device dropdown
3. Press `Cmd+B` to build
4. The first build will take longer as it creates fresh build artifacts

## Alternative: Build from Command Line

If Xcode UI isn't working:

```bash
cd /Users/alexandermcgreevy/Documents/GitHub/HackUMass/VaultEye

# Build for simulator
xcodebuild \
  -project VaultEye.xcodeproj \
  -scheme VaultEye \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  clean build
```

## If Errors Persist

### Check Build Settings

1. Open VaultEye.xcodeproj in Xcode
2. Select VaultEye target
3. Go to **Build Settings** tab
4. Search for "Architectures"
5. Verify:
   - **Architectures**: `$(ARCHS_STANDARD)`
   - **Valid Architectures**: Should include `x86_64` and `arm64`
   - **Build Active Architecture Only**:
     - Debug: `Yes`
     - Release: `No`

### Exclude Architectures for Simulator

If building for simulator still fails:

1. Build Settings → search "Excluded Architectures"
2. For "Any iOS Simulator SDK":
   - Add `arm64` if on Intel Mac
   - Add `x86_64` if on Apple Silicon Mac
   - In your case (x86_64 Mac), you shouldn't need exclusions

### Reset Xcode

Last resort:

```bash
# Close Xcode first, then:
defaults delete com.apple.dt.Xcode
rm -rf ~/Library/Developer/Xcode/UserData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
```

Then restart Xcode and try building again.

## Verification Steps

After cleaning and rebuilding, you should see:

1. **Build Succeeded** in Xcode
2. No lstat errors
3. All Swift files compile without errors
4. App launches in simulator

## Expected Build Output

Successful build will show:
```
▸ Compiling VaultEyeApp.swift
▸ Compiling ContentView.swift
▸ Compiling BackgroundScanManager.swift
... (all other Swift files)
▸ Linking VaultEye
▸ Signing VaultEye
Build succeeded
```

## Common Issues

### "Command PhaseScriptExecution failed"
- Clean and rebuild
- Check for script build phases with errors

### "Code signing failed"
- Go to Signing & Capabilities
- Make sure "Automatically manage signing" is checked
- Select your development team

### "Module not found"
- Clean derived data
- Rebuild

## Next Steps After Successful Build

1. ✅ Build succeeds with no errors
2. ✅ Run app in simulator (Cmd+R)
3. ✅ Test all three tabs: Photos, Background Scan, Matched
4. ✅ Grant permissions when prompted
5. ✅ Test background scan functionality

## Quick Checklist

- [ ] Closed Xcode completely
- [ ] Cleaned build folder (Cmd+Shift+K)
- [ ] Deleted DerivedData
- [ ] Reopened Xcode
- [ ] Selected valid simulator
- [ ] Built project (Cmd+B)
- [ ] Build succeeded

If you've done all these steps and still get errors, there may be an issue with your Xcode installation or the project file itself.

## Emergency: Start Fresh Build

If nothing works, this nuclear option resets everything:

```bash
#!/bin/bash
# Save this as reset_xcode.sh and run it

echo "🧹 Nuclear clean of Xcode for VaultEye..."

# Close Xcode
killall Xcode 2>/dev/null || true
sleep 2

# Clean everything
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*/Symbols/System/Library/Caches
rm -rf ~/Library/Developer/Xcode/Products
rm -rf build

echo "✅ Clean complete!"
echo "Now open Xcode and build (Cmd+B)"
```

Run with: `bash reset_xcode.sh`

---

**The errors you're seeing are normal after adding new files or major changes. A clean build should resolve them.** 🚀
