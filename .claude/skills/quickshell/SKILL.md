---
name: quickshell
description: Criar, editar e depurar widgets Quickshell (QML/QtQuick layer-shell) neste rice NixOS+Hyprland. Use ao mexer em dotfiles/quickshell/, ao criar qualquer widget de desktop novo (mídia, volume, bateria, workspaces, notificações, tray, OSD, lock screen), ao migrar um módulo da waybar para Quickshell, ou ao responder qualquer dúvida sobre a API do Quickshell (PanelWindow, PopupWindow, WlrLayershell, MPRIS, Pipewire, UPower, Hyprland IPC). Cobre a API 0.3.0 exata, os padrões de layer-shell, o design system wallust e as armadilhas específicas deste hardware.
---

# Quickshell — widgets para este rice

Quickshell é um framework QML/QtQuick para construir shells de desktop no Wayland. Diferente
da waybar (que renderiza módulos GTK dentro de uma barra), cada janela Quickshell é uma
**superfície wlr-layer-shell própria** — o que permite cards que descem, popups, OSDs e
animações que a waybar estruturalmente não consegue fazer.

> **Regra de ouro deste repo:** MCP first. Mas **não existe** `mcp__nix-ricing__quickshell_*` —
> o server não cobre Quickshell. Aqui, editar o `.qml` direto é o caminho correto. As tools MCP
> continuam valendo para o resto: `mcp__nixos__nix` para pacotes/opções, `waybar_read_section`
> antes de mexer na barra, `theme_read_palette`/`theme_get_color` para ler a paleta atual,
> `codebase-memory` para navegar código Python. Ao delegar a subagentes, repasse esta regra.

## Como o Quickshell vive neste repo

| | |
|---|---|
| Config | `dotfiles/quickshell/shell.qml` |
| Symlink | `modules/home/quickshell.nix` → `~/.config/quickshell/` via `mkOutOfStoreSymlink` |
| Start | `exec-once = quickshell` em `dotfiles/hypr/hyprland.conf` |
| Paleta | `~/.config/quickshell/colors.json`, gerada por wallust |
| Versão | 0.3.0 (nixpkgs) |

**Editar `.qml` tem efeito imediato** — o Quickshell observa o arquivo e recarrega sozinho.
Não precisa de `home-manager switch`; só a mudança do wiring Nix precisa. O Quickshell
descobre `shell.qml` sozinho em `~/.config/quickshell/` (sem flag `-c`/`-p`).

Widget novo entra como **arquivo QML no mesmo processo**, nunca como um segundo `exec-once` —
um processo por widget desperdiça memória (FAQ oficial), e num Core i5 de 2012 isso importa.

## O design system é inegociável

Cores **nunca** são hex literal no QML. A fonte única é o wallpaper → wallust → por app.
O Quickshell não tem `@import`, então lê a paleta em runtime:

```
dotfiles/wallust/templates/colors-quickshell.json  →  ~/.config/quickshell/colors.json
```

São exatamente **6 tokens** — não invente outros sem adicionar ao template:

| Token | Origem wallust | Uso |
|---|---|---|
| `background` | `{{background}}` | fundo de cards, barra |
| `foreground` | `{{foreground}}` | — |
| `primary` | `{{color4}}` | acento, ícones ativos, progresso |
| `secondary` | `{{color2}}` | acento secundário |
| `alert` | `{{color1}}` | crítico, bateria baixa, urgente |
| `text` | `{{foreground}}` | texto |

Hierarquia se faz com **alpha sobre os tokens**, não com cores novas:
`Qt.alpha(Theme.text, 0.7)` para texto secundário, `0.3` para desabilitado,
`Qt.alpha(Theme.primary, 0.18)` para trilhos/fundos sutis. (O `shell.qml` atual tem um helper
`withAlpha()` porque foi escrito antes; `Qt.alpha()` é nativo e faz o mesmo.)

Ler a paleta, com fallback para checkout limpo (o `colors.json` é gitignored e não existe
antes do primeiro `update-theme`):

```qml
FileView {
    path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
    watchChanges: true
    onFileChanged: reload()          // watchChanges só avisa; não recarrega sozinho
    onLoaded: {
        try { root.colors = JSON.parse(text()) }
        catch (e) { console.warn("colors.json inválido, mantendo fallback:", e) }
    }
}
```

Isso é o que faz o widget **re-tematizar ao vivo** a cada `update-theme`, sem restart.

### Coerência visual com a waybar (perfil `default`)

Valores extraídos de `dotfiles/profiles/default/waybar/style.css` (caminho atual — o layout
por perfil vive em `dotfiles/profiles/<name>/`, não em `dotfiles/waybar/` direto) — respeite-os
para os widgets lerem como parte da mesma barra:

- Fonte: `"JetBrainsMono Nerd Font"`, fallback `"Symbols Nerd Font"`; base **13px**
- Raios: **16px** pill externo · **12px** módulo · **10px** botão · **14px** tooltip/card
- Padding típico: `4px 8px`; margem entre módulos: `2px`
- Opacidade dos pills: **0.88** sobre o background (é o `alpha(@base, 0.88)` do CSS)
- Cards flutuantes: opacidade **0.94**, raio 14, borda `Qt.alpha(primary, 0.25)`

### Perfil `nous`: a barra inteira é Quickshell, não só um widget

O perfil `nous` não roda waybar — `dotfiles/profiles/nous/quickshell/` é a barra completa
(workspaces, hub central, módulos de status, tray, notificações, OSD), não um widget avulso.
Arquitetura completa: [`docs/quickshell-bar-nous.md`](../../../docs/quickshell-bar-nous.md).
Métricas extraídas de `dotfiles/profiles/nous/waybar/style.css` **antes de ser removido**
(preservadas em `quickshell/ui/Theme.qml`), para não recalibrar de novo:

- Fonte: `"IBM Plex Mono"`, fallback `"Symbols Nerd Font"`; base **13.5px**; clock **14px/Medium**
- Raio **0 em tudo** — "o gesto central do perfil", nada de pill/raio como no `default`
- Grid de **3.5px** (paddings `3.5 / 7 / 10.5 / 14`); módulo de status `3.5px 10.5px`
- `minWidth` dos módulos de status: **52px** (impede a barra de "pular" ao trocar de estado)
- Régua entre módulos: 1px em `alpha(text, 0.08)`; filete inferior da barra: 1px em
  `alpha(primary, 0.35)`
- Hover: `alpha(primary, 0.14)`, texto vira `text`
- Durações: `animFast: 160`, `animNormal: 200` (perfil é "precise, technical", mais seco que o
  220/280 do `default`)

### Arquitetura recomendada quando surgir o 2º widget

Hoje o `shell.qml` é um arquivo só, com a paleta inline — o certo para um widget. Ao
adicionar o segundo, extraia antes de duplicar:

```
dotfiles/quickshell/
  shell.qml              # só compõe os widgets
  Theme.qml              # pragma Singleton: paleta + raios + fonte + durações
  Widgets/Media.qml
  Widgets/Volume.qml
```

```qml
// Theme.qml
pragma Singleton
import Quickshell
Singleton {
    property var colors: ({ /* fallback */ })
    readonly property color primary: colors.primary
    readonly property int radiusCard: 14
    readonly property int animFast: 220
    readonly property int animNormal: 280
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    FileView { /* ... lê colors.json ... */ }
}
```

Precisa de um `qmldir` com `singleton Theme 1.0 Theme.qml` ao lado, e os widgets importam
com `import qs.Widgets` / `import "."`. Um `Theme` singleton é o equivalente QML do que o
`colors.css`/`colors.rasi` já são para waybar e rofi — mantém o design system com uma fonte
só. **Não faça essa refatoração sem o usuário pedir**; documente que é o caminho.

## Pré-requisitos de sistema (verificado neste host)

Os serviços do Quickshell falam D-Bus com daemons do sistema. Se o daemon não roda, o serviço
**não dá erro** — as propriedades ficam zeradas e o widget renderiza "quase certo". Estado real
desta máquina:

| Serviço QML | Daemon | Estado aqui |
|---|---|---|
| `Pipewire` | pipewire (user) | ✅ ativo |
| `Bluetooth` | bluez | ⚠️ daemon ativo, mas ver nota abaixo |
| `Networking` | NetworkManager | ⚠️ daemon ativo, mas ver nota abaixo |
| `Polkit` | polkit | ✅ ativo (`configuration.nix:126`) |
| `Hyprland` | socket do compositor | ✅ nativo |
| `Mpris` | por aplicação | ✅ |
| `Notifications` | o próprio Quickshell vira o daemon | ⚠️ conflita se já houver outro (mako instalado, ver abaixo) |
| **`UPower`** | upower | ✅ ativo (`modules/system/power.nix`, desde a migração do perfil `nous` para barra Quickshell) |

**`Quickshell.Networking` e `Quickshell.Bluetooth` existem no build (0.3.0, nixpkgs) mas
ficaram permanentemente vazios em teste isolado neste host** — `Networking.devices.values.length
=== 0` e `Bluetooth.adapters.values.length === 0` o tempo todo, apesar de NetworkManager e bluez
rodando e com dispositivos reais conectados (confirmado fora do Quickshell via
`busctl`/`nmcli`/`bluetoothctl`). Não é sobre o daemon estar ou não ativo — é o binding do
Quickshell contra esse backend específico que não popula neste sistema. **Não assuma que os
dois tipos funcionam sem testar isolado primeiro** (`qs -p` + `console.warn` nos valores, ver
`dotfiles/profiles/nous/quickshell/ui/Sys.qml` para o teste que expôs isto). O fallback usado no
perfil `nous` é `Process` com `nmcli -g ...`/`bluetoothctl`, documentado em
`docs/quickshell-bar-nous.md`.

`UPower` **funciona neste host** desde que `services.upower.enable = true;` (opção validada
contra o nixpkgs deste flake) — sem ele o widget de bateria mostraria `0%`/`Unknown` em
silêncio (era o caso antes da migração do `nous`; `Could not launch service
org.freedesktop.UPower` no log). A waybar nunca precisou disso: lê `/sys/class/power_supply`
direto.

**Notificações:** este host tem `mako` instalado (`modules/home/packages.nix`) — se estiver
rodando, ele registra `org.freedesktop.Notifications` e um `NotificationServer` do Quickshell
não consegue registrar o mesmo nome (ver próximo parágrafo). Nada o inicia automaticamente
(sem `exec-once`), mas confira antes de assumir que seu `NotificationServer` está quebrado.

`NotificationServer` só registra em `org.freedesktop.Notifications` se **nenhum outro daemon**
estiver registrado. Ele reclama e tenta de novo quando o outro sair — verifique antes de
assumir que o widget está quebrado.

## Regras de código

- `pragma ComponentBehavior: Bound` no topo de arquivos com delegates — torna `modelData`
  corretamente escopado. Com ele, delegates precisam de `required property var modelData`.
- `RowLayout`/`ColumnLayout`, **nunca** `Row`/`Column` (estes não alinham a pixel).
  O `spacing` default do Layout é **5** — declare sempre.
- Tamanho flui: `implicitWidth/Height` de baixo para cima, `width/height` de cima para baixo.
  Nunca dimensione container por `childrenRect` (loop de binding — ver gotchas §6).
- Animação: `Behavior on <prop> { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }`.
  Só `opacity`, `height`/`width`, `x`/`y`, `scale`. Nada de blur em QML (gotchas §10).
- Serviço nativo > polling. `Mpris`, `Pipewire`, `UPower`, `SystemTray`, `Hyprland` são
  event-driven; scripts bash em `Process` com `interval` são o antipadrão que já removemos
  daqui (os antigos `waybar-media-play`/`waybar-media-info`).
- `?.` e `??` funcionam em QML e evitam metade dos erros de binding com serviço vazio:
  `Pipewire.defaultAudioSink?.audio?.volume ?? 0`.

## Direção estética

O objetivo não é "um widget que funciona", é um rice que alguém pararia para olhar no
r/unixporn. Antes de codar, escolha uma direção e execute com precisão:

- **Comprometa-se com um gesto.** O widget de mídia tem um: um thumb discreto que *desce* num
  card. Um widget sem gesto próprio é um retângulo com texto.
- **Movimento com intenção.** Revelação escalonada, largura que cresce no item focado
  (ver workspaces em `patterns.md` §5), progresso que desliza. Sempre `OutCubic`, ~200–280ms.
  Instantâneo parece quebrado; acima de 400ms parece lento.
- **Profundidade por alpha e raio**, não por sombra pesada. Fundo 0.88–0.94, bordas de 1px em
  `alpha(primary, 0.25)`.
- **Densidade.** Fonte 11–12px para metadados secundários, 14px bold para o primário. Espaço
  em branco é hierarquia.
- **Sem "AI slop":** nada de gradiente roxo, nada de card genérico centralizado, nada de emoji
  no lugar de glyph Nerd Font. Fique na paleta wallust — ela muda com o wallpaper, então o
  widget precisa ficar bom com *qualquer* paleta, não com uma escolhida a dedo.

## Fluxo ao criar um widget

1. Confira se já existe serviço nativo para o dado (`references/api-services.md`) antes de
   pensar em `Process`.
2. Se substituir um módulo da waybar: leia o módulo atual com `waybar_read_section` e remova-o
   de `dotfiles/wallust/templates/waybar-config.jsonc` (**não** do `~/.config/waybar/config.jsonc`,
   que é gerado) e do `style.css`.
3. Escreva o QML. Copie o esqueleto de `references/patterns.md`.
4. Teste isolado antes de plugar no shell: `qs -p /caminho/arquivo.qml`.
5. Verifique os erros: `qs log -f` — **erro de binding não derruba o app**, só deixa a
   propriedade no default.
6. Alinhamento de layer-shell: `hyprctl layers` e `hyprctl monitors` (campo `reserved`) para
   achar os offsets. Sempre defina `WlrLayershell.namespace`.
7. Rode `update-theme` e confirme que o widget continua legível com outra paleta.
8. Atualize `CLAUDE.md` se a mudança for estrutural (é regra permanente deste repo).

## Referências

Carregue sob demanda — não leia tudo de uma vez:

- **`references/gotchas.md`** — leia **antes de escrever QML novo**. 14 armadilhas: animação de
  superfície layer-shell, geometria do `HoverHandler`, offset de âncora, QTBUG-137166,
  `childrenRect`, `position` do MPRIS, `PwObjectTracker`, limites da Intel HD 4000.
- **`references/patterns.md`** — 13 receitas prontas: drop-down no hover, popup, OSD de volume,
  bateria, workspaces, notificações, tray, relógio, por-monitor, `Process`, IPC, lock screen,
  blur do compositor.
- **`references/api-core.md`** — `Quickshell`, `Quickshell.Io`, `Quickshell.Wayland`,
  `Quickshell.Widgets`. Assinaturas exatas extraídas do pacote instalado.
- **`references/api-services.md`** — `Hyprland`, `Mpris`, `Pipewire`, `UPower`,
  `Notifications`, `SystemTray`, `Bluetooth`, `Networking`, `Pam`, `Greetd`, `DBusMenu`.

Ambos os arquivos de API vêm dos `.qmltypes` do `quickshell-0.3.0` instalado — são a verdade
deste sistema, não conhecimento de treinamento. **Prefira-os à memória**; a API do Quickshell
muda entre releases e tem breaking changes assumidas pelo projeto.

## Comandos

```bash
qs log -f                  # log da instância rodando (erros QML vão pra cá)
qs log -t 100              # últimas 100 linhas
qs list                    # instâncias rodando
qs -p arquivo.qml          # testa um QML isolado
qs ipc show                # lista targets de IPC expostos pelo shell
qs kill                    # mata a instância
quickshell -v / -vv        # sobe verbosidade (INFO / DEBUG)
```
