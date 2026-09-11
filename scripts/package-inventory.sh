#!/usr/bin/env bash
#
# package-inventory.sh — snapshot installed applications (any install
# method) plus Homebrew formulae/casks and flat-package receipts, and
# optionally diff against a previous snapshot.
#
# App discovery uses Spotlight metadata (mdfind) rather than
# system_profiler, which is slow and misses some bundled apps (Safari
# among them).
#
# Usage:
#   ./package-inventory.sh -o /path/to/snapshot.txt
#   ./package-inventory.sh -d /path/to/baseline.txt   # diff vs. a prior run
#
# Options:
#   -o   Write the current snapshot to this file (default: stdout)
#   -d   Diff the current snapshot against this baseline file instead of
#        just printing it
#   -h   Show this help

set -euo pipefail

OUT_FILE=""
BASELINE=""

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":o:d:h" opt; do
  case "$opt" in
    o) OUT_FILE="$OPTARG" ;;
    d) BASELINE="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

snapshot() {
  echo "# package-inventory snapshot: $(date '+%Y-%m-%d %H:%M:%S')"

  echo "## Applications (mdfind, application bundles)"
  mdfind "kMDItemContentType == 'com.apple.application-bundle'" 2>/dev/null \
    | grep -v '/Library/Caches/' \
    | sort -u \
    | while read -r app; do
        ver="$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '?')"
        printf 'app\t%s\t%s\n' "$(basename "$app")" "$ver"
      done

  if command -v brew >/dev/null 2>&1; then
    echo "## Homebrew formulae"
    brew list --versions --formula | awk '{print "brew\t"$1"\t"$2}'
    echo "## Homebrew casks"
    brew list --versions --cask | awk '{print "cask\t"$1"\t"$2}'
  fi

  echo "## Installer packages (pkgutil receipts)"
  pkgutil --pkgs | while read -r pkg; do
    ver="$(pkgutil --pkg-info "$pkg" 2>/dev/null | awk -F': ' '/^version:/{print $2}')"
    printf 'pkg\t%s\t%s\n' "$pkg" "${ver:-?}"
  done
}

if [[ -n "$BASELINE" ]]; then
  if [[ ! -f "$BASELINE" ]]; then
    echo "Baseline file not found: $BASELINE" >&2
    exit 1
  fi
  CURRENT="$(mktemp)"
  trap 'rm -f "$CURRENT"' EXIT
  snapshot > "$CURRENT"
  echo "=== Diff: $BASELINE -> current ==="
  diff -u <(grep -v '^#' "$BASELINE" | sort) <(grep -v '^#' "$CURRENT" | sort) || true
  exit 0
fi

if [[ -n "$OUT_FILE" ]]; then
  snapshot > "$OUT_FILE"
  echo "Snapshot written to $OUT_FILE"
else
  snapshot
fi
