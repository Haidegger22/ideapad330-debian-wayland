#!/usr/bin/env python3
"""Виджет температур процессора и внешнего NVMe (способ Зеро: GTK3 + Cairo).

Источники: процессор — напрямую из hwmon (k10temp), NVMe — из /run/nvme-temp,
который пишет служба nvme-temp (smartctl требует root).
Позицию задаёт правило KWin: в Wayland окно не может двигать себя само.
"""
import glob, os
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib
import cairo

UPDATE_SEC = 5
NVME_FILE = "/run/nvme-temp"
VALUES = os.path.expanduser("~/.cache/temp-widget.values")

def read(path):
    try:
        with open(path) as fh:
            return fh.read().strip()
    except OSError:
        return None

def cpu_temp():
    for hw in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        if (read(hw + "/name") or "") in ("k10temp", "coretemp", "zenpower"):
            v = read(hw + "/temp1_input")
            if v and v.lstrip("-").isdigit():
                t = int(v) / 1000.0
                if 0 < t < 120:
                    return t
    for zone in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
        v = read(zone + "/temp")
        if v and v.isdigit() and 0 < int(v) / 1000.0 < 120:
            return int(v) / 1000.0
    return None

def nvme_temp():
    try:
        return float(read(NVME_FILE))
    except (TypeError, ValueError):
        return None

def colour(t, warn, hot):
    if t is None:
        return (0.62, 0.62, 0.62)
    if t >= hot:
        return (0.96, 0.36, 0.30)
    if t >= warn:
        return (0.96, 0.76, 0.26)
    return (0.45, 0.86, 0.46)

class TempWidget(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        GLib.set_prgname("tempwidget")
        self.set_title("tempwidget")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)
        self.set_app_paintable(True)
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_size_request(225, 32)      # жёсткий размер: иначе окно растягивается
        self.set_default_size(225, 32)
        self.connect("draw", self.on_draw)
        self.cpu = self.nvme = None
        self.refresh()
        GLib.timeout_add_seconds(UPDATE_SEC, self.refresh)

    def refresh(self):
        self.cpu, self.nvme = cpu_temp(), nvme_temp()
        try:
            os.makedirs(os.path.dirname(VALUES), exist_ok=True)
            with open(VALUES, "w") as fh:
                fh.write("cpu=%s nvme=%s\n" % (self.cpu, self.nvme))
        except OSError:
            pass
        self.queue_draw()
        return True

    @staticmethod
    def draw_reading(cr, x, y, label, value, warn, hot):
        cr.set_source_rgb(*colour(value, warn, hot))
        cr.arc(x + 8, y + 9, 6.0, 0, 2 * 3.14159265)
        cr.fill()
        text = "%s %s" % (label, "--" if value is None else "%.0f\u00b0" % value)
        cr.move_to(x + 20, y + 14)
        cr.show_text(text)
        return x + 20 + len(text) * 8.4 + 12

    def on_draw(self, _widget, cr):
        cr.set_source_rgba(0.07, 0.08, 0.10, 0.74)   # полупрозрачная подложка
        cr.paint()
        cr.select_font_face("DejaVu Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(13)
        x = 10
        x = self.draw_reading(cr, x, 6, "CPU", self.cpu, 50, 70)
        self.draw_reading(cr, x, 6, "NVMe", self.nvme, 50, 70)
        return False

win = TempWidget()
win.show_all()
Gtk.main()