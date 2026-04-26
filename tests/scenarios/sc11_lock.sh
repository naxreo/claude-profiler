#!/usr/bin/env bash
# SC-11: Lock contention is rejected with exit 4 within timeout.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes
cprof create work

# Simulate another live process holding the lock by writing our own PID
# (which is alive). With a short timeout the second invocation must give up.
mkdir -p "$HOME/.claude-profiler"
printf '%s:%s\n' "$$" "$(date +%s)" >"$HOME/.claude-profiler/.lock"

set +e
CPROF_LOCK_TIMEOUT=2 cprof switch work >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 4 ]] || { echo "expected exit 4, got $rc" >&2; exit 1; }

rm -f "$HOME/.claude-profiler/.lock"
