---
name: theme-profiles
description: Perfis visuais deste rice (default, nous) — o mecanismo do symlink ~/.config/theme/active, o comando theme-profile, e as regras para criar/editar/remover um perfil. Use ao criar um perfil novo, ao trocar/adicionar arquivos dentro de dotfiles/profiles/<name>/, ao mexer em hyprland.conf/kitty/rofi/walker/waybar de um perfil, ao decidir se algo é per-profile ou compartilhado, ao mexer em modules/home/theme.nix ou em qualquer módulo *.nix que aponte para active/, e sempre que aparecer "perfil", "theme-profile", "profile switch", "active symlink" ou "geometry.jsonc".
---

# Perfis visuais (theme profiles)

Um **perfil** é um look completo e autocontido: decoração do Hyprland, kitty, rofi, walker e a
camada de barra/mídia. Troca com **`theme-profile <name>`** — ao vivo, sem rebuild; sem argumento
mostra o atual e lista os outros.

Perfis existentes: `default` e `nous`.

> **Antes de editar um perfil, leia o `DESIGN.md` dele** — `dotfiles/profiles/<name>/DESIGN.md`
> tem paleta, fontes, raios, as constantes calibradas na tela e as verrugas conhecidas. Isso
> **não** está nesta skill de propósito: só interessa quando se trabalha naquele perfil
> específico.
>
> - `profiles/default/DESIGN.md` — o rice original: pills flutuantes, paleta derivada do wallpaper.
> - `profiles/nous/DESIGN.md` — look Nous Portal: cantos retos, paleta fixa, IBM Plex.

## O que é per-profile e o que é compartilhado

Tudo sob `dotfiles/profiles/<name>/` é **per-profile**. Todo o resto de `dotfiles/` é
**compartilhado** por todos os perfis:

```
dotfiles/
  profiles/<name>/       # per-profile: hypr, kitty, rofi, walker, [waybar], quickshell, gtk
  sddm/theme/            # compartilhado
  wallust/               # compartilhado (wallust.toml + templates)
  scripts/               # compartilhado (wallpaper-picker, palette-to-wallust, startup-fade)
  waybar/scripts/        # compartilhado (volume-popup.py, temperature.sh)
  wallpapers/            # compartilhado
```

Ao adicionar um arquivo, decida de qual lado ele está **antes** de escrever: um arquivo
compartilhado editado para agradar um perfil repinta todos os outros.

## O mecanismo é um único symlink mutável

```
~/.config/theme/active  ->  dotfiles/profiles/<name>/
```

Cada declaração do Home Manager aponta para um caminho **constante** sob `active/`, nunca para um
perfil direto. Isso não é estilo — é load-bearing:

> **Um script nunca pode re-apontar um caminho que o Home Manager declara.** O
> `check-link-targets.sh` do HM monta
> `homeFilePattern="$(readlink -e /nix/store)/*-home-manager-files/*"`; um target fora desse
> padrão é tratado como estrangeiro, o `cmp` vê conteúdo diferente e, porque o target **é** um
> symlink, o branch do `backupFileExtension` é pulado — o resultado é `collision=1` e um
> **`nixos-rebuild switch` que falha**. Manter o target declarado constante elimina isso.

O symlink `active` é criado automaticamente por um hook `home.activation` em
`modules/home/theme.nix` (apontando para `default`) se estiver faltando, então nada fica pendurado
num checkout limpo.

Além do hop do `active`, os dotfiles entram em `~/.config/` via
`config.lib.file.mkOutOfStoreSymlink` — ver a skill **`nix-wiring`** para o que isso implica
(edição ao vivo vs. quando um `switch` é obrigatório).

## Quatro regras ao adicionar qualquer coisa a um perfil

1. **Caminho absoluto nos includes de cor.** Os arquivos do perfil carregam de
   `~/.config/theme/active/…`, então um `include`/`@import` relativo resolve dentro do *repo*, não
   dentro de `~/.config/` onde o wallust escreve. A única exceção deliberada é o
   `@theme "theme.rasi"` do rofi, que **deve** continuar relativo para cada perfil pegar o seu
   próprio tema.
2. **O layout da waybar é compartilhado; só a geometria é per-profile** — e só para perfis que
   têm diretório `waybar/`. `wallust/templates/waybar-config.jsonc` é comum a todo perfil
   baseado em waybar e puxa `active/waybar/geometry.jsonc` via `include` da waybar. Como a waybar
   resolve duplicatas com *"the first defined value takes precedence"* (`man 5 waybar`), o
   template principal **não pode** redeclarar `height`/`margin-*` — ele venceria e o perfil seria
   silenciosamente ignorado. Qualquer outra coisa editada lá repinta **todos** os perfis com
   waybar.
3. **Quickshell não faz hot-reload na troca de perfil.** O watch dele é no *inode resolvido*, e
   virar o `active` não emite evento inotify — por isso `theme-profile` mata e respawna o
   Quickshell. (Mesma razão pela qual o `colors.json` *faz* hot-reload: o wallust executa uma
   escrita real.)
4. **No `default`, mudar a geometria da barra obriga a re-medir o widget de mídia.** O `shell.qml`
   se ancora contra a exclusive zone da waybar com `margins.top` e `barOffset` — ambos **medidos
   na tela**, nunca derivados no papel (procedimento em `profiles/default/DESIGN.md`). **Isso não
   se aplica ao `nous`**: a barra dele reserva a própria `exclusiveZone` e o hub se posiciona
   pela geometria da própria barra (`Theme.barHeight`/`Theme.panelWidth` em
   `quickshell/ui/Theme.qml`), então não existe aritmética de âncora cross-app para re-medir.

## `nous` não tem waybar

O perfil `nous` **não roda waybar** — a barra inteira é um app Quickshell standalone
(`dotfiles/profiles/nous/quickshell/`), não um módulo de waybar mais um widget de mídia separado
como no `default`. Consequências:

- `reloadApps` (em `modules/home/theme.nix`) é profile-aware: só sobe/recarrega a waybar quando o
  perfil recém-ativado tem diretório `waybar/`, e a mata caso contrário.
- A regra udev de `SIGUSR2` na waybar (`modules/system/udev.nix`) é irrelevante no `nous` — o
  módulo de bateria dele lê `Quickshell.Services.UPower` direto. Ver skill **`hardware-quirks`**.
- Arquitetura da barra: [`docs/quickshell-bar-nous.md`](../../../docs/quickshell-bar-nous.md).
  Para escrever/editar o QML, carregue também a skill **`quickshell`**.

**Verruga observada em teste:** ao reclamar a waybar para o `default` depois de estar no `nous`,
`hyprctl dispatch exec waybar` é intermitentemente instável — o dispatch retorna ok mas o
processo não sempre acaba rodando; rodar `theme-profile default` de novo resolve. O respawn
equivalente do `quickshell` nunca falhou assim em dezenas de testes. Não foi root-caused (ver
`profiles/nous/DESIGN.md` § "Barra Quickshell").

## Cor: paleta fixa vs. derivada do wallpaper

Se um perfil contém `palette.toml`, ele tem paleta **fixa**: `theme-profile` converte o arquivo
com `dotfiles/scripts/palette-to-wallust.py` em `~/.config/wallust/colorschemes/<name>.json` e
aplica com `wallust cs -q -s <name>`, que renderiza **os mesmos 7 templates** do fluxo do
wallpaper. Sem `palette.toml` (o perfil `default`), cai no `wallust run` sobre o wallpaper atual.

O `update-theme` sabe disso também: num perfil de paleta fixa ele troca a imagem do wallpaper mas
**pula o `wallust run`**, que destruiria a paleta.

**Para recolorir um perfil de paleta fixa: edite o `palette.toml` dele e rode
`theme-profile <name>`.** Esse arquivo é o único lugar onde as cores dele existem.

Detalhes do pipeline de cor (templates, tokens, quem consome o quê) estão na skill
**`design-system`**.

## Checklist para criar um perfil novo

1. `dotfiles/profiles/<novo>/` com, no mínimo, `hypr/hyprland.conf`, `kitty/kitty.conf`,
   `rofi/{config,theme}.rasi`, `walker/{config.toml,themes/walker.css}`, `gtk/popups.css`.
2. Decida se tem waybar. Se sim: `waybar/style.css` + `waybar/geometry.jsonc`. Se não: a barra
   tem que vir de `quickshell/`.
3. Includes de cor com **caminho absoluto** (regra 1).
4. Opcional: `palette.toml` para paleta fixa.
5. `DESIGN.md` documentando o look, os valores calibrados e as verrugas.
6. `exec-once` no `hyprland.conf` para o que o perfil precisa subir (hyprpaper, quickshell,
   waybar, `udiskie --tray`).
7. Nenhum módulo Nix novo é necessário se o perfil usa a mesma árvore de arquivos — os módulos já
   apontam para `active/`. Se o perfil introduz um arquivo linkado novo, aí sim mexa no módulo
   (skill **`nix-wiring`**) e rode `sudo nixos-rebuild switch --flake .#macbookpro2012`.
8. `theme-profile <novo>` e verifique com `update-theme` que continua legível.
