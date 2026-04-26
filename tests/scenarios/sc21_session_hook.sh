#!/usr/bin/env bash
# SC-21: SessionStart 배너 훅 자동 주입 (default + 빈 프로파일 + 클론 상속).
# 또한 --session-banner 명령이 plain text 로 현재 프로파일을 출력하는지 검증.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

seed_claude_home
cprof init --yes

# 1. default 의 settings.json 에 훅이 주입되어야 한다.
assert_grep 'claude-profiler --session-banner' "$HOME/.claude-profiler/profiles/default/settings.json"
assert_grep 'SessionStart' "$HOME/.claude-profiler/profiles/default/settings.json"
# 기존 설정(theme:dark) 은 jq 가 있다면 보존, 없다면 건너뜀이 정상이므로 둘 중 하나여야 함.
if command -v jq >/dev/null 2>&1; then
  assert_grep '"theme"' "$HOME/.claude-profiler/profiles/default/settings.json"
fi

# 2. --empty 프로파일에도 자동 주입되어야 한다.
cprof create scratch --empty
assert_grep 'claude-profiler --session-banner' "$HOME/.claude-profiler/profiles/scratch/settings.json"

# 3. 기본 create 는 현재 프로파일 클론이므로 훅이 자연 상속되어야 한다.
cprof create work
assert_grep 'claude-profiler --session-banner' "$HOME/.claude-profiler/profiles/work/settings.json"

# 4. switch vanilla 자동 생성에도 주입되어야 한다.
cprof switch vanilla --force >/dev/null
assert_grep 'claude-profiler --session-banner' "$HOME/.claude-profiler/profiles/vanilla/settings.json"
cprof switch default --force >/dev/null

# 5. --session-banner 출력 검증: 현재 프로파일 이름이 포함되고 plain text 여야 함.
out="$(cprof --session-banner)"
echo "$out" | grep -q "현재 프로파일: default" || { echo "banner missing current profile" >&2; exit 1; }
echo "$out" | grep -q "claude-profiler switch" || { echo "banner missing switch hint" >&2; exit 1; }
# ANSI 이스케이프(\033) 가 없어야 함 (훅 출력은 모델 컨텍스트로 들어가므로 plain).
if printf '%s' "$out" | grep -q $'\033'; then
  echo "banner contains ANSI escapes (must be plain text)" >&2
  exit 1
fi

# 6. 두 번째 init 시도 (재실행) 는 이미 초기화로 거부되어야 함 — 훅 idempotency 와 무관.
assert_exit 1 cprof init --yes
