#!/usr/bin/env bash
#
# pending-reboot-check.sh — detect whether a restart is needed to finish
# applying macOS updates.
#
# softwareupdate flags each pending item with a trailing "[restart]" when
# it requires one; this just checks for that marker rather than trying to
# infer it from any other state.
#
# Usage:
#   ./pending-reboot-check.sh
#
# Options:
#   -h   Show this help
#
# Exit codes:
#   0  no restart required
#   2  one or more pending updates require a restart

set -euo pipefail

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":h" opt; do
  case "$opt" in
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
  esac
done

LIST_OUTPUT="$(softwareupdate -l 2>&1 || true)"
echo "$LIST_OUTPUT"

if echo "$LIST_OUTPUT" | grep -q '\[restart\]'; then
  echo
  echo "Restart required to finish applying one or more updates."
  exit 2
fi

echo
echo "No pending updates require a restart."
