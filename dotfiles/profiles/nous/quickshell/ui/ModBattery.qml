// Bateria. Fonte: UPower (services.upower.enable precisa estar ligado no
// sistema — modules/system/power.nix — senão isto mostra 0%/Unknown em
// silêncio, sem erro). percentage é 0.0–1.0, não 0–100.
import Quickshell.Services.UPower

BarModule {
    id: root
    showSeparator: false // último módulo da direita

    readonly property var bat: UPower.displayDevice
    readonly property real pct: bat?.percentage ?? 0
    readonly property bool charging: bat?.state === UPowerDeviceState.Charging
    readonly property bool critical: root.pct < 0.15 && !root.charging

    visible: bat?.isPresent ?? false

    readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    glyph: {
        if (root.charging)
            return "󰂄";
        if (bat?.state === UPowerDeviceState.FullyCharged)
            return "󰁹";
        const idx = Math.max(0, Math.min(9, Math.floor(root.pct * 10)));
        return root.icons[idx];
    }
    valueText: Math.round(root.pct * 100) + "%"

    tint: root.critical ? Theme.cAlert : (root.pct < 0.30 ? Theme.cWarning : Theme.cPrimary)
    valueColor: root.critical ? Theme.cAlert : (root.pct < 0.30 ? Theme.cWarning : Qt.alpha(Theme.cText, 0.85))
    inverted: root.critical
}
