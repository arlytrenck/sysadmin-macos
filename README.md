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

Just getting started. The layout and CI are wired up, but `scripts/` and
`docs/` are still empty — content will land incrementally, the same way
the Linux and Windows companions did.

## Layout

```
sysadmin-macos/
├── scripts/    # self-contained bash scripts, one task each
└── docs/       # runbooks, cheatsheets, and reference docs
```

## Usage

Once scripts land, review the source before running anything against a
production host. These will be starting points, not turnkey solutions —
adapt paths, thresholds, and tool choices to your environment.

## Requirements

- macOS with the built-in Bash 3.2, or a newer Bash from Homebrew
- Per-script tool requirements will be documented here as scripts are added

## Contributing

Bug reports, script/doc suggestions, and pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the process and style guidelines.
Pushes and PRs touching `scripts/**.sh` run through
[ShellCheck](.github/workflows/shellcheck.yml) in CI.

## License

MIT. See [LICENSE](LICENSE). Use at your own risk, no warranty.
