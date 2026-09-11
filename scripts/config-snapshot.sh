#!/usr/bin/env bash
#
# config-snapshot.sh — roll the settings that matter for drift tracking
# (OS version, hostname, security posture, network config, loaded
# launchd jobs, installed configuration profiles) into one plain-text
# snapshot. Not JSON — this only uses tools in the base OS, and building
# correct JSON without jq isn't worth the risk of subtly corrupting it.
#
# Usage:
#   ./config-snapshot.sh [-o /path/to/snapshot.txt] [-r]
#
# Options:
#   -o   Write to this file instead of stdout
#   -r   Redact hostname and hardware serial (for sharing a snapshot
#        outside your own environment)
#   -h   Show this help

set -euo pipefail

OUT_FILE=""
REDACT=0

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":o:rh" opt; do
  case "$opt" in
    o) OUT_FILE="$OPTARG" ;;
    r) REDACT=1 ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

snapshot() {
  echo "# config-snapshot: $(date '+%Y-%m-%d %H:%M:%S')"

  echo
  echo "## System"
  echo "macOS: $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  if [[ "$REDACT" -eq 1 ]]; then
    echo "ComputerName: [redacted]"
    echo "Serial: [redacted]"
  else
    echo "ComputerName: $(scutil --get ComputerName 2>/dev/null || echo unknown)"
    echo "Serial: $(ioreg -l | awk -F'"' '/IOPlatformSerialNumber/{print $4}')"
  fi
  echo "Timezone: $(systemsetup -gettimezone 2>/dev/null || true)"

  echo
  echo "## Security posture"
  echo "SIP: $(csrutil status 2>&1)"
  echo "Gatekeeper: $(spctl --status 2>&1)"
  echo "FileVault: $(fdesetup status 2>&1)"
  echo "App firewall: $(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1)"
  echo "Remote Login: $(systemsetup -getremotelogin 2>&1)"

  echo
  echo "## Network"
  networksetup -listallnetworkservices 2>/dev/null | tail -n +2
  echo "-- DNS --"
  scutil --dns 2>/dev/null | grep -E 'nameserver\[[0-9]+\]' | sort -u

  echo
  echo "## launchd"
  echo "Loaded jobs: $(launchctl list | tail -n +2 | wc -l | tr -d ' ')"

  echo
  echo "## Configuration profiles (MDM / manual)"
  profiles list 2>&1 || echo "(profiles command unavailable or none installed)"
}

if [[ -n "$OUT_FILE" ]]; then
  snapshot > "$OUT_FILE"
  echo "Snapshot written to $OUT_FILE"
else
  snapshot
fi
