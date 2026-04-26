#!/usr/bin/env bash
# bootstrap-update.sh — claude-profiler 첫 업그레이드용 단독 스크립트.
#
# 'update' 명령이 없는 구버전(예: 0.1.0)을 새 버전으로 갱신할 때 한 번만 사용합니다.
# 한 번 실행해 새 바이너리가 설치되면 이후로는 'claude-profiler update' 를 쓰세요.
#
# 동작은 'claude-profiler update' 와 동일합니다 — install.sh --no-shell 로 호출하므로
# 셸 rc 마커 블록과 사용자 데이터(~/.claude-profiler/)는 절대 건드리지 않습니다.
set -Eeuo pipefail

FROM=""
REF=""
PREFIX=""           # 빈 값 = 자동 감지
YES=0

usage() {
  cat <<EOF
claude-profiler bootstrap-update — 구버전을 update 명령 없이 새 버전으로 갱신.

사용법:
  bash bootstrap-update.sh --from <git-url|path> [--ref <ref>] [--prefix <path>] [--yes]

옵션:
  --from <url|path>   업데이트 소스 (git URL 또는 로컬 디렉토리). 필수.
  --ref <branch|tag>  git URL 일 때 체크아웃할 브랜치/태그.
  --prefix <path>     설치 prefix. 미지정 시 PATH 상 claude-profiler 위치에서 자동 감지,
                      못 찾으면 \$HOME/.local 사용.
  --yes, -y           확인 프롬프트 자동 동의.
  -h, --help          이 도움말.

예:
  bash bootstrap-update.sh --from /tmp/claude-profiler-new --yes
  bash bootstrap-update.sh --from https://example.org/claude-profiler.git --ref v0.2.0
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)   FROM="$2"; shift ;;
    --ref)    REF="$2"; shift ;;
    --prefix) PREFIX="$2"; shift ;;
    --yes|-y) YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$FROM" ]]; then
  echo "x 필수 옵션이 없습니다: --from <git-url|path>" >&2
  usage >&2
  exit 2
fi

# --- 1) prefix 자동 감지 (사용자가 --prefix 안 줬을 때만) ---
if [[ -z "$PREFIX" ]]; then
  cur="$(command -v claude-profiler 2>/dev/null || true)"
  if [[ -n "$cur" ]]; then
    bin_dir="$(cd "$(dirname "$cur")" && pwd -P)"
    if [[ "$(basename "$bin_dir")" == "bin" ]]; then
      PREFIX="$(dirname "$bin_dir")"
    fi
  fi
  PREFIX="${PREFIX:-$HOME/.local}"
fi

# --- 2) 소스 확보 ---
CLEANUP_SRC=0
if [[ -d "$FROM" ]]; then
  SRC_DIR="$(cd "$FROM" && pwd -P)"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "x git 미설치 — 원격 URL 을 쓰려면 git 이 필요합니다." >&2
    exit 1
  fi
  echo "> 원격 소스 fetch: $FROM${REF:+ (ref: $REF)}"
  SRC_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t cprof-bootstrap)"
  CLEANUP_SRC=1
  clone_args=(--depth 1)
  [[ -n "$REF" ]] && clone_args+=(--branch "$REF")
  if ! git clone "${clone_args[@]}" "$FROM" "$SRC_DIR" >/dev/null 2>&1; then
    rm -rf "$SRC_DIR"
    echo "x git clone 실패: $FROM" >&2
    exit 1
  fi
fi

cleanup() {
  if [[ "$CLEANUP_SRC" -eq 1 ]]; then
    rm -rf "$SRC_DIR"
  fi
  return 0
}
trap cleanup EXIT INT TERM

# --- 3) 소스 형태 감지 ---
if [[ -f "$SRC_DIR/build.sh" ]] && [[ -d "$SRC_DIR/src" ]]; then
  MODE="rebuild"
elif [[ -f "$SRC_DIR/dist/install.sh" ]] && [[ -f "$SRC_DIR/dist/claude-profiler" ]]; then
  MODE="prebuilt"
else
  echo "x 소스 형태를 인식할 수 없습니다: $SRC_DIR" >&2
  echo "  build.sh + src/ 또는 dist/install.sh + dist/claude-profiler 가 필요합니다." >&2
  exit 1
fi

# --- 4) 버전 추출 ---
NEW_VER=""
if [[ -f "$SRC_DIR/build.sh" ]]; then
  NEW_VER="$(awk -F'"' '/^VERSION="\$\{VERSION:-/ { sub(/^\$\{VERSION:-/, "", $2); sub(/\}$/, "", $2); print $2; exit }' "$SRC_DIR/build.sh" 2>/dev/null || true)"
fi
CURRENT_VER=""
if command -v claude-profiler >/dev/null 2>&1; then
  CURRENT_VER="$(claude-profiler --version 2>/dev/null | awk '{print $2}' || true)"
fi

# --- 5) 사용자 확인 ---
echo
echo "claude-profiler bootstrap-update"
echo "  현재 버전     : ${CURRENT_VER:-(미설치/감지 불가)}"
echo "  새 버전       : ${NEW_VER:-(unknown)}"
echo "  설치 prefix   : $PREFIX"
echo "  소스          : $FROM"
echo "  모드          : $MODE"
echo "  주의          : 셸 rc 와 사용자 데이터(~/.claude-profiler/)는 보존됩니다"
echo

if [[ "$YES" -ne 1 ]]; then
  printf '진행하시겠습니까? [Y/n] '
  ans=""
  read -r ans </dev/tty 2>/dev/null || ans=""
  case "$ans" in
    n|N|no|NO) echo "취소됨."; exit 0 ;;
  esac
fi

# --- 6) 빌드(필요 시) + 설치 ---
if [[ "$MODE" == "rebuild" ]]; then
  echo "> 빌드 중..."
  if ! ( cd "$SRC_DIR" && bash build.sh ) >/dev/null 2>&1; then
    echo "x build.sh 실패. 직접 실행해 원인을 확인하세요: cd $SRC_DIR && bash build.sh" >&2
    exit 1
  fi
fi

echo "> 설치: $PREFIX"
if ! bash "$SRC_DIR/dist/install.sh" --prefix "$PREFIX" --no-shell >/dev/null; then
  echo "x install.sh 실패" >&2
  exit 1
fi

echo
if [[ -n "$NEW_VER" ]] && [[ -n "$CURRENT_VER" ]]; then
  echo "+ 업그레이드 완료: $CURRENT_VER → $NEW_VER"
else
  echo "+ 업그레이드 완료${NEW_VER:+ (버전: $NEW_VER)}"
fi
echo "  검증: claude-profiler --version"
echo "  이후 갱신: claude-profiler update --from <소스> --yes"
