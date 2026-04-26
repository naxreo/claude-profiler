# lib/git.sh — Unified git repository helpers.
# The tool itself does not invoke git for daily backup; users run git manually.
# This module only handles initialization at `init` time.

cprof_git_extract_origin() {
  local dir="$1"
  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" config --get remote.origin.url 2>/dev/null || true
  elif [[ -f "$dir/.git" ]]; then
    git -C "$dir" config --get remote.origin.url 2>/dev/null || true
  fi
}

cprof_git_write_gitignore() {
  local root="$1"
  cat >"$root/.gitignore" <<'EOF'
# claude-profiler — unified repository ignores

# Tool metadata (per-machine; not synced)
current
.lock
config.json
backup/
origin-backup-*.tgz

# Volatile / cache (regeneratable; not part of profile)
profiles/*/cache/
profiles/*/image-cache/
profiles/*/paste-cache/
profiles/*/shell-snapshots/
profiles/*/session-env/
profiles/*/telemetry/
profiles/*/statsig/
profiles/*/debug/
profiles/*/ide/
profiles/*/downloads/
profiles/*/stats-cache.json
profiles/*/mcp-needs-auth-cache.json

# Security-sensitive (never push to remote)
profiles/*/.credentials.json
profiles/*/_home/.credentials.json
EOF
}

# cprof_git_init_unified <root>
# SR-06: .gitignore must be written BEFORE `git add`.
cprof_git_init_unified() {
  local root="$1"
  cprof_have_git || return 13
  cprof_git_write_gitignore "$root"
  (
    cd "$root" || exit 13
    git init -q -b main 2>/dev/null || git init -q
    if [[ "$(git symbolic-ref -q HEAD)" != "refs/heads/main" ]]; then
      git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
    fi
    if ! git config user.email >/dev/null 2>&1; then
      git config user.email "claude-profiler@local"
    fi
    if ! git config user.name >/dev/null 2>&1; then
      git config user.name "claude-profiler"
    fi
    git add .gitignore profiles/ 2>/dev/null || true
    git commit -q -m "Initial unified profile repository" 2>/dev/null || true
  ) || return 13
  return 0
}

# cprof_git_post_init_hint <origin_url>
# init 종료 후 사용자 안내 출력. 빈 origin_url이면 origin 안내 생략.
cprof_git_post_init_hint() {
  local origin_url="${1:-}"
  cprof_header "다음 단계"
  cprof_info "  통합 저장소를 다른 머신과 동기화하려면:"
  cprof_info "    cd $HOME/.claude-profiler"
  cprof_info "    git add profiles/ && git commit -m \"...\" && git push"
  if [[ -n "$origin_url" ]]; then
    cprof_info ""
    cprof_info "  기존 원격 저장소를 통합 저장소에서 사용하려면:"
    cprof_info "    cd $HOME/.claude-profiler"
    cprof_info "    git remote add origin $origin_url"
    cprof_warn "    git push -u origin main --force   # 기존 history와 다르므로 force 필요"
    cprof_warn "    (협업자/다른 머신과 충돌 여부를 먼저 확인하세요)"
  fi
  cprof_info ""
  cprof_info "  다른 시스템에서 가져오려면:"
  cprof_info "    git clone <URL> ~/.claude-profiler"
  cprof_info "    claude-profiler switch default"
}
