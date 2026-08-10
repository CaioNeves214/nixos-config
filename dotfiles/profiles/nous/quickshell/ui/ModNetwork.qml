// Rede. Fonte: Sys (nmcli via Process) — Quickshell.Networking existe neste
// build mas fica permanentemente vazio neste sistema (ver o comentário em
// Sys.qml). Sem on-click (a waybar também não tinha). Desconectado ->
// @alert (única exceção à cor única do perfil, junto com bateria crítica).
BarModule {
    id: root

    readonly property bool connected: Sys.networkKind !== "disconnected"
    readonly property bool isWifi: Sys.networkKind === "wifi"

    glyph: {
        if (!root.connected)
            return "󰖪";
        if (!root.isWifi)
            return "󰈀";
        return Sys.networkSignal > 66 ? "󰖩" : (Sys.networkSignal > 33 ? "󰖩" : "󰤯");
    }
    valueText: {
        if (!root.connected)
            return "Off";
        if (!root.isWifi)
            return "Cabo";
        return Sys.networkSignal + "%";
    }
    tint: root.connected ? Theme.cPrimary : Theme.cAlert
    valueColor: root.connected ? Qt.alpha(Theme.cText, 0.85) : Theme.cAlert
}
