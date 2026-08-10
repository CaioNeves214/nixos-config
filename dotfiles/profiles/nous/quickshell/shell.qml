// Perfil "nous": barra Quickshell própria, substituindo a waybar deste
// perfil por completo (o perfil "default" continua na waybar, intocado).
// Este arquivo só compõe — toda a implementação mora em ui/. Ver
// docs/quickshell-bar-nous.md para a arquitetura completa (superfícies,
// mask, hub, extensão) e cada DESIGN.md do perfil para o porquê visual.
import Quickshell
import "ui"

ShellRoot {
    Bar {}
    Notifications {}
    Osd {}
}
