#!/usr/bin/env bash
#
# security-audit.sh — snapshot the state of the main macOS security
# controls (SIP, Gatekeeper, FileVault, application firewall, remote
# login, screen sharing, guest/auto-login, automatic updates) and the
# local admin group, and flag anything off that's usually expected to be
# on (or on that's usually expected to be off).
#
# This reports state; it does not change anything. Pair it with
# server-hardening-checklist.md for the reasoning behind each check and
# how to fix what it flags.
#
# Needs root: socketfilterfw and systemsetup both refuse to run
# unprivileged, and running this unprivileged would otherwise mean the
# firewall and Remote Login checks silently misreport "off" from a
# permission error rather than the actual state.
#
# Usage:
#   sudo ./security-audit.sh
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

if [[ "$EUID" -ne 0 ]]; then
  echo "This needs root — socketfilterfw and systemsetup both refuse to run unprivileged. Re-run with sudo." >&2
  exit 1
fi

FLAGGED=0
flag() { echo "FLAG: $1"; FLAGGED=1; }

echo "=== System Integrity Protection (SIP) ==="
sip_status="$(csrutil status 2>&1 || true)"
echo "$sip_status"
echo "$sip_status" | grep -qi "enabled" || flag "SIP is not enabled."
# "enabled (Custom Configuration)" still matches the check above, but means
# some protections were switched off individually.
echo "$sip_status" | grep -qi "custom configuration" && flag "SIP has a custom configuration — some protections are off."

echo
echo "=== Gatekeeper ==="
gk_status="$(spctl --status 2>&1 || true)"
echo "$gk_status"
echo "$gk_status" | grep -qi "assessments enabled" || flag "Gatekeeper assessments are disabled."

echo
echo "=== FileVault ==="
fv_status="$(fdesetup status 2>&1 || true)"
echo "$fv_status"
echo "$fv_status" | grep -qi "FileVault is On" || flag "FileVault is not on."

echo
echo "=== Application firewall ==="
fw_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 || true)"
echo "$fw_state"
echo "$fw_state" | grep -qi "enabled" || flag "Application firewall is disabled."

echo
echo "=== Remote login (SSH) ==="
ssh_state="$(systemsetup -getremotelogin 2>&1 || true)"
echo "$ssh_state"
if echo "$ssh_state" | grep -Eqi '^Remote Login: (On|Off)$'; then
  echo "$ssh_state" | grep -qi "^Remote Login: On$" && flag "Remote Login (SSH) is on — confirm this is intentional."
else
  # Since Monterey systemsetup can refuse even as root without Full Disk
  # Access. Ask launchd instead: sshd is only loaded while Remote Login is on.
  echo "(systemsetup couldn't answer — checking launchd instead)"
  if launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
    flag "Remote Login (SSH) is on — confirm this is intentional."
  else
    echo "sshd is not loaded."
  fi
fi

echo
echo "=== Screen Sharing ==="
if launchctl print-disabled system 2>/dev/null | grep -q '"com.apple.screensharing" => enabled'; then
  flag "Screen Sharing is enabled — confirm this is intentional."
else
  echo "Screen Sharing is not enabled."
fi

echo
echo "=== Login window ==="
guest="$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo 0)"
[[ "$guest" == "1" ]] && flag "Guest account is enabled." || echo "Guest account: off"
autologin="$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true)"
[[ -n "$autologin" ]] && flag "Automatic login is set for '$autologin'." || echo "Automatic login: off"

echo
echo "=== Automatic updates ==="
# An absent key means the default, which is on, so only an explicit 0 flags.
for key in AutomaticCheckEnabled CriticalUpdateInstall ConfigDataInstall; do
  val="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate "$key" 2>/dev/null || echo "default")"
  echo "$key: $val"
  [[ "$val" == "0" ]] && flag "Software Update setting $key is off."
done

echo
echo "=== Local admin group members ==="
dscl . -read /Groups/admin GroupMembership 2>/dev/null | cut -d: -f2- | tr -s ' ' '\n' | sed '/^$/d; s/^/  /' || echo "  (could not read admin group membership)"

echo
if [[ "$FLAGGED" -eq 1 ]]; then
  echo "One or more items flagged above."
  exit 2
fi
echo "Nothing flagged."
