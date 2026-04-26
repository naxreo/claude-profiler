#!/usr/bin/env bash
# tests/run.sh — run all scenario scripts in isolated HOME directories.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${BIN:-$ROOT/dist/claude-profiler}"
SCENARIOS_DIR="$ROOT/tests/scenarios"

if [[ ! -x "$BIN" ]]; then
  echo "build first: bash build.sh" >&2
  exit 1
fi

C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
[[ -t 1 ]] || { C_RED='' C_GREEN='' C_YELLOW='' C_DIM='' C_RESET=''; }

PASS=0
FAIL=0
FAILED_NAMES=()

run_one() {
  local script="$1" name
  name="$(basename "$script" .sh)"
  local sandbox
  sandbox="$(mktemp -d -t cprof-test)"
  local log="$sandbox/output.log"
  printf '  %s%s%s ' "$C_DIM" "$name" "$C_RESET"
  if HOME="$sandbox" CPROF_TEST_BIN="$BIN" CPROF_TEST_SANDBOX="$sandbox" \
        bash "$script" >"$log" 2>&1; then
    printf '%s+ PASS%s\n' "$C_GREEN" "$C_RESET"
    PASS=$((PASS + 1))
    rm -rf "$sandbox"
  else
    printf '%sx FAIL%s\n' "$C_RED" "$C_RESET"
    printf '    %slog: %s%s\n' "$C_DIM" "$log" "$C_RESET"
    sed 's/^/    | /' "$log" | tail -20
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
  fi
}

printf '%sclaude-profiler — scenario tests%s\n' "$C_GREEN" "$C_RESET"
printf '  binary: %s\n' "$BIN"
printf '\n'

shopt -s nullglob
for s in "$SCENARIOS_DIR"/sc*.sh; do
  run_one "$s"
done

printf '\n'
if [[ "$FAIL" -eq 0 ]]; then
  printf '%s+ %d/%d 통과%s\n' "$C_GREEN" "$PASS" "$((PASS + FAIL))" "$C_RESET"
  exit 0
else
  printf '%sx %d/%d 통과 (실패: %s)%s\n' "$C_RED" "$PASS" "$((PASS + FAIL))" "${FAILED_NAMES[*]}" "$C_RESET"
  exit 1
fi
