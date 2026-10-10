#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
preview_app=.build/ClickLoopOverlayPreview.app
mkdir -p "$preview_app/Contents/MacOS"
cat > "$preview_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClickLoopOverlayPreview</string>
<key>CFBundleIdentifier</key><string>com.andyjzhao.clickloop.overlay-preview</string>
<key>CFBundleName</key><string>ClickLoop Overlay Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
swiftc Sources/ClickScheme.swift Sources/MouseClicker.swift Sources/ClickRateMeter.swift \
    Sources/CPSOverlayController.swift Tests/OverlayPreview.swift \
    -o "$preview_app/Contents/MacOS/ClickLoopOverlayPreview" \
    -framework AppKit -framework CoreGraphics
"$preview_app/Contents/MacOS/ClickLoopOverlayPreview"
