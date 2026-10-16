#!/usr/bin/env bash
# Build a portable x86_64 AppImage from out/AyuGram.
#
# The binary is already self-contained (static Qt), so there is nothing to
# bundle: appimagetool just wraps an AppDir. linuxdeploy is not used because it
# rejects the "Exec=env ..." desktop entry and drags host libraries in.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
BIN_IN="${1:-${ROOT}/out/AyuGram}"
APPDIR="${ROOT}/build/AppDir"
OUT_DIR="${ROOT}/dist"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
OUTPUT="${OUT_DIR}/$(asset_appimage "$VERSION")"

[[ -x "$BIN_IN" ]] || die "binary not found: $BIN_IN (run ./scripts/build-linux.sh or ./scripts/ci-package.sh)"

rm -rf "$APPDIR"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/metainfo"
install -m755 "$BIN_IN" "${APPDIR}/usr/bin/AyuGram"
stage_icons "${APPDIR}/usr/share/icons/hicolor"
render_metainfo "$VERSION" "${APPDIR}/usr/share/metainfo/${FLATPAK_ID}.metainfo.xml"

# Desktop entry inside the image: plain Exec (AppRun resolves the path).
sed -e 's|^TryExec=.*|TryExec=AyuGram|' \
    -e 's|^Exec=env DESKTOPINTEGRATION=1 AyuGram |Exec=AyuGram |' \
    -e '/^DBusActivatable=/d' \
    "${ROOT}/packaging/linux/${FLATPAK_ID}.desktop" > "${APPDIR}/usr/share/applications/${FLATPAK_ID}.desktop"
cp -f "${APPDIR}/usr/share/applications/${FLATPAK_ID}.desktop" "${APPDIR}/${FLATPAK_ID}.desktop"

ICON256="${APPDIR}/usr/share/icons/hicolor/256x256/apps/${FLATPAK_ID}.png"
[[ -f "$ICON256" ]] || die "256px icon missing; appimagetool needs one"
cp -f "$ICON256" "${APPDIR}/${FLATPAK_ID}.png"
ln -sfn "${FLATPAK_ID}.png" "${APPDIR}/.DirIcon"

cat > "${APPDIR}/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "${HERE}/usr/bin/AyuGram" "$@"
EOF
chmod 755 "${APPDIR}/AppRun"

mkdir -p "${ROOT}/build" "$OUT_DIR"
TOOL="${ROOT}/build/appimagetool-x86_64.AppImage"
if [[ ! -x "$TOOL" ]]; then
  log "downloading appimagetool"
  download "$APPIMAGETOOL_URL" "$TOOL"
  chmod +x "$TOOL"
fi

rm -f "$OUTPUT"
# Extract-and-run: works without FUSE (containers, CI runners).
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream "$APPDIR" "$OUTPUT"

[[ -f "$OUTPUT" ]] || die "AppImage was not produced"
chmod +x "$OUTPUT"
log "wrote $OUTPUT"
