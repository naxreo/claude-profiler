#!/usr/bin/env bash
# SC-23: dist/bootstrap-update.sh — update 명령이 없는 구버전 시뮬레이션 후 첫 업그레이드.
# 시나리오: dist/claude-profiler 를 가짜 prefix 에 설치 → 새 소스에 버전 9.9.9 로 패치 →
# bootstrap-update.sh 실행 → 새 바이너리 버전 확인 + 데이터/셸 rc 보존 검증.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

PROJ_ROOT="$(cd "$(dirname "$CPROF")/.." && pwd)"

# --- 1) 가짜 prefix 에 "구버전" 설치 (셸 rc 마커도 미리 작성) ---
PREFIX="$HOME/local"
BIN="$PREFIX/bin/claude-profiler"
mkdir -p "$PREFIX/bin" "$PREFIX/share/claude-profiler/completions"
install -m 0755 "$CPROF" "$BIN"

RC="$HOME/.bashrc"
{
  echo '# >>> claude-profiler >>>'
  echo "export PATH=\"$PREFIX/bin:\$PATH\""
  echo '# <<< claude-profiler <<<'
} > "$RC"

# 사용자 데이터 마커 — 보존돼야 함
"$BIN" init --yes >/dev/null
echo "preserve-me" > "$HOME/.claude-profiler/profiles/default/marker.txt"

# --- 2) 가짜 새 버전 소스 (버전 9.9.9) ---
SRC="$HOME/cprof-src"
mkdir -p "$SRC"
cp -R "$PROJ_ROOT/src" "$SRC/src"
cp "$PROJ_ROOT/build.sh" "$SRC/build.sh"
chmod +x "$SRC/build.sh"
awk '{
  if ($0 ~ /^VERSION="\$\{VERSION:-/) {
    print "VERSION=\"${VERSION:-9.9.9}\""
  } else { print }
}' "$SRC/build.sh" > "$SRC/build.sh.new" && mv "$SRC/build.sh.new" "$SRC/build.sh"
chmod +x "$SRC/build.sh"

# 새 소스에는 dist/ 가 비어 있을 수 있으므로 한 번 빌드해서 dist/bootstrap-update.sh 생성
( cd "$SRC" && bash build.sh ) >/dev/null
[[ -f "$SRC/dist/bootstrap-update.sh" ]] || { echo "build.sh did not copy bootstrap-update.sh to dist/"; exit 1; }

# --- 3) bootstrap-update.sh 실행 (PATH 에 새 PREFIX 를 노출시켜 자동 감지) ---
export PATH="$PREFIX/bin:$PATH"
bash "$SRC/dist/bootstrap-update.sh" --from "$SRC" --yes

# --- 4) 새 바이너리 버전이 9.9.9 인지 ---
ver="$("$BIN" --version)"
echo "$ver" | grep -q "9.9.9" || { echo "version not updated: $ver"; exit 1; }

# --- 5) 사용자 데이터 보존 ---
[[ -f "$HOME/.claude-profiler/profiles/default/marker.txt" ]] || { echo "user data wiped"; exit 1; }

# --- 6) 셸 rc 마커 한 번만 ---
grep -q '# >>> claude-profiler >>>' "$RC" || { echo "shell rc marker stripped"; exit 1; }
count="$(grep -c '# >>> claude-profiler >>>' "$RC")"
[[ "$count" -eq 1 ]] || { echo "shell rc marker duplicated (count=$count)"; exit 1; }

# --- 7) --from 누락 시 코드 2 ---
set +e
bash "$SRC/dist/bootstrap-update.sh" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || { echo "expected exit 2 without --from, got $rc"; exit 1; }

# --- 8) 알 수 없는 옵션도 코드 2 ---
set +e
bash "$SRC/dist/bootstrap-update.sh" --from "$SRC" --bogus >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || { echo "expected exit 2 on unknown option, got $rc"; exit 1; }

# --- 9) 명시적 --prefix 가 자동 감지를 덮어쓰는지 ---
ALT="$HOME/altprefix"
mkdir -p "$ALT/bin"
bash "$SRC/dist/bootstrap-update.sh" --from "$SRC" --prefix "$ALT" --yes >/dev/null
[[ -x "$ALT/bin/claude-profiler" ]] || { echo "explicit --prefix ignored"; exit 1; }
"$ALT/bin/claude-profiler" --version | grep -q "9.9.9" || { echo "alt prefix wrong version"; exit 1; }
