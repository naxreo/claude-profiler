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
  cprof_inject_session_hook "$dir/settings.json" || true
  chmod 0700 "$dir" 2>/dev/null || true
}

# cprof_inject_session_hook <settings.json path>
# settings.json 에 SessionStart 훅을 주입한다 (idempotent).
# - 파일이 없거나 사실상 빈 객체({})면 우리 훅만 가진 새 파일 작성.
# - jq 가용 + 사용자 내용 존재: jq 로 안전 병합.
# - jq 없음 + 사용자 내용 존재: 사용자 JSON 손상 위험 → 경고 후 건너뜀.
# 항상 0 반환 (init/seed 흐름을 깨지 않음). 실제 실패 시 경고만.
cprof_inject_session_hook() {
  local settings="$1"
  local marker='claude-profiler --session-banner'

  if [[ -f "$settings" ]] && grep -q "$marker" "$settings" 2>/dev/null; then
    return 0
  fi

  local fresh
  fresh='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "claude-profiler --session-banner" }
        ]
      }
    ]
  }
}'

  if [[ ! -s "$settings" ]] || [[ "$(tr -d '[:space:]' <"$settings")" == "{}" ]]; then
    printf '%s\n' "$fresh" >"$settings"
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    local tmp="${settings}.cprof-tmp.$$"
    if jq '
      .hooks //= {}
      | .hooks.SessionStart //= []
      | .hooks.SessionStart += [{
          "matcher": "startup|resume",
          "hooks": [{ "type": "command", "command": "claude-profiler --session-banner" }]
        }]
    ' "$settings" >"$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      return 0
    fi
    rm -f "$tmp"
    cprof_warn "settings.json JSON 병합 실패 — SessionStart 훅 주입 건너뜀: $settings"
    return 0
  fi

  cprof_warn "기존 settings.json 에 내용이 있고 jq 가 없어 SessionStart 배너 훅 주입을 건너뜁니다: $settings"
  cprof_dim "  수동 추가 방법은 docs/USAGE.md '세션 배너' 섹션 참고."
  return 0
}

cprof_profile_create() {
  local name="$1" from="${2:-}" empty="${3:-0}"
  cprof_profile_validate_name "$name" || return $?
  if cprof_profile_exists "$name"; then
    cprof_error "프로파일이 이미 존재합니다: $name"
    return 7
  fi
  local target_dir="$(cprof_profile_dir "$name")"
  if [[ "$empty" == "1" ]]; then
    cprof_profile_seed_empty "$name" || return 20
  elif [[ -n "$from" ]]; then
    cprof_profile_exists "$from" || { cprof_error "원본 프로파일이 없습니다: $from"; return 3; }
    mkdir -p "$(dirname "$target_dir")"
    cprof_cp_preserve "$(cprof_profile_dir "$from")" "$target_dir" || return 20
  else
    cprof_error "내부 오류: from 또는 empty 중 하나가 지정되어야 합니다."
    return 2
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
