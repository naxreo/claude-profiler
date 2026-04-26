#!/usr/bin/env bash
# SC-04: switch vanilla auto-creates the profile if missing.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes

# vanilla does not exist yet.
[[ ! -d "$HOME/.claude-profiler/profiles/vanilla" ]] || { echo "vanilla pre-existed" >&2; exit 1; }

cprof switch vanilla
assert_dir "$HOME/.claude-profiler/profiles/vanilla"
assert_file "$HOME/.claude-profiler/profiles/vanilla/_home/.claude.json"
assert_eq "vanilla" "$(cprof current)"
assert_readlink "$HOME/.claude" "$HOME/.claude-profiler/profiles/vanilla"

# Re-running switch vanilla when it already exists must not fail.
cprof switch default
cprof switch vanilla
assert_eq "vanilla" "$(cprof current)"
