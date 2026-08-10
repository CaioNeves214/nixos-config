// Título da janela ativa. Era impossível na waybar deste perfil: o módulo
// hyprland/window tem largura VARIÁVEL, e isso quebrava o offset fixo que o
// widget de mídia calculava contra a pilha de workspaces (por isso foi
// removido — ver o comentário em waybar-config.jsonc). Sem esse offset a
// resolver, aqui é só um Text com largura fixa e elide.
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland

Text {
    readonly property var toplevel: ToplevelManager.activeToplevel

    Layout.preferredWidth: 220
    elide: Text.ElideRight
    text: toplevel ? toplevel.title : ""
    color: Qt.alpha(Theme.cText, 0.6)
    font.family: Theme.uiFont
    font.pixelSize: 12
}
