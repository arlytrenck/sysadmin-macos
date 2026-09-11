# Homebrew cheatsheet

Homebrew is the closest thing macOS has to a system package manager — it
isn't one (nothing here is required for macOS to function), but for a
server/homelab Mac it's where most CLI tools and background services come
from.

## Formulae vs. casks

- **Formula** — a CLI tool or library, built or fetched as a bottle
  (precompiled binary). `brew install jq`.
- **Cask** — a GUI application, or a CLI tool distributed as a `.pkg`/`.app`.
  `brew install --cask visual-studio-code`.

Both live in the same `brew` command and the same tap namespace; `--cask`
just tells Homebrew which catalog to look in.

## Day to day

```
brew update                    # refresh Homebrew's own metadata (not your packages)
brew outdated                  # what has a newer version available
brew upgrade                   # upgrade everything outdated
brew upgrade <formula>         # upgrade just one
brew list --versions           # installed formulae + versions
brew list --versions --cask    # installed casks + versions
brew info <formula>            # what it is, dependencies, caveats
brew uses --installed <formula> # what depends on this formula
brew cleanup                   # remove old versions and cached downloads
brew doctor                    # flag common environment problems
```

## Services

Homebrew wraps launchd for anything installed as a service (databases,
proxies, agents) rather than inventing its own supervisor:

```
brew services list                    # every Homebrew-managed service + status
brew services start <formula>         # load it now and on every login/boot
brew services stop <formula>          # unload it
brew services restart <formula>       # kickstart it
```

`brew services` is a thin wrapper over `launchctl bootstrap`/`bootout`
against plists Homebrew writes under `~/Library/LaunchAgents` (per-user
install) or `/Library/LaunchDaemons` (root install via `sudo brew
services`). See [launchd-cheatsheet.md](launchd-cheatsheet.md) if one of
these won't start and you need to look underneath the wrapper.

## Taps

A tap is an additional formula/cask repository beyond Homebrew's default:

```
brew tap <user>/<repo>          # add one
brew tap                        # list what's currently tapped
brew untap <user>/<repo>        # remove one
```

## Reproducing a machine's package set

```
brew bundle dump --file=Brewfile          # write everything installed to a Brewfile
brew bundle install --file=Brewfile        # install everything a Brewfile lists
brew bundle check --file=Brewfile          # verify without installing
```

A `Brewfile` is the practical equivalent of a `package-inventory.sh`
baseline for anything Homebrew manages — check it into your dotfiles repo
and `brew bundle install` gets a fresh Mac to the same package set.

## Never run brew with sudo

Homebrew installs into `/opt/homebrew` (Apple Silicon) or `/usr/local`
(Intel), both owned by the invoking user, and it refuses to run as root.
If a script needs to install packages during unattended provisioning, run
Homebrew's own steps as the target non-root user (`sudo -u <user> brew
...`), not as root directly.

## See also

- [macos-cheatsheet.md](macos-cheatsheet.md)
- `package-inventory.sh` and `update-and-patch.sh` in `../scripts/`
