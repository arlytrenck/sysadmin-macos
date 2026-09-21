#!/usr/bin/env bash
#
# service-health-check.sh — check the status of one or more launchd jobs
# (daemons or agents) and, optionally, kickstart-restart any that aren't
# running.
#
# Labels are checked with `launchctl print`, which requires a full domain
# target (system/<label>, gui/<uid>/<label>, or user/<uid>/<label>) rather
# than just the label — pass the domain that matches where the job is
# actually loaded (LaunchDaemons load into `system`; a logged-in user's
# LaunchAgents load into `gui/<uid>`).
#
# Usage:
#   ./service-health-check.sh -l                          # list loaded jobs matching a filter
#   ./service-health-check.sh -s label1,label2 [-d system] [-r]
#
# Options:
#   -l   List loaded job labels (optionally narrowed with -f) and exit
#   -f   Substring filter for -l (default: none, lists everything)
#   -s   Comma-separated list of labels to check (required unless -l)
#   -d   launchd domain: system, gui/<uid>, or user/<uid> (default: system)
#   -r   Kickstart (restart) any checked job that isn't running
#   -h   Show this help
#
# Exit codes:
#   0  all checked jobs are running (or -l was used)
#   1  bad usage
#   2  one or more checked jobs were not running (even after -r)

set -euo pipefail

DO_LIST=0
FILTER=""
LABELS=""
DOMAIN="system"
DO_RESTART=0

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":lf:s:d:rh" opt; do
  case "$opt" in
    l) DO_LIST=1 ;;
    f) FILTER="$OPTARG" ;;
    s) LABELS="$OPTARG" ;;
    d) DOMAIN="$OPTARG" ;;
    r) DO_RESTART=1 ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

if [[ "$DO_LIST" -eq 1 ]]; then
  echo "=== Loaded jobs matching '${FILTER:-<all>}' ==="
  if [[ -n "$FILTER" ]]; then
    # sed, not head: an early-exiting head can SIGPIPE launchctl, which
    # pipefail would turn into a script exit.
    launchctl list | sed -n '1p'
    launchctl list | tail -n +2 | grep -i -- "$FILTER" || echo "(no matches)"
  else
    launchctl list
  fi
  exit 0
fi

if [[ -z "$LABELS" ]]; then
  echo "Either -l or -s <labels> is required" >&2
  usage 1
fi

FAILED=0
IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
for label in "${LABEL_ARRAY[@]}"; do
  target="${DOMAIN}/${label}"
  if ! print_out="$(launchctl print "$target" 2>&1)"; then
    echo "NOT LOADED: $target"
    FAILED=1
    continue
  fi

  # || true: a job with no "state =" line makes grep exit 1, and pipefail
  # would end the whole run on the first such job.
  state="$(echo "$print_out" | grep -m1 'state = ' | awk -F'= ' '{print $2}' || true)"

  if [[ "$state" == "running" ]]; then
    echo "OK: $target (state = running)"
    continue
  fi

  echo "NOT RUNNING: $target (state = ${state:-unknown})"

  RECOVERED=0
  if [[ "$DO_RESTART" -eq 1 ]]; then
    echo "  Kickstarting $target..."
    if launchctl kickstart -k "$target"; then
      sleep 2
      new_state="$(launchctl print "$target" 2>/dev/null | grep -m1 'state = ' | awk -F'= ' '{print $2}' || true)"
      echo "  New state: ${new_state:-unknown}"
      if [[ "$new_state" == "running" ]]; then RECOVERED=1; fi
    else
      echo "  Kickstart failed."
    fi
  fi
  if [[ "$RECOVERED" -eq 0 ]]; then FAILED=1; fi
done

if [[ "$FAILED" -eq 1 ]]; then
  echo "One or more jobs are not running."
  exit 2
fi

echo "All checked jobs are running."
