#!/usr/bin/env bash
# SC-03: Profile roundtrip (create → switch → switch back → list).
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

seed_claude_home
cprof init --yes

cprof create work --from default
assert_dir "$HOME/.claude-profiler/profiles/work"
assert_grep '"theme":[[:space:]]*"dark"' "$HOME/.claude-profiler/profiles/work/settings.json"

cprof switch work
assert_eq "work" "$(cprof current)"
assert_readlink "$HOME/.claude" "$HOME/.claude-profiler/profiles/work"

cprof switch default
assert_eq "default" "$(cprof current)"
assert_readlink "$HOME/.claude" "$HOME/.claude-profiler/profiles/default"

# list output includes both
out="$(cprof list --quiet | sort | tr '\n' ' ')"
assert_eq "default work " "$out"
