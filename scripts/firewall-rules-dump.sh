#!/usr/bin/env bash
#
# firewall-rules-dump.sh — snapshot both firewall layers macOS ships:
# the application firewall (socketfilterfw, allow/block by app) and pf
# (packet filter, the actual packet-level firewall underneath it and
# VPN/NAT). Requires sudo for both.
#
# pf is off by default on a stock Mac — nothing enables it out of the box,
# and Apple's own tooling (Application Firewall, Internet Sharing, VPN)
# loads its own anchors only while those features are active. Seeing empty
# pf output on a Mac that isn't running any of those is expected, not a
# problem.
#
# Usage:
#   sudo ./firewall-rules-dump.sh [-o /path/to/output.txt]
#
# Options:
#   -o   Write output to this file instead of stdout
#   -h   Show this help

set -euo pipefail

OUT_FILE=""

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":o:h" opt; do
  case "$opt" in
    o) OUT_FILE="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

if [[ "$EUID" -ne 0 ]]; then
  echo "This needs root to read pf state and the firewall app list — re-run with sudo." >&2
  exit 1
fi

dump() {
  echo "# firewall-rules-dump: $(date '+%Y-%m-%d %H:%M:%S')"

  echo "## Application firewall (socketfilterfw)"
  /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
  /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall
  /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
  echo "### Per-app rules"
  /usr/libexec/ApplicationFirewall/socketfilterfw --listapps

  echo
  echo "## pf (packet filter)"
  echo "### Loaded rules"
  pfctl -s rules 2>&1
  echo "### NAT rules"
  pfctl -s nat 2>&1
  echo "### Active anchors"
  pfctl -s Anchors 2>&1
}

if [[ -n "$OUT_FILE" ]]; then
  dump > "$OUT_FILE"
  echo "Written to $OUT_FILE"
else
  dump
fi
