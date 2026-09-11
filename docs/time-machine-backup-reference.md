# Time Machine backup reference

The mechanics behind `backup-verify.sh`, and the design questions worth
answering before trusting Time Machine as your only backup.

## How it actually works

Time Machine takes hourly local snapshots (APFS snapshots on the startup
volume) and, separately, periodic backups to whatever destination you've
configured — an external drive, a Time Capsule-style network share, or
an SMB/AFP share advertising itself as a Time Machine destination. Local
snapshots exist even with no destination attached; they get thinned
automatically as the volume needs the space, and they are not a backup
by themselves since they live on the same physical disk.

## Command-line surface

```
tmutil status                        # is a backup running right now, and its phase
tmutil latestbackup                   # path to the most recent completed backup
tmutil listbackups                    # every backup Time Machine knows about
tmutil compare                        # what changed between the last two backups
tmutil startbackup                    # kick one off now
tmutil destinationinfo                # configured destination(s) and free space
```

Everything here needs Full Disk Access granted to whatever process runs
it (Terminal, or the binary behind a scheduled script) — without it,
`tmutil` doesn't error loudly, it just reports nothing, which is the
failure mode `backup-verify.sh` is written to catch by treating "no
backup found" as a hard failure rather than assuming Time Machine must be
off.

## Exclusions

```
tmutil isexcluded /path/to/thing              # is this path excluded?
sudo tmutil addexclusion /path/to/thing        # exclude it
sudo tmutil removeexclusion /path/to/thing     # stop excluding it
```

Large, regenerable directories (build caches, container image layers, a
local package-manager cache) are worth excluding explicitly rather than
backing them up hourly and paying for it in destination space and backup
time.

## What Time Machine alone doesn't give you

- **Off-site copy.** A local external drive backs up against disk
  failure and accidental deletion, not against theft, fire, or the drive
  being physically next to the Mac when something happens to both.
- **Versioned, verified restore testing.** Time Machine backups can look
  complete and still fail to restore a specific file if the backup was
  interrupted at the wrong moment. `backup-verify.sh` checks that a
  backup exists and is recent; it does not attempt a restore.
- **Point-in-time consistency for databases.** A database file mid-write
  when a backup snapshot happens can back up in a torn state. If a Mac
  runs a database service, treat that data's backup as a separate
  problem from Time Machine, with its own dump-and-verify step.

## See also

- `backup-verify.sh` in `../scripts/`
- [diskutil-and-apfs-cheatsheet.md](diskutil-and-apfs-cheatsheet.md) — local snapshot commands
- [security-and-privacy-reference.md](security-and-privacy-reference.md) — Full Disk Access
