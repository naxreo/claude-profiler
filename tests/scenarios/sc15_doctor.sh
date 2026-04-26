#!/usr/bin/env bash
# SC-15: doctor diagnoses corrupted-link state when ~/.claude symlink is missing.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes

# Break the link state on purpose.
rm -f "$HOME/.claude"

out="$(cprof doctor 2>&1 || true)"
echo "$out" | grep -q "corrupted-link" || { echo "doctor did not detect corruption" >&2; echo "$out" >&2; exit 1; }
