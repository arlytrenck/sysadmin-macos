#!/usr/bin/env bash
#
# backup-verify.sh — assert that a Time Machine backup exists and is
# recent, rather than trusting that the feature is "on".
#
# tmutil needs Full Disk Access granted to the process running it (Terminal,
# or whatever runs this script under cron/launchd) — System Settings ->
# Privacy & Security -> Full Disk Access. Without it, tmutil silently
# reports no backups.
#
# Usage:
#   ./backup-verify.sh [-m 26]
#
# Options:
#   -m   Maximum age in hours since the latest backup before this is
#        treated as a failure (default: 26, i.e. a bit over a day)
#   -h   Show this help
#
# Exit codes:
#   0  a backup exists and is within the age threshold
#   2  no backup found, the latest one is too old, or its age can't be
#      determined (fails closed)

set -euo pipefail

MAX_AGE_HOURS=26

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":m:h" opt; do
  case "$opt" in
    m) MAX_AGE_HOURS="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

echo "=== tmutil status ==="
tmutil status 2>&1 || true

LATEST="$(tmutil latestbackup 2>/dev/null || true)"
if [[ -z "$LATEST" ]]; then
  echo
  echo "No backup found (or Full Disk Access is missing for this process)."
  exit 2
fi

echo
echo "Latest backup: $LATEST"

# The backup's directory name carries a LOCAL-time stamp, YYYY-MM-DD-HHMMSS.
# APFS backups append ".backup" to it, so don't anchor the match to the end
# of the name. An assertion script has to fail closed: if the age can't be
# worked out, that's a failure, not a pass.
STAMP="$(basename "$LATEST" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | head -n1 || true)"
if [[ -z "$STAMP" ]]; then
  echo "Could not parse a timestamp from the backup name; can't verify its age."
  exit 2
fi

BACKUP_EPOCH="$(date -j -f '%Y-%m-%d-%H%M%S' "$STAMP" '+%s' 2>/dev/null || true)"
if [[ -z "$BACKUP_EPOCH" ]]; then
  echo "Could not parse the backup timestamp ($STAMP); can't verify its age."
  exit 2
fi

NOW_EPOCH="$(date '+%s')"
AGE_HOURS=$(( (NOW_EPOCH - BACKUP_EPOCH) / 3600 ))
echo "Age: ${AGE_HOURS}h (threshold: ${MAX_AGE_HOURS}h)"

if (( AGE_HOURS > MAX_AGE_HOURS )); then
  echo "Latest backup is older than the threshold."
  exit 2
fi

echo "Backup is recent enough."
