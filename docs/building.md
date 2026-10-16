# Building

There are two ways to get the `AyuGram` binary into `out/`. Every packager (`package-deb.sh`, `package-appimage.sh`, `package-arch.sh`) works from there or from the portable tarball.

## 1. Repack the community Flatpak (what CI does, minutes)

```bash
sudo apt install flatpak ostree dpkg-dev python3 xz-utils   # Mint / Ubuntu / Debian
./scripts/ci-package.sh
```

It downloads the [0FL01/AyuGramDesktop-flatpak](https://github.com/0FL01/AyuGramDesktop-flatpak) bundle **for exactly the version in `VERSION.json`**, unpacks it with `ostree` (no Flathub, no runtime download), checks the binary is the portable build (glibc ≤ 2.31, no `/app/lib` references) and writes into `dist/`:

- `ayugram-desktop_<version>_amd64.deb`
- `AyuGram-<version>-linux-x64.tar.xz`
- `AyuGram-<version>-x86_64.AppImage`
- `ayugram-desktop-<version>.flatpak`
- `SHA256SUMS`

Override the bundle with `FLATPAK_URL=...` if you need a specific build.

On Arch, turn the tarball into a pacman package:

```bash
./scripts/package-arch.sh            # dist/ayugram-for-linux-bin-<version>-1-x86_64.pkg.tar.zst
./scripts/package-arch.sh --repo     # plus a pacman repo database (ayugram.db)
```

## 2. Compile upstream sources in Docker (hours)

Follows the official guide: https://github.com/AyuGram/AyuGramDesktop/blob/dev/docs/building-linux.md

`scripts/build-linux.sh` clones **AyuGram/AyuGramDesktop** at the tag from `VERSION.json` and builds it in `ghcr.io/telegramdesktop/tdesktop/centos_env:latest`.

Requirements: Git, Docker, ~30 GB free disk, a few hours.

```bash
./scripts/build-linux.sh
./scripts/package-deb.sh
./scripts/package-appimage.sh
```

If the prebuilt image does not match the AyuGram version, build the image locally with the official prepare script (needs Poetry and Docker Buildx, takes much longer):

```bash
PREPARE=1 ./scripts/build-linux.sh
```

### API credentials

By default the public Telegram Desktop pair from the official docs is used (`2040` / `b18441a1ff607e10a989891a5462e627`). Your own pair from https://my.telegram.org :

```bash
export TDESKTOP_API_ID=123456
export TDESKTOP_API_HASH=yourhash
./scripts/build-linux.sh
```

## GitHub Actions

`.github/workflows/linux-package.yml` (run it from the Actions tab):

1. **lint** — shellcheck on every script
2. **package** — `ci-package.sh` on Ubuntu, checks the `.deb` and runs `ldd` on the binary
3. **arch** — `package-arch.sh --repo` in an `archlinux:base-devel` container, installs the package and checks it
4. **release** — publishes everything as `v<version>`, including the pacman repo files

Inputs: `version` (empty = `VERSION.json`), `pkgrel` (bump to rebuild the same version for Arch), `publish`.

Pull requests that touch scripts or packaging run steps 1–3 without publishing.

`.github/workflows/check-upstream.yml` opens an issue every time AyuGram releases a new version, and says whether the community Flatpak for it is out yet.

## Releasing a new version

1. Wait for the community Flatpak of the new version (the upstream-check issue tells you).
2. Set `version` and `upstream_tag` in `VERSION.json`, and `DEFAULT_VERSION` in `scripts/common.sh`.
3. Run **Linux packages** from the Actions tab.
