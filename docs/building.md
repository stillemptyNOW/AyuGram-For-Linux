# Building AyuGram on Linux

This follows the official guide:

https://github.com/AyuGram/AyuGramDesktop/blob/dev/docs/building-linux.md

`scripts/build-linux.sh` clones **AyuGram/AyuGramDesktop** (tag from `VERSION.json`) and builds it in:

`ghcr.io/telegramdesktop/tdesktop/centos_env:latest`

## Requirements

- Git
- Docker + Buildx
- ~30 GB free disk
- several hours on a typical laptop
- optional: Poetry, for the official `prepare/linux.sh` step

## API credentials

By default the script uses the public Telegram Desktop API id/hash shipped in the official Linux docs (`2040` / `b18441a1ff607e10a989891a5462e627`).

To use your own pair from https://my.telegram.org :

```bash
export TDESKTOP_API_ID=123456
export TDESKTOP_API_HASH=yourhash
./scripts/build-linux.sh
```

## Output

- `out/AyuGram` — stripped binary
- `dist/ayugram-desktop_<version>_amd64.deb` after `./scripts/package-deb.sh`
- `dist/AyuGram-<version>-x86_64.AppImage` after `./scripts/package-appimage.sh`

## GitHub Actions

`.github/workflows/linux-package.yml` can:

- `source` — full Docker build (needs a large runner; GitHub-hosted disks are often too small)
- `flatpak-repack` — take the community Flatpak binary and wrap `.deb` + AppImage

Trigger it from the Actions tab (`workflow_dispatch`).
