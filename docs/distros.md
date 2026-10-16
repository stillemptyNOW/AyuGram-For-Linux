# Distro matrix

The binary needs x86_64 and glibc ≥ 2.28. Everything below is covered by the installer (`scripts/install.sh`).

| Distro | Installer default | Other options | Notes |
| --- | --- | --- | --- |
| Linux Mint 20 / 21 / 22 | `.deb` | Flatpak, AppImage, portable | first-class target |
| Ubuntu 20.04+ | `.deb` | Flatpak, AppImage, portable | |
| Debian 11 / 12 / 13 | `.deb` | Flatpak, AppImage, portable | |
| Pop!_OS, Zorin, elementary, KDE neon, MX | `.deb` | | Debian family |
| Arch, Manjaro, EndeavourOS, CachyOS, Garuda, Artix | pacman package | pacman repo, PKGBUILD, AUR | see [arch.md](arch.md) |
| Fedora | portable | Flatpak | |
| openSUSE, Void, Gentoo, Solus, others | portable | Flatpak, AppImage | |
| NixOS | — | nixpkgs `ayugram-desktop` | the installer does not manage Nix |

Official Windows/macOS builds stay on https://github.com/AyuGram/AyuGramDesktop/releases
