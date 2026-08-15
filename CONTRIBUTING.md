# Contributing

This repository packages [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) for Linux. Feature requests that belong in the client itself should go upstream.

## Good contributions here

- Linux Mint / Ubuntu / Debian packaging fixes
- AppImage / Flatpak / `.deb` install bugs
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
./scripts/build-linux.sh
./scripts/package-deb.sh
```

Keep scripts POSIX-friendly bash (`set -euo pipefail`), and do not commit binaries.
