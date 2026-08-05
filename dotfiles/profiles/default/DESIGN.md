# Perfil visual `default`

O rice original. Superfícies flutuantes com cantos bem arredondados, sombras suaves e
**paleta derivada do wallpaper** — a cor muda toda vez que o papel de parede muda.

Ativar com `theme-profile default`. Para o mecanismo de perfis em si — o symlink `active`, a
regra de colisão do Home Manager — ver a seção "Perfis visuais" no `CLAUDE.md`.

> Este perfil não nasceu de uma spec: o visual foi construído direto no CSS/conf ao longo do
> tempo. Este arquivo documenta o que *está* lá, para servir de referência ao comparar com
> outros perfis e para não mexer sem querer no que é calibrado.

---

## Paleta — derivada do wallpaper

Não existe `palette.toml` aqui. É isso que faz `theme-profile default` cair no caminho do
`wallust run` sobre o wallpaper atual, em vez do `wallust cs`. `update-theme <img>` troca o
papel de parede **e** a paleta inteira junto.

Extração configurada em `dotfiles/wallust/wallust.toml` (compartilhado):
`backend = "resized"`, `color_space = "lch"`, `palette = "dark"`, `check_contrast = true`.

Os 5 tokens saem sempre dos mesmos slots: `base←background`, `text←foreground`,
`primary←color4`, `secondary←color2`, `alert←color1`.

**Consequência:** as cores não são escolhidas, são sorteadas. Um wallpaper de baixo contraste
pode gerar um `secondary` quase ilegível, e `secondary` ocupa o slot do *verde* ANSI — então
"verde" no terminal costuma sair de outra cor. É o custo de seguir o wallpaper.

## Tipografia

`JetBrainsMono Nerd Font` em tudo (waybar, kitty, quickshell), com `Symbols Nerd Font` de
fallback para glifos. O rofi não declara fonte e usa o padrão do sistema.

`font_family` é declarado explicitamente no `kitty.conf` — sem isso o kitty cai no
`monospace` do fontconfig, e instalar qualquer fonte nova mudaria o terminal sem querer.

## Geometria

Escala de raios generosa, decrescente por nível de aninhamento:

| Elemento | Raio |
|---|---|
| Placas da waybar (`.modules-*`) | 16 |
| Tooltip | 14 |
| Card de mídia (quickshell) | 14 |
| Módulos da waybar | 12 |
| Botões de workspace | 10 |
| Janela do rofi / capa do álbum | 10 |
| Janelas do Hyprland (`rounding`) | 10 |
| Thumb do player | 9 |
| Tray em alerta / inputbar do rofi | 6–8 |
| Barra de progresso | 2 |

- **Barra flutuante**: `height 42`, `margin-top 8`, `margin-left/right 12`. Os três grupos são
  placas separadas em `alpha(@base, 0.88)`, com borda de 1px em branco a 7% e sombra suave
  (`0 4px 24px`).
- **Hyprland**: `gaps_in 4`, `gaps_out 8`, `border_size 2`, blur ligado (`size 6`, `passes 2`).
- **Kitty**: `background_opacity 0.75` — o wallpaper pinta o terminal por baixo.
- **Animações**: `slidefade` em 7 ticks nos workspaces; transições de 0.25s na waybar.

## Constantes calibradas (não derivar no papel)

O widget de mídia do Quickshell se ancora contra a zona exclusiva da waybar. **Medidos na
tela**, mudam se a geometria da barra mudar:

| Constante | Valor aqui | Como remedir |
|---|---|---|
| `margins.top` | `-44` | `hyprctl monitors -j` → `reserved` (array é `[left, top, right, bottom]`); a regra é `top = y_desejado - reserved.top`, aqui `8 - 52` |
| `barOffset` | `37 + 40n` | `grim` + varredura de pixel: a placa de workspaces vai de x=12 até `36 + 40n`, e o thumb entra 1px depois |

(No perfil `nous` os mesmos valores são `-42` e `13 + 40n`, porque lá a barra é fechada e
encostada no topo.)

## Verrugas conhecidas

- **Bateria usa cores literais de CSS** (`lightgreen`, `gold`, `lightcoral`, `lime`) em
  `waybar/style.css`, fora do sistema de tokens. Sobrevive de antes do design system; o
  perfil `nous` corrigiu isso na cópia dele.
- **Sombras e bordas hardcoded**: `rgba(255,255,255,0.07)` nas bordas das placas e
  `rgba(0,0,0,0.35)` nas sombras — também fora dos tokens.
- **`@alert` não é usado no rofi**, só nos outros apps.

## Onde o perfil NÃO chega

- **Tela de login (SDDM)**: segue a cor (template `colors-sddm.conf`), não a fonte — ela é
  assada no `/nix/store` e o greeter não sabe qual perfil está ativo no boot.
- **Apps GTK** (thunar, nm-connection-editor): não seguem o tema.
