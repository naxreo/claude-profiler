#!/usr/bin/env bash
# SC-20: init when already initialized must reject (exit 1).
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes
assert_exit 1 cprof init --yes
