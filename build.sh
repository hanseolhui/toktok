#!/bin/bash
# 톡톡(TokTok).app 빌드. 사용법: ./build.sh [설치할 폴더]  (기본: ./build)
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-build}"
APP="$OUT/TokTok.app"
VERSION="${VERSION:-0.1.0}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# ARCHS="arm64 x86_64" 로 유니버설 빌드 (배포용), 기본은 이 맥의 CPU용
ARCHS="${ARCHS:-$(uname -m)}"
BINS=()
for arch in $ARCHS; do
  swiftc -O \
    -import-objc-header Sources/MultitouchBridge.h \
    -target "$arch-apple-macos13.0" \
    Sources/main.swift \
    -o "$OUT/TokTok-$arch"
  BINS+=("$OUT/TokTok-$arch")
done
lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/TokTok"
rm -f "${BINS[@]}"

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

# 서명: Developer ID 인증서가 있으면 사용 (다시 빌드해도 손쉬운 사용 권한 유지), 없으면 임시 서명
SIGN_ID="${TOKTOK_SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | awk '/Developer ID Application/ {print $2; exit}')}"
if [ -n "$SIGN_ID" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" \
    --identifier io.github.hanseolhui.toktok "$APP" >/dev/null
  echo "서명: Developer ID"
else
  codesign --force --sign - --identifier io.github.hanseolhui.toktok "$APP" >/dev/null 2>&1
  echo "서명: 임시(ad-hoc) — 다시 빌드하면 손쉬운 사용 권한을 다시 허용해야 해요"
fi
echo "빌드 완료: $APP"
