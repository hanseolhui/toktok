#!/bin/bash
# 톡톡(TokTok).app 빌드. 사용법: ./build.sh [설치할 폴더]  (기본: ./build)
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-build}"
APP="$OUT/TokTok.app"
VERSION="0.1.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O \
  -import-objc-header Sources/MultitouchBridge.h \
  -target "$(uname -m)-apple-macos13.0" \
  Sources/main.swift \
  -o "$APP/Contents/MacOS/TokTok"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TokTok</string>
  <key>CFBundleDisplayName</key><string>톡톡</string>
  <key>CFBundleIdentifier</key><string>io.github.hanseolhui.toktok</string>
  <key>CFBundleExecutable</key><string>TokTok</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
EOF

codesign --force --sign - --identifier io.github.hanseolhui.toktok "$APP" >/dev/null 2>&1
echo "빌드 완료: $APP"
