# New Mac bootstrap checklist

Day-0 setup for a Mac going into service (homelab box, small-office
workstation, or a server-ish role like a build machine or media server).
Not an MDM replacement — for a fleet, use MDM and treat this as the
manual fallback / what MDM is automating.

## Before anything else

- [ ] Confirm macOS version: `sw_vers`. Update if it's more than one major
      version behind (`update-and-patch.sh` handles the check + install).
- [ ] Set the computer name and hostname:
      `sudo scutil --set ComputerName "<name>"`,
      `sudo scutil --set HostName "<name>"`,
      `sudo scutil --set LocalHostName "<name>"`
- [ ] Create the working admin account via `sysadminctl` (see
      `../scripts/user-mgmt.sh`) rather than staying on the account from
      initial setup, if that one was a personal Apple ID-linked account.

## Security baseline

- [ ] Enable FileVault: `sudo fdesetup enable` (interactive — decide where
      the recovery key goes before running this). See
      [security-and-privacy-reference.md](security-and-privacy-reference.md).
- [ ] Confirm SIP is enabled: `csrutil status`.
- [ ] Confirm Gatekeeper is enabled: `spctl --status`.
- [ ] Turn on the application firewall:
      `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on`
- [ ] Leave Remote Login (SSH) off unless this Mac needs it
      (`systemsetup -getremotelogin`); if it does, deploy keys and disable
      password auth in `/etc/ssh/sshd_config` before exposing it to
      anything but the local network.
- [ ] Run `security-audit.sh` and confirm nothing is flagged.

## Time and updates

- [ ] Confirm network time sync is on: `systemsetup -getusingnetworktime`
      (`time-sync-check.sh` verifies this plus the offset).
- [ ] Set the automatic-update policy you actually want in System
      Settings -> General -> Software Update -> Automatic Updates,
      rather than leaving Apple's defaults unexamined — the defaults
      install security updates but not major OS upgrades.

## Backups

- [ ] Point Time Machine at a destination and confirm a first backup
      completes: `tmutil status`.
- [ ] Grant Full Disk Access to whatever will run `backup-verify.sh` on a
      schedule (Terminal, or the launchd job's binary) — without it,
      `tmutil` silently reports no backups.

## If this Mac runs unattended services

- [ ] Disable sleep for a server-ish role: `sudo pmset -a sleep 0
      disksleep 0` (leave display sleep alone if a display is attached
      and you still want it to blank).
- [ ] Enable automatic restart after a power failure:
      `sudo pmset -a autorestart 1`
- [ ] Install and register anything under Homebrew services rather than
      a standalone background process, so `launchctl`/`brew services`
      has one place to check status (see
      [launchd-cheatsheet.md](launchd-cheatsheet.md) and
      [homebrew-cheatsheet.md](homebrew-cheatsheet.md)).

## Baseline for future drift checks

- [ ] Run `package-inventory.sh -o baseline.txt` and keep the file — future
      runs with `-d baseline.txt` show what's changed.
