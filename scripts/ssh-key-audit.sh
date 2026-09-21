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

if [[ "$EUID" -ne 0 ]]; then
  echo "Heads up: not running as root — other users' home directories are unreadable to you," >&2
  echo "so their authorized_keys will be skipped silently. Run with sudo for full coverage." >&2
  echo >&2
fi

echo "=== sshd effective config: key auth vs. password auth ==="
# `sshd -T` prints the effective config (main file plus the sshd_config.d
# drop-ins macOS ships) but needs root; without it, fall back to grepping the
# files, which shows only what's set explicitly.
if [[ "$EUID" -eq 0 ]] && SSHD_T="$(sshd -T 2>/dev/null)"; then
  echo "$SSHD_T" | grep -Ei '^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin) ' || true
  if echo "$SSHD_T" | grep -Eqi '^permitrootlogin yes$'; then
    echo "FLAG: sshd permits root login with a password (PermitRootLogin yes)."
    FLAGGED=1
  fi
elif [[ -r /etc/ssh/sshd_config ]]; then
  grep -Ei '^[[:space:]]*(PasswordAuthentication|PubkeyAuthentication|PermitRootLogin)([[:space:]]|$)' \
    /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null \
    || echo "(no explicit settings — defaults apply)"
else
  echo "/etc/ssh/sshd_config not readable (need sudo, or Remote Login is off)"
fi

# True if the path is group- or world-writable: sshd's StrictModes then
# refuses to use the file, and anyone with that access can plant a key.
loose_perms() {
  local mode
  mode="$(stat -f '%Lp' "$1" 2>/dev/null || echo 0)"
  (( 8#$mode & 8#022 ))
}

echo
echo "=== authorized_keys by user ==="
while read -r home; do
  user="$(basename "$home")"
  akfile="$home/.ssh/authorized_keys"
  [[ -r "$akfile" ]] || continue

  echo "-- $user --"
  if loose_perms "$home/.ssh" || loose_perms "$akfile"; then
    echo "FLAG: $user has a group/world-writable ~/.ssh or authorized_keys."
    FLAGGED=1
  fi

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue

    # A line may start with options (command="...", from=...) before the key
    # type, so find the type by pattern rather than taking field 1.
    keytype="$(awk '{for (i=1; i<=NF; i++) if ($i ~ /^(ssh-|ecdsa-|sk-)/) {print $i; exit}}' <<< "$line")"
    if [[ -z "$keytype" ]]; then
      echo "FLAG: $user has an unparseable authorized_keys line (no key type found)."
      FLAGGED=1
      continue
    fi

    fpline="$(ssh-keygen -lf /dev/stdin <<< "$line" 2>/dev/null || true)"
    bits="$(awk '{print $1}' <<< "$fpline")"
    fp="$(awk '{print $2}' <<< "$fpline")"

    case "$keytype" in
      ssh-dss)
        echo "FLAG: $user has a DSA key — deprecated and disabled in modern OpenSSH; replace it."
        FLAGGED=1
        ;;
      ssh-rsa)
        if [[ "$bits" =~ ^[0-9]+$ ]] && (( bits < 2048 )); then
          echo "FLAG: $user has a ${bits}-bit RSA key (2048 is the floor, 3072+ preferred)."
          FLAGGED=1
        fi
        ;;
      ssh-ed25519|ecdsa-sha2-*|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-*)
        : # fine
        ;;
      *)
        echo "FLAG: $user has an unrecognized key type: $keytype"
        FLAGGED=1
        ;;
    esac

    # Everything after the base64 blob is the comment.
    comment="$(awk -v t="$keytype" '{for (i=1; i<=NF; i++) if ($i == t) {for (j=i+2; j<=NF; j++) printf "%s%s", $j, (j<NF ? " " : ""); exit}}' <<< "$line")"
    if [[ -z "$comment" ]]; then
      echo "FLAG: $user has a key with no comment — can't tell who/what issued it."
      FLAGGED=1
    fi

    if [[ -n "$fp" ]]; then echo "$fp $user" >> "$TMP_FINGERPRINTS"; fi
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
