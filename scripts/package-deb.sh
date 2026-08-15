#!/usr/bin/env bash
# Build a Debian package for Linux Mint / Ubuntu / Debian.
#
# Looks for a binary in:
#   1) $1
#   2) ./out/AyuGram
#   3) extracted Flatpak fallback (optional, AYUGRAM_FROM_FLATPAK=1)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
ARCH="${ARCH:-amd64}"
BIN_IN="${1:-}"
OUT_DIR="${ROOT}/dist"
STAGE="${ROOT}/build/deb"

find_binary() {
  if [[ -n "$BIN_IN" && -x "$BIN_IN" ]]; then
    printf '%s\n' "$BIN_IN"
    return 0
  fi
  if [[ -x "${ROOT}/out/AyuGram" ]]; then
    printf '%s\n' "${ROOT}/out/AyuGram"
    return 0
  fi
  return 1
}

extract_from_flatpak() {
  local json url bundle mount
  need_cmd flatpak
  json="$(fetch_json "${FLATPAK_FALLBACK_API}/releases/latest")"
  url="$(json_first_browser_url "$json" ".flatpak")"
  [[ -n "$url" ]] || die "no Flatpak to extract"
  mkdir -p "${ROOT}/build"
  bundle="${ROOT}/build/ayugram-desktop.flatpak"
  log "downloading Flatpak to extract the binary"
  download "$url" "$bundle"
  ensure_flathub
  flatpak install --user -y --noninteractive "$bundle" || true
  local found
  found="$(find "${HOME}/.local/share/flatpak/app/${FLATPAK_ID}" -type f -name AyuGram 2>/dev/null | head -n1 || true)"
  [[ -n "$found" ]] || die "could not extract AyuGram from Flatpak"
  mkdir -p "${ROOT}/out"
  cp -f "$found" "${ROOT}/out/AyuGram"
  chmod +x "${ROOT}/out/AyuGram"
  printf '%s\n' "${ROOT}/out/AyuGram"
}

BIN="$(find_binary || true)"
if [[ -z "$BIN" ]]; then
  if [[ "${AYUGRAM_FROM_FLATPAK:-0}" == "1" ]]; then
    BIN="$(extract_from_flatpak)"
  else
    die "AyuGram binary not found. Run ./scripts/build-linux.sh first, or set AYUGRAM_FROM_FLATPAK=1"
  fi
fi

log "packaging $BIN as ${PKG_NAME}_${VERSION}_${ARCH}.deb"

rm -rf "$STAGE"
mkdir -p \
  "${STAGE}/DEBIAN" \
  "${STAGE}/usr/bin" \
  "${STAGE}/usr/share/applications" \
  "${STAGE}/usr/share/metainfo" \
  "${STAGE}/usr/share/dbus-1/services" \
  "${STAGE}/usr/share/icons/hicolor/256x256/apps" \
  "${STAGE}/usr/share/doc/${PKG_NAME}"

cp -f "$BIN" "${STAGE}/usr/bin/AyuGram"
chmod 755 "${STAGE}/usr/bin/AyuGram"
ln -sfn AyuGram "${STAGE}/usr/bin/ayugram"

cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.desktop" \
  "${STAGE}/usr/share/applications/com.ayugram.desktop.desktop"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.metainfo.xml" \
  "${STAGE}/usr/share/metainfo/com.ayugram.desktop.metainfo.xml"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.service" \
  "${STAGE}/usr/share/dbus-1/services/com.ayugram.desktop.service"

ICON_URL="https://raw.githubusercontent.com/AyuGram/AyuGramDesktop/dev/.github/AyuGram.png"
if download "$ICON_URL" "${STAGE}/usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png"; then
  :
else
  warn "could not download icon; package will use the default theme icon"
fi

cp -f "${ROOT}/LICENSE" "${STAGE}/usr/share/doc/${PKG_NAME}/copyright"
cp -f "${ROOT}/NOTICE" "${STAGE}/usr/share/doc/${PKG_NAME}/NOTICE"
printf 'AyuGram For Linux %s\n' "$VERSION" > "${STAGE}/usr/share/doc/${PKG_NAME}/README"

SIZE_KB="$(du -sk "${STAGE}/usr" | awk '{print $1}')"

cat > "${STAGE}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: ${REPO_OWNER} <https://github.com/${REPO_SLUG}>
Installed-Size: ${SIZE_KB}
Depends: libasound2 | libasound2t64, libc6, libglib2.0-0 | libglib2.0-0t64, libgtk-3-0 | libgtk-3-0t64, libpulse0, libx11-6, libxcb1, desktop-file-utils
Recommends: fonts-open-sans, xdg-utils
Provides: ${PKG_NAME}
Conflicts: ${PKG_NAME}
Homepage: https://github.com/${REPO_SLUG}
Description: AyuGram Desktop for Linux
 Unofficial Telegram client (AyuGram) packaged for Linux Mint,
 Ubuntu, Debian and derivatives. Ghost mode, anti-recall and the
 rest of AyuGram come from upstream AyuGramDesktop.
EOF

cat > "${STAGE}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
# Register tg:// handler if nothing else owns it yet.
if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default com.ayugram.desktop.desktop x-scheme-handler/tg || true
fi
exit 0
EOF
chmod 755 "${STAGE}/DEBIAN/postinst"

cat > "${STAGE}/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q || true
fi
exit 0
EOF
chmod 755 "${STAGE}/DEBIAN/postrm"

mkdir -p "$OUT_DIR"
DEB="${OUT_DIR}/${PKG_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$DEB"
log "wrote $DEB"
