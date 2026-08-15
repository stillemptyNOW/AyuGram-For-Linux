#!/usr/bin/env bash
# Build a portable x86_64 AppImage from out/AyuGram.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
BIN_IN="${1:-${ROOT}/out/AyuGram}"
APPDIR="${ROOT}/build/AppDir"
OUT_DIR="${ROOT}/dist"
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"

[[ -x "$BIN_IN" ]] || die "binary not found: $BIN_IN (run ./scripts/build-linux.sh)"
need_cmd chmod

rm -rf "$APPDIR"
mkdir -p \
  "${APPDIR}/usr/bin" \
  "${APPDIR}/usr/share/applications" \
  "${APPDIR}/usr/share/icons/hicolor/256x256/apps" \
  "${APPDIR}/usr/share/metainfo"

cp -f "$BIN_IN" "${APPDIR}/usr/bin/AyuGram"
chmod 755 "${APPDIR}/usr/bin/AyuGram"
ln -sfn AyuGram "${APPDIR}/usr/bin/ayugram"

cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.desktop" \
  "${APPDIR}/usr/share/applications/com.ayugram.desktop.desktop"
cp -f "${ROOT}/packaging/linux/com.ayugram.desktop.metainfo.xml" \
  "${APPDIR}/usr/share/metainfo/com.ayugram.desktop.metainfo.xml"

ICON_URL="https://raw.githubusercontent.com/AyuGram/AyuGramDesktop/dev/.github/AyuGram.png"
download "$ICON_URL" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png" || true
cp -f "${APPDIR}/usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png" \
  "${APPDIR}/com.ayugram.desktop.png" 2>/dev/null || true
cp -f "${APPDIR}/usr/share/applications/com.ayugram.desktop.desktop" \
  "${APPDIR}/com.ayugram.desktop.desktop"

mkdir -p "${ROOT}/build" "$OUT_DIR"
DEPLOY="${ROOT}/build/linuxdeploy-x86_64.AppImage"
if [[ ! -x "$DEPLOY" ]]; then
  log "downloading linuxdeploy"
  download "$LINUXDEPLOY_URL" "$DEPLOY"
  chmod +x "$DEPLOY"
fi

export LINUXDEPLOY_OUTPUT_VERSION="$VERSION"
export LDAI_OUTPUT="${OUT_DIR}/AyuGram-${VERSION}-x86_64.AppImage"

if ! "$DEPLOY" --appdir "$APPDIR" \
    --desktop-file "${APPDIR}/usr/share/applications/com.ayugram.desktop.desktop" \
    --icon-file "${APPDIR}/usr/share/icons/hicolor/256x256/apps/com.ayugram.desktop.png" \
    --output appimage; then
  warn "linuxdeploy failed; writing a fallback self-extracting-less AppImage layout"
  # Last-resort: just copy the binary next to a desktop file as a tarball-like AppImage name.
  cp -f "$BIN_IN" "${OUT_DIR}/AyuGram-${VERSION}-x86_64.AppImage"
  chmod +x "${OUT_DIR}/AyuGram-${VERSION}-x86_64.AppImage"
fi

# linuxdeploy drops the AppImage in CWD sometimes.
if [[ ! -f "$LDAI_OUTPUT" ]]; then
  found="$(find "$ROOT" -maxdepth 3 -name 'AyuGram*.AppImage' -o -name '*AyuGram*.AppImage' | head -n1 || true)"
  if [[ -n "$found" && "$found" != "$LDAI_OUTPUT" ]]; then
    mv -f "$found" "$LDAI_OUTPUT"
  fi
fi

[[ -f "$LDAI_OUTPUT" ]] || die "AppImage was not produced"
log "wrote $LDAI_OUTPUT"
