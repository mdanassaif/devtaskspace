#!/bin/bash
# Builds "Anas HQ.app" and puts it in ~/Applications (shows in Spotlight, Launchpad and Dock).
set -e
cd "$(dirname "$0")"
OUT="build/Anas HQ.app"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources" build/AppIcon.iconset

swiftc -O -parse-as-library -o "$OUT/Contents/MacOS/AnasHQ" Sources/*.swift
swift make-icon.swift build/icon-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon-1024.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$OUT/Contents/Resources/AppIcon.icns"

cat > "$OUT/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Anas HQ</string>
  <key>CFBundleDisplayName</key><string>Anas HQ</string>
  <key>CFBundleIdentifier</key><string>com.anashq.app</string>
  <key>CFBundleExecutable</key><string>AnasHQ</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
EOF
codesign --force --sign - "$OUT"
mkdir -p ~/Applications
ditto "$OUT" ~/Applications/"Anas HQ.app"
echo "✓ Installed ~/Applications/Anas HQ.app"
