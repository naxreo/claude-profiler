#!/usr/bin/env bash
# SC-17: Default uninstall restores active profile and removes tool dir.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

seed_claude_home
cprof init --yes
cprof create work --from default
cprof switch work

# uninstall: should restore work to ~/.claude and archive default.
cprof uninstall --yes

# After uninstall, ~/.claude must be a real directory (not a symlink).
[[ -d "$HOME/.claude" && ! -L "$HOME/.claude" ]] || { echo "~/.claude not real dir" >&2; exit 1; }
[[ -f "$HOME/.claude.json" && ! -L "$HOME/.claude.json" ]] || { echo "~/.claude.json not real file" >&2; exit 1; }
assert_grep '"theme":[[:space:]]*"dark"' "$HOME/.claude/settings.json"
[[ ! -d "$HOME/.claude-profiler" ]] || { echo "tool dir still exists" >&2; exit 1; }

# Snapshot and archive must exist in HOME root.
shopt -s nullglob
snaps=( "$HOME/uninstall-snapshot-"*.tgz )
[[ "${#snaps[@]}" -ge 1 ]] || { echo "no uninstall snapshot" >&2; exit 1; }
archives=( "$HOME/claude-profiles-archive-"*.tgz )
[[ "${#archives[@]}" -ge 1 ]] || { echo "no profiles archive" >&2; exit 1; }
