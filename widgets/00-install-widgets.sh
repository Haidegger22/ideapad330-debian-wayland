#!/bin/bash
# Установка виджета температур (процессор + внешний NVMe) на панель Plasma 6.
# Запускать НА НОУТБУКЕ от своего пользователя. Пароль sudo спросят один раз.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLASMOID_ID="ru.artem.tempwidget"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"
BIN_DIR="$HOME/.local/bin"

echo "=== 1. пакеты ==="
sudo apt-get install -y -q smartmontools lm-sensors python3-gi python3-gi-cairo \
    gir1.2-gtk-3.0 python3-cairo qml6-module-org-kde-plasma-plasma5support 2>&1 | tail -2

echo
echo "=== 2. служба, которая читает температуру NVMe за USB-мостом ==="
# smartctl требует root; чтобы не расширять права sudo, значение кладём в файл для пользователя
sudo install -m 755 "$HERE/01-nvme-temp-report.sh" /usr/local/sbin/nvme-temp.sh
sudo install -m 644 "$HERE/nvme-temp.service" /etc/systemd/system/nvme-temp.service
sudo install -m 644 "$HERE/nvme-temp.timer"   /etc/systemd/system/nvme-temp.timer
sudo systemctl daemon-reload
sudo systemctl enable --now nvme-temp.timer >/dev/null
sleep 3
echo "  таймер: $(systemctl is-active nvme-temp.timer)"
echo "  температура NVMe: $(cat /run/nvme-temp 2>/dev/null || echo 'пока нет')"

echo
echo "=== 3. скрипт-строка для панели ==="
mkdir -p "$BIN_DIR"
install -m 755 "$HERE/02-temp-line.sh" "$BIN_DIR/temp-line.sh"
echo "  проверка: $("$BIN_DIR/temp-line.sh")"

echo
echo "=== 4. сам апплет (плазмоид) ==="
mkdir -p "$PLASMOID_DIR/contents/ui"
sed "s|__HOME__|$HOME|g" "$HERE/plasmoid-tempwidget/contents/ui/main.qml" > "$PLASMOID_DIR/contents/ui/main.qml"
cp "$HERE/plasmoid-tempwidget/metadata.json" "$PLASMOID_DIR/metadata.json"
chmod 644 "$PLASMOID_DIR/metadata.json" "$PLASMOID_DIR/contents/ui/main.qml"

echo
echo "=== 5. добавляю в панель (только если его там ещё нет) ==="
CFG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
if grep -q "plugin=$PLASMOID_ID" "$CFG" 2>/dev/null; then
    echo "  уже стоит в панели — не трогаю (иначе появятся копии)"
else
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
        "var p = panels()[0]; p.addWidget('$PLASMOID_ID'); print('добавлен')" || \
        echo "  не получилось добавить автоматически: панель → правка → «Добавить виджеты» → «Температуры CPU и NVMe»"
fi
echo "  копий в панели: $(grep -c "plugin=$PLASMOID_ID" "$CFG" 2>/dev/null || echo 0)"

echo
echo "=== 6. необязательно: плавающее окно вместо апплета ==="
echo "  файл 04-temp-widget-float.py — самодостаточный виджет GTK (способ, проверенный на Zero 3W)."
echo "  Он нужен, только если апплет в панель поставить нельзя."
echo
echo "Готово. Пороги цвета: зелёный до 49°, жёлтый 50–69°, красный от 70°."
echo "Проверка со стороны системы: systemctl status nvme-temp.timer; cat /run/nvme-temp"
