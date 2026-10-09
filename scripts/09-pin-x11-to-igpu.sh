#!/bin/bash
# Привязка X11 к встроенной видеокарте. Нужна на ноутбуках с двумя GPU (например
# Vega + дискретная Radeon): X-сервер может занять дискретную карту, к которой не подключён
# экран, и тогда X11-сессии дают чёрный экран, а в логе видно "flip queue failed".
# Запускать НА НОУТБУКЕ от root.
set -euo pipefail

echo "=== какой GPU ведёт встроенный экран ==="
found=""
for c in /sys/class/drm/card[0-9]*; do
    [ -e "$c/status" ] || continue
    state="$(cat "$c/status")"
    printf "  %-24s %s\n" "$(basename "$c")" "$state"
    case "$(basename "$c")" in
        *-eDP-*|*-LVDS-*) [ "$state" = "connected" ] && found="$(basename "$c" | grep -oE 'card[0-9]+')" ;;
    esac
done
[ -n "$found" ] || { echo "  не удалось определить карту с внутренним экраном — задайте BusID вручную"; exit 1; }

BUS="$(cat /sys/class/drm/${found}/device/uevent 2>/dev/null | grep -m1 PCI_SLOT_NAME | cut -d= -f2)"
echo "  встроенный экран на $found, PCI-адрес $BUS"

PCI_BUS="$(echo "$BUS" | cut -d: -f2 | sed 's/^0*//')"
PCI_DEV="$(echo "$BUS" | cut -d: -f3 | sed 's/^0*//')"
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-igpu.conf <<EOF
# Внутренний экран подключён к этой видеокарте. Без привязки X-сервер может занять
# дискретную карту без подключённого экрана — получится чёрный экран.
Section "Device"
    Identifier "Internal GPU"
    Driver     "amdgpu"
    BusID      "PCI:${PCI_BUS}:${PCI_DEV}:0"
    Option     "TearFree" "true"
EndSection
EOF
echo "  записано: /etc/X11/xorg.conf.d/20-igpu.conf (BusID PCI:${PCI_BUS}:${PCI_DEV}:0)"
echo "  применяется после перезапуска экрана входа: systemctl restart sddm"
