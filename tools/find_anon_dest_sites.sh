#!/usr/bin/env bash
# tools/find_anon_dest_sites.sh
#
# Enumerates every place in the emitter, runtime, and testbench that
# handles (or fails to handle) the anonymous-destination case. Read-only.
#
# Usage:
#   tools/find_anon_dest_sites.sh            # print to screen + save to .analysis/grep/full.txt
#   tools/find_anon_dest_sites.sh --no-file  # print to screen only
#   tools/find_anon_dest_sites.sh --out DIR  # save under DIR instead of .analysis/grep
#
# Safe to run from anywhere: it locates the repo root via git (or by
# walking up to build.zig) and works in that directory.

set -euo pipefail

# ----------------------------------------------------------------------
# Locate the repo root, independent of the current working directory.
# ----------------------------------------------------------------------
find_repo_root() {
  if command -v git >/dev/null 2>&1; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) && {
      printf '%s\n' "$root"
      return 0
    }
  fi
  # Fallback: walk up from the script's own directory until build.zig appears.
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
  echo "error: could not locate repo root (no git, no build.zig above script)" >&2
  exit 1
}
cd "$REPO_ROOT"

# ----------------------------------------------------------------------
# Argument parsing.
# ----------------------------------------------------------------------
OUT_DIR=".analysis/grep"
TO_FILE=1
while [ $# -gt 0 ]; do
  case "$1" in
    --no-file) TO_FILE=0 ;;
    --out) shift; OUT_DIR="$1" ;;
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
# Directories to scan (relative to repo root).
# ----------------------------------------------------------------------
SCAN_DIRS=(
  "src/dialects/ipl/vhdl"
  "src/dialects/ipl/runtime"
  "src/dialects/ipl/parser"
  "src/tests"
)

EXCLUDE=(
  "--exclude-dir=.zig-cache"
  "--exclude-dir=zig-out"
  "--exclude-dir=docs"
  "--exclude-dir=.analysis"
  "--exclude=*.tb.vec"
)

sep() {
  printf '\n'
  printf '=%.0s' {1..80}
  printf '\n%s\n' "$1"
  printf '=%.0s' {1..80}
  printf '\n'
}

g() {
  grep -rn "${EXCLUDE[@]}" "$@" "${SCAN_DIRS[@]}" 2>/dev/null || true
}

# ----------------------------------------------------------------------
# Emit report to stdout.
# ----------------------------------------------------------------------
emit_report() {
  echo "# find_anon_dest_sites.sh"
  echo "# repo root: $REPO_ROOT"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo

  sep "1. Files that check for empty destination names (name.len == 0)"
  g -E '\.name\.len[[:space:]]*==[[:space:]]*0|name\[0\]\.\.|args\.len == 0' \
    | grep -Ev '^\s*//' || true

  sep "2. Files that check for empty destination lists (destinations.len == 0)"
  g -E 'destinations\.len[[:space:]]*==[[:space:]]*0|destinations\.len[[:space:]]*!=[[:space:]]*0' \
    | grep -Ev '^\s*//' || true

  sep "3. Occurrences of the reserved name 'result'"
  g -E '"result"|result<' \
    | grep -Ev '^\s*//' || true

  sep "4. normalizeReturnDestinations and its callers"
  g -E 'normalizeReturnDestinations'

  sep "5. isKeyCompositionHeader, parseInvocationArgs, findComposedDispatchHeader"
  g -E 'isKeyCompositionHeader|parseInvocationArgs|findComposedDispatchHeader'

  sep "6. appendSelectRules and its callers"
  g -E 'appendSelectRules'

  sep "7. Places that read def.destinations"
  g -E 'def\.destinations|\.destinations\b' \
    | grep -Ev '^\s*//' \
    | grep -E 'for[[:space:]]*\(|\.destinations\[' || true

  sep "8. Places that read dest.name"
  g -E 'dest\.name|dst\.name|dest_arg\.name' \
    | grep -Ev '^\s*//' || true

  sep "9. The 'result' constant in boundary.zig (if any)"
  g -E 'const[[:space:]]+\w*[Rr]esult\w*[[:space:]]*=' \
    src/dialects/ipl/vhdl/export/boundary.zig 2>/dev/null || true

  sep "10. Testbench.run's outer loop and progress check"
  g -E 'outer:|break :outer|fed_any|fed_this_wavefront'

  sep "11. rules_mod.run's completeness check"
  g -E 'destinationSatisfied|incomplete|CompletionReport'

  sep "12. Test files that reference anonymous destinations"
  g -E '<>|arg\.name\.len|empty name' \
    | grep -E '\.zig:' || true

  sep "Summary"
  local total
  total=$(g -E 'normalizeReturnDestinations|isKeyCompositionHeader|appendSelectRules|destinationSatisfied' | wc -l)
  echo "Files/functions of interest: $total matches."
  echo
  echo "Next steps (see ticket):"
  echo "  1. Decide reserved name (likely 'result')."
  echo "  2. Move destination synthesis into the parser."
  echo "  3. Delete every downstream check in groups 1-3 that exists only"
  echo "     to handle the anonymous case."
  echo "  4. Fix appendSelectRules to handle .pure_value contained entries."
  echo "  5. Add a progress check to Testbench.run's outer loop."
}

# ----------------------------------------------------------------------
# Run, tee to file if requested.
# ----------------------------------------------------------------------
if [ "$TO_FILE" -eq 1 ]; then
  mkdir -p "$OUT_DIR"
  OUT_FILE="$OUT_DIR/full.txt"
  emit_report | tee "$OUT_FILE"
  echo
  echo "(also saved to $REPO_ROOT/$OUT_FILE)" >&2
else
  emit_report
fi