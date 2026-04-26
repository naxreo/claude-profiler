# lib/ui.sh — colors, output, prompts
# Colors are activated only on TTY and respect NO_COLOR / --no-color.

CPROF_C_RED=''
CPROF_C_GREEN=''
CPROF_C_YELLOW=''
CPROF_C_BLUE=''
CPROF_C_BOLD=''
CPROF_C_DIM=''
CPROF_C_RESET=''

cprof_color_init() {
  local force="${1:-auto}"
  local enable=0
  case "$force" in
    on|yes|1) enable=1 ;;
    off|no|0) enable=0 ;;
    auto)
      if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${CPROF_NO_COLOR:-}" != "1" ]]; then
        enable=1
      fi
      ;;
  esac
  if [[ "$enable" -eq 1 ]]; then
    CPROF_C_RED=$'\033[31m'
    CPROF_C_GREEN=$'\033[32m'
    CPROF_C_YELLOW=$'\033[33m'
    CPROF_C_BLUE=$'\033[34m'
    CPROF_C_BOLD=$'\033[1m'
    CPROF_C_DIM=$'\033[2m'
    CPROF_C_RESET=$'\033[0m'
  else
    CPROF_C_RED='' CPROF_C_GREEN='' CPROF_C_YELLOW='' CPROF_C_BLUE=''
    CPROF_C_BOLD='' CPROF_C_DIM='' CPROF_C_RESET=''
  fi
}

cprof_info()    { printf '%s\n' "$*"; }
cprof_dim()     { printf '%s%s%s\n' "$CPROF_C_DIM" "$*" "$CPROF_C_RESET"; }
cprof_warn()    { printf '%s! %s%s\n' "$CPROF_C_YELLOW" "$*" "$CPROF_C_RESET" >&2; }
cprof_error()   { printf '%sx %s%s\n' "$CPROF_C_RED" "$*" "$CPROF_C_RESET" >&2; }
cprof_success() { printf '%s%s+%s %s\n' "$CPROF_C_GREEN" "$CPROF_C_BOLD" "$CPROF_C_RESET" "$*"; }
cprof_step()    { printf '%s>%s %s\n' "$CPROF_C_BLUE" "$CPROF_C_RESET" "$*"; }
cprof_header()  { printf '\n%s%s%s%s\n' "$CPROF_C_BOLD" "$CPROF_C_BLUE" "$*" "$CPROF_C_RESET"; }

cprof_die() {
  local code="$1"; shift
  cprof_error "$*"
  exit "$code"
}

cprof_confirm() {
  local prompt="$1" default="${2:-N}"
  if [[ "${CPROF_YES:-0}" == "1" ]] || [[ "${CPROF_FLAG_YES:-0}" == "1" ]]; then
    return 0
  fi
  local hint="[y/N]"
  [[ "$default" == "Y" ]] && hint="[Y/n]"
  local ans=""
  printf '%s %s ' "$prompt" "$hint" >&2
  IFS= read -r ans </dev/tty 2>/dev/null || ans=""
  if [[ -z "$ans" ]]; then
    [[ "$default" == "Y" ]] && return 0 || return 1
  fi
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

cprof_box() {
  local title="$1"; shift
  printf '\n%s%s %s %s\n' "$CPROF_C_BOLD" "$CPROF_C_BLUE" "$title" "$CPROF_C_RESET"
  printf '%s%s%s\n' "$CPROF_C_DIM" "----------------------------------------" "$CPROF_C_RESET"
  printf '%s\n' "$@"
  printf '%s%s%s\n' "$CPROF_C_DIM" "----------------------------------------" "$CPROF_C_RESET"
}

cprof_kv() {
  local key="$1" value="$2"
  printf '  %s%-22s%s %s\n' "$CPROF_C_DIM" "$key" "$CPROF_C_RESET" "$value"
}
