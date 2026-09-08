#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift run --package-path macos --scratch-path .cache/swift-build --disable-sandbox SessionTests
swift build --package-path macos --scratch-path .cache/swift-build --disable-sandbox -c release --product KeyPossum --arch arm64
binary_dir="$(swift build --package-path macos --scratch-path .cache/swift-build --disable-sandbox -c release --show-bin-path --arch arm64)"
bundle="$project_root/dist/KeyPossum.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/KeyPossum" "$bundle/Contents/MacOS/KeyPossum"
cp assets/keypossum.icns "$bundle/Contents/Resources/keypossum.icns"
cp assets/keypossum.png "$bundle/Contents/Resources/keypossum.png"
cp LICENSE "$bundle/Contents/Resources/LICENSE"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>KeyPossum</string>
<key>CFBundleDisplayName</key><string>KeyPossum</string>
<key>CFBundleIdentifier</key><string>org.keypossum.app</string>
<key>CFBundleVersion</key><string>0.1.0-alpha.1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleExecutable</key><string>KeyPossum</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>keypossum</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSInputMonitoringUsageDescription</key><string>KeyPossum observes your selected four-key gesture while cleaning. No key activity is saved.</string>
</dict></plist>
PLIST
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"
ditto -c -k --sequesterRsrc --keepParent "$bundle" "$project_root/dist/KeyPossum-0.1.0-alpha.1-macos-arm64.zip"
echo "Built: $bundle"
