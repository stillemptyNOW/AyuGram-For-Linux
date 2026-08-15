#!/usr/bin/env bash
# CI / local packager: fetch AyuGram Linux binary, emit .deb, tar.xz, AppImage, Flatpak.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
DIST="${ROOT}/dist"
BUILD="${ROOT}/build"
OUT="${ROOT}/out"
FLATPAK_URL_FALLBACK="https://github.com/0FL01/AyuGramDesktop-flatpak/releases/download/flatpak-v7.0.9-20260809120143/ayugram-desktop-7.0.9.flatpak"

mkdir -p "$DIST" "$BUILD" "$OUT"

python_asset_url() {
  local api="$1" suffix="$2"
  python3 - "$api" "$suffix" <<'PY'
import json, sys, urllib.request
api, suffix = sys.argv[1], sys.argv[2]
req = urllib.request.Request(api, headers={"Accept": "application/vnd.github+json", "User-Agent": "AyuGram-For-Linux"})
with urllib.request.urlopen(req, timeout=60) as r:
    data = json.load(r)
for a in data.get("assets", []):
    name = a.get("name") or ""
    url = a.get("browser_download_url") or ""
    if name.endswith(suffix) or suffix in name:
        print(url)
        raise SystemExit(0)
raise SystemExit(1)
PY
}

log "resolving Flatpak URL for AyuGram ${VERSION}"
FLATPAK_URL="$(python_asset_url "${FLATPAK_FALLBACK_API}/releases/latest" ".flatpak" || true)"
if [[ -z "${FLATPAK_URL}" ]]; then
  warn "GitHub API did not return a Flatpak URL, using fallback"
  FLATPAK_URL="$FLATPAK_URL_FALLBACK"
fi

BUNDLE="${BUILD}/ayugram-desktop-${VERSION}.flatpak"
log "downloading $FLATPAK_URL"
download "$FLATPAK_URL" "$BUNDLE"
cp -f "$BUNDLE" "${DIST}/ayugram-desktop-${VERSION}.flatpak"

extract_via_ostree() {
  local repo="${BUILD}/ostree-repo"
  local checkout="${BUILD}/flatpak-checkout"
  rm -rf "$repo" "$checkout"
  mkdir -p "$repo"
  ostree init --repo="$repo" --mode=archive-z2
  log "importing Flatpak bundle into ostree"
  flatpak build-import-bundle "$repo" "$BUNDLE"
  log "ostree refs:"
  ostree --repo="$repo" refs || true
  local ref
  ref="$(ostree --repo="$repo" refs | awk '/ayugram|com\.ayugram|app\//{print; exit}')"
  if [[ -z "$ref" ]]; then
    ref="$(ostree --repo="$repo" refs | head -n1 || true)"
  fi
  [[ -n "$ref" ]] || return 1
  log "checking out $ref"
  ostree --repo="$repo" checkout "$ref" "$checkout"
  find "$checkout" -type f \( -name AyuGram -o -name ayugram-desktop \) -print || true
  local found
  found="$(find "$checkout" -type f \( -name AyuGram -o -name ayugram-desktop \) | head -n1 || true)"
  [[ -n "$found" ]] || return 1
  cp -f "$found" "${OUT}/AyuGram"
  chmod +x "${OUT}/AyuGram"
  log "extracted binary: ${OUT}/AyuGram ($(du -h "${OUT}/AyuGram" | awk '{print $1}'))"
}

extract_via_flatpak_install() {
  log "adding Flathub as a user remote"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak remotes --show-details || true
  log "installing GNOME Platform runtime"
  flatpak install --user -y --noninteractive flathub org.gnome.Platform//50
  log "installing Flatpak bundle"
  flatpak install --user -y --noninteractive "$BUNDLE"
  local found
  found="$(find "${HOME}/.local/share/flatpak/app/${FLATPAK_ID}" \
    \( -type f -name AyuGram -o -type f -name ayugram-desktop \) 2>/dev/null | head -n1 || true)"
  [[ -n "$found" ]] || return 1
  cp -f "$found" "${OUT}/AyuGram"
  chmod +x "${OUT}/AyuGram"
  log "extracted binary: ${OUT}/AyuGram ($(du -h "${OUT}/AyuGram" | awk '{print $1}'))"
}

if ! extract_via_ostree; then
  warn "ostree import failed, falling back to Flatpak install"
  extract_via_flatpak_install
fi
[[ -x "${OUT}/AyuGram" ]] || die "could not extract AyuGram binary"

log "building .deb"
VERSION="$VERSION" "${HERE}/package-deb.sh" "${OUT}/AyuGram"

log "building portable tarball"
PORTABLE="${BUILD}/AyuGram-${VERSION}-linux-x64"
rm -rf "$PORTABLE"
mkdir -p "${PORTABLE}/bin" "${PORTABLE}/share/applications" "${PORTABLE}/share/icons" "${PORTABLE}/share/metainfo"
cp -f "${OUT}/AyuGram" "${PORTABLE}/bin/AyuGram"
chmod 755 "${PORTABLE}/bin/AyuGram"
ln -sfn AyuGram "${PORTABLE}/bin/ayugram"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.desktop" "${PORTABLE}/share/applications/"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.metainfo.xml" "${PORTABLE}/share/metainfo/"
curl -fsSL "https://raw.githubusercontent.com/AyuGram/AyuGramDesktop/dev/.github/AyuGram.png" \
  -o "${PORTABLE}/share/icons/com.ayugram.desktop.png" || true
cat > "${PORTABLE}/README.txt" <<EOF
AyuGram For Linux ${VERSION}
Run: ./bin/AyuGram
Or copy bin/AyuGram to /usr/local/bin and the .desktop file to ~/.local/share/applications
EOF
(
  cd "$BUILD"
  tar -cJf "${DIST}/AyuGram-${VERSION}-linux-x64.tar.xz" "AyuGram-${VERSION}-linux-x64"
)
log "wrote ${DIST}/AyuGram-${VERSION}-linux-x64.tar.xz"

log "building AppImage"
DEPLOY="${BUILD}/linuxdeploy-x86_64.AppImage"
if [[ ! -x "$DEPLOY" ]]; then
  download "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" "$DEPLOY"
  chmod +x "$DEPLOY"
fi
APPDIR="${BUILD}/AppDir"
rm -rf "$APPDIR"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/icons/hicolor/256x256/apps" "${APPDIR}/usr/share/metainfo"
cp -f "${OUT}/AyuGram" "${APPDIR}/usr/bin/AyuGram"
chmod 755 "${APPDIR}/usr/bin/AyuGram"
ln -sfn AyuGram "${APPDIR}/usr/bin/ayugram"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.desktop" "${APPDIR}/usr/share/applications/"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.metainfo.xml" "${APPDIR}/usr/share/metainfo/"
cp -f "${PORTABLE}/share/icons/com.ayugram.desktop.png" \
  "${APPDIR}/usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png" 2>/dev/null || true

export APPIMAGE_EXTRACT_AND_RUN=1
export LDAI_OUTPUT="${DIST}/AyuGram-${VERSION}-x86_64.AppImage"
set +e
(
  cd "$BUILD"
  "$DEPLOY" --appimage-extract-and-run \
    --appdir "$APPDIR" \
    --desktop-file "${APPDIR}/usr/share/applications/com.ayugram.desktop.desktop" \
    --icon-file "${APPDIR}/usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png" \
    --output appimage
)
rc=$?
set -e
if [[ "$rc" -ne 0 || ! -f "$LDAI_OUTPUT" ]]; then
  found="$(find "$BUILD" "$ROOT" -maxdepth 3 -name 'AyuGram*.AppImage' ! -name 'linuxdeploy*' | head -n1 || true)"
  if [[ -n "$found" ]]; then
    mv -f "$found" "$LDAI_OUTPUT"
  else
    warn "AppImage tool failed; continuing without AppImage"
  fi
fi

log "dist contents:"
ls -lh "$DIST"
