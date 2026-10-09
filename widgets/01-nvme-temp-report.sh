#!/bin/bash
# Температура и служебные данные NVMe за USB-мостом.
# smartctl требует root, поэтому результат кладём в файлы, доступные пользователю.
set -u
OUT=/run/nvme-temp
SMART=/run/nvme-smart
write_f() { printf '%s\n' "$2" > "$1.tmp" && mv "$1.tmp" "$1" && chmod 644 "$1"; }

DEV=""
for d in /dev/sd? /dev/nvme?n?; do
    [ -b "$d" ] || continue
    case "$d" in
        /dev/sd*) [ "$(lsblk -ndo TRAN "$d" 2>/dev/null | tr -d ' ')" = usb ] || continue ;;
    esac
    DEV="$d"; break
done
[ -n "$DEV" ] || { echo "USB-накопитель не найден"; exit 0; }

RAW=$(smartctl -A -d sntasmedia "$DEV" 2>/dev/null)
[ -n "$RAW" ] || RAW=$(smartctl -A -d sat "$DEV" 2>/dev/null)
[ -n "$RAW" ] || RAW=$(smartctl -A "$DEV" 2>/dev/null)

T=$(printf '%s\n' "$RAW" | awk -F: '/^Temperature:/ { gsub(/[^0-9]/, "", $2); print $2; exit }')
[ -n "$T" ] && write_f "$OUT" "$T"

write_f "$SMART" "$(printf '%s\n' "$RAW" | grep -E '^(Model Number|Serial Number|Firmware|Critical Warning|Temperature|Available Spare|Available Spare Threshold|Percentage Used|Data Units Read|Data Units Written|Power On Hours|Unsafe Shutdowns|Media and Data Integrity Errors|Warning  Comp|Warning Temperature)' | sed 's/  */ /g')"