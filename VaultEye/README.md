# Obscurafy

**Obscurafy** is an iOS app that helps protect your privacy by automatically detecting and managing sensitive content in your photo library. Using on-device machine learning, it scans for documents, IDs, cards, and other sensitive information, then gives you tools to review, redact, or delete flagged photos.

## 🎯 Overview

Obscurafy runs entirely on your device to maintain privacy. It uses:
- **YOLO ML model** for object detection (documents, IDs, credit cards, etc.)
- **Apple Vision OCR** for text detection and extraction
- **Google Gemini AI** (optional) for intelligent content analysis
- **Background processing** for efficient library scanning

## ✨ Key Features

### 1. **Background Photo Scanning**
- Automatically scans your entire photo library in the background
- Configurable confidence threshold (40-100%)
- Progress tracking with real-time statistics
- Low battery impact using iOS Background Tasks API

### 2. **Swipe-to-Review Interface**
- **Swipe left** (green) to keep photos
- **Swipe right** (red) to queue for deletion
- Risk level indicator based on ML confidence
- Batch deletion to prevent accidental losses

### 3. **Smart Text Redaction**
- One-tap text detection and blurring
- Combines YOLO object detection + Vision OCR
- Preserves original photo metadata
- Creates new redacted version automatically

### 4. **AI-Powered Analysis** (Optional)
- Gemini AI explains why photos were flagged
- Risk level assessment (High/Medium/Low)
- Privacy score calculation
- Content categorization

### 5. **Privacy-First Design**
- ✅ All processing happens on-device
- ✅ No photos leave your device (except optional Gemini API)
- ✅ Requires explicit user consent for AI features
- ✅ Can disable AI analysis entirely

## 🏗️ Architecture

### Core Components

```
VaultEye/
├── BackgroundScan/
│   ├── BackgroundScanManager.swift    # Orchestrates background scanning
│   ├── BGTasks.swift                  # Background task registration
│   ├── ImageClassifier.swift         # ML model wrapper
│   ├── ScanScreen.swift               # Scan control UI
│   └── ResultStore.swift              # Persistent scan results
│
├── Services/
│   ├── YOLOService.swift              # YOLO object detection
│   ├── RedactionService.swift        # Text blurring engine
│   ├── GeminiService.swift            # AI analysis (optional)
│   ├── OCRService.swift               # Vision text extraction
│   ├── PhotoLibraryManager.swift     # Photo access wrapper
│   └── StatisticsManager.swift       # Usage analytics
│
├── Views/
│   ├── SwipeCardView.swift            # Main review interface
│   ├── DetailView.swift               # Full-screen photo view
│   └── StatisticsView.swift           # Stats dashboard
│
├── Models/
│   ├── DetectionResult.swift          # Scan result model
│   ├── DetectedRegion.swift           # ML detection box
│   └── SensitiveAnalysis.swift        # AI analysis result
│
└── Utilities/
    ├── AppColor.swift                 # Design system
    └── ImageGeometry.swift            # Coordinate conversion
```

### Technical Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **ML Framework**: CoreML, Vision
- **Minimum iOS**: iOS 16.0+
- **Architecture**: MVVM with Combine

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 16.0+ device or simulator
- Apple Developer account (for device testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/VaultEye.git
   cd VaultEye
   ```

2. **Configure Gemini API (Optional)**

   If you want AI analysis features:

   a. Create `Secrets.xcconfig` in project root:
   ```bash
   touch Secrets.xcconfig
   ```

   b. Add your API key:
   ```
   GEMINI_API_KEY = YOUR_GEMINI_API_KEY_HERE
   ```

   c. Get a free API key at [Google AI Studio](https://makersuite.google.com/app/apikey)

3. **Open in Xcode**
   ```bash
   open VaultEye.xcodeproj
   ```

4. **Build and Run**
   - Select your target device
   - Press `Cmd + R` to build and run

### First Launch Setup

1. **Grant Photo Library Access**
   - App will request "Full Access" to scan all photos
   - Required for background scanning

2. **Enable Notifications** (Optional)
   - Get alerts when background scans complete
   - Recommended for better UX

3. **Configure AI Analysis** (Optional)
   - Tap "Enable AI Analysis" in scan settings
   - Review privacy disclosure
   - Only enables if Gemini API key is configured

## 📱 Usage Guide

### Starting a Scan

1. Navigate to **"Background Scan"** tab
2. Adjust confidence threshold (recommended: 70%)
3. Tap **"Start Scan"**
4. App will scan photos in background
5. Notification appears when complete

### Reviewing Flagged Photos

1. Go to **"Review Photos"** tab
2. View detected photos one at a time
3. **Swipe left** to keep (green indicator)
4. **Swipe right** to queue for deletion (red indicator)
5. Tap **"Delete"** button to permanently remove queued photos

### Redacting Sensitive Text

1. Open any flagged photo
2. Tap **"Redact"** button (top right)
3. App automatically:
   - Detects all text using OCR
   - Blurs YOLO-detected objects
   - Saves new redacted version
   - Queues original for deletion
4. Review and confirm deletion

### Understanding Risk Levels

**High Risk (Red)** - 80-100% confidence
- Very likely sensitive content
- Strong detection by ML model
- Recommended for immediate review

**Medium Risk (Orange)** - 50-79% confidence
- Possibly sensitive content
- Moderate detection confidence
- Worth reviewing

**Low Risk (Yellow)** - 0-49% confidence
- Low probability of sensitive content
- May be false positive
- Quick review recommended

## 🎨 Design System

### Two-Color Minimal Theme

**Primary Colors:**
- Blue: `#4EA8FF` - Interactive elements, buttons, accents
- Gray: `#94A3B8` - Text, borders, secondary elements

**Semantic Tokens:**
- `AppColor.primary` - Main interactive color
- `AppColor.primaryBg` - Light background (10% opacity)
- `AppColor.cardFill` - Card backgrounds (adaptive for light/dark mode)
- `AppColor.border` - Borders (35% opacity)

**Special Colors** (preserved for UX clarity):
- Green: "Keep" action
- Red: "Delete" action
- Orange: Medium risk warning
- Yellow: Low risk warning

### Dark Mode Support

Automatically adapts to system appearance:
- Light backgrounds: `#F8FAFC`
- Dark backgrounds: `#1E293B`
- Text contrast meets WCAG AA standards

## 🔒 Privacy & Security

### Data Handling

✅ **What stays on your device:**
- All photos and images
- ML detection results
- Scan history and statistics
- Redacted images

⚠️ **What may leave your device** (only if AI enabled):
- OCR-extracted text sent to Gemini API
- ML detection labels (e.g., "id_card")
- No images are ever sent to external servers

### Permissions Required

| Permission | Purpose | Required? |
|------------|---------|-----------|
| Photo Library (Full Access) | Scan and analyze all photos | Yes |
| Background App Refresh | Run scans while app is closed | Recommended |
| Notifications | Alert when scans complete | Optional |

### Privacy Controls

- AI analysis is **opt-in only**
- Clear consent dialog before enabling
- Can disable AI at any time
- All ML processing happens on-device

## 🧪 Testing

### Manual Testing

1. **Test with sample images**
   - Add test photos with IDs, documents, credit cards
   - Run a scan with 70% threshold
   - Verify correct detection

2. **Test redaction**
   - Open flagged photo
   - Tap "Redact"
   - Check blurred areas cover sensitive content

3. **Test batch deletion**
   - Queue multiple photos
   - Verify count updates
   - Confirm deletion removes only queued photos

### Background Task Testing

```bash
# Simulate background task in simulator
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.obscurafy.scan"]
```

## 🛠️ Configuration

### Confidence Threshold

Adjust in Background Scan tab:
- **40-60%**: More sensitive, may have false positives
- **70%** (recommended): Balanced accuracy
- **80-100%**: Only high-confidence detections

### YOLO Model

Located at: `VaultEye/ML/yolov8n.mlmodelc`

Detects:
- Documents
- ID cards
- Passports
- Credit cards
- Driver licenses
- Business cards

### Gemini Configuration

Edit `GeminiService.swift` to adjust:
- Model version (default: `gemini-1.5-flash`)
- Temperature (default: 0.7)
- Max tokens (default: 500)

## 🐛 Troubleshooting

### "No photos to review" after scan

**Cause**: No photos exceeded confidence threshold

**Solution**:
1. Lower confidence threshold to 50-60%
2. Check photo library has scannable content
3. Review scan statistics for total photos scanned

### Background scan not running

**Cause**: Background refresh disabled or low battery

**Solution**:
1. Enable Background App Refresh in Settings
2. Keep device plugged in
3. Ensure device not in Low Power Mode

### Redaction not working

**Cause**: No text detected in image

**Solution**:
1. Ensure image has visible text
2. Check image quality and resolution
3. Try adjusting OCR confidence in code

### Gemini API errors

**Cause**: Invalid API key or rate limit

**Solution**:
1. Verify API key in `Secrets.xcconfig`
2. Check API quota at Google AI Studio
3. Review Gemini API console logs

## 📊 Performance

### Scan Performance

- **Speed**: ~5-10 photos/second (iPhone 12+)
- **Battery Impact**: Low (runs during idle time)
- **Storage**: Minimal (results cached in UserDefaults)

### ML Model Performance

- **YOLO Detection**: ~100-200ms per image
- **Vision OCR**: ~200-500ms per image
- **Gemini Analysis**: ~1-3 seconds (network dependent)

### Memory Usage

- **Typical**: 50-100 MB
- **Peak** (during scan): 150-200 MB
- **Redaction**: 200-300 MB (temporary)

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for consistency
- Add comments for complex logic
- Write unit tests for new features

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- **Apple Vision Framework** - Text detection and OCR
- **YOLO (You Only Look Once)** - Object detection model
- **Google Gemini AI** - Intelligent content analysis
- **SwiftUI** - Modern UI framework

## 📞 Contact

- **Issues**: [GitHub Issues](https://github.com/yourusername/VaultEye/issues)
- **Email**: your.email@example.com
- **Website**: https://obscurafy.app (if applicable)

## 🗺️ Roadmap

### Upcoming Features

- [ ] Face detection and blurring
- [ ] Handwriting recognition
- [ ] Custom ML model training
- [ ] iCloud sync for scan results
- [ ] Share extension for quick redaction
- [ ] Automated backup before deletion
- [ ] Advanced filtering and search
- [ ] Export redaction reports

### Known Issues

- Background tasks may not run frequently on older devices
- Large photo libraries (>10,000) may take hours to scan
- Gemini API has usage limits on free tier

---

**Made with ❤️ to protect your privacy**

*Obscurafy - Keep your sensitive photos secure*
