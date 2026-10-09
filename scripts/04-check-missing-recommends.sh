#!/bin/bash
# Обезличено для публикации: личные пути, имя пользователя и адреса заменены.
# Проверьте значения ниже перед запуском.

# Ищем рекомендованные пакеты, которых нет в системе (для рабочего стола и его приложений).
export LC_ALL=C
INST=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | sort -u)
PKGS="kde-plasma-desktop plasma-desktop plasma-workspace kwin-wayland systemsettings powerdevil bluedevil plasma-nm plasma-pa kde-config-sddm dolphin konsole ark okular gwenview kio-extras kio-admin cinnamon cinnamon-desktop-environment nemo nemo-fileroller gnome-keyring seahorse flatpak apt-xapian-index"
for p in $PKGS; do
  recs=$(apt-cache show "$p" 2>/dev/null | awk '/^Recommends:/{sub(/^Recommends: */,""); print}')
  [ -z "$recs" ] && continue
  echo "$recs" | tr ',' '\n' | sed 's/|.*//' | awk '{print $1}' | grep -vE '^$' | while read -r r; do
    echo "$INST" | grep -qx "$r" || echo "$r|$p"
  done
done | sort -u | awk -F'|' '{printf "  %-28s (для %s)\n", $1, $2}'
