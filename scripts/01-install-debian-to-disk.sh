#!/bin/bash
# Обезличено для публикации: личные пути, имя пользователя и адреса заменены.
# Проверьте значения ниже перед запуском.

# Установка Debian 13 (trixie) amd64 на внешний NVMe /dev/sdX — под ноутбук IdeaPad 330-15ARR.
# Система собирается на Джарвисе (ARM) через debootstrap + qemu-user-static.
# Рабочий стол НЕ ставим здесь: он будет поставлен нативно по SSH на первой загрузке ноутбука.
set -euo pipefail

LOG=/tmp/install-ideapad.log
MNT=/mnt/target
DISK=/dev/sdX
HOST="${TARGET_HOST:-debian-laptop}"
USERNAME="${TARGET_USER:-user}"
KEYFILE=$HOME/.ssh/id_ed25519.pub

exec > >(tee -a "$LOG") 2>&1
# Debian-зеркала доступны напрямую; локальный прокси рвал часть загрузок (было: "Couldn't download package dash/grep"),
# поэтому для этой установки прокси-переменные снимаем.
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
echo "### старт: $(date '+%Y-%m-%d %H:%M:%S') (прокси для загрузки отключён, зеркала напрямую)"

step() { echo; echo "=== $* ==="; }

step "0. Проверки безопасности"
[ -b "$DISK" ] || { echo "НЕТ диска $DISK"; exit 1; }
SIZE=$(blockdev --getsize64 "$DISK")
echo "  размер: $SIZE байт ($((SIZE/1000/1000/1000)) ГБ)"
TRAN=$(lsblk -ndo TRAN "$DISK")
echo "  шина: $TRAN"
[ "$TRAN" = "usb" ] || { echo "ОТКАЗ: диск не на USB — это может быть мой загрузочный, останавливаюсь"; exit 1; }
[ "$SIZE" -gt 200000000000 ] && [ "$SIZE" -lt 300000000000 ] || { echo "ОТКАЗ: размер не похож на 256 ГБ"; exit 1; }
mountpoint -q "$MNT" && { echo "ОТКАЗ: $MNT уже смонтирован"; exit 1; }
findmnt -no SOURCE / | grep -q nvme && echo "  мой корень на nvme — внешний диск не задет"

step "1. Ставлю инструменты на Джарвис"
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q debootstrap qemu-user-static binfmt-support dosfstools gdisk parted >/dev/null
echo "  готово: $(debootstrap --version | head -1)"

step "2. Разметка диска (GPT: EFI 512 МБ + ext4 на остальное)"
sgdisk -Z "$DISK" >/dev/null
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" -n 2:0:0 -t 2:8300 -c 2:"ROOT" "$DISK" >/dev/null
partprobe "$DISK" || true; sleep 2
mkfs.vfat -F32 -n EFI "${DISK}1" >/dev/null
mkfs.ext4 -q -L ROOT -F "${DISK}2"
echo "  разделы: $(lsblk -no NAME,SIZE,FSTYPE "$DISK" | tr '\n' ' ')"

step "3. Монтирую и ставлю базу Debian 13 amd64"
mkdir -p "$MNT"
mount "${DISK}2" "$MNT"
mkdir -p "$MNT/boot/efi"
mount "${DISK}1" "$MNT/boot/efi"
for attempt in 1 2 3; do
  echo "  попытка загрузки базы: $attempt"
  if debootstrap --arch=amd64 --variant=minbase --foreign trixie "$MNT" http://deb.debian.org/debian; then
    break
  fi
  echo "  загрузка прервалась, повтор через 15 с"
  sleep 15
  [ "$attempt" = "3" ] && { echo "ОТКАЗ: базу скачать не удалось"; exit 1; }
done
cp /usr/bin/qemu-x86_64-static "$MNT/usr/bin/"
chroot "$MNT" /debootstrap/debootstrap --second-stage
echo "  база распакована"

step "4. Настройка системы в chroot"
for d in dev dev/pts proc sys run; do mount --bind "/$d" "$MNT/$d"; done
ROOT_UUID=$(blkid -s UUID -o value "${DISK}2")
EFI_UUID=$(blkid -s UUID -o value "${DISK}1")
cat > "$MNT/etc/fstab" <<EOF
UUID=$ROOT_UUID  /          ext4  defaults,noatime  0 1
UUID=$EFI_UUID   /boot/efi  vfat  umask=0077        0 1
EOF
echo "  fstab: root=$ROOT_UUID efi=$EFI_UUID"

echo "$HOST" > "$MNT/etc/hostname"
cat > "$MNT/etc/hosts" <<EOF
127.0.0.1  localhost
127.0.1.1  $HOST
::1        localhost ip6-localhost ip6-loopback
EOF

cat > "$MNT/etc/apt/sources.list" <<'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free-firmware
EOF

cat > "$MNT/etc/apt/apt.conf.d/99norecommends" <<'EOF'
APT::Install-Recommends "false";
Acquire::http::Proxy "false";
Acquire::https::Proxy "false";
Acquire::Retries "10";
EOF

chroot "$MNT" apt-get update -q
chroot "$MNT" apt-get install -y -q --no-install-recommends \
  linux-image-amd64 amd64-microcode initramfs-tools \
  firmware-amd-graphics firmware-realtek firmware-misc-nonfree \
  grub-efi-amd64 grub-efi-amd64-signed shim-signed \
  network-manager openssh-server sudo locales tzdata console-setup \
  kmod pciutils usbutils rfkill rfkill bash-completion nano htop rsync \
  ca-certificates apt-utils wpasupplicant
echo "  пакеты установлены"

step "5. Язык, время, клавиатура"
chroot "$MNT" bash -c "sed -i 's/^# *ru_RU.UTF-8/ru_RU.UTF-8/; s/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen"
echo 'LANG=ru_RU.UTF-8' > "$MNT/etc/default/locale"
ln -sf /usr/share/zoneinfo/Europe/Moscow "$MNT/etc/localtime"
cat > "$MNT/etc/default/keyboard" <<'EOF'
XKBMODEL="pc105"
XKBLAYOUT="ru,us"
XKBVARIANT=","
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

step "6. Пользователь $USERNAME и доступ по ключу"
chroot "$MNT" useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev "$USERNAME"
mkdir -p "$MNT/home/$USERNAME/.ssh"
if [ -f "$KEYFILE" ]; then
  cp "$KEYFILE" "$MNT/home/$USERNAME/.ssh/authorized_keys"
  chmod 700 "$MNT/home/$USERNAME/.ssh"; chmod 600 "$MNT/home/$USERNAME/.ssh/authorized_keys"
  chroot "$MNT" chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
  echo "  ключ Джарвиса добавлен"
fi
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$MNT/etc/sudoers.d/90-$USERNAME"
chmod 440 "$MNT/etc/sudoers.d/90-$USERNAME"
# автологин на tty1, чтобы на первой загрузке Артём сразу попал в систему и задал себе пароль
mkdir -p "$MNT/etc/systemd/system/getty@tty1.service.d"
cat > "$MNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear %I \$TERM
EOF

step "7. Параметры ядра (Raven Ridge) и загрузчик на внешний диск"
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet idle=nomwait amdgpu.dcdebugmask=0x10"/' "$MNT/etc/default/grub"
grep -q '^GRUB_DISABLE_OS_PROBER' "$MNT/etc/default/grub" || echo 'GRUB_DISABLE_OS_PROBER=true' >> "$MNT/etc/default/grub"
chroot "$MNT" update-initramfs -u -k all
chroot "$MNT" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --removable --no-nvram
chroot "$MNT" update-grub
# страховка: если съёмный путь не создался — копируем сами
if [ ! -f "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" ]; then
  mkdir -p "$MNT/boot/efi/EFI/BOOT"
  cp "$MNT/boot/efi/EFI/debian/shimx64.efi" "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI" 2>/dev/null || true
  cp "$MNT/boot/efi/EFI/debian/grubx64.efi" "$MNT/boot/efi/EFI/BOOT/grubx64.efi" 2>/dev/null || true
  cp "$MNT/boot/efi/EFI/debian/grub.cfg"   "$MNT/boot/efi/EFI/BOOT/grub.cfg"   2>/dev/null || true
  echo "  съёмный путь создан вручную"
fi

step "8. Сервисы"
chroot "$MNT" systemctl enable ssh NetworkManager >/dev/null 2>&1 || true
chroot "$MNT" systemctl set-default multi-user.target >/dev/null 2>&1 || true

step "9. Проверка результата"
echo "  ядро:      $(ls "$MNT/boot" | grep -E '^vmlinuz' | head -1)"
echo "  initrd:    $(ls "$MNT/boot" | grep -E '^initrd' | head -1)"
echo "  ESP:       $(find "$MNT/boot/efi/EFI" -maxdepth 2 -type f | sed "s|$MNT||" | tr '\n' ' ')"
echo "  grub.cfg:  $([ -s "$MNT/boot/grub/grub.cfg" ] && echo есть || echo НЕТ)"
echo "  раздел /:  $(grep -c "$ROOT_UUID" "$MNT/boot/grub/grub.cfg" || true) ссылок в grub.cfg"

step "10. Размонтирование"
for d in dev/pts dev proc sys run; do umount -l "$MNT/$d" 2>/dev/null || true; done
umount "$MNT/boot/efi" 2>/dev/null || true
sync
umount "$MNT" 2>/dev/null || true
sync
echo
echo "### ГОТОВО: $(date '+%Y-%m-%d %H:%M:%S')"
echo "### Диск /dev/sdX можно отключать от Джарвиса и ставить в ноутбук"
