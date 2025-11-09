# Quick Setup Guide - Background Scanning

## ✅ Build Error Fixed
The "Multiple commands produce Info.plist" error is now fixed. Modern iOS apps don't need a separate Info.plist file.

## 🚀 2-Minute Setup

### Step 1: Add Background Task Identifier
1. Xcode → Select VaultEye target
2. **Info** tab
3. Click **+** button
4. Add: `Permitted background task scheduler identifiers` (BGTaskSchedulerPermittedIdentifiers)
5. Expand it → Add item: **`com.vaulteye.scan`**

### Step 2: Enable Background Modes
1. **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add: **Background Modes**
4. Check these boxes:
   - ✅ **Background fetch**
   - ✅ **Background processing**

### That's it! Now build and test on your iPhone.

## 🧪 Test It

1. Build to your iPhone
2. Start a scan (try 10-20% threshold for faster results)
3. Press **Home button** to leave app
4. Wait 1-2 minutes
5. Check for notification! 🔔

## 📊 What You'll See in Console

```
🔵 Background task started: 1        ← iOS granted background time
📱 App entered background - scan will continue
🔍 Asset D69A57A8... - Found 1 YOLO detection(s)
💾 Checkpoint: 20/150               ← Progress saved
🎉 Scan complete: 5 matches         ← Done!
🔵 Background task ended: 1
```

## ⚠️ Simulator vs Device

**Simulator**: Limited background time, you may see warnings (this is normal)
**Real iPhone**: Full background processing, scans will complete properly

## 📖 Full Documentation

See `BACKGROUND_SETUP_INSTRUCTIONS_UPDATED.md` for complete details, troubleshooting, and architecture info.

---

**The app will now continue scanning even when you leave it!** 🎉
