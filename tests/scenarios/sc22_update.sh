#!/usr/bin/env bash
# SC-22: claude-profiler update — 로컬 소스 경로에서 설치된 바이너리 갱신.
# - 가짜 prefix 에 install 시뮬레이션 → 가짜 새 버전 소스 준비 → update 실행 → 버전 검증.
# - 사용자 데이터(~/.claude-profiler/) 와 셸 rc 마커가 보존되는지 동시 검증.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

# --- 1) 가짜 설치: dist/claude-profiler 를 $PREFIX/bin 에 복사 (install.sh 의 결과를 흉내)
PREFIX="$HOME/local"
BIN="$PREFIX/bin/claude-profiler"
SHARE="$PREFIX/share/claude-profiler"
mkdir -p "$PREFIX/bin" "$SHARE/completions"
install -m 0755 "$CPROF" "$BIN"

# 셸 rc 마커가 보존되는지 확인하기 위해 마커 블록을 미리 작성
RC="$HOME/.bashrc"
{
  echo '# >>> claude-profiler >>>'
  echo "export PATH=\"$PREFIX/bin:\$PATH\""
  echo '# <<< claude-profiler <<<'
} > "$RC"

# init 으로 사용자 데이터 생성 — 보존돼야 함
"$BIN" init --yes >/dev/null
[[ -d "$HOME/.claude-profiler/profiles/default" ]] || { echo "init failed"; exit 1; }
USER_DATA_BEFORE="$(ls "$HOME/.claude-profiler/profiles/default" | sort | tr '\n' ' ')"

# --- 2) 가짜 새 버전 소스 준비: 프로젝트 트리를 복사하고 build.sh 의 VERSION 값을 9.9.9 로 변경
PROJ_ROOT="$(cd "$(dirname "$CPROF")/.." && pwd)"
SRC="$HOME/cprof-src"
mkdir -p "$SRC"
cp -R "$PROJ_ROOT/src" "$SRC/src"
cp "$PROJ_ROOT/build.sh" "$SRC/build.sh"
# 안전한 sed (BSD/GNU 양립): 새 파일에 작성 후 교체
awk '{
  if ($0 ~ /^VERSION="\$\{VERSION:-/) {
    print "VERSION=\"${VERSION:-9.9.9}\""
  } else { print }
}' "$SRC/build.sh" > "$SRC/build.sh.new" && mv "$SRC/build.sh.new" "$SRC/build.sh"
chmod +x "$SRC/build.sh"

# --- 3) update 실행 (--check 는 lock 미획득 → 먼저 검증)
out_check="$("$BIN" update --from "$SRC" --check 2>&1)"
echo "$out_check" | grep -q "9.9.9"           || { echo "--check missing new version: $out_check"; exit 1; }
echo "$out_check" | grep -q "새 버전이 가용"  || { echo "--check missing availability hint"; exit 1; }
# --check 는 임시 클론을 안 하고 로컬 소스를 그대로 쓰므로 SRC 는 살아있어야 함
[[ -d "$SRC" ]] || { echo "--check should not delete local source"; exit 1; }

# --- 4) 실제 update
"$BIN" update --from "$SRC" --yes >/dev/null

# 5) 새 바이너리는 9.9.9 보고해야 함
ver="$("$BIN" version)"
echo "$ver" | grep -q "9.9.9" || { echo "version not updated: $ver"; exit 1; }

# 6) 사용자 데이터 보존
[[ -d "$HOME/.claude-profiler/profiles/default" ]] || { echo "user data wiped"; exit 1; }
USER_DATA_AFTER="$(ls "$HOME/.claude-profiler/profiles/default" | sort | tr '\n' ' ')"
[[ "$USER_DATA_BEFORE" == "$USER_DATA_AFTER" ]] || { echo "user data changed: $USER_DATA_BEFORE → $USER_DATA_AFTER"; exit 1; }

# 7) 셸 rc 마커 블록이 그대로 유지되어야 함 (--no-shell 강제)
grep -q '# >>> claude-profiler >>>' "$RC" || { echo "shell rc marker stripped"; exit 1; }
# 마커 블록이 한 번만 있어야 함 (재기록되지 않았는지)
count="$(grep -c '# >>> claude-profiler >>>' "$RC")"
[[ "$count" -eq 1 ]] || { echo "shell rc marker duplicated (count=$count)"; exit 1; }

# 8) 소스 미지정 시 에러(코드 2)
unset CPROF_UPDATE_URL
assert_exit 2 "$BIN" update

# 9) 정상 설치 위치가 아닌 곳(=$CPROF, dist/claude-profiler)에서 실행하면 거부(코드 1)
set +e
"$CPROF" update --from "$SRC" --yes >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { echo "expected exit 1 from non-installed path, got $rc"; exit 1; }
