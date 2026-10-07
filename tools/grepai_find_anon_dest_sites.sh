#!/usr/bin/env bash
# tools/find_anon_dest_grepai.sh
#
# Runs a fixed set of semantic queries (via grepai) that target the
# anonymous-destination refactor. Complementary to find_anon_dest_sites.sh:
# grep gives the exhaustive literal checklist, grepai gives the
# semantically-adjacent sites the grep won't find.
#
# Usage:
#   tools/find_anon_dest_grepai.sh              # run all queries, tee to .analysis/grepai/all.txt
#   tools/find_anon_dest_grepai.sh --no-file    # print only
#   tools/find_anon_dest_grepai.sh --out DIR    # save under DIR instead of .analysis/grepai
#   tools/find_anon_dest_grepai.sh --query N    # run only query N (1-based)
#   tools/find_anon_dest_grepai.sh --list       # list queries without running
#
# Requires `grepai` on PATH. Safe to run from anywhere.

set -euo pipefail

# ----------------------------------------------------------------------
# Locate repo root.
# ----------------------------------------------------------------------
find_repo_root() {
  if command -v git >/dev/null 2>&1; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) && {
      printf '%s\n' "$root"
      return 0
    }
  fi
  local dir
  dir=$(cd "$(dirname "$0")" && pwd)
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/build.zig" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

REPO_ROOT=$(find_repo_root) || {
  echo "error: could not locate repo root" >&2
  exit 1
}
cd "$REPO_ROOT"

if ! command -v grepai >/dev/null 2>&1; then
  echo "error: grepai not found on PATH" >&2
  exit 1
fi

# ----------------------------------------------------------------------
# Arguments.
# ----------------------------------------------------------------------
OUT_DIR=".analysis/grepai"
TO_FILE=1
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --no-file) TO_FILE=0 ;;
    --out) shift; OUT_DIR="$1" ;;
    --query) shift; ONLY="$1" ;;
    --list)
      grep -n '^  "' "$0" | sed 's/^\([0-9]*\):  "\(.*\)",/\1. \2/'
      exit 0
      ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
  shift
done

# ----------------------------------------------------------------------
# Queries. Each is a full sentence describing a *concept*, not keywords.
# Grepai ranks by semantic similarity, so plain-language phrasing works
# better than code identifiers.
# ----------------------------------------------------------------------
QUERIES=(
  "code that assigns a name to a place or destination that has none"
  "code that decides whether a destination or output place has been satisfied"
  "code that rewrites or normalizes a parsed definition before emitting or executing it"
  "code that checks whether a place, port, or destination name is empty or missing"
  "code that uses the literal name result as a fallback destination"
  "code that binds a callee's anonymous return to the caller's destination"
)

# ----------------------------------------------------------------------
# Report driver.
# ----------------------------------------------------------------------
emit_reports() {
  echo "# find_anon_dest_grepai.sh"
  echo "# repo root: $REPO_ROOT"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  local idx=0
  for q in "${QUERIES[@]}"; do
    idx=$((idx + 1))
    if [ -n "$ONLY" ] && [ "$ONLY" != "$idx" ]; then
      continue
    fi

    printf '\n'
    printf '=%.0s' {1..80}
    printf '\nQuery %d: %s\n' "$idx" "$q"
    printf '=%.0s' {1..80}
    printf '\n\n'

    # --path scope: restrict to src/ so we don't get docs/tools noise.
    # If your grepai version doesn't support --path, drop the flag and
    # filter the output below instead.
    if ! grepai search "$q" --path src 2>/dev/null; then
      # Fallback: run without path scope, filter client-side.
      grepai search "$q" 2>/dev/null | grep -E '^File: src/' || true
    fi
  done

  printf '\n'
  printf '=%.0s' {1..80}
  printf '\nNotes\n'
  printf '=%.0s' {1..80}
  printf '\n\n'
  cat <<'EOF'
Reading the output:

  For each query, the top-ranked hits are the sites whose *intent*
  matches the query, even if they use different vocabulary than you
  expected. Cross-reference against .analysis/grep/full.txt:

    - hit in grep list               -> already on the checklist
    - hit NOT in grep list           -> blind spot; add to checklist
    - hit in a file not in SCAN_DIRS -> widen the grep script's scope

  Classify each checklist item as producer or consumer:

    producer  synthesizes a destination name (belongs in the parser after
              the refactor; should collapse to one site)
    consumer  reads def.destinations or dest.name (after the refactor,
              these should have no anonymity-specific logic)

  The refactor's success criterion: one producer, zero anonymity-specific
  consumers. If the string "result" still appears in the emitter or the
  runtime at the end, the synthesis isn't fully moved.
EOF
}

# ----------------------------------------------------------------------
# Run.
# ----------------------------------------------------------------------
if [ "$TO_FILE" -eq 1 ]; then
  mkdir -p "$OUT_DIR"
  OUT_FILE="$OUT_DIR/all.txt"
  emit_reports | tee "$OUT_FILE"
  echo
  echo "(also saved to $REPO_ROOT/$OUT_FILE)" >&2
else
  emit_reports
fi