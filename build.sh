#!/usr/bin/env bash
# build.sh — combine src/lib/*.sh and src/claude-profiler into dist/claude-profiler.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src"
DIST="$ROOT/dist"
VERSION="${VERSION:-0.1.0}"
BUILD_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$DIST"
OUT="$DIST/claude-profiler"

LIBS=(
  platform.sh
  ui.sh
  profile.sh
  backup.sh
  git.sh
  switch.sh
)

{
  echo '#!/usr/bin/env bash'
  echo "# claude-profiler — single-file build"
  echo "# Version: $VERSION"
  echo "# Built: $BUILD_TS"
  echo 'set -Eeuo pipefail'
  echo "CPROF_VERSION='$VERSION'"
  echo "CPROF_BUILT=1"
  echo
  for mod in "${LIBS[@]}"; do
    echo "# === lib/$mod ==="
    sed '1{/^#!.*$/d;}' "$SRC/lib/$mod"
    echo
  done
  echo '# === main ==='
  awk '
    BEGIN { skip=1 }
    skip && /^main "\$@"/ { print; next }
    /^set -Eeuo pipefail/ && skip { skip=0; next }
    !skip { print }
  ' "$SRC/claude-profiler" \
    | awk '
        # Drop the dev-mode "source lib/*" block. It is bounded by:
        #   if [[ -z "${CPROF_BUILT:-}" ]]; then ... fi
        BEGIN { in_block=0 }
        /^if \[\[ -z "\$\{CPROF_BUILT:-\}" \]\]; then$/ { in_block=1; next }
        in_block && /^fi$/ { in_block=0; next }
        !in_block { print }
      '
} >"$OUT"

chmod +x "$OUT"

mkdir -p "$DIST/completions"
cp "$SRC/completions/"* "$DIST/completions/" 2>/dev/null || true
cp "$SRC/install.sh" "$DIST/install.sh" 2>/dev/null || true
[[ -f "$DIST/install.sh" ]] && chmod +x "$DIST/install.sh"

echo "Built $OUT (version $VERSION, $(wc -l <"$OUT" | tr -d ' ') lines)"
