#!/bin/bash
# Генерация русской локали. Без неё интерфейс останется английским, сколько бы
# настроек языка ни менять: приложения не могут переключиться на несуществующую локаль.
# Запускать НА НОУТБУКЕ от root (или через пакет с postinst, если sudo узкий).
set -euo pipefail

echo "=== было ==="
locale -a | head -5 | sed 's/^/  /'
echo -n "  русских локалей: "; locale -a | grep -c ru_RU || true

sed -i 's/^# *ru_RU\.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
grep -q '^ru_RU\.UTF-8 UTF-8' /etc/locale.gen || echo 'ru_RU.UTF-8 UTF-8' >> /etc/locale.gen
grep -q '^en_US\.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
printf 'LANG=ru_RU.UTF-8\n' > /etc/default/locale

echo
echo "=== стало ==="
locale -a | grep -iE 'ru_RU|en_US' | sed 's/^/  /'
echo -n "  проверка живым тестом: "; LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8 date '+%A, %d %B %Y' 2>&1
echo "  (если вывод вида «Пятница, 09 октября 2026» — локаль работает)"
echo
echo "Чтобы интерфейс стал русским, нужно перезапустить оболочку или выйти из сессии и войти снова."
