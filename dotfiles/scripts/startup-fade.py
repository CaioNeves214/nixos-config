#!/usr/bin/env python3
"""Animação de entrada da sessão: fade-in + zoom do wallpaper ao abrir o Hyprland.

Sem isso a tela fica preta entre o greeter sair e o hyprpaper/waybar desenharem.
Este overlay (layer-shell, camada OVERLAY, click-through) sobe junto com o
Hyprland e cobre justamente essa janela de tempo:

  1. fade-in   — o wallpaper aparece sobre $base, saindo de um zoom leve (ZOOM→1.0)
  2. espera    — segura o quadro até o hyprpaper ter o wallpaper carregado
  3. dissolve  — o overlay some, revelando o desktop vivo (mesmo wallpaper + waybar)

Como o quadro final do overlay é idêntico ao que o hyprpaper pinta, a passagem
para o desktop real é invisível: só a waybar surge no fade.

As cores vêm do design system (~/.config/hypr/colors.conf, gerado pelo wallust).
"""

import os
import re
import subprocess
import time

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk, GtkLayerShell  # noqa: E402

WALLPAPER = os.path.expanduser("~/.cache/current-wallpaper")
COLORS = os.path.expanduser("~/.config/hypr/colors.conf")

FADE_IN_MS = 900       # wallpaper surgindo + zoom assentando
DISSOLVE_MS = 450      # overlay se dissolvendo no desktop real
MAX_WAIT_MS = 4000     # teto de espera pelo hyprpaper (nunca trava a sessão)
ZOOM = 1.06            # escala inicial; termina em 1.0
FALLBACK_BASE = (0.02, 0.02, 0.02)


def load_base_color():
    """Lê $base do colors.conf do wallust: `$base = rgb(020000)`."""
    try:
        with open(COLORS) as f:
            m = re.search(r"\$base\s*=\s*rgb\(([0-9A-Fa-f]{6})\)", f.read())
        if m:
            h = m.group(1)
            return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    except OSError:
        pass
    return FALLBACK_BASE


def ease_out_cubic(t):
    return 1 - (1 - t) ** 3


def wallpaper_ready():
    """True quando o hyprpaper já tem o wallpaper carregado (logo, pintado)."""
    try:
        out = subprocess.run(
            ["hyprctl", "hyprpaper", "listloaded"],
            capture_output=True, text=True, timeout=1,
        ).stdout.strip()
        return bool(out) and "no wallpapers" not in out.lower()
    except (OSError, subprocess.SubprocessError):
        return True  # sem hyprpaper não há o que esperar


class StartupFade(Gtk.Window):
    def __init__(self, pixbuf, base):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.pixbuf = pixbuf
        self.base = base
        self.scaled = None      # pixbuf recortado para a tela, no zoom máximo
        self.start = time.monotonic()
        self.dissolve_start = None

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "startup-fade")
        GtkLayerShell.set_exclusive_zone(self, -1)  # cobre a waybar também
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM,
                     GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)

        self.set_app_paintable(True)
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.connect("draw", self.on_draw)
        self.connect("realize", self.on_realize)
        self.connect("destroy", Gtk.main_quit)
        self.add_tick_callback(lambda *_: (self.queue_draw(), GLib.SOURCE_CONTINUE)[1])

    def on_realize(self, _w):
        # Click-through: região de input vazia, para não roubar cliques do desktop.
        self.input_shape_combine_region(cairo.Region())

    def cover(self, w, h):
        """Recorta o wallpaper para cobrir a tela, já no zoom máximo."""
        if self.scaled and (self.scaled.get_width(), self.scaled.get_height()) == (w, h):
            return self.scaled
        iw, ih = self.pixbuf.get_width(), self.pixbuf.get_height()
        s = max(w / iw, h / ih) * ZOOM
        sw, sh = max(1, round(iw * s)), max(1, round(ih * s))
        big = self.pixbuf.scale_simple(sw, sh, GdkPixbuf.InterpType.BILINEAR)
        self.scaled = GdkPixbuf.Pixbuf.new_subpixbuf(
            big, (sw - w) // 2, (sh - h) // 2, w, h
        )
        return self.scaled

    def on_draw(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        elapsed = (time.monotonic() - self.start) * 1000

        # Fase 1: wallpaper surge sobre $base e o zoom assenta em 1.0.
        p = min(1.0, elapsed / FADE_IN_MS)
        img_alpha = ease_out_cubic(p)
        scale = ZOOM - (ZOOM - 1.0) * ease_out_cubic(p)

        # Fase 3: overlay inteiro se dissolve (só começa com o hyprpaper pronto).
        win_alpha = 1.0
        if self.dissolve_start is not None:
            d = (time.monotonic() - self.dissolve_start) * 1000 / DISSOLVE_MS
            win_alpha = max(0.0, 1.0 - d)
            if win_alpha <= 0:
                GLib.idle_add(self.destroy)

        cr.save()
        cr.set_operator(cairo.Operator.SOURCE)  # escreve o alfa, não compõe sobre ele
        cr.set_source_rgba(*self.base, win_alpha)
        cr.paint()
        cr.restore()

        pb = self.cover(w, h)
        cr.save()
        # Zoom em torno do centro da tela.
        cr.translate(w / 2, h / 2)
        cr.scale(scale, scale)
        cr.translate(-w / 2, -h / 2)
        Gdk.cairo_set_source_pixbuf(cr, pb, 0, 0)
        cr.paint_with_alpha(img_alpha * win_alpha)
        cr.restore()
        return False

    # Fase 2: assim que o fade-in termina e o hyprpaper está pronto, dissolve.
    def poll(self):
        if self.dissolve_start is not None:
            return GLib.SOURCE_REMOVE
        elapsed = (time.monotonic() - self.start) * 1000
        if elapsed < FADE_IN_MS:
            return GLib.SOURCE_CONTINUE
        if wallpaper_ready() or elapsed > MAX_WAIT_MS:
            self.dissolve_start = time.monotonic()
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE


def main():
    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(os.path.realpath(WALLPAPER))
    except GLib.Error:
        return  # sem wallpaper definido: nada a animar, a sessão segue normal

    win = StartupFade(pixbuf, load_base_color())
    win.show_all()
    GLib.timeout_add(120, win.poll)
    Gtk.main()


if __name__ == "__main__":
    main()
