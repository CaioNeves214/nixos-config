// Página de mídia do hub — porte direto do card do shell.qml original deste
// perfil (capa, metadados, seek, controles). `player` chega de Hub.qml
// (fonte única do MPRIS); esta página só desenha.
//
// Toda leitura de propriedade do player usa `root.player?.x ?? default`,
// NUNCA um booleano `hasPlayer` separado como guarda (`hasPlayer && player.x`).
// `hasPlayer` e `player` são propriedades QML distintas: quando o player some,
// as duas são recomputadas por bindings INDEPENDENTES, sem garantia de ordem
// atômica entre elas — há uma janela real em que uma já mudou e a outra
// ainda não, e `player.x` explode com "Cannot read property of null" bem no
// meio dessa janela (raça confirmada ao vivo com um MPRIS real tocando: os
// dois QtQuick não crasham — gotchas §14 — mas o log enche de TypeError).
// `?.`/`??` é atômico porque não depende de uma segunda propriedade.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris

ColumnLayout {
    id: root

    property var player: null
    property bool playerTick: false

    readonly property bool hasPlayer: root.player !== null // só para visible/height — nunca para ler .x do player

    spacing: 8

    function fmtTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds))
            return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // ── Estado vazio ─────────────────────────────────────────────────────
    Text {
        Layout.fillWidth: true
        visible: !root.hasPlayer
        Layout.preferredHeight: visible ? implicitHeight : 0
        text: "Nada tocando"
        color: Qt.alpha(Theme.cText, 0.4)
        font.family: Theme.uiFont
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Capa + metadados ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: root.hasPlayer
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: 12

        // ClippingRectangle, não Rectangle+clip: clip comum recorta no
        // retângulo, ignorando o radius (aqui é 0, mas mantém o padrão).
        ClippingRectangle {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            radius: Theme.radiusSharp
            color: Qt.alpha(Theme.cPrimary, 0.12)

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !(root.player?.trackArtUrl)
                text: ""
                font.family: Theme.iconFont
                font.pixelSize: 20
                color: Qt.alpha(Theme.cPrimary, 0.5)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? ""
                color: Theme.cText
                // Único "display" do painel: serif, peso leve — a voz
                // editorial do DESIGN.md ("weight 300 for headings").
                font.family: Theme.displayFont
                font.pixelSize: 15
                font.weight: Font.Light
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                color: Qt.alpha(Theme.cText, 0.7)
                font.family: Theme.uiFont
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: root.player?.identity ?? ""
                color: Qt.alpha(Theme.cText, 0.4)
                font.family: Theme.uiFont
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    // ── Progresso (clicável para seek) ──────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.hasPlayer ? 12 : 0
        visible: root.hasPlayer

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: Theme.radiusSharp
            color: Qt.alpha(Theme.cPrimary, 0.18)

            Rectangle {
                height: parent.height
                radius: Theme.radiusSharp
                color: Theme.cPrimary
                // (playerTick || true) só existe para criar a dependência —
                // position não emite sinal de mudança (gotchas §7).
                width: {
                    const p = root.player;
                    return (root.playerTick || true) && p && p.length > 0 ? parent.width * Math.min(1, p.position / p.length) : 0;
                }
            }
        }

        TapHandler {
            enabled: (root.player?.canSeek ?? false) && (root.player?.length ?? 0) > 0
            onTapped: eventPoint => {
                const p = root.player;
                if (!p)
                    return;
                const frac = Math.max(0, Math.min(1, eventPoint.position.x / track.width));
                p.position = frac * p.length;
                root.playerTick = !root.playerTick;
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.hasPlayer
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: 0

        Text {
            text: {
                const p = root.player;
                return (root.playerTick || true) && p ? root.fmtTime(p.position) : "0:00";
            }
            color: Qt.alpha(Theme.cText, 0.6)
            font.family: Theme.monoFont
            font.pixelSize: 11
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            text: root.fmtTime(root.player?.length ?? 0)
            color: Qt.alpha(Theme.cText, 0.6)
            font.family: Theme.monoFont
            font.pixelSize: 11
        }
    }

    // ── Controles ────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: root.hasPlayer
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: 4

        MediaButton {
            visible: root.player?.shuffleSupported ?? false
            glyph: "󰒝"
            glyphSize: 13
            tint: (root.player?.shuffle ?? false) ? Theme.cPrimary : Qt.alpha(Theme.cText, 0.45)
            onActivated: {
                const p = root.player;
                if (p)
                    p.shuffle = !p.shuffle;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        MediaButton {
            glyph: "󰒮"
            tint: Theme.cPrimary
            active: root.player?.canGoPrevious ?? false
            onActivated: root.player?.previous()
        }
        MediaButton {
            glyph: (root.player?.isPlaying ?? false) ? "󰏤" : "󰐊"
            glyphSize: 20
            tint: Theme.cPrimary
            active: root.player?.canTogglePlaying ?? false
            onActivated: root.player?.togglePlaying()
        }
        MediaButton {
            glyph: "󰒭"
            tint: Theme.cPrimary
            active: root.player?.canGoNext ?? false
            onActivated: root.player?.next()
        }

        Item {
            Layout.fillWidth: true
        }

        // Um glyph só para os três modos; o estado é a cor: apagado = off,
        // primary = playlist, secondary = faixa.
        MediaButton {
            visible: root.player?.loopSupported ?? false
            glyph: "󰑖"
            glyphSize: 13
            tint: {
                const p = root.player;
                if (!p || p.loopState === MprisLoopState.None)
                    return Qt.alpha(Theme.cText, 0.45);
                return p.loopState === MprisLoopState.Track ? Theme.cSecondary : Theme.cPrimary;
            }
            onActivated: {
                const p = root.player;
                if (!p)
                    return;
                const s = p.loopState;
                p.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
            }
        }
    }
}
