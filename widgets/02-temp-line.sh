#!/bin/bash
# Строка для виджета панели: температура процессора и внешнего NVMe.
# Процессор читается напрямую (k10temp), NVMe — из файла, который пишет служба nvme-temp.
cpu_temp() {
    for h in /sys/class/hwmon/hwmon*; do
        case "$(cat "$h/name" 2>/dev/null)" in
            k10temp|coretemp|zenpower)
                v=$(cat "$h/temp1_input" 2>/dev/null) && [ -n "$v" ] && { echo $((v / 1000)); return; } ;;
        esac
    done
    for z in /sys/class/thermal/thermal_zone*; do
        v=$(cat "$z/temp" 2>/dev/null) && [ -n "$v" ] && { echo $((v / 1000)); return; }
    done
}
C=$(cpu_temp); N=$(tr -dc '0-9.' < /run/nvme-temp 2>/dev/null)
printf 'CPU %s° · NVMe %s°' "${C:---}" "${N:---}"