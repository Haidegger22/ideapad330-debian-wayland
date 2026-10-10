#!/bin/bash
# Виджеты системного монитора на РАБОЧЕМ СТОЛЕ: ЦП, память, диск — круговыми диаграммами.
# Запускать НА НОУТБУКЕ из графической сессии (не по SSH без окружения).
# Ставятся штатные виджеты Plasma, своего кода не нужно.
set -euo pipefail

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
CFG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
SHELL_IFACE="org.kde.PlasmaShell"

say() { printf '%s\n' "$*"; }
E()   { qdbus6 org.kde.plasmashell /PlasmaShell "$SHELL_IFACE.evaluateScript" "$1" 2>&1 | head -3; }

say "=== 1. пакеты ==="
for p in plasma-systemmonitor ksystemstats; do
    dpkg -l "$p" >/dev/null 2>&1 || { say "  ставлю $p"; sudo apt-get install -y -q "$p" >/dev/null; }
    say "  $p: $(dpkg -l "$p" 2>/dev/null | awk '/^ii/{print $3}')"
done

say
say "=== 2. копия настроек Plasma (обязательно ДО правок) ==="
mkdir -p "$HOME/.config/plasma-backups"
cp "$CFG" "$HOME/.config/plasma-backups/appletsrc-$(date +%Y%m%d-%H%M%S)"
say "  копия: $(ls -1t "$HOME/.config/plasma-backups" | head -1)"
say "  (настройки Plasma руками не править — только через evaluateScript,"
say "   иначе можно потерять раздел панели и остаться без панели вовсе)"

say
say "=== 3. добавляю три виджета и сразу настраиваю ==="
E 'var d = desktops()[0];
   var jobs = [
     {plugin: "org.kde.plasma.systemmonitor.cpu",       title: "CPU", hi: ["cpu/all/usage"]},
     {plugin: "org.kde.plasma.systemmonitor.memory",    title: "RAM", hi: ["memory/physical/used"]},
     {plugin: "org.kde.plasma.systemmonitor.diskusage", title: "SSD", hi: []}
   ];
   var out = [];
   for (var i = 0; i < jobs.length; i++) {
     var j = jobs[i];
     var existing = null;
     var ws = d.widgets;
     for (var k = 0; k < ws.length; k++) { if (ws[k].type == j.plugin) existing = ws[k]; }
     var a = existing ? existing : d.addWidget(j.plugin);
     if (!a) { out.push(j.title + ": не удалось"); continue; }
     a.currentConfigGroup = ["Appearance"];
     a.writeConfig("title", j.title);
     a.writeConfig("chartFace", "org.kde.ksysguard.piechart");
     a.currentConfigGroup = ["General"];
     a.writeConfig("chartFace", "org.kde.ksysguard.piechart");
     a.currentConfigGroup = ["Sensors"];
     a.writeConfig("highPrioritySensorIds", j.hi);
     if (j.title == "SSD") {
       // Ключ к нужному виду кружка: объёмы в байтах (used/free), а не проценты.
       // С highPrioritySensorIds=[disk/all/used] plasma подставляет usedPercent
       // и вместо «17,9 ГиБ» показывает «Доля использования 7,7%».
       a.writeConfig("totalSensors", ["disk/all/used", "disk/all/free"]);
       a.writeConfig("lowPrioritySensorIds", []);
     }
     a.reloadConfig();
     out.push(j.title + ": " + (existing ? "уже был, настроен заново" : "добавлен"));
   }
   print(out.join(" | "))'

say
say "=== 4. проверка ==="
E 'print("панелей: " + String(panels().length) + " | виджетов на рабочем столе: " + JSON.stringify(desktops()[0].widgetIds))'
say "  круговой вид в настройках: $(grep -c 'chartFace=org.kde.ksysguard.piechart' "$CFG" 2>/dev/null || echo 0)"
say
say "Готово. Подписи виджетов: CPU, RAM, SSD."
say "Убрать виджет: навести курсор на круг → крестик; либо правой кнопкой по рабочему столу →"
say "режим правки → «✕» у ненужного. Перетаскивать и менять размер — там же."
say "Панельный виджет температур это не затрагивает."
