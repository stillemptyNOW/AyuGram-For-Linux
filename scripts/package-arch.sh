#!/usr/bin/env bash
# Build the Arch Linux package (ayugram-for-linux-bin) from the portable tarball.
#
# Usage: package-arch.sh [--tarball FILE] [--no-build] [--repo]
#   --tarball FILE  use this AyuGram-<ver>-linux-x64.tar.xz
#                   (default: dist/, else download it from the GitHub release)
#   --no-build      only render PKGBUILD and .SRCINFO into dist/
#   --repo          also write a pacman repository database (ayugram.db) into dist/
#
# Env: VERSION (default VERSION.json), PKGREL (default 1).
# Needs an Arch-based system with base-devel; run as a normal user, not root.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
VERSION="${VERSION:-$(read_tracked_version)}"
PKGREL="${PKGREL:-1}"
DIST="${ROOT}/dist"
STAGE="${ROOT}/build/arch"
REPO_DB_NAME="ayugram"
TARBALL=""
BUILD_PKG=1
MAKE_REPO=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tarball) TARBALL="${2:-}"; shift 2 ;;
    --tarball=*) TARBALL="${1#*=}"; shift ;;
    --no-build) BUILD_PKG=0; shift ;;
    --repo) MAKE_REPO=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

TARBALL_NAME="$(asset_tarball "$VERSION")"
mkdir -p "$DIST"
if [[ -z "$TARBALL" ]]; then
  if [[ -f "${DIST}/${TARBALL_NAME}" ]]; then
    TARBALL="${DIST}/${TARBALL_NAME}"
  else
    TARBALL="${ROOT}/build/${TARBALL_NAME}"
    mkdir -p "${ROOT}/build"
    log "downloading ${TARBALL_NAME} from the v${VERSION} release"
    download "$(release_asset_url "$VERSION" "$TARBALL_NAME")" "$TARBALL"
  fi
fi
[[ -f "$TARBALL" ]] || die "tarball not found: $TARBALL"
[[ "$(basename "$TARBALL")" == "$TARBALL_NAME" ]] || die "expected ${TARBALL_NAME}, got $(basename "$TARBALL") (set VERSION?)"

SHA256="$(sha256sum "$TARBALL" | awk '{print $1}')"
log "${TARBALL_NAME} sha256 ${SHA256}"

render_pkgbuild() {
  local source="$1" dest="$2"
  sed -e "s|@VERSION@|${VERSION}|g" \
      -e "s|@PKGREL@|${PKGREL}|g" \
      -e "s|@SOURCE@|${source}|g" \
      -e "s|@SHA256@|${SHA256}|g" \
      "${ROOT}/packaging/arch/PKGBUILD.in" > "$dest"
}

# Publishable PKGBUILD: fetches the tarball from the GitHub release (also fits AUR).
# shellcheck disable=SC2016  # ${pkgver} is for makepkg, not for this shell
render_pkgbuild '${url}/releases/download/v${pkgver}/AyuGram-${pkgver}-linux-x64.tar.xz' "${DIST}/PKGBUILD"
log "wrote ${DIST}/PKGBUILD"

# Local build: same PKGBUILD, tarball sitting next to it.
rm -rf "$STAGE"
mkdir -p "$STAGE"
render_pkgbuild "$TARBALL_NAME" "${STAGE}/PKGBUILD"
cp -f "$TARBALL" "${STAGE}/${TARBALL_NAME}"

if have makepkg; then
  ( cd "$DIST" && makepkg --printsrcinfo > .SRCINFO )
  log "wrote ${DIST}/.SRCINFO"
fi

if [[ "$BUILD_PKG" -eq 0 ]]; then
  exit 0
fi

need_cmd makepkg
[[ "${EUID}" -ne 0 ]] || die "makepkg refuses to run as root; run this as a normal user"

log "running makepkg"
# --nodeps: this only repackages files, nothing links against the depends;
# pacman -U installs them along with the package.
(
  cd "$STAGE"
  PKGDEST="$DIST" SRCDEST="$STAGE" BUILDDIR="${STAGE}/work" makepkg --force --cleanbuild --nodeps --noconfirm
)

PKG_FILE="$(find "$DIST" -maxdepth 1 -name "${ARCH_PKG_NAME}-${VERSION}-${PKGREL}-x86_64.pkg.tar.*" ! -name '*.sig' | head -n1)"
[[ -n "$PKG_FILE" ]] || die "makepkg finished but no package in ${DIST}"
log "wrote ${PKG_FILE}"

if [[ "$MAKE_REPO" -eq 1 ]]; then
  need_cmd repo-add
  rm -f "${DIST}/${REPO_DB_NAME}".{db,files}{,.tar.gz,.tar.gz.old}
  repo-add "${DIST}/${REPO_DB_NAME}.db.tar.gz" "$PKG_FILE"
  # repo-add makes ayugram.db a symlink; release assets cannot be symlinks.
  for kind in db files; do
    rm -f "${DIST}/${REPO_DB_NAME}.${kind}"
    cp -f "${DIST}/${REPO_DB_NAME}.${kind}.tar.gz" "${DIST}/${REPO_DB_NAME}.${kind}"
  done
  rm -f "${DIST}/${REPO_DB_NAME}".*.old
  log "wrote pacman repo ${DIST}/${REPO_DB_NAME}.db"
fi

log "install with: sudo pacman -U ${PKG_FILE}"
