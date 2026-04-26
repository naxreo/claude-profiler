# lib/platform.sh — OS/shell detection and BSD/GNU portability helpers
# All functions are pure (no side effects beyond stdout/return).

cprof_os() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' macos ;;
    Linux)  printf '%s\n' linux ;;
    *)      printf '%s\n' unknown ;;
  esac
}

cprof_realpath() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target" 2>/dev/null && return 0
  fi
  if [[ -d "$target" ]]; then
    (cd "$target" 2>/dev/null && pwd -P)
  else
    local dir base
    dir="$(dirname "$target")"
    base="$(basename "$target")"
    if [[ -d "$dir" ]]; then
      printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
    else
      printf '%s\n' "$target"
    fi
  fi
}

cprof_mktempd() {
  local prefix="${1:-cprof}"
  mktemp -d 2>/dev/null || mktemp -d -t "$prefix"
}

cprof_require_cmd() {
  local missing=0 cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '필수 명령이 없습니다: %s\n' "$cmd" >&2
      missing=1
    fi
  done
  return "$missing"
}

cprof_path_inside() {
  local target="$1" boundary="$2"
  local rt rb
  rt="$(cprof_realpath "$target" 2>/dev/null || printf '%s' "$target")"
  rb="$(cprof_realpath "$boundary" 2>/dev/null || printf '%s' "$boundary")"
  case "$rt" in
    "$rb"|"$rb"/*) return 0 ;;
    *) return 1 ;;
  esac
}

cprof_cp_preserve() {
  local src="$1" dst="$2"
  if [[ "$(cprof_os)" == "macos" ]]; then
    cp -Rp "$src" "$dst"
  else
    cp -a "$src" "$dst"
  fi
}

cprof_pgrep_active_claude() {
  local self_pid=$$ parent_pid=$PPID
  local pids pid cmd
  if command -v pgrep >/dev/null 2>&1; then
    pids="$(pgrep -f 'claude' 2>/dev/null || true)"
  else
    pids="$(ps -ax -o pid=,command= 2>/dev/null | awk '/claude/ {print $1}')"
  fi
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    [[ "$pid" == "$self_pid" ]] && continue
    [[ "$pid" == "$parent_pid" ]] && continue
    cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    [[ -z "$cmd" ]] && continue
    case "$cmd" in
      *claude-profiler*) continue ;;
      *claude*) printf '%s\t%s\n' "$pid" "$cmd"; return 0 ;;
    esac
  done <<<"$pids"
  return 1
}

cprof_atomic_write() {
  local content="$1" target="$2"
  local dir tmp
  dir="$(dirname "$target")"
  tmp="$(mktemp "$dir/.cprof-write.XXXXXX")" || return 1
  printf '%s\n' "$content" >"$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$target"
}

cprof_have_git() {
  command -v git >/dev/null 2>&1
}

cprof_disk_free_mb() {
  local path="$1"
  if [[ "$(cprof_os)" == "macos" ]]; then
    df -m "$path" 2>/dev/null | awk 'NR==2 {print $4}'
  else
    df -BM --output=avail "$path" 2>/dev/null | awk 'NR==2 {gsub("M",""); print $1}' \
      || df -m "$path" 2>/dev/null | awk 'NR==2 {print $4}'
  fi
}
