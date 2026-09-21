#!/usr/bin/env bash
#
# memory-pressure-check.sh — check macOS's own memory-pressure metric
# (not raw free RAM, which is a poor signal on macOS since it aggressively
# uses "free" memory for the page cache) plus swap usage.
#
# Usage:
#   ./memory-pressure-check.sh [-f 10]
#
# Options:
#   -f   Minimum acceptable free-memory percentage from `memory_pressure`
#        before this flags (default: 10)
#   -h   Show this help
#
# Exit codes:
#   0  free percentage at/above threshold
#   2  free percentage below threshold, or memory_pressure's output
#      couldn't be parsed (fails closed)

set -euo pipefail

MIN_FREE_PCT=10

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":f:h" opt; do
  case "$opt" in
    f) MIN_FREE_PCT="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

echo "=== vm_stat ==="
vm_stat

echo
echo "=== Swap usage ==="
sysctl vm.swapusage

echo
echo "=== Memory pressure ==="
MP_OUT="$(memory_pressure 2>&1)"
echo "$MP_OUT"

# || true: with no matching line grep exits 1, and under pipefail that would
# end the script here instead of reaching the message below.
FREE_PCT="$(echo "$MP_OUT" | grep "System-wide" | awk '{print $5}' | tr -d '%' || true)"
if [[ ! "$FREE_PCT" =~ ^[0-9]+$ ]]; then
  echo "Could not parse a free percentage from memory_pressure output."
  exit 2
fi

echo
echo "Free: ${FREE_PCT}% (threshold: ${MIN_FREE_PCT}%)"
if (( FREE_PCT < MIN_FREE_PCT )); then
  echo "Free memory percentage is below threshold."
  exit 2
fi
echo "OK."
