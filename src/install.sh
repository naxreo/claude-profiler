#!/usr/bin/env bash
# install.sh — install claude-profiler binary, completions, and shell hooks.
set -Eeuo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/claude-profiler"
COMPLETIONS_DIR="$SHARE_DIR/completions"

MARKER_BEGIN='# >>> claude-profiler >>>'
MARKER_END='# <<< claude-profiler <<<'

usage() {
  cat <<EOF
claude-profiler installer

옵션:
  --prefix <path>     설치 prefix (기본: \$HOME/.local)
  --no-shell          셸 rc 파일을 자동 수정하지 않음
  --uninstall         설치한 파일 제거 + 셸 rc 마커 줄 제거
  -h, --help          이 도움말

설치되는 위치:
  $PREFIX/bin/claude-profiler
  $PREFIX/share/claude-profiler/completions/...
EOF
}

OPT_NO_SHELL=0
OPT_UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; BIN_DIR="$PREFIX/bin"; SHARE_DIR="$PREFIX/share/claude-profiler"; COMPLETIONS_DIR="$SHARE_DIR/completions"; shift ;;
    --no-shell) OPT_NO_SHELL=1 ;;
    --uninstall) OPT_UNINSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
  shift
done

detect_os() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' macos ;;
    Linux)  printf '%s\n' linux ;;
    *)      printf '%s\n' unknown ;;
  esac
}

shell_rc_path() {
  local sh
  sh="$(basename "${SHELL:-bash}")"
  case "$sh" in
    bash)
      if [[ "$(detect_os)" == "macos" ]]; then printf '%s\n' "$HOME/.bash_profile"
      else printf '%s\n' "$HOME/.bashrc"; fi
      ;;
    zsh) printf '%s\n' "$HOME/.zshrc" ;;
    fish) printf '%s\n' "$HOME/.config/fish/config.fish" ;;
    *)    printf '%s\n' "" ;;
  esac
}

remove_marker_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local tmp
  tmp="$(mktemp "$file.XXXXXX")"
  # NOTE: do not use 'BEG'/'END' as awk -v names — END is an awk reserved word.
  awk -v mbeg="$MARKER_BEGIN" -v mend="$MARKER_END" '
    $0 == mbeg { skip=1; next }
    $0 == mend { skip=0; next }
    !skip { print }
  ' "$file" >"$tmp" && mv "$tmp" "$file"
}

write_marker_block() {
  local file="$1" content="$2"
  remove_marker_block "$file"
  {
    printf '\n%s\n' "$MARKER_BEGIN"
    printf '%s\n' "$content"
    printf '%s\n' "$MARKER_END"
  } >>"$file"
}

shell_block_for() {
  local sh="$1"
  case "$sh" in
    bash)
      cat <<EOF
export PATH="$BIN_DIR:\$PATH"
[ -f "$COMPLETIONS_DIR/claude-profiler.bash" ] && . "$COMPLETIONS_DIR/claude-profiler.bash"
EOF
      ;;
    zsh)
      cat <<EOF
export PATH="$BIN_DIR:\$PATH"
fpath=("$COMPLETIONS_DIR" \$fpath)
autoload -Uz compinit && compinit -i
EOF
      ;;
    fish)
      cat <<EOF
set -gx PATH $BIN_DIR \$PATH
EOF
      ;;
  esac
}

do_uninstall() {
  rm -f "$BIN_DIR/claude-profiler"
  rm -rf "$SHARE_DIR"
  rm -f "$HOME/.config/fish/completions/claude-profiler.fish"
  rm -f "$HOME/.config/fish/functions/claude-profiler.fish"
  for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    remove_marker_block "$rc"
  done
  echo "+ claude-profiler 설치 파일을 제거했습니다."
  echo "  ~/.claude-profiler/ (사용자 데이터)는 보존되었습니다."
  echo "  데이터까지 제거하려면: claude-profiler uninstall (설치된 상태일 때) 또는 수동 제거."
}

do_install() {
  [[ -f "$HERE/claude-profiler" ]] || { echo "claude-profiler 바이너리가 없습니다: $HERE/claude-profiler" >&2; exit 1; }

  mkdir -p "$BIN_DIR" "$COMPLETIONS_DIR"
  install -m 0755 "$HERE/claude-profiler" "$BIN_DIR/claude-profiler"

  if [[ -d "$HERE/completions" ]]; then
    cp "$HERE/completions/"* "$COMPLETIONS_DIR/" 2>/dev/null || true
    chmod 0644 "$COMPLETIONS_DIR/"* 2>/dev/null || true
  fi

  if [[ -f "$COMPLETIONS_DIR/claude-profiler.fish" ]]; then
    mkdir -p "$HOME/.config/fish/completions" "$HOME/.config/fish/functions"
    cp "$COMPLETIONS_DIR/claude-profiler.fish" "$HOME/.config/fish/completions/claude-profiler.fish"
  fi

  echo "+ 설치됨: $BIN_DIR/claude-profiler"
  echo "+ 완성:   $COMPLETIONS_DIR/"

  if [[ "$OPT_NO_SHELL" -eq 1 ]]; then
    echo
    echo "  --no-shell 지정: PATH/완성을 수동으로 등록하세요."
    return
  fi

  local rc sh
  rc="$(shell_rc_path)"
  sh="$(basename "${SHELL:-bash}")"
  if [[ -z "$rc" ]]; then
    echo "  알 수 없는 셸: $SHELL — 수동 등록이 필요합니다."
    return
  fi
  mkdir -p "$(dirname "$rc")"
  touch "$rc"
  local block
  block="$(shell_block_for "$sh")"
  write_marker_block "$rc" "$block"
  echo "+ 셸 설정: $rc 에 마커 블록 추가됨"
  echo
  echo "  새 셸을 열거나 다음 명령으로 즉시 적용하세요:"
  if [[ "$sh" == "fish" ]]; then
    echo "    source $rc"
  else
    echo "    source $rc"
  fi
  echo
  echo "  검증: claude-profiler version"
}

if [[ "$OPT_UNINSTALL" -eq 1 ]]; then
  do_uninstall
else
  do_install
fi
