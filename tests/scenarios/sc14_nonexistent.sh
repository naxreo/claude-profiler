#!/usr/bin/env bash
# SC-14: switch <nonexistent> → exit code 3.
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes
assert_exit 3 cprof switch nonexistent
