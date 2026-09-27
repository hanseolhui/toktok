#!/bin/bash
# 톡톡(TokTok) 설치: 애플 공증을 받은 최신 릴리스를 받아 응용 프로그램 폴더에 설치합니다.
# 사용법: bash -c "$(curl -fsSL https://raw.githubusercontent.com/hanseolhui/toktok/main/install.sh)"
#
# 환경 변수: TOKTOK_DEST (설치 폴더), TOKTOK_NO_OPEN=1 (설치 후 실행 안 함),
#           TOKTOK_BUILD=1 (릴리스를 받지 않고 소스에서 직접 빌드)
set -euo pipefail

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }

echo "▶ 톡톡(TokTok) 설치"

# 설치 위치: /Applications 에 쓸 수 있으면 거기, 아니면 ~/Applications
if [ -n "${TOKTOK_DEST:-}" ]; then DEST="$TOKTOK_DEST"
elif [ -w /Applications ]; then DEST="/Applications"
else DEST="$HOME/Applications"; fi
mkdir -p "$DEST"

TMP=$(mktemp -d -t toktok)
trap 'rm -rf "$TMP"' EXIT

build_from_source() {
  if ! xcrun --find swiftc >/dev/null 2>&1; then
    warn "직접 빌드하려면 Apple 개발 도구(Command Line Tools)가 필요해요."
    warn "설치 창을 엽니다. 설치가 끝나면 이 명령을 다시 실행하세요."
    xcode-select --install 2>/dev/null || true
    exit 1
  fi
  local src
  src="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo .)"
  if [ ! -f "$src/Sources/main.swift" ]; then
    curl -fsSL https://github.com/hanseolhui/toktok/archive/refs/heads/main.tar.gz | tar xz -C "$TMP" --strip-components 1
    src="$TMP"
  fi
  bash "$src/build.sh" "$TMP/out" >/dev/null
  ok "소스에서 빌드 완료"
}

if [ "${TOKTOK_BUILD:-0}" = "1" ]; then
  build_from_source
elif TAG=$(curl -fsSL https://api.github.com/repos/hanseolhui/toktok/releases/latest 2>/dev/null \
       | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1); \
     URL="https://github.com/hanseolhui/toktok/releases/latest/download/TokTok.zip"; \
     [ -n "$TAG" ] && URL="https://github.com/hanseolhui/toktok/releases/download/$TAG/TokTok.zip"; \
     curl -fsSL "$URL" -o "$TMP/TokTok.zip" \
     && mkdir -p "$TMP/out" && ditto -x -k "$TMP/TokTok.zip" "$TMP/out" \
     && spctl --assess --type execute "$TMP/out/TokTok.app" 2>/dev/null; then
  ok "공증된 최신 릴리스 다운로드 (${TAG:-latest})"
else
  warn "릴리스를 받지 못해 소스에서 직접 빌드합니다."
  rm -rf "$TMP/out"; build_from_source
fi

[ "${TOKTOK_NO_OPEN:-0}" = "1" ] || pkill -x TokTok 2>/dev/null || true
rm -rf "$DEST/TokTok.app"
ditto "$TMP/out/TokTok.app" "$DEST/TokTok.app"
# 예전 위치(~/Applications)에 남은 사본 정리
if [ "$DEST" = "/Applications" ] && [ -d "$HOME/Applications/TokTok.app" ]; then
  rm -rf "$HOME/Applications/TokTok.app"
fi
ok "설치 완료: $DEST/TokTok.app"

if [ "${TOKTOK_NO_OPEN:-0}" != "1" ]; then
  open "$DEST/TokTok.app"
  ok "실행 완료 (메뉴바의 V 손가락 아이콘)"
fi
echo
echo "  처음이면 '손쉬운 사용' 권한을 허용해 주세요:"
echo "   • 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > TokTok 켜기"
