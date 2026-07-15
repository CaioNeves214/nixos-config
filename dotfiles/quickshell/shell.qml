// Widget de mídia: thumb sempre visível na faixa da waybar, expande num
// card drop-down no hover (recolhe no mouse-leave). Substitui o antigo
// group/mediaplayer da waybar; controle via MPRIS nativo do Quickshell
// (sem polling bash). Cores: paleta wallust (design system), lida em
// runtime de ~/.config/quickshell/colors.json com fallback embutido.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property var colors: ({
        background: "#1e1e2e",
        foreground: "#cdd6f4",
        primary:    "#89b4fa",
        secondary:  "#a6e3a1",
        alert:      "#f38ba8",
        text:       "#cdd6f4"
    })

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colors = JSON.parse(text())
            } catch (e) {
                console.warn("quickshell media: falha ao ler colors.json, mantendo paleta fallback:", e)
            }
        }
    }

    property var players: Mpris.players.values
    property MprisPlayer player: players.length > 0 ? players[0] : null
    property bool hasPlayer: player !== null
    property bool expanded: false
    property bool playerTick: false

    function fmtTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds)) return "0:00"
        var s = Math.floor(seconds)
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    function withAlpha(hex, a) {
        var h = hex.replace("#", "")
        var ah = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16).padStart(2, "0")
        return "#" + ah + h
    }

    PanelWindow {
        id: panel

        property int barHeight: 42
        // Altura do card = altura real do conteúdo (ColumnLayout) + as duas
        // margens de 14px. Antes era um valor fixo (132) menor que o
        // necessário, o que cortava a linha de controles (prev/play/next) —
        // por isso vem do próprio conteúdo agora, não de um número mágico.
        property int cardHeight: cardColumn.implicitHeight + 28

        anchors { top: true; left: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-media"

        // Sem player MPRIS registrado: some por completo (não fica nem o
        // ícone na waybar). Some a superfície inteira, não só o thumb, para
        // não sobrar uma área invisível "morta" recebendo hover por engano.
        visible: root.hasPlayer

        // Tamanho FIXO da superfície layer-shell (nunca anima). Animar o
        // implicitHeight de um PanelWindow exige reconfigurar a superfície
        // Wayland a cada frame — o Hyprland não faz isso de forma suave, e é
        // isso (não um crash real) que causava o card aparecer "cortado pela
        // metade": o buffer antigo (menor) ficava visível até o próximo
        // commit. A animação de abrir/fechar agora acontece só dentro da
        // superfície, no clip do card (ver cardClip abaixo).
        implicitWidth: 320
        implicitHeight: barHeight + cardHeight

        // Alinha logo após o grupo modules-left da waybar. Com o módulo
        // hyprland/window removido (waybar-config.jsonc), modules-left só
        // tem os 5 botões de workspace — largura agora estável, então este
        // offset fixo é viável (antes o título de janela tinha largura
        // variável e nunca alinhava). Se o número de workspaces mudar,
        // reajustar visualmente.
        //
        // top é NEGATIVO de propósito: a waybar reserva uma exclusiveZone de
        // 52px no topo (44px de altura + 8px de margin-top dela), e o
        // Hyprland ancora superfícies layer-shell a partir do fim da área
        // reservada de outras camadas, não do topo físico da tela — sem essa
        // correção o widget nascia em y=60 (52 + 8), bem abaixo da waybar.
        // Confirmado via `hyprctl layers`/`hyprctl monitors` (campo
        // "reserved"). 8 - 52 = -44 traz de volta para y=8, igual à waybar.
        margins {
            top: -44
            left: 205
        }

        // Timer só para forçar reavaliação de position/length enquanto toca.
        Timer {
            interval: 1000
            running: root.hasPlayer && root.player.isPlaying
            repeat: true
            onTriggered: root.playerTick = !root.playerTick
        }

        // Hover restrito ao ícone e ao card (não à faixa inteira de 320px do
        // painel) — o HoverHandler segue a geometria do seu Item pai, não da
        // propriedade 'target', então cada um é declarado dentro do item que
        // deve ser monitorado.
        Binding {
            target: root
            property: "expanded"
            value: thumbHover.hovered || cardHover.hovered
        }

        Rectangle {
            id: thumb
            width: panel.barHeight
            height: panel.barHeight
            radius: 12
            color: "transparent"

            HoverHandler {
                id: thumbHover
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 9
                // Mesma opacidade do pill .modules-left da waybar
                // (alpha(@base, 0.88) em style.css) para o thumb ler como
                // parte da mesma barra, não um card solto sobre o wallpaper.
                color: root.withAlpha(root.colors.background, 0.88)
                border.color: root.withAlpha(root.colors.primary, 0.35)
                border.width: 1
            }

            Item {
                anchors.fill: parent
                anchors.margins: 5
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: (root.hasPlayer && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !art.visible
                text: "\u{f001}"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: root.colors.primary
            }
        }

        // Clip com altura animada: a superfície Wayland já nasce no tamanho
        // máximo (fixo), então esta animação é só uma propriedade QML normal
        // dentro dela — suave, sem depender de reconfigurar o layer-shell.
        Item {
            id: cardClip
            anchors.top: thumb.bottom
            anchors.left: parent.left
            width: panel.implicitWidth
            height: root.expanded ? panel.cardHeight : 0
            clip: true

            Behavior on height {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            HoverHandler {
                id: cardHover
            }

        Rectangle {
            id: card
            width: parent.width
            height: panel.cardHeight
            radius: 14
            color: root.colors.background
            opacity: root.expanded ? 0.94 : 0
            border.color: root.withAlpha(root.colors.primary, 0.25)
            border.width: 1

            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: cardColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        radius: 10
                        color: root.withAlpha(root.colors.primary, 0.12)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.hasPlayer && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: source !== ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.hasPlayer ? root.player.trackTitle : ""
                            color: root.colors.text
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.hasPlayer ? root.player.trackArtist : ""
                            color: root.withAlpha(root.colors.text, 0.7)
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: root.withAlpha(root.colors.primary, 0.18)

                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: root.colors.primary
                        // Referenciar playerTick força reavaliação a cada tick do Timer
                        // (position não emite change signal próprio na maioria dos players).
                        width: (root.playerTick || true) && root.hasPlayer && root.player.length > 0
                            ? parent.width * Math.min(1, root.player.position / root.player.length)
                            : 0
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: (root.playerTick || true) && root.hasPlayer ? root.fmtTime(root.player.position) : "0:00"
                        color: root.withAlpha(root.colors.text, 0.6)
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.hasPlayer ? root.fmtTime(root.player.length) : "0:00"
                        color: root.withAlpha(root.colors.text, 0.6)
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 18

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "\u{f048}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: (root.hasPlayer && root.player.canGoPrevious) ? root.colors.primary : root.withAlpha(root.colors.text, 0.3)
                        TapHandler {
                            enabled: root.hasPlayer && root.player.canGoPrevious
                            onTapped: root.player.previous()
                        }
                    }

                    Text {
                        text: (root.hasPlayer && root.player.isPlaying) ? "\u{f04c}" : "\u{f04b}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                        color: root.colors.primary
                        TapHandler {
                            enabled: root.hasPlayer
                            onTapped: root.player.togglePlaying()
                        }
                    }

                    Text {
                        text: "\u{f051}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: (root.hasPlayer && root.player.canGoNext) ? root.colors.primary : root.withAlpha(root.colors.text, 0.3)
                        TapHandler {
                            enabled: root.hasPlayer && root.player.canGoNext
                            onTapped: root.player.next()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
        }
    }
}
