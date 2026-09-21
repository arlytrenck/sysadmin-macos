#!/usr/bin/env bash
#
# update-and-patch.sh — check for and optionally install macOS system
# updates (softwareupdate) and Homebrew package updates, with a timestamped
# log.
#
# Usage:
#   ./update-and-patch.sh [-i] [-r] [-b] [-L /path/to/log]
#
# Options:
#   -i   Install available macOS updates (default: list only)
#   -r   Allow automatic restart if an installed macOS update requires it
#        (only meaningful with -i; ignored otherwise)
#   -b   Also run `brew update && brew upgrade` (skipped if brew isn't
#        installed, rather than failing)
#   -L   Log file to append a timestamped copy of all output to
#        (default: none)
#   -h   Show this help
#
# Exit codes:
#   0  success (updates listed, or installed cleanly)
#   1  bad usage
#   2  softwareupdate or brew reported a failure

set -euo pipefail

DO_INSTALL=0
ALLOW_RESTART=0
DO_BREW=0
LOG_FILE=""

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":irbL:h" opt; do
  case "$opt" in
    i) DO_INSTALL=1 ;;
    r) ALLOW_RESTART=1 ;;
    b) DO_BREW=1 ;;
    L) LOG_FILE="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

log() {
  echo "$1"
  # An if, not `[[ ]] && ...`: with no -L the test is false, the function
  # returns 1, and set -e would kill the script on the very first log call.
  if [[ -n "$LOG_FILE" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
  fi
}

RESULT=0

if [[ "$DO_INSTALL" -eq 1 && "$EUID" -ne 0 ]]; then
  echo "Installing updates requires root — re-run with sudo." >&2
  exit 1
fi

log "=== macOS software updates ($(sw_vers -productVersion)) ==="
if [[ "$DO_INSTALL" -eq 1 ]]; then
  log "Installing available updates..."
  if [[ "$ALLOW_RESTART" -eq 1 ]]; then
    softwareupdate -i -a -R 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || RESULT=2
  else
    softwareupdate -i -a 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || RESULT=2
  fi
else
  softwareupdate -l 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || true
  log "(list only — pass -i to install)"
fi

if [[ "$DO_BREW" -eq 1 ]]; then
  log ""
  log "=== Homebrew updates ==="
  if [[ "$EUID" -eq 0 ]]; then
    log "Homebrew refuses to run as root — skipping (re-run -b without sudo)."
  elif command -v brew >/dev/null 2>&1; then
    brew update 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || RESULT=2
    brew upgrade 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || RESULT=2
    brew cleanup 2>&1 | tee -a "${LOG_FILE:-/dev/null}" || true
  else
    log "brew not found on PATH — skipping."
  fi
fi

exit "$RESULT"
