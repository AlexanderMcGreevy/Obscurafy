# Fix Entitlements Build Error

## Error Message
```
Build input file cannot be found: '.../VaultEye.entitlements'
Did you forget to declare this file as an output of a script phase or custom build rule which produces it?
```

## The Issue
The VaultEye.entitlements file exists but is not properly added to the Xcode project or the reference is broken.

## Solution 1: Re-add the Entitlements File (Recommended)

1. Open Xcode and select the VaultEye project in the navigator
2. Select the "VaultEye" target
3. Go to the "Signing & Capabilities" tab
4. Look for the "Code Signing Entitlements" field
5. You should see: `VaultEye/VaultEye.entitlements`
6. If it shows a red/missing file:
   - Click the small folder icon next to the field
   - Navigate to and select: `VaultEye/VaultEye.entitlements`
   - Click "Open"

## Solution 2: Add File to Project

If the file isn't in the Xcode project navigator at all:

1. In Finder, locate: `VaultEye/VaultEye.entitlements`
2. Drag it into the Xcode project navigator (into the VaultEye folder)
3. In the dialog:
   - ✅ **DON'T** check "Copy items if needed" (file is already there)
   - ✅ Check "VaultEye" target
   - Click "Finish"

## Solution 3: Remove and Re-create Entitlements

If the above don't work:

1. In Xcode, select the VaultEye target
2. Go to "Signing & Capabilities" tab
3. Clear the "Code Signing Entitlements" field (make it empty)
4. Clean the build folder: `Shift+Cmd+K`
5. Build again: `Cmd+B`
6. If you need entitlements (for push notifications, etc.), Xcode will auto-create them

## Solution 4: Manual Project File Edit (Advanced)

If you're comfortable editing the project file:

1. Close Xcode completely
2. Open `VaultEye.xcodeproj/project.pbxproj` in a text editor
3. Search for `VaultEye.entitlements`
4. Look for a line like:
   ```
   CODE_SIGN_ENTITLEMENTS = VaultEye/VaultEye.entitlements;
   ```
5. Verify the path is correct relative to the project root
6. Save and reopen Xcode
7. Clean and rebuild

## Quick Fix: Remove Entitlements Temporarily

If you just want to build quickly and don't need entitlements right now:

1. Open Xcode
2. Select VaultEye target
3. Go to "Build Settings" tab
4. Search for "Code Signing Entitlements"
5. Clear the value (make it empty)
6. Build should succeed

**Note**: You'll need entitlements later for background tasks and notifications, but this gets you building.

## After Fixing

Once the build succeeds:

1. Continue adding the BackgroundScan files
2. Configure Info.plist for background tasks
3. Test the app

## Current Entitlements Content

Your `VaultEye.entitlements` file currently contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
</dict>
</plist>
```

This is for push notifications (APS environment). The background scanning system doesn't require any additional entitlements beyond what's in Info.plist.
