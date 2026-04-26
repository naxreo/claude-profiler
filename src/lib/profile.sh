# lib/profile.sh — profile CRUD operations.
# Uses CPROF_ROOT (set in main entry) as the profiler root directory.

CPROF_RESERVED_NAMES=(vanilla current default)
CPROF_NAME_MAX_LEN=64

cprof_profile_root() {
  printf '%s\n' "${CPROF_ROOT:-$HOME/.claude-profiler}"
}

cprof_profile_dir() {
  printf '%s/profiles/%s\n' "$(cprof_profile_root)" "$1"
}

cprof_profile_exists() {
  [[ -d "$(cprof_profile_dir "$1")" ]]
}

cprof_profile_validate_name() {
  local name="$1" context="${2:-create}"
  if [[ -z "$name" ]]; then
    cprof_error "프로파일 이름이 비어있습니다."
    return 2
  fi
  if [[ "${#name}" -gt "$CPROF_NAME_MAX_LEN" ]]; then
    cprof_error "이름이 너무 깁니다 (최대 $CPROF_NAME_MAX_LEN 자): $name"
    return 2
  fi
  if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
    cprof_error "이름은 영문/숫자/_/-만 허용되며 영문·숫자로 시작해야 합니다: $name"
    return 2
  fi
  if [[ "$name" == "current" ]]; then
    cprof_error "예약어는 사용할 수 없습니다: current (메타 파일명과 충돌)"
    return 6
  fi
  if [[ "$context" == "create" ]]; then
    case "$name" in
      vanilla|default)
        cprof_error "예약어는 사용할 수 없습니다: $name (자동 생성 전용 이름)"
        return 6
        ;;
    esac
  fi
  return 0
}

cprof_profile_list() {
  local root profiles_dir
  root="$(cprof_profile_root)"
  profiles_dir="$root/profiles"
  [[ -d "$profiles_dir" ]] || return 0
  find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | awk -F/ '{print $NF}' \
    | sort
}

cprof_profile_current() {
  local f="$(cprof_profile_root)/current"
  if [[ -f "$f" ]]; then
    head -n1 "$f" | tr -d '\r\n' | tr -d ' '
  fi
}

cprof_profile_set_current() {
  local name="$1"
  local root="$(cprof_profile_root)"
  cprof_atomic_write "$name" "$root/current"
}

cprof_profile_seed_empty() {
  local name="$1"
  local dir="$(cprof_profile_dir "$name")"
  mkdir -p "$dir/_home" || return 20
  if [[ ! -f "$dir/settings.json" ]]; then
    printf '{}\n' >"$dir/settings.json"
  fi
  if [[ ! -f "$dir/_home/.claude.json" ]]; then
    printf '{}\n' >"$dir/_home/.claude.json"
  fi
  chmod 0700 "$dir" 2>/dev/null || true
}

cprof_profile_create() {
  local name="$1" from="${2:-}" empty="${3:-0}"
  cprof_profile_validate_name "$name" || return $?
  if cprof_profile_exists "$name"; then
    cprof_error "프로파일이 이미 존재합니다: $name"
    return 7
  fi
  local target_dir="$(cprof_profile_dir "$name")"
  if [[ -n "$from" ]]; then
    cprof_profile_exists "$from" || { cprof_error "원본 프로파일이 없습니다: $from"; return 3; }
    mkdir -p "$(dirname "$target_dir")"
    cprof_cp_preserve "$(cprof_profile_dir "$from")" "$target_dir" || return 20
  elif [[ "$empty" == "1" ]] || [[ -z "$from" ]]; then
    cprof_profile_seed_empty "$name" || return 20
  fi
  chmod 0700 "$target_dir" 2>/dev/null || true
  return 0
}

cprof_profile_delete() {
  local name="$1"
  cprof_profile_validate_name "$name" use || return $?
  local current
  current="$(cprof_profile_current)"
  if [[ "$name" == "$current" ]]; then
    cprof_error "활성 프로파일은 삭제할 수 없습니다: $name (다른 프로파일로 먼저 switch 하세요)"
    return 8
  fi
  if ! cprof_profile_exists "$name"; then
    cprof_error "프로파일이 없습니다: $name"
    return 3
  fi
  rm -rf "$(cprof_profile_dir "$name")"
}

cprof_profile_rename() {
  local old="$1" new="$2"
  cprof_profile_validate_name "$old" use    || return $?
  cprof_profile_validate_name "$new" create || return $?
  local current
  current="$(cprof_profile_current)"
  if [[ "$old" == "$current" ]]; then
    cprof_error "활성 프로파일은 이름을 변경할 수 없습니다: $old"
    return 8
  fi
  cprof_profile_exists "$old" || { cprof_error "원본 프로파일이 없습니다: $old"; return 3; }
  if cprof_profile_exists "$new"; then
    cprof_error "대상 이름이 이미 존재합니다: $new"
    return 7
  fi
  mv "$(cprof_profile_dir "$old")" "$(cprof_profile_dir "$new")"
}
