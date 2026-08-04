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
//
// O thumb tem largura animada (não fixa): quando um player começa a tocar,
// ele cresce para abrir espaço para as barrinhas do visualizer — mesmo
// gesto de "pílula crescendo" que `hyprland/workspaces` já faz na waybar
// (ver patterns.md #5). Isto é seguro para animar (diferente da SUPERFÍCIE
// do PanelWindow, gotchas §1): é só a largura de um Item comum por dentro
// da superfície, que já nasce fixa em 320px.
//
// O visualizer usa dado real de áudio — Pipewire.PwNodePeakMonitor no sink
// padrão do sistema — não uma animação simulada/fake. Sem processo externo
// (cava etc.): é um serviço nativo do Quickshell, então segue a mesma regra
// de "serviço nativo > polling" do resto do widget.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

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

    // ── Visualizer de áudio real (Pipewire) ──────────────────────────────
    // PwNodePeakMonitor lê o nível de pico do sink padrão em tempo real —
    // é o mesmo mecanismo de um medidor de VU, não uma FFT de espectro, mas
    // é dado de áudio de verdade (reage ao volume real tocando), não uma
    // curva senoidal fake. PwObjectTracker é obrigatório (gotchas §9): sem
    // ele o Pipewire não assina as propriedades do node e tudo fica zerado.
    readonly property int waveBars: 5
    property var waveSamples: [0, 0, 0, 0, 0]

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    PwNodePeakMonitor {
        id: peakMonitor
        node: Pipewire.defaultAudioSink
        enabled: root.hasPlayer && root.player.isPlaying
        // Ao pausar/parar, força as barras a assentarem em 0 em vez de
        // congelarem no último nível — sem isto o visualizer "trava" aceso.
        onEnabledChanged: {
            if (!enabled)
                root.waveSamples = new Array(root.waveBars).fill(0);
        }
    }

    // Amostra o pico periodicamente e desliza a janela — é isto que dá o
    // efeito de "onda" nas barras em vez de um valor só piscando.
    // sqrt() aproxima a resposta perceptual do ouvido (não-linear); o ganho
    // de 1.4 compensa picos de mixagem que raramente chegam perto de 1.0.
    Timer {
        interval: 90
        running: peakMonitor.enabled
        repeat: true
        onTriggered: {
            const level = Math.min(1, Math.sqrt(peakMonitor.peak) * 1.4);
            const next = root.waveSamples.slice(1);
            next.push(level);
            root.waveSamples = next;
        }
    }

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
        // Largura ANIMADA: colapsado é só o glyph (mesmo tamanho de sempre);
        // com um player ativo, cresce para abrir espaço pro visualizer — o
        // gesto de "pílula crescendo" da hyprland/workspaces (patterns.md
        // #5) aplicado ao nosso próprio thumb. Seguro de animar (gotchas §1
        // é sobre a SUPERFÍCIE do PanelWindow, que continua fixa em 320px;
        // um Item comum por dentro pode animar width à vontade).
        Rectangle {
            id: thumb

            readonly property int barW: 3
            readonly property int barGap: 3
            readonly property int visualizerWidth: root.waveBars * barW + (root.waveBars - 1) * barGap
            readonly property int glyphZoneWidth: panel.barHeight

            width: root.hasPlayer ? (glyphZoneWidth + 10 + visualizerWidth + 10) : panel.barHeight
            height: panel.barHeight
            color: "transparent"
            border.width: 0 // workaround QTBUG-137166

            Behavior on width {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.0
                }
            }

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
                id: thumbGlyph
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: thumb.glyphZoneWidth
                horizontalAlignment: Text.AlignHCenter
                text: ""
                font.family: root.iconFont
                font.pixelSize: 16
                color: (root.hasPlayer && root.player.isPlaying) ? root.cPrimary : Qt.alpha(root.cText, 0.55)
                Behavior on color { ColorAnimation { duration: root.animFast } }
            }

            // Visualizer — barras animadas com o pico real do sink padrão
            // (root.waveSamples, amostrado pelo Timer lá em cima, dentro de
            // root). Opacity soma à animação de largura: a barra mais fina
            // já entra meio visível antes do thumb terminar de crescer.
            RowLayout {
                id: visualizer
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: thumbGlyph.right
                spacing: thumb.barGap
                opacity: root.hasPlayer ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: root.animFast }
                }

                Repeater {
                    model: root.waveBars
                    delegate: Rectangle {
                        id: bar
                        required property int index

                        Layout.preferredWidth: thumb.barW
                        Layout.preferredHeight: 4 + (root.waveSamples[index] ?? 0) * 20
                        Layout.alignment: Qt.AlignVCenter
                        radius: thumb.barW / 2
                        color: (root.hasPlayer && root.player.isPlaying) ? root.cPrimary : Qt.alpha(root.cText, 0.35)

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: root.animFast }
                        }
                    }
                }
            }
        }

        // ── Card (desce no hover) ────────────────────────────────────────
        // A superfície já nasce alta o bastante; aqui é só uma propriedade QML
        // animando dentro dela, com clip.
        //
        // Abertura e fechamento usam States/Transitions em vez de um único
        // Behavior simétrico: abrir é mais lento e tem um leve overshoot
        // (Easing.OutBack) — "quanto mais animação melhor" — e fechar é
        // rápido e seco (Easing.InCubic), pra não parecer que o card está
        // "sobrando" na tela depois que o mouse já saiu.
        Item {
            id: cardClip
            anchors.top: thumb.bottom
            anchors.left: parent.left
            width: panel.implicitWidth
            height: 0
            clip: true

            state: root.expanded ? "open" : ""
            states: State {
                name: "open"
                PropertyChanges {
                    target: cardClip
                    height: panel.cardHeight
                }
            }
            transitions: [
                Transition {
                    from: ""
                    to: "open"
                    NumberAnimation {
                        target: cardClip
                        property: "height"
                        duration: 300
                        easing.type: Easing.OutCubic
                    }
                },
                Transition {
                    from: "open"
                    to: ""
                    NumberAnimation {
                        target: cardClip
                        property: "height"
                        duration: 190
                        easing.type: Easing.InCubic
                    }
                }
            ]

            HoverHandler {
                id: cardHover
            }

            Rectangle {
                id: card
                width: parent.width
                height: panel.cardHeight
                radius: 14
                color: root.cBg
                opacity: 0
                border.width: 1
                border.color: Qt.alpha(root.cPrimary, 0.25)

                state: root.expanded ? "open" : ""
                states: State {
                    name: "open"
                    PropertyChanges {
                        target: card
                        opacity: 0.94
                    }
                }
                transitions: [
                    Transition {
                        from: ""
                        to: "open"
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    },
                    Transition {
                        from: "open"
                        to: ""
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            duration: 160
                            easing.type: Easing.InCubic
                        }
                    }
                ]

                ColumnLayout {
                    id: cardColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8 // o default de Layout é 5; sempre declarar

                    opacity: 0
                    transform: Translate {
                        id: cardColumnTranslate
                        y: -10
                    }

                    state: root.expanded ? "open" : ""
                    states: State {
                        name: "open"
                        PropertyChanges {
                            target: cardColumn
                            opacity: 1
                        }
                        PropertyChanges {
                            target: cardColumnTranslate
                            y: 0
                        }
                    }
                    // Entrada: uma pausa curta deixa a altura abrir espaço
                    // antes do texto subir, com um pequeno "estouro"
                    // (overshoot) no final — revelação escalonada com uma
                    // pitada de bounce. Saída: sem pausa, direto e rápido.
                    transitions: [
                        Transition {
                            from: ""
                            to: "open"
                            SequentialAnimation {
                                PauseAnimation {
                                    duration: 60
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: cardColumn
                                        property: "opacity"
                                        duration: 240
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: cardColumnTranslate
                                        property: "y"
                                        duration: 340
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.3
                                    }
                                }
                            }
                        },
                        Transition {
                            from: "open"
                            to: ""
                            ParallelAnimation {
                                NumberAnimation {
                                    target: cardColumn
                                    property: "opacity"
                                    duration: 150
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    target: cardColumnTranslate
                                    property: "y"
                                    duration: 170
                                    easing.type: Easing.InCubic
                                }
                            }
                        }
                    ]

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
