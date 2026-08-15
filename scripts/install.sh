#!/usr/bin/env bash
# Install AyuGram on Linux Mint, Ubuntu, Debian, Fedora, Arch and others.
# Usage:
#   ./scripts/install.sh [--method auto|deb|flatpak|appimage|source] [--yes]
#   curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash

set -euo pipefail

METHOD="auto"
ASSUME_YES=0
PREFIX="${PREFIX:-$HOME/.local}"
APPIMAGE_DIR="${APPIMAGE_DIR:-$HOME/Applications}"

usage() {
  cat <<'EOF'
AyuGram For Linux installer

Usage: install.sh [options]

  --method auto       pick the best method for this distro (default)
  --method deb        install .deb (Linux Mint / Ubuntu / Debian)
  --method flatpak    install Flatpak bundle
  --method appimage   install portable AppImage
  --method source     build official sources with Docker
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
cleanup() { rm -rf "$TMPDIR_INSTALL"; }
trap cleanup EXIT

# Load helpers when running from a git clone; otherwise fetch them.
if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/common.sh" ]]; then
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/common.sh"
else
  COMMON_TMP="${TMPDIR_INSTALL}/common.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/common.sh" -o "$COMMON_TMP"
  else
    wget -qO "$COMMON_TMP" "https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/common.sh"
  fi
  # shellcheck disable=SC1090
  . "$COMMON_TMP"
fi

detect_os
VERSION="$(read_tracked_version)"

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    return 0
  fi
  read -r -p "$prompt [Y/n] " answer || true
  case "$answer" in
    ""|Y|y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

latest_release_json() {
  fetch_json "${API_BASE}/releases/latest" || true
}

install_deb() {
  [[ "$DETECTED_FAMILY" == "debian" ]] || die ".deb install is for Linux Mint / Ubuntu / Debian"
  need_cmd dpkg

  local json url deb
  json="$(latest_release_json)"
  url="$(json_first_browser_url "$json" ".deb")"
  if [[ -z "$url" ]]; then
    warn "no .deb in ${REPO_SLUG} releases yet"
    return 1
  fi

  deb="${TMPDIR_INSTALL}/${PKG_NAME}.deb"
  log "downloading $url"
  download "$url" "$deb"
  log "installing .deb"
  sudo_run apt-get update -y || true
  if sudo_run apt-get install -y "$deb"; then
    return 0
  fi
  sudo_run dpkg -i "$deb" || sudo_run apt-get install -f -y
}

install_flatpak_bundle() {
  ensure_flathub

  local json url bundle
  json="$(latest_release_json)"
  url="$(json_first_browser_url "$json" ".flatpak")"

  if [[ -z "$url" ]]; then
    log "using community Flatpak from 0FL01/AyuGramDesktop-flatpak"
    json="$(fetch_json "${FLATPAK_FALLBACK_API}/releases/latest")"
    url="$(json_first_browser_url "$json" ".flatpak")"
  fi
  [[ -n "$url" ]] || die "could not find a Flatpak bundle"

  bundle="${TMPDIR_INSTALL}/ayugram-desktop.flatpak"
  log "downloading $url"
  download "$url" "$bundle"
  log "installing Flatpak (id ${FLATPAK_ID})"
  if ! flatpak install --user -y --noninteractive "$bundle"; then
    sudo_run flatpak install -y --noninteractive "$bundle"
  fi
  log "run with: flatpak run ${FLATPAK_ID}"
}

install_desktop_entry() {
  local exec_line="$1" icon_path="${2:-ayugram}"
  local apps="${HOME}/.local/share/applications"
  mkdir -p "$apps"
  cat > "${apps}/com.ayugram.desktop.desktop" <<EOF
[Desktop Entry]
Name=AyuGram Desktop
Comment=AyuGram Telegram client for Linux
TryExec=${exec_line%% *}
Exec=env DESKTOPINTEGRATION=1 ${exec_line} -- %U
Icon=${icon_path}
Terminal=false
StartupWMClass=AyuGram
Type=Application
Categories=Chat;Network;InstantMessaging;Qt;
MimeType=x-scheme-handler/tg;x-scheme-handler/tonsite;
Keywords=tg;chat;im;messaging;messenger;sms;telegram;tdesktop;ayugram;
SingleMainWindow=true
X-GNOME-UsesNotifications=true
EOF
  if have update-desktop-database; then
    update-desktop-database "$apps" >/dev/null 2>&1 || true
  fi
}

install_appimage() {
  local json url image dest
  json="$(latest_release_json)"
  url="$(json_first_browser_url "$json" ".AppImage")"
  [[ -n "$url" ]] || die "no AppImage in ${REPO_SLUG} releases yet; try --method flatpak"

  mkdir -p "$APPIMAGE_DIR"
  dest="${APPIMAGE_DIR}/AyuGram-${VERSION}-x86_64.AppImage"
  log "downloading $url"
  download "$url" "$dest"
  chmod +x "$dest"
  mkdir -p "${PREFIX}/bin"
  ln -sfn "$dest" "${PREFIX}/bin/AyuGram"
  ln -sfn "$dest" "${PREFIX}/bin/ayugram"
  install_desktop_entry "$dest"
  log "AppImage installed to $dest"
  log "make sure ${PREFIX}/bin is on your PATH"
}

install_source() {
  local root
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/build-linux.sh" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    "${root}/scripts/build-linux.sh"
    "${root}/scripts/package-deb.sh" || true
    if [[ "$DETECTED_FAMILY" == "debian" && -f "${root}/dist/${PKG_NAME}_${VERSION}_amd64.deb" ]]; then
      sudo_run apt-get install -y "${root}/dist/${PKG_NAME}_${VERSION}_amd64.deb" || \
        sudo_run dpkg -i "${root}/dist/${PKG_NAME}_${VERSION}_amd64.deb"
      return 0
    fi
    die "build finished; install the files from ${root}/dist yourself"
  fi

  need_cmd git
  local work="${TMPDIR_INSTALL}/AyuGram-For-Linux"
  git clone --depth 1 "https://github.com/${REPO_SLUG}.git" "$work"
  "${work}/scripts/build-linux.sh"
  "${work}/scripts/package-deb.sh" || true
}

install_fedora() {
  if have dnf && confirm "try RPM Fusion package ayugram-desktop?"; then
    if sudo_run dnf install -y ayugram-desktop; then
      return 0
    fi
    warn "dnf package not available, falling back to Flatpak"
  fi
  install_flatpak_bundle
}

install_arch() {
  local helper=""
  if have yay; then helper="yay"
  elif have paru; then helper="paru"
  fi
  if [[ -n "$helper" ]] && confirm "install ayugram-desktop from AUR via $helper?"; then
    "$helper" -S --needed --noconfirm ayugram-desktop-bin || "$helper" -S --needed --noconfirm ayugram-desktop
    return 0
  fi
  warn "no AUR helper found, falling back to Flatpak"
  install_flatpak_bundle
}

auto_method() {
  case "$DETECTED_FAMILY" in
    debian)
      if install_deb; then
        return 0
      fi
      log "no .deb release yet, using Flatpak"
      install_flatpak_bundle
      ;;
    fedora) install_fedora ;;
    arch)   install_arch ;;
    *)
      log "unknown distro (${DETECTED_PRETTY}), using Flatpak"
      install_flatpak_bundle
      ;;
  esac
}

log "AyuGram For Linux ${VERSION}"
log "detected: ${DETECTED_PRETTY} (${DETECTED_ID}, family=${DETECTED_FAMILY})"

case "$METHOD" in
  auto)     auto_method ;;
  deb)      install_deb || die "deb install failed" ;;
  flatpak)  install_flatpak_bundle ;;
  appimage) install_appimage ;;
  source)   install_source ;;
  *) die "unknown method: $METHOD" ;;
esac

log "done. look for AyuGram Desktop in the application menu."
