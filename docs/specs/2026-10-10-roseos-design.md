# Rose OS 1.0 «Rosette» — спецификация дизайна

Дата: 2026-10-10
Автор: enum000
Статус: черновик на ревью

## 1. Цель и аудитория

Rose OS — дистрибутив Linux на базе Debian 13 «trixie». Это красивая и удобная система «из коробки» с уклоном в разработку.

Цели проекта:
1. **Обучение.** Автор разбирается, как устроен дистрибутив: пакеты, репозиторий, загрузка, установщик.
2. **Продукт для других.** Систему можно скачать, установить рядом с Windows (dual boot) и получать обновления.

Аудитория: новички, пришедшие с Windows, и разработчики, которым нужна красивая готовая система.

Уровень автора: начинающий пользователь Linux. Решения выбираются в пользу надёжности, документированности и минимальной поддержки.

### Критерии успеха 1.0

- ISO `roseos-1.0-amd64.iso` загружается в UEFI (с Secure Boot и без) и запускает live-сессию KDE.
- Calamares ставит систему рядом с Windows 11, в меню GRUB видны Rose OS, Windows и снапшоты.
- На машине с NVIDIA драйвер ставится автоматически, KDE и Hyprland работают.
- После установки `apt upgrade` получает пакеты из репозитория Rose OS, подписанного ключом проекта.
- Откат на снапшот из меню GRUB возвращает систему в рабочее состояние.
- Весь интерфейс в стиле Rosé Pine; язык RU или EN выбирается в установщике.

### Вне рамок 1.0 (будет в 1.x)

- Приложение Rose Welcome (приветственное окно).
- Rose Dev Setup (установка Python, Node, Docker, Rust и т.д. галочками).
- Собственная сборка свежего Hyprland и его зависимостей.
- Сайт проекта, дополнительные варианты логотипа.
- Архитектуры, кроме amd64.

## 2. Ключевые решения

| Вопрос | Решение | Почему |
|---|---|---|
| База | Debian 13 «trixie» stable | Стабильность, документация, Secure Boot, основа Ubuntu/Mint |
| Сборка ISO | live-build | Официальный инструмент Debian, декларативные конфиги в git |
| Установщик | Calamares | Стандарт для производных дистрибутивов, брендируется, умеет «рядом с Windows» |
| Окружение по умолчанию | KDE Plasma 6 | Привычно для пользователей Windows, гибкий брендинг через Global Theme |
| Доп. сессия | Hyprland (версия из Debian 13) | Для продвинутых; выбирается на экране входа SDDM |
| Стиль | Rosé Pine (тёмная по умолчанию), Rosé Pine Dawn (светлая) | Готовые темы почти для всех программ, совпадает с названием |
| Шелл | zsh + Starship по умолчанию у пользователей; bash остаётся системным и у root | Красиво и привычно разработчикам, совместимо со скриптами |
| Редактор | VS Code (репозиторий Microsoft) | Выбор автора |
| Браузер | Firefox (APT-репозиторий Mozilla, не ESR) | Свежая версия, тема Rosé Pine через политики |
| Файловая система | Btrfs + Snapper + grub-btrfs, zram вместо swap-раздела | Откат обновлений из меню загрузки |
| NVIDIA | Один ISO, драйвер внутри, автоопределение при установке, MOK при Secure Boot | Не нужно выбирать ISO; работает «из коробки» |
| Языки | RU и EN, выбор в установщике | Русскоязычная аудитория плюс международная |
| Хостинг | GitHub (код, CI, APT-репозиторий на Pages), SourceForge (ISO) | Бесплатно; ISO больше лимита GitHub Releases в 2 ГБ |
| Выпуски | Привязка к Debian 13; ISO 1.x раз в 2–3 месяца; 2.0 на Debian 14 | Минимум поддержки, предсказуемо |

## 3. Идентичность

- Имя: **Rose OS**, всегда пишется так (чтобы не путать с ROSA Linux).
- Версия 1.0, кодовое имя **Rosette** (по туманности Розетка).
- Логотип: стилизованная красная роза с серыми листьями (`branding/logo-original.png`, авторский).
- Производные логотипа (делаются на этапе 3):
  - SVG-векторизация оригинала;
  - вариант для тёмного фона: листья цвета pine/foam из Rosé Pine вместо светло-серых;
  - монохромный вариант для трея и мест с одним цветом;
  - PNG в размерах 16, 22, 24, 32, 48, 64, 128, 256, 512.
- Фирменный цвет: красный логотипа. Акцентный цвет интерфейса: `love` из Rosé Pine (`#eb6f92` / Dawn `#b4637a`).

`/etc/os-release`:
```
PRETTY_NAME="Rose OS 1.0 (Rosette)"
NAME="Rose OS"
VERSION_ID="1.0"
VERSION="1.0 (Rosette)"
VERSION_CODENAME=trixie
ROSEOS_CODENAME=rosette
ID=roseos
ID_LIKE=debian
HOME_URL="https://github.com/enum000/roseos"
BUG_REPORT_URL="https://github.com/enum000/roseos/issues"
LOGO=roseos-logo
```
`VERSION_CODENAME` остаётся `trixie`: по нему сторонние установщики (Docker, NodeSource, PostgreSQL) выбирают репозиторий.

## 4. Архитектура репозитория

Один репозиторий `github.com/enum000/roseos`:

```
roseos/
├── build/                    # конфигурация live-build
│   ├── auto/config           # параметры lb config
│   ├── config/package-lists/ # base, kde, hyprland, apps, dev, nvidia, live
│   ├── config/includes.chroot/
│   ├── config/hooks/live/    # скрипты настройки при сборке
│   ├── config/archives/      # сторонние репозитории и ключи (Rose, Mozilla, Microsoft)
│   └── config/bootloaders/   # тема меню загрузки live
├── packages/
│   ├── roseos-archive-keyring/
│   ├── roseos-branding/      # os-release, логотипы, обои, тема GRUB, Plymouth
│   ├── roseos-theme/         # Global Theme «Rose», цвета, SDDM, Konsole, GTK, Firefox-политики
│   ├── roseos-settings/      # /etc/skel, zsh + Starship, умолчания KDE, zram
│   ├── roseos-hyprland/      # конфиг Hyprland, Waybar, лаунчер, уведомления, блокировка
│   ├── roseos-snapshots/     # Snapper, grub-btrfs, apt-хуки
│   ├── roseos-nvidia/        # детект, установка драйвера, переменные для Hyprland
│   ├── roseos-calamares/     # брендинг и конфиги модулей Calamares
│   └── roseos-desktop/       # метапакет: тянет всё вышеперечисленное
├── branding/                 # исходники графики
├── scripts/                  # build-packages.sh, build-iso.sh, publish-repo.sh, run-vm.sh
├── docs/
└── .github/workflows/        # packages.yml, iso.yml
```

Отдельный репозиторий `github.com/enum000/roseos-repo` содержит только опубликованный APT-репозиторий (ветка для GitHub Pages).

**Главный принцип:** всё, что отличает Rose OS от Debian, живёт в пакетах `roseos-*`. В конфиге live-build допустимы только вещи, нужные live-сессии и установщику. Благодаря этому любые изменения доходят до установленных систем через `apt upgrade`.

Настройки по умолчанию ставятся способами, которые не перетирают изменения пользователя: `/etc/skel` (для новых пользователей), системные каталоги XDG `/etc/xdg` (KDE читает их как умолчания), drop-in-каталоги (`*.d/`), `dpkg-divert` только при крайней необходимости.

## 5. Live-образ и установщик

### Live-сессия
- Загрузка UEFI через подписанные shim и GRUB Debian; поддерживается и legacy BIOS (через isolinux), но приоритет у UEFI.
- Пункты меню: «Rose OS (live)», «Rose OS (безопасная графика, nomodeset)», «Проверка памяти».
- Автовход в KDE под пользователем `rose`, на рабочем столе значок «Установить Rose OS».
- В live-сессии используется открытый драйвер (nouveau); проприетарный NVIDIA ставится уже в установленную систему.

### Calamares
Последовательность: welcome → locale → keyboard → partition → users → summary → exec → finished.

- **welcome:** выбор RU/EN; проверки: ≥ 40 ГБ на диске, ≥ 4 ГБ RAM, подключение к питанию; предупреждение про Fast Startup и BitLocker.
- **keyboard:** для русского — раскладки `us,ru`, переключение Alt+Shift.
- **partition:** варианты «Рядом с Windows», «Заменить раздел», «Стереть диск», «Вручную». По умолчанию Btrfs, подтома `@`, `@home`, `@snapshots`, `@var_log`, `@cache`, сжатие `zstd:1`, опция `noatime`. Шифрование LUKS2 — галочкой, по умолчанию выключено. Отдельный swap-раздел не создаётся.
- **users:** имя, пароль, имя компьютера; автовход — выключен по умолчанию.
- **exec (после копирования файлов):**
  1. Загрузчик: `shim-signed` + `grub-efi-amd64-signed` в существующий ESP. Каталог `\EFI\debian` (подписанный GRUB Debian ищет конфиг там), запись NVRAM с названием «Rose OS».
  2. `GRUB_DISABLE_OS_PROBER=false`, тема GRUB Rose, `GRUB_DISTRIBUTOR="Rose OS"`.
  3. Детект NVIDIA (`lspci -n`, вендор `10de`): установка `nvidia-driver` и прошивок с ISO. При включённом Secure Boot — генерация ключа DKMS и `mokutil --import` с паролем, который пользователь вводит в Calamares.
  4. zram (`zram-tools`, 50 % RAM, zstd).
  5. Удаление Calamares и live-пакетов.
  6. Настройка Snapper и первый снапшот «Чистая установка».
- **finished:** кнопка «Перезагрузить»; если ставился MOK — напоминание про синий экран MokManager.

### Требования к Windows перед установкой (документируются)
- Отключить «Быстрый запуск».
- Приостановить или выключить BitLocker / шифрование устройства.
- Освободить место на диске (рекомендуется ≥ 60 ГБ для Rose OS).
- Сделать резервную копию.

## 6. Рабочий стол

### KDE Plasma 6 (сессия по умолчанию)
- Плавающая нижняя панель: меню с логотипом слева, задачи по центру, трей и часы справа.
- Global Theme «Rose» (`org.roseos.desktop`): цветовые схемы Rosé Pine и Rosé Pine Dawn, стиль Breeze в палитре проекта (без Kvantum), иконки Papirus с розовыми папками, курсор Breeze, шрифты Inter (интерфейс) и JetBrains Mono (моноширинный).
- Обои: 4 штуки, у каждой тёмный и светлый вариант.
- Сквозной стиль загрузки: тема GRUB → Plymouth (логотип с плавной анимацией) → SDDM (тема на основе Breeze в палитре Rosé Pine) → рабочий стол.
- Темы программ: Konsole (Rosé Pine), GTK-приложения (через Breeze GTK и цветовую схему), Firefox (тема Rosé Pine через `policies.json`), VS Code (расширение Rosé Pine ставится при первом входе пользователя скриптом автозапуска; при отсутствии сети повторяется при следующем входе).

### Hyprland (дополнительная сессия)
- Версия — из Debian 13.
- Компоненты: Waybar (верх), лаунчер по `Super+Space`, уведомления, экран блокировки, гашение экрана при простое, обои, скриншоты, шпаргалка клавиш по `Super+/`.
- Конкретные пакеты выбираются на этапе 5 по фактическому наличию в Debian 13: в приоритете hyprlock/hypridle/hyprpaper, иначе аналоги из экосистемы Sway (swaylock, swayidle, swaybg); лаунчер — fuzzel или wofi; уведомления — mako или swaync.
- При наличии NVIDIA — переменные окружения для Wayland выставляет `roseos-nvidia`.

### Терминал и шелл
- zsh — шелл по умолчанию для новых пользователей (через `/etc/adduser.conf` / `useradd` defaults и Calamares).
- Starship с темой Rosé Pine, `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- bash остаётся у root и для скриптов.

## 7. Программы по умолчанию

- **Система:** Discover (+ Flatpak и Flathub), Dolphin, Konsole, Kate, Ark, Spectacle, Gwenview, Okular, системный монитор, KDE Partition Manager.
- **Интернет и общение:** Firefox, Telegram Desktop.
- **Мультимедиа:** VLC (знаком пользователям Windows), Elisa (музыка), кодеки.
- **Офис:** LibreOffice (интерфейс KDE, языковые пакеты RU/EN).
- **Разработка:** git, VS Code, build-essential, curl, wget, zsh + Starship.
- **Прошивки:** `firmware-linux`, `firmware-misc-nonfree`, `firmware-iwlwifi`, `firmware-realtek`, `firmware-atheros`, `firmware-sof-signed` (звук на современных ноутбуках), `intel-microcode`, `amd64-microcode`.
- **Локализация:** RU и EN, переводы KDE, LibreOffice, Firefox; словари проверки орфографии.

## 8. Пакеты, репозиторий и обновления

### Источники APT
- Debian 13: `main contrib non-free non-free-firmware`, `trixie-updates`, `trixie-security`.
- Rose OS: `deb [signed-by=/usr/share/keyrings/roseos-archive-keyring.gpg] https://enum000.github.io/roseos-repo trixie main`.
- Mozilla (Firefox) и Microsoft (VS Code) — со своими ключами в `/usr/share/keyrings/`, Firefox ESR из Debian понижается в приоритете через APT pinning.

### Наш репозиторий
- Индексы генерирует `apt-ftparchive`, подпись `InRelease`/`Release.gpg` делает `gpg`, после подписи она проверяется `gpgv` против ключа из `roseos-archive-keyring`. Публикуется в `enum000/roseos-repo` (GitHub Pages); CI пушит туда по deploy key с правом записи.
- Подпись — GPG-ключ «Rose OS Archive Signing Key» (ed25519, срок действия 2 года с продлением). Приватный ключ хранится как секрет GitHub Actions и в офлайн-бэкапе у автора.
- Версии пакетов: `1.0.0` для первого выпуска, далее семантически (`1.0.1` — исправления, `1.1.0` — новое).

### Обновления у пользователя
- Discover уведомляет и ставит обновления Debian, Rose OS и Flatpak.
- Snapper делает снапшоты до и после каждой операции `apt`; grub-btrfs добавляет их в меню GRUB.
- Хранение снапшотов: последние 10 «apt»-пар и снапшот «Чистая установка».

### CI (GitHub Actions)
- `packages.yml`: при изменениях в `packages/` — сборка в контейнере `debian:trixie`, `lintian`, подпись, публикация в `roseos-repo`.
- `iso.yml`: по тегу `v*` — сборка ISO в привилегированном контейнере `debian:trixie`, SHA256SUMS, загрузка на SourceForge (проект `roseos`), черновик GitHub Release со ссылками и контрольными суммами.
- Ожидаемый размер ISO — 3–3,5 ГБ; больше лимита GitHub Releases в 2 ГБ, поэтому ISO живёт на SourceForge.

## 9. Окружение сборки

- WSL2 с Debian 13 на ноутбуке автора (HP OMEN 16, i7‑14700HX, RTX 4070 Laptop, 32 ГБ RAM, Windows 11 Home).
- Исходники и кэш сборки внутри файловой системы WSL (`~/roseos`), не на `/mnt/c`.
- Ориентировочно нужно 30 ГБ на диске C: под WSL и кэш; сейчас свободно 80 ГБ — перед этапом 0 диск чистится.
- Скрипты `scripts/*.sh` одинаково работают локально и в CI.

## 10. Тестирование

**Основное тестирование — в виртуальных машинах.** Реальный ноутбук используется только на этапе 7.

| Уровень | Что проверяем | Где |
|---|---|---|
| 1. Пакеты | `lintian`, чистая установка и удаление, обновление с предыдущей версии | WSL, CI |
| 2. Загрузка ISO | UEFI с Secure Boot и без, legacy BIOS, live-сессия KDE | VM |
| 3. Установка | Calamares (стереть диск, вручную), Btrfs, снапшоты, откат из GRUB, `apt upgrade` из нашего репозитория | VM |
| 4. Dual boot | Установка «рядом с Windows» на диск с Windows 11, загрузка обеих систем, os-prober | VM с Windows 11 (оценочная версия Microsoft) |
| 5. Живое железо | Live с флешки на OMEN без установки: NVIDIA, Wi‑Fi, звук, сон, тачпад, Hyprland | Ноутбук автора |
| 6. Финальная установка | Dual boot на ноутбуке автора | Ноутбук автора, после бэкапа |

### Виртуальные машины
- Гипервизор — VirtualBox 7 на Windows (UEFI, Secure Boot и TPM 2.0 поддерживаются, понятный интерфейс). Резерв — QEMU + OVMF внутри WSL2.
- VM «rose-clean»: пустой диск 60 ГБ, UEFI.
- VM «rose-dualboot»: Windows 11 Enterprise Evaluation, UEFI + Secure Boot + TPM, диск 120 ГБ; снапшот VM «чистая Windows» для повторных прогонов.
- Ограничения VM, проверяемые только на железе: драйвер NVIDIA и MOK с реальной картой, ускорение графики в Hyprland. Hyprland в VM запускается с программным рендерингом только для проверки конфигов.

### Чек-лист релиза (минимум)
- [ ] ISO грузится в VM: UEFI, UEFI + Secure Boot, BIOS.
- [ ] Установка «стереть диск» и «рядом с Windows» проходит без ошибок.
- [ ] В меню GRUB есть Rose OS, Windows, снапшоты; Windows загружается.
- [ ] `apt update && apt upgrade` получает пакет из `roseos-repo` с проверкой подписи.
- [ ] Откат на снапшот работает.
- [ ] RU и EN установки: язык интерфейса и раскладки корректны.
- [ ] На OMEN: NVIDIA, Wi‑Fi, звук, сон/пробуждение, KDE и Hyprland.

## 11. Этапы

| # | Этап | Результат |
|---|---|---|
| 0 | Окружение | WSL2 + Debian 13, live-build, VirtualBox, GPG-ключ, репозитории `roseos` и `roseos-repo` |
| 1 | «Голый» ISO | Debian 13 + KDE + Calamares, ставится в VM «rose-clean» |
| 2 | Пакеты и репозиторий | Каркасы `roseos-*`, APT-репозиторий на Pages, CI для пакетов |
| 3 | Брендинг | SVG-логотип и варианты, обои, os-release, GRUB, Plymouth, SDDM, Global Theme |
| 4 | Btrfs и NVIDIA | Разметка и подтома, Snapper + grub-btrfs, модуль NVIDIA + MOK; dual boot в VM |
| 5 | Hyprland | Вторая сессия с конфигом в Rosé Pine |
| 6 | Программы и dev | Набор приложений, Firefox, VS Code, zsh + Starship, RU/EN |
| 7 | Железо | Live-тест на OMEN → бэкап → подготовка диска → установка dual boot |
| 8 | Релиз 1.0 | ISO на SourceForge, README, инструкция по установке, GitHub Release |

## 12. Работы на ноутбуке автора (этап 7)

Выполняются только после явного подтверждения каждого шага и полного бэкапа:
1. Перенос нужных файлов с раздела D: (вторая установка Windows «Kernel OS», 45 ГБ).
2. Удаление записи Kernel OS из загрузчика Windows (если она там есть) и раздела D:.
3. Удаление старой записи UEFI «Fedora» и каталога `\EFI\fedora` из ESP.
4. Проверка свободного места в ESP (размер раздела около 200 МБ; нужно ≥ 30 МБ свободно).
5. Отключение Fast Startup, проверка BitLocker.
6. Освобождение места на C: и установка Rose OS «рядом с Windows».

## 13. Риски

| Риск | Что делаем |
|---|---|
| Старый Hyprland в Debian 13 | Конфиг пишется под имеющуюся версию; своя сборка — в 1.x |
| NVIDIA + Secure Boot у пользователей | MOK в установщике, понятная инструкция, пункт «безопасная графика» |
| Потеря GPG-ключа | Офлайн-бэкап; ключ в пакете `roseos-archive-keyring` для плавной ротации |
| live-build в WSL2 (chroot, loop-устройства) | Сборка от root внутри WSL; при проблемах — сборка в CI или в VM с Debian |
| Мало места на C: | Чистка перед этапом 0, ограничение размера кэша сборки |
| Размер ISO > 2 ГБ | ISO на SourceForge |
