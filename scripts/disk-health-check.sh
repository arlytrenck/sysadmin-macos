#!/usr/bin/env bash
#
# disk-health-check.sh — check the S.M.A.R.T. status macOS reports for
# each physical disk. Only covers what diskutil surfaces natively; it
# does not read full SMART attribute tables (that needs smartmontools,
# and Apple Silicon NVMe internal drives generally don't expose one at
# all through either path).
#
# Usage:
#   ./disk-health-check.sh
#
# Options:
#   -h   Show this help
#
# Exit codes:
#   0  every disk reports "Verified" (or SMART isn't supported on it)
#   2  one or more disks report a non-Verified SMART status

set -euo pipefail

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":h" opt; do
  case "$opt" in
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
  esac
done

FLAGGED=0

while read -r disk; do
  info="$(diskutil info "$disk" 2>/dev/null || true)"
  name="$(echo "$info" | awk -F':  *' '/Device \/ Media Name:/{print $2}')"
  smart="$(echo "$info" | awk -F':  *' '/SMART Status:/{print $2}')"

  if [[ -z "$smart" ]]; then
    echo "$disk (${name:-unknown}): SMART not reported (common for external/virtual disks and some NVMe)"
    continue
  fi

  echo "$disk (${name:-unknown}): SMART Status: $smart"
  if [[ "$smart" != "Verified" ]]; then
    echo "FLAG: $disk reports '$smart'"
    FLAGGED=1
  fi
done < <(diskutil list | awk '/^\/dev\/disk[0-9]+ \(/{print $1}')

if [[ "$FLAGGED" -eq 1 ]]; then
  exit 2
fi
echo
echo "All reporting disks are healthy."
