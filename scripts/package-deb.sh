#!/usr/bin/env bash
# Build a Debian package for Linux Mint / Ubuntu / Debian.
#
# Usage: package-deb.sh [path/to/AyuGram]   (default: out/AyuGram)
# Produce out/AyuGram with ./scripts/ci-package.sh or ./scripts/build-linux.sh.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
ARCH="${ARCH:-amd64}"
BIN="${1:-${ROOT}/out/AyuGram}"
OUT_DIR="${ROOT}/dist"
STAGE="${ROOT}/build/deb"

[[ -x "$BIN" ]] || die "AyuGram binary not found at $BIN. Run ./scripts/ci-package.sh or ./scripts/build-linux.sh first"
need_cmd dpkg-deb

log "packaging $BIN as $(asset_deb "$VERSION")"

rm -rf "$STAGE"
mkdir -p "${STAGE}/DEBIAN" "${STAGE}/usr/share/doc/${PKG_NAME}"
stage_system_tree "$BIN" "${STAGE}/usr" "$VERSION"

cp -f "${ROOT}/NOTICE" "${STAGE}/usr/share/doc/${PKG_NAME}/NOTICE"
cat > "${STAGE}/usr/share/doc/${PKG_NAME}/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: AyuGram Desktop
Source: https://github.com/AyuGram/AyuGramDesktop

Files: *
License: GPL-3.0-or-later WITH OpenSSL-exception
 AyuGram Desktop is a fork of Telegram Desktop. Packaging scripts:
 ${REPO_URL}
 .
 On Debian systems the full GPL-3 text is in /usr/share/common-licenses/GPL-3.
EOF

SIZE_KB="$(du -sk "${STAGE}/usr" | awk '{print $1}')"

# The binary is the portable build: Qt, ffmpeg, OpenSSL and friends are
# static. Only glibc >= 2.28, GLib and fontconfig/freetype are linked;
# audio, GTK and WebKit are loaded at runtime when present.
cat > "${STAGE}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: ${REPO_OWNER} <${REPO_OWNER}@users.noreply.github.com>
Installed-Size: ${SIZE_KB}
Depends: libc6 (>= 2.28), libglib2.0-0 | libglib2.0-0t64, libfontconfig1, libfreetype6
Recommends: libpulse0 | pipewire-pulse, libasound2 | libasound2t64, xdg-utils, xdg-desktop-portal, fonts-open-sans
Suggests: libwebkit2gtk-4.1-0
Homepage: ${REPO_URL}
Description: AyuGram Desktop - Telegram client with Ghost mode
 Unofficial Telegram client (AyuGram) packaged for Linux Mint,
 Ubuntu, Debian and derivatives. Ghost mode, anti-recall and the
 rest of AyuGram come from upstream AyuGramDesktop.
EOF

cat > "${STAGE}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF
cp -f "${STAGE}/DEBIAN/postinst" "${STAGE}/DEBIAN/postrm"
chmod 755 "${STAGE}/DEBIAN/postinst" "${STAGE}/DEBIAN/postrm"

mkdir -p "$OUT_DIR"
DEB="${OUT_DIR}/$(asset_deb "$VERSION")"
dpkg-deb --root-owner-group -Zxz --build "$STAGE" "$DEB"
log "wrote $DEB"
