#!/usr/bin/env bash
#
# user-mgmt.sh — create, disable, enable, remove, or list local macOS user
# accounts.
#
# "Disable" here means setting the account's login shell to /usr/bin/false,
# which blocks new interactive shell/login-window sessions for that user.
# It is a soft disable: it does not revoke Secure Token, does not touch
# FileVault unlock ability, and does not kill sessions already open. There
# is no built-in macOS equivalent of Windows' Disable-LocalUser that fully
# locks an account; for that level of control, use MDM.
#
# Usage:
#   sudo ./user-mgmt.sh -a create -u NAME [-f "Full Name"] [-A]
#   sudo ./user-mgmt.sh -a disable -u NAME
#   sudo ./user-mgmt.sh -a enable  -u NAME
#   sudo ./user-mgmt.sh -a remove  -u NAME [-k]
#        ./user-mgmt.sh -a list
#
# Options:
#   -a   Action: create, disable, enable, remove, list (required)
#   -u   Target username (required for create/disable/enable/remove)
#   -f   Full name, for create (default: same as username)
#   -A   Make the new account an administrator, for create
#   -k   Keep the home directory when removing (default: delete it)
#   -h   Show this help
#
# Exit codes:
#   0  success
#   1  bad usage / missing argument
#   2  action failed (see sysadminctl/dscl output above)

set -euo pipefail

ACTION=""
TARGET_USER=""
FULL_NAME=""
MAKE_ADMIN=0
KEEP_HOME=0

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":a:u:f:Akh" opt; do
  case "$opt" in
    a) ACTION="$OPTARG" ;;
    u) TARGET_USER="$OPTARG" ;;
    f) FULL_NAME="$OPTARG" ;;
    A) MAKE_ADMIN=1 ;;
    k) KEEP_HOME=1 ;;
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
    :) echo "Option -$OPTARG requires an argument" >&2; usage 1 ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  echo "Missing required -a <action>" >&2
  usage 1
fi

if [[ "$ACTION" != "list" && -z "$TARGET_USER" ]]; then
  echo "Action '$ACTION' requires -u <username>" >&2
  usage 1
fi

case "$ACTION" in
  create)
    [[ -z "$FULL_NAME" ]] && FULL_NAME="$TARGET_USER"
    echo "Creating user '$TARGET_USER' ($FULL_NAME)..."
    if [[ "$MAKE_ADMIN" -eq 1 ]]; then
      sysadminctl -addUser "$TARGET_USER" -fullName "$FULL_NAME" -admin interactive
    else
      sysadminctl -addUser "$TARGET_USER" -fullName "$FULL_NAME" interactive
    fi
    echo "Created. Set a password at the interactive prompt above, or with:"
    echo "  sudo sysadminctl -resetPasswordFor $TARGET_USER -newPassword <password>"
    ;;

  disable)
    if ! dscl . -read "/Users/$TARGET_USER" RecordName >/dev/null 2>&1; then
      echo "No such user: $TARGET_USER" >&2
      exit 2
    fi
    echo "Disabling interactive login for '$TARGET_USER' (shell -> /usr/bin/false)..."
    dscl . -create "/Users/$TARGET_USER" UserShell /usr/bin/false
    echo "Done. Note: this does not revoke an existing Secure Token or FileVault unlock ability."
    ;;

  enable)
    if ! dscl . -read "/Users/$TARGET_USER" RecordName >/dev/null 2>&1; then
      echo "No such user: $TARGET_USER" >&2
      exit 2
    fi
    DEFAULT_SHELL="/bin/zsh"
    [[ -x /bin/zsh ]] || DEFAULT_SHELL="/bin/bash"
    echo "Re-enabling interactive login for '$TARGET_USER' (shell -> $DEFAULT_SHELL)..."
    dscl . -create "/Users/$TARGET_USER" UserShell "$DEFAULT_SHELL"
    ;;

  remove)
    echo "Removing user '$TARGET_USER'..."
    if [[ "$KEEP_HOME" -eq 1 ]]; then
      sysadminctl -deleteUser "$TARGET_USER" -keepHome
    else
      sysadminctl -deleteUser "$TARGET_USER"
    fi
    ;;

  list)
    echo "=== Local user accounts (UID >= 500, non-hidden) ==="
    while read -r user; do
      uid="$(dscl . -read "/Users/$user" UniqueID 2>/dev/null | awk '{print $2}')"
      [[ -z "$uid" ]] && continue
      (( uid < 500 )) && continue
      shell="$(dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}')"
      admin="no"
      dseditgroup -o checkmember -m "$user" admin >/dev/null 2>&1 && admin="yes"
      printf '%-20s uid=%-6s shell=%-20s admin=%s\n' "$user" "$uid" "$shell" "$admin"
    done < <(dscl . -list /Users | sort)
    ;;

  *)
    echo "Unknown action: $ACTION (expected create|disable|enable|remove|list)" >&2
    usage 1
    ;;
esac
