#!/usr/bin/env python3
"""Volume popup for waybar: slider + dynamic icon. Toggle via lock file."""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')

from gi.repository import GLib
GLib.set_prgname('waybar-volume-popup')
GLib.set_application_name('waybar-volume-popup')

from gi.repository import Gtk, Gdk

import fcntl
import os
import re
import signal
import subprocess
import sys

LOCK_FILE = '/tmp/waybar-volume-popup.lock'
PID_FILE  = '/tmp/waybar-volume-popup.pid'

ICON_MUTE = '󰝟'
ICON_LOW  = '󰕿'
ICON_HIGH = '󰕾'

# ── Cores do design system ────────────────────────────────────────────────────
# Lê os tokens gerados pelo wallust (mesmo include usado pelo rofi). Nunca
# hardcodar cor: o popup segue a paleta do wallpaper como todo o resto.
COLORS_FILE = os.path.expanduser('~/.config/rofi/colors.rasi')

# Fallback partilhado com o wallpaper-picker — só usado se o include não existir.
_FALLBACK = {
    'base': '#1e1e2e', 'text': '#cdd6f4',
    'primary': '#cba6f7', 'secondary': '#585b70', 'alert': '#f38ba8',
}


def load_colors() -> dict:
    c = dict(_FALLBACK)
    try:
        txt = open(COLORS_FILE).read()
        for k in c:
            m = re.search(rf'\b{k}\s*:\s*(#[0-9a-fA-F]{{6}})', txt)
            if m:
                c[k] = m.group(1)
    except Exception:
        pass
    return c


def _rgba(hex_color: str, alpha: float) -> str:
    h = hex_color.lstrip('#')
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return f'rgba({r},{g},{b},{alpha})'


def build_css() -> bytes:
    c = load_colors()
    return f"""
window {{
    background: {_rgba(c['base'], 0.96)};
    border: 1px solid {_rgba(c['primary'], 0.3)};
    border-radius: 12px;
}}
box {{
    padding: 8px 14px;
}}
label.vol-icon {{
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono", monospace;
    font-size: 20px;
    color: {c['primary']};
    margin-right: 6px;
}}
scale trough {{
    background: {_rgba(c['text'], 0.08)};
    border-radius: 4px;
    min-height: 6px;
}}
scale highlight {{
    background: {c['primary']};
    border-radius: 4px;
}}
scale slider {{
    background: {c['primary']};
    border-radius: 50%;
    min-width: 14px;
    min-height: 14px;
    margin: -4px 0;
}}
scale value {{
    color: {c['text']};
    font-size: 12px;
    min-width: 38px;
}}
""".encode()


def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def get_volume() -> int:
    out = _run(['pactl', 'get-sink-volume', '@DEFAULT_SINK@']).stdout
    m = re.search(r'(\d+)%', out)
    return int(m.group(1)) if m else 0


def is_muted() -> bool:
    out = _run(['pactl', 'get-sink-mute', '@DEFAULT_SINK@']).stdout
    return 'yes' in out


def set_volume(vol: int):
    _run(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{vol}%'])


def volume_icon(vol: int, muted: bool) -> str:
    if muted or vol == 0:
        return ICON_MUTE
    return ICON_LOW if vol < 50 else ICON_HIGH


def try_toggle_existing() -> bool:
    """Return True if an existing popup was killed (caller should exit)."""
    try:
        with open(PID_FILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, signal.SIGTERM)
        return True
    except Exception:
        return False


class VolumePopup(Gtk.Window):
    def __init__(self):
        super().__init__(title='waybar-volume-popup')
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_resizable(False)
        self.set_default_size(290, 54)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)

        # Enable RGBA for rounded corners transparency
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        provider = Gtk.CssProvider()
        provider.load_from_data(build_css())
        Gtk.StyleContext.add_provider_for_screen(
            screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.add(box)

        self._muted = is_muted()
        vol = get_volume()

        self._icon = Gtk.Label(label=volume_icon(vol, self._muted))
        self._icon.get_style_context().add_class('vol-icon')
        box.pack_start(self._icon, False, False, 0)

        self._scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 150, 1)
        self._scale.set_value(vol)
        self._scale.set_draw_value(True)
        self._scale.set_value_pos(Gtk.PositionType.RIGHT)
        self._scale.set_hexpand(True)
        self._scale.connect('format-value', lambda s, v: f'{int(v)}%')
        self._scale.connect('value-changed', self._on_value_changed)
        box.pack_start(self._scale, True, True, 0)

        self.connect('focus-out-event', lambda w, e: self._quit())
        self.connect('delete-event', lambda w, e: self._quit())
        self.connect('key-press-event', self._on_key)

        self.show_all()
        self.present()

    def _on_value_changed(self, scale):
        vol = int(scale.get_value())
        set_volume(vol)
        self._icon.set_label(volume_icon(vol, is_muted()))

    def _on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self._quit()

    def _quit(self):
        try:
            os.remove(PID_FILE)
            os.remove(LOCK_FILE)
        except Exception:
            pass
        Gtk.main_quit()


def main():
    # Acquire exclusive lock — second invocation kills first (toggle behavior)
    try:
        lock_fd = open(LOCK_FILE, 'w')
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except IOError:
        try_toggle_existing()
        sys.exit(0)

    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))

    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())

    VolumePopup()
    Gtk.main()

    try:
        os.remove(PID_FILE)
        os.remove(LOCK_FILE)
    except Exception:
        pass


if __name__ == '__main__':
    main()
