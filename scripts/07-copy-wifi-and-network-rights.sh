#!/bin/bash
# Перенос профилей Wi-Fi с машины-сборщика на целевой диск + права на управление сетью.
# Запускать НА МАШИНЕ-СБОРЩИКЕ (той, где диск смонтирован), от root.
#
# Смысл: пользователь на новом ноутбуке не должен набирать пароль Wi-Fi руками.
# Профили NetworkManager копируются ФАЙЛАМИ — пароли нигде не печатаются и не логируются.
set -euo pipefail

MNT="${MNT:-/mnt/target}"          # куда смонтирован корень целевой системы
TARGET_USER="${TARGET_USER:-user}" # имя пользователя в целевой системе
DISK="${DISK:-/dev/sdX2}"          # корневой раздел целевого диска

[ -d "$MNT/etc" ] || { echo "НЕТ: $MNT не похож на корень системы"; exit 1; }
mountpoint -q "$MNT" || mount "$DISK" "$MNT"

TARGET_DIR="$MNT/etc/NetworkManager/system-connections"
mkdir -p "$TARGET_DIR"

echo "=== 1. переношу профили Wi-Fi (пароли не выводятся) ==="
count=0
for src in /run/NetworkManager/system-connections/*.nmconnection \
           /etc/NetworkManager/system-connections/*.nmconnection; do
    [ -f "$src" ] || continue
    name="$(basename "$src" | sed 's/^netplan-wlan0-//')"
    [ -f "$TARGET_DIR/$name" ] && continue
    cp "$src" "$TARGET_DIR/$name"
    # привязка к пользователю машины-сборщика не даст профилю работать у нового пользователя
    sed -i '/^permissions=/d' "$TARGET_DIR/$name"
    chown root:root "$TARGET_DIR/$name"
    chmod 600 "$TARGET_DIR/$name"
    printf "  %-34s psk=%s привязка=%s\n" "$name" \
        "$(grep -c '^psk=' "$TARGET_DIR/$name" || true)" \
        "$(grep -c '^permissions=' "$TARGET_DIR/$name" || true)"
    count=$((count + 1))
done
echo "  перенесено профилей: $count"

echo
echo "=== 2. права на управление сетью (иначе в консоли: Not authorized to control networking) ==="
mkdir -p "$MNT/etc/polkit-1/rules.d"
cat > "$MNT/etc/polkit-1/rules.d/49-networkmanager-local.rules" <<'EOF'
// Локальным пользователям из групп netdev/sudo разрешено управлять сетью без запроса пароля.
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
        (subject.isInGroup("netdev") || subject.isInGroup("sudo"))) {
        return polkit.Result.YES;
    }
});
EOF
chmod 644 "$MNT/etc/polkit-1/rules.d/49-networkmanager-local.rules"

if [ -x /usr/bin/qemu-x86_64-static ] && [ ! -e "$MNT/usr/bin/qemu-x86_64-static" ]; then
    cp /usr/bin/qemu-x86_64-static "$MNT/usr/bin/"
fi
for d in dev dev/pts proc sys; do mount --bind "/$d" "$MNT/$d" 2>/dev/null || true; done
chroot "$MNT" usermod -aG netdev "$TARGET_USER" 2>/dev/null || true
chroot "$MNT" apt-get install -y -q --no-install-recommends wireless-regdb 2>/dev/null || true
echo "  группы пользователя: $(chroot "$MNT" id -nG "$TARGET_USER" 2>/dev/null || echo '?')"

for d in dev/pts dev proc sys; do umount -l "$MNT/$d" 2>/dev/null || true; done
sync
echo
echo "Готово. На первой загрузке ноутбук подключится к сети сам, без ввода пароля."
