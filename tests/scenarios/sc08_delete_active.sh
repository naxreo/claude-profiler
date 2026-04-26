#!/usr/bin/env bash
# SC-08: Cannot delete active profile.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes

# delete default while it is active
assert_exit 8 cprof delete default --yes

# but a non-active profile can be deleted (with backup)
cprof create scratch
cprof delete scratch --yes
[[ ! -d "$HOME/.claude-profiler/profiles/scratch" ]] || { echo "scratch not deleted" >&2; exit 1; }
shopt -s nullglob
backups=( "$HOME/.claude-profiler/backup/"*-delete-scratch.tgz )
[[ "${#backups[@]}" -eq 1 ]] || { echo "expected delete backup, got ${#backups[@]}" >&2; exit 1; }
