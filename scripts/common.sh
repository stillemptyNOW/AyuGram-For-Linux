#!/usr/bin/env bash
# Shared helpers for AyuGram For Linux scripts.
# Sourced by the other scripts, so most variables here are used elsewhere.
# shellcheck disable=SC2034

set -euo pipefail

REPO_OWNER="stillemptyNOW"
REPO_NAME="AyuGram-For-Linux"
REPO_SLUG="${REPO_OWNER}/${REPO_NAME}"
REPO_URL="https://github.com/${REPO_SLUG}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}/main"
API_BASE="https://api.github.com/repos/${REPO_SLUG}"
FLATPAK_FALLBACK_API="https://api.github.com/repos/0FL01/AyuGramDesktop-flatpak"
FLATPAK_ID="com.ayugram.desktop"
PKG_NAME="ayugram-desktop"
ARCH_PKG_NAME="ayugram-for-linux-bin"
DEFAULT_VERSION="7.2.9"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  have "$1" || die "missing required command: $1"
}

repo_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${here}/.." && pwd
}

# Version from VERSION.json in a git clone; empty when running via curl | bash.
read_local_version() {
  local root
  if root="$(repo_root 2>/dev/null)" && [[ -f "${root}/VERSION.json" ]]; then
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${root}/VERSION.json" | head -n1
  fi
}

read_tracked_version() {
  local v
  v="$(read_local_version)"
  printf '%s\n' "${v:-$DEFAULT_VERSION}"
}

os_release_field() {
  # Read one field without sourcing the file: os-release defines VERSION,
  # NAME and others that would clobber script variables.
  local file="/etc/os-release"
  [[ -f "$file" ]] || file="/usr/lib/os-release"
  [[ -f "$file" ]] || return 0
  sed -n "s/^$1=//p" "$file" | head -n1 | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

detect_os() {
  local id like
  id="$(os_release_field ID)"
  id="${id:-unknown}"
  like="$(os_release_field ID_LIKE)"

  DETECTED_ID="$id"
  DETECTED_LIKE="$like"
  DETECTED_VERSION_ID="$(os_release_field VERSION_ID)"
  DETECTED_PRETTY="$(os_release_field PRETTY_NAME)"
  DETECTED_PRETTY="${DETECTED_PRETTY:-$id}"

  case "$id" in
    linuxmint|ubuntu|debian|pop|zorin|elementary|neon|kali|raspbian|deepin|mx)
      DETECTED_FAMILY="debian" ;;
    fedora|nobara|ultramarine)
      DETECTED_FAMILY="fedora" ;;
    arch|archarm|manjaro|manjaro-arm|endeavouros|garuda|cachyos|artix|arcolinux|rebornos|biglinux|parabola)
      DETECTED_FAMILY="arch" ;;
    *)
      case " $like " in
        *" debian "*|*" ubuntu "*) DETECTED_FAMILY="debian" ;;
        *" fedora "*|*" rhel "*|*" centos "*) DETECTED_FAMILY="fedora" ;;
        *" arch "*) DETECTED_FAMILY="arch" ;;
        *) DETECTED_FAMILY="other" ;;
      esac
      ;;
  esac
  # pacman is the real signal for Arch-likes that don't set ID_LIKE.
  if [[ "$DETECTED_FAMILY" == "other" ]] && have pacman && have makepkg; then
    DETECTED_FAMILY="arch"
  fi
}

sudo_run() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  elif have doas; then
    doas "$@"
  else
    die "this action needs root (sudo or doas)"
  fi
}

download() {
  local url="$1" dest="$2"
  if have curl; then
    curl -fL --retry 3 --retry-delay 2 --proto '=https' -o "$dest" "$url"
  elif have wget; then
    wget -q --show-progress -O "$dest" "$url" || wget -O "$dest" "$url"
  else
    die "need curl or wget"
  fi
}

fetch_json() {
  local url="$1"
  if have curl; then
    curl -fsSL -H "Accept: application/vnd.github+json" -H "User-Agent: ${REPO_NAME}" "$url"
  elif have wget; then
    wget -qO- --header="Accept: application/vnd.github+json" "$url"
  else
    die "need curl or wget"
  fi
}

# Prints every browser_download_url in a GitHub release JSON (pretty or compact).
json_browser_urls() {
  printf '%s' "$1" \
    | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | sed -E 's/.*"(https?:[^"]+)"$/\1/'
}

# Prints the first browser_download_url whose file name ends with $2.
json_first_browser_url() {
  local json="$1" suffix="$2"
  json_browser_urls "$json" | awk -v s="$suffix" '{ n = split($0, p, "/"); f = p[n]; if (length(f) >= length(s) && substr(f, length(f) - length(s) + 1) == s) { print; exit } }'
}

json_tag_name() {
  printf '%s' "$1" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/'
}

# Tag of the latest release in this repo. Uses the github.com redirect first,
# which is not rate limited, then the API.
latest_release_tag() {
  local url tag=""
  if have curl; then
    url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "${REPO_URL}/releases/latest" 2>/dev/null || true)"
    case "$url" in
      */releases/tag/*) tag="${url##*/releases/tag/}" ;;
    esac
  fi
  if [[ -z "$tag" ]]; then
    tag="$(json_tag_name "$(fetch_json "${API_BASE}/releases/latest" 2>/dev/null || true)")"
  fi
  printf '%s\n' "$tag"
}

# Version a user install should fetch: VERSION.json in a clone, else latest release.
resolve_install_version() {
  local v tag
  v="$(read_local_version)"
  if [[ -n "$v" ]]; then
    printf '%s\n' "$v"
    return 0
  fi
  tag="$(latest_release_tag)"
  if [[ -n "$tag" ]]; then
    printf '%s\n' "${tag#v}"
    return 0
  fi
  warn "could not reach GitHub to find the latest release, assuming ${DEFAULT_VERSION}"
  printf '%s\n' "$DEFAULT_VERSION"
}

release_asset_url() {
  local version="$1" name="$2"
  printf '%s/releases/download/v%s/%s\n' "$REPO_URL" "$version" "$name"
}

# Asset names produced by scripts/ci-package.sh.
asset_deb()      { printf '%s_%s_amd64.deb\n' "$PKG_NAME" "$1"; }
asset_appimage() { printf 'AyuGram-%s-x86_64.AppImage\n' "$1"; }
asset_tarball()  { printf 'AyuGram-%s-linux-x64.tar.xz\n' "$1"; }
asset_flatpak()  { printf '%s-%s.flatpak\n' "$PKG_NAME" "$1"; }

ensure_flatpak() {
  if have flatpak; then
    return 0
  fi
  detect_os
  log "installing Flatpak"
  case "$DETECTED_FAMILY" in
    debian) sudo_run apt-get update; sudo_run apt-get install -y flatpak ;;
    fedora) sudo_run dnf install -y flatpak ;;
    arch)   sudo_run pacman -S --needed --noconfirm flatpak ;;
    *) die "install Flatpak yourself, then re-run" ;;
  esac
  have flatpak || die "flatpak is still missing"
}

ensure_flathub() {
  ensure_flatpak
  if ! flatpak remotes --user --columns=name 2>/dev/null | grep -qx flathub; then
    log "adding Flathub (user)"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

ICON_SIZES="16 32 48 64 128 256 512"

# Copy hicolor icons into $1. Uses out/icons (extracted from the Flatpak or a
# source build) when present, else downloads them from the upstream tag.
stage_icons() {
  local dest="$1" root src size tag
  root="$(repo_root)"
  src="${root}/out/icons/hicolor"
  mkdir -p "$dest"
  if [[ -d "$src" ]] && [[ -n "$(ls -A "$src" 2>/dev/null)" ]]; then
    cp -a "${src}/." "${dest}/"
    return 0
  fi
  tag="${UPSTREAM_TAG:-v$(read_tracked_version)}"
  for size in $ICON_SIZES; do
    mkdir -p "${dest}/${size}x${size}/apps"
    download "https://raw.githubusercontent.com/AyuGram/AyuGramDesktop/${tag}/Telegram/Resources/art/icon${size}.png" \
      "${dest}/${size}x${size}/apps/${FLATPAK_ID}.png" >/dev/null 2>&1 \
      || warn "could not fetch ${size}px icon"
  done
}

# metainfo with a <release> entry for $1.
render_metainfo() {
  local version="$1" dest="$2" root
  root="$(repo_root)"
  sed -e "s/@VERSION@/${version}/g" -e "s/@DATE@/$(date -u +%Y-%m-%d)/g" \
    "${root}/packaging/linux/${FLATPAK_ID}.metainfo.xml" > "$dest"
}

# Desktop entry for installs where AyuGram is not on PATH and no D-Bus
# service is installed (AppImage, portable tarball): absolute Exec, no
# DBusActivatable (it makes GNOME/KDE launchers do nothing without a service).
render_portable_desktop() {
  local exe="$1" dest="$2" root
  root="$(repo_root)"
  sed -e "s|^TryExec=.*|TryExec=${exe}|" \
      -e "s|^Exec=env DESKTOPINTEGRATION=1 AyuGram |Exec=env DESKTOPINTEGRATION=1 \"${exe}\" |" \
      -e "s|^Exec=AyuGram |Exec=\"${exe}\" |" \
      -e '/^DBusActivatable=/d' \
      "${root}/packaging/linux/${FLATPAK_ID}.desktop" > "$dest"
}

# Lay out bin/ and share/ for a system package under prefix $2 (e.g. $pkg/usr).
stage_system_tree() {
  local bin="$1" prefix="$2" version="$3" root
  root="$(repo_root)"
  install -Dm755 "$bin" "${prefix}/bin/AyuGram"
  ln -sfn AyuGram "${prefix}/bin/ayugram"
  install -Dm644 "${root}/packaging/linux/${FLATPAK_ID}.desktop" \
    "${prefix}/share/applications/${FLATPAK_ID}.desktop"
  install -Dm644 "${root}/packaging/linux/${FLATPAK_ID}.service" \
    "${prefix}/share/dbus-1/services/${FLATPAK_ID}.service"
  mkdir -p "${prefix}/share/metainfo"
  render_metainfo "$version" "${prefix}/share/metainfo/${FLATPAK_ID}.metainfo.xml"
  stage_icons "${prefix}/share/icons/hicolor"
}
