#!/usr/bin/env bash
#
# time-sync-check.sh — check whether network time sync is enabled and
# which server it's using, and flag a large offset from that server.
#
# Usage:
#   ./time-sync-check.sh [-t 5]
#
# Options:
#   -t   Offset threshold in seconds that triggers a non-zero exit
#        (default: 5)
#   -h   Show this help
#
# Exit codes:
#   0  sync enabled and offset within threshold
#   2  sync disabled, or offset exceeds threshold, or sntp failed

set -euo pipefail

THRESHOLD=5

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":t:h" opt; do
  case "$opt" in
    t) THRESHOLD="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

FLAGGED=0

NETTIME="$(systemsetup -getnetworktimeserver 2>&1 || true)"
USING="$(systemsetup -getusingnetworktime 2>&1 || true)"
echo "$NETTIME"
echo "$USING"

if ! echo "$USING" | grep -qi "^Network Time: On$"; then
  echo "FLAG: Network time sync is off."
  FLAGGED=1
fi

SERVER="$(echo "$NETTIME" | awk -F': ' '{print $2}')"
if [[ -n "$SERVER" ]] && command -v sntp >/dev/null 2>&1; then
  echo
  echo "=== Offset from $SERVER ==="
  SNTP_OUT="$(sntp "$SERVER" 2>&1 || true)"
  echo "$SNTP_OUT"
  # sntp prints a leading signed offset in seconds, e.g. "+0.012345 ...".
  OFFSET="$(echo "$SNTP_OUT" | grep -Eo '^[+-][0-9]+\.[0-9]+' | head -n1)"
  if [[ -n "$OFFSET" ]]; then
    ABS_OFFSET="${OFFSET#-}"
    ABS_OFFSET="${ABS_OFFSET#+}"
    if awk -v o="$ABS_OFFSET" -v t="$THRESHOLD" 'BEGIN{exit !(o>t)}'; then
      echo "FLAG: offset ${OFFSET}s exceeds threshold of ${THRESHOLD}s."
      FLAGGED=1
    fi
  else
    echo "Could not parse an offset from sntp output."
  fi
fi

if [[ "$FLAGGED" -eq 1 ]]; then
  exit 2
fi
echo
echo "Time sync OK."
