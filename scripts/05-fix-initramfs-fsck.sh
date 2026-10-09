#!/bin/bash
# Обезличено для публикации: личные пути, имя пользователя и адреса заменены.
# Проверьте значения ниже перед запуском.

# Доводка системы на внешнем диске: ставим e2fsprogs (чтобы fsck попал в initramfs), пересобираем initramfs.
set -euo pipefail
MNT=/mnt/target
export DEBIAN_FRONTEND=noninteractive

echo "### доводка: $(date '+%H:%M:%S')"
cp /usr/bin/qemu-x86_64-static "$MNT/usr/bin/" 2>/dev/null || true
for d in dev dev/pts proc sys; do mount --bind "/$d" "$MNT/$d"; done
umount "$MNT/boot/efi" 2>/dev/null || true   # не нужен для установки пакетов

echo "=== ставлю e2fsprogs ==="
chroot "$MNT" apt-get install -y -q --no-install-recommends e2fsprogs

echo "=== пересобираю initramfs ==="
chroot "$MNT" update-initramfs -u -k all

echo "=== проверяю, что fsck теперь внутри ==="
chroot "$MNT" lsinitramfs /boot/initrd.img-6.12.111+deb13-amd64 2>/dev/null | grep -E "fsck|e2fsck" | sort -u | sed 's/^/  /' || echo "  не найдено"

echo "=== прошивки на месте? ==="
ls "$MNT/lib/firmware/rtw88/rtw8821c_fw.bin" 2>/dev/null | sed 's/^/  /' || echo "  нет прошивки Wi-Fi RTL8821C"
ls "$MNT/lib/firmware/amdgpu/" 2>/dev/null | grep -c . | sed 's/^/  файлов прошивок AMD: /'

echo "=== размонтирую ==="
for d in dev/pts dev proc sys; do umount -l "$MNT/$d" 2>/dev/null || true; done
sync; umount "$MNT" 2>/dev/null || true; sync
echo "### готово: $(date '+%H:%M:%S')"
