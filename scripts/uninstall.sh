#!/usr/bin/env bash
# Remove AyuGram installed by AyuGram For Linux.

set -euo pipefail

TMPDIR_UN="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR_UN"; }
trap cleanup EXIT

if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/common.sh" ]]; then
  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")/common.sh"
else
  COMMON_TMP="${TMPDIR_UN}/common.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/common.sh" -o "$COMMON_TMP"
  else
    wget -qO "$COMMON_TMP" "https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/common.sh"
  fi
  # shellcheck disable=SC1090
  . "$COMMON_TMP"
fi

detect_os

removed=0

if have dpkg && dpkg -s ayugram-desktop >/dev/null 2>&1; then
  log "removing .deb package"
  sudo_run apt-get remove -y ayugram-desktop || sudo_run dpkg -r ayugram-desktop
  removed=1
fi

if have flatpak; then
  if flatpak info --user com.ayugram.desktop >/dev/null 2>&1; then
    log "removing user Flatpak"
    flatpak uninstall --user -y com.ayugram.desktop || true
    removed=1
  fi
  if flatpak info com.ayugram.desktop >/dev/null 2>&1; then
    log "removing system Flatpak"
    sudo_run flatpak uninstall -y com.ayugram.desktop || true
    removed=1
  fi
fi

for path in \
  "${HOME}/Applications/AyuGram-"*.AppImage \
  "${HOME}/.local/bin/AyuGram" \
  "${HOME}/.local/bin/ayugram" \
  "${HOME}/.local/share/applications/com.ayugram.desktop.desktop" \
  "/usr/bin/AyuGram" \
  "/usr/bin/ayugram" \
  "/usr/share/applications/com.ayugram.desktop.desktop"
do
  if [[ -e $path || -L $path ]]; then
    if [[ "$path" == /usr/* ]]; then
      sudo_run rm -f $path
    else
      rm -f $path
    fi
    removed=1
  fi
done

if have update-desktop-database; then
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
fi

if [[ "$removed" -eq 0 ]]; then
  warn "nothing to remove (AyuGram does not look installed)"
else
  log "AyuGram removed. Chat data in ~/.local/share/AyuGramDesktop was left untouched."
  log "delete that folder yourself if you also want to wipe the local profile."
fi
