// Uso de memória. Fonte: Sys (/proc/meminfo).
BarModule {
    glyph: "󰘚"
    valueText: Math.round(Sys.memUsedFrac * 100) + "%"
}
