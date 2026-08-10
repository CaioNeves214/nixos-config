// Uso de CPU. Fonte: Sys (delta entre amostras de /proc/stat).
BarModule {
    glyph: "󰍛"
    valueText: Math.round(Sys.cpuUsage * 100) + "%"
}
