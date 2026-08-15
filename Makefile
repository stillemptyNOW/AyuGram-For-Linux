PREFIX ?= /usr/local
VERSION ?= $(shell sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' VERSION.json | head -n1)

.PHONY: help install uninstall build deb appimage check

help:
	@echo "AyuGram For Linux $(VERSION)"
	@echo "  make install     run the distro installer"
	@echo "  make uninstall   remove the client"
	@echo "  make build       compile official sources in Docker"
	@echo "  make deb         package out/AyuGram as .deb"
	@echo "  make appimage    package out/AyuGram as AppImage"

install:
	bash scripts/install.sh --yes

uninstall:
	bash scripts/uninstall.sh

build:
	bash scripts/build-linux.sh

deb: 
	bash scripts/package-deb.sh

appimage:
	bash scripts/package-appimage.sh

check:
	bash -n scripts/common.sh
	bash -n scripts/install.sh
	bash -n scripts/uninstall.sh
	bash -n scripts/build-linux.sh
	bash -n scripts/package-deb.sh
	bash -n scripts/package-appimage.sh
