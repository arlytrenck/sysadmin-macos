# Security and privacy reference

The command-line surface for the security controls `security-audit.sh`
checks, and why each one matters.

## System Integrity Protection (SIP)

Restricts write access to system files and processes, and restricts
debugging/code-injection into Apple-signed processes, even from root.

```
csrutil status                  # "enabled" or a list of exceptions if partially disabled
```

SIP can only be toggled by rebooting into Recovery Mode and running
`csrutil enable`/`disable` there — there is no live command-line toggle,
by design. Treat a Mac with SIP disabled as compromised or
mid-development-work, not as routine configuration.

## Gatekeeper

Enforces code-signing and notarization checks before running downloaded
software.

```
spctl --status                          # "assessments enabled" or "disabled"
spctl -a -vv /path/to/App.app           # explain why Gatekeeper would allow/block one app
xattr -d com.apple.quarantine <path>    # clear the quarantine flag Gatekeeper checks against
                                         # (only do this for software you've verified yourself)
```

## FileVault

Full-disk encryption, enabled per-Mac and keyed either to user passwords
or an institutional/personal recovery key.

```
fdesetup status                 # "FileVault is On" / "Off"
fdesetup list                   # users currently enabled to unlock at boot
sudo fdesetup enable            # turn it on interactively (prompts for a recovery key choice)
```

Enabling FileVault from the command line still walks through an
interactive recovery-key prompt; it isn't a fire-and-forget operation, and
scripting past that prompt means deciding where the recovery key ends up,
which is a policy decision, not a scripting one.

## Application firewall

The built-in inbound-connection firewall (distinct from packet filtering —
this is application-level, allow/block by process).

```
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps
```

## Remote Login (SSH)

```
sudo systemsetup -getremotelogin           # "Remote Login: On/Off"
sudo systemsetup -setremotelogin on        # enable sshd
```

Off by default on a fresh Mac. `security-audit.sh` flags it as *on* purely
so you notice and confirm it's intentional — an SSH daemon you forgot
about is the more common failure mode on a machine that's supposed to be a
workstation, not a server.

## TCC (privacy permissions)

The permission system behind every "App wants to access your..." prompt —
Full Disk Access, camera, microphone, Automation, Accessibility. There is
no fully supported command-line way to grant these (the backing database,
`~/Library/Application Support/com.apple.TCC/TCC.db`, is itself SIP-protected).
For any script that needs Full Disk Access (`tmutil`, reading another
user's files, some `log show` queries), grant it once, by hand, to
whichever process actually runs the script — Terminal, a specific script
interpreter, or the launchd job's binary — under System Settings ->
Privacy & Security -> Full Disk Access.

## See also

- [macos-cheatsheet.md](macos-cheatsheet.md)
- `security-audit.sh` in `../scripts/`
