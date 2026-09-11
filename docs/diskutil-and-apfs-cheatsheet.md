# diskutil and APFS cheatsheet

APFS replaced HFS+ as the default filesystem in 10.13, and it changes how
disks are organized: a container holds volumes that share free space,
rather than fixed-size partitions that each own a slice of the disk.

## Reading the layout

```
diskutil list                    # every disk, container, and volume
diskutil list -plist              # same, as a plist for scripting
diskutil apfs list                 # just the APFS containers and their volumes
diskutil info /                    # detail on the volume mounted at /
diskutil info disk0                # detail on a physical disk (SMART status is here)
```

`diskutil list` output on a modern Mac usually shows something like:

```
/dev/disk0 (internal, physical):
   0:      GUID_partition_scheme                        *500.3 GB   disk0
   1:                        EFI EFI                     314.6 MB   disk0s1
   2:                 Apple_APFS Container disk3         500.0 GB   disk0s2

/dev/disk3 (synthesized):
   0:      APFS Container Scheme -                      +500.0 GB   disk3
   1:                APFS Volume Macintosh HD - Data     ...          disk3s1
   2:                APFS Volume Macintosh HD            ...          disk3s5
```

`disk0` is the physical device; `disk3` is a *synthesized* virtual disk
APFS creates to represent the container. Volumes live under the
container, not the physical disk — that's why `diskutil info /` reports
a `disk3s5`-style identifier, not `disk0s2`.

## Space accounting

Because volumes in a container share free space, `df` on two different
APFS volumes in the same container can show the same "available" figure —
that's not a bug, it means neither volume has a size cap and both are
drawing from the same pool. Check `diskutil apfs list` for actual
per-volume quotas (`Capacity Ceiling`) if any are set.

## Snapshots

APFS local snapshots are what Time Machine uses for local backups on the
startup disk, and what "hourly" Time Machine snapshots you see with no
external drive attached actually are.

```
tmutil listlocalsnapshots /                  # snapshots on the boot volume
tmutil listlocalsnapshotdates /               # just the dates, faster to parse
sudo tmutil deletelocalsnapshots <date>       # remove one (2001-02-03-040506 format)
```

These commands need Full Disk Access for whatever process runs them, same
as the rest of `tmutil` — see
[security-and-privacy-reference.md](security-and-privacy-reference.md).

## Verifying and repairing

```
diskutil verifyVolume /              # check without changing anything
diskutil repairVolume /               # only works from Recovery for the boot volume
diskutil verifyDisk disk0             # check the partition map itself
```

You cannot repair the volume you're currently booted from; boot into
Recovery Mode (or an external volume) for that.

## See also

- [macos-cheatsheet.md](macos-cheatsheet.md)
- `disk-usage-report.sh` and `disk-health-check.sh` in `../scripts/`
