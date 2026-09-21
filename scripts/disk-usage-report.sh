#!/usr/bin/env bash
#
# disk-usage-report.sh — report filesystem usage and the largest directories
# under a given path, and exit non-zero if any real filesystem exceeds a
# threshold (useful for cron + alerting).
#
# APFS mounts a handful of synthetic system volumes (Preboot, VM, Update,
# xarts, iSCPreboot, Hardware) alongside the visible ones; these are
# filtered out of the threshold check since their usage isn't actionable.
#
# Usage:
#   ./disk-usage-report.sh [-p /path/to/scan] [-n 10] [-t 90]
#
# Options:
#   -p   Directory to scan for largest subdirectories (default: /)
#   -n   Number of top consumers to show (default: 10)
#   -t   Threshold percent that triggers a non-zero exit (default: 90)
#   -h   Show this help

set -euo pipefail

SCAN_PATH="/"
TOP_N=10
THRESHOLD=90

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":p:n:t:h" opt; do
  case "$opt" in
    p) SCAN_PATH="$OPTARG" ;;
    n) TOP_N="$OPTARG" ;;
    t) THRESHOLD="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

# Rows worth showing and checking: drop the header, the pseudo filesystems
# (devfs and the autofs "map" entries both report a permanent 100%), and the
# synthetic APFS system volumes.
real_filesystems() {
  df -hP | awk 'NR > 1 && $1 != "devfs" && $1 != "map" && $0 !~ /\/System\/Volumes\/(Preboot|VM|Update|xarts|iSCPreboot|Hardware)/'
}

echo "=== Filesystem usage ==="
df -hP | head -n 1
real_filesystems

echo
echo "=== Top $TOP_N largest directories under $SCAN_PATH (depth 2) ==="
# BSD du has no --max-depth; -d is the equivalent. `|| true`: du exits 1 on
# every unreadable (TCC-protected) directory, and head can close the pipe
# early; either would trip pipefail and end the script before the threshold
# check below.
du -h -d 2 -x "$SCAN_PATH" 2>/dev/null \
  | sort -rh \
  | sed -n "1,${TOP_N}p" || true

echo
echo "=== Threshold check (>=${THRESHOLD}%) ==="
OVER=0
while read -r pct mount; do
  pct="${pct%\%}"
  if [[ "$pct" =~ ^[0-9]+$ ]] && (( pct >= THRESHOLD )); then
    echo "WARNING: $mount is at ${pct}% (threshold: ${THRESHOLD}%)"
    OVER=1
  fi
# Capacity is field 5; the mount point is everything from field 6 on, which
# keeps volume names containing spaces intact.
done < <(real_filesystems | awk '{m=$6; for (i=7;i<=NF;i++) m=m " " $i; print $5, m}')

if (( OVER )); then
  echo "One or more filesystems exceeded the threshold."
  exit 2
fi

echo "All filesystems below threshold."
