# Quickshell — receitas prontas

Padrões testáveis para os widgets que fazem sentido neste rice. Todos assumem o `Theme`
singleton descrito no `SKILL.md` (paleta wallust); se ele ainda não existir, troque
`Theme.primary` por `root.colors.primary` no estilo atual do `shell.qml`.

Índice: [drop-down no hover](#1) · [popup clicável](#2) · [OSD de volume](#3) ·
[bateria](#4) · [workspaces](#5) · [notificações](#6) · [system tray](#7) ·
[relógio](#8) · [por monitor](#9) · [processo externo](#10) · [IPC](#11) ·
[lock screen](#12) · [blur do compositor](#13)

---

<a id="1"></a>
## 1. Drop-down no hover (o padrão do widget de mídia)

Superfície fixa + clip animado por dentro. É a base de qualquer card que desce da barra.
Ver `gotchas.md` §1 e §2 para o porquê de cada detalhe.

```qml
PanelWindow {
    id: panel
    property int barHeight: 42
    property int cardHeight: content.implicitHeight + 28

    anchors { top: true; left: true }
    exclusiveZone: 0                      // não empurra janelas
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-meuwidget"

    implicitWidth: 320
    implicitHeight: barHeight + cardHeight    // FIXO
    margins { top: -44; left: 205 }           // ver gotchas §3

    Binding {
        target: root
        property: "expanded"
        value: thumbHover.hovered || cardHover.hovered
    }

    Rectangle {
        id: thumb
        width: panel.barHeight; height: panel.barHeight
        color: "transparent"
        border.width: 0                    // workaround QTBUG-137166
        HoverHandler { id: thumbHover }
        // ... ícone
    }

    Item {
        id: cardClip
        anchors.top: thumb.bottom
        width: panel.implicitWidth
        height: root.expanded ? panel.cardHeight : 0
        clip: true
        Behavior on height {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        HoverHandler { id: cardHover }

        Rectangle {
            id: content
            width: parent.width
            height: panel.cardHeight
            radius: 14
            color: Theme.background
            opacity: root.expanded ? 0.94 : 0
            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            // ... conteúdo
        }
    }
}
```

<a id="2"></a>
## 2. Popup que abre no clique e fecha ao clicar fora

Quando o conteúdo é grande ou precisa de foco de teclado, `PopupWindow` é melhor que o clip:
ele é uma superfície própria, posicionada em relação a um item.

```qml
PanelWindow {
    id: bar
    Rectangle {
        id: botao
        TapHandler { onTapped: menu.visible = !menu.visible }
    }

    PopupWindow {
        id: menu
        anchor.window: bar
        anchor.item: botao          // ancora no item, não em coordenada fixa
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8
        implicitWidth: 280
        implicitHeight: col.implicitHeight + 24
        color: "transparent"
        visible: false
        grabFocus: true             // clicar fora fecha (visible -> false)

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Theme.background
            ColumnLayout { id: col; anchors.fill: parent; anchors.margins: 12 }
        }
    }
}
```

`anchor.adjustment` (`PopupAdjustment`) controla o que fazer quando não cabe na tela.
Sob Hyprland, `HyprlandFocusGrab` dá detecção de clique-fora mais precisa que `grabFocus`.

<a id="3"></a>
## 3. OSD de volume (Pipewire)

Substituiria o `volume-popup.py` (GTK3) por algo nativo, sem o custo de `GI_TYPELIB_PATH`.
O `PwObjectTracker` é **obrigatório** — ver `gotchas.md` §9.

```qml
import Quickshell.Services.Pipewire

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker { objects: [root.sink] }   // sem isto, volume não atualiza

    // Mostra o OSD por 1.5s sempre que o volume mudar
    property bool showing: false
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.showing = false
    }
    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showing = true; hideTimer.restart() }
        function onMutedChanged()  { root.showing = true; hideTimer.restart() }
    }

    PanelWindow {
        anchors { bottom: true }
        margins.bottom: 80
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 260
        implicitHeight: 60
        visible: root.showing
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Theme.background
            opacity: 0.94

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Text {
                    text: root.sink?.audio?.muted ? "" : ""
                    font.family: Theme.iconFont
                    color: Theme.primary
                }
                Rectangle {                       // trilho
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Qt.alpha(Theme.primary, 0.18)
                    Rectangle {                   // preenchimento
                        height: parent.height
                        radius: 3
                        color: Theme.primary
                        width: parent.width * Math.min(1, root.sink?.audio?.volume ?? 0)
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
                Text {
                    text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                    color: Theme.text
                }
            }
        }
    }
}
```

Para **escrever** volume: `sink.audio.volume = 0.5` (0.0–1.0) e `sink.audio.muted = true`.

<a id="4"></a>
## 4. Bateria (UPower) — relevante neste MacBook

> ⚠️ **`services.upower.enable = true;` é obrigatório e hoje NÃO está no config.** Sem ele
> este widget mostra `0%` / `Unknown` sem erro nenhum. Ver a tabela de pré-requisitos no
> `SKILL.md`.

```qml
import Quickshell.Services.UPower

readonly property var bat: UPower.displayDevice

// ícone por faixa de carga
readonly property string icon: {
    if (bat.state === UPowerDeviceState.Charging) return ""
    const p = bat.percentage
    if (p > 0.9) return ""
    if (p > 0.6) return ""
    if (p > 0.4) return ""
    if (p > 0.1) return ""
    return ""
}

Text {
    text: root.icon + "  " + Math.round(bat.percentage * 100) + "%"
    color: bat.percentage < 0.15 && !UPower.onBattery ? Theme.alert : Theme.text
}
```

`percentage` é **0.0–1.0**, não 0–100. `timeToEmpty`/`timeToFull` vêm em segundos.
`UPower.onBattery` é o global (tem AC ou não) — é o mesmo evento que a regra udev usa hoje
para mandar `SIGUSR2` na waybar; um widget Quickshell reage sozinho, sem udev.

<a id="5"></a>
## 5. Workspaces do Hyprland

```qml
import Quickshell.Hyprland

RowLayout {
    spacing: 6
    Repeater {
        model: Hyprland.workspaces        // UntypedObjectModel direto no model
        delegate: Rectangle {
            required property var modelData
            implicitWidth: modelData.focused ? 28 : 16
            implicitHeight: 16
            radius: 8
            color: modelData.focused ? Theme.primary
                 : modelData.urgent  ? Theme.alert
                 : Qt.alpha(Theme.primary, 0.3)
            Behavior on implicitWidth {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            TapHandler { onTapped: modelData.activate() }
        }
    }
}
```

`required property var modelData` é obrigatório em delegates com
`pragma ComponentBehavior: Bound` (recomendado — ver `SKILL.md`).

<a id="6"></a>
## 6. Daemon de notificações

Substituiria o `mako`/`dunst`. `keepOnReload: true` evita perder notificações no live-reload.

```qml
import Quickshell.Services.Notifications

NotificationServer {
    id: server
    keepOnReload: true
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    actionsSupported: true

    onNotification: notif => {
        notif.tracked = true       // sem isto a notificação é descartada na hora
    }
}

// Renderiza a pilha
PanelWindow {
    anchors { top: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)

    ColumnLayout {
        id: stack
        width: parent.width
        spacing: 8
        Repeater {
            model: server.trackedNotifications
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 80
                radius: 14
                color: Theme.background
                border.width: 1
                border.color: modelData.urgency === NotificationUrgency.Critical
                    ? Theme.alert : Qt.alpha(Theme.primary, 0.25)
                // modelData.summary / .body / .appName / .image / .actions
                TapHandler { onTapped: modelData.dismiss() }
            }
        }
    }
}
```

`notif.actions` é uma lista de `NotificationAction` com `text` e `invoke()`.

<a id="7"></a>
## 7. System tray

```qml
import Quickshell
import Quickshell.Services.SystemTray

RowLayout {
    Repeater {
        model: SystemTray.items
        delegate: IconImage {
            required property var modelData
            implicitSize: 18
            source: modelData.icon
            asynchronous: true
            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: eventPoint => {
                    if (eventPoint.event.button === Qt.RightButton && modelData.hasMenu)
                        modelData.display(QsWindow.window, 0, 0)
                    else
                        modelData.activate()
                }
            }
        }
    }
}
```

Para desenhar o menu você mesmo em vez de usar `display()`, veja `QsMenuOpener` no fim de
`api-services.md`.

<a id="8"></a>
## 8. Relógio

Não use `Timer` para relógio — `SystemClock` alinha nas bordas reais do segundo/minuto e não
acorda a CPU à toa.

```qml
SystemClock {
    id: clock
    precision: SystemClock.Minutes    // Hours | Minutes | Seconds
}

Text {
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text
}
```

<a id="9"></a>
## 9. Uma janela por monitor

Irrelevante hoje (um monitor), mas é o padrão correto e custa nada:

```qml
Variants {
    model: Quickshell.screens
    PanelWindow {
        required property var modelData
        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 32
    }
}
```

<a id="10"></a>
## 10. Rodar um processo externo

Só quando não existir serviço nativo — serviço nativo sempre ganha de polling em shell.
Comandos **não** passam por shell: use `["sh", "-c", "..."]` se precisar de pipe/glob.

```qml
// Saída única
Process {
    running: true
    command: ["sh", "-c", "cat /sys/class/thermal/thermal_zone0/temp"]
    stdout: StdioCollector {
        onStreamFinished: root.temp = parseInt(this.text) / 1000
    }
}

// Fluxo contínuo, linha a linha
Process {
    running: true
    command: ["journalctl", "-f", "-o", "cat"]
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: data => console.log(data)
    }
}
```

`Quickshell.execDetached(["comando"])` para disparar e esquecer (abrir um app, por exemplo).

<a id="11"></a>
## 11. Controlar o shell por linha de comando (IPC)

Substitui o `SIGUSR2`/scripts: dá para amarrar um bind do Hyprland direto num widget.

```qml
import Quickshell.Io

IpcHandler {
    target: "media"
    function toggle(): void { root.expanded = !root.expanded }
    function setVolume(v: real): void { Pipewire.defaultAudioSink.audio.volume = v }
    function status(): string { return root.player?.trackTitle ?? "" }
}
```

```bash
qs ipc show                      # lista os targets
qs ipc show target media         # assinatura das funções
qs ipc call media toggle
qs ipc call media setVolume 0.4
```

No `hyprland.conf`: `bind = SUPER, M, exec, qs ipc call media toggle`.
Tipos aceitos: `string`, `int`, `bool`, `real`, `color`, `void` (máx. 10 argumentos).

<a id="12"></a>
## 12. Lock screen (`WlSessionLock` + PAM)

Alternativa nativa ao `hyprlock`, e coerente com o tema do greeter SDDM.

```qml
import Quickshell.Wayland
import Quickshell.Services.Pam

WlSessionLock {
    id: lock
    locked: true

    surface: WlSessionLockSurface {
        color: "black"
        // conteúdo: avatar, campo de senha, wallpaper borrado
    }
}

PamContext {
    id: pam
    onCompleted: result => {
        if (result === PamResult.Success) lock.locked = false
    }
    // pam.start() e pam.respond(senha) conforme responseRequired
}
```

`WlSessionLock.secure` diz se o compositor garantiu o bloqueio de verdade.
Anime só opacity/posição aqui — o wallpaper borrado deve ser pré-renderizado
com ImageMagick, como já é feito em `/var/lib/sddm-theme/` (ver `gotchas.md` §10).

<a id="13"></a>
## 13. Blur de fundo pelo compositor

Em vez de borrar na GPU via QML (proibitivo na HD 4000), peça ao Hyprland:

```qml
import Quickshell.Wayland

PanelWindow {
    color: "transparent"
    BackgroundEffect.blurRegion: Region {
        item: card          // borra exatamente a área do card
        radius: 14
    }
}
```

Requer blur ativo no Hyprland (`decoration:blur:enabled = true`).
