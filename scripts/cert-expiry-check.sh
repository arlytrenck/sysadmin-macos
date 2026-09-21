#!/usr/bin/env bash
#
# cert-expiry-check.sh — check a certificate's expiry, either from a live
# TLS host or a local PEM file, and flag anything expiring soon.
#
# Usage:
#   ./cert-expiry-check.sh -H example.com[:443] [-w 14]
#   ./cert-expiry-check.sh -f /path/to/cert.pem [-w 14]
#
# Options:
#   -H   Host (optionally host:port, default port 443) to fetch a live cert from
#   -f   Local PEM certificate file to check instead of a live host
#   -w   Warn if fewer than this many days remain (default: 14)
#   -h   Show this help
#
# Exit codes:
#   0  cert is valid and outside the warning window
#   2  cert expires within the warning window, or has already expired

set -euo pipefail

TARGET_HOST=""
CERT_FILE=""
WARN_DAYS=14

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":H:f:w:h" opt; do
  case "$opt" in
    H) TARGET_HOST="$OPTARG" ;;
    f) CERT_FILE="$OPTARG" ;;
    w) WARN_DAYS="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

if [[ -z "$TARGET_HOST" && -z "$CERT_FILE" ]]; then
  echo "Either -H <host> or -f <file> is required" >&2
  usage 1
fi

if [[ -n "$CERT_FILE" ]]; then
  # || true on both reads: under pipefail an unreadable file or a refused
  # connection would otherwise abort here, before the friendly error below.
  ENDDATE_RAW="$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2 || true)"
  SUBJECT="$CERT_FILE"
else
  HOST="${TARGET_HOST%%:*}"
  PORT="443"
  [[ "$TARGET_HOST" == *:* ]] && PORT="${TARGET_HOST##*:}"
  ENDDATE_RAW="$(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null \
    | openssl x509 -enddate -noout 2>/dev/null | cut -d= -f2 || true)"
  SUBJECT="$TARGET_HOST"
fi

if [[ -z "$ENDDATE_RAW" ]]; then
  echo "Could not read a certificate for $SUBJECT" >&2
  exit 2
fi

echo "Subject: $SUBJECT"
echo "Expires: $ENDDATE_RAW"

ENDDATE_CLEAN="${ENDDATE_RAW% GMT}"
EXPIRY_EPOCH="$(TZ=UTC date -j -f '%b %d %T %Y' "$ENDDATE_CLEAN" '+%s' 2>/dev/null || true)"
if [[ -z "$EXPIRY_EPOCH" ]]; then
  echo "Could not parse the expiry date; can't verify how long is left." >&2
  exit 2
fi

NOW_EPOCH="$(date '+%s')"
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
echo "Days remaining: $DAYS_LEFT"

# Test the epochs, not DAYS_LEFT: integer division truncates toward zero, so a
# cert that expired 12 hours ago would read as 0 days left rather than negative.
if (( EXPIRY_EPOCH <= NOW_EPOCH )); then
  echo "Certificate has already expired."
  exit 2
fi
if (( DAYS_LEFT < WARN_DAYS )); then
  echo "Certificate expires within the warning window (${WARN_DAYS}d)."
  exit 2
fi
echo "OK."
