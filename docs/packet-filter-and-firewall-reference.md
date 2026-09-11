# Packet filter and firewall reference

macOS ships two independent firewall layers. They don't share
configuration, and checking one tells you nothing about the other.

## Application firewall (socketfilterfw)

The one exposed in System Settings -> Network -> Firewall. It's
application-level: allow or block by signed binary, not by port or
protocol.

```
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on   # don't respond to unsolicited probes (ping, closed-port SYNs)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall
```

Turning it on doesn't block anything by default beyond what's already
configured; it starts from "allow signed apps to receive incoming
connections" and you add exceptions or flip to block-all from there.

## pf (packet filter)

The actual packet-level firewall underneath, shared with FreeBSD/OpenBSD
lineage. Off by default in the sense that nothing loads a ruleset unless
something asks it to — Internet Sharing, certain VPN configurations, and
some third-party network tools load their own anchors while active.

```
sudo pfctl -s info               # is pf enabled, and basic stats
sudo pfctl -s rules               # currently loaded filter rules
sudo pfctl -s nat                 # currently loaded NAT rules
sudo pfctl -s Anchors              # anchors attached to the main ruleset
sudo pfctl -a '*' -s rules         # rules in every anchor, recursively
```

System Integrity Protection protects `/etc/pf.conf` and the anchors under
`/etc/pf.anchors/` from being modified by anything other than a
root-privileged, Apple-signed process — `pfctl` itself is signed and can
still load a ruleset at runtime (`sudo pfctl -f /path/to/rules.conf`),
but editing those protected files with an ordinary editor and expecting
`pfctl` to pick them up on the next boot works differently than on
FreeBSD; test any change with `-f` before assuming it survives a restart.

## Which one do you actually want?

For "block inbound connections to this Mac except from specific hosts,"
pf is the right layer — it does real port/protocol/source filtering.
The application firewall answers a narrower question: "should this
specific app be allowed to listen at all," which is useful but isn't a
substitute for port-level rules.

## See also

- `firewall-rules-dump.sh` in `../scripts/` — snapshots both layers in one pass
- [security-and-privacy-reference.md](security-and-privacy-reference.md)
