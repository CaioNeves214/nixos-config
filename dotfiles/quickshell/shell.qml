// Widget de mídia: thumb discreto na faixa da waybar que, no hover, desce um
// card com capa, metadados, progresso (com seek) e controles. Substitui o
// antigo group/mediaplayer da waybar; os dados vêm do serviço MPRIS nativo do
// Quickshell (event-driven, sem polling bash). Cores: paleta wallust lida em
// runtime de ~/.config/quickshell/colors.json, com fallback embutido.
//
// Ver .claude/skills/quickshell/ — em especial gotchas §1 (nunca animar o
// tamanho da superfície layer-shell), §2 (HoverHandler segue o pai), §3
// (âncora parte da zona reservada), §4 (QTBUG-137166) e §7 (position do MPRIS
// não emite sinal de mudança).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    // ── Design system ────────────────────────────────────────────────────
    // Nenhum hex literal fora daqui: o fallback só existe porque colors.json é
    // gerado por `update-theme` e gitignored (num checkout limpo não existe).
    readonly property var fallbackColors: ({
        background: "#1e1e2e",
        foreground: "#cdd6f4",
        primary: "#89b4fa",
        secondary: "#a6e3a1",
        alert: "#f38ba8",
        text: "#cdd6f4"
    })
    property var colors: fallbackColors

    // Tokens tipados como `color`: JSON devolve string, e Qt.alpha() exige
    // color de verdade.
    readonly property color cBg: colors.background
    readonly property color cText: colors.text
    readonly property color cPrimary: colors.primary
    readonly property color cSecondary: colors.secondary

    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int animFast: 220
    readonly property int animNormal: 280

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true // só avisa da mudança; recarregar é com o onFileChanged
        blockLoading: true // 1ª leitura síncrona: nenhum frame com a paleta errada
        onFileChanged: reload()
        onLoaded: {
            try {
                // Merge sobre o fallback: garante que todo token existe mesmo se
                // o template ficar incompleto.
                root.colors = Object.assign({}, root.fallbackColors, JSON.parse(text()));
            } catch (e) {
                console.warn("quickshell media: colors.json inválido, mantendo fallback:", e);
            }
        }
    }

    // ── Player ativo ─────────────────────────────────────────────────────
    // Brave/Chromium se registram no MPRIS mesmo sem faixa carregada
    // (playbackState Stopped, trackTitle vazio) — filtrar por conteúdo real
    // evita o ícone do navegador preso na barra sem nada tocando.
    readonly property var activePlayers: Mpris.players.values.filter(function (p) {
        return p.trackTitle && p.trackTitle.length > 0;
    })
    // Com vários players, o que está tocando ganha do que está só pausado.
    readonly property MprisPlayer player: {
        const ps = activePlayers;
        if (ps.length === 0)
            return null;
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying)
                return ps[i];
        }
        return ps[0];
    }
    readonly property bool hasPlayer: player !== null

    // ── Alinhamento com a waybar ─────────────────────────────────────────
    // A pilha de workspaces da waybar NÃO tem largura fixa: `hyprland/workspaces`
    // só desenha os workspaces que existem, então a pill cresce quando um novo
    // aparece — um offset constante desalinha na primeira troca de workspace.
    // Medido com grim contra a barra viva: a pill vai de x=12 até
    // 36 + 40*n (40px por botão). O thumb entra 1px depois, e os 5px de margem
    // interna dele viram o respiro visual entre as duas pills.
    readonly property int workspaceCount: Hyprland.workspaces.values.filter(function (w) {
        return w.id > 0; // ignora workspaces especiais (scratchpad)
    }).length
    readonly property int barOffset: 37 + 40 * workspaceCount

    property bool pinned: false // travado aberto via IPC (bind do Hyprland)
    property bool hovered: false
    readonly property bool expanded: hovered || pinned

    // position não emite PropertiesChanged na maioria dos players (é caro no
    // D-Bus) — este tick força a reavaliação dos bindings de progresso.
    property bool playerTick: false

    function fmtTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds))
            return "0:00";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // ── Controle por linha de comando ────────────────────────────────────
    // `qs ipc call media <fn>` — usado pelos binds de tecla de mídia no
    // hyprland.conf, em vez de um playerctl paralelo ao MPRIS daqui.
    IpcHandler {
        target: "media"

        function toggle(): void {
            root.pinned = !root.pinned;
        }
        function playPause(): void {
            if (root.hasPlayer)
                root.player.togglePlaying();
        }
        function next(): void {
            if (root.hasPlayer && root.player.canGoNext)
                root.player.next();
        }
        function previous(): void {
            if (root.hasPlayer && root.player.canGoPrevious)
                root.player.previous();
        }
        function status(): string {
            if (!root.hasPlayer)
                return "";
            return root.player.trackArtist + " — " + root.player.trackTitle;
        }
    }

    PanelWindow {
        id: panel

        property int barHeight: 42
        // Altura vinda do conteúdo, nunca de um número mágico: um valor fixo
        // menor que o necessário cortava a linha de controles.
        property int cardHeight: cardColumn.implicitHeight + 28

        anchors {
            top: true
            left: true
        }
        exclusiveZone: 0 // não empurra janelas; a waybar é quem reserva espaço
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-media"

        // Sem faixa carregada em nenhum player: some a superfície inteira, não
        // só o conteúdo — senão sobra uma área invisível capturando o mouse.
        visible: root.hasPlayer

        // Tamanho FIXO (nunca animado): animar implicitHeight obriga o
        // compositor a reconfigurar a superfície Wayland a cada frame, e o
        // Hyprland mostra o buffer antigo — é o que fazia o card aparecer
        // "cortado pela metade". A animação mora dentro, no cardClip.
        implicitWidth: 320
        implicitHeight: barHeight + cardHeight

        // left: acompanha a largura real da pill de workspaces (ver barOffset).
        // Mover a superfície de lugar é barato — o que não se pode é animar o
        // TAMANHO dela; e a waybar também relayouta instantaneamente, então o
        // salto sem animação é o comportamento coerente.
        //
        // top NEGATIVO de propósito: a waybar reserva 52px (44 de altura + 8 de
        // margem) e o Hyprland ancora layer-shells a partir do fim da zona
        // reservada, não do topo físico. 8 - 52 = -44 devolve o widget para
        // y=8, alinhado à barra. Conferir com `hyprctl monitors` (campo
        // "reserved") se a altura da barra mudar.
        margins {
            top: -44
            left: root.barOffset
        }

        // Sem isto a superfície inteira (320px de largura) engole cliques que
        // eram para a waybar por baixo. A máscara restringe a área clicável ao
        // thumb + card; com o card recolhido (altura 0) sobra só o thumb.
        mask: Region {
            Region {
                item: thumb
            }
            // Geometria explícita em vez de `item: cardClip`: a altura do clip
            // está animando, e a região de input precisa já valer o card
            // inteiro no primeiro frame da abertura — senão o ponteiro sai da
            // máscara ao descer para o card e ele fecha sozinho.
            Region {
                x: 0
                y: panel.barHeight
                width: panel.implicitWidth
                height: root.expanded ? panel.cardHeight : 0
            }
        }

        Timer {
            interval: 1000
            running: root.hasPlayer && root.player.isPlaying && root.expanded
            repeat: true
            onTriggered: root.playerTick = !root.playerTick
        }

        // Hover restrito ao thumb e ao card — um HoverHandler solto aqui pegaria
        // os 320px inteiros da superfície, incluindo o vazio ao lado do ícone.
        Binding {
            target: root
            property: "hovered"
            value: thumbHover.hovered || cardHover.hovered
        }

        // ── Thumb (sempre na faixa da barra) ─────────────────────────────
        Rectangle {
            id: thumb
            width: panel.barHeight
            height: panel.barHeight
            color: "transparent"
            border.width: 0 // workaround QTBUG-137166

            HoverHandler {
                id: thumbHover
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 9 // mesma família de raios dos módulos da waybar
                // 0.88 é o alpha(@base, 0.88) do .modules-left em style.css —
                // é o que faz o thumb ler como parte da barra, não como card solto.
                color: Qt.alpha(root.cBg, 0.88)
                border.width: 1
                border.color: Qt.alpha(root.cPrimary, root.expanded ? 0.55 : 0.35)
                Behavior on border.color { ColorAnimation { duration: root.animFast } }
            }

            // Gatilho é só o glyph — a capa aparece no card, no hover.
            // A cor comunica o estado: aceso tocando, apagado pausado.
            Text {
                anchors.centerIn: parent
                text: ""
                font.family: root.iconFont
                font.pixelSize: 16
                color: (root.hasPlayer && root.player.isPlaying) ? root.cPrimary : Qt.alpha(root.cText, 0.55)
                Behavior on color { ColorAnimation { duration: root.animFast } }
            }
        }

        // ── Card (desce no hover) ────────────────────────────────────────
        // A superfície já nasce alta o bastante; aqui é só uma propriedade QML
        // animando dentro dela, com clip.
        Item {
            id: cardClip
            anchors.top: thumb.bottom
            anchors.left: parent.left
            width: panel.implicitWidth
            height: root.expanded ? panel.cardHeight : 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: root.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: cardHover
            }

            Rectangle {
                id: card
                width: parent.width
                height: panel.cardHeight
                radius: 14
                color: root.cBg
                opacity: root.expanded ? 0.94 : 0
                border.width: 1
                border.color: Qt.alpha(root.cPrimary, 0.25)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.animFast
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    id: cardColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8 // o default de Layout é 5; sempre declarar

                    // Revelação escalonada: o conteúdo entra logo depois da
                    // altura, subindo alguns pixels.
                    opacity: root.expanded ? 1 : 0
                    transform: Translate {
                        y: root.expanded ? 0 : -6
                        Behavior on y {
                            NumberAnimation {
                                duration: root.animNormal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.animNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Capa + metadados
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // ClippingRectangle, não Rectangle+clip: clip comum
                        // recorta no retângulo, ignorando o radius, e a capa
                        // ficaria com cantos quadrados sobrando.
                        ClippingRectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 10
                            color: Qt.alpha(root.cPrimary, 0.12)

                            Image {
                                anchors.fill: parent
                                source: (root.hasPlayer && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true // capa vem de disco/rede: nunca no thread de render
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !(root.hasPlayer && root.player.trackArtUrl)
                                text: ""
                                font.family: root.iconFont
                                font.pixelSize: 22
                                color: Qt.alpha(root.cPrimary, 0.5)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: root.hasPlayer ? root.player.trackTitle : ""
                                color: root.cText
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.hasPlayer ? root.player.trackArtist : ""
                                color: Qt.alpha(root.cText, 0.7)
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            // De onde vem o som — útil justamente quando há mais
                            // de um player registrado.
                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                text: root.hasPlayer ? root.player.identity : ""
                                color: Qt.alpha(root.cText, 0.4)
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Progresso — clicável para seek quando o player permite.
                    // O Item é mais alto que o trilho só para dar área de clique.
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 12

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Qt.alpha(root.cPrimary, 0.18)

                            Rectangle {
                                height: parent.height
                                radius: 2
                                color: root.cPrimary
                                // (playerTick || true) só existe para criar a
                                // dependência do Timer — ver gotchas §7.
                                width: (root.playerTick || true) && root.hasPlayer && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                            }
                        }

                        TapHandler {
                            enabled: root.hasPlayer && root.player.canSeek && root.player.length > 0
                            onTapped: eventPoint => {
                                const frac = Math.max(0, Math.min(1, eventPoint.position.x / track.width));
                                root.player.position = frac * root.player.length;
                                root.playerTick = !root.playerTick;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: (root.playerTick || true) && root.hasPlayer ? root.fmtTime(root.player.position) : "0:00"
                            color: Qt.alpha(root.cText, 0.6)
                            font.pixelSize: 11
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.hasPlayer ? root.fmtTime(root.player.length) : "0:00"
                            color: Qt.alpha(root.cText, 0.6)
                            font.pixelSize: 11
                        }
                    }

                    // Controles. shuffle/loop só aparecem se o player suportar —
                    // botão morto é pior que botão ausente.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 4

                        MediaButton {
                            visible: root.hasPlayer && root.player.shuffleSupported
                            glyph: ""
                            glyphSize: 13
                            iconFont: root.iconFont
                            tint: (root.hasPlayer && root.player.shuffle) ? root.cPrimary : Qt.alpha(root.cText, 0.45)
                            onActivated: root.player.shuffle = !root.player.shuffle
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        MediaButton {
                            glyph: ""
                            iconFont: root.iconFont
                            tint: root.cPrimary
                            active: root.hasPlayer && root.player.canGoPrevious
                            onActivated: root.player.previous()
                        }
                        MediaButton {
                            glyph: (root.hasPlayer && root.player.isPlaying) ? "" : ""
                            glyphSize: 20
                            iconFont: root.iconFont
                            tint: root.cPrimary
                            active: root.hasPlayer && root.player.canTogglePlaying
                            onActivated: root.player.togglePlaying()
                        }
                        MediaButton {
                            glyph: ""
                            iconFont: root.iconFont
                            tint: root.cPrimary
                            active: root.hasPlayer && root.player.canGoNext
                            onActivated: root.player.next()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Um glyph só para os três modos; o estado é a cor:
                        // apagado = off, primary = playlist, secondary = faixa.
                        MediaButton {
                            visible: root.hasPlayer && root.player.loopSupported
                            glyph: ""
                            glyphSize: 13
                            iconFont: root.iconFont
                            tint: {
                                if (!root.hasPlayer || root.player.loopState === MprisLoopState.None)
                                    return Qt.alpha(root.cText, 0.45);
                                return root.player.loopState === MprisLoopState.Track ? root.cSecondary : root.cPrimary;
                            }
                            onActivated: {
                                const s = root.player.loopState;
                                root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                            }
                        }
                    }
                }
            }
        }
    }
}
