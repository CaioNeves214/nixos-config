// Drop-down do hub: clip animado (gotchas §1 — a SUPERFÍCIE da barra nunca
// muda de tamanho, só este Item por dentro dela). Abertura mais lenta com
// leve overshoot (300ms OutCubic), fechamento seco (190ms InCubic) — mesma
// assinatura do card de mídia original.
//
// Hospeda as páginas empilhadas num ColumnLayout. Extensão futura: nova
// página = novo PanelX.qml inserido aqui; Theme.panelZone é o único número
// a revisar para caber a soma máxima.
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool expanded: false
    property var player: null
    property bool playerTick: false

    readonly property alias hovered: hover.hovered
    readonly property int contentHeight: column.implicitHeight + Theme.gridDouble * 2

    clip: true
    height: 0

    state: root.expanded ? "open" : ""
    states: State {
        name: "open"
        PropertyChanges {
            target: root
            height: root.contentHeight
        }
    }
    transitions: [
        Transition {
            from: ""
            to: "open"
            NumberAnimation {
                target: root
                property: "height"
                duration: 300
                easing.type: Easing.OutCubic
            }
        },
        Transition {
            from: "open"
            to: ""
            NumberAnimation {
                target: root
                property: "height"
                duration: 190
                easing.type: Easing.InCubic
            }
        }
    ]

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: card
        width: parent.width
        height: root.contentHeight
        color: Theme.cBg
        radius: Theme.radiusSharp
        opacity: root.expanded ? 0.94 : 0
        border.width: 1
        border.color: Qt.alpha(Theme.cPrimary, 0.25)

        Behavior on opacity {
            NumberAnimation {
                duration: root.expanded ? 260 : 160
                easing.type: root.expanded ? Easing.OutCubic : Easing.InCubic
            }
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.gridDouble
            spacing: 12

            PanelMedia {
                Layout.fillWidth: true
                player: root.player
                playerTick: root.playerTick
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.separatorColor
            }

            PanelCalendar {
                Layout.fillWidth: true
            }
        }
    }
}
