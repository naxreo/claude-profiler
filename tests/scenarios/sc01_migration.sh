#!/usr/bin/env bash
# SC-01: Existing user first-run migration.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

seed_claude_home
cprof init --yes

# ~/.claude must become a symlink pointing into profiles/default.
assert_symlink "$HOME/.claude"
assert_readlink "$HOME/.claude" "$HOME/.claude-profiler/profiles/default"

# ~/.claude.json must become a symlink pointing into _home/.
assert_symlink "$HOME/.claude.json"
assert_readlink "$HOME/.claude.json" "$HOME/.claude-profiler/profiles/default/_home/.claude.json"

# Settings preserved.
assert_grep '"theme":[[:space:]]*"dark"' "$HOME/.claude/settings.json"
assert_grep 'mcpServers' "$HOME/.claude.json"

# current file equals "default".
assert_eq "default" "$(cat "$HOME/.claude-profiler/current")"

# Origin backup tarball exists and is non-empty.
shopt -s nullglob
backups=( "$HOME/.claude-profiler/backup/"*-origin.tgz )
[[ "${#backups[@]}" -eq 1 ]] || { echo "expected 1 origin backup, got ${#backups[@]}" >&2; exit 1; }
[[ -s "${backups[0]}" ]] || { echo "origin backup is empty" >&2; exit 1; }

# Original .git, if any, must NOT be in profiles/default (we converted to unified).
[[ ! -d "$HOME/.claude-profiler/profiles/default/.git" ]] || { echo "default profile still contains .git" >&2; exit 1; }
