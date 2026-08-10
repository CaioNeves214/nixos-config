// Temperatura da CPU. Substitui waybar-cpu-temp (que rodava `sensors`+`jq`
// a cada 5s via Process — o antipadrão que a skill proíbe). Sys resolve o
// hwmon do coretemp uma vez no startup e só faz FileView dali em diante.
BarModule {
    visible: Sys.tempAvailable
    glyph: "󰔏"
    valueText: Math.round(Sys.tempCelsius) + "°C"
    tint: Sys.tempCelsius >= 80 ? Theme.cWarning : Theme.cPrimary
    valueColor: Sys.tempCelsius >= 80 ? Theme.cWarning : Qt.alpha(Theme.cText, 0.85)
}
