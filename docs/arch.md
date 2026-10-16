# Arch Linux

Package: **`ayugram-for-linux-bin`** (provides `ayugram-desktop`).

Works on Arch and its derivatives: Manjaro, EndeavourOS, CachyOS, Garuda, Artix, ArcoLinux.

## What the package is

It repackages the portable AyuGram build from this repo's Releases (the same binary as the `.deb`): Qt, ffmpeg, OpenSSL and WebRTC are linked statically, only glibc ≥ 2.28, GLib, fontconfig and freetype come from the system.

That is the opposite of the AUR `ayugram-desktop` package, which compiles against Arch's `qt6-base`, `abseil-cpp`, `protobuf` and friends. The native build integrates a bit tighter with Plasma, but it needs a rebuild every time one of those libraries changes soname. This one does not.

| | `ayugram-for-linux-bin` | AUR `ayugram-desktop` |
| --- | --- | --- |
| install time | seconds | 30–90 min of compiling |
| breaks on library updates | no | needs a rebuild |
| uses system Qt theme | no (bundled Qt) | yes |
| updates | `pacman -Syu` with the repo below | AUR helper |

The installer can do either: `--method arch` (default on Arch) or `--method aur`.

## Install

### Installer

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

It downloads `ayugram-for-linux-bin-<version>-<rel>-x86_64.pkg.tar.zst` from the release and runs `sudo pacman -U`. If the release has no package (or GitHub's API is rate limited), it builds one locally with `makepkg`, which needs `base-devel` and a non-root user.

### pacman repository (updates with `pacman -Syu`)

Add to `/etc/pacman.conf`, below the official repos:

```ini
[ayugram]
SigLevel = Optional TrustAll
Server = https://github.com/stillemptyNOW/AyuGram-For-Linux/releases/latest/download
```

```bash
sudo pacman -Syu ayugram-for-linux-bin
```

The repo is the `ayugram.db` file attached to the latest GitHub Release. Packages are **not GPG-signed**, hence `SigLevel = Optional TrustAll`: you trust this GitHub repository and its CI. If that is not acceptable, use the PKGBUILD and check the sha256 yourself.

### PKGBUILD

```bash
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/package-arch.sh          # renders dist/PKGBUILD and runs makepkg
sudo pacman -U dist/ayugram-for-linux-bin-*-x86_64.pkg.tar.zst
```

Every release also carries a ready `PKGBUILD` (and `SRCINFO`) that downloads the tarball by itself, so this works too:

```bash
mkdir ayugram && cd ayugram
curl -fLO https://github.com/stillemptyNOW/AyuGram-For-Linux/releases/latest/download/PKGBUILD
makepkg -si
```

The template lives in [packaging/arch/PKGBUILD.in](../packaging/arch/PKGBUILD.in); `scripts/package-arch.sh` fills in the version and checksum.

## Optional dependencies

| Package | For |
| --- | --- |
| `libpulse` | sound (also needed with PipeWire, via `pipewire-pulse`) |
| `alsa-lib` | sound on plain ALSA |
| `libva` | hardware video decoding |
| `webkit2gtk-4.1` | in-app browser for bots and Mini Apps |
| `xdg-desktop-portal` + a backend (`-gtk`, `-kde`, `-hyprland`…) | native file dialogs, screen sharing on Wayland |
| `ttf-opensans` | the font Telegram is designed for |

## Troubleshooting

**No sound / calls are silent.** `sudo pacman -S libpulse` (with PipeWire also `pipewire-pulse`).

**Window does not appear on Wayland / tiling WM.** Try X11 mode: `QT_QPA_PLATFORM=xcb AyuGram`.

**`tg://` links open something else.** `xdg-mime default com.ayugram.desktop.desktop x-scheme-handler/tg`

**Conflicts with `ayugram-desktop`.** Only one AyuGram package can be installed. `sudo pacman -R ayugram-desktop` first, your profile in `~/.local/share/AyuGramDesktop` is not touched.

## Uninstall

```bash
sudo pacman -R ayugram-for-linux-bin
```

Then remove the `[ayugram]` section from `/etc/pacman.conf` if you added it.
