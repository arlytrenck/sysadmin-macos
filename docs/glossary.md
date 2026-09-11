# Glossary

**APFS** — Apple File System, the default filesystem since macOS 10.13.
Uses space-sharing containers and volumes rather than fixed-size
partitions; a handful of synthetic system volumes (`Preboot`, `VM`,
`Update`, and others) exist alongside the visible `Macintosh HD`/`Data`
pair.

**Gatekeeper** — the code-signing/notarization enforcement layer that
decides whether downloaded software is allowed to run. Controlled with
`spctl`.

**launchd** — the service manager and init system: boots the machine,
supervises daemons and agents, and replaces both `init`/`systemd` and
`cron` from a Linux perspective. Controlled with `launchctl`.

**LaunchAgent / LaunchDaemon** — a launchd job definition (a `.plist`
file). An agent runs as a logged-in user in a GUI session; a daemon runs
as root with no session, starting at boot.

**Secure Token** — a per-user cryptographic credential required to unlock
an APFS volume encrypted with FileVault, or to authorize adding another
user who can do so. The first user created during setup gets one
automatically; users created later by `sysadminctl`/`dscl` may not,
depending on how they're created and whether FileVault is already on —
verify with `sysadminctl -secureTokenStatus <user>` before assuming a new
account can unlock the disk.

**SIP (System Integrity Protection)** — kernel-enforced restrictions on
modifying system files, injecting code into Apple-signed processes, and
similar, that apply even to root. Controlled (from Recovery Mode only)
with `csrutil`.

**TCC (Transparency, Consent, and Control)** — the permission system
behind Full Disk Access, camera/microphone access, Automation, and
Accessibility prompts. Grants are per-app and largely not scriptable by
design.

**dscl** — Directory Service command line utility; reads and writes local
(or bound directory) user/group records directly. Lower-level and more
error-prone than `sysadminctl` for account lifecycle, but the only way to
read/set individual attributes like `UserShell` or `IsHidden`.

**sysadminctl** — the higher-level, modern tool for creating, modifying,
and deleting user accounts; wraps the lower-level `dscl`/`pwpolicy`
mechanics with safer defaults.

**tmutil** — the Time Machine command-line utility: status, forcing a
backup, listing snapshots, comparing backups.
