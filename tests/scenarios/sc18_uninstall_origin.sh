#!/usr/bin/env bash
# SC-18: uninstall --restore-origin reverts to the very first ~/.claude.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

seed_claude_home
# Make a recognizable marker in original .claude that should reappear after revert.
echo "MARKER" > "$HOME/.claude/marker.txt"

cprof init --yes
cprof create work
cprof switch work
# Add some change to current profile that should NOT exist after revert.
echo "should-not-exist" > "$HOME/.claude/settings.json"

cprof uninstall --restore-origin --yes

# After origin revert, ~/.claude must be a real dir, with the original marker file.
assert_file "$HOME/.claude/marker.txt"
assert_grep '"theme":"dark"' "$HOME/.claude/settings.json"
[[ ! -d "$HOME/.claude-profiler" ]] || { echo "tool dir not removed" >&2; exit 1; }
