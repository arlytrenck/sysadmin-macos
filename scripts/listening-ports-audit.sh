#!/usr/bin/env bash
#
# listening-ports-audit.sh — list every listening TCP/UDP socket and flag
# any port not on an allowlist.
#
# Usage:
#   ./listening-ports-audit.sh [-a "22,80,443"]
#
# Options:
#   -a   Comma-separated allowlist of ports. Anything listening outside
#        this list is flagged. Omit to just list, with nothing flagged.
#   -h   Show this help
#
# Exit codes:
#   0  nothing flagged (or no allowlist given)
#   2  a listening port isn't on the allowlist

set -euo pipefail

ALLOWLIST=""

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":a:h" opt; do
  case "$opt" in
    a) ALLOWLIST="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

# lsof only shows other users' sockets to root. Use root when available, but
# say so when it isn't, so an allowlist check on partial data isn't mistaken
# for a clean bill of health.
if [[ "$EUID" -eq 0 ]]; then
  LSOF=(lsof)
elif sudo -n true 2>/dev/null; then
  LSOF=(sudo -n lsof)
else
  LSOF=(lsof)
  echo "Heads up: not root and no passwordless sudo — only this user's sockets are visible." >&2
fi

# lsof exits 1 when it finds nothing, hence the || true on each capture.
TCP_OUT="$("${LSOF[@]}" -nP -iTCP -sTCP:LISTEN 2>/dev/null || true)"
UDP_OUT="$("${LSOF[@]}" -nP -iUDP 2>/dev/null || true)"

echo "=== Listening TCP sockets ==="
echo "$TCP_OUT"

echo
echo "=== Bound UDP sockets ==="
echo "$UDP_OUT"

if [[ -z "$ALLOWLIST" ]]; then
  echo
  echo "(no -a allowlist given — nothing checked)"
  exit 0
fi

echo
echo "=== Allowlist check (allowed: $ALLOWLIST) ==="
FLAGGED=0
IFS=',' read -ra ALLOWED <<< "$ALLOWLIST"

while read -r port proc pid; do
  [[ -z "$port" ]] && continue
  allowed=0
  for a in "${ALLOWED[@]}"; do
    [[ "$port" == "$a" ]] && allowed=1 && break
  done
  if [[ "$allowed" -eq 0 ]]; then
    echo "FLAG: port $port not on allowlist (pid=$pid, $proc)"
    FLAGGED=1
  fi
done < <(echo "$TCP_OUT" | tail -n +2 | awk 'NF {n=split($9,a,":"); print a[n], $1, $2}' | sort -un)

if [[ "$FLAGGED" -eq 1 ]]; then
  exit 2
fi
echo "All listening TCP ports are on the allowlist."
