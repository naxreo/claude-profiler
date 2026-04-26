#!/usr/bin/env bash
# SC-06: Reserved name rejection (vanilla, current as user-specified profile names for create).
set -Eeuo pipefail
. "$(dirname "$0")/../lib_assert.sh"

cprof init --yes
assert_exit 6 cprof create vanilla
assert_exit 6 cprof create current
assert_exit 6 cprof create default

# Invalid characters
assert_exit 2 cprof create "../bad"
assert_exit 2 cprof create ".hidden"
