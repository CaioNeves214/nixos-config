// Daemon de notificações. Hoje NENHUM roda neste host (sem mako/dunst nos
// exec-once) — o Quickshell vira o daemon. keepOnReload evita perder
// notificações no live-reload durante o desenvolvimento; sem
// `notif.tracked = true` a notificação é descartada na hora.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

Scope {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        actionsSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
        }
    }

    PanelWindow {
        anchors {
            top: true
            right: true
        }
        exclusiveZone: 0
        margins.top: 0 // a barra reserva 42 — cai em y=42 sozinho, sem aritmética
        color: "transparent"
        implicitWidth: 340
        implicitHeight: Math.max(1, stack.implicitHeight)

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"

        mask: Region {
            item: stack
        }

        ColumnLayout {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                delegate: Rectangle {
                    id: toast
                    required property var modelData

                    readonly property bool critical: toast.modelData.urgency === NotificationUrgency.Critical

                    Layout.fillWidth: true
                    implicitHeight: toastColumn.implicitHeight + Theme.gridDouble * 2
                    radius: Theme.radiusSharp
                    color: Theme.cBg
                    opacity: 0.94
                    border.width: 1
                    border.color: toast.critical ? Theme.cAlert : Qt.alpha(Theme.cPrimary, 0.25)

                    Timer {
                        // expireTimeout vem em ms; -1 = default do servidor, 0 = nunca.
                        readonly property int effective: toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : 6000
                        running: toast.modelData.expireTimeout !== 0
                        interval: effective
                        onTriggered: toast.modelData.dismiss()
                    }

                    ColumnLayout {
                        id: toastColumn
                        anchors.fill: parent
                        anchors.margins: Theme.gridDouble
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconImage {
                                visible: toast.modelData.appIcon.length > 0
                                implicitSize: 16
                                source: toast.modelData.appIcon.length > 0 ? Quickshell.iconPath(toast.modelData.appIcon, true) : ""
                            }

                            Text {
                                Layout.fillWidth: true
                                text: toast.modelData.summary
                                color: toast.critical ? Theme.cAlert : Theme.cText
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "×"
                                color: Qt.alpha(Theme.cText, 0.5)
                                font.pixelSize: 16
                                TapHandler {
                                    onTapped: toast.modelData.dismiss()
                                }
                            }
                        }

                        Text {
                            visible: toast.modelData.body.length > 0
                            Layout.fillWidth: true
                            text: toast.modelData.body
                            textFormat: Text.StyledText
                            color: Qt.alpha(Theme.cText, 0.7)
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            visible: toast.modelData.actions.length > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 6

                            Repeater {
                                model: toast.modelData.actions
                                delegate: Rectangle {
                                    id: actionBtn
                                    required property var modelData

                                    implicitWidth: actionLabel.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: Theme.radiusSharp
                                    color: actionHover.hovered ? Theme.cPrimary : Qt.alpha(Theme.cPrimary, 0.14)

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: actionBtn.modelData.text
                                        color: actionHover.hovered ? Theme.cBg : Theme.cPrimary
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                    }

                                    HoverHandler {
                                        id: actionHover
                                    }
                                    TapHandler {
                                        onTapped: actionBtn.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: toast.modelData.dismiss()
                    }
                }
            }
        }
    }
}
