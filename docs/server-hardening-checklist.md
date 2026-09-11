# Server hardening checklist

For a Mac running unattended or exposed to more than a trusted local
network: a Mac mini as a build agent, a media server, a small office's
file-sharing box. Not a replacement for MDM at fleet scale — the manual
version of what MDM would enforce.

## Accounts

- [ ] No shared logins. One account per person, created with
      `../scripts/user-mgmt.sh` or `sysadminctl`, not a single admin
      account everyone uses.
- [ ] The account doing day-to-day work is not an administrator.
      `dseditgroup -o checkmember -m <user> admin` shows whether it is.
- [ ] Guest User is off: System Settings -> Users & Groups -> Guest User,
      or `sysadminctl -guestAccount off`.
- [ ] Automatic login is off (System Settings -> Users & Groups -> Login
      Options) unless there's a specific, understood reason it's on.

## Network exposure

- [ ] Remote Login (SSH) is off unless this Mac is meant to be reachable
      that way: `systemsetup -getremotelogin`.
- [ ] If SSH is on: key-based auth only. Set
      `PasswordAuthentication no` in `/etc/ssh/sshd_config`, confirm keys
      work first, then restart `sshd`
      (`sudo launchctl kickstart -k system/com.openssh.sshd`).
- [ ] Screen Sharing / Remote Management is off unless actively used
      (System Settings -> General -> Sharing).
- [ ] AirDrop, File Sharing, and any other Sharing service not in active
      use are off, on the same screen.
- [ ] `../scripts/listening-ports-audit.sh -a "<allowlist>"` runs clean
      against the ports this Mac is actually supposed to expose.

## The built-in security stack

- [ ] SIP enabled: `csrutil status`.
- [ ] Gatekeeper enabled: `spctl --status`.
- [ ] FileVault on: `fdesetup status`.
- [ ] Application firewall on: `socketfilterfw --getglobalstate`.
- [ ] `../scripts/security-audit.sh` runs clean.

## Updates

- [ ] Automatic security updates are on (System Settings -> General ->
      Software Update -> Automatic Updates) even if major-version
      upgrades are deferred deliberately.
- [ ] `../scripts/pending-reboot-check.sh` isn't sitting on a
      restart-required update indefinitely.

## If it's headless / unattended

- [ ] Sleep disabled: `sudo pmset -a sleep 0 disksleep 0`.
- [ ] Auto-restart after power failure:
      `sudo pmset -a autorestart 1`.
- [ ] A monitoring path exists for "did this Mac come back after a
      restart" — this repo doesn't ship one yet, but a launchd
      `RunAtLoad` job that pings somewhere on boot is the shape of it.

## Verify, don't assume

Run `security-audit.sh` after making any of these changes, not just
once at setup — a macOS update or a careless System Settings click can
silently revert one of them.

## See also

- [security-and-privacy-reference.md](security-and-privacy-reference.md)
- [packet-filter-and-firewall-reference.md](packet-filter-and-firewall-reference.md)
- [new-mac-bootstrap-checklist.md](new-mac-bootstrap-checklist.md) — day-0 setup this checklist assumes already happened
