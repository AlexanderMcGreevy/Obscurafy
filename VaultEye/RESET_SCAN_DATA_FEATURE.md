# Reset Scan Data Feature

## Overview

Added a "Reset Scan Data" feature to clear all scan history and start fresh without deleting any photos.

## What It Does

The reset feature:
- ✅ Clears all scan progress and history
- ✅ Removes the list of flagged photos from previous scans
- ✅ Clears the Review tab (removes all photos from view)
- ✅ Clears the delete queue (unstages any photos marked for deletion)
- ✅ Resets completion status
- ✅ Allows you to start a brand new scan from scratch
- ✅ **Does NOT delete any photos** - only clears scan metadata and UI state

## User Interface

### Location
The reset button is located at the **bottom of the Scan screen** (scrollable).

### Visual Design
```
┌─────────────────────────────────────────┐
│  🔄 Reset Scan Data                     │
│  Clear all scan history and start fresh │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │  🗑️ Reset                          │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

- Orange color scheme to indicate caution
- Disabled while scan is running
- Clear description of what it does

### Confirmation Dialog
When you tap "Reset", a confirmation dialog appears:

```
┌─────────────────────────────────────────┐
│  Reset Scan Data?                        │
│                                          │
│  This will clear all scan history and   │
│  progress. You'll start from scratch on │
│  the next scan. This does not delete    │
│  any photos.                             │
│                                          │
│  [ Cancel ]  [ Reset ]                   │
└─────────────────────────────────────────┘
```

## Use Cases

### Use Case 1: Testing Different Thresholds
You want to test how different confidence thresholds affect results:
1. Run scan with 85% threshold → 5 photos flagged
2. Reset scan data
3. Run scan with 50% threshold → 25 photos flagged
4. Compare results

### Use Case 2: Fresh Start After Cleanup
You've reviewed and deleted sensitive photos:
1. Completed initial scan
2. Deleted/redacted all flagged photos
3. Reset scan data
4. Run new scan to verify cleanup

### Use Case 3: False Positive Cleanup
Previous scan had many false positives:
1. Old scan flagged 100 photos
2. Most were false positives
3. Reset scan data
4. Run new scan with updated ML model/threshold

### Use Case 4: Debugging
Testing the app behavior:
1. Reset scan data to clear all state
2. Test fresh scan from known state
3. Verify expected behavior

## Implementation Details

### Files Modified

**1. BackgroundScanManager.swift** (lines 170-188)
```swift
func resetScanData() {
    print("🗑️ Resetting all scan data")

    // Cancel any running scan
    if isRunning {
        cancel()
    }

    // Reset the store (deletes ScanState.json)
    store.reset()

    // Reset UI state
    total = 0
    processed = 0
    lastCompletionSummary = nil

    print("✅ Scan data reset complete")
}
```

**2. ScanScreen.swift** (lines 18, 22, 52-59, 366-415)
- Made screen scrollable with `ScrollView`
- Added `@State private var showResetConfirmation = false`
- Added confirmation alert
- Added `resetSection` view at bottom

### What Gets Cleared

When you reset scan data:

**1. Scan State File Deleted:**
```
~/Library/Application Support/ScanState.json
```
Contains:
- List of all photo asset IDs to scan
- Current progress cursor position
- List of selected (flagged) photo IDs
- Confidence threshold used
- Completion status

**2. UI State Cleared:**
- Review tab shows empty state (all flagged photos removed from view)
- Delete queue cleared (staged deletions cancelled)
- Progress counter reset to 0/0
- Completion summary removed
- Scan data version incremented

### What Is Preserved

The reset does **NOT** affect:
- Your actual photos in the library (photos are NEVER deleted)
- App settings and preferences
- Notification permissions
- Photo library permissions
- Gemini AI consent settings
- Statistics (separate from scan state)

## Technical Behavior

### When Scan Is Running
- Reset button is **disabled** (grayed out)
- Prevents accidentally resetting mid-scan
- Must cancel scan first, then reset

### When Scan Is Idle
- Reset button is **enabled**
- Tap shows confirmation dialog
- Confirms before performing irreversible action

### After Reset
- Progress shows 0/0
- No completion summary displayed
- Next scan will process all photos fresh
- No memory of previous flagged photos

## Console Output

When you reset scan data:
```
🗑️ Resetting all scan data
✅ Scan data reset complete - version 1
🗑️ Scan data reset detected - clearing review results
```

If scan was running when reset was triggered:
```
🗑️ Resetting all scan data
🛑 Cancelling scan
🚫 Cancelled background tasks
✅ Scan data reset complete - version 1
🗑️ Scan data reset detected - clearing review results
```

## Safety Features

### Double Confirmation
1. Tap "Reset" button
2. Confirmation dialog appears
3. Must tap "Reset" again to confirm
4. "Cancel" button available to back out

### Clear Messaging
The confirmation explicitly states:
- "This will clear all scan history and progress"
- "You'll start from scratch on the next scan"
- "This does not delete any photos"

### Disabled While Running
Cannot reset while scan is active to prevent:
- Data corruption
- Race conditions
- Lost work

## Comparison with Other Reset Options

| Feature | Reset Scan Data | Cancel Scan | Delete Photos |
|---------|----------------|-------------|---------------|
| Stops current scan | ✅ Yes | ✅ Yes | ❌ No |
| Clears progress | ✅ Yes | ❌ No | ❌ No |
| Clears flagged list | ✅ Yes | ❌ No | ❌ No |
| Deletes photos | ❌ No | ❌ No | ✅ Yes |
| Reversible | ❌ No | ✅ Yes* | ❌ No |

*Cancel allows resuming from checkpoint

## Future Enhancements

Potential improvements:
1. Show what will be deleted (X photos flagged, Y% complete)
2. Export scan results before reset
3. Selective reset (keep progress, clear flagged list)
4. Undo reset (backup ScanState.json temporarily)
5. Reset statistics separately
6. Bulk operations (reset + clear cache + etc.)

## FAQ

**Q: Will this delete my photos?**
A: No! It only clears scan metadata. Your photos are safe.

**Q: Can I undo a reset?**
A: No, reset is permanent. The scan state file is deleted.

**Q: Do I need to reset between scans?**
A: No. The app automatically handles completed scans. Only reset if you want to completely start over.

**Q: Will my flagged photos disappear from Review tab?**
A: Yes. Reset clears the Review tab completely. All flagged photos will be removed from the view, but the actual photos remain in your library.

**Q: Can I reset while scanning?**
A: No. The reset button is disabled while a scan is running. Cancel the scan first.

**Q: What happens if I change the threshold?**
A: The app automatically resets scan progress when threshold changes. Manual reset is not needed.

---

The reset feature is now available! Scroll to the bottom of the Scan screen to find it.
