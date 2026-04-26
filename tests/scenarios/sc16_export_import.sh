#!/usr/bin/env bash
# SC-16: export then import roundtrip.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

seed_claude_home
cprof init --yes

cprof export default "$HOME/default-export.tgz"
[[ -s "$HOME/default-export.tgz" ]] || { echo "export tgz empty" >&2; exit 1; }

# Import as a different name.
cprof import "$HOME/default-export.tgz" --name imported
assert_dir "$HOME/.claude-profiler/profiles/imported"
assert_grep '"theme":"dark"' "$HOME/.claude-profiler/profiles/imported/settings.json"
