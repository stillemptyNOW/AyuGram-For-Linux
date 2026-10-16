#!/usr/bin/env bash
# Install AyuGram on Linux Mint, Ubuntu, Debian, Arch, Fedora and others.
# Usage:
#   ./scripts/install.sh [--method auto|deb|arch|aur|flatpak|appimage|portable|source] [--yes]
#   curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash

set -euo pipefail

# Everything lives in main() so a truncated `curl | bash` download runs nothing.
main() {
METHOD="auto"
ASSUME_YES=0
PREFIX="${PREFIX:-$HOME/.local}"
APPIMAGE_DIR="${APPIMAGE_DIR:-$HOME/Applications}"
PORTABLE_DIR="${PORTABLE_DIR:-$HOME/.local/opt/AyuGram}"

usage() {
  cat <<'EOF'
AyuGram For Linux installer

Usage: install.sh [options]

  --method auto       pick the best method for this distro (default)
  --method deb        .deb package (Linux Mint / Ubuntu / Debian)
  --method arch       pacman package from this repo (Arch / Manjaro / EndeavourOS / CachyOS)
  --method aur        build ayugram-desktop from AUR with yay or paru (slow, native libs)
  --method flatpak    Flatpak bundle (any distro)
  --method appimage   AppImage in ~/Applications (any distro)
  --method portable   unpack the portable build into ~/.local/opt (any distro, no root)
  --method source     build official sources with Docker (hours, ~30 GB)
  --yes               do not ask questions
  -h, --help          show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) METHOD="${2:-}"; shift 2 ;;
    --method=*) METHOD="${1#*=}"; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

TMPDIR_INSTALL="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR_INSTALL'" EXIT

# Load helpers from the clone this script lives in; otherwise fetch them.
local self_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n "$self_dir" && -f "${self_dir}/common.sh" ]]; then
  # shellcheck disable=SC1091
  . "${self_dir}/common.sh"
else
  local common_tmp="${TMPDIR_INSTALL}/common.sh"
  local common_url="https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/common.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$common_url" -o "$common_tmp"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$common_tmp" "$common_url"
  else
    echo "error: need curl or wget" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  . "$common_tmp"
fi

[[ "$(uname -m)" == "x86_64" ]] || die "only x86_64 builds exist for now (this machine is $(uname -m))"

detect_os
VERSION="$(resolve_install_version)"

log "AyuGram For Linux ${VERSION}"
log "detected: ${DETECTED_PRETTY} (${DETECTED_ID}, family=${DETECTED_FAMILY})"

case "$METHOD" in
  auto)     auto_method ;;
  deb)      install_deb || die "deb install failed" ;;
  arch|pacman) install_arch_pkg || die "Arch package install failed" ;;
  aur)      install_aur || die "AUR install failed" ;;
  flatpak)  install_flatpak_bundle ;;
  appimage) install_appimage ;;
  portable|tarball) install_portable ;;
  source)   install_source ;;
  *) die "unknown method: $METHOD" ;;
esac

log "done. look for AyuGram Desktop in the application menu."
}

confirm() {
  local prompt="$1" answer=""
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  # Under `curl | bash` stdin is the script itself; ask the terminal instead.
  if [[ -r /dev/tty ]] && { : < /dev/tty; } 2>/dev/null; then
    read -r -p "$prompt [Y/n] " answer < /dev/tty || true
  else
    return 0
  fi
  case "$answer" in
    ""|Y|y|yes|YES|Д|д|да) return 0 ;;
    *) return 1 ;;
  esac
}

# Download release asset $1 for $VERSION into the temp dir; prints the path.
fetch_asset() {
  local name="$1" dest="${TMPDIR_INSTALL}/$1"
  log "downloading ${name}" >&2
  if download "$(release_asset_url "$VERSION" "$name")" "$dest" >&2; then
    printf '%s\n' "$dest"
    return 0
  fi
  return 1
}

install_deb() {
  [[ "$DETECTED_FAMILY" == "debian" ]] || die ".deb install is for Linux Mint / Ubuntu / Debian"
  need_cmd apt-get

  local deb
  if ! deb="$(fetch_asset "$(asset_deb "$VERSION")")"; then
    warn "no .deb in the v${VERSION} release"
    return 1
  fi
  # apt runs downloads as _apt; give it a readable copy to avoid the sandbox warning.
  chmod 755 "$TMPDIR_INSTALL"
  chmod 644 "$deb"
  log "installing .deb (sudo)"
  sudo_run apt-get install -y "$deb"
}

install_arch_pkg() {
  [[ "$DETECTED_FAMILY" == "arch" ]] || die "pacman package is for Arch-based distros"
  need_cmd pacman

  local json url pkg
  json="$(fetch_json "${API_BASE}/releases/tags/v${VERSION}" 2>/dev/null || true)"
  url="$(json_first_browser_url "$json" "-x86_64.pkg.tar.zst")"
  if [[ -n "$url" ]]; then
    pkg="${TMPDIR_INSTALL}/${url##*/}"
    log "downloading ${url##*/}"
    download "$url" "$pkg"
  else
    warn "no prebuilt pacman package in v${VERSION} (or GitHub API is rate limited); building it with makepkg"
    pkg="$(build_arch_pkg_locally)" || return 1
  fi
  log "installing ${pkg##*/} (sudo pacman -U)"
  sudo_run pacman -U --needed --noconfirm "$pkg"
  log "tip: add the ayugram pacman repo to get updates with pacman -Syu (see docs/arch.md)"
}

build_arch_pkg_locally() {
  need_cmd makepkg
  [[ "${EUID}" -ne 0 ]] || die "makepkg cannot run as root; re-run the installer as your normal user"
  local root
  root="$(repo_root 2>/dev/null || true)"
  if [[ -z "$root" || ! -x "${root}/scripts/package-arch.sh" ]]; then
    need_cmd git
    root="${TMPDIR_INSTALL}/AyuGram-For-Linux"
    git clone --depth 1 "${REPO_URL}.git" "$root" >&2
  fi
  VERSION="$VERSION" "${root}/scripts/package-arch.sh" >&2
  find "${root}/dist" -maxdepth 1 -name "${ARCH_PKG_NAME}-${VERSION}-*-x86_64.pkg.tar.*" ! -name '*.sig' | head -n1
}

install_aur() {
  local helper=""
  if have paru; then helper="paru"
  elif have yay; then helper="yay"
  fi
  [[ -n "$helper" ]] || die "no AUR helper (yay or paru) found"
  confirm "build ayugram-desktop from AUR with ${helper}? this compiles for a long time" || return 1
  "$helper" -S --needed ayugram-desktop
}

install_flatpak_bundle() {
  ensure_flathub

  local bundle
  if ! bundle="$(fetch_asset "$(asset_flatpak "$VERSION")")"; then
    log "using the latest community Flatpak from 0FL01/AyuGramDesktop-flatpak"
    local json url
    json="$(fetch_json "${FLATPAK_FALLBACK_API}/releases/latest")"
    url="$(json_first_browser_url "$json" ".flatpak")"
    [[ -n "$url" ]] || die "could not find a Flatpak bundle"
    bundle="${TMPDIR_INSTALL}/ayugram-desktop.flatpak"
    download "$url" "$bundle"
  fi
  log "installing Flatpak (id ${FLATPAK_ID})"
  flatpak install --user -y --noninteractive --reinstall "$bundle"
  log "run with: flatpak run ${FLATPAK_ID}"
}

install_user_icons() {
  local from="$1" to="${HOME}/.local/share/icons/hicolor"
  [[ -d "$from" ]] || return 0
  mkdir -p "$to"
  cp -a "${from}/." "$to/"
  if have gtk-update-icon-cache; then
    gtk-update-icon-cache -q -t "$to" >/dev/null 2>&1 || true
  fi
}

install_desktop_entry() {
  local exe="$1" apps="${HOME}/.local/share/applications"
  mkdir -p "$apps"
  render_desktop_for "$exe" > "${apps}/${FLATPAK_ID}.desktop"
  if have update-desktop-database; then
    update-desktop-database "$apps" >/dev/null 2>&1 || true
  fi
  if have xdg-mime; then
    xdg-mime default "${FLATPAK_ID}.desktop" x-scheme-handler/tg >/dev/null 2>&1 || true
  fi
}

# Desktop entry pointing at an absolute binary path (no D-Bus activation).
render_desktop_for() {
  local exe="$1"
  cat <<EOF
[Desktop Entry]
Name=AyuGram Desktop
Comment=Telegram client with Ghost mode and anti-recall
Comment[ru]=Клиент Telegram с режимом призрака и антиудалением
TryExec=${exe}
Exec=env DESKTOPINTEGRATION=1 "${exe}" -- %U
Icon=${FLATPAK_ID}
Terminal=false
StartupWMClass=AyuGram
Type=Application
Categories=Chat;Network;InstantMessaging;Qt;
MimeType=x-scheme-handler/tg;x-scheme-handler/tonsite;
Keywords=tg;chat;im;messaging;messenger;sms;telegram;tdesktop;ayugram;
Actions=quit;
SingleMainWindow=true
X-GNOME-UsesNotifications=true

[Desktop Action quit]
Exec="${exe}" -quit
Name=Quit AyuGram
Name[ru]=Выйти из AyuGram
Icon=application-exit
EOF
}

link_user_bin() {
  local target="$1"
  mkdir -p "${PREFIX}/bin"
  ln -sfn "$target" "${PREFIX}/bin/AyuGram"
  ln -sfn "$target" "${PREFIX}/bin/ayugram"
  case ":${PATH}:" in
    *":${PREFIX}/bin:"*) ;;
    *) warn "${PREFIX}/bin is not on your PATH; the menu entry works anyway" ;;
  esac
}

install_portable() {
  need_cmd tar
  local tarball top
  tarball="$(fetch_asset "$(asset_tarball "$VERSION")")" || die "no portable tarball in the v${VERSION} release"
  top="${TMPDIR_INSTALL}/unpack"
  mkdir -p "$top"
  tar -C "$top" -xJf "$tarball"
  local src="${top}/AyuGram-${VERSION}-linux-x64"
  [[ -x "${src}/bin/AyuGram" ]] || die "unexpected tarball layout"

  rm -rf "$PORTABLE_DIR"
  mkdir -p "$PORTABLE_DIR"
  cp -a "${src}/." "$PORTABLE_DIR/"
  link_user_bin "${PORTABLE_DIR}/bin/AyuGram"
  install_user_icons "${PORTABLE_DIR}/share/icons/hicolor"
  install_desktop_entry "${PORTABLE_DIR}/bin/AyuGram"
  log "AyuGram installed to ${PORTABLE_DIR}"
}

install_appimage() {
  local image dest
  image="$(fetch_asset "$(asset_appimage "$VERSION")")" || die "no AppImage in the v${VERSION} release; try --method portable"
  mkdir -p "$APPIMAGE_DIR"
  rm -f "${APPIMAGE_DIR}"/AyuGram-*-x86_64.AppImage
  dest="${APPIMAGE_DIR}/$(asset_appimage "$VERSION")"
  mv -f "$image" "$dest"
  chmod +x "$dest"
  link_user_bin "$dest"

  # Icons come out of the image itself; no FUSE needed for --appimage-extract.
  ( cd "$TMPDIR_INSTALL" && "$dest" --appimage-extract 'usr/share/icons/*' >/dev/null 2>&1 ) || true
  install_user_icons "${TMPDIR_INSTALL}/squashfs-root/usr/share/icons/hicolor"
  install_desktop_entry "$dest"
  if ! have fusermount && ! have fusermount3; then
    warn "FUSE is missing; AppImages need libfuse2 (Mint/Ubuntu: sudo apt install libfuse2t64 or libfuse2)"
  fi
  log "AppImage installed to $dest"
}

install_source() {
  local root
  root="$(repo_root 2>/dev/null || true)"
  if [[ -z "$root" || ! -x "${root}/scripts/build-linux.sh" ]]; then
    need_cmd git
    root="${TMPDIR_INSTALL}/AyuGram-For-Linux"
    git clone --depth 1 "${REPO_URL}.git" "$root"
  fi
  "${root}/scripts/build-linux.sh"
  case "$DETECTED_FAMILY" in
    debian)
      VERSION="$VERSION" "${root}/scripts/package-deb.sh"
      sudo_run apt-get install -y "${root}/dist/$(asset_deb "$VERSION")"
      ;;
    *)
      log "built ${root}/out/AyuGram; run it directly or package it with scripts/package-*.sh"
      ;;
  esac
}

install_fedora() {
  # The portable build runs fine on Fedora; Flatpak is the sandboxed alternative.
  if confirm "install the portable build into ${PORTABLE_DIR} (no root)? answer n for Flatpak"; then
    install_portable
  else
    install_flatpak_bundle
  fi
}

auto_method() {
  case "$DETECTED_FAMILY" in
    debian)
      if install_deb; then
        return 0
      fi
      log "no .deb release, using Flatpak"
      install_flatpak_bundle
      ;;
    arch)
      if install_arch_pkg; then
        return 0
      fi
      log "pacman package failed, using the portable build"
      install_portable
      ;;
    fedora) install_fedora ;;
    *)
      log "unknown distro (${DETECTED_PRETTY}), using the portable build"
      install_portable
      ;;
  esac
}

main "$@"
