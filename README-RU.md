# AyuGram For Linux

[ [English](README.md) | Русский ]

**Неофициальные Linux-пакеты [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop)** для Linux Mint, Ubuntu, Debian, Arch Linux и любого другого x86_64-дистрибутива.

Официальный AyuGram выпускает сборки только под Windows и macOS. Этот репозиторий берёт портативную Linux-сборку (Qt вшит статически, нужен glibc ≥ 2.28) из community Flatpak и делает из неё нормальные пакеты — собирать Telegram Desktop самому не нужно.

Текущий апстрим: **AyuGram Desktop v7.2.9**

## Быстрая установка

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

Скрипт сам определяет дистрибутив:

| Дистрибутив | Что ставится |
| --- | --- |
| Linux Mint, Ubuntu, Debian, Pop!_OS, Zorin… | `.deb` из Releases (если не вышло — Flatpak) |
| Arch, Manjaro, EndeavourOS, CachyOS, Garuda… | pacman-пакет из Releases (если не вышло — `makepkg`) |
| Fedora | портативная сборка в `~/.local/opt` или Flatpak |
| всё остальное | портативная сборка в `~/.local/opt`, root не нужен |

### Выбрать способ вручную

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method deb
```

| `--method` | |
| --- | --- |
| `deb` | `.deb`-пакет (Mint / Ubuntu / Debian) |
| `arch` | pacman-пакет `ayugram-for-linux-bin` |
| `aur` | собрать `ayugram-desktop` из AUR через yay/paru (системные библиотеки, долго) |
| `flatpak` | Flatpak |
| `appimage` | AppImage в `~/Applications` |
| `portable` | распаковать в `~/.local/opt/AyuGram`, добавить в меню с иконками |
| `source` | собрать официальные исходники в Docker (часы, ~30 ГБ) |

## Arch Linux

Три способа, от простого к сложному:

```bash
# 1. установщик (скачает готовый пакет и сделает pacman -U)
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

```ini
# 2. pacman-репозиторий: добавить в /etc/pacman.conf, потом `sudo pacman -Syu ayugram-for-linux-bin`
#    дальше обновления приходят обычным `sudo pacman -Syu`
[ayugram]
SigLevel = Optional TrustAll
Server = https://github.com/stillemptyNOW/AyuGram-For-Linux/releases/latest/download
```

```bash
# 3. собрать самому из PKGBUILD
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/package-arch.sh
sudo pacman -U dist/ayugram-for-linux-bin-*-x86_64.pkg.tar.zst
```

Пакет зависит только от `glibc`, `glib2`, `fontconfig`, `freetype2`, `cairo` и `pango`, поэтому обновления Qt, abseil или ffmpeg в Arch его не ломают. Подробности: [docs/arch.md](docs/arch.md).

## Удаление

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/uninstall.sh | bash
```

Удаляет `.deb`, pacman-пакет, Flatpak, AppImage или портативную установку. Переписки в `~/.local/share/AyuGramDesktop` остаются.

## Собрать пакеты самому

```bash
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
make package     # нужны flatpak и ostree: .deb, .tar.xz, AppImage в dist/
make arch        # на Arch: pacman-пакет из tar.xz
make build       # или скомпилировать исходники апстрима в Docker (часы)
```

Подробно: [docs/building.md](docs/building.md). Про Mint: [docs/linux-mint.md](docs/linux-mint.md). Таблица дистрибутивов: [docs/distros.md](docs/distros.md).

## Отказ от ответственности

- Не связан с Telegram FZ-LLC и авторами AyuGram.
- В AyuGram есть функции, нарушающие Terms of Service Telegram (режим призрака, антиудаление и др.). Используйте на свой риск.
- Скрипты упаковки — GPL-3.0. Само приложение — GPL-3.0 с исключением OpenSSL, как Telegram Desktop.

## Благодарности

- [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) — клиент
- [Telegram Desktop](https://github.com/telegramdesktop/tdesktop) — апстрим
- [0FL01/AyuGramDesktop-flatpak](https://github.com/0FL01/AyuGramDesktop-flatpak) — community Flatpak, откуда берётся бинарник

## Лицензия

[GPL-3.0](LICENSE) (условия Telegram Desktop / AyuGram, включая исключение OpenSSL).
