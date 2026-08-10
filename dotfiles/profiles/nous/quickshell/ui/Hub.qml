// Gatilho central da barra: glyph de mídia + visualizer + relógio, numa
// linha. Hover ou click expande o HubPanel logo abaixo (drop-down clipado,
// gotchas §1). Lógica MPRIS preservada verbatim do shell.qml original deste
// perfil — filtro por trackTitle não-vazio (players fantasma do
// Brave/Chromium, gotchas §8) e o playerTick (position não emite sinal de
// mudança, gotchas §7).
//
// Largura FIXA em Theme.panelWidth: o HubPanel nasce exatamente com essa
// largura, e ficar com o mesmo x/width aqui é o que permite ao Bar.qml
// montar a região de máscara do painel só com `hub.x` — sem mapear
// coordenadas entre itens (ver Bar.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    // Ver comentário em Bar.qml / ModVolume.qml sobre por que
    // `anchor.window: QsWindow.window` crasha e precisa vir por propriedade.
    property var barWindow: null

    implicitWidth: Theme.panelWidth
    implicitHeight: Theme.barHeight

    // ── Player ativo ─────────────────────────────────────────────────────
    readonly property var activePlayers: Mpris.players.values.filter(function (p) {
        return p.trackTitle && p.trackTitle.length > 0;
    })
    readonly property MprisPlayer player: {
        const ps = root.activePlayers;
        if (ps.length === 0)
            return null;
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying)
                return ps[i];
        }
        return ps[0];
    }
    // `hasPlayer`/`isPlaying` só servem para toggles booleanos (visible,
    // Layout.preferredWidth) — NUNCA para guardar leitura de `.x` do player.
    // Ver o comentário no topo de PanelMedia.qml: duas propriedades
    // derivadas separadamente do mesmo Mpris.players.values não atualizam
    // atomicamente, e isso já derrubou bindings aqui com "Cannot read
    // property of null" ao vivo, com um player real tocando.
    readonly property bool hasPlayer: root.player !== null
    readonly property bool isPlaying: root.player?.isPlaying ?? false

    // position não emite PropertiesChanged na maioria dos players (caro no
    // D-Bus) — este tick força a reavaliação dos bindings de progresso.
    property bool playerTick: false
    Timer {
        interval: 1000
        running: root.isPlaying && root.expanded
        repeat: true
        onTriggered: root.playerTick = !root.playerTick
    }

    // ── Estado de expansão ───────────────────────────────────────────────
    property bool pinned: false // travado aberto via IPC/click
    readonly property bool expanded: triggerHover.hovered || panel.hovered || root.pinned

    IpcHandler {
        target: "media"

        function toggle(): void {
            root.pinned = !root.pinned;
        }
        function playPause(): void {
            root.player?.togglePlaying();
        }
        function next(): void {
            const p = root.player;
            if (p?.canGoNext)
                p.next();
        }
        function previous(): void {
            const p = root.player;
            if (p?.canGoPrevious)
                p.previous();
        }
        function status(): string {
            const p = root.player;
            return p ? (p.trackArtist + " — " + p.trackTitle) : "";
        }
    }

    // ── Gatilho (sempre visível na faixa da barra) ──────────────────────
    RowLayout {
        id: triggerRow
        anchors.centerIn: parent
        spacing: 8

        Item {
            id: mediaZone
            readonly property int glyphW: 18
            readonly property int visualizerW: visualizer.bars * visualizer.barW + (visualizer.bars - 1) * visualizer.spacing

            Layout.preferredWidth: root.hasPlayer ? (glyphW + 6 + visualizerW) : 0
            Layout.preferredHeight: Theme.barHeight
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.0
                }
            }

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    Layout.preferredWidth: mediaZone.glyphW
                    horizontalAlignment: Text.AlignHCenter
                    text: ""
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                    color: root.isPlaying ? Theme.cPrimary : Qt.alpha(Theme.cText, 0.55)
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                Visualizer {
                    id: visualizer
                    active: root.isPlaying
                }
            }
        }

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.monoFont
            font.pixelSize: Theme.clockFontSize
            font.weight: Theme.clockFontWeight
            color: Theme.cPrimary
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    HoverHandler {
        id: triggerHover
    }
    TapHandler {
        onTapped: root.pinned = !root.pinned
    }

    // ── Painel (drop-down clipado, mesma superfície da barra) ───────────
    HubPanel {
        id: panel
        anchors.top: parent.top
        anchors.topMargin: Theme.barHeight
        anchors.left: parent.left
        width: Theme.panelWidth
        expanded: root.expanded
        player: root.player
        playerTick: root.playerTick
    }
}
