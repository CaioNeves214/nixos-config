// Volume. PwObjectTracker é obrigatório (gotchas §9 / api-services.md nota
// final) — sem ele audio.volume/muted não atualizam, em silêncio. Scroll
// escreve volume direto (0.0–1.0); click abre um seletor de saída.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

BarModule {
    id: root

    // Setado explicitamente pelo Bar.qml — ver o comentário em Bar.qml sobre
    // por que `anchor.window: QsWindow.window` crasha aqui.
    property var hostWindow: null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker {
        objects: [root.sink]
    }

    glyph: root.muted ? "󰝟" : (root.volume > 0.66 ? "󰕾" : (root.volume > 0.01 ? "󰖀" : "󰕿"))
    valueText: root.muted ? "Mudo" : Math.round(root.volume * 100) + "%"
    valueColor: root.muted ? Qt.alpha(Theme.cText, 0.28) : Qt.alpha(Theme.cText, 0.85)
    tint: root.muted ? Qt.alpha(Theme.cText, 0.28) : Theme.cPrimary

    onScrolledUp: if (root.sink?.audio)
        root.sink.audio.volume = Math.min(1, root.volume + 0.05)
    onScrolledDown: if (root.sink?.audio)
        root.sink.audio.volume = Math.max(0, root.volume - 0.05)
    onClicked: outputPopup.visible = !outputPopup.visible

    PopupWindow {
        id: outputPopup
        anchor.window: root.hostWindow
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        visible: false
        color: "transparent"
        implicitWidth: 260
        implicitHeight: outputCol.implicitHeight + Theme.gridDouble * 2

        readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && n.audio && !n.isStream)

        PwObjectTracker {
            objects: outputPopup.sinks
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.cBg
            radius: Theme.radiusSharp
            border.width: 1
            border.color: Theme.borderBottom

            ColumnLayout {
                id: outputCol
                anchors.fill: parent
                anchors.margins: Theme.gridDouble
                spacing: Theme.grid

                Text {
                    text: "Saída de áudio"
                    color: Qt.alpha(Theme.cText, 0.5)
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }

                Repeater {
                    model: outputPopup.sinks
                    delegate: Rectangle {
                        id: entry
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 30
                        color: entry.modelData === root.sink ? Theme.cPrimary : (entryHover.hovered ? Qt.alpha(Theme.cPrimary, 0.14) : "transparent")
                        radius: Theme.radiusSharp

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Theme.gridHalf
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: entry.modelData.description || entry.modelData.name
                            color: entry.modelData === root.sink ? Theme.cBg : Theme.cText
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                        }

                        HoverHandler {
                            id: entryHover
                        }
                        TapHandler {
                            onTapped: {
                                Pipewire.preferredDefaultAudioSink = entry.modelData;
                                outputPopup.visible = false;
                            }
                        }
                    }
                }
            }
        }

        HyprlandFocusGrab {
            active: outputPopup.visible
            windows: [outputPopup]
            onCleared: outputPopup.visible = false
        }
    }
}
