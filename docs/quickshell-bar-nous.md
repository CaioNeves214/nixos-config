# Barra Quickshell do perfil `nous`

O perfil `nous` não usa waybar. A barra inteira — workspaces, título da janela, hub central
(relógio + mídia + calendário), módulos de status, tray, notificações e OSD — é uma única
aplicação Quickshell (`dotfiles/profiles/nous/quickshell/`). O perfil `default` continua na
waybar, sem mudança nenhuma. **Escopo: apenas `nous`.**

> Leia primeiro a skill `quickshell` (`.claude/skills/quickshell/SKILL.md`) e
> `docs/media-widget.md` (o widget do `default` — a base de onde esta barra evoluiu). Este
> documento assume as duas.

## Por que existe

A waybar deste perfil tinha três limitações estruturais:

1. **Ícone e valor eram um label GTK só** (`"{icon} {value}"`). CSS não colore parte de um
   label, então o perfil inteiro pintava o módulo de status em `@primary` — não dava para
   destacar só o número. Corrigir exigiria markup Pango no `waybar-config.jsonc`
   **compartilhado com o `default`**, repintando os dois perfis.
2. **Qualquer mudança de geometria da barra obrigava a remedir com `grim`** o widget de mídia
   Quickshell, que se ancorava contra a zona exclusiva da waybar por aritmética
   (`margins.top: -42`, `barOffset: 13 + 40n`).
3. **Drawers GTK só expandem horizontalmente.** O card de mídia só existia como card
   drop-down porque virou uma segunda superfície layer-shell — todo o custo de âncora acima
   é decorrência disso.

Migrar tudo para Quickshell dissolve as três de uma vez: ícone e valor viram dois `Text`
independentes, a própria barra reserva sua `exclusiveZone` (não há mais widget externo se
ancorando contra ela), e o módulo central cresce num painel drop-down nativo.

## Arquitetura: uma superfície para a barra, o painel animando por dentro

`docs/media-widget.md` e a skill são categóricos: **nunca anime o tamanho de uma superfície
layer-shell** — o Hyprland reconfigura o buffer a cada frame e o resultado é o painel
renderizado pela metade. A barra herda a mesma solução do widget de mídia do `default`:

```qml
PanelWindow {                                        // ui/Bar.qml
    anchors { top: true; left: true; right: true }
    exclusiveZone: Theme.barHeight                    // 42 — a barra reserva o espaço, ninguém mais
    implicitHeight: Theme.barHeight + Theme.panelZone // FIXO (42 + 460), nunca muda
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top                 // Top, não Overlay: não cobre fullscreen
    WlrLayershell.namespace: "quickshell-bar"
    mask: Region { /* faixa da barra + painel do hub, geometria explícita */ }
}
```

A superfície nasce alta o bastante para o hub mais expandido e **nunca muda de tamanho**; o
drop-down do hub é um `Item { clip: true }` com `height` animada por `States`/`Transitions`
assimétricas (abrir 300ms `OutCubic`, fechar 190ms `InCubic` — o mesmo gesto do card de mídia
original).

**Três superfícies, um processo** (um processo por widget desperdiça memória — FAQ oficial
do Quickshell, e num Core i5 de 2012 isso importa):

| Superfície | Namespace | Âncora | `exclusiveZone` |
|---|---|---|---|
| `Bar.qml` | `quickshell-bar` | top+left+right | `Theme.barHeight` (reserva espaço) |
| `Notifications.qml` | `quickshell-notifications` | top+right | `0` |
| `Osd.qml` | `quickshell-osd` | bottom | `0` |

Com a barra reservando 42px, `Notifications.qml` cai em `y = 42` sozinho com
`margins.top: 0` — **não há mais aritmética negativa a calcular**. É a maior simplificação
sobre o desenho antigo.

### `mask: Region` — a regra que não pode ser violada

A região do hub usa **geometria explícita dirigida pelo booleano de estado**
(`hub.expanded`), nunca `item: hub` (cujo bounding box real está no meio de uma animação de
clip). A altura salta **instantaneamente** para o alvo no mesmo frame em que `expanded` muda:

```qml
// Bar.qml
mask: Region {
    Region { x: 0; y: 0; width: bar.width; height: Theme.barHeight }
    Region {
        x: hub.x
        y: Theme.barHeight
        width: Theme.panelWidth
        height: hub.expanded ? Theme.panelZone : 0
    }
}
```

Uma região atrasada em relação à animação derruba o ponteiro ao descer do gatilho para o
painel — ele sai da máscara e o painel fecha sozinho no meio do movimento. Ver
`docs/media-widget.md`, seção "Input masking", para o mesmo problema no widget original.

`Hub.qml` nasce com `implicitWidth: Theme.panelWidth` (a mesma largura do `HubPanel`) — é o
que permite ao `Bar.qml` montar a região do painel só com `hub.x`, sem mapear coordenadas
entre itens de arquivos diferentes.

## Árvore de arquivos

```
dotfiles/profiles/nous/quickshell/
  shell.qml                # só compõe: Bar {} + Notifications {} + Osd {}
  ui/
    qmldir                 # torna ui/ um módulo QML explícito — todo componente tem de estar listado
    Theme.qml              # singleton — paleta (FileView), fontes, radii, durações, métricas
    Sys.qml                # singleton — UM Timer de 2s para /proc, /sys, nmcli e bluetoothctl
    BarModule.qml           # base dos módulos de status: hover, tap, scroll, min-width, régua, ícone+valor
    Workspaces.qml
    WindowTitle.qml
    Hub.qml                 # gatilho central: glyph de mídia + visualizer + relógio; dono do MPRIS
    HubPanel.qml             # drop-down clipado; hospeda as páginas em ColumnLayout
    PanelMedia.qml           # porte do card de mídia original
    PanelCalendar.qml        # grid de mês — substitui o tooltip Pango do clock e o gsimplecal
    Visualizer.qml            # as 5 barras VU (Pipewire), extraídas do widget original
    MediaButton.qml            # já existia; reaproveitado sem mudança
    ModTray.qml  ModBacklight.qml  ModVolume.qml  ModNetwork.qml
    ModBluetooth.qml  ModTemperature.qml  ModCpu.qml  ModMemory.qml  ModBattery.qml
    Bar.qml
    Osd.qml
    Notifications.qml
```

## Design system em QML (`Theme.qml`)

Singleton `pragma Singleton`, o equivalente do `colors.css`/`palette.toml` para esta barra.
Lê a paleta com o mesmo `FileView` que o widget de mídia original já usava (merge sobre
`fallbackColors`, `blockLoading: true`, `onFileChanged: reload()`), só que movido para o
singleton — todo componente novo herda a leitura de graça.

| Token | Valor | Origem |
|---|---|---|
| `barHeight` | `42` | igual à antiga `waybar/geometry.jsonc` |
| `panelZone` | `460` | altura reservada para o hub expandido — revisar ao somar uma página |
| `panelWidth` | `340` | largura do hub e do seu painel |
| `radiusSharp` | `0` | "o gesto central do perfil" (DESIGN.md) |
| `grid` / `gridHalf` / `gridOneAndHalf` / `gridDouble` | `3.5 / 7 / 10.5 / 14` | grid do DESIGN.md |
| `statusMinWidth` | `52` | impede a barra de "pular" ao trocar de estado |
| fontes | IBM Plex Mono 13.5px · clock 14px/Medium · workspace 12px · Symbols Nerd Font | DESIGN.md |
| `animFast` / `animNormal` | `160` / `200` | "precise, technical" |

**Dois tokens novos no template compartilhado**, aditivos e seguros para o `default`
(`dotfiles/wallust/templates/colors-quickshell.json` ganhou `warning` e `surface` apontando
para `color3`/`color8` — slots ANSI que já existiam; o `shell.qml` do `default` ignora chaves
extras).

## Sys.qml — um Timer para tudo que não tem serviço nativo

CPU, memória, temperatura e backlight não têm serviço Quickshell nativo. Em vez de quatro
`Timer`/`Process` soltos, `Sys.qml` é um singleton com **um** `Timer` de 2s que dispara
`reload()` nos `FileView` de `/proc/stat`/`/proc/meminfo` e nos caminhos de `/sys` já
resolvidos (o hwmon do coretemp e o diretório de backlight são resolvidos **uma vez**, no
`Component.onCompleted`, via `Process`; depois disso é só `FileView`).

### Fallback: rede e bluetooth via `nmcli`/`bluetoothctl`

O plano original previa `Quickshell.Networking` e `Quickshell.Bluetooth` nativos. **Os dois
existem neste build** (`.qmltypes` presentes, os módulos importam sem erro) **mas ficam
permanentemente vazios em teste isolado neste sistema** —
`Networking.devices.values.length === 0` e `Bluetooth.adapters.values.length === 0` o tempo
todo, mesmo com NetworkManager e bluez rodando e um dispositivo real conectado (confirmado
via `busctl`/`nmcli`/`bluetoothctl` direto no D-Bus, fora do Quickshell). Não investigado a
fundo por que o backend do Quickshell não popula — pode ser incompatibilidade de versão da
lib que ele linka contra o NetworkManager/bluez deste sistema.

Era exatamente o ponto de fallback que o plano previu ("verificação antecipada, passo 2").
`Sys.qml` faz o polling por `Process` (mesmo Timer de 2s dos outros dados):

- **Rede**: `nmcli -g DEVICE,TYPE,STATE device status` acha o device conectado;
  se for wifi, `nmcli -g IN-USE,SIGNAL device wifi list` pega o sinal. Ambos os comandos usam
  `-g`, cujos valores **não são localizados** (diferente de `-t`, que devolve "sim"/"não" no
  locale pt_BR deste sistema — armadilha real, encontrada em teste).
- **Bluetooth**: `bluetoothctl show` (campo `Powered`) + `bluetoothctl devices Connected`
  (contagem). Toggle é `bluetoothctl power on/off` via `Quickshell.execDetached`.

`ModNetwork.qml`/`ModBluetooth.qml` leem `Sys.networkKind`/`Sys.networkSignal`/
`Sys.btPowered`/`Sys.btConnectedCount` — nenhum dos dois módulos importa
`Quickshell.Networking`/`Quickshell.Bluetooth`.

## O hub central

**Recolhido**: glyph de mídia + 5 barras de visualizer (Pipewire, leitura de pico real — não
FFT) + relógio, numa linha. Sem player, a parte de mídia anima a **largura** até sumir
(`Behavior on Layout.preferredWidth`, 340ms `OutBack`, overshoot 1.0), preservando o gesto de
"pílula crescendo" que o widget original já tinha, em vez de sumir seco.

**Expandido** (hover ou click — e `SUPER SHIFT M` trava aberto via IPC): `HubPanel.qml` desce
com o clip animado, hospedando páginas empilhadas num `ColumnLayout`:

1. `PanelMedia.qml` — porte do card original: capa (`ClippingRectangle`, não `Rectangle` +
   `clip`, que recorta no bounding box quadrado), título em IBM Plex Serif Light, seek por
   clique, controles via `MediaButton`.
2. `PanelCalendar.qml` — grid de mês com navegação, "hoje" destacado em `@alert`. Substitui o
   tooltip Pango do clock da waybar (que só existia porque Pango não tem `@import` — motivo de
   o `waybar-config.jsonc` inteiro ser template wallust) e o `gsimplecal` do `on-click`.

**Extensão futura:** uma página nova é um `PanelX.qml` inserido no `ColumnLayout` do
`HubPanel`. `Theme.panelZone` é o único número a revisar — tem de caber a soma máxima das
páginas.

### A armadilha de null que já pegou este código: `hasX` como guarda de acesso aninhado

`PanelMedia.qml` originalmente seguia o padrão do widget de mídia antigo:
`root.hasPlayer && root.player.trackTitle`. Com um MPRIS real tocando, isso derrubou o log
com uma enxurrada de `TypeError: Cannot read property 'trackTitle' of null` — não crasha o
app (erro de binding não derruba o Quickshell), mas é sinal de um bug real.

**Causa:** `hasPlayer` e `player` são duas propriedades **separadas**, cada uma recomputada
por um binding independente quando `Mpris.players.values` muda. Não há garantia de ordem
atômica entre as duas — existe uma janela real em que uma já atualizou e a outra não, e
`player.trackTitle` explode nela.

**Correção aplicada em todo o hub** (`Hub.qml`, `PanelMedia.qml`): nunca guardar leitura
aninhada com um booleano derivado à parte. Usar encadeamento opcional direto sobre a
referência nula, que é atômico porque não depende de uma segunda propriedade:

```qml
// Errado — dois property bindings independentes, sem ordem garantida
text: root.hasPlayer ? root.player.trackTitle : ""

// Certo — uma única leitura, segura mesmo se player virar null no meio do caminho
text: root.player?.trackTitle ?? ""
```

`hasPlayer` continua existindo, mas só para alternar `visible`/altura (nunca para acessar
`.algumaCoisa` de dentro do player).

## Notificações e OSD

**`Notifications.qml`** — `NotificationServer { keepOnReload: true }`, com
`onNotification: notif => notif.tracked = true` (sem isso a notificação é descartada na
hora). **Atenção:** este host tem `mako` instalado (`modules/home/packages.nix`) e ele registra
`org.freedesktop.Notifications` se estiver rodando — os dois competem pelo mesmo nome DBus, e
só um vence. Nada no `nous/hyprland.conf` inicia o `mako` (sem `exec-once`), então numa sessão
limpa deste perfil ele não sobe sozinho; se você o iniciar manualmente para testar outra
coisa, pare-o antes de testar notificações aqui.

**`Osd.qml`** — substitui `waybar-volume-popup` (GTK3, `GI_TYPELIB_PATH`, 5 `windowrulev2`).
`Connections` no `sink.audio` (instantâneo) e em `Sys.backlightFrac` (o brilho tem até ~2s de
atraso — não há sinal nativo de mudança em `/sys`, só o polling do `Sys.qml`; aceitável para
um OSD de feedback).

## Mudanças fora do `ui/`

- **`modules/system/power.nix`** (novo) — `services.upower.enable = true`. Sem ele
  `ModBattery.qml` mostra `0%`/`Unknown` **em silêncio**, sem erro no log.
- **`modules/home/theme.nix`** — `reloadApps` ficou profile-aware: só sobe/recarrega a
  waybar se `active/waybar/` existir; mata a waybar quando não existir (perfil `nous`).
- **`dotfiles/wallust/templates/colors-quickshell.json`** — dois tokens novos (`warning`,
  `surface`), aditivos.
- Removido de `dotfiles/profiles/nous/`: `waybar/` (`style.css`, `geometry.jsonc`); o
  `exec-once = waybar`, as `windowrulev2` do `waybar-volume-popup` e a `layerrule` de
  `quickshell-media` em `hypr/hyprland.conf`.

**Não tocado** (o perfil `default` depende): `modules/home/waybar.nix`, `packages.nix`
(waybar, `waybar-volume-popup`, `waybar-cpu-temp`, `gsimplecal`), `modules/system/udev.nix`,
`wallust.toml`, `wallust/templates/waybar-config.jsonc` e `colors-waybar.css`,
`dotfiles/waybar/scripts/`, `dotfiles/profiles/default/` inteiro.

## Verificação

```bash
qs log -f                                  # erros de binding NÃO derrubam o app — deixe aberto
hyprctl layers                             # quickshell-bar / -notifications / -osd, e NADA de waybar
hyprctl monitors | grep reserved           # esperado "0 42 0 0"

qs ipc call media playPause                # mesmo target/funções do widget antigo — binds não mudaram

theme-profile default                      # waybar sobe, quickshell-bar some
theme-profile nous                         # waybar morre, quickshell-bar sobe
```
