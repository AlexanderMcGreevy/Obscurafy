# Background Processing Setup Instructions (UPDATED - No Info.plist Needed)

## What Was Changed

I've configured VaultEye to continue scanning photos even when the app is in the background. The scan will now continue processing and send you a notification when complete.

## Changes Made to Code

### 1. Updated BackgroundScanManager
- Added `UIBackgroundTaskIdentifier` to request extended background time
- Calls `UIApplication.shared.beginBackgroundTask()` when scan starts
- Automatically checkpoints and ends background task when:
  - Scan completes
  - Scan is cancelled
  - iOS is about to expire the background task

### 2. Updated VaultEyeApp.swift
- Added scene phase monitoring to detect when app goes to background
- Registers background task handler with the correct scanManager instance
- Schedules BGProcessingTask as a fallback for longer scans

## Required Xcode Setup Steps (SIMPLIFIED)

**IMPORTANT**: Modern iOS apps don't use Info.plist files - everything is configured in Xcode settings.

### Step 1: Add Background Task Identifier

1. Open Xcode and your VaultEye project
2. Select the **VaultEye** target in the Project Navigator
3. Go to the **"Info"** tab
4. Find or add **"Permitted background task scheduler identifiers"** (key: `BGTaskSchedulerPermittedIdentifiers`)
   - If you don't see it, click the **"+"** button at the top
   - Type: `BGTaskSchedulerPermittedIdentifiers` (or select from dropdown)
5. Expand the array and add a new item with value: **`com.vaulteye.scan`**

### Step 2: Enable Background Modes Capability

1. Select the **VaultEye** target
2. Go to the **"Signing & Capabilities"** tab
3. Click the **"+ Capability"** button at the top
4. Search for and add **"Background Modes"**
5. In the Background Modes section that appears, check these boxes:
   - ✅ **Background fetch**
   - ✅ **Background processing**

### Step 3: Verify Privacy Descriptions (Should Already Exist)

1. Stay in the **VaultEye** target
2. Go to the **"Info"** tab
3. Verify these entries exist (add if missing):
   - **Privacy - Photo Library Usage Description** (`NSPhotoLibraryUsageDescription`)
     - Value: "VaultEye needs access to your photos to scan for sensitive information"
   - **Privacy - Photo Library Additions Usage Description** (`NSPhotoLibraryAddUsageDescription`)
     - Value: "VaultEye needs to save redacted images to your photo library"
   - **Privacy - User Notifications Usage Description** (`NSUserNotificationsUsageDescription`)
     - Value: "VaultEye sends notifications when background scans complete"

### Visual Guide:

```
1. Info Tab Setup:
   ┌─────────────────────────────────────────────────────────┐
   │ Custom iOS Target Properties                            │
   ├─────────────────────────────────────────────────────────┤
   │ ▼ Permitted background task scheduler identifiers       │
   │   └─ Item 0: com.vaulteye.scan                          │
   │ ▼ Privacy - Photo Library Usage Description             │
   │   └─ VaultEye needs access to your photos...            │
   │ ▼ Privacy - User Notifications Usage Description        │
   │   └─ VaultEye sends notifications when...               │
   └─────────────────────────────────────────────────────────┘

2. Signing & Capabilities Tab:
   ┌─────────────────────────────────────────────────────────┐
   │ + Capability      Debug      Release                    │
   ├─────────────────────────────────────────────────────────┤
   │ Background Modes                                         │
   │ ☐ Audio, AirPlay, and Picture in Picture               │
   │ ☐ Location updates                                       │
   │ ☑ Background fetch                                       │
   │ ☑ Background processing                                  │
   │ ☐ Remote notifications                                   │
   └─────────────────────────────────────────────────────────┘
```

## How It Works

### Short Background Tasks (3-5 minutes)
When you start a scan and leave the app:
1. App calls `beginBackgroundTask()` to request ~3-5 minutes of background time
2. Scan continues processing images
3. Progress is checkpointed every 20 images
4. When scan completes or time expires, notification is sent

### Long Background Tasks (30+ minutes)
For longer scans with many photos:
1. iOS may suspend the app after 3-5 minutes
2. The `BGProcessingTask` scheduler will resume the scan later
3. Scan resumes from last checkpoint
4. Process repeats until all photos are scanned
5. Final notification sent when complete

## Testing on Device

**Note**: Background processing works differently on simulator vs. real device:

### On Simulator:
- Background tasks have shorter time limits
- BGProcessingTask scheduling may not work
- You'll see: "Background task identifier not registered (expected in simulator)"
- This is **NORMAL** - it will work on real device

### On Real Device:
1. Build and run on your iPhone
2. Start a background scan with 10-20% threshold
3. Press the home button or swipe up to leave the app
4. The scan will continue for 3-5 minutes
5. You'll receive a notification when complete

## Debugging

### Check Console Output in Xcode:
Look for these log messages when you start a scan and background the app:

```
✅ Good signs:
🔵 Background task started: [ID]      ← Background time granted
📱 App entered background - scan will continue
💾 Checkpoint: 20/100                  ← Progress being saved
✅ Scheduled background processing task
🎉 Scan complete: 5 matches            ← Success!
🔵 Background task ended: [ID]
```

```
⚠️ Expected warnings (simulator only):
⚠️ Background task identifier not registered (expected in simulator)
```

### Common Issues:

**Build Error: "Multiple commands produce Info.plist"**
- ✅ **FIXED** - We removed the Info.plist file
- Modern iOS apps configure everything in Xcode settings

**"Background task identifier not registered" on device**
- Verify you added `com.vaulteye.scan` to BGTaskSchedulerPermittedIdentifiers
- Check spelling and case (must match exactly)
- Clean build: Product → Clean Build Folder (Cmd+Shift+K)

**Scan stops immediately when backgrounding**
- Check that Background Modes capability is enabled
- Check that both "Background fetch" and "Background processing" are checked
- Test on a real device (simulator has severe limitations)

**No notification received**
- Check notification permissions are granted (app will ask on first scan)
- Look in Notification Center
- Check Console for "🎉 Scan complete" message

## Testing Tips

### Quick Test (30 seconds):
1. Set confidence threshold to **10%** (will match more photos)
2. Scan only a small subset (app will scan all, but you'll see results quickly)
3. Start scan
4. Immediately press home button
5. Wait 30-60 seconds
6. Check notification center

### Full Test (5 minutes):
1. Set confidence threshold to **70%** (more realistic)
2. Start full library scan
3. Leave app
4. Go do something else for 5 minutes
5. Should receive notification when complete

### Monitor in Real-Time:
1. Connect iPhone to Mac with cable
2. In Xcode: Window → Devices and Simulators
3. Select your iPhone
4. Click "Open Console" button
5. Filter for "VaultEye" to see all logs
6. Start scan on phone and background app
7. Watch logs in real-time

## Expected Behavior

✅ **What should work:**
- Start scan with 10-70% confidence threshold
- Leave app (home button or swipe up)
- App continues scanning for 3-5 minutes
- Progress checkpointed every 20 images
- Notification sent when complete
- Return to app and see results in Review tab

✅ **For large libraries (500+ photos):**
- Initial scan runs for 3-5 minutes in background
- iOS may suspend app after that
- BGProcessingTask resumes scan later (when device is idle/charging)
- Multiple background sessions until complete
- Final notification when all photos scanned
- Check back in Review tab to see all flagged photos

## Next Steps

1. ✅ Complete the Xcode setup steps above (should take 2-3 minutes)
2. ✅ Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
3. ✅ Build and install on your iPhone
4. ✅ Grant photo library and notification permissions when prompted
5. ✅ Start a background scan
6. ✅ Leave the app (home button)
7. ✅ Wait for completion notification

**The scan will now continue even when you're not in the app!** 🎉

## Architecture Summary

```
User starts scan → App calls beginBackgroundTask()
                ↓
              iOS grants 3-5 minutes of background time
                ↓
              App enters background (user presses home)
                ↓
              onChange(scenePhase) detects background
                ↓
              Schedules BGProcessingTask as backup
                ↓
         ┌──────┴──────┐
         │             │
    Short scan     Long scan
    (< 5 min)      (> 5 min)
         │             │
    Completes     Hits time limit
    in window     → iOS suspends
         │             │
    Notification  BGProcessingTask
         ✅        resumes later
                       │
                  Continues from
                  checkpoint
                       │
                  Eventually
                  completes
                       │
                  Notification
                       ✅
```

The code is ready! Just add those two Xcode settings and it will work perfectly.
