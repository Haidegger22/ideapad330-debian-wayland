#!/bin/bash
# Русский язык KDE Plasma + перенос панели наверх. Запускать НА НОУТБУКЕ от имени пользователя.
# Проверено на Debian 13 + Plasma 6.3 (Wayland).
#
# ВАЖНО: скрипт сработает только если русская локаль уже сгенерирована.
# Проверка:  locale -a | grep ru_RU   -> должна быть строка ru_RU.utf8
# Если её нет — сначала запустить 08-fix-locale-ru.sh, иначе интерфейс останется английским,
# сколько бы настроек языка вы ни меняли.
set -euo pipefail

UID_NUM="$(id -u)"
export XDG_RUNTIME_DIR="/run/user/${UID_NUM}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${UID_NUM}/bus"

echo "=== 1. язык интерфейса KDE ==="
cat > "$HOME/.config/plasma-localerc" <<'EOF'
[Formats]
LANG=ru_RU.UTF-8

[Translations]
LANGUAGE=ru
EOF
sed 's/^/  /' "$HOME/.config/plasma-localerc"

echo
echo "=== 2. раскладка клавиатуры: us+ru, переключение Alt+Shift ==="
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "us,ru"
kwriteconfig6 --file kxkbrc --group Layout --key VariantList ","
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames "en,ru"
kwriteconfig6 --file kxkbrc --group Layout --key Options "grp:alt_shift_toggle"
kwriteconfig6 --file kxkbrc --group Layout --key ResetOldOptions true
sed 's/^/  /' "$HOME/.config/kxkbrc"

echo
echo "=== 3. панель Plasma наверх ==="
printf 'var p = panelById(panelIds[0]);\nif (p) { p.location = "top"; }\n' > /tmp/panel-to-top.js
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat /tmp/panel-to-top.js)" >/dev/null 2>&1 || true
sleep 3

echo "=== 4. проверка по факту (ответ самой Plasma, а не файл) ==="
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.dumpCurrentLayoutJS 2>/dev/null \
  | grep -oE '"location": "[a-z]+"' | head -3 | sed 's/^/  /' || echo "  (ответ не получен — проверьте глазами)"

echo
echo "Готово. Чтобы переводы подхватились, нужно выйти из сессии и войти снова."
