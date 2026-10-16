# AyuGram For Linux

[ English | [Русский](README-RU.md) ]

**Unofficial Linux packages of [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop)** for Linux Mint, Ubuntu, Debian, Arch Linux and any other x86_64 distro.

Official AyuGram ships Windows and macOS binaries only. This repository takes the portable Linux build (static Qt, glibc ≥ 2.28) from the community Flatpak and turns it into native packages, so you do not have to compile Telegram Desktop yourself.

Current upstream: **AyuGram Desktop v7.2.9**

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

The script detects your distro:

| Distro | What it installs |
| --- | --- |
| Linux Mint, Ubuntu, Debian, Pop!_OS, Zorin… | `.deb` from Releases (falls back to Flatpak) |
| Arch, Manjaro, EndeavourOS, CachyOS, Garuda… | pacman package from Releases (falls back to `makepkg`) |
| Fedora | portable build in `~/.local/opt` or Flatpak |
| anything else | portable build in `~/.local/opt`, no root needed |

### Pick a method yourself

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method deb
```

| `--method` | |
| --- | --- |
| `deb` | `.deb` package (Mint / Ubuntu / Debian) |
| `arch` | pacman package `ayugram-for-linux-bin` |
| `aur` | build `ayugram-desktop` from AUR with yay/paru (native libs, slow) |
| `flatpak` | Flatpak bundle |
| `appimage` | AppImage in `~/Applications` |
| `portable` | unpack into `~/.local/opt/AyuGram`, add menu entry and icons |
| `source` | build official sources with Docker (hours, ~30 GB) |

## Arch Linux

Three ways, from simplest:

```bash
# 1. the installer (downloads the prebuilt package and runs pacman -U)
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

```ini
# 2. pacman repo: add to /etc/pacman.conf, then `sudo pacman -Syu ayugram-for-linux-bin`
#    updates then arrive with the usual `sudo pacman -Syu`
[ayugram]
SigLevel = Optional TrustAll
Server = https://github.com/stillemptyNOW/AyuGram-For-Linux/releases/latest/download
```

```bash
# 3. build it yourself from the PKGBUILD
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/package-arch.sh
sudo pacman -U dist/ayugram-for-linux-bin-*-x86_64.pkg.tar.zst
```

The package only depends on `glibc`, `glib2`, `fontconfig` and `freetype2`, so Qt, abseil or ffmpeg updates in Arch never break it. Details and caveats: [docs/arch.md](docs/arch.md).

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/uninstall.sh | bash
```

Removes the `.deb`, pacman package, Flatpak, AppImage or portable install. Your chats in `~/.local/share/AyuGramDesktop` stay.

## Build the packages yourself

```bash
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
make package     # needs flatpak + ostree: .deb, .tar.xz, AppImage in dist/
make arch        # on Arch: pacman package from the tarball
make build       # or compile upstream sources in Docker instead (hours)
```

Full guide: [docs/building.md](docs/building.md). Mint notes: [docs/linux-mint.md](docs/linux-mint.md). Distro matrix: [docs/distros.md](docs/distros.md).

## Disclaimer

- Not affiliated with Telegram FZ-LLC or the AyuGram authors.
- AyuGram has features that break Telegram's Terms of Service (Ghost mode, anti-recall and others). Use at your own risk.
- Packaging scripts are GPL-3.0. The application is GPL-3.0 with the OpenSSL exception, same as Telegram Desktop.

## Credits

- [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) — the client
- [Telegram Desktop](https://github.com/telegramdesktop/tdesktop) — upstream
- [0FL01/AyuGramDesktop-flatpak](https://github.com/0FL01/AyuGramDesktop-flatpak) — community Flatpak builds, the source of the binary

## License

[GPL-3.0](LICENSE) (Telegram Desktop / AyuGram terms, including the OpenSSL exception).
