# Linux Mint

AyuGram For Linux is aimed at **Linux Mint** first (Cinnamon, MATE, Xfce).

Mint is Ubuntu-based, so the native format is a `.deb` package. Flatpak is also installed by default on recent Mint releases and is the fallback when a `.deb` is not published yet.

## Recommended: one command

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

Then open the application menu and search for **AyuGram Desktop**.

## If the menu does not show it

1. Log out and back in, or run `cinnamon --replace &` on Cinnamon.
2. For a user-level AppImage install, confirm `~/.local/share/applications/com.ayugram.desktop.desktop` exists.
3. Flatpak apps live under the *System* / *Internet* category.

## Telegram Desktop is already installed

That is fine. AyuGram uses the binary name `AyuGram` and the desktop id `com.ayugram.desktop`. The two clients can sit next to each other. They do **not** share the same profile directory.

- Telegram Desktop: `~/.local/share/TelegramDesktop`
- AyuGram: `~/.local/share/AyuGramDesktop`

## `tg://` links

The `.deb` postinst tries to register AyuGram as the `tg://` handler. To do it yourself:

```bash
xdg-mime default com.ayugram.desktop.desktop x-scheme-handler/tg
```

## Wayland vs X11

Mint Cinnamon still defaults to X11 on many machines. Both should work. If the window is invisible or input is broken on Wayland:

```bash
AyuGram -platform xcb
```

or, for Flatpak:

```bash
flatpak run --env=QT_QPA_PLATFORM=xcb com.ayugram.desktop
```

## Build on Mint itself

Install Docker using the Ubuntu instructions (Mint 22 ≈ Ubuntu 24.04, Mint 21 ≈ Ubuntu 22.04), add your user to the `docker` group, then:

```bash
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/build-linux.sh
./scripts/package-deb.sh
sudo apt install ./dist/ayugram-desktop_*_amd64.deb
```

You need tens of gigabytes free and a few hours. The Docker image is the official Telegram Desktop CentOS build environment.
