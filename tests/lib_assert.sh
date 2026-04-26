# tests/lib_assert.sh — assertion helpers sourced by scenarios.
# Each scenario is run with HOME=<sandbox>, CPROF_TEST_BIN=<dist/claude-profiler>.

CPROF="${CPROF_TEST_BIN:?}"

cprof() { "$CPROF" "$@"; }

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [[ "$expected" != "$actual" ]]; then
    printf 'ASSERT FAIL %s\n  expected: %s\n  actual:   %s\n' "$msg" "$expected" "$actual" >&2
    return 1
  fi
}

assert_exit() {
  local expected="$1"; shift
  set +e
  "$@" >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    printf 'ASSERT FAIL exit code: expected=%d actual=%d cmd: %s\n' "$expected" "$rc" "$*" >&2
    return 1
  fi
}

assert_symlink() {
  local p="$1" msg="${2:-}"
  if [[ ! -L "$p" ]]; then
    printf 'ASSERT FAIL not a symlink: %s %s\n' "$p" "$msg" >&2
    return 1
  fi
}

assert_dir() {
  local p="$1" msg="${2:-}"
  if [[ ! -d "$p" ]]; then
    printf 'ASSERT FAIL not a directory: %s %s\n' "$p" "$msg" >&2
    return 1
  fi
}

assert_file() {
  local p="$1" msg="${2:-}"
  if [[ ! -f "$p" ]]; then
    printf 'ASSERT FAIL not a file: %s %s\n' "$p" "$msg" >&2
    return 1
  fi
}

assert_readlink() {
  local link="$1" expected="$2" msg="${3:-}"
  local got
  got="$(readlink "$link")"
  assert_eq "$expected" "$got" "$msg readlink $link"
}

assert_grep() {
  local pattern="$1" file="$2" msg="${3:-}"
  if ! grep -q "$pattern" "$file"; then
    printf 'ASSERT FAIL grep "%s" not found in %s %s\n' "$pattern" "$file" "$msg" >&2
    return 1
  fi
}

# Seed a realistic ~/.claude/ for tests that simulate "existing user".
seed_claude_home() {
  mkdir -p "$HOME/.claude/agents" "$HOME/.claude/skills" "$HOME/.claude/commands"
  printf '{"theme":"dark"}\n'    > "$HOME/.claude/settings.json"
  printf '# memory\n'             > "$HOME/.claude/CLAUDE.md"
  printf 'echo agent\n'           > "$HOME/.claude/agents/dummy.md"
  printf '{"mcpServers":{"x":{"command":"y"}}}\n' > "$HOME/.claude.json"
}
