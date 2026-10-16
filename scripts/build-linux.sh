#!/usr/bin/env bash
# Build AyuGram Desktop from official sources using the Telegram Docker image.
# Follows https://github.com/AyuGram/AyuGramDesktop/blob/dev/docs/building-linux.md
#
# Env:
#   UPSTREAM_TAG        tag to build (default: v<VERSION.json version>)
#   TDESKTOP_API_ID / TDESKTOP_API_HASH   your API pair (default: public tdesktop pair)
#   TDESKTOP_IMAGE      build image (default: ghcr.io/telegramdesktop/tdesktop/centos_env:latest)
#   PREPARE=1           build the image locally with the official prepare script
#                       (hours; only needed when the ghcr image does not match)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${HERE}/common.sh"

ROOT="$(cd "${HERE}/.." && pwd)"
WORK="${BUILD_DIR:-${ROOT}/src}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/AyuGram/AyuGramDesktop.git}"
UPSTREAM_TAG="${UPSTREAM_TAG:-v$(read_tracked_version)}"
API_ID="${TDESKTOP_API_ID:-2040}"
API_HASH="${TDESKTOP_API_HASH:-b18441a1ff607e10a989891a5462e627}"
IMAGE="${TDESKTOP_IMAGE:-ghcr.io/telegramdesktop/tdesktop/centos_env:latest}"

need_cmd git
need_cmd docker

mkdir -p "$WORK"
SRC="${WORK}/tdesktop"

if [[ ! -d "$SRC/.git" ]]; then
  log "cloning ${UPSTREAM_URL} (${UPSTREAM_TAG})"
  git clone --branch "$UPSTREAM_TAG" --depth 1 "$UPSTREAM_URL" "$SRC"
  git -C "$SRC" submodule update --init --recursive --depth 1 \
    || git -C "$SRC" submodule update --init --recursive
else
  current="$(git -C "$SRC" describe --tags --exact-match 2>/dev/null || true)"
  if [[ "$current" != "$UPSTREAM_TAG" ]]; then
    die "${SRC} is at '${current:-unknown}', not ${UPSTREAM_TAG}. Remove it or set BUILD_DIR"
  fi
  log "reusing source tree at $SRC (${UPSTREAM_TAG})"
fi

if [[ "${PREPARE:-0}" == "1" ]]; then
  log "building the image locally (official prepare/linux.sh)"
  ( cd "$SRC" && ./Telegram/build/prepare/linux.sh )
  IMAGE="${TDESKTOP_IMAGE:-tdesktop:centos_env}"
else
  log "pulling ${IMAGE}"
  docker pull "$IMAGE" || die "could not pull ${IMAGE}; re-run with PREPARE=1 to build it locally"
fi

log "building with ${IMAGE}"
log "API id ${API_ID} (override with TDESKTOP_API_ID / TDESKTOP_API_HASH)"

docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "${SRC}:/usr/src/tdesktop" \
  "$IMAGE" \
  /usr/src/tdesktop/Telegram/build/docker/centos_env/build.sh \
  -D TDESKTOP_API_ID="$API_ID" \
  -D TDESKTOP_API_HASH="$API_HASH"

BIN=""
for candidate in \
  "${SRC}/out/Release/AyuGram" \
  "${SRC}/out/Release/Telegram" \
  "${SRC}/out/AyuGram"
do
  if [[ -x "$candidate" ]]; then
    BIN="$candidate"
    break
  fi
done

[[ -n "$BIN" ]] || die "build finished but AyuGram binary was not found in ${SRC}/out"

rm -rf "${ROOT}/out"
install -Dm755 "$BIN" "${ROOT}/out/AyuGram"
if have strip; then
  strip --strip-unneeded "${ROOT}/out/AyuGram" || true
fi

for size in $ICON_SIZES; do
  icon="${SRC}/Telegram/Resources/art/icon${size}.png"
  if [[ -f "$icon" ]]; then
    install -Dm644 "$icon" "${ROOT}/out/icons/hicolor/${size}x${size}/apps/${FLATPAK_ID}.png"
  fi
done

log "binary: ${ROOT}/out/AyuGram"
log "next: ./scripts/package-deb.sh, ./scripts/package-appimage.sh or ./scripts/package-arch.sh"
