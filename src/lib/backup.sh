# lib/backup.sh — backup creation, listing, pruning, restoration helpers.

cprof_backup_dir() {
  local d="$(cprof_profile_root)/backup"
  mkdir -p "$d"
  printf '%s\n' "$d"
}

cprof_backup_ts() {
  date +%Y%m%d-%H%M%S
}

# cprof_backup_create_origin
# init 시 원본 ~/.claude + ~/.claude.json 전체 백업.
# Echoes the resulting tarball path on stdout.
cprof_backup_create_origin() {
  local ts="$(cprof_backup_ts)"
  local out="$(cprof_backup_dir)/${ts}-origin.tgz"
  local sources=()
  [[ -e "$HOME/.claude" ]]      && sources+=(.claude)
  [[ -e "$HOME/.claude.json" ]] && sources+=(.claude.json)
  if [[ "${#sources[@]}" -eq 0 ]]; then
    : >"$out"
    printf '%s\n' "$out"
    return 0
  fi
  if ! tar -czf "$out" -C "$HOME" "${sources[@]}" 2>/dev/null; then
    rm -f "$out"
    return 21
  fi
  [[ -s "$out" ]] || { rm -f "$out"; return 21; }
  printf '%s\n' "$out"
}

# cprof_backup_create_profile <profile-name> <action>
# delete/import 시 특정 프로파일 디렉토리를 통째 보존.
cprof_backup_create_profile() {
  local name="$1" action="$2"
  local ts="$(cprof_backup_ts)"
  local out="$(cprof_backup_dir)/${ts}-${action}-${name}.tgz"
  local profiles="$(cprof_profile_root)/profiles"
  [[ -d "$profiles/$name" ]] || return 3
  if ! tar -czf "$out" -C "$profiles" "$name" 2>/dev/null; then
    rm -f "$out"
    return 21
  fi
  [[ -s "$out" ]] || { rm -f "$out"; return 21; }
  printf '%s\n' "$out"
}

# cprof_backup_state <action> <kv...>
# switch/rename 시 가벼운 텍스트 상태 기록.
cprof_backup_state() {
  local action="$1"; shift
  local ts="$(cprof_backup_ts)"
  local out="$(cprof_backup_dir)/${ts}-${action}.txt"
  {
    printf 'timestamp=%s\n' "$ts"
    printf 'action=%s\n' "$action"
    local kv
    for kv in "$@"; do
      printf '%s\n' "$kv"
    done
  } >"$out"
  printf '%s\n' "$out"
}

cprof_backup_list() {
  local d="$(cprof_backup_dir)"
  local f size mtime
  shopt -s nullglob 2>/dev/null || true
  for f in "$d"/*; do
    [[ -f "$f" ]] || continue
    if [[ "$(cprof_os)" == "macos" ]]; then
      size="$(stat -f %z "$f" 2>/dev/null || echo 0)"
      mtime="$(stat -f %Sm -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null || echo '?')"
    else
      size="$(stat -c %s "$f" 2>/dev/null || echo 0)"
      mtime="$(stat -c %y "$f" 2>/dev/null | cut -d. -f1)"
    fi
    printf '%s\t%s\t%s\n' "$mtime" "$size" "$(basename "$f")"
  done
}

# cprof_backup_age_days <file>
cprof_backup_age_days() {
  local f="$1"
  [[ -f "$f" ]] || { printf '0\n'; return; }
  local now ftime
  now="$(date +%s)"
  if [[ "$(cprof_os)" == "macos" ]]; then
    ftime="$(stat -f %m "$f" 2>/dev/null || echo "$now")"
  else
    ftime="$(stat -c %Y "$f" 2>/dev/null || echo "$now")"
  fi
  printf '%s\n' "$(( (now - ftime) / 86400 ))"
}

cprof_backup_count_old() {
  local days="${1:-30}"
  local d="$(cprof_backup_dir)" f age count=0
  shopt -s nullglob 2>/dev/null || true
  for f in "$d"/*; do
    [[ -f "$f" ]] || continue
    age="$(cprof_backup_age_days "$f")"
    [[ "$age" -gt "$days" ]] && count=$((count + 1))
  done
  printf '%s\n' "$count"
}

cprof_backup_prune() {
  local days="${1:-30}"
  local d="$(cprof_backup_dir)" f age removed=0
  shopt -s nullglob 2>/dev/null || true
  for f in "$d"/*; do
    [[ -f "$f" ]] || continue
    age="$(cprof_backup_age_days "$f")"
    if [[ "$age" -gt "$days" ]]; then
      rm -f "$f" && removed=$((removed + 1))
    fi
  done
  printf '%s\n' "$removed"
}

# cprof_backup_validate_tar_safe <tgz>
# tar 추출 시 절대경로/상위경로 방어. SR-05.
cprof_backup_validate_tar_safe() {
  local tgz="$1"
  [[ -f "$tgz" ]] || return 2
  if tar -tzf "$tgz" 2>/dev/null | grep -qE '^/|(^|/)\.\.(/|$)'; then
    return 1
  fi
  return 0
}

# cprof_backup_find_oldest_origin
# 가장 오래된 origin 백업을 출력. 없으면 비어있는 출력.
cprof_backup_find_oldest_origin() {
  local d="$(cprof_backup_dir)"
  shopt -s nullglob 2>/dev/null || true
  ls -1tr "$d"/*-origin.tgz 2>/dev/null | head -n1
}

# cprof_backup_find_newest_origin
cprof_backup_find_newest_origin() {
  local d="$(cprof_backup_dir)"
  ls -1t "$d"/*-origin.tgz 2>/dev/null | head -n1
}
