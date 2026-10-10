# Rose OS: этапы 0–2 (окружение, базовый ISO, пакеты и репозиторий) — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Получить ISO на Debian 13 с KDE и Calamares, который ставится в виртуальную машину, содержит пакеты `roseos-*` и после установки получает обновления из подписанного APT-репозитория Rose OS на GitHub Pages, собираемого в GitHub Actions.

**Architecture:** Сборка идёт в WSL2 (Debian 13) на ноутбуке автора, проект хранится в `~/roseos` внутри WSL. live-build собирает ISO из декларативной конфигурации в `build/`. Свои пакеты лежат в `packages/` (debhelper, `3.0 (native)`) и собираются скриптом `scripts/build-packages.sh`. Репозиторий генерирует `apt-ftparchive` и подписывает `gpg` (скрипт `scripts/publish-repo.sh`), публикация идёт в отдельный git-репозиторий `enum000/roseos-repo`, который раздаёт GitHub Pages. Тестирование: shell-скрипты в `scripts/tests/` плюс виртуальные машины VirtualBox на Windows.

**Tech Stack:** Debian 13 «trixie», live-build, Calamares (`calamares-settings-debian`), KDE Plasma 6, debhelper 13, apt-ftparchive, GnuPG (ed25519), mmdebstrap (тестовые chroot), GitHub Actions (контейнер `debian:trixie`), GitHub Pages, VirtualBox 7 (VBoxManage), WSL2.

**Spec:** `docs/specs/2026-10-10-roseos-design.md`

## Global Constraints

- База: Debian 13 `trixie`, архитектура `amd64`.
- Все свои пакеты называются `roseos-*`, формат `3.0 (native)`, `debhelper-compat (= 13)`, `Architecture: all`, `Rules-Requires-Root: no`.
- Maintainer во всех пакетах: `enum000 <enum000@users.noreply.github.com>` (личная почта не публикуется).
- Начальная версия всех пакетов: `1.0.0`.
- URL репозитория: `https://enum000.github.io/roseos-repo`, suite `trixie`, component `main`.
- Ключ репозитория у пользователя: `/usr/share/keyrings/roseos-archive-keyring.asc`; источник: `/etc/apt/sources.list.d/roseos.sources` (формат deb822).
- Ключ подписи: ed25519, только подпись, срок 2 года, UID `Rose OS Archive Signing Key <enum000@users.noreply.github.com>`.
- Проект собирается **только** внутри файловой системы WSL (`~/roseos`), никогда не из `/mnt/c/...`.
- Все текстовые файлы с окончаниями строк LF (`.gitattributes`: `* text=auto eol=lf`).
- Shell-скрипты POSIX `sh` (`#!/bin/sh`, `set -eu`), исполняемые (`chmod +x`, бит хранится в git).
- Скрипты, которым нужен root, вызывают `as_root` из `scripts/lib/common.sh` (sudo, если не root; напрямую, если root, как в CI).
- Действия, видимые другим (создание репозиториев на GitHub, push, секреты), выполняются только после явного «да» пользователя в чате.

## Review Focus

1. **Сборка из `/mnt/c/...`** (проект склонирован не туда): `build-iso.sh` должен сразу завершиться с кодом 2 и понятным сообщением, а не падать через полчаса на правах файлов. Тест в Task 5.
2. **Мало места на диске** (на C: свободно всего ~80 ГБ): `build-iso.sh` проверяет, что свободно ≥ 25 ГБ, и иначе завершается с кодом 3 до начала сборки. Тест в Task 5.
3. **CI подписывает не тем ключом**, который стоит у пользователей (перепутан секрет): `publish-repo.sh` проверяет подпись `gpgv` против ключа из пакета `roseos-archive-keyring` и при несовпадении не публикует. Тест в Task 8.
4. **Пакет изменён без повышения версии**: у пользователей обновление не придёт. `check-version-bumps.sh` валит CI, если файлы пакета поменялись, а `debian/changelog` нет. Тест в Task 9.
5. **Windows-окончания строк (CRLF)** в скриптах и конфигах дают ошибки вида `/bin/sh^M`. `test-packages.sh` валится при наличии CR. Тест в Task 7.

---

## Структура файлов (после этапов 0–2)

```
roseos/
├── .gitattributes                      # LF везде, png бинарные
├── .gitignore                          # артефакты сборки
├── .github/workflows/packages.yml      # CI: сборка, тесты, публикация пакетов
├── branding/                           # уже есть: logo-original.png, logo-concepts.html
├── build/
│   ├── auto/config                     # параметры lb config
│   ├── auto/build                      # lb build с логом
│   ├── auto/clean                      # lb clean + удаление сгенерированного
│   └── config/
│       ├── package-lists/live.list.chroot
│       ├── package-lists/base.list.chroot
│       ├── package-lists/kde.list.chroot
│       ├── package-lists/installer.list.chroot
│       ├── package-lists/rose.list.chroot          # Task 10
│       └── includes.chroot/usr/lib/live/config/1190-roseos-sddm-autologin
├── docs/specs/, docs/plans/
├── packages/
│   ├── roseos-archive-keyring/         # ключ + источник APT
│   └── roseos-desktop/                 # метапакет
└── scripts/
    ├── lib/common.sh                   # fail, as_root
    ├── build-iso.sh                    # сборка ISO с проверками
    ├── copy-iso-to-windows.sh          # копия ISO в C:\Users\<user>\RoseOS\iso
    ├── build-packages.sh               # сборка всех packages/* в out/debs
    ├── publish-repo.sh                 # out/debs -> подписанный APT-репозиторий
    ├── check-version-bumps.sh          # проверка версий в CI
    ├── ci-publish.sh                   # публикация из CI в roseos-repo
    ├── vm/new-vm.ps1                   # создание VM VirtualBox
    ├── vm/vm-screenshot.ps1            # скриншот VM
    └── tests/
        ├── iso-expected-paths.txt
        ├── test-build-guards.sh
        ├── test-iso.sh
        ├── test-packages.sh
        ├── test-repo.sh
        └── test-version-bumps.sh
```

Где что запускается:
- `*.sh` запускаются в WSL: `wsl -d Debian -- bash -lc 'cd ~/roseos && ...'`.
- `*.ps1` запускаются в Windows PowerShell: `powershell -ExecutionPolicy Bypass -File \\wsl.localhost\Debian\home\<user>\roseos\scripts\vm\new-vm.ps1 ...`.
- Агент редактирует файлы проекта по пути `\\wsl.localhost\Debian\home\<user>\roseos\...`. Здесь `<user>` — имя пользователя WSL из Task 1.

---

## Этап 0. Окружение

### Task 1: WSL2 с Debian 13 и инструментами сборки

**Files:** нет (настройка системы).

**Interfaces:**
- Produces: дистрибутив WSL `Debian` с `VERSION_CODENAME=trixie`; пользователь WSL `<user>` с sudo; установлены `git live-build debootstrap mmdebstrap xorriso squashfs-tools debhelper dpkg-dev lintian apt-utils gnupg openssh-client rsync gh`.

- [ ] **Step 1: Пользователь ставит WSL (нужны права администратора и перезагрузка)**

Попросить пользователя открыть PowerShell **от имени администратора** и выполнить:
```powershell
wsl --install -d Debian
```
Затем перезагрузить ноутбук. После перезагрузки откроется окно Debian: пользователь задаёт имя (латиницей, например `dima`) и пароль. Имя записать: это `<user>` для всех дальнейших путей.

- [ ] **Step 2: Проверить, что WSL работает и это WSL2**

Run (обычный PowerShell): `wsl -l -v`
Expected: строка `Debian  Running|Stopped  2` (версия 2).

- [ ] **Step 3: Проверить версию Debian**

Run: `wsl -d Debian -- bash -lc '. /etc/os-release; echo $VERSION_CODENAME'`
Expected: `trixie`. Если выведено `bookworm`, выполнить Step 4, иначе пропустить.

- [ ] **Step 4 (только если bookworm): обновить до trixie**

Run:
```bash
wsl -d Debian -- bash -lc 'sudo sed -i "s/bookworm/trixie/g" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y'
```
Затем: `wsl --shutdown`, и повторить Step 3. Expected: `trixie`.

- [ ] **Step 5: Поставить инструменты**

Run:
```bash
wsl -d Debian -- bash -lc 'sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git live-build debootstrap mmdebstrap xorriso squashfs-tools debhelper dpkg-dev lintian apt-utils gnupg openssh-client rsync gh'
```
Expected: завершается без ошибок.

- [ ] **Step 6: Проверить инструменты**

Run: `wsl -d Debian -- bash -lc 'lb --version && mmdebstrap --version && apt-ftparchive --version | head -1 && gh --version | head -1'`
Expected: четыре строки с версиями, без `command not found`.

- [ ] **Step 7: Пользователь настраивает git и GitHub внутри WSL (интерактивно)**

Попросить пользователя выполнить в окне Debian:
```bash
git config --global user.name "enum000"
git config --global user.email "enum000@users.noreply.github.com"
gh auth login
gh auth setup-git
```
(`gh auth login`: GitHub.com → HTTPS → Login with a web browser.)
Проверка: `wsl -d Debian -- bash -lc 'gh auth status'` → `Logged in to github.com account enum000`.

---

### Task 2: Репозиторий проекта на GitHub и рабочая копия в WSL

**Files:**
- Modify: `.gitignore` (уже есть, содержит `.claude/`)
- Create: `docs/plans/2026-10-10-roseos-stages-0-2.md` (этот файл, уже лежит в папке сессии)

**Interfaces:**
- Consumes: Task 1 (git, gh в WSL).
- Produces: публичный репозиторий `github.com/enum000/roseos`; рабочая копия `~/roseos` в WSL, где делаются все последующие задачи.

- [ ] **Step 1: Убрать личную почту из первого коммита**

Первый коммит (`Add Rose OS 1.0 design spec and logo`) создан с личной gmail-почтой. Перед публикацией переписать автора на noreply. Это безопасно, потому что коммит ещё никуда не отправлен. В папке сессии (Windows, Git Bash):
```bash
GIT_AUTHOR_NAME=enum000 GIT_AUTHOR_EMAIL=enum000@users.noreply.github.com GIT_COMMITTER_NAME=enum000 GIT_COMMITTER_EMAIL=enum000@users.noreply.github.com git commit --amend --reset-author --no-edit
git log --format='%an <%ae>' -1
```
Expected: `enum000 <enum000@users.noreply.github.com>`.

- [ ] **Step 2: Закоммитить план**

```bash
git add docs/
GIT_AUTHOR_NAME=enum000 GIT_AUTHOR_EMAIL=enum000@users.noreply.github.com GIT_COMMITTER_NAME=enum000 GIT_COMMITTER_EMAIL=enum000@users.noreply.github.com git commit -m "Add implementation plan for stages 0-2"
```

- [ ] **Step 3: ⚠ Спросить пользователя и создать публичный репозиторий**

Спросить в чате: «Создаю публичный репозиторий github.com/enum000/roseos и отправляю туда спецификацию, план и логотип. Ок?» Только после «да»:
```bash
gh repo create enum000/roseos --public --description "Rose OS — Debian-based Linux distribution" --source . --remote origin --push
```
Expected: `✓ Created repository enum000/roseos`, `✓ Pushed commits`.

- [ ] **Step 4: Склонировать в WSL**

Run: `wsl -d Debian -- bash -lc 'git clone https://github.com/enum000/roseos.git ~/roseos && cd ~/roseos && git log --oneline'`
Expected: два коммита.

- [ ] **Step 5: Проверить окончания строк и права в клоне**

Run: `wsl -d Debian -- bash -lc 'cd ~/roseos && git ls-files --eol | grep -v "i/lf\|i/-text" || echo OK-LF'`
Expected: `OK-LF`.

С этого момента все изменения делаются в `~/roseos` внутри WSL. Папка сессии на Windows больше не используется для кода.

---

### Task 3: VirtualBox и скрипты виртуальных машин

**Files:**
- Create: `scripts/vm/new-vm.ps1`
- Create: `scripts/vm/vm-screenshot.ps1`

**Interfaces:**
- Consumes: Task 2 (`~/roseos`).
- Produces:
  - `new-vm.ps1 -Name <string> [-Iso <path>] [-DiskGB <int=60>] [-MemoryMB <int=8192>] [-SecureBoot] [-Recreate]` создаёт VM с UEFI в `%USERPROFILE%\RoseOS\vms\<Name>`.
  - `vm-screenshot.ps1 -Name <string> -Out <path.png> [-WaitSeconds <int=0>]` сохраняет PNG экрана работающей VM.

- [ ] **Step 1: ⚠ Спросить пользователя и установить VirtualBox**

Спросить: «Скачиваю и устанавливаю VirtualBox (Oracle, ~120 МБ) через winget. Ок?» После «да»:
```powershell
winget install --id Oracle.VirtualBox -e --accept-package-agreements --accept-source-agreements
```
Проверка: `& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" --version` → `7.x.x`.

Примечание: при включённом WSL2 VirtualBox работает через Hyper-V (в углу окна VM будет значок черепахи) и медленнее обычного. Для тестов этого достаточно.

- [ ] **Step 2: Написать `scripts/vm/new-vm.ps1`**

```powershell
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Iso,
    [int]$DiskGB = 60,
    [int]$MemoryMB = 8192,
    [switch]$SecureBoot,
    [switch]$Recreate
)
$ErrorActionPreference = 'Stop'
$vbm = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
$base = Join-Path $env:USERPROFILE 'RoseOS\vms'
New-Item -ItemType Directory -Force -Path $base | Out-Null

function Invoke-VBox { & $vbm @args; if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($args -join ' ') failed ($LASTEXITCODE)" } }

$exists = (& $vbm list vms) -match "^`"$([regex]::Escape($Name))`""
if ($exists) {
    if (-not $Recreate) { throw "VM '$Name' already exists. Use -Recreate to replace it." }
    & $vbm controlvm $Name poweroff 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Invoke-VBox unregistervm $Name --delete
}

Invoke-VBox createvm --name $Name --ostype Debian_64 --register --basefolder $base
Invoke-VBox modifyvm $Name --memory $MemoryMB --cpus 4 --firmware efi --graphicscontroller vmsvga --vram 128 --nic1 nat --rtc-use-utc on
$disk = Join-Path $base "$Name\$Name.vdi"
Invoke-VBox createmedium disk --filename $disk --size ($DiskGB * 1024) --format VDI
Invoke-VBox storagectl $Name --name SATA --add sata --controller IntelAhci --portcount 2
Invoke-VBox storageattach $Name --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
if ($Iso) {
    Invoke-VBox storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso
} else {
    Invoke-VBox storageattach $Name --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
}
if ($SecureBoot) {
    Invoke-VBox modifynvram $Name inituefivarstore
    Invoke-VBox modifynvram $Name enrollmssignatures
    Invoke-VBox modifynvram $Name enrollorclpk
    Invoke-VBox modifynvram $Name secureboot --enable
}
Write-Output "Created VM '$Name' (EFI, ${DiskGB}GB, ${MemoryMB}MB, SecureBoot=$($SecureBoot.IsPresent))"
```

- [ ] **Step 3: Написать `scripts/vm/vm-screenshot.ps1`**

```powershell
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$WaitSeconds = 0
)
$ErrorActionPreference = 'Stop'
$vbm = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if ($WaitSeconds -gt 0) { Start-Sleep -Seconds $WaitSeconds }
& $vbm controlvm $Name screenshotpng $Out
if ($LASTEXITCODE -ne 0) { throw "screenshot of '$Name' failed" }
Write-Output $Out
```

- [ ] **Step 4: Проверить создание VM**

Run (PowerShell):
```powershell
$p = '\\wsl.localhost\Debian\home\<user>\roseos\scripts\vm'
powershell -ExecutionPolicy Bypass -File "$p\new-vm.ps1" -Name rose-selftest -DiskGB 2
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" showvminfo rose-selftest --machinereadable | Select-String '^firmware='
```
Expected: `Created VM 'rose-selftest' ...` и `firmware="EFI"`.

- [ ] **Step 5: Проверить защиту от перезаписи и -Recreate**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "$p\new-vm.ps1" -Name rose-selftest -DiskGB 2; "exit=$LASTEXITCODE"
powershell -ExecutionPolicy Bypass -File "$p\new-vm.ps1" -Name rose-selftest -DiskGB 2 -Recreate -SecureBoot
```
Expected: первая команда пишет `already exists` и `exit=1`; вторая — `SecureBoot=True`.

- [ ] **Step 6: Удалить тестовую VM**

Run: `& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" unregistervm rose-selftest --delete`
Expected: без ошибок.

- [ ] **Step 7: Commit**

```bash
cd ~/roseos && git add scripts/vm && git commit -m "Add VirtualBox VM helper scripts" && git push
```

---

### Task 4: Ключ подписи репозитория

**Files:** нет в репозитории (ключ живёт в `~/.gnupg` и `~/.roseos` в WSL).

**Interfaces:**
- Produces:
  - `~/.roseos/signing-passphrase` — пароль ключа (права 600).
  - `~/.roseos/signing-key-fpr` — отпечаток ключа (одна строка, 40 hex-символов).
  - `~/.roseos/roseos-archive-keyring.asc` — публичный ключ (ASCII).
  - Резервная копия в `C:\Users\dimab\RoseOS-key-backup\`.

- [ ] **Step 1: Создать пароль и ключ**

Run в WSL:
```bash
mkdir -p ~/.roseos && chmod 700 ~/.roseos
head -c 32 /dev/urandom | base64 > ~/.roseos/signing-passphrase && chmod 600 ~/.roseos/signing-passphrase
gpg --batch --pinentry-mode loopback --passphrase-file ~/.roseos/signing-passphrase \
    --quick-gen-key "Rose OS Archive Signing Key <enum000@users.noreply.github.com>" ed25519 sign 2y
gpg --list-secret-keys --with-colons "Rose OS Archive Signing Key" | awk -F: '/^fpr:/ {print $10; exit}' > ~/.roseos/signing-key-fpr
gpg --armor --export "$(cat ~/.roseos/signing-key-fpr)" > ~/.roseos/roseos-archive-keyring.asc
```

- [ ] **Step 2: Проверить ключ: тип, срок, подпись и проверка**

Run:
```bash
FPR=$(cat ~/.roseos/signing-key-fpr); echo "$FPR" | grep -Eq '^[0-9A-F]{40}$' && echo FPR-OK
gpg --list-keys --with-colons "$FPR" | awk -F: '/^pub:/ {print "algo="$4, "expires="$7}'
echo test > /tmp/rose-sig-test
gpg --batch --yes --pinentry-mode loopback --passphrase-file ~/.roseos/signing-passphrase -u "$FPR" --detach-sign -o /tmp/rose-sig-test.sig /tmp/rose-sig-test
gpg --dearmor < ~/.roseos/roseos-archive-keyring.asc > /tmp/rose-keyring.gpg
gpgv --keyring /tmp/rose-keyring.gpg /tmp/rose-sig-test.sig /tmp/rose-sig-test && echo VERIFY-OK
rm -f /tmp/rose-sig-test /tmp/rose-sig-test.sig /tmp/rose-keyring.gpg
```
Expected: `FPR-OK`, `algo=22 expires=<число>` (22 = EdDSA), `VERIFY-OK`.

- [ ] **Step 3: Сделать резервную копию**

Run:
```bash
FPR=$(cat ~/.roseos/signing-key-fpr)
WIN=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
B="$WIN/RoseOS-key-backup"; mkdir -p "$B"
gpg --batch --pinentry-mode loopback --passphrase-file ~/.roseos/signing-passphrase --armor --export-secret-keys "$FPR" > "$B/roseos-signing-secret.asc"
cp ~/.roseos/signing-passphrase ~/.roseos/signing-key-fpr ~/.roseos/roseos-archive-keyring.asc "$B/"
cp ~/.gnupg/openpgp-revocs.d/"$FPR".rev "$B/"
ls "$B"
```
Expected: 5 файлов (secret.asc, passphrase, fpr, keyring.asc, .rev).

Сказать пользователю: «Скопируй папку `C:\Users\dimab\RoseOS-key-backup` на флешку или в менеджер паролей и удали её с диска C:. Без этого ключа нельзя будет выпускать обновления. Срок ключа — 2 года, продлить нужно до октября 2028».

Коммита нет: ключи в git не попадают.

---

## Этап 1. Базовый ISO

### Task 5: Конфигурация live-build, защиты сборки и тест ISO

**Files:**
- Create: `scripts/lib/common.sh`
- Create: `scripts/build-iso.sh`
- Create: `scripts/copy-iso-to-windows.sh`
- Create: `scripts/tests/test-build-guards.sh`
- Create: `scripts/tests/test-iso.sh`
- Create: `scripts/tests/iso-expected-paths.txt`
- Create: `build/auto/config`, `build/auto/build`, `build/auto/clean`
- Create: `build/config/package-lists/{live,base,kde,installer}.list.chroot`
- Create: `build/config/includes.chroot/usr/lib/live/config/1190-roseos-sddm-autologin`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1 (live-build и др.).
- Produces:
  - `scripts/lib/common.sh`: функции `fail <msg>` (печатает `FAIL: msg` в stderr, exit 1) и `as_root <cmd...>`.
  - `scripts/build-iso.sh` → `out/roseos-1.0-amd64.iso`. Коды выхода: 2 — проект под `/mnt/`, 3 — мало места. Переменные: `ROSEOS_ROOT` (корень проекта), `ROSEOS_MIN_FREE_GB` (по умолчанию 25).
  - `scripts/tests/test-iso.sh <iso>` проверяет файл `scripts/tests/iso-expected-paths.txt` (строки `iso:<путь в ISO, glob, без учёта регистра>` и `fs:<абсолютный путь в squashfs>`).
  - `scripts/copy-iso-to-windows.sh <iso>` печатает путь Linux к копии в `C:\Users\<win>\RoseOS\iso\`.

- [ ] **Step 1: Написать `scripts/lib/common.sh`**

```sh
# Sourced by Rose OS scripts.

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}
```

- [ ] **Step 2: Написать падающий тест `scripts/tests/test-build-guards.sh`**

```sh
#!/bin/sh
set -u
. "$(dirname "$0")/../lib/common.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/build-iso.sh"

ROSEOS_ROOT=/mnt/c/fake-roseos "$SCRIPT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] || fail "expected exit 2 when project is under /mnt, got $rc"

ROSEOS_MIN_FREE_GB=999999 "$SCRIPT" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 3 ] || fail "expected exit 3 when disk space is low, got $rc"

echo "PASS: build guards"
```

- [ ] **Step 3: Запустить и убедиться, что падает**

Run: `cd ~/roseos && chmod +x scripts/tests/test-build-guards.sh && scripts/tests/test-build-guards.sh`
Expected: `FAIL: expected exit 2 when project is under /mnt, got 127` (скрипта ещё нет).

- [ ] **Step 4: Написать `scripts/build-iso.sh`**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
MIN_FREE_GB=${ROSEOS_MIN_FREE_GB:-25}

case "$ROOT" in
    /mnt/*)
        echo "ERROR: $ROOT is on a Windows drive. Clone the project inside WSL (e.g. ~/roseos) and build there." >&2
        exit 2
        ;;
esac

free_gb=$(df -BG --output=avail "$ROOT" | tail -1 | tr -dc '0-9')
if [ "$free_gb" -lt "$MIN_FREE_GB" ]; then
    echo "ERROR: need at least ${MIN_FREE_GB}G free in $ROOT, have ${free_gb}G." >&2
    exit 3
fi

cd "$ROOT/build"
as_root lb clean
as_root lb config
as_root lb build

iso=$(ls -t ./*.iso 2>/dev/null | head -1)
[ -n "$iso" ] || fail "live-build did not produce an ISO; see build/build.log"
mkdir -p "$ROOT/out"
as_root mv "$iso" "$ROOT/out/roseos-1.0-amd64.iso"
as_root chown "$(id -u):$(id -g)" "$ROOT/out/roseos-1.0-amd64.iso"
echo "$ROOT/out/roseos-1.0-amd64.iso"
```

- [ ] **Step 5: Запустить тест защит, убедиться, что проходит**

Run: `cd ~/roseos && chmod +x scripts/build-iso.sh && scripts/tests/test-build-guards.sh`
Expected: `PASS: build guards`.

- [ ] **Step 6: Написать список ожидаемых путей `scripts/tests/iso-expected-paths.txt`**

```
# iso:<path inside the ISO, glob, case-insensitive>
# fs:<absolute path inside live/filesystem.squashfs>
iso:EFI/boot/bootx64.efi
iso:EFI/boot/grubx64.efi
iso:isolinux/isolinux.bin
iso:live/filesystem.squashfs
iso:live/vmlinuz*
iso:live/initrd.img*
fs:/usr/bin/sddm
fs:/usr/bin/startplasma-wayland
fs:/usr/share/wayland-sessions/plasma.desktop
fs:/usr/bin/calamares
fs:/usr/bin/konsole
fs:/usr/lib/live/config/1190-roseos-sddm-autologin
```

- [ ] **Step 7: Написать `scripts/tests/test-iso.sh`**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

ISO=${1:?usage: test-iso.sh path/to/roseos.iso}
EXPECTED="$(dirname "$0")/iso-expected-paths.txt"
MAX_BYTES=4500000000

[ -f "$ISO" ] || fail "ISO not found: $ISO"
size=$(stat -c %s "$ISO")
[ "$size" -lt "$MAX_BYTES" ] || fail "ISO is too large: $size bytes"

MNT=$(mktemp -d)
LIST=$(mktemp)
cleanup() {
    as_root umount "$MNT" 2>/dev/null || true
    rmdir "$MNT" 2>/dev/null || true
    rm -f "$LIST"
}
trap cleanup EXIT

as_root mount -o loop,ro "$ISO" "$MNT"
unsquashfs -l "$MNT/live/filesystem.squashfs" | sed -n 's#^squashfs-root##p' > "$LIST"

while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    kind=${line%%:*}
    path=${line#*:}
    case "$kind" in
        iso) [ -n "$(find "$MNT" -ipath "$MNT/$path" -print -quit)" ] || fail "missing in ISO: $path" ;;
        fs) grep -qxF "$path" "$LIST" || fail "missing in live filesystem: $path" ;;
        *) fail "bad line in $EXPECTED: $line" ;;
    esac
done < "$EXPECTED"

echo "PASS: $ISO ($size bytes)"
```

- [ ] **Step 8: Запустить тест ISO, убедиться, что падает**

Run: `cd ~/roseos && chmod +x scripts/tests/test-iso.sh && scripts/tests/test-iso.sh out/roseos-1.0-amd64.iso`
Expected: `FAIL: ISO not found: out/roseos-1.0-amd64.iso`.

- [ ] **Step 9: Написать конфиг live-build**

`build/auto/config`:
```sh
#!/bin/sh
set -e
lb config noauto \
    --distribution trixie \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --linux-flavours amd64 \
    --binary-images iso-hybrid \
    --bootloaders "syslinux,grub-efi" \
    --uefi-secure-boot enable \
    --debian-installer none \
    --firmware-chroot true \
    --security true \
    --updates true \
    --memtest none \
    --iso-application "Rose OS" \
    --iso-publisher "Rose OS; https://github.com/enum000/roseos" \
    --iso-volume "ROSEOS_1_0" \
    --image-name roseos \
    --bootappend-live "boot=live components quiet splash username=rose hostname=roseos locales=en_US.UTF-8 keyboard-layouts=us,ru keyboard-options=grp:alt_shift_toggle" \
    "${@}"
```

`build/auto/build`:
```sh
#!/bin/sh
set -e
lb build noauto "${@}" 2>&1 | tee build.log
```

`build/auto/clean`:
```sh
#!/bin/sh
set -e
lb clean noauto "${@}"
rm -f config/binary config/bootstrap config/chroot config/common config/source
rm -f build.log
```

`build/config/package-lists/live.list.chroot`:
```
live-boot
live-config
live-config-systemd
```

`build/config/package-lists/base.list.chroot`:
```
sudo
network-manager
firmware-linux
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
firmware-sof-signed
intel-microcode
amd64-microcode
```

`build/config/package-lists/kde.list.chroot`:
```
kde-plasma-desktop
sddm
plasma-nm
plasma-pa
konsole
dolphin
kate
```

`build/config/package-lists/installer.list.chroot`:
```
calamares
calamares-settings-debian
```

`build/config/includes.chroot/usr/lib/live/config/1190-roseos-sddm-autologin`:
```sh
#!/bin/sh
# live-config runs this at boot of the live session only; the file it writes
# is not part of the squashfs, so Calamares never copies it to the target.
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-roseos-live-autologin.conf <<'EOF'
[Autologin]
User=rose
Session=plasma
EOF
```

- [ ] **Step 10: Обновить `.gitignore`**

```
.claude/
out/
build/cache/
build/chroot/
build/binary/
build/.build/
build/local/
build/*.iso
build/*.log
build/*.contents
build/*.files
build/*.packages
build/*.zsync
build/chroot.*
build/binary.*
build/config/binary
build/config/bootstrap
build/config/chroot
build/config/common
build/config/source
build/config/packages.chroot/
```

- [ ] **Step 11: Сделать исполняемыми и собрать ISO (30–60 минут в первый раз)**

Run:
```bash
cd ~/roseos
chmod +x build/auto/* build/config/includes.chroot/usr/lib/live/config/1190-roseos-sddm-autologin scripts/*.sh
scripts/build-iso.sh
```
Expected: последняя строка — `/home/<user>/roseos/out/roseos-1.0-amd64.iso`.
При ошибке: смотреть `build/build.log` с конца (`tail -50 build/build.log`) и исправлять причину, а не обходить её.

- [ ] **Step 12: Проверить, что live-build не нагенерировал неотслеживаемых файлов**

Run: `cd ~/roseos && git status --short`
Expected: только наши новые файлы. Если появились сгенерированные `lb config` файлы в `build/config/`, добавить их пути в `.gitignore` и повторить.

- [ ] **Step 13: Запустить тест ISO, убедиться, что проходит**

Run: `scripts/tests/test-iso.sh out/roseos-1.0-amd64.iso`
Expected: `PASS: out/roseos-1.0-amd64.iso (<размер> bytes)`.

- [ ] **Step 14: Написать `scripts/copy-iso-to-windows.sh` и скопировать ISO**

```sh
#!/bin/sh
set -eu
ISO=${1:?usage: copy-iso-to-windows.sh path/to/iso}
WINHOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
DEST="$WINHOME/RoseOS/iso"
mkdir -p "$DEST"
cp "$ISO" "$DEST/"
echo "$DEST/$(basename "$ISO")"
```
Run: `chmod +x scripts/copy-iso-to-windows.sh && scripts/copy-iso-to-windows.sh out/roseos-1.0-amd64.iso`
Expected: `/mnt/c/Users/dimab/RoseOS/iso/roseos-1.0-amd64.iso`.

- [ ] **Step 15: Commit**

```bash
git add .gitignore build scripts
git commit -m "Add live-build config for base KDE + Calamares ISO with build guards and ISO test"
git push
```

---

### Task 6: Загрузка и установка ISO в виртуальных машинах

**Files:** нет новых (проверка результата Task 5). Если найдётся ошибка, исправить её в файлах Task 5 и закоммитить отдельно.

**Interfaces:**
- Consumes: `C:\Users\dimab\RoseOS\iso\roseos-1.0-amd64.iso` (Task 5), `new-vm.ps1`, `vm-screenshot.ps1` (Task 3).
- Produces: VM `rose-clean` с установленной системой; подтверждение, что live и установка работают с Secure Boot и без него.

- [ ] **Step 1: Создать VM без Secure Boot и загрузить live**

Run (PowerShell):
```powershell
$p = '\\wsl.localhost\Debian\home\<user>\roseos\scripts\vm'
$iso = "$env:USERPROFILE\RoseOS\iso\roseos-1.0-amd64.iso"
powershell -ExecutionPolicy Bypass -File "$p\new-vm.ps1" -Name rose-clean -Iso $iso -Recreate
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" startvm rose-clean --type gui
powershell -ExecutionPolicy Bypass -File "$p\vm-screenshot.ps1" -Name rose-clean -Out "$env:USERPROFILE\RoseOS\shots\rose-clean-live.png" -WaitSeconds 180
```
(Перед этим: `New-Item -ItemType Directory -Force "$env:USERPROFILE\RoseOS\shots"`.)
Expected: на скриншоте рабочий стол KDE Plasma, вход выполнен автоматически (без экрана ввода пароля). Скриншот посмотреть инструментом Read.

- [ ] **Step 2: Пользователь ставит систему через Calamares**

Попросить пользователя в окне VM: запустить установщик (значок на рабочем столе или «Install Debian» в меню), язык Русский, разметка «Стереть диск», пользователь `test` / пароль `test`, перезагрузить в конце.
Expected: установка завершается сообщением об успехе.

- [ ] **Step 3: Загрузить установленную систему**

Run:
```powershell
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" controlvm rose-clean poweroff
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" storageattach rose-clean --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" startvm rose-clean --type gui
powershell -ExecutionPolicy Bypass -File "$p\vm-screenshot.ps1" -Name rose-clean -Out "$env:USERPROFILE\RoseOS\shots\rose-clean-installed.png" -WaitSeconds 90
```
Expected: экран входа SDDM с пользователем `test` (не автоматический вход: файл автовхода live не должен был скопироваться). Пользователь входит, интерфейс на русском.

- [ ] **Step 4: Проверить Secure Boot**

Run:
```powershell
powershell -ExecutionPolicy Bypass -File "$p\new-vm.ps1" -Name rose-sb -Iso $iso -SecureBoot -Recreate
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" startvm rose-sb --type gui
```
Попросить пользователя в live-сессии открыть Konsole и выполнить `mokutil --sb-state`.
Expected: live загрузился, вывод `SecureBoot enabled`.

- [ ] **Step 5: Выключить VM `rose-sb`**

Run: `& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" controlvm rose-sb poweroff`
VM `rose-clean` оставить: она понадобится в Task 10 (будет пересоздана).

---

## Этап 2. Пакеты, репозиторий и CI

### Task 7: Пакеты `roseos-archive-keyring` и `roseos-desktop`

**Files:**
- Create: `packages/roseos-archive-keyring/debian/{control,changelog,rules,install,copyright}`
- Create: `packages/roseos-archive-keyring/debian/source/format`
- Create: `packages/roseos-archive-keyring/roseos-archive-keyring.asc` (копия `~/.roseos/roseos-archive-keyring.asc`)
- Create: `packages/roseos-archive-keyring/roseos.sources`
- Create: `packages/roseos-desktop/debian/{control,changelog,rules,copyright}`
- Create: `packages/roseos-desktop/debian/source/format`
- Create: `scripts/build-packages.sh`
- Create: `scripts/tests/test-packages.sh`

**Interfaces:**
- Consumes: `scripts/lib/common.sh` (Task 5), `~/.roseos/roseos-archive-keyring.asc` (Task 4).
- Produces:
  - `scripts/build-packages.sh` собирает каждый каталог `packages/*/` в `out/debs/*.deb` (каталог очищается перед сборкой). Учитывает `ROSEOS_ROOT`.
  - `out/debs/roseos-archive-keyring_1.0.0_all.deb`: `/usr/share/keyrings/roseos-archive-keyring.asc`, `/etc/apt/sources.list.d/roseos.sources`.
  - `out/debs/roseos-desktop_1.0.0_all.deb`: метапакет, `Depends: roseos-archive-keyring`.

- [ ] **Step 1: Написать падающий тест `scripts/tests/test-packages.sh`**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
OUT="$ROOT/out/debs"

cr=$(printf '\r')
if grep -rlI "$cr" "$ROOT/packages" "$ROOT/scripts" "$ROOT/build/auto" "$ROOT/build/config" 2>/dev/null; then
    fail "files above contain Windows (CRLF) line endings"
fi

for pkg in roseos-archive-keyring roseos-desktop; do
    ls "$OUT/${pkg}"_*_all.deb >/dev/null 2>&1 || fail "missing package: $pkg"
done

lintian --fail-on error "$OUT"/*.deb || fail "lintian reported errors"

keyring_deb=$(ls "$OUT"/roseos-archive-keyring_*_all.deb)
contents=$(dpkg-deb -c "$keyring_deb")
echo "$contents" | grep -q ' ./usr/share/keyrings/roseos-archive-keyring.asc$' || fail "keyring file missing from $keyring_deb"
echo "$contents" | grep -q ' ./etc/apt/sources.list.d/roseos.sources$' || fail "APT source missing from $keyring_deb"
dpkg-deb -I "$keyring_deb" conffiles | grep -qx '/etc/apt/sources.list.d/roseos.sources' || fail "roseos.sources is not a conffile"

desktop_deb=$(ls "$OUT"/roseos-desktop_*_all.deb)
dpkg-deb -f "$desktop_deb" Depends | grep -q 'roseos-archive-keyring' || fail "roseos-desktop must depend on roseos-archive-keyring"

echo "PASS: packages"
```

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd ~/roseos && chmod +x scripts/tests/test-packages.sh && scripts/tests/test-packages.sh`
Expected: `FAIL: missing package: roseos-archive-keyring`.

- [ ] **Step 3: Создать пакет `roseos-archive-keyring`**

Run: `mkdir -p packages/roseos-archive-keyring/debian/source && cp ~/.roseos/roseos-archive-keyring.asc packages/roseos-archive-keyring/`

`packages/roseos-archive-keyring/roseos.sources`:
```
Types: deb
URIs: https://enum000.github.io/roseos-repo
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/roseos-archive-keyring.asc
```

`packages/roseos-archive-keyring/debian/control`:
```
Source: roseos-archive-keyring
Section: misc
Priority: optional
Maintainer: enum000 <enum000@users.noreply.github.com>
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.7.0
Rules-Requires-Root: no
Homepage: https://github.com/enum000/roseos

Package: roseos-archive-keyring
Architecture: all
Depends: ${misc:Depends}
Description: Rose OS archive signing key and APT source
 Installs the public OpenPGP key that signs the Rose OS APT repository
 and the APT source definition that points at that repository.
```

`packages/roseos-archive-keyring/debian/changelog`:
```
roseos-archive-keyring (1.0.0) trixie; urgency=medium

  * Initial release.

 -- enum000 <enum000@users.noreply.github.com>  Sat, 10 Oct 2026 12:00:00 +0300
```

`packages/roseos-archive-keyring/debian/rules` (отступ — **табуляция**):
```make
#!/usr/bin/make -f
%:
	dh $@
```

`packages/roseos-archive-keyring/debian/install`:
```
roseos-archive-keyring.asc usr/share/keyrings/
roseos.sources etc/apt/sources.list.d/
```

`packages/roseos-archive-keyring/debian/source/format`:
```
3.0 (native)
```

`packages/roseos-archive-keyring/debian/copyright`:
```
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: roseos-archive-keyring
Source: https://github.com/enum000/roseos

Files: *
Copyright: 2026 enum000
License: GPL-3.0-or-later
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public License
 version 3 can be found in "/usr/share/common-licenses/GPL-3".
```

- [ ] **Step 4: Создать пакет `roseos-desktop`**

Run: `mkdir -p packages/roseos-desktop/debian/source`

`packages/roseos-desktop/debian/control`:
```
Source: roseos-desktop
Section: metapackages
Priority: optional
Maintainer: enum000 <enum000@users.noreply.github.com>
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.7.0
Rules-Requires-Root: no
Homepage: https://github.com/enum000/roseos

Package: roseos-desktop
Architecture: all
Depends: ${misc:Depends}, roseos-archive-keyring
Description: Rose OS desktop metapackage
 Depends on every package that makes up the Rose OS desktop, so that
 installing or upgrading this one package brings the whole system in line.
```

`packages/roseos-desktop/debian/changelog`:
```
roseos-desktop (1.0.0) trixie; urgency=medium

  * Initial release.

 -- enum000 <enum000@users.noreply.github.com>  Sat, 10 Oct 2026 12:00:00 +0300
```

`packages/roseos-desktop/debian/rules` (табуляция):
```make
#!/usr/bin/make -f
%:
	dh $@
```

`packages/roseos-desktop/debian/source/format`:
```
3.0 (native)
```

`packages/roseos-desktop/debian/copyright`:
```
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: roseos-desktop
Source: https://github.com/enum000/roseos

Files: *
Copyright: 2026 enum000
License: GPL-3.0-or-later
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public License
 version 3 can be found in "/usr/share/common-licenses/GPL-3".
```

- [ ] **Step 5: Написать `scripts/build-packages.sh`**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
OUT="$ROOT/out/debs"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

rm -rf "$OUT"
mkdir -p "$OUT"

for dir in "$ROOT"/packages/*/; do
    name=$(basename "$dir")
    cp -a "$dir" "$WORK/$name"
    (cd "$WORK/$name" && dpkg-buildpackage -b --no-sign) || fail "build failed: $name"
done

mv "$WORK"/*.deb "$OUT"/
ls -1 "$OUT"
```

- [ ] **Step 6: Собрать и прогнать тест**

Run:
```bash
chmod +x packages/*/debian/rules scripts/build-packages.sh
scripts/build-packages.sh && scripts/tests/test-packages.sh
```
Expected: список из двух `.deb`, затем `PASS: packages`.

- [ ] **Step 7: Проверить, что тест ловит CRLF (Review Focus 5)**

Run:
```bash
printf 'x\r\n' > scripts/crlf-probe.txt
scripts/tests/test-packages.sh; echo "exit=$?"
rm scripts/crlf-probe.txt
```
Expected: печатается `scripts/crlf-probe.txt`, затем `FAIL: files above contain Windows (CRLF) line endings` и `exit=1`.

- [ ] **Step 8: Commit**

```bash
git add packages scripts/build-packages.sh scripts/tests/test-packages.sh
git commit -m "Add roseos-archive-keyring and roseos-desktop packages with build and test scripts"
git push
```

---

### Task 8: Публикация подписанного APT-репозитория

**Files:**
- Create: `scripts/publish-repo.sh`
- Create: `scripts/tests/test-repo.sh`

**Interfaces:**
- Consumes: `out/debs/*.deb` (Task 7), `scripts/lib/common.sh`.
- Produces: `scripts/publish-repo.sh <debs-dir> <repo-dir>`. Переменные (обязательные): `ROSEOS_GPG_KEY` (отпечаток), `ROSEOS_GPG_PASSPHRASE_FILE`, `ROSEOS_VERIFY_KEYRING` (ключ в формате `.asc`, против которого проверяется подпись). Результат в `<repo-dir>`: `pool/main/*.deb`, `dists/trixie/{Release,InRelease,Release.gpg}`, `dists/trixie/main/binary-amd64/Packages{,.gz}`, `roseos-archive-keyring.asc`, `.nojekyll`. Остальное содержимое `<repo-dir>` (README, `.git`) не трогается. При любой ошибке `pool/` и `dists/` в `<repo-dir>` остаются прежними.

- [ ] **Step 1: Написать падающий тест `scripts/tests/test-repo.sh`**

Тест создаёт **временный тестовый ключ** (настоящий ключ не нужен), публикует репозиторий и проверяет установку из него в чистом chroot Debian 13. Плюс три негативных случая: неверный пароль, подделанный репозиторий, подпись чужим ключом.

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

ROOT=${ROSEOS_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
PUBLISH="$ROOT/scripts/publish-repo.sh"
DEBS="$ROOT/out/debs"
WORK=$(mktemp -d)
trap 'as_root rm -rf "$WORK"' EXIT

ls "$DEBS"/*.deb >/dev/null 2>&1 || fail "no packages in $DEBS; run scripts/build-packages.sh first"

export GNUPGHOME="$WORK/gnupg"
mkdir -m 700 "$GNUPGHOME"
printf 'test-passphrase' > "$WORK/pass"
printf 'wrong-passphrase' > "$WORK/badpass"
gen_key() {
    gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$WORK/pass" \
        --quick-gen-key "$1" ed25519 sign 1d
    gpg --list-secret-keys --with-colons "$1" | awk -F: '/^fpr:/ {print $10; exit}'
}
FPR=$(gen_key "Rose OS Test Key")
OTHER_FPR=$(gen_key "Someone Else")
gpg --armor --export "$FPR" > "$WORK/test-key.asc"

# 1. Wrong passphrase: publish fails and leaves no dists/.
mkdir "$WORK/repo-bad"
if ROSEOS_GPG_KEY=$FPR ROSEOS_GPG_PASSPHRASE_FILE="$WORK/badpass" ROSEOS_VERIFY_KEYRING="$WORK/test-key.asc" \
    "$PUBLISH" "$DEBS" "$WORK/repo-bad" >/dev/null 2>&1; then
    fail "publish succeeded with a wrong passphrase"
fi
[ ! -e "$WORK/repo-bad/dists" ] || fail "publish left dists/ behind after failing"

# 2. Signing key differs from the shipped keyring: publish refuses (Review Focus 3).
mkdir "$WORK/repo-other"
if ROSEOS_GPG_KEY=$OTHER_FPR ROSEOS_GPG_PASSPHRASE_FILE="$WORK/pass" ROSEOS_VERIFY_KEYRING="$WORK/test-key.asc" \
    "$PUBLISH" "$DEBS" "$WORK/repo-other" >/dev/null 2>&1; then
    fail "publish succeeded although the signature does not match the shipped keyring"
fi
[ ! -e "$WORK/repo-other/dists" ] || fail "publish left dists/ behind after key mismatch"

# 3. Happy path.
mkdir "$WORK/repo"
echo "keep me" > "$WORK/repo/README.md"
ROSEOS_GPG_KEY=$FPR ROSEOS_GPG_PASSPHRASE_FILE="$WORK/pass" ROSEOS_VERIFY_KEYRING="$WORK/test-key.asc" \
    "$PUBLISH" "$DEBS" "$WORK/repo"
for f in dists/trixie/InRelease dists/trixie/Release.gpg dists/trixie/main/binary-amd64/Packages.gz .nojekyll roseos-archive-keyring.asc README.md; do
    [ -e "$WORK/repo/$f" ] || fail "repo is missing $f"
done

SOURCES='Types: deb\nURIs: file:/srv/repo\nSuites: trixie\nComponents: main\nSigned-By: /usr/share/keyrings/test-key.asc\n'

# 4. Install from the signed repo in a clean Debian 13 chroot.
as_root mmdebstrap --variant=apt --quiet \
    --setup-hook='mkdir -p "$1/srv/repo" "$1/usr/share/keyrings"' \
    --setup-hook="sync-in $WORK/repo /srv/repo" \
    --setup-hook="copy-in $WORK/test-key.asc /usr/share/keyrings" \
    --customize-hook="printf '$SOURCES' > \"\$1/etc/apt/sources.list.d/roseos-test.sources\"" \
    --customize-hook='chroot "$1" apt-get update' \
    --customize-hook='chroot "$1" apt-get install -y roseos-desktop' \
    --customize-hook='chroot "$1" test -f /usr/share/keyrings/roseos-archive-keyring.asc' \
    --customize-hook='chroot "$1" test -f /etc/apt/sources.list.d/roseos.sources' \
    trixie /dev/null || fail "installing roseos-desktop from the signed repo failed"

# 5. Tampered repo: apt must refuse it.
cp -a "$WORK/repo" "$WORK/repo-tampered"
sed -i 's/^Label: Rose OS$/Label: Evil/' "$WORK/repo-tampered/dists/trixie/InRelease"
as_root mmdebstrap --variant=apt --quiet \
    --setup-hook='mkdir -p "$1/srv/repo" "$1/usr/share/keyrings"' \
    --setup-hook="sync-in $WORK/repo-tampered /srv/repo" \
    --setup-hook="copy-in $WORK/test-key.asc /usr/share/keyrings" \
    --customize-hook="printf '$SOURCES' > \"\$1/etc/apt/sources.list.d/roseos-test.sources\"" \
    --customize-hook='chroot "$1" apt-get update || true' \
    --customize-hook='if chroot "$1" apt-get install -y roseos-desktop; then echo "tampered repo was accepted" >&2; exit 1; fi' \
    trixie /dev/null || fail "apt accepted a tampered repository"

echo "PASS: repo"
```

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd ~/roseos && chmod +x scripts/tests/test-repo.sh && scripts/tests/test-repo.sh`
Expected: ненулевой код выхода с сообщением `.../scripts/publish-repo.sh: not found` (случай 3, happy path). Случаи 1 и 2 «проходят» только потому, что скрипта нет; после Step 3 они проверяются по-настоящему.

- [ ] **Step 3: Написать `scripts/publish-repo.sh`**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

DEBS=${1:?usage: publish-repo.sh <debs-dir> <repo-dir>}
REPO=${2:?usage: publish-repo.sh <debs-dir> <repo-dir>}
: "${ROSEOS_GPG_KEY:?set ROSEOS_GPG_KEY to the signing key fingerprint}"
: "${ROSEOS_GPG_PASSPHRASE_FILE:?set ROSEOS_GPG_PASSPHRASE_FILE}"
: "${ROSEOS_VERIFY_KEYRING:?set ROSEOS_VERIFY_KEYRING to the .asc keyring users have}"

mkdir -p "$REPO"
DEBS=$(realpath "$DEBS")
REPO=$(realpath "$REPO")
ROSEOS_GPG_PASSPHRASE_FILE=$(realpath "$ROSEOS_GPG_PASSPHRASE_FILE")
ROSEOS_VERIFY_KEYRING=$(realpath "$ROSEOS_VERIFY_KEYRING")

SUITE=trixie
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

ls "$DEBS"/*.deb >/dev/null 2>&1 || fail "no .deb files in $DEBS"
mkdir -p "$STAGE/pool/main" "$STAGE/dists/$SUITE/main/binary-amd64"
cp "$DEBS"/*.deb "$STAGE/pool/main/"

cd "$STAGE"
apt-ftparchive packages pool/main > "dists/$SUITE/main/binary-amd64/Packages"
gzip -9kn "dists/$SUITE/main/binary-amd64/Packages"
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="Rose OS" \
    -o APT::FTPArchive::Release::Label="Rose OS" \
    -o APT::FTPArchive::Release::Suite="$SUITE" \
    -o APT::FTPArchive::Release::Codename="$SUITE" \
    -o APT::FTPArchive::Release::Architectures="amd64" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="Rose OS packages" \
    release "dists/$SUITE" > "$STAGE/Release.tmp"
mv "$STAGE/Release.tmp" "dists/$SUITE/Release"

sign() {
    gpg --batch --yes --pinentry-mode loopback \
        --passphrase-file "$ROSEOS_GPG_PASSPHRASE_FILE" \
        --local-user "$ROSEOS_GPG_KEY" --digest-algo SHA512 "$@"
}
sign --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
sign --armor --detach-sign -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"

gpg --dearmor < "$ROSEOS_VERIFY_KEYRING" > "$STAGE/verify.gpg"
gpgv --keyring "$STAGE/verify.gpg" "dists/$SUITE/InRelease" 2>/dev/null \
    || fail "InRelease is not signed by the key in $ROSEOS_VERIFY_KEYRING"
gpgv --keyring "$STAGE/verify.gpg" "dists/$SUITE/Release.gpg" "dists/$SUITE/Release" 2>/dev/null \
    || fail "Release.gpg is not signed by the key in $ROSEOS_VERIFY_KEYRING"
rm -f "$STAGE/verify.gpg"

cp "$ROSEOS_VERIFY_KEYRING" roseos-archive-keyring.asc
touch .nojekyll

rm -rf "$REPO/pool" "$REPO/dists"
mv pool dists "$REPO/"
cp roseos-archive-keyring.asc .nojekyll "$REPO/"
echo "Published $(ls "$REPO/pool/main" | wc -l) packages to $REPO"
```

- [ ] **Step 4: Прогнать тест, убедиться, что проходит (3–5 минут: два chroot)**

Run: `chmod +x scripts/publish-repo.sh && scripts/build-packages.sh >/dev/null && scripts/tests/test-repo.sh`
Expected: `Published 2 packages to ...`, затем `PASS: repo`.

- [ ] **Step 5: Commit**

```bash
git add scripts/publish-repo.sh scripts/tests/test-repo.sh
git commit -m "Add signed APT repository publishing with end-to-end install test"
git push
```

---

### Task 9: Репозиторий пакетов на GitHub Pages и CI

**Files:**
- Create: `scripts/check-version-bumps.sh`
- Create: `scripts/tests/test-version-bumps.sh`
- Create: `scripts/ci-publish.sh`
- Create: `.github/workflows/packages.yml`

**Interfaces:**
- Consumes: `build-packages.sh`, `test-packages.sh` (Task 7), `publish-repo.sh`, `test-repo.sh` (Task 8), ключ из Task 4.
- Produces:
  - `scripts/check-version-bumps.sh <base-ref>`: выход 1 и строка `ERROR: packages/<name> changed but debian/changelog was not updated` для каждого такого пакета; выход 0, если всё в порядке. Работает в текущем git-репозитории.
  - GitHub: репозиторий `enum000/roseos-repo` с Pages из ветки `main` по адресу `https://enum000.github.io/roseos-repo`; секреты в `enum000/roseos`: `ROSEOS_GPG_PRIVATE_KEY`, `ROSEOS_GPG_PASSPHRASE`, `ROSEOS_REPO_DEPLOY_KEY`.

- [ ] **Step 1: Написать падающий тест `scripts/tests/test-version-bumps.sh` (Review Focus 4)**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/../lib/common.sh"

CHECK="$(cd "$(dirname "$0")/.." && pwd)/check-version-bumps.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
g() { git -c user.name=test -c user.email=test@example.invalid "$@"; }

mkdir -p packages/foo/debian packages/bar/debian
echo "foo (1.0.0) trixie; urgency=medium" > packages/foo/debian/changelog
echo "a" > packages/foo/data
echo "bar (1.0.0) trixie; urgency=medium" > packages/bar/debian/changelog
g add -A && g commit -qm base
BASE=$(git rev-parse HEAD)

echo "b" > packages/foo/data
g commit -qam "change foo without bump"
if "$CHECK" "$BASE" > "$WORK/out" 2>&1; then fail "unbumped change was accepted"; fi
grep -q 'packages/foo changed' "$WORK/out" || fail "error does not name packages/foo"
grep -q 'packages/bar' "$WORK/out" && fail "untouched packages/bar was reported"

echo "foo (1.0.1) trixie; urgency=medium" > packages/foo/debian/changelog
g commit -qam "bump foo"
"$CHECK" "$BASE" >/dev/null || fail "bumped change was rejected"

g rm -rq packages/bar && g commit -qm "remove bar"
"$CHECK" "$BASE" >/dev/null || fail "removed package was reported"

echo "PASS: version bumps"
```

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd ~/roseos && chmod +x scripts/tests/test-version-bumps.sh && scripts/tests/test-version-bumps.sh`
Expected: `FAIL: error does not name packages/foo` (скрипта нет, вывод — `not found`).

- [ ] **Step 3: Написать `scripts/check-version-bumps.sh`**

```sh
#!/bin/sh
set -eu
BASE=${1:?usage: check-version-bumps.sh <base-git-ref>}

bad=0
for name in $(git diff --name-only "$BASE" HEAD -- packages/ | cut -d/ -f2 | sort -u); do
    [ -d "packages/$name" ] || continue
    if [ -z "$(git diff --name-only "$BASE" HEAD -- "packages/$name/debian/changelog")" ]; then
        echo "ERROR: packages/$name changed but debian/changelog was not updated (bump the version)"
        bad=1
    fi
done
exit "$bad"
```

- [ ] **Step 4: Запустить тест, убедиться, что проходит**

Run: `chmod +x scripts/check-version-bumps.sh && scripts/tests/test-version-bumps.sh`
Expected: `PASS: version bumps`.

- [ ] **Step 5: Написать `scripts/ci-publish.sh`**

```sh
#!/bin/sh
set -eu
. "$(dirname "$0")/lib/common.sh"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${ROSEOS_GPG_PRIVATE_KEY:?}" "${ROSEOS_GPG_PASSPHRASE:?}" "${ROSEOS_REPO_DEPLOY_KEY:?}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export GNUPGHOME="$WORK/gnupg"
mkdir -m 700 "$GNUPGHOME"
printf '%s' "$ROSEOS_GPG_PASSPHRASE" > "$WORK/pass"
printf '%s\n' "$ROSEOS_GPG_PRIVATE_KEY" | gpg --batch --pinentry-mode loopback --passphrase-file "$WORK/pass" --import
FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ {print $10; exit}')

mkdir -p "$HOME/.ssh"
printf '%s\n' "$ROSEOS_REPO_DEPLOY_KEY" > "$HOME/.ssh/id_ed25519"
chmod 600 "$HOME/.ssh/id_ed25519"
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

git clone --depth 1 git@github.com:enum000/roseos-repo.git "$WORK/site"
ROSEOS_GPG_KEY=$FPR \
ROSEOS_GPG_PASSPHRASE_FILE="$WORK/pass" \
ROSEOS_VERIFY_KEYRING="$ROOT/packages/roseos-archive-keyring/roseos-archive-keyring.asc" \
    "$ROOT/scripts/publish-repo.sh" "$ROOT/out/debs" "$WORK/site"

cd "$WORK/site"
git add -A
if git diff --cached --quiet; then
    echo "Nothing to publish"
    exit 0
fi
git -c user.name="Rose OS CI" -c user.email="enum000@users.noreply.github.com" \
    commit -m "Publish packages from enum000/roseos@${GITHUB_SHA:-local}"
git push origin HEAD:main
```

- [ ] **Step 6: Написать `.github/workflows/packages.yml`**

```yaml
name: packages

on:
  push:
    branches: [main]
    paths:
      - 'packages/**'
      - 'scripts/**'
      - '.github/workflows/packages.yml'
  pull_request:
    paths:
      - 'packages/**'
      - 'scripts/**'
      - '.github/workflows/packages.yml'
  workflow_dispatch:

concurrency:
  group: packages-${{ github.ref }}
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: debian:trixie
      options: --privileged
    steps:
      - name: Install tools
        run: |
          apt-get update
          DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            git ca-certificates debhelper dpkg-dev lintian apt-utils gnupg gpgv \
            mmdebstrap openssh-client rsync
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Trust workspace
        run: git config --global --add safe.directory "$GITHUB_WORKSPACE"
      - name: Check version bumps
        if: github.event_name == 'push' && github.event.before != '0000000000000000000000000000000000000000'
        run: scripts/check-version-bumps.sh "${{ github.event.before }}"
      - name: Unit tests
        run: scripts/tests/test-version-bumps.sh
      - name: Build packages
        run: scripts/build-packages.sh
      - name: Test packages
        run: scripts/tests/test-packages.sh
      - name: Test repository
        run: scripts/tests/test-repo.sh
      - name: Publish
        if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
        env:
          ROSEOS_GPG_PRIVATE_KEY: ${{ secrets.ROSEOS_GPG_PRIVATE_KEY }}
          ROSEOS_GPG_PASSPHRASE: ${{ secrets.ROSEOS_GPG_PASSPHRASE }}
          ROSEOS_REPO_DEPLOY_KEY: ${{ secrets.ROSEOS_REPO_DEPLOY_KEY }}
        run: scripts/ci-publish.sh
```

- [ ] **Step 7: ⚠ Спросить пользователя и создать `roseos-repo` с GitHub Pages**

Спросить: «Создаю публичный репозиторий github.com/enum000/roseos-repo и включаю для него GitHub Pages. Ок?» После «да»:
```bash
gh repo create enum000/roseos-repo --public --description "Rose OS APT repository" --add-readme
gh api -X POST repos/enum000/roseos-repo/pages -f "source[branch]=main" -f "source[path]=/"
```
Expected: репозиторий создан; ответ API содержит `"html_url":"https://enum000.github.io/roseos-repo/"`.

- [ ] **Step 8: ⚠ Спросить пользователя и добавить ключ развёртывания и секреты**

Спросить: «Добавляю в enum000/roseos три секрета (ключ подписи, его пароль, ключ доступа к roseos-repo) и в roseos-repo — deploy key с правом записи. Ок?» После «да»:
```bash
ssh-keygen -t ed25519 -N '' -C "roseos CI deploy" -f ~/.roseos/deploy_key
gh repo deploy-key add ~/.roseos/deploy_key.pub --repo enum000/roseos-repo --title "roseos CI" --allow-write
gh secret set ROSEOS_REPO_DEPLOY_KEY --repo enum000/roseos < ~/.roseos/deploy_key
gh secret set ROSEOS_GPG_PASSPHRASE --repo enum000/roseos < ~/.roseos/signing-passphrase
gpg --batch --pinentry-mode loopback --passphrase-file ~/.roseos/signing-passphrase --armor --export-secret-keys "$(cat ~/.roseos/signing-key-fpr)" | gh secret set ROSEOS_GPG_PRIVATE_KEY --repo enum000/roseos
gh secret list --repo enum000/roseos
```
Expected: в списке три секрета.

- [ ] **Step 9: Commit и запуск CI**

```bash
chmod +x scripts/ci-publish.sh
git add scripts/check-version-bumps.sh scripts/tests/test-version-bumps.sh scripts/ci-publish.sh .github/workflows/packages.yml
git commit -m "Add packages CI with version-bump check and publishing to GitHub Pages"
git push
gh run watch --repo enum000/roseos --exit-status "$(gh run list --repo enum000/roseos --workflow packages --limit 1 --json databaseId -q '.[0].databaseId')"
```
Expected: все шаги зелёные, включая `Publish`.

- [ ] **Step 10: Проверить, что репозиторий доступен по HTTPS и подпись верна**

Run (через 1–2 минуты после публикации, пока Pages обновится):
```bash
curl -fsS https://enum000.github.io/roseos-repo/dists/trixie/InRelease -o /tmp/InRelease
gpg --dearmor < ~/roseos/packages/roseos-archive-keyring/roseos-archive-keyring.asc > /tmp/rose.gpg
gpgv --keyring /tmp/rose.gpg /tmp/InRelease && echo SIGNATURE-OK
curl -fsS https://enum000.github.io/roseos-repo/dists/trixie/main/binary-amd64/Packages | grep '^Package:'
```
Expected: `SIGNATURE-OK`; строки `Package: roseos-archive-keyring` и `Package: roseos-desktop`.

---

### Task 10: Пакеты Rose OS в ISO и обновления в установленной системе

**Files:**
- Modify: `scripts/build-iso.sh` (копирование `out/debs` в `build/config/packages.chroot/`)
- Create: `build/config/package-lists/rose.list.chroot`
- Modify: `scripts/tests/iso-expected-paths.txt`

**Interfaces:**
- Consumes: `out/debs/*.deb` (Task 7), репозиторий на Pages (Task 9), VM-скрипты (Task 3).
- Produces: ISO, где установлен `roseos-desktop`; установленная система с источником APT Rose OS.

- [ ] **Step 1: Добавить ожидания в `scripts/tests/iso-expected-paths.txt` (тест сначала)**

Дописать в конец:
```
fs:/usr/share/keyrings/roseos-archive-keyring.asc
fs:/etc/apt/sources.list.d/roseos.sources
```

- [ ] **Step 2: Проверить, что тест падает на старом ISO**

Run: `cd ~/roseos && scripts/tests/test-iso.sh out/roseos-1.0-amd64.iso`
Expected: `FAIL: missing in live filesystem: /usr/share/keyrings/roseos-archive-keyring.asc`.

- [ ] **Step 3: Создать `build/config/package-lists/rose.list.chroot`**

```
roseos-desktop
```

- [ ] **Step 4: Изменить `scripts/build-iso.sh`: класть свежие пакеты в ISO**

Заменить строку `cd "$ROOT/build"` на:
```sh
ls "$ROOT"/out/debs/*.deb >/dev/null 2>&1 || fail "no packages in out/debs; run scripts/build-packages.sh first"

cd "$ROOT/build"
mkdir -p config/packages.chroot
rm -f config/packages.chroot/*.deb
cp "$ROOT"/out/debs/*.deb config/packages.chroot/
```

- [ ] **Step 5: Проверить, что защиты по-прежнему работают**

Run: `scripts/tests/test-build-guards.sh`
Expected: `PASS: build guards` (проверки `/mnt` и места стоят раньше новой проверки пакетов).

- [ ] **Step 6: Пересобрать пакеты и ISO, прогнать тест**

Run:
```bash
scripts/build-packages.sh && scripts/build-iso.sh && scripts/tests/test-iso.sh out/roseos-1.0-amd64.iso
scripts/copy-iso-to-windows.sh out/roseos-1.0-amd64.iso
```
Expected: `PASS: out/roseos-1.0-amd64.iso (...)` и путь копии в `/mnt/c/Users/dimab/RoseOS/iso/`.

- [ ] **Step 7: Установить в VM и проверить обновления из репозитория Rose OS**

Run (PowerShell):
```powershell
$p = '\\wsl.localhost\Debian\home\<user>\roseos\scripts\vm'
$iso = "$env:USERPROFILE\RoseOS\iso\roseos-1.0-amd64.iso"
powershell -ExecutionPolicy Bypass -File "$p\new-vm.ps1" -Name rose-clean -Iso $iso -Recreate
& "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe" startvm rose-clean --type gui
```
Пользователь ставит систему, как в Task 6 Step 2, отключает ISO (Task 6 Step 3), входит и выполняет в Konsole:
```bash
sudo apt update
apt policy roseos-desktop
```
Expected: в выводе `apt update` есть строка `https://enum000.github.io/roseos-repo trixie InRelease` без ошибок и предупреждений о подписи; `apt policy` показывает `Installed: 1.0.0` и источник `https://enum000.github.io/roseos-repo trixie/main amd64`.

- [ ] **Step 8: Commit**

```bash
git add scripts/build-iso.sh scripts/tests/iso-expected-paths.txt build/config/package-lists/rose.list.chroot
git commit -m "Ship Rose OS packages in the ISO"
git push
```

---

## После этапов 0–2

Когда все задачи выполнены, получаем: ISO (KDE, Calamares, пакеты Rose OS), который ставится в VM с Secure Boot и без, и подписанный репозиторий, который CI обновляет при каждом изменении пакетов. Следующий план — этап 3 (брендинг: SVG-логотип, обои, os-release, GRUB, Plymouth, SDDM, Global Theme «Rose»).
