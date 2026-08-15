# AyuGram For Linux

[ [English](README.md) | Русский ]

**Неофициальный Linux-порт [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop)** — пакеты и установщик для Linux Mint, Ubuntu, Debian, Fedora, Arch и других дистрибутивов.

Официальный AyuGram отдаёт готовые сборки только под Windows и macOS. Этот репозиторий нужен, чтобы поставить тот же клиент на Linux без ручной сборки ~25 000 коммитов.

Текущий апстрим: **AyuGram Desktop v7.0.9**

## Что внутри

| Возможность | Откуда |
| --- | --- |
| Ghost mode | апстрим |
| Антиудаление / история сообщений | апстрим |
| Шрифты, streamer mode, переводчик | апстрим |
| Локальный Telegram Premium | апстрим |
| Установка одной командой на Linux Mint | этот репозиторий |
| `.deb` для Mint / Ubuntu / Debian | этот репозиторий |
| AppImage | этот репозиторий |
| Запасной вариант через Flatpak | этот репозиторий |
| Скрипты сборки из исходников | этот репозиторий |

Это упаковочный форк, а не переписанный клиент. Сама программа — [AyuGram/AyuGramDesktop](https://github.com/AyuGram/AyuGramDesktop), форк [Telegram Desktop](https://github.com/telegramdesktop/tdesktop).

Форк исходников на этом аккаунте: [stillemptyNOW/AyuGramDesktop](https://github.com/stillemptyNOW/AyuGramDesktop)

## Быстрая установка (Linux Mint, Ubuntu, Debian)

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash
```

Скрипт сам определяет дистрибутив и выбирает способ:

1. `.deb` из Releases этого репозитория, если пакет уже собран
2. иначе Flatpak (на Linux Mint обычно уже есть)
3. AppImage, если указать `--method appimage`

### Выбрать способ вручную

```bash
# пакет для Linux Mint / Ubuntu / Debian
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method deb

# Flatpak (самый простой рабочий вариант)
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method flatpak

# портативный AppImage
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method appimage

# сборка официальных исходников через Docker (долго, ~30 ГБ)
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/install.sh | bash -s -- --method source
```

### Другие дистрибутивы

| Дистрибутив | Команда |
| --- | --- |
| **Linux Mint / Ubuntu / Debian** | установщик выше или `sudo apt install ./ayugram-desktop_*_amd64.deb` |
| **Fedora** | `sudo dnf install ayugram-desktop` из [RPM Fusion](https://admin.rpmfusion.org/pkgdb/package/free/ayugram-desktop/) |
| **Arch / Manjaro** | `yay -S ayugram-desktop` или `yay -S ayugram-desktop-bin` |
| **NixOS** | `ayugram-desktop` из nixpkgs / [ndfined-crp](https://github.com/ndfined-crp/ayugram-desktop) |
| **Любой Linux** | Flatpak или AppImage из [Releases](https://github.com/stillemptyNOW/AyuGram-For-Linux/releases) |

Заметки именно для Mint: [docs/linux-mint.md](docs/linux-mint.md)

## Удаление

```bash
curl -fsSL https://raw.githubusercontent.com/stillemptyNOW/AyuGram-For-Linux/main/scripts/uninstall.sh | bash
```

## Сборка у себя

Нужны Git, Docker и Docker Buildx. На Linux Mint:

```bash
sudo apt update
sudo apt install -y git curl ca-certificates
# Docker: https://docs.docker.com/engine/install/ubuntu/
git clone https://github.com/stillemptyNOW/AyuGram-For-Linux.git
cd AyuGram-For-Linux
./scripts/build-linux.sh
./scripts/package-deb.sh
./scripts/package-appimage.sh
```

Полная инструкция: [docs/building.md](docs/building.md)

## Зачем этот репозиторий

| Официальный AyuGram | Этот форк |
| --- | --- |
| Windows `.zip` + macOS `.dmg` | `.deb` для Linux Mint / Ubuntu |
| Linux только из исходников | AppImage |
| Community Flatpak в чужом репозитории | один установщик для Mint и рядом |
| Arch / Fedora / Nix пакуют другие люди | в приоритете семейство Debian |

## Отказ от ответственности

- Не связан с Telegram FZ-LLC и авторами AyuGram.
- AyuGram — неофициальный клиент Telegram с функциями, которые могут нарушать Terms of Service (Ghost mode, антиудаление и др.). Используйте на свой риск.
- Скрипты упаковки здесь — GPL-3.0. Само приложение — GPL-3.0 с исключением OpenSSL, как у Telegram Desktop.

## Благодарности

- [AyuGram Desktop](https://github.com/AyuGram/AyuGramDesktop) — клиент
- [Telegram Desktop](https://github.com/telegramdesktop/tdesktop) — апстрим
- [0FL01/AyuGramDesktop-flatpak](https://github.com/0FL01/AyuGramDesktop-flatpak) — community Flatpak
- Kotatogram, 64Gram, Forkgram — соседние форки

## Лицензия

[GPL-3.0](LICENSE) (условия Telegram Desktop / AyuGram, включая исключение OpenSSL).
