# Troubleshooting guide

Starting points for the problems that come up most, macOS-specific where
it matters.

## Mac won't boot / boots to a black or gray screen

- Hold the power button for the startup options menu (Apple Silicon) or
  the boot chime (Intel), and try Safe Mode (hold Shift after the chime,
  or select Safe Mode in the startup options). Safe Mode skips third-party
  kernel extensions, login items, and font caches — if it boots clean,
  the problem is one of those, not the OS itself.
- From Recovery Mode (hold Cmd+R at boot, or select it in the startup
  options), Disk Utility -> First Aid checks and repairs the boot
  volume. This is the one context where you can repair the volume you'd
  otherwise be booted from.
- An NVRAM/PRAM reset (rarely needed on Apple Silicon; still occasionally
  relevant on Intel) clears display, sound, and startup-disk settings
  that can cause a hang.

## Kernel panics

- Panic reports land in `/Library/Logs/DiagnosticReports/` as
  `Kernel-<date>.panic` (or `.ips` on newer macOS). The first few lines
  name the panicked process/thread and often a kernel extension.
- A panic that started after installing a specific piece of
  kernel-extension-based software (some VPN clients, some virtualization
  and driver software) is usually that software, not hardware. Check for
  an update or uninstall it as the first move.
- Recurring panics with no clear software trigger warrant Apple
  Diagnostics (hold D at startup) to rule out a hardware fault.

## "The app is running but the launchd job says it isn't" (or vice versa)

- `launchctl print <domain>/<label>` is the source of truth over
  `launchctl list`'s summary line — it shows the actual PID, last exit
  status, and whether the job is disabled.
- A LaunchAgent loaded into the wrong domain (system instead of the
  logged-in user's `gui/<uid>`) will show as loaded but never actually
  run as expected. See
  [launchd-cheatsheet.md](launchd-cheatsheet.md) on domains.

## Disk full, but Finder/`df` disagree with what you expect

- APFS local snapshots hold onto space from deleted files until they
  age out. `tmutil listlocalsnapshots /` shows what's pinning space;
  deleting old ones frees it immediately
  (see [diskutil-and-apfs-cheatsheet.md](diskutil-and-apfs-cheatsheet.md)).
- `../scripts/disk-usage-report.sh` filters out the synthetic APFS system
  volumes that otherwise clutter a `df` reading.

## Network works for some apps, not others

- Check per-app permissions before assuming a network problem: some
  apps need explicit Local Network permission (System Settings -> Privacy
  & Security -> Local Network), separate from general network access.
- `../scripts/network-diagnostics.sh` covers interface state, default
  route, DNS, and basic reachability in one pass, which usually narrows
  whether the problem is this Mac's network stack or something upstream.

## An app won't open ("is damaged and can't be opened")

- Usually Gatekeeper quarantine on something downloaded outside the App
  Store. `xattr -l /Applications/App.app` shows the quarantine flag;
  `xattr -d com.apple.quarantine /Applications/App.app` clears it — only
  do this for software you've verified yourself, since that flag exists
  specifically to make you pause. `spctl -a -vv /Applications/App.app`
  explains exactly why Gatekeeper is objecting.

## See also

- [macos-cheatsheet.md](macos-cheatsheet.md)
- [unified-logging-cheatsheet.md](unified-logging-cheatsheet.md) — `log show`/`log stream` for anything not covered above
