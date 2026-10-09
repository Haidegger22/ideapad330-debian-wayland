#!/bin/bash
# Обезличено для публикации: личные пути, имя пользователя и адреса заменены.
# Проверьте значения ниже перед запуском.

# ЭТАП 2 — выполняется НА НОУТБУКЕ (после первой загрузки, по SSH с Джарвиса).
# Ставит рабочий стол KDE Plasma 6.3 с сессией Wayland по умолчанию.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "### Plasma для ноутбука: $(date '+%H:%M:%S')"

apt-get update -q
apt-get install -y --no-install-recommends \
  kde-plasma-desktop kde-config-sddm sddm \
  plasma-nm plasma-pa powerdevil bluedevil xdg-desktop-portal-kde \
  dolphin konsole ark okular gwenview \
  fonts-dejavu fonts-noto-core \
  qterminal

# Wayland как сессия по умолчанию на экране входа
mkdir -p /etc/sddm.conf.d
printf '[General]\nDisplayServer=wayland\n' > /etc/sddm.conf.d/10-wayland.conf

systemctl enable sddm
systemctl set-default graphical.target
echo "### готово: $(date '+%H:%M:%S')"
