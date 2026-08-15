#!/usr/bin/env bash
# Build AyuGram Desktop from official sources using the Telegram Docker image.
# Follows https://github.com/AyuGram/AyuGramDesktop/blob/dev/docs/building-linux.md

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
  git clone --recursive --branch "$UPSTREAM_TAG" --depth 1 "$UPSTREAM_URL" "$SRC" \
    || git clone --recursive "$UPSTREAM_URL" "$SRC"
  if [[ -d "$SRC/.git" ]]; then
    git -C "$SRC" fetch --tags --depth 1 origin "$UPSTREAM_TAG" || true
    git -C "$SRC" checkout "$UPSTREAM_TAG" || true
    git -C "$SRC" submodule update --init --recursive --depth 1 || \
      git -C "$SRC" submodule update --init --recursive
  fi
else
  log "reusing existing source tree at $SRC"
fi

if [[ -x "${SRC}/Telegram/build/prepare/linux.sh" ]]; then
  log "preparing libraries (official linux.sh)"
  if have poetry || have python3; then
    (
      cd "$SRC"
      ./Telegram/build/prepare/linux.sh || warn "prepare script returned non-zero; continuing if Docker image already has deps"
    )
  else
    warn "poetry/python3 not found; skipping prepare and relying on ${IMAGE}"
  fi
fi

log "building with ${IMAGE}"
log "API id ${API_ID} (override with TDESKTOP_API_ID / TDESKTOP_API_HASH)"

docker pull "$IMAGE"

docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "${SRC}:/usr/src/tdesktop" \
  -e TDESKTOP_API_ID="$API_ID" \
  -e TDESKTOP_API_HASH="$API_HASH" \
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

mkdir -p "${ROOT}/out"
cp -f "$BIN" "${ROOT}/out/AyuGram"
chmod +x "${ROOT}/out/AyuGram"
if have strip; then
  strip --strip-unneeded "${ROOT}/out/AyuGram" || true
fi

log "binary: ${ROOT}/out/AyuGram"
log "next: ./scripts/package-deb.sh   and/or   ./scripts/package-appimage.sh"
