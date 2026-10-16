#!/usr/bin/env bash
# CI / local packager: take the AyuGram binary out of the community Flatpak
# and emit .deb, portable .tar.xz, AppImage and the Flatpak bundle itself.
#
# The Flatpak ships the official-style portable build (static Qt, glibc 2.28),
# so the extracted binary runs on any x86_64 distro from ~2019 onwards.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
DIST="${ROOT}/dist"
BUILD="${ROOT}/build"
OUT="${ROOT}/out"

need_cmd python3
need_cmd ostree
need_cmd flatpak

rm -rf "$DIST" "$OUT"
mkdir -p "$DIST" "$BUILD" "$OUT"

# Flatpak bundle URL for exactly $VERSION (tags look like flatpak-v7.2.9-<stamp>).
flatpak_url_for_version() {
  python3 - "${FLATPAK_FALLBACK_API}/releases?per_page=50" "$1" <<'PY'
import json, sys, urllib.request
api, version = sys.argv[1], sys.argv[2]
req = urllib.request.Request(api, headers={"Accept": "application/vnd.github+json", "User-Agent": "AyuGram-For-Linux"})
with urllib.request.urlopen(req, timeout=60) as r:
    releases = json.load(r)
prefix = f"flatpak-v{version}-"
for rel in releases:  # newest first
    if rel.get("draft") or rel.get("prerelease") or not rel.get("tag_name", "").startswith(prefix):
        continue
    for a in rel.get("assets", []):
        if a.get("name", "").endswith(".flatpak"):
            print(a["browser_download_url"])
            raise SystemExit(0)
raise SystemExit(1)
PY
}

log "resolving Flatpak bundle for AyuGram ${VERSION}"
FLATPAK_URL="${FLATPAK_URL:-$(flatpak_url_for_version "$VERSION" || true)}"
[[ -n "$FLATPAK_URL" ]] || die "no Flatpak release for ${VERSION} in 0FL01/AyuGramDesktop-flatpak (set FLATPAK_URL to override)"

BUNDLE="${BUILD}/$(asset_flatpak "$VERSION")"
log "downloading $FLATPAK_URL"
download "$FLATPAK_URL" "$BUNDLE"
cp -f "$BUNDLE" "${DIST}/$(asset_flatpak "$VERSION")"

log "unpacking the bundle with ostree"
REPO="${BUILD}/ostree-repo"
CHECKOUT="${BUILD}/flatpak-checkout"
rm -rf "$REPO" "$CHECKOUT"
ostree init --repo="$REPO" --mode=archive-z2
flatpak build-import-bundle "$REPO" "$BUNDLE"
REF="$(ostree --repo="$REPO" refs | grep -m1 "^app/${FLATPAK_ID}/" || true)"
[[ -n "$REF" ]] || die "bundle has no app/${FLATPAK_ID} ref: $(ostree --repo="$REPO" refs | tr '\n' ' ')"
# -U: user mode, no chown (fails on CI runners otherwise).
ostree --repo="$REPO" checkout -U "$REF" "$CHECKOUT"

BIN_SRC="${CHECKOUT}/files/bin/AyuGram"
[[ -f "$BIN_SRC" ]] || BIN_SRC="$(find "${CHECKOUT}/files" -type f -name AyuGram | head -n1)"
[[ -n "$BIN_SRC" && -f "$BIN_SRC" ]] || die "AyuGram binary not found in the bundle"
install -Dm755 "$BIN_SRC" "${OUT}/AyuGram"

if [[ -d "${CHECKOUT}/files/share/icons/hicolor" ]]; then
  (
    cd "${CHECKOUT}/files/share/icons/hicolor"
    find . -name "${FLATPAK_ID}*" \( -type f -o -type l \) -exec install -Dm644 {} "${OUT}/icons/hicolor/{}" \;
  )
fi

# Sanity: the binary must be the portable build, not one linked against the
# Flatpak runtime (/app or GNOME Platform libraries).
python3 - "${OUT}/AyuGram" <<'PY'
import re, struct, sys
data = open(sys.argv[1], "rb").read()
assert data[:4] == b"\x7fELF", "not an ELF file"
glibc = sorted({tuple(map(int, v.split(b".")[1:])) for v in re.findall(rb"GLIBC_(2\.[0-9]+)", data)})
print(f"max GLIBC symbol version: 2.{glibc[-1][0]}")
if glibc[-1][0] > 31:
    sys.exit("binary needs glibc > 2.31; Mint 20 / Ubuntu 20.04 would break")
if b"/app/lib" in data:
    sys.exit("binary references /app/lib (Flatpak runtime build), refusing to repackage")
PY
log "binary: ${OUT}/AyuGram ($(du -h "${OUT}/AyuGram" | awk '{print $1}'))"

log "building .deb"
VERSION="$VERSION" "${HERE}/package-deb.sh" "${OUT}/AyuGram"

log "building portable tarball"
PORTABLE_NAME="AyuGram-${VERSION}-linux-x64"
PORTABLE="${BUILD}/${PORTABLE_NAME}"
rm -rf "$PORTABLE"
stage_system_tree "${OUT}/AyuGram" "$PORTABLE" "$VERSION"
cp -f "${ROOT}/LICENSE" "${ROOT}/NOTICE" "$PORTABLE/"
cat > "${PORTABLE}/README.txt" <<EOF
AyuGram For Linux ${VERSION}

Run without installing:
  ./bin/AyuGram

Install for the current user (menu entry, icons, tg:// links):
  curl -fsSL ${RAW_BASE}/scripts/install.sh | bash -s -- --method portable

Arch Linux: this archive is the source of the ${ARCH_PKG_NAME} package.
EOF
tar -C "$BUILD" --owner=0 --group=0 -cJf "${DIST}/$(asset_tarball "$VERSION")" "$PORTABLE_NAME"
log "wrote ${DIST}/$(asset_tarball "$VERSION")"

log "building AppImage"
VERSION="$VERSION" "${HERE}/package-appimage.sh" "${OUT}/AyuGram" || warn "AppImage failed; release continues without it"

(
  cd "$DIST"
  sha256sum -- * > SHA256SUMS
)
log "dist contents:"
ls -lh "$DIST"
