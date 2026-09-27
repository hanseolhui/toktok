#!/bin/bash
# 배포용 릴리스: 유니버설 빌드 → Developer ID 서명 → 애플 공증 → staple → zip
# 사전 준비: xcrun notarytool store-credentials notary ...
# 사용법: ./release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${1:?버전을 입력하세요 (예: ./release.sh 0.1.0)}"
DIST="dist"
rm -rf "$DIST"; mkdir -p "$DIST"

VERSION="$VERSION" ARCHS="arm64 x86_64" ./build.sh "$DIST"
codesign --verify --strict "$DIST/TokTok.app"
lipo -archs "$DIST/TokTok.app/Contents/MacOS/TokTok"

ZIP="$DIST/TokTok-$VERSION.zip"
ditto -c -k --keepParent "$DIST/TokTok.app" "$ZIP"
echo "▶ 애플 공증 제출 (몇 분 걸려요)"
xcrun notarytool submit "$ZIP" --keychain-profile notary --wait
xcrun stapler staple "$DIST/TokTok.app"
rm "$ZIP"
ditto -c -k --keepParent "$DIST/TokTok.app" "$ZIP"
spctl --assess --type execute --verbose "$DIST/TokTok.app"
shasum -a 256 "$ZIP"
echo "릴리스 완료: $ZIP"
