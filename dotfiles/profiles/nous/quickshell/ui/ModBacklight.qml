// Brilho. Fonte: Sys (FileView sobre /sys/class/backlight/*). Scroll chama o
// wrapper brightness-ctl já existente em packages.nix — não escreve em /sys
// diretamente (o wrapper cuida de permissão/udev).
import Quickshell

BarModule {
    visible: Sys.backlightAvailable
    glyph: Sys.backlightFrac > 0.66 ? "󰃠" : (Sys.backlightFrac > 0.33 ? "󰃟" : "󰃞")
    valueText: Math.round(Sys.backlightFrac * 100) + "%"

    onScrolledUp: Quickshell.execDetached(["brightness-ctl", "inc", "1"])
    onScrolledDown: Quickshell.execDetached(["brightness-ctl", "dec", "1"])
}
