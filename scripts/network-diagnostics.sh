#!/usr/bin/env bash
#
# network-diagnostics.sh — snapshot network interfaces, the default route,
# DNS resolver configuration, and basic reachability, for triaging "the
# network is broken" reports.
#
# Usage:
#   ./network-diagnostics.sh [-t example.com] [-c 3]
#
# Options:
#   -t   Host to test DNS resolution and reachability against
#        (default: 1.1.1.1 for reachability, apple.com for DNS)
#   -c   Ping count (default: 3)
#   -h   Show this help

set -euo pipefail

TEST_HOST="apple.com"
PING_TARGET="1.1.1.1"
PING_COUNT=3

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":t:c:h" opt; do
  case "$opt" in
    t) TEST_HOST="$OPTARG" ;;
    c) PING_COUNT="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

echo "=== Network services (in network-preference order) ==="
networksetup -listnetworkserviceorder 2>&1 | grep -E '^\([0-9]+\)' || echo "(none found)"

echo
echo "=== Active interfaces ==="
# ifconfig prints "status: active" AFTER the inet lines, so the addresses
# are held per interface and only printed once the status line is seen.
ifconfig -a | awk '
  function flush() { if (up && addrs != "") printf "%s", addrs; addrs = ""; up = 0 }
  /^[a-z]/ { flush(); iface = $1; sub(/:$/, "", iface) }
  /inet / { addrs = addrs iface " " $0 "\n" }
  /status: active/ { up = 1 }
  END { flush() }
' || true

echo
echo "=== Default route ==="
route -n get default 2>/dev/null || echo "No default route found."

echo
echo "=== DNS configuration ==="
scutil --dns 2>&1 | grep -E 'nameserver\[[0-9]+\]|search domain' | sort -u || echo "(none found)"

echo
echo "=== DNS resolution test: $TEST_HOST ==="
if command -v dig >/dev/null 2>&1; then
  dig +short "$TEST_HOST" || echo "dig returned no answer for $TEST_HOST"
else
  # dig ships with macOS by default; this is a fallback for a stripped-down PATH.
  host "$TEST_HOST" 2>&1 || echo "Could not resolve $TEST_HOST"
fi

echo
echo "=== Reachability test: $PING_TARGET ($PING_COUNT packets) ==="
if ping -c "$PING_COUNT" -t 5 "$PING_TARGET"; then
  echo "Reachable."
else
  echo "WARNING: $PING_TARGET is not reachable."
  exit 2
fi
