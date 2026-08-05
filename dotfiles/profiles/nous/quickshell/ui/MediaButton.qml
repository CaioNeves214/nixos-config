// Botão de ícone do card de mídia: glyph Nerd Font + realce de hover.
// Componentizado porque são 5 botões (shuffle/prev/play/next/loop) com o mesmo
// comportamento — e porque componente inline (`component X: Item {}`) não pode
// acessar ids do arquivo que o contém, então tudo entra por propriedade.
import QtQuick

Item {
    id: btn

    property string glyph
    property int glyphSize: 16
    property string iconFont: "Symbols Nerd Font"
    // active=false não é só cor: desliga o TapHandler (respeita canGoNext/
    // canGoPrevious/canSeek do MPRIS em vez de chamar método que o player recusa).
    property bool active: true
    property color tint: "#0000F2"

    signal activated

    implicitWidth: glyphSize + 14
    implicitHeight: glyphSize + 10

    opacity: btn.active ? 1 : 0.32
    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: 0 // DESIGN.md: cantos retos
        color: hover.hovered && btn.active ? Qt.alpha(btn.tint, 0.16) : "transparent"
        border.width: 0 // workaround QTBUG-137166 (transparente + border = buraco)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        font.family: btn.iconFont
        font.pixelSize: btn.glyphSize
        color: btn.tint
    }

    HoverHandler { id: hover }

    TapHandler {
        enabled: btn.active
        onTapped: btn.activated()
    }
}
