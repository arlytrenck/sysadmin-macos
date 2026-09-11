# launchd cheatsheet

launchd is the one service manager for everything on macOS — boot-time
daemons, per-user background agents, and cron's job. There's no separate
"services" subsystem to learn on top of it.

## Domains

Every job is loaded into a domain, and the domain is part of its address:

| Domain                | Where jobs come from                              | Runs as |
|------------------------|----------------------------------------------------|---------|
| `system`               | `/Library/LaunchDaemons`                            | root, no GUI, always running |
| `system/<label>`       | one specific system daemon                          | — |
| `gui/<uid>`             | `~/Library/LaunchAgents`, `/Library/LaunchAgents`    | that user, only while logged into a GUI session |
| `user/<uid>`            | background agents not tied to a GUI session          | that user |

Get a UID with `id -u <username>`, or use `id -u` for yourself.

## Modern commands (10.11+)

The old `launchctl load`/`unload` pair still works but gives vague errors.
Prefer the domain-target commands:

```
launchctl list                                  # every loaded job, PID + last exit status
launchctl list <label>                          # just one, more detail
launchctl print system/<label>                  # full state: PID, run count, last exit, state
launchctl print gui/501/<label>                  # same, for a user agent (UID 501 here)
launchctl bootstrap system /path/to/some.plist   # load a daemon
launchctl bootstrap gui/501 /path/to/agent.plist # load a user agent (must be logged into that GUI session)
launchctl bootout system/<label>                 # unload
launchctl enable system/<label>                  # clear a job's disabled bit
launchctl disable system/<label>                  # set it (survives reboot; bootstrap alone does not)
launchctl kickstart -k system/<label>             # kill and relaunch now
```

`kickstart -k` is the right way to "restart a service" — it's one command
instead of bootout-then-bootstrap, and it works whether the job is
currently running or not.

## Plist anatomy

A launchd job is a property list, most often at:

- `/Library/LaunchDaemons/<reverse-dns-label>.plist` — system daemon
- `/Library/LaunchAgents/<label>.plist` — agent for every user
- `~/Library/LaunchAgents/<label>.plist` — agent for one user

Minimum fields worth knowing:

```xml
<key>Label</key>            <!-- the reverse-DNS identifier, matches the filename -->
<string>com.example.myjob</string>
<key>ProgramArguments</key>  <!-- argv, as an array — no shell involved -->
<array>
  <string>/usr/local/bin/myjob</string>
  <string>--flag</string>
</array>
<key>RunAtLoad</key><true/>              <!-- start as soon as it's loaded -->
<key>StartInterval</key><integer>3600</integer>   <!-- re-run every N seconds -->
<key>KeepAlive</key><true/>               <!-- relaunch if it exits -->
<key>StandardOutPath</key><string>/var/log/myjob.log</string>
<key>StandardErrorPath</key><string>/var/log/myjob.err</string>
```

`RunAtLoad` + no `KeepAlive`/`StartInterval` is a one-shot job. `StartInterval`
is launchd's cron equivalent; there's no separate `crontab` mechanism worth
using on macOS (it still exists, but Apple's own tools and most third-party
installers write launchd jobs instead).

After editing a plist, `bootout` then `bootstrap` it back (or `kickstart -k`
if only the running process needs to pick up a code change, not the plist
itself — `kickstart` does not reread the plist).

## Debugging a job that won't start

```
plutil -lint /path/to/some.plist       # is the XML even valid?
launchctl print system/<label>         # look at "last exit reason" and "state"
log show --predicate 'process == "myjob"' --last 1h    # unified log, that process only
```

A job with a bad plist or an unreadable/non-executable target binary
usually shows up as "spawn failed" or a nonzero last exit code in
`launchctl print`, not as a shell error — there's no shell in the loop.

## See also

- [macos-cheatsheet.md](macos-cheatsheet.md)
- `service-health-check.sh` in `../scripts/` — checks and kickstarts jobs by label
