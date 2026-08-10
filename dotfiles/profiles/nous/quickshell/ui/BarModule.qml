// Base reutilizável dos módulos de status da direita (tray excluído — ele é
// uma linha de ícones, não glyph+valor). Porta waybar/style.css:
// - padding 3.5px 10.5px, min-width 52 (a barra nunca "pula" de largura)
// - hover: fundo alpha(primary, 0.14), texto -> text
// - régua de 1px em alpha(text, 0.08) entre módulos
// - ícone e valor são dois Text INDEPENDENTES (era impossível na waybar,
//   onde os dois viviam no mesmo label GTK — DESIGN.md, limitação #1)
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string glyph: ""
    property string valueText: ""
    property color tint: Theme.cPrimary
    property color valueColor: Qt.alpha(Theme.cText, 0.85)
    property bool showSeparator: true
    // Estado crítico: inverte o bloco (fundo sólido no tint, texto no bg) em
    // vez de piscar — "precise, technical", não decorativo.
    property bool inverted: false

    readonly property alias hovered: hover.hovered

    signal clicked
    signal scrolledUp
    signal scrolledDown

    implicitHeight: Theme.barHeight
    implicitWidth: Math.max(Theme.statusMinWidth, row.implicitWidth + Theme.gridOneAndHalf * 2)

    Rectangle {
        anchors.fill: parent
        color: root.inverted ? Qt.alpha(root.tint, 0.9) : (hover.hovered ? Theme.hoverBg : "transparent")
        border.width: 0 // workaround QTBUG-137166
        Behavior on color {
            ColorAnimation {
                duration: Theme.animFast
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: Theme.grid
        anchors.bottomMargin: Theme.grid
        width: 1
        color: Theme.separatorColor
        visible: root.showSeparator
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            visible: root.glyph.length > 0
            text: root.glyph
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: root.inverted ? Theme.cBg : (hover.hovered ? Theme.cText : root.tint)
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }

        Text {
            visible: root.valueText.length > 0
            text: root.valueText
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSize
            color: root.inverted ? Theme.cBg : (hover.hovered ? Theme.cText : root.valueColor)
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.clicked()
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y > 0)
                root.scrolledUp();
            else if (event.angleDelta.y < 0)
                root.scrolledDown();
        }
    }
}
