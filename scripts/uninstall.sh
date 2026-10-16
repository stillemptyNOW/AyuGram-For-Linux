#!/usr/bin/env bash
# Remove AyuGram installed by AyuGram For Linux (any method).

set -euo pipefail

main() {
TMPDIR_UN="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR_UN'" EXIT

local self_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -n "$self_dir" && -f "${self_dir}/common.sh" ]]; then
  # shellcheck disable=SC1091
  . "${self_dir}/common.sh"
else
  local common_tmp="${TMPDIR_UN}/common.sh"
  local common_url="https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/common.sh"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$common_url" -o "$common_tmp"
  else
    wget -qO "$common_tmp" "$common_url"
  fi
  # shellcheck disable=SC1090
  . "$common_tmp"
fi

local removed=0 pkg path

if have dpkg-query && dpkg-query -W -f='${Status}' "$PKG_NAME" 2>/dev/null | grep -q "install ok installed"; then
  log "removing .deb package"
  sudo_run apt-get remove -y "$PKG_NAME" || sudo_run dpkg -r "$PKG_NAME"
  removed=1
fi

if have pacman; then
  for pkg in "$ARCH_PKG_NAME" ayugram-desktop ayugram-desktop-bin ayugram-desktop-git; do
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
      log "removing pacman package ${pkg}"
      sudo_run pacman -R --noconfirm "$pkg"
      removed=1
    fi
  done
fi

if have flatpak; then
  if flatpak info --user "$FLATPAK_ID" >/dev/null 2>&1; then
    log "removing user Flatpak"
    flatpak uninstall --user -y "$FLATPAK_ID" || true
    removed=1
  fi
  if flatpak info --system "$FLATPAK_ID" >/dev/null 2>&1; then
    log "removing system Flatpak"
    sudo_run flatpak uninstall --system -y "$FLATPAK_ID" || true
    removed=1
  fi
fi

shopt -s nullglob
local user_paths=(
  "${HOME}/Applications/"AyuGram-*.AppImage
  "${HOME}/.local/opt/AyuGram"
  "${HOME}/.local/bin/AyuGram"
  "${HOME}/.local/bin/ayugram"
  "${HOME}/.local/share/applications/${FLATPAK_ID}.desktop"
  "${HOME}/.local/share/icons/hicolor/"*/apps/"${FLATPAK_ID}"*
)
shopt -u nullglob
for path in "${user_paths[@]}"; do
  if [[ -e "$path" || -L "$path" ]]; then
    rm -rf -- "$path"
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
}

main "$@"
