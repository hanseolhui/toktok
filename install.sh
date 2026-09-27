#!/bin/bash
# 톡톡(TokTok) 설치: 소스를 받아 이 맥에서 직접 빌드한 뒤 ~/Applications 에 설치합니다.
# 사용법: bash -c "$(curl -fsSL https://raw.githubusercontent.com/hanseolhui/toktok/main/install.sh)"
set -euo pipefail

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }

echo "▶ 톡톡(TokTok) 설치"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  warn "앱을 빌드하려면 Apple 개발 도구(Command Line Tools)가 필요해요."
  warn "설치 창을 엽니다. 설치가 끝나면 이 명령을 다시 실행하세요."
  xcode-select --install 2>/dev/null || true
  exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo .)"
TMP=""
if [ ! -f "$SRC_DIR/Sources/main.swift" ]; then   # 한 줄 설치(curl)로 실행한 경우 소스 받기
  TMP=$(mktemp -d -t toktok)
  curl -fsSL https://github.com/hanseolhui/toktok/archive/refs/heads/main.tar.gz | tar xz -C "$TMP" --strip-components 1
  SRC_DIR="$TMP"
fi

DEST="${TOKTOK_DEST:-$HOME/Applications}"
mkdir -p "$DEST"
pkill -x TokTok 2>/dev/null || true
bash "$SRC_DIR/build.sh" "$DEST" >/dev/null
[ -n "$TMP" ] && rm -rf "$TMP"
ok "설치 완료: $DEST/TokTok.app"

if [ "${TOKTOK_NO_OPEN:-0}" != "1" ]; then
  open "$DEST/TokTok.app"
  ok "실행 완료 (메뉴바의 손가락 아이콘)"
fi
echo
echo "  처음이면 '손쉬운 사용' 권한을 허용해 주세요:"
echo "   • 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > TokTok 켜기"
echo "  (업데이트 후 동작하지 않으면 목록에서 TokTok을 '-'로 지우고 다시 허용)"
