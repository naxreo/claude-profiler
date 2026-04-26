#!/usr/bin/env bash
# SC-02: Fresh user (no ~/.claude) — init creates an empty default profile.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

# Note: HOME is empty. Do NOT seed.
cprof init --yes

assert_symlink "$HOME/.claude"
assert_symlink "$HOME/.claude.json"
assert_dir "$HOME/.claude-profiler/profiles/default"
assert_file "$HOME/.claude-profiler/profiles/default/settings.json"
assert_file "$HOME/.claude-profiler/profiles/default/_home/.claude.json"
assert_eq "default" "$(cat "$HOME/.claude-profiler/current")"
