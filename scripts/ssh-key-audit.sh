#!/usr/bin/env bash
#
# ssh-key-audit.sh — audit authorized_keys for every local user, and flag
# the common problems: weak key types, missing comments, and keys shared
# across multiple accounts (a sign a key wasn't issued per-person).
#
# Usage:
#   ./ssh-key-audit.sh
#
# Options:
#   -h   Show this help
#
# Exit codes:
#   0  nothing flagged
#   2  one or more problems found

set -euo pipefail

usage() { sed -n '2,/^[^#]/p' "$0" | sed '1{/^#$/d;}; $d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while getopts ":h" opt; do
  case "$opt" in
    h) usage 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage 1 ;;
  esac
done

FLAGGED=0
TMP_FINGERPRINTS="$(mktemp)"
trap 'rm -f "$TMP_FINGERPRINTS"' EXIT

echo "=== sshd_config: key auth vs. password auth ==="
if [[ -r /etc/ssh/sshd_config ]]; then
  grep -Ei '^\s*(PasswordAuthentication|PubkeyAuthentication|PermitRootLogin)\b' /etc/ssh/sshd_config || echo "(no explicit settings — defaults apply)"
else
  echo "/etc/ssh/sshd_config not readable (need sudo, or Remote Login is off)"
fi

echo
echo "=== authorized_keys by user ==="
while read -r home; do
  user="$(basename "$home")"
  akfile="$home/.ssh/authorized_keys"
  [[ -r "$akfile" ]] || continue

  echo "-- $user --"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue

    keytype="$(awk '{print $1}' <<< "$line")"
    case "$keytype" in
      ssh-rsa|ssh-dss)
        echo "FLAG: $user has a $keytype key (RSA should be 3072+ bit; DSA is deprecated) — verify bit length or replace with ed25519."
        FLAGGED=1
        ;;
      ssh-ed25519|ecdsa-sha2-*)
        : # fine
        ;;
      *)
        echo "FLAG: $user has an unrecognized/unexpected key-type line: $keytype"
        FLAGGED=1
        ;;
    esac

    comment="$(awk '{print $NF}' <<< "$line")"
    if [[ "$comment" == "$keytype" || "$comment" == ssh-* ]]; then
      echo "FLAG: $user has a key with no comment — can't tell who/what issued it."
      FLAGGED=1
    fi

    fp="$(ssh-keygen -lf /dev/stdin <<< "$line" 2>/dev/null | awk '{print $2}')"
    [[ -n "$fp" ]] && echo "$fp $user" >> "$TMP_FINGERPRINTS"
  done < "$akfile"
done < <(dscl . -list /Users NFSHomeDirectory 2>/dev/null | awk '{print $2}' | sort -u)

echo
echo "=== Keys shared across multiple accounts ==="
if [[ -s "$TMP_FINGERPRINTS" ]]; then
  while read -r dupfp; do
    echo "FLAG: fingerprint $dupfp appears for multiple users:"
    grep "^$dupfp " "$TMP_FINGERPRINTS" | awk '{print "  - "$2}'
    FLAGGED=1
  done < <(awk '{print $1}' "$TMP_FINGERPRINTS" | sort | uniq -d)
fi

if [[ "$FLAGGED" -eq 1 ]]; then
  exit 2
fi
echo
echo "Nothing flagged."
