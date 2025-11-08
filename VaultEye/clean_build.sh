#!/bin/bash
# Clean build script for VaultEye

echo "🧹 Cleaning VaultEye build..."

# Navigate to project directory
cd "$(dirname "$0")"

# Clean derived data
echo "Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/VaultEye-*

# Clean build folder if Xcode is available
if command -v xcodebuild &> /dev/null; then
    echo "Running xcodebuild clean..."
    xcodebuild clean -project VaultEye.xcodeproj -scheme VaultEye 2>/dev/null || true
fi

echo "✅ Clean complete!"
echo ""
echo "Next steps:"
echo "1. Open VaultEye.xcodeproj in Xcode"
echo "2. Press Cmd+Shift+K to clean build folder"
echo "3. Press Cmd+B to build"
echo ""
echo "If you still get the entitlements error:"
echo "- See FIX_ENTITLEMENTS_ERROR.md for solutions"
