// Pílula de workspaces. Porta waybar/style.css #workspaces: focado é bloco
// sólido @primary com texto @base (o gesto do .btn-primary do DESIGN.md),
// urgente em @alert. Largura animada no foco — patterns.md §5, sem raio
// (DESIGN.md: cantos retos em tudo).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

RowLayout {
    id: root
    spacing: 4

    readonly property var sortedWorkspaces: {
        const arr = Hyprland.workspaces.values.filter(w => w.id > 0);
        arr.sort((a, b) => a.id - b.id);
        return arr;
    }

    Repeater {
        model: root.sortedWorkspaces

        delegate: Rectangle {
            id: pill
            required property var modelData

            readonly property bool focused: modelData.focused
            readonly property bool urgent: modelData.urgent

            Layout.preferredHeight: 20
            Layout.preferredWidth: label.implicitWidth + (focused ? 24 : 18)
            radius: Theme.radiusSharp
            color: focused ? Theme.cPrimary : (urgent ? Theme.cAlert : (hover.hovered ? Qt.alpha(Theme.cText, 0.07) : "transparent"))
            border.width: 0 // workaround QTBUG-137166

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: Theme.animNormal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: pill.modelData.name
                font.family: Theme.monoFont
                font.pixelSize: Theme.workspaceFontSize
                color: (pill.focused || pill.urgent) ? Theme.cBg : Qt.alpha(Theme.cText, 0.32)
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
            }

            HoverHandler {
                id: hover
            }

            TapHandler {
                onTapped: pill.modelData.activate()
            }
        }
    }
}
