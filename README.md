# AyuGram For Linux

[ English | [Русский](README-RU.md) ]

**Unofficial Linux port of [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop)** — packages and installers for Linux Mint, Ubuntu, Debian, Fedora, Arch and other distributions.

Official AyuGram ships Windows and macOS binaries. This repository exists so Linux users can install the same client without building 25,000 commits by hand.

Current upstream: **AyuGram Desktop v7.0.9**

## What you get

| Feature | Status |
| --- | --- |
| Ghost mode | from upstream |
| Anti-recall / message history | from upstream |
| Fonts, streamer mode, translator | from upstream |
| Local Telegram Premium | from upstream |
| One-command install on Linux Mint | this repo |
| `.deb` for Mint / Ubuntu / Debian | this repo |
| AppImage | this repo |
| Flatpak fallback | this repo |
| Build-from-source scripts | this repo |

This is a packaging fork, not a rewrite. The client itself is [AyuGram/AyuGramDesktop](https://github.com/AyuGram/AyuGramDesktop), which is a fork of [Telegram Desktop](https://github.com/telegramdesktop/tdesktop).

Source fork on this account: [stillemptyNOW/AyuGramDesktop](https://github.com/stillemptyNOW/AyuGramDesktop)

## Quick install (Linux Mint, Ubuntu, Debian)

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

The script detects your distro and picks the best method:

1. `.deb` from this repo's Releases, if a package exists
2. otherwise Flatpak (works on Linux Mint out of the box)
3. AppImage, if you pass `--method appimage`

### Choose a method

```bash
# Linux Mint / Ubuntu / Debian package
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method deb

# Flatpak (recommended if you just want it working)
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method flatpak

# Portable AppImage
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method appimage

# Build official sources with Docker (long, needs ~30 GB)
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method source
```

### Other distros

| Distro | Command |
| --- | --- |
| **Linux Mint / Ubuntu / Debian** | installer above, or `sudo apt install ./ayugram-desktop_*_amd64.deb` |
| **Fedora** | `sudo dnf install ayugram-desktop` from [RPM Fusion](https://admin.rpmfusion.org/pkgdb/package/free/ayugram-desktop/) |
| **Arch / Manjaro** | `yay -S ayugram-desktop` or `yay -S ayugram-desktop-bin` |
| **NixOS** | `ayugram-desktop` from nixpkgs / [ndfined-crp](https://github.com/ndfined-crp/ayugram-desktop) |
| **Any distro** | Flatpak or AppImage from [Releases](https://github.com/stillemptyNOW/AyuGram-For-Linux/releases) |

Mint-specific notes: [docs/linux-mint.md](docs/linux-mint.md)

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/uninstall.sh | bash
```

## Build on your machine

Needs Git, Docker and Docker Buildx. On Linux Mint:

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
# install Docker from https://docs.docker.com/engine/install/ubuntu/
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/build-linux.sh
./scripts/package-deb.sh
./scripts/package-appimage.sh
```

Full guide: [docs/building.md](docs/building.md)

## Why this repository exists

| Official AyuGram | This fork |
| --- | --- |
| Windows `.zip` + macOS `.dmg` | Linux Mint / Ubuntu `.deb` |
| Linux **source only** | AppImage |
| Community Flatpak lives in another repo | one installer for Mint and friends |
| Arch / Fedora / Nix packaged by others | Debian-family first |

## Disclaimer

- Not affiliated with Telegram FZ-LLC or the AyuGram authors.
- AyuGram is an unofficial Telegram client with features that can break Telegram Terms of Service (Ghost mode, anti-recall, and others). Use at your own risk.
- Packaging scripts here are GPL-3.0. The application is GPL-3.0 with the OpenSSL exception, same as Telegram Desktop.

## Credits

- [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) — the client
- [Telegram Desktop](https://github.com/telegramdesktop/tdesktop) — upstream
- [0FL01/AyuGramDesktop-flatpak](https://github.com/0FL01/AyuGramDesktop-flatpak) — community Flatpak builds
- Kotatogram, 64Gram, Forkgram — related desktop forks

## License

[GPL-3.0](LICENSE) (Telegram Desktop / AyuGram terms, including the OpenSSL exception).
