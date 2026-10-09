#!/bin/bash
# Обезличено для публикации: личные пути, имя пользователя и адреса заменены.
# Проверьте значения ниже перед запуском.

# Доводка №2: доставить систему инициализации (systemd-sysv → /sbin/init) и службы сессий.
# Причина: база ставилась вариантом minbase (только «required»), а systemd-sysv и libpam-systemd
# имеют приоритет «important» и в minbase не попадают → загрузка обрывалась на
# "Target filesystem doesn't have requested /sbin/init".
set -euo pipefail
MNT=/mnt/target
DISK=/dev/sdX
export DEBIAN_FRONTEND=noninteractive
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

echo "### доводка init-системы: $(date '+%H:%M:%S')"
[ -b "$DISK" ] || { echo "НЕТ диска $DISK"; exit 1; }
mountpoint -q "$MNT" && { echo "ОТКАЗ: $MNT уже смонтирован (сделать umount -R)"; exit 1; }

mount "${DISK}2" "$MNT"
cp /usr/bin/qemu-x86_64-static "$MNT/usr/bin/" 2>/dev/null || true
for d in dev dev/pts proc sys; do mount --bind "/$d" "$MNT/$d"; done

# Убираем глобальный запрет recommends: для рабочего стола он вреден (шрифты, доп. модули).
sed -i '/^APT::Install-Recommends/d' "$MNT/etc/apt/apt.conf.d/99setup" || true

echo "=== ставлю систему инициализации и службы сессий ==="
chroot "$MNT" apt-get update -q
chroot "$MNT" apt-get install -y -q --no-install-recommends \
  init systemd-sysv libpam-systemd less psmisc systemd-timesyncd

echo "=== проверка: есть ли теперь /sbin/init ==="
ls -l "$MNT/sbin/init" | sed 's/^/  /'
readlink -f "$MNT/sbin/init" | sed 's/^/  ведёт на: /'
ls -l "$MNT/lib/systemd/systemd" | sed 's/^/  /'
chroot "$MNT" dpkg -l systemd systemd-sysv libpam-systemd 2>/dev/null | grep -E "^ii" | awk '{print "  "$2" "$3}'

echo "=== идентификатор машины ==="
chroot "$MNT" systemd-machine-id-setup 2>&1 | sed 's/^/  /'
ls -l "$MNT/etc/machine-id" | sed 's/^/  /'

echo "=== включаю службы (вывод не скрываю) ==="
chroot "$MNT" systemctl enable ssh NetworkManager
chroot "$MNT" systemctl set-default multi-user.target
chroot "$MNT" systemctl is-enabled ssh NetworkManager | sed 's/^/  /'

echo "=== что лежит в wants ==="
ls "$MNT/etc/systemd/system/multi-user.target.wants/" 2>/dev/null | tr '\n' ' ' | sed 's/^/  /'
echo
echo "=== автологин на первой консоли ==="
cat "$MNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" 2>/dev/null | tail -2 | sed 's/^/  /'

echo "=== размонтирую ==="
for d in dev/pts dev proc sys; do umount -l "$MNT/$d" 2>/dev/null || true; done
sync; umount "$MNT" 2>/dev/null || true; sync
echo "### готово: $(date '+%H:%M:%S') — диск можно ставить в ноутбук"
