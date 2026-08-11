// System tray. show-passive-items: true (waybar-config.jsonc) — não filtra
// por Status.Passive, só reduz a opacidade. NeedsAttention ganha destaque em
// @alert (a waybar não fazia isso). Menu desenhado por nós via QsMenuOpener
// (mora em Quickshell core, não em Quickshell.DBusMenu); acionar item é
// EMITIR entry.triggered() — não existe função trigger().
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray

RowLayout {
    id: root
    spacing: 0

    property var hostWindow: null // ver comentário em Bar.qml / ModVolume.qml
    property var menuTarget: null

    // blueman: redundante — ModBluetooth.qml já mostra estado/ligar-desligar do adaptador.
    // udiskie: fora por preferência do usuário (era também o ícone que ficava quebrado —
    // drive-removable-media só existe no tema Adwaita, não registrado no sistema).
    readonly property var hiddenTrayIds: ["blueman", "udiskie"]
    readonly property var visibleItems: SystemTray.items.values.filter(it => root.hiddenTrayIds.indexOf(it.id) === -1)

    Repeater {
        model: root.visibleItems
        delegate: Item {
            id: entry
            required property var modelData

            Layout.preferredWidth: Theme.barHeight
            Layout.preferredHeight: Theme.barHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                color: entry.modelData.status === Status.NeedsAttention ? Qt.alpha(Theme.cAlert, 0.22) : (hover.hovered ? Theme.hoverBg : "transparent")
                border.width: 0 // workaround QTBUG-137166
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                asynchronous: true
                opacity: entry.modelData.status === Status.Passive ? 0.5 : 1

                // `SystemTrayItem.icon` já vem como URL `image://icon/...` PRONTA nesta versão
                // do Quickshell — não é um nome de tema cru. Passá-la por
                // `Quickshell.iconPath(nome, fallback)` prefixa a URL de novo (inválida, falha
                // sempre); use o valor direto, como em `patterns.md` #7.
                source: entry.modelData.icon
            }

            HoverHandler {
                id: hover
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // tapped(eventPoint, button) — button é o SEGUNDO parâmetro do sinal, não
                // eventPoint.event.button (isso não existe; TypeError confirmado ao vivo).
                onTapped: (eventPoint, button) => {
                    if (button === Qt.RightButton && entry.modelData.hasMenu) {
                        root.menuTarget = entry.modelData.menu;
                        trayMenu.visible = true;
                    } else {
                        entry.modelData.activate();
                    }
                }
            }
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.menuTarget
    }

    PopupWindow {
        id: trayMenu
        anchor.window: root.hostWindow
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 6
        visible: false
        color: "transparent"
        implicitWidth: 200
        implicitHeight: menuCol.implicitHeight + Theme.grid * 2

        Rectangle {
            anchors.fill: parent
            color: Theme.cBg
            radius: Theme.radiusSharp
            border.width: 1
            border.color: Theme.borderBottom

            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: Theme.grid
                spacing: 0

                Repeater {
                    model: opener.children
                    delegate: Item {
                        id: item
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: item.modelData.isSeparator ? 9 : 26

                        Rectangle {
                            visible: item.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 1
                            color: Theme.separatorColor
                        }

                        Rectangle {
                            visible: !item.modelData.isSeparator
                            anchors.fill: parent
                            color: itemHover.hovered ? Qt.alpha(Theme.cPrimary, 0.14) : "transparent"

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: Theme.gridHalf
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: item.modelData.text
                                color: item.modelData.enabled ? Theme.cText : Qt.alpha(Theme.cText, 0.35)
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }

                            HoverHandler {
                                id: itemHover
                            }
                            TapHandler {
                                enabled: item.modelData.enabled
                                onTapped: {
                                    item.modelData.triggered();
                                    trayMenu.visible = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        HyprlandFocusGrab {
            active: trayMenu.visible
            windows: [trayMenu]
            onCleared: trayMenu.visible = false
        }
    }
}
