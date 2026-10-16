# Contributing

This repository packages [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) for Linux. Feature requests that belong in the client itself should go upstream.

## Good contributions here

- Linux Mint / Ubuntu / Debian and Arch packaging fixes
- AppImage / Flatpak / `.deb` / pacman install bugs
- desktop integration (icons, MIME, Cinnamon / GNOME / KDE)
- new distro install paths in `scripts/install.sh`
- documentation in English or Russian

## Client features

Ghost mode, anti-recall, UI and protocol work belong in:

https://github.com/AyuGram/AyuGramDesktop

## Development

```bash
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/ci-package.sh   # or ./scripts/build-linux.sh for a source build
make check                # shellcheck + bash -n, also runs in CI
```

Keep scripts bash with `set -euo pipefail`, clean under `shellcheck -x`, and do not commit binaries.
