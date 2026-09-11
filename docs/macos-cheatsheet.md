# macOS cheatsheet

macOS ships BSD userland tools, not GNU coreutils. Muscle memory from Linux
breaks in specific, predictable ways. This is the reference for those
breaks, plus the everyday commands for processes, files, permissions, and
disks.

## BSD vs. GNU: the traps

| Task                     | Linux (GNU)                  | macOS (BSD)                              |
|---------------------------|-------------------------------|-------------------------------------------|
| In-place sed edit         | `sed -i 's/a/b/' f`           | `sed -i '' 's/a/b/' f` (empty string required) |
| du to a fixed depth       | `du --max-depth=2`            | `du -d 2`                                  |
| stat, custom format       | `stat -c '%s %n' f`           | `stat -f '%z %N' f`                        |
| Relative date arithmetic  | `date -d '+1 day'`            | `date -v+1d`                               |
| Parse a fixed date string | `date -d '2026-01-01' +%s`    | `date -j -f '%Y-%m-%d' '2026-01-01' +%s`   |
| Extended regex in grep    | `grep -P '...'` (PCRE)        | no PCRE; use `grep -E` (ERE) or `pcre2grep` if installed |
| Resolve a symlink fully   | `readlink -f path`            | no `-f`; use `python3 -c "import os,sys;print(os.path.realpath(sys.argv[1]))" path` or install GNU coreutils |
| List by inode / block use | `ls --block-size=M`           | `ls -lh` (no `--block-size`)               |

If you need GNU tool behavior specifically, `brew install coreutils gnu-sed
grep` installs them prefixed with `g` (`gsed`, `ggrep`, `gdate`, ...) so
they don't shadow the system versions.

## Processes

```
ps aux                      # every process, BSD-style columns
ps -ef                      # every process, System V-style columns
top -o cpu                  # live, sorted by CPU
top -o mem                  # live, sorted by memory
pgrep -fl <pattern>         # find PIDs + command lines by pattern
kill -TERM <pid>            # ask a process to exit
kill -9 <pid>                # force it
lsof -p <pid>                # what a process has open
lsof -i :<port>              # what's listening on / using a port
```

## Files and permissions

```
ls -leO <path>               # long listing with ACLs (@) and flags (e)
xattr -l <path>               # list extended attributes (e.g. quarantine)
xattr -d com.apple.quarantine <path>   # clear the Gatekeeper quarantine flag
chflags uchg <path>           # set the user-immutable flag (blocks writes/deletes)
chflags nouchg <path>         # clear it
stat -f '%Sp %N' <path>       # permissions + name, human-readable mode
mdfind -name '<needle>'       # Spotlight search by filename
mdls <path>                   # every Spotlight metadata attribute for a file
```

## Disks and volumes

```
diskutil list                        # every disk and partition
diskutil info /                      # detail on one volume
diskutil apfs list                   # APFS containers and volumes
diskutil verifyVolume /              # check a volume without repairing
df -h                                 # usage per mounted volume
du -h -d 1 <path>                    # usage one level deep under a path
```

APFS mounts several synthetic system volumes you'll see in `df` output —
`Preboot`, `VM`, `Update`, `xarts`, `iSCPreboot`, `Hardware` — that aren't
independently manageable and aren't worth alerting on.

## System info

```
sw_vers                       # macOS product name, version, build
sysctl -n machdep.cpu.brand_string    # CPU model
system_profiler SPHardwareDataType    # full hardware summary (slow)
uptime                        # load averages + time since boot
sysctl vm.swapusage           # swap usage
nvram boot-args                # kernel boot args, if any are set
```

## See also

- [launchd-cheatsheet.md](launchd-cheatsheet.md) — services and scheduled jobs
- [homebrew-cheatsheet.md](homebrew-cheatsheet.md) — package management
- [security-and-privacy-reference.md](security-and-privacy-reference.md) — SIP, Gatekeeper, FileVault, TCC
