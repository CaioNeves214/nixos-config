// OSD de volume e brilho. Substitui waybar-volume-popup (GTK3, que arrasta
// GI_TYPELIB_PATH e 5 windowrulev2). Superfície própria, ancorada embaixo,
// exclusiveZone: 0 (não empurra nada).
//
// Brilho tem latência de até ~2s: Sys.backlightFrac só é atualizado pelo
// Timer de polling em Sys.qml (não há sinal nativo de /sys), diferente do
// volume, que reage instantaneamente ao sinal onVolumeChanged do Pipewire.
// Aceitável — é OSD de feedback, não controle em tempo real.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: osd

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [osd.sink]
    }

    property string kind: "volume" // "volume" | "backlight"
    property bool showing: false

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.showing = false
    }

    Connections {
        target: osd.sink?.audio ?? null
        function onVolumeChanged() {
            osd.kind = "volume";
            osd.showing = true;
            hideTimer.restart();
        }
        function onMutedChanged() {
            osd.kind = "volume";
            osd.showing = true;
            hideTimer.restart();
        }
    }

    Connections {
        target: Sys
        function onBacklightFracChanged() {
            osd.kind = "backlight";
            osd.showing = true;
            hideTimer.restart();
        }
    }

    anchors {
        bottom: true
    }
    margins.bottom: 80
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 260
    implicitHeight: 60
    visible: osd.showing

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    mask: Region {
        item: card
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.cBg
        opacity: 0.94
        radius: Theme.radiusSharp
        border.width: 1
        border.color: Qt.alpha(Theme.cPrimary, 0.25)

        readonly property real value: osd.kind === "volume" ? (osd.sink?.audio?.muted ? 0 : (osd.sink?.audio?.volume ?? 0)) : Sys.backlightFrac
        readonly property bool muted: osd.kind === "volume" && (osd.sink?.audio?.muted ?? false)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.gridDouble
            spacing: 12

            Text {
                text: {
                    if (osd.kind === "backlight")
                        return "󰃟";
                    if (card.muted)
                        return "󰝟";
                    return card.value > 0.66 ? "󰕾" : (card.value > 0.01 ? "󰖀" : "󰕿");
                }
                font.family: Theme.iconFont
                font.pixelSize: 18
                color: Theme.cPrimary
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: Theme.radiusSharp
                color: Qt.alpha(Theme.cPrimary, 0.18)

                Rectangle {
                    height: parent.height
                    radius: Theme.radiusSharp
                    color: Theme.cPrimary
                    width: parent.width * Math.min(1, card.value)
                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
            }

            Text {
                text: Math.round(card.value * 100) + "%"
                color: Theme.cText
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
