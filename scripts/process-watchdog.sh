#!/usr/bin/env bash
#
# process-watchdog.sh — flag processes over a CPU or memory threshold.
#
# Usage:
#   ./process-watchdog.sh [-c 90] [-m 20] [-n 10]
#
# Options:
#   -c   CPU percent threshold to flag (default: 90)
#   -m   Memory percent threshold to flag (default: 20)
#   -n   Show this many top consumers regardless of threshold (default: 10)
#   -h   Show this help
#
# Exit codes:
#   0  nothing over threshold
#   2  one or more processes exceeded a threshold

set -euo pipefail

CPU_THRESHOLD=90
MEM_THRESHOLD=20
TOP_N=10

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":c:m:n:h" opt; do
  case "$opt" in
    c) CPU_THRESHOLD="$OPTARG" ;;
    m) MEM_THRESHOLD="$OPTARG" ;;
    n) TOP_N="$OPTARG" ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

echo "=== Top $TOP_N by CPU ==="
# sed rather than head: head exits early, ps can then die of SIGPIPE, and
# pipefail turns that into a script exit before the threshold check runs.
ps -Ao pid,pcpu,pmem,comm -r | sed -n "1,$((TOP_N + 1))p"

echo
echo "=== Top $TOP_N by memory ==="
ps -Ao pid,pcpu,pmem,comm -m | sed -n "1,$((TOP_N + 1))p"

echo
echo "=== Threshold check (CPU > ${CPU_THRESHOLD}%, mem > ${MEM_THRESHOLD}%) ==="
FLAGGED=0
while read -r pid pcpu pmem comm; do
  [[ "$pid" == "PID" ]] && continue
  over=0
  awk -v v="$pcpu" -v t="$CPU_THRESHOLD" 'BEGIN{exit !(v>t)}' && over=1
  awk -v v="$pmem" -v t="$MEM_THRESHOLD" 'BEGIN{exit !(v>t)}' && over=1
  if [[ "$over" -eq 1 ]]; then
    echo "FLAG: pid=$pid cpu=${pcpu}% mem=${pmem}% comm=$comm"
    FLAGGED=1
  fi
done < <(ps -Ao pid,pcpu,pmem,comm)

if [[ "$FLAGGED" -eq 1 ]]; then
  exit 2
fi
echo "Nothing over threshold."
