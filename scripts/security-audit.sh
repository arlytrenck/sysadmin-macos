#!/usr/bin/env bash
#
# security-audit.sh — snapshot the state of the main macOS security
# controls (SIP, Gatekeeper, FileVault, application firewall, remote
# login) and the local admin group, and flag anything off that's usually
# expected to be on.
#
# This reports state; it does not change anything. Pair it with
# server-hardening-checklist.md for the reasoning behind each check and
# how to fix what it flags.
#
# Usage:
#   ./security-audit.sh
#
# Options:
#   -h   Show this help
#
# Exit codes:
#   0  nothing flagged
#   2  one or more controls are off / unexpected

set -euo pipefail

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":h" opt; do
  case "$opt" in
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
  esac
done

FLAGGED=0
flag() { echo "FLAG: $1"; FLAGGED=1; }

echo "=== System Integrity Protection (SIP) ==="
sip_status="$(csrutil status 2>&1)"
echo "$sip_status"
echo "$sip_status" | grep -qi "enabled" || flag "SIP is not enabled."

echo
echo "=== Gatekeeper ==="
gk_status="$(spctl --status 2>&1)"
echo "$gk_status"
echo "$gk_status" | grep -qi "assessments enabled" || flag "Gatekeeper assessments are disabled."

echo
echo "=== FileVault ==="
fv_status="$(fdesetup status 2>&1)"
echo "$fv_status"
echo "$fv_status" | grep -qi "FileVault is On" || flag "FileVault is not on."

echo
echo "=== Application firewall ==="
fw_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1)"
echo "$fw_state"
echo "$fw_state" | grep -qi "enabled" || flag "Application firewall is disabled."

echo
echo "=== Remote login (SSH) ==="
ssh_state="$(systemsetup -getremotelogin 2>&1)"
echo "$ssh_state"
echo "$ssh_state" | grep -qi "^Remote Login: On$" && flag "Remote Login (SSH) is on — confirm this is intentional."

echo
echo "=== Local admin group members ==="
dseditgroup -o read admin 2>/dev/null | grep -A999 '^ users:' | tail -n +2 | sed 's/^/  /'

echo
if [[ "$FLAGGED" -eq 1 ]]; then
  echo "One or more items flagged above."
  exit 2
fi
echo "Nothing flagged."
