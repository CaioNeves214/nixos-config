# CLAUDE.md

Guia do Claude Code (claude.ai/code) para este repositório.

**Este arquivo é um roteador, não um manual.** Ele contém apenas o que vale para *todo* prompt:
como decidir onde buscar contexto, o que é este repo, e as invariantes que nunca podem ser
quebradas. Todo o detalhe operacional vive em **skills**, carregadas sob demanda — ver o mapa
abaixo.

---

## 🔁 REGRA 1 — Roteamento de skills antes de qualquer plano

A ordem é sempre esta, em **todo** prompt:

> **entender o pedido → rotear skills → consultar MCP → planejar → executar**

1. **Entenda o objetivo real** por trás da instrução, não a leitura literal dela.
2. **Percorra a listagem de skills disponíveis e decida pelo nome + descrição.** A listagem já
   traz o resumo de cada skill; **não abra o corpo das skills uma a uma para decidir**. Rotear
   custa ler uma tabela, não ler as skills.
3. **Se uma ou mais forem pertinentes, carregue-as via `Skill` antes de escrever qualquer plano ou
   tocar em qualquer arquivo.** Se nenhuma se aplica, siga direto para a Regra 2.
4. **Roteamento não é uma checagem única do início.** Se no meio do raciocínio ou da execução
   ficar claro que uma skill não cogitada antes é útil — ou essencial — **carregue-a naquele
   momento**, mesmo com o plano já em andamento. Nunca prossiga sem ela só porque a decisão
   inicial foi "nenhuma se aplica".

**Por quê:** cada skill carrega o contexto já calibrado daquele pedaço do rice — valores medidos
na tela, armadilhas já pagas com sessões de debug, invariantes que quebram o `switch` se
violadas. Trabalhar sem a skill certa é reinventar decisões que já foram tomadas e testadas aqui.
Trabalhar com todas carregadas é desperdiçar contexto. **Carregue o mínimo suficiente — e o
suficiente.**

## 🔒 REGRA 2 — MCP first, sempre

**Antes de abrir qualquer arquivo, antes de planejar qualquer implementação e antes de escrever
qualquer arquivo, verifique se um MCP server (`nix-ricing`, `nixos`, `codebase-memory`) fornece
essa informação — e use-o primeiro.** `Read`/`Grep`/`Write` direto só entram depois de esgotar as
tools MCP relevantes, ou quando não existe tool MCP aplicável.

| Necessidade | Rota obrigatória |
|---|---|
| Ler/escrever config de Hyprland, Waybar, Kitty, Hyprpaper, paleta | `mcp__nix-ricing__*` |
| Pacote nixpkgs, opção NixOS/home-manager, canal, flake, cache | `mcp__nixos__nix`, `nix_versions` |
| Onde um símbolo está definido, quem chama o quê, impacto de um diff | `mcp__codebase-memory__*` |
| QML, `.nix`, Markdown, CSS de perfil (sem tool MCP) | `Read`/`Edit` direto — legítimo |

Isso vale integralmente para o **Plan Mode**: levantar o estado real via MCP antes de esboçar
qualquer plano, nunca assumir a partir de memória.

**E vale para subagentes.** Um subagente **não herda este arquivo**. Ao delegar via `Agent`/`Task`,
repita as duas regras no prompt: rotear skills pelo nome/descrição, e consultar os MCP servers
antes de ler, planejar ou escrever.

Inventário completo das tools e o roteamento fino entre os três servers: skill **`mcp-routing`**.

---

## 🗺️ Mapa de skills

Roteie por esta tabela. As descrições completas (com os gatilhos) estão na listagem de skills da
sessão.

| Skill | Carregue quando o pedido envolver |
|---|---|
| **`theme-profiles`** | perfis visuais, `theme-profile`, symlink `active`, criar/editar um perfil, decidir per-profile vs compartilhado, `geometry.jsonc` |
| **`design-system`** | cor, paleta, tokens, wallust, `update-theme`, wallpaper, templates `colors-*`, restilizar visualmente qualquer app |
| **`quickshell`** | QML/QtQuick, layer-shell, widget de desktop, a barra do `nous`, o widget de mídia do `default`, API do Quickshell |
| **`nix-wiring`** | `flake.nix`, `modules/system/*`, `modules/home/*`, adicionar pacote/serviço, fronteira system↔home, rebuild e validação |
| **`hardware-quirks`** | áudio CS4206/EasyEffects, GPU Intel HD 4000, GTK4, fan, bateria/AC/UPower, `nix-ld`, algo que falha em silêncio |
| **`sddm-login`** | tela de login, greeter SDDM, `dotfiles/sddm/`, avatar, blur do login |
| **`gtk-popups`** | scripts Python PyGObject, `volume-popup`, `wallpaper-picker`, `GI_TYPELIB_PATH`, typelibs |
| **`mcp-routing`** | qual MCP usar, nome exato de uma tool, (re)indexar o grafo, delegar a subagente |

Documentos longos, referenciados pelas skills (não carregue direto sem passar pela skill):
`docs/media-widget.md`, `docs/quickshell-bar-nous.md`, `docs/MCP_SETUP.md`, `docs/mcp_server.md`,
e o **`DESIGN.md` de cada perfil** (`dotfiles/profiles/<name>/DESIGN.md`) — leitura obrigatória
antes de editar aquele perfil.

---

## O que é este repo

Configuração **NixOS + Home Manager** de um **MacBook Pro 2012** rodando **NixOS 25.05** com
**Hyprland** (compositor Wayland), gerenciada como **flake**. Host único: `macbookpro2012`
(`x86_64-linux`).

Três eixos organizam tudo:

1. **Wiring Nix** (`flake.nix`, `hosts/`, `modules/`) — o que é instalado e ligado. Mudança aqui
   exige `nixos-rebuild switch`.
2. **Dotfiles** (`dotfiles/`) — como as coisas parecem e se comportam. Linkados por
   `mkOutOfStoreSymlink`, então **edição tem efeito imediato, sem rebuild**.
3. **Design system** (`dotfiles/wallust/`) — a cor de todos os apps vem de uma fonte só, derivada
   do wallpaper. **Nunca hardcode hex num dotfile.**

## Estrutura (visão macro)

```
flake.nix                     # inputs + nixosConfigurations (host único)
hosts/macbookpro2012/         # configuration.nix + hardware-configuration.nix (gerado)
home/caio.nix                 # entry point do Home Manager
modules/
  system/                     # audio bluetooth boot fan locale login networking
                              # packages power storage udev users zsh
  home/                       # dev easyeffects git hyprland kitty packages quickshell
                              # rofi theme walker waybar
dotfiles/
  profiles/<name>/            # PER-PROFILE: um look completo cada (default, nous) + DESIGN.md
  wallust/                    # compartilhado: wallust.toml + templates de cor
  sddm/theme/                 # compartilhado: tema QML do login
  scripts/, waybar/scripts/   # compartilhado: popups GTK3 e helpers Python
  wallpapers/                 # compartilhado
mcp_server/                   # server MCP nix-ricing (Python)
docs/                         # documentos longos referenciados pelas skills
.claude/skills/               # as skills deste repo
```

Tudo sob `dotfiles/profiles/<name>/` é **per-profile**; todo o resto de `dotfiles/` é
**compartilhado por todos os perfis**.

## Comandos essenciais

```bash
# Aplica system + home. É o ÚNICO comando de switch: o home-manager roda como módulo
# NixOS e o flake não expõe `homeConfigurations`, então `home-manager switch` falha.
sudo nixos-rebuild switch --flake .#macbookpro2012

# Validação rápida, sem build e sem sudo
nix eval .#nixosConfigurations.macbookpro2012.config.system.build.toplevel.drvPath

theme-profile [nome]     # troca o perfil visual — ao vivo, sem rebuild
update-theme [img]       # wallpaper + regenera a paleta + recarrega os apps
wallpaper-picker         # popup GTK3 de seleção (SUPER+W)

nix flake check          # valida outputs/sintaxe
nix flake update         # atualiza inputs
```

## Invariantes — quebrar qualquer uma destas custa caro

Cada uma está explicada na skill indicada. Estão aqui porque violá-las causa dano fora do escopo
da tarefa que as encontrou.

1. **Nenhum script pode re-apontar um caminho declarado pelo Home Manager.** As declarações apontam
   para caminhos **constantes** sob `~/.config/theme/active/`; re-apontar produz `collision=1` e um
   **`nixos-rebuild switch` que falha**. → `theme-profiles`
2. **Includes de cor em arquivos de perfil usam caminho absoluto.** Relativo resolve dentro do
   repo, não em `~/.config/`. Exceção deliberada: `@theme "theme.rasi"` do rofi. → `theme-profiles`
3. **Nunca edite arquivo gerado** (`~/.config/**/colors.*`, `waybar/config.jsonc`). Edite o
   template em `dotfiles/wallust/templates/` e rode `update-theme`. → `design-system`
4. **Nunca hardcode hex num dotfile.** Referencie tokens. → `design-system`
5. **`quickshell.nix` symlinka `shell.qml` e `ui/` individualmente, nunca o diretório** — symlink
   de diretório faz o wallust escrever dentro da working tree do repo. → `design-system`,
   `quickshell`
6. **`nous` não tem waybar.** Qualquer raciocínio "a barra é a waybar" está errado nesse perfil.
   → `theme-profiles`
7. **Num checkout limpo, os arquivos de cor não existem** — `update-theme <wallpaper>` uma vez
   depois do primeiro switch. → `design-system`
8. **Nesta máquina, backend ausente falha em silêncio**, não com erro (UPower zerado, GTK4 sem
   texto, bindings Quickshell vazios). Ao ver algo "quase certo", suspeite do backend antes do
   código. → `hardware-quirks`

## Manutenção deste arquivo

- **Mudança estrutural exige atualizar a documentação junto** — é regra permanente deste repo.
- **Detalhe vai para a skill, não para cá.** Este arquivo só cresce quando surge uma regra que vale
  para *todo* prompt ou uma invariante nova. Um tópico novo que só interessa a um tipo de tarefa
  vira uma **skill nova** (e uma linha no mapa acima).
- Ao criar uma skill, escreva a `description` com **gatilhos concretos** — nomes de arquivo,
  comandos, sintomas, vocabulário que o usuário usa. É por ela que o roteamento da Regra 1 decide,
  e uma descrição vaga faz a skill nunca ser carregada.
