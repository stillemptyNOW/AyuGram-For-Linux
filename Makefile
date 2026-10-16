VERSION ?= $(shell sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' VERSION.json | head -n1)
export VERSION

.PHONY: help install uninstall build package deb appimage arch check clean

help:
	@echo "AyuGram For Linux $(VERSION)"
	@echo "  make install     run the distro installer"
	@echo "  make uninstall   remove the client"
	@echo "  make package     fetch the binary from the Flatpak, build .deb/.tar.xz/AppImage (needs flatpak, ostree)"
	@echo "  make build       compile official sources in Docker (hours)"
	@echo "  make deb         package out/AyuGram as .deb"
	@echo "  make appimage    package out/AyuGram as AppImage"
	@echo "  make arch        build the pacman package (Arch, needs the tarball from 'make package' or the release)"
	@echo "  make check       shellcheck + bash -n"

install:
	bash scripts/install.sh --yes

uninstall:
	bash scripts/uninstall.sh

build:
	bash scripts/build-linux.sh

package:
	bash scripts/ci-package.sh

deb:
	bash scripts/package-deb.sh

appimage:
	bash scripts/package-appimage.sh

arch:
	bash scripts/package-arch.sh

check:
	@for f in scripts/*.sh; do bash -n "$$f" || exit 1; done
	@if command -v shellcheck >/dev/null 2>&1; then shellcheck -x scripts/*.sh; else echo "shellcheck not installed, skipped"; fi

clean:
	rm -rf build dist out
