#!/bin/bash
# Приоритет загрузки с внешнего диска: прописывает запись в NVRAM ноутбука,
# чтобы не нажимать F12 каждый раз. Нужен, когда Linux живёт целиком на внешнем USB/NVMe.
# Запускать НА НОУТБУКЕ от root. Read-only просмотр работает и без root: efibootmgr
set -euo pipefail

DISK="${DISK:-/dev/sdX}"     # весь внешний диск (не раздел)
PART="${PART:-1}"            # номер раздела EFI на нём
LABEL="${LABEL:-Debian external NVMe}"

command -v efibootmgr >/dev/null || apt-get install -y -q efibootmgr

echo "=== до ==="
efibootmgr -v | head -8 | sed 's/^/  /'

efibootmgr -c -d "$DISK" -p "$PART" -L "$LABEL" -l '\EFI\BOOT\BOOTX64.EFI' >/dev/null 2>&1 || true
sleep 1
NEW="$(efibootmgr | awk -v l="$LABEL" '$0 ~ l {print substr($1,5,4); exit}')"
[ -n "$NEW" ] || { echo "не удалось создать запись — проверьте путь \\EFI\\BOOT\\BOOTX64.EFI на разделе EFI"; exit 1; }

OLD="$(efibootmgr | awk '/^BootOrder:/{print $2}')"
ORDER="$NEW"
for e in $(echo "$OLD" | tr ',' ' '); do [ "$e" = "$NEW" ] && continue; ORDER="$ORDER,$e"; done
efibootmgr -o "$ORDER" >/dev/null

echo
echo "=== после (наша запись должна быть первой) ==="
efibootmgr | grep -E '^BootOrder|^Boot[0-9A-F]{4}' | cut -c1-70 | sed 's/^/  /'
echo
echo "Диск подключён — грузится Linux; диск отключён — грузится Windows (его записи остались следом)."
