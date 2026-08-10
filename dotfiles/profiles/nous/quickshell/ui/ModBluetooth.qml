// Bluetooth. Fonte: Sys (bluetoothctl via Process) — Quickshell.Bluetooth
// existe neste build mas fica permanentemente vazio neste sistema (ver o
// comentário em Sys.qml). Click liga/desliga o adaptador via
// `bluetoothctl power`; o valor mostra quantos dispositivos conectados.
BarModule {
    id: root

    glyph: Sys.btPowered ? "󰂯" : "󰂲"
    valueText: (Sys.btPowered && Sys.btConnectedCount > 0) ? String(Sys.btConnectedCount) : ""
    tint: Sys.btPowered ? Theme.cPrimary : Qt.alpha(Theme.cText, 0.35)

    onClicked: Sys.toggleBluetooth()
}
