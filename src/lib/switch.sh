# lib/switch.sh — Lock, active-session check, and the two-symlink transaction.
# This module hosts the most safety-critical code (SR-01, SR-03, SR-04, SR-07).

CPROF_LOCK_TIMEOUT="${CPROF_LOCK_TIMEOUT:-10}"
CPROF_LOCK_PATH=""

cprof_lock_path() {
  printf '%s/.lock\n' "$(cprof_profile_root)"
}

# cprof_lock_acquire [timeout_seconds]
# Atomic create with PID:timestamp. Stale detection by PID liveness or 1h age.
cprof_lock_acquire() {
  local timeout="${1:-$CPROF_LOCK_TIMEOUT}"
  local lock="$(cprof_lock_path)"
  local i pid_ts pid age now
  mkdir -p "$(dirname "$lock")"
  for ((i=0; i<timeout; i++)); do
    if ( set -C; printf '%s:%s\n' "$$" "$(date +%s)" >"$lock" ) 2>/dev/null; then
      CPROF_LOCK_PATH="$lock"
      return 0
    fi
    pid_ts="$(cat "$lock" 2>/dev/null || true)"
    pid="${pid_ts%%:*}"
    if [[ -n "$pid" ]] && [[ "$pid" =~ ^[0-9]+$ ]]; then
      if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$lock"
        continue
      fi
      now="$(date +%s)"
      age=$(( now - ${pid_ts##*:} ))
      if [[ "$age" -gt 3600 ]]; then
        rm -f "$lock"
        continue
      fi
    else
      rm -f "$lock"
      continue
    fi
    sleep 1
  done
  return 4
}

cprof_lock_release() {
  if [[ -n "$CPROF_LOCK_PATH" ]] && [[ -f "$CPROF_LOCK_PATH" ]]; then
    local pid_ts pid
    pid_ts="$(cat "$CPROF_LOCK_PATH" 2>/dev/null || true)"
    pid="${pid_ts%%:*}"
    if [[ "$pid" == "$$" ]]; then
      rm -f "$CPROF_LOCK_PATH"
    fi
  fi
  CPROF_LOCK_PATH=""
}

# cprof_check_no_active_claude [--force]
cprof_check_no_active_claude() {
  local force="${1:-0}"
  if [[ "$force" == "1" ]]; then
    return 0
  fi
  local hit
  if hit="$(cprof_pgrep_active_claude)"; then
    cprof_error "활성 Claude Code 세션이 감지되었습니다."
    cprof_dim "  $hit"
    cprof_info "Claude Code 종료 후 재시도하거나 --force 로 우회하세요. (--force는 진행 중인 작업이 손상될 수 있습니다)"
    return 5
  fi
  return 0
}

# cprof_link_target <name>
# 두 심볼릭 링크가 가리켜야 할 정상 타겟 경로 출력.
cprof_link_target_claude() {
  printf '%s\n' "$(cprof_profile_dir "$1")"
}
cprof_link_target_claude_json() {
  printf '%s/_home/.claude.json\n' "$(cprof_profile_dir "$1")"
}

# cprof_verify_links <profile-name>
# 두 링크가 정상이고 예상 타겟을 가리키는지 검증.
cprof_verify_links() {
  local name="$1"
  local exp_claude exp_json got_claude got_json
  exp_claude="$(cprof_link_target_claude "$name")"
  exp_json="$(cprof_link_target_claude_json "$name")"
  [[ -L "$HOME/.claude" ]] || return 12
  [[ -L "$HOME/.claude.json" ]] || return 12
  got_claude="$(readlink "$HOME/.claude")"
  got_json="$(readlink "$HOME/.claude.json")"
  [[ "$got_claude" == "$exp_claude" ]] || return 12
  [[ "$got_json" == "$exp_json" ]] || return 12
  [[ -d "$HOME/.claude/" ]] || return 12
  [[ -f "$HOME/.claude.json" ]] || return 12
  return 0
}

# Internal: clean up temporary links if mid-transaction abort.
_cprof_cleanup_tmp_links() {
  rm -f "$HOME/.claude.cprof-new" 2>/dev/null || true
  rm -f "$HOME/.claude.json.cprof-new" 2>/dev/null || true
}

# Internal rollback after partial mv.
_cprof_rollback_links() {
  local prev_claude="$1" prev_json="$2"
  if [[ -n "$prev_claude" ]]; then
    rm -f "$HOME/.claude" 2>/dev/null || true
    ln -s "$prev_claude" "$HOME/.claude" 2>/dev/null || true
  fi
  if [[ -n "$prev_json" ]]; then
    rm -f "$HOME/.claude.json" 2>/dev/null || true
    ln -s "$prev_json" "$HOME/.claude.json" 2>/dev/null || true
  fi
  _cprof_cleanup_tmp_links
}

# cprof_relink_two <profile-name>
# SR-01: 두 링크 갱신 사이의 비원자 구간을 최소화.
#
# Note: macOS BSD `mv -f` follows directory symlinks (it tries to move INTO the
# pointed directory rather than replacing the link), so `mv` cannot be used to
# atomically replace a symlink that points to a directory. We use `ln -snf`
# (`-n` = no-dereference) instead, which both macOS and GNU ln support.
# `ln -snf` is not strictly atomic but is the safe portable idiom for this case.
# Active-session blocking is the primary defense against the brief inconsistency.
cprof_relink_two() {
  local name="$1"
  local new_claude new_json
  new_claude="$(cprof_link_target_claude "$name")"
  new_json="$(cprof_link_target_claude_json "$name")"

  [[ -d "$new_claude" ]] || { cprof_error "대상 프로파일 디렉토리가 없습니다: $new_claude"; return 11; }
  [[ -f "$new_json" ]]   || { cprof_error "대상 .claude.json이 없습니다: $new_json"; return 11; }

  local prev_claude prev_json
  prev_claude="$(readlink "$HOME/.claude" 2>/dev/null || true)"
  prev_json="$(readlink "$HOME/.claude.json" 2>/dev/null || true)"

  # ↓ 두 줄은 인접하게 유지 (SR-01). 첫 줄 실패는 바로 종료, 두 번째 실패는 즉시 롤백.
  ln -snf "$new_claude" "$HOME/.claude" || return 11
  ln -snf "$new_json"   "$HOME/.claude.json" || { _cprof_rollback_links "$prev_claude" "$prev_json"; return 11; }

  return 0
}

# cprof_switch_to <name> [--force]
cprof_switch_to() {
  local target="$1"
  local force="${2:-0}"

  cprof_profile_validate_name "$target" use || return $?

  cprof_lock_acquire || { cprof_error "다른 claude-profiler 실행 중입니다."; return 4; }
  trap 'cprof_lock_release' EXIT INT TERM

  cprof_check_no_active_claude "$force" || { cprof_lock_release; trap - EXIT INT TERM; return 5; }

  if [[ "$target" == "vanilla" ]] && ! cprof_profile_exists "vanilla"; then
    cprof_step "vanilla 프로파일이 없어 새로 생성합니다."
    cprof_profile_seed_empty "vanilla" || { cprof_lock_release; trap - EXIT INT TERM; return 20; }
  fi

  if ! cprof_profile_exists "$target"; then
    cprof_error "프로파일이 없습니다: $target"
    local available
    available="$(cprof_profile_list | tr '\n' ' ')"
    [[ -n "$available" ]] && cprof_dim "사용 가능: $available"
    cprof_lock_release; trap - EXIT INT TERM
    return 3
  fi

  local current
  current="$(cprof_profile_current)"
  if [[ "$current" == "$target" ]]; then
    cprof_info "이미 활성 프로파일입니다: $target"
    cprof_lock_release; trap - EXIT INT TERM
    return 0
  fi

  if [[ -e "$HOME/.claude" ]] && [[ ! -L "$HOME/.claude" ]]; then
    cprof_error "~/.claude 가 일반 디렉토리입니다. claude-profiler 외부에서 변경되었거나 init이 필요합니다."
    cprof_lock_release; trap - EXIT INT TERM
    return 11
  fi
  if [[ -L "$HOME/.claude" ]]; then
    local rt
    rt="$(readlink "$HOME/.claude")"
    if ! cprof_path_inside "$rt" "$(cprof_profile_root)"; then
      cprof_error "~/.claude 가 claude-profiler 영역 외부를 가리킵니다: $rt"
      cprof_lock_release; trap - EXIT INT TERM
      return 11
    fi
  fi

  local prev_claude prev_json
  prev_claude="$(readlink "$HOME/.claude" 2>/dev/null || true)"
  prev_json="$(readlink "$HOME/.claude.json" 2>/dev/null || true)"
  cprof_backup_state switch \
    "previous_profile=$current" \
    "previous_claude_target=$prev_claude" \
    "previous_claude_json_target=$prev_json" \
    "new_profile=$target" >/dev/null

  if ! cprof_relink_two "$target"; then
    cprof_error "스위칭 실패. 이전 상태로 롤백되었습니다."
    cprof_lock_release; trap - EXIT INT TERM
    return 11
  fi

  cprof_profile_set_current "$target" || {
    _cprof_rollback_links "$prev_claude" "$prev_json"
    cprof_error "current 파일 갱신 실패. 롤백했습니다."
    cprof_lock_release; trap - EXIT INT TERM
    return 11
  }

  if ! cprof_verify_links "$target"; then
    _cprof_rollback_links "$prev_claude" "$prev_json"
    cprof_profile_set_current "$current" 2>/dev/null || true
    cprof_error "스위칭 검증 실패. 롤백했습니다."
    cprof_lock_release; trap - EXIT INT TERM
    return 12
  fi

  cprof_lock_release
  trap - EXIT INT TERM
  cprof_success "$current → $target 전환 완료"
  return 0
}
