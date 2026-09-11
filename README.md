# sysadmin-macos

[![ShellCheck](https://github.com/arlytrenck/sysadmin-macos/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/arlytrenck/sysadmin-macos/actions/workflows/shellcheck.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A collection of macOS system-administration scripts, runbooks, and
reference documentation, gathered from day-to-day homelab and small-fleet
operations. Companion repo to
[sysadmin-linux](https://github.com/arlytrenck/sysadmin-linux) and
[sysadmin-windows](https://github.com/arlytrenck/sysadmin-windows), which
cover the same ground for Linux and Windows Server.

## Status

Early days — a first batch of scripts and docs, growing incrementally the
same way the Linux and Windows companions did. Not yet at their depth.

## Layout

```
sysadmin-macos/
├── scripts/
│   ├── disk-usage-report.sh      # filesystem usage + largest dirs, threshold alerting
│   ├── user-mgmt.sh              # create/disable/enable/remove local users
│   ├── service-health-check.sh   # check & kickstart-restart launchd jobs
│   ├── update-and-patch.sh       # softwareupdate + brew wrapper, with logging
│   ├── network-diagnostics.sh    # interfaces, routing, DNS, reachability
│   ├── security-audit.sh         # SIP, Gatekeeper, FileVault, firewall, admin group
│   ├── package-inventory.sh      # apps + Homebrew + pkg receipts, diff baselines
│   ├── pending-reboot-check.sh   # detect whether a software update needs a restart
│   ├── time-sync-check.sh        # network time sync status + offset threshold
│   └── backup-verify.sh          # assert a Time Machine backup exists and is recent
└── docs/
    ├── README.md                              # index of everything below
    ├── macos-cheatsheet.md                    # BSD vs. GNU traps, processes, disks
    ├── launchd-cheatsheet.md                  # domains, bootstrap/bootout/kickstart, plists
    ├── homebrew-cheatsheet.md                 # formulae/casks, brew services, Brewfiles
    ├── security-and-privacy-reference.md      # SIP, Gatekeeper, FileVault, firewall, TCC
    ├── new-mac-bootstrap-checklist.md         # day-0 procedure for a fresh Mac
    └── glossary.md
```

## Usage

Each script is self-contained bash, and documents its own options via
`-h`. Review the source before running anything against a production
host. These are starting points, not turnkey solutions, and you should
adapt paths, thresholds, and tool choices to your environment.

```bash
chmod +x scripts/*.sh
./scripts/disk-usage-report.sh -h
```

## Requirements

- macOS with the built-in Bash 3.2 (all scripts here target it
  specifically — no Bash 4+ syntax), or a newer Bash from Homebrew
- Standard BSD userland (these scripts assume BSD `du`/`sed`/`date`/`stat`,
  not GNU coreutils — see [docs/macos-cheatsheet.md](docs/macos-cheatsheet.md))
- `sysadminctl`, `dscl`, `dseditgroup` (all built in) for `user-mgmt.sh`
- `launchctl` (built in) for `service-health-check.sh`
- `softwareupdate` (built in) for `update-and-patch.sh` and
  `pending-reboot-check.sh`; `brew` is optional and skipped cleanly if
  absent
- `dig` (built in) for `network-diagnostics.sh`, with a `host` fallback
- `csrutil`, `spctl`, `fdesetup`, `socketfilterfw`, `systemsetup` (all
  built in) for `security-audit.sh`
- `mdfind` (built in) for `package-inventory.sh`; `brew` and `pkgutil`
  sections are skipped/empty if not applicable
- `systemsetup`, `sntp` (both built in) for `time-sync-check.sh`
- `tmutil` (built in) for `backup-verify.sh` — needs Full Disk Access
  granted to whatever process runs it, or it silently reports no backups
- Several scripts (`user-mgmt.sh`, install actions in `update-and-patch.sh`,
  parts of `security-audit.sh`) need to run as root via `sudo`

## Contributing

Bug reports, script/doc suggestions, and pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the process and style guidelines.
Pushes and PRs touching `scripts/**.sh` run through
[ShellCheck](.github/workflows/shellcheck.yml) in CI.

## License

MIT. See [LICENSE](LICENSE). Use at your own risk, no warranty.
