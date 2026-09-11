# Unified logging cheatsheet

macOS replaced syslog with the unified logging system in 10.12. There's
no `/var/log/system.log` with plain text you can `tail` and `grep`
anymore for most subsystems — everything goes through `log`, backed by a
binary store, with fields you filter on rather than lines you pattern-match.

## Reading logs

```
log show --last 1h                                    # everything, last hour
log show --last 1h --predicate 'eventMessage contains "error"'
log show --last 1h --predicate 'process == "sshd"'
log show --last 1h --predicate 'subsystem == "com.apple.backupd"'   # Time Machine
log stream --predicate 'process == "sshd"'              # live, instead of a time window
log show --style syslog --last 1h                       # classic syslog-like formatting
```

The predicate language is NSPredicate, not a regex or grep pattern:
`==`, `contains`, `beginswith`, `endswith`, and `&&`/`||` for combining
clauses. Append `[c]` to a string comparison (`contains[c]`) for
case-insensitive matching.

## Useful predicates

```
'process == "kernel"'                        # kernel messages only
'eventType == logEvent && messageType == error'
'subsystem == "com.apple.security"'           # security-relevant events
'category == "authentication"'
'process == "sshd" && eventMessage contains "Failed"'
```

## Crash and diagnostic reports

Unified logging isn't where crash reports live. Those are separate files:

```
~/Library/Logs/DiagnosticReports/           # per-user app crashes
/Library/Logs/DiagnosticReports/            # system-wide crashes, kernel panics
```

Console.app (GUI) reads both the unified log and these report
directories in one place, and is often faster for a first look than
constructing a `log show` predicate — reach for `log show`/`log stream`
once you know what you're looking for, or need it in a script.

## Persistence and retention

The unified log store rotates and ages out automatically (a few days of
detail by default, longer for less verbose levels), so `log show --last
7d` may return less than you expect on a Mac that's been busy. There's no
built-in way to extend retention beyond adjusting the store's size
policy in `/etc/asl.conf`-era configs, which unified logging mostly
superseded — if you need durable logs, ship them somewhere else
(a log-anomaly script, a SIEM forwarder) rather than relying on the local
store as an archive.

## See also

- `../scripts/` — none of the current scripts scan the unified log yet;
  a `log-anomaly-scan.sh` (comparing a live error rate against a trailing
  baseline, the way the Linux repo's does) is a natural next addition
