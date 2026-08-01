# Quickshell — armadilhas, bugs e limites de hardware

Cada item aqui custou tempo real de debug (nossa ou da doc oficial). Ler antes de escrever
QML novo é mais barato que descobrir de novo.

---

## 1. Nunca anime o tamanho de uma superfície layer-shell

**Sintoma:** o card aparece "cortado pela metade", com aspecto travado/stale, e a animação
engasga.

**Causa:** animar `implicitHeight`/`implicitWidth` de um `PanelWindow` obriga o compositor a
reconfigurar a superfície Wayland a cada frame. O Hyprland não faz isso de forma suave — o
buffer antigo (menor) continua visível até o próximo commit.

**Solução — o padrão que usamos:** dimensione a superfície **de uma vez, no tamanho máximo
expandido**, e anime só *dentro* dela, num `Item` com `clip: true`:

```qml
PanelWindow {
    implicitWidth: 320
    implicitHeight: barHeight + cardHeight   // FIXO, nunca animado

    Item {
        id: cardClip
        clip: true
        height: root.expanded ? panel.cardHeight : 0   // isto sim anima
        Behavior on height {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        // ... conteúdo do card
    }
}
```

Corolário: a superfície fixa ocupa espaço mesmo recolhida. Se ela não deve receber hover
quando vazia, esconda a **superfície inteira** (`visible: false`), não só o conteúdo — senão
sobra uma área invisível "morta" capturando o mouse.

## 2. `HoverHandler` segue a geometria do *pai*, não do `target`

**Sintoma:** o widget expande quando o mouse passa longe dele, em espaço vazio.

**Causa:** um `HoverHandler` declarado direto no `PanelWindow` monitora a superfície inteira
(no nosso caso, 320px de largura), não o ícone de 42px.

**Solução:** declare o handler **dentro** do `Item` que ele deve monitorar, e combine vários
com um `Binding`:

```qml
Rectangle { id: thumb;  HoverHandler { id: thumbHover } }
Item      { id: cardClip; HoverHandler { id: cardHover } }

Binding {
    target: root
    property: "expanded"
    value: thumbHover.hovered || cardHover.hovered
}
```

A propriedade `target` do handler muda para quem os *eventos* vão — **não** muda a região
que é testada.

## 3. Âncoras layer-shell partem da zona já reservada, não do topo físico

**Sintoma:** `margins.top: 8` posiciona o widget em y=60, bem abaixo do esperado.

**Causa:** a waybar reserva uma `exclusiveZone` (aqui: 44px de altura + 8px de margem = 52px).
O Hyprland ancora superfícies layer-shell a partir do **fim da área reservada pelas outras
camadas**, não do topo da tela.

**Solução:** compense com margem negativa. Aqui, `8 - 52 = -44`:

```qml
margins { top: -44; left: 205 }
```

**Como descobrir os números certos** (não chute):

```bash
hyprctl layers      # namespaces e ordem das camadas
hyprctl monitors    # campo "reserved": [left, top, right, bottom]
```

Ponha `WlrLayershell.namespace` em todo painel — é assim que ele aparece nomeado no
`hyprctl layers`, e é o que torna esse debug possível.

## 4. QTBUG-137166 — o buraco no meio da janela

**Sintoma:** tudo que está *embaixo* de um retângulo transparente fica invisível — um buraco
recortado na janela.

**Causa:** `Rectangle { color: "transparent" }` **e** tocar na propriedade `border` (mesmo só
lendo) dispara o bug.

**Solução:** declare `border.width: 0` explicitamente.

```qml
Rectangle {
    color: "transparent"
    border.width: 0   // workaround QTBUG-137166
}
```

## 5. Cor de fundo opaca vira superfície opaca

**Sintoma:** transparência/blur não funciona apesar de `color` com alpha.

**Causa:** se a cor do fundo é opaca, o Quickshell cria uma superfície opaca por performance.

**Solução:** `color: "transparent"` na janela e desenhe um `Rectangle` interno com a cor real
— ou force via `surfaceFormat.opaque: false`.

Este é também o jeito de fazer **janela com cantos arredondados** (FAQ oficial): a janela é
transparente, o `Rectangle` interno tem o `radius`.

## 6. `childrenRect` para dimensionar container = loop de binding

**Errado:**

```qml
Item {
    implicitWidth: childrenRect.width   // ERRADO
    Rectangle { anchors.fill: parent; implicitWidth: 50 }
}
```

`childrenRect` é geometria **real**, não implícita. O implicit do pai passa a depender do
tamanho real dele, que depende do implicit. Loop.

**Certo:** some os implicits dos filhos à mão, ou use os wrappers do
`Quickshell.Widgets` (`WrapperItem`, `WrapperRectangle`, …), que existem exatamente para isso.

No nosso `shell.qml` a altura do card vem do conteúdo, não de um número mágico:

```qml
property int cardHeight: cardColumn.implicitHeight + 28   // + as duas margens de 14
```

Antes era um `132` fixo, menor que o necessário, e cortava a linha de controles.

## 7. `position` do MPRIS não emite sinal de mudança

**Sintoma:** a barra de progresso não anda.

**Causa:** a maioria dos players não emite `PropertiesChanged` para `Position` (é caro no
D-Bus) — o valor é lido sob demanda.

**Solução:** um `Timer` que alterna um booleano, referenciado no binding para forçar
reavaliação:

```qml
property bool playerTick: false

Timer {
    interval: 1000
    running: root.hasPlayer && root.player.isPlaying
    repeat: true
    onTriggered: root.playerTick = !root.playerTick
}

// no binding, o (playerTick || true) só existe para criar a dependência:
width: (root.playerTick || true) && root.player.length > 0
    ? parent.width * Math.min(1, root.player.position / root.player.length)
    : 0
```

Mantenha o `running` amarrado a `isPlaying` — não faça o timer rodar com nada tocando.

## 8. Players MPRIS fantasma

**Sintoma:** o ícone do navegador fica preso no widget sem nada tocando.

**Causa:** Brave/Chromium com MediaSession se registram no MPRIS mesmo sem faixa carregada —
`playbackState: Stopped` e `trackTitle` vazio.

**Solução:** filtre por conteúdo real, não por existência:

```qml
property var activePlayers: Mpris.players.values.filter(p => p.trackTitle && p.trackTitle.length > 0)
```

## 9. Pipewire: sem `PwObjectTracker`, o volume não atualiza

Ver a nota completa em `api-services.md`. Resumo: o Quickshell não assina as propriedades de
todos os nodes por padrão. Sem um `PwObjectTracker { objects: [Pipewire.defaultAudioSink] }`
vivo, `audio.volume` fica parado — **e não há erro no log**.

## 10. Hardware: Intel HD 4000 (MacBook Pro 2012)

Mesma lição que já aprendemos no greeter do SDDM (onde o blur é pré-renderizado com
ImageMagick, não feito em QML):

- **Anime só** `opacity`, `height`/`width` de Items comuns, `x`/`y`, `scale`, `rotation`.
- **Evite** `MultiEffect` com blur, `ShaderEffect` pesado, `layer.enabled` em área grande,
  e qualquer blur em tempo real de tela cheia.
- Sombra: `RectangularShadow` (barata, retângulo/círculo) antes de `MultiEffect`.
- Blur de fundo real: peça ao **compositor** via `BackgroundEffect.blurRegion`
  (`Quickshell.Wayland`) — o Hyprland faz isso muito melhor que a GPU via QML.
- `asynchronous: true` em `Image`/`IconImage` que carregam de disco ou rede (capas de álbum).

## 11. Um processo por widget é desperdício

FAQ oficial, direto: *"Using a process per widget will use significantly more memory than
using a single process."* Widgets novos entram como arquivos QML no **mesmo** `shell.qml`,
não como novo `exec-once`.

Para não pagar memória por widget que quase nunca aparece, use `Loader` (para coisas
derivadas de `Item`) ou `LazyLoader` (para o resto) com `active:` amarrado à condição.

## 12. Ícones roxos/pretos de "faltando"

`Quickshell.iconPath(nome)` devolve o placeholder quebrado quando o ícone não existe. Use as
variantes com fallback:

```qml
Quickshell.iconPath(icone, "application-x-executable")  // fallback explícito
Quickshell.iconPath(icone, true)                        // "" em vez de placeholder
```

## 13. `Row`/`Column` vs `RowLayout`/`ColumnLayout`

`Row`/`Column`/`Grid` são *positioners*: não têm o attached object `Layout` e **não alinham
a pixel**, o que borra a renderização quando algum filho tem tamanho fracionário.

Prefira `RowLayout`/`ColumnLayout` (com `Layout.fillWidth`, `Layout.preferredWidth`, …) em
tudo, salvo se quebrar o alinhamento de pixel for intencional. Cuidado: `spacing` default do
Layout é **5**, não 0 — sempre declare explicitamente.

## 14. Debug: os erros QML não vão para o stderr do terminal

```bash
qs log -f              # segue o log da instância rodando
qs log -t 100          # últimas 100 linhas
qs list                # instâncias rodando
qs -v / -vv            # sobe a verbosidade (INFO / DEBUG)
```

Erro de binding em QML **não derruba** o app: a propriedade fica com valor default e o widget
renderiza "quase certo". Se algo está silenciosamente errado, `qs log` primeiro.

Para testar QML isolado sem mexer no shell rodando:

```bash
qs -p /caminho/para/arquivo.qml
```
