---
name: design-system
description: O sistema de cores único deste rice — wallust extrai a paleta do wallpaper e a distribui para todo app. Use para qualquer tarefa envolvendo cor, paleta, tema, wallpaper, tokens, wallust, update-theme, os templates em dotfiles/wallust/templates/, os arquivos colors.* gerados, ou ao restilizar visualmente qualquer app (hyprland, kitty, rofi, walker, waybar, quickshell, sddm). Use também antes de escrever qualquer hex literal num dotfile — a resposta quase sempre é "use um token".
---

# Design System — a fonte única de cor

Cores **não são hardcoded por app**. Elas são derivadas do wallpaper atual pelo
[`wallust`](https://codeberg.org/explosion-mental/wallust) e distribuídas para cada app.
`dotfiles/wallust/wallust.toml` é a fonte única de verdade.

**Nunca escreva hex literal num dotfile.** Para restilizar um app mantendo a coerência, edite o
dotfile dele para referenciar **tokens** diferentes — nunca uma cor nova.

## O fluxo

```
update-theme <img>
  → seta o wallpaper (hyprpaper)
  → wallust extrai a paleta e renderiza cada dotfiles/wallust/templates/colors-*
    num include por app
  → recarrega os apps ao vivo
```

Num perfil de **paleta fixa** (que tem `palette.toml`) o caminho é outro: `theme-profile` converte
o TOML com `dotfiles/scripts/palette-to-wallust.py` e aplica com `wallust cs -q -s <name>` — os
mesmos templates, origem diferente; e `update-theme` **pula o `wallust run`** para não destruir a
paleta. Ver skill **`theme-profiles`**.

## Extração (wallust.toml)

```toml
backend = "resized"      # equilíbrio precisão/velocidade
color_space = "lch"      # espaço para escolher as cores prominentes
palette = "dark"         # 8 cores escuras, fundo escuro, contraste claro
check_contrast = true    # garante texto legível sobre o fundo
```

Mudar o look de **todo o sistema**: troque o wallpaper e rode `update-theme`, ou ajuste
`color_space`/`palette`/`check_contrast` aqui.

## Os tokens

Cinco tokens semânticos, iguais em todos os templates (nomes variam com a sintaxe do app):

| Token | Origem wallust | Papel |
|---|---|---|
| `base` / `background` | `{{background}}` | fundo |
| `text` / `foreground` | `{{foreground}}` | texto |
| `primary` | `{{color4}}` | acento, ativo, progresso |
| `secondary` | `{{color2}}` | acento secundário |
| `alert` | `{{color1}}` | crítico, urgente, bateria baixa |

O template do Quickshell tem **8** tokens: os 5 acima (com `background`/`foreground`/`text`) mais
`warning` (`{{color3}}`) e `surface` (`{{color8}}`), adicionados para o perfil `nous`.

Hierarquia se faz com **alpha sobre os tokens**, não com cores novas.

## Templates → destino → como o app consome

Todos os arquivos gerados vivem em `~/.config/` (ou `~/.cache/`), são **gitignored** e **nunca
devem ser editados à mão**. Edite o *template* no repo e rode `update-theme`.

| Template (`dotfiles/wallust/templates/`) | Gera | App consome via |
|---|---|---|
| `colors-hypr.conf` | `hypr/colors.conf` | `source = ~/.config/hypr/colors.conf` |
| `colors-kitty.conf` | `kitty/colors.conf` | `include /home/caio/.config/kitty/colors.conf` (absoluto) |
| `colors-waybar.css` | `waybar/colors.css` | `@import url("file:///home/caio/.config/waybar/colors.css")` no `style.css` |
| `colors-rofi.rasi` | `rofi/colors.rasi` | `@import "/home/caio/.config/rofi/colors.rasi"` no `theme.rasi` |
| `colors-walker.css` | `walker/colors.css` | `@import url("file:///home/caio/.config/walker/colors.css")` no `themes/walker.css` |
| `colors-quickshell.json` | `quickshell/colors.json` | `FileView` com `watchChanges: true` |
| `colors-sddm.conf` | `~/.cache/sddm-colors.conf` | copiado por `update-theme` para `/var/lib/sddm-theme/colors.conf` |
| `waybar-config.jsonc` | `waybar/config.jsonc` | **o layout inteiro**, gerado (ver abaixo) |

Os caminhos absolutos nos includes são obrigatórios porque os dotfiles do perfil carregam de
`~/.config/theme/active/…` — um caminho relativo resolveria dentro do repo. Ver skill
**`theme-profiles`**, regra 1.

As linhas de waybar só valem para perfis baseados em waybar (`default`). O `nous` não tem waybar e
lê `quickshell/colors.json` para a **barra inteira**, não só para um widget de mídia.

## Os quatro apps que não conseguem `@import` tokens

1. **`waybar/config.jsonc`** — o tooltip do calendário usa Pango markup inline
   (`<span color=…>`), que não tem mecanismo de import, então **o config inteiro é um template
   wallust** (`wallust/templates/waybar-config.jsonc`). Edite *layout* ali, não em `~/.config`.
   O `waybar.nix` deliberadamente **não** symlinka `config.jsonc`. Geometria vem do perfil, não
   deste template.
2. **Popups GTK3** (`volume-popup.py`, `wallpaper-picker.py`) — leem o `rofi/colors.rasi` gerado
   em runtime via um `load_colors()` com regex e montam o CSS a partir dos tokens (paleta de
   fallback só se o arquivo faltar). **Mantenha os fallbacks dos dois em sincronia.** Ver skill
   **`gtk-popups`**.
3. **Greeter do SDDM** (`dotfiles/sddm/theme/Main.qml`) — roda como usuário `sddm` e não lê
   `/home/caio`, então `update-theme` publica os assets em `/var/lib/sddm-theme/`. Ver skill
   **`sddm-login`**.
4. **Quickshell** (`dotfiles/profiles/<name>/quickshell/`) — lê
   `~/.config/quickshell/colors.json` via `FileView` com `watchChanges: true`, com paleta de
   fallback embutida no QML para checkout limpo. No `default` isso re-tematiza o card de mídia; no
   `nous` o mesmo padrão vive em `quickshell/ui/Theme.qml` (singleton) e re-tematiza a **barra
   inteira** ao vivo a cada `update-theme`.
   ⚠️ `quickshell.nix` symlinka `shell.qml` e `ui/` **individualmente, não o diretório** — um
   symlink de diretório faria o wallust escrever `colors.json` dentro da working tree do repo
   (já aconteceu, e o arquivo acabou versionado no git). Ver skill **`quickshell`**.

## Comandos

Definidos em `modules/home/theme.nix` como `writeShellScriptBin`, então estão no `PATH`:

- **`update-theme [img|path]`** — aplica wallpaper + regenera a paleta + recarrega os apps. Sem
  argumento, re-aplica o wallpaper atual (`~/.cache/current-wallpaper`).
- **`wallpaper-picker`** — popup GTK3 para escolher wallpaper, ligado a **SUPER+W** no
  `hyprland.conf`. Chama `update-theme` na seleção.
- **`theme-profile [name]`** — troca de perfil visual (skill **`theme-profiles`**).

## Bootstrap

Os arquivos gerados (`colors.*`, `waybar/config.jsonc`) são gitignored e **não existem num
checkout limpo** — rode `update-theme <wallpaper>` uma vez depois do primeiro
`nixos-rebuild switch`, ou a waybar/as cores não estarão presentes.

## Ler a paleta atual sem abrir arquivo

Regra de ouro do repo: use MCP antes de `Read`.

- `mcp__nix-ricing__theme_read_palette` — paleta gerada atual
- `mcp__nix-ricing__theme_get_color <NAME>` — um token só
- `mcp__nix-ricing__theme_list_wallpapers` — wallpapers disponíveis
- `mcp__nix-ricing__theme_set_wallpaper` — troca o wallpaper (dispara o fluxo do update-theme)

## Ao adicionar um app novo ao design system

1. Crie `dotfiles/wallust/templates/colors-<app>.<ext>` usando **os tokens**, não hex.
2. Registre em `[templates]` no `wallust.toml` (`template` é relativo a
   `~/.config/wallust/templates/`, `target` é caminho absoluto).
3. Faça o dotfile do app importar/ler o arquivo gerado — **com caminho absoluto**.
4. Se o app não tem mecanismo de import, escolha um dos 4 padrões acima; não invente um quinto.
5. Adicione o reload do app ao `update-theme` (`modules/home/theme.nix`).
6. Rode `update-theme` e confirme que o app fica legível com **outra** paleta também — a paleta
   muda com o wallpaper, então o app precisa ficar bom com qualquer uma.
