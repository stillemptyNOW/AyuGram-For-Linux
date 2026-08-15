#!/usr/bin/env bash
# Shared helpers for AyuGram For Linux scripts.

set -euo pipefail

REPO_OWNER="stillemptyNOW"
REPO_NAME="AyuGram-For-Linux"
REPO_SLUG="${REPO_OWNER}/${REPO_NAME}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_SLUG}/main"
API_BASE="https://api.github.com/repos/${REPO_SLUG}"
UPSTREAM_API="https://api.github.com/repos/AyuGram/AyuGramDesktop"
FLATPAK_FALLBACK_API="https://api.github.com/repos/0FL01/AyuGramDesktop-flatpak"
FLATPAK_ID="com.ayugram.desktop"
APP_NAME="AyuGram"
PKG_NAME="ayugram-desktop"
DEFAULT_VERSION="7.0.9"

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  have "$1" || die "missing required command: $1"
}

script_dir() {
  cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

repo_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${here}/.." && pwd
}

read_tracked_version() {
  local root json
  if root="$(repo_root 2>/dev/null)" && [[ -f "${root}/VERSION.json" ]]; then
    json="$(cat "${root}/VERSION.json")"
    printf '%s\n' "$json" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
    return 0
  fi
  printf '%s\n' "$DEFAULT_VERSION"
}

detect_os() {
  local id like version_id
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-unknown}"
    like="${ID_LIKE:-}"
    version_id="${VERSION_ID:-}"
  else
    id="unknown"
    like=""
    version_id=""
  fi

  DETECTED_ID="$id"
  DETECTED_LIKE="$like"
  DETECTED_VERSION_ID="$version_id"

  case "$id" in
    linuxmint) DETECTED_FAMILY="debian"; DETECTED_PRETTY="Linux Mint" ;;
    ubuntu)    DETECTED_FAMILY="debian"; DETECTED_PRETTY="Ubuntu" ;;
    debian)    DETECTED_FAMILY="debian"; DETECTED_PRETTY="Debian" ;;
    pop|zorin|elementary|neon) DETECTED_FAMILY="debian"; DETECTED_PRETTY="$id" ;;
    fedora)    DETECTED_FAMILY="fedora"; DETECTED_PRETTY="Fedora" ;;
    arch|manjaro|endeavouros|garuda) DETECTED_FAMILY="arch"; DETECTED_PRETTY="$id" ;;
    *)
      case " $like " in
        *" debian "*|" ubuntu "*) DETECTED_FAMILY="debian"; DETECTED_PRETTY="$id" ;;
        *" fedora "*|" rhel "*|" centos "*) DETECTED_FAMILY="fedora"; DETECTED_PRETTY="$id" ;;
        *" arch "*) DETECTED_FAMILY="arch"; DETECTED_PRETTY="$id" ;;
        *) DETECTED_FAMILY="other"; DETECTED_PRETTY="$id" ;;
      esac
      ;;
  esac
}

sudo_run() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    die "this action needs root (sudo)"
  fi
}

download() {
  local url="$1" dest="$2"
  if have curl; then
    curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url"
  elif have wget; then
    wget -O "$dest" "$url"
  else
    die "need curl or wget"
  fi
}

fetch_json() {
  local url="$1"
  if have curl; then
    curl -fsSL -H "Accept: application/vnd.github+json" "$url"
  else
    wget -qO- --header="Accept: application/vnd.github+json" "$url"
  fi
}

json_first_browser_url() {
  # Prints the first browser_download_url whose name matches $2 (glob-ish substring).
  local json="$1" needle="$2"
  printf '%s' "$json" | tr ',' '\n' | sed -n "s/.*\"browser_download_url\":\"\([^\"]*${needle}[^\"]*\)\".*/\1/p" | head -n1
}

ensure_flatpak() {
  if have flatpak; then
    return 0
  fi
  detect_os
  log "installing Flatpak"
  case "$DETECTED_FAMILY" in
    debian) sudo_run apt-get update -y; sudo_run apt-get install -y flatpak ;;
    fedora) sudo_run dnf install -y flatpak ;;
    arch)   sudo_run pacman -Sy --noconfirm flatpak ;;
    *) die "install Flatpak yourself, then re-run" ;;
  esac
  have flatpak || die "flatpak is still missing"
}

ensure_flathub() {
  ensure_flatpak
  if ! flatpak remotes --columns=name | grep -qx flathub; then
    log "adding Flathub"
    sudo_run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || \
      flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}
