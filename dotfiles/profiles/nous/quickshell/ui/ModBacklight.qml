// Brilho. Fonte: Sys (FileView sobre /sys/class/backlight/*). Scroll chama o
// wrapper brightness-ctl já existente em packages.nix — não escreve em /sys
// diretamente (o wrapper cuida de permissão/udev).
import QtQuick
import Quickshell

BarModule {
    visible: Sys.backlightAvailable
    glyph: Sys.backlightFrac > 0.66 ? "󰃠" : (Sys.backlightFrac > 0.33 ? "󰃟" : "󰃞")
    valueText: Math.round(Sys.backlightFrac * 100) + "%"

    onScrolledUp: {
        Quickshell.execDetached(["brightness-ctl", "inc", "1"]);
        refreshDelay.restart();
    }
    onScrolledDown: {
        Quickshell.execDetached(["brightness-ctl", "dec", "1"]);
        refreshDelay.restart();
    }

    // execDetached é fire-and-forget; brightness-ctl escreve em /sys quase na hora
    // (~15ms medido), então um atraso curto aqui já garante ler o valor novo, sem
    // esperar o próximo tick do Timer de 2s do Sys.qml (ver o comentário lá).
    Timer {
        id: refreshDelay
        interval: 80
        onTriggered: Sys.refreshBacklight()
    }
}
