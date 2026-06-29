#!/usr/bin/env python3
"""Wallpaper & theme picker para Hyprland. Abre com SUPER+W."""
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import Gtk, GdkPixbuf, Gdk
import os
import re
import subprocess

WALLPAPER_DIR = os.path.expanduser("~/.config/wallpapers")
CURRENT_LINK  = os.path.expanduser("~/.cache/current-wallpaper")
COLORS_FILE   = os.path.expanduser("~/.config/rofi/colors.rasi")

THUMB_W, THUMB_H = 210, 118
COLS = 3

# ── Cores ────────────────────────────────────────────────────────────────────

def _load_colors():
    defaults = {
        "base": "#1a1b26", "text": "#c0caf5",
        "primary": "#7aa2f7", "secondary": "#414868", "alert": "#f7768e",
    }
    try:
        txt = open(COLORS_FILE).read()
        for k in defaults:
            m = re.search(rf'\b{k}\s*:\s*(#[0-9a-fA-F]{{6}})', txt)
            if m:
                defaults[k] = m.group(1)
    except Exception:
        pass
    return defaults

def _rgba(hex_color: str, alpha: float) -> str:
    h = hex_color.lstrip('#')
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f"rgba({r},{g},{b},{alpha})"

# ── Helpers ───────────────────────────────────────────────────────────────────

def _current_wallpaper() -> str | None:
    try:
        return os.path.realpath(CURRENT_LINK)
    except Exception:
        return None

def _list_wallpapers():
    exts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'}
    if not os.path.isdir(WALLPAPER_DIR):
        return []
    return sorted(
        os.path.join(WALLPAPER_DIR, f)
        for f in os.listdir(WALLPAPER_DIR)
        if os.path.splitext(f)[1].lower() in exts
    )

# ── Janela ────────────────────────────────────────────────────────────────────

class WallpaperPicker(Gtk.Window):
    def __init__(self):
        super().__init__()
        self._c       = _load_colors()
        self._current = _current_wallpaper()

        self.set_title("Wallpapers")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)

        self.connect("key-press-event", self._on_key)
        self.connect("destroy", Gtk.main_quit)

        self._apply_css()
        self._build_ui()
        self.show_all()
        self._center()
        self.grab_focus()

    # ── CSS gerado dinamicamente a partir das cores wallust ───────────────────

    def _apply_css(self):
        c = self._c
        css = f"""
window {{
    background-color: {c['base']};
    border-radius: 14px;
    border: 1px solid {_rgba(c['secondary'], 0.6)};
}}
.picker-title {{
    font-size: 17px;
    font-weight: bold;
    color: {c['text']};
}}
.card {{
    background-color: {_rgba(c['secondary'], 0.12)};
    border-radius: 10px;
    padding: 8px;
    border: 1px solid {_rgba(c['secondary'], 0.25)};
    transition: background-color 80ms ease;
}}
.card:hover {{
    background-color: {_rgba(c['primary'], 0.18)};
    border-color: {_rgba(c['primary'], 0.55)};
}}
.card-active {{
    border: 2px solid {c['primary']};
    background-color: {_rgba(c['primary'], 0.10)};
}}
.wp-name {{
    color: {c['text']};
    font-size: 12px;
    font-weight: 600;
}}
.wp-theme {{
    color: {_rgba(c['text'], 0.55)};
    font-size: 11px;
}}
.badge-active {{
    color: {c['primary']};
    font-size: 10px;
    font-weight: bold;
}}
.hint {{
    color: {_rgba(c['text'], 0.35)};
    font-size: 11px;
}}
separator {{
    background-color: {_rgba(c['secondary'], 0.4)};
    min-height: 1px;
}}
"""
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    # ── Layout ────────────────────────────────────────────────────────────────

    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        root.set_border_width(16)

        # Cabeçalho
        title = Gtk.Label(label="  Wallpapers & Temas")
        title.set_halign(Gtk.Align.START)
        title.get_style_context().add_class("picker-title")
        root.pack_start(title, False, False, 0)
        root.pack_start(Gtk.Separator(), False, False, 0)

        # Área com scroll (caso tenham muitos wallpapers)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_propagate_natural_height(True)
        scroll.set_max_content_height(520)

        grid = Gtk.Grid()
        grid.set_row_spacing(10)
        grid.set_column_spacing(10)
        grid.set_border_width(4)

        for i, wp in enumerate(_list_wallpapers()):
            row, col = divmod(i, COLS)
            grid.attach(self._make_card(wp), col, row, 1, 1)

        scroll.add(grid)
        root.pack_start(scroll, True, True, 0)

        # Rodapé
        hint = Gtk.Label(label="Clique para aplicar  ·  ESC para fechar")
        hint.get_style_context().add_class("hint")
        hint.set_halign(Gtk.Align.CENTER)
        root.pack_start(hint, False, False, 2)

        self.add(root)

    # ── Card de cada wallpaper ────────────────────────────────────────────────

    def _make_card(self, path: str) -> Gtk.Button:
        name     = os.path.basename(path)
        stem     = os.path.splitext(name)[0]
        is_active = os.path.realpath(path) == self._current

        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn._wp_path = path
        btn.connect("clicked", self._apply)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.set_size_request(THUMB_W + 12, -1)
        box.get_style_context().add_class("card")
        if is_active:
            box.get_style_context().add_class("card-active")

        # Miniatura
        try:
            pb  = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, THUMB_W, THUMB_H, True)
            img = Gtk.Image.new_from_pixbuf(pb)
        except Exception:
            img = Gtk.Image.new_from_icon_name("image-missing", Gtk.IconSize.DIALOG)
        img.set_size_request(THUMB_W, THUMB_H)
        box.pack_start(img, False, False, 0)

        # Nome do arquivo
        lbl_name = Gtk.Label(label=name)
        lbl_name.set_ellipsize(3)          # PANGO_ELLIPSIZE_END
        lbl_name.set_max_width_chars(26)
        lbl_name.set_halign(Gtk.Align.START)
        lbl_name.get_style_context().add_class("wp-name")
        box.pack_start(lbl_name, False, False, 0)

        # Nome do tema (stem do arquivo)
        lbl_theme = Gtk.Label(label=f"Tema: {stem}")
        lbl_theme.set_halign(Gtk.Align.START)
        lbl_theme.get_style_context().add_class("wp-theme")
        box.pack_start(lbl_theme, False, False, 0)

        # Badge "Ativo"
        if is_active:
            badge = Gtk.Label(label="● Ativo")
            badge.set_halign(Gtk.Align.START)
            badge.get_style_context().add_class("badge-active")
            box.pack_start(badge, False, False, 0)

        btn.add(box)
        return btn

    # ── Ações ─────────────────────────────────────────────────────────────────

    def _apply(self, btn):
        subprocess.Popen(["update-theme", btn._wp_path])
        Gtk.main_quit()

    def _on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()

    def _center(self):
        self.realize()
        display = Gdk.Display.get_default()
        monitor = display.get_primary_monitor()
        if not monitor:
            return
        geo  = monitor.get_geometry()
        w, h = self.get_size()
        self.move(geo.x + (geo.width - w) // 2, geo.y + (geo.height - h) // 2)


if __name__ == "__main__":
    WallpaperPicker()
    Gtk.main()
