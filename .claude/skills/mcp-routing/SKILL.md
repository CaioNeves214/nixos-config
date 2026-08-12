---
name: mcp-routing
description: Inventário e roteamento dos MCP servers deste repo (nix-ricing, nixos, codebase-memory) — qual tool usar para qual pergunta, nomes exatos das tools, e como o server nix-ricing local está montado. Use quando não estiver claro qual MCP responde a pergunta, ao precisar do nome exato de uma tool, ao mexer em mcp_server/ ou .claude/mcp.json, ao (re)indexar o grafo de código, e ao delegar trabalho a subagentes (a regra de ouro precisa ser repassada explicitamente).
---

# Roteamento de MCP

A regra de ouro deste repo (`CLAUDE.md`) é **MCP first**. Esta skill é o mapa: qual server
responde o quê, com os nomes exatos das tools.

## Decisão em uma tabela

| A pergunta é sobre… | Server | Não use |
|---|---|---|
| valor de config do Hyprland/Waybar/Kitty/Hyprpaper, paleta atual | **nix-ricing** | `Read` no dotfile |
| pacote nixpkgs, opção NixOS/home-manager, canal, flake, cache, store path | **nixos** | memória de treinamento, `nix search` |
| onde um símbolo está definido, quem chama o quê, arquitetura, impacto de um diff | **codebase-memory** | `Grep`/`Glob` varrendo arquivos |
| QML do Quickshell, `.nix`, Markdown, CSS de perfil | *nenhum* → `Read`/`Edit` direto | — |

O último caso é real e legítimo: **não existe** tool MCP para QML, Nix ou Markdown. Nesses casos
`Read`/`Edit` é o caminho correto, não um desvio da regra.

## nix-ricing — server local deste repo

Python, definido em `mcp_server/`, registrado em `.claude/mcp.json` como
`python3 -m mcp_server.server` com `PYTHONPATH=/home/caio/nix-config`. Cada tool lê/escreve um
recorte da config em vez do arquivo inteiro — é isso que economiza tokens.

**Hyprland** (`mcp_server/tools/hyprland.py`)
- `hyprland_read_config` → lista as seções disponíveis (não o config inteiro)
- `hyprland_get_section SECTION` → só aquela seção (`general`, `input`, `gestures`, …)
- `hyprland_search_keybind MODIFIER KEY` → acha o keybind sem ler o config
- `hyprland_get_variable $VAR` → valor de uma variável
- `hyprland_set_variable`, `hyprland_set_keybind`, `hyprland_update_section` → escrita
- `hyprland_backup`

**Waybar** (`waybar.py`)
- `waybar_read_config` → módulos por posição (left/center/right)
- `waybar_read_section SECTION config|style` → um módulo ou um seletor CSS
- `waybar_read_style`, `waybar_add_module`, `waybar_backup`

**Kitty** (`kitty.py`)
- `kitty_read_config` → categorias de opção (font, colors, window)
- `kitty_search_option OPTION` → o valor de uma opção
- `kitty_set_option`, `kitty_backup`

**Hyprpaper** (`hyprpaper.py`)
- `hyprpaper_read_config`, `hyprpaper_set_wallpaper`, `hyprpaper_backup`

**Tema / design system** (`theme.py`)
- `theme_read_palette` → paleta gerada atual
- `theme_get_color NAME` → um token (`background`, `color1`, …)
- `theme_list_wallpapers`, `theme_set_wallpaper`

Exemplos de roteamento:
- "muda o bind do SUPER+D" → `hyprland_search_keybind SUPER D` → `hyprland_set_keybind`
- "edita o módulo clock da waybar" → `waybar_read_section clock config` → editar
- "qual o font size do kitty" → `kitty_search_option font_size` (não o config inteiro)

⚠️ **A escrita via MCP não conhece os perfis.** Essas tools escrevem no caminho resolvido pelo
`~/.config/theme/active`, ou seja no perfil ativo. Antes de escrever, saiba em qual perfil está —
skill **`theme-profiles`**.

Mexer no próprio server (`mcp_server/`) exige reiniciar a sessão do Claude Code para recarregar as
tools.

## nixos — pacotes e opções, ao vivo

Duas tools, configuradas no nível do usuário (não em `.claude/mcp.json`):

- `mcp__nixos__nix` — busca/info/stats/canais/flake-inputs/cache/store, cobrindo NixOS,
  Home Manager, nix-darwin, Nixvim, NVF, flakes, FlakeHub, NixHub, wiki, nix.dev, Noogle.
- `mcp__nixos__nix_versions` — histórico por commit (qual commit do nixpkgs trouxe a versão X).

Formas prontas:

```
nix {"action":"info","query":"X","channel":"25.05"}
nix {"action":"search","query":"X","type":"options"}
nix {"action":"search","source":"home-manager","query":"X"}
nix {"action":"cache","query":"X"}
nix_versions {"package":"X","version":"Y"}
```

Use **mesmo achando que sabe a resposta** — dados de treinamento atrasam meses em relação ao
nixpkgs.

## codebase-memory — grafo estrutural do código

[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) parseia o código deste repo
(Python de `mcp_server/`, scripts em `dotfiles/`, CSS, TOML) num grafo tree-sitter, então navegar
custa uma query em vez de leituras de arquivo inteiro.

- **Nome do projeto no grafo: `home-caio-nix-config`** — é o argumento `project` de toda tool.
  (`list_projects` confirma.)
- Registrado em `.claude/mcp.json` como o **binário nativo**
  `/home/caio/.local/bin/codebase-memory-mcp` (instalado pelo `install.sh` oficial, **não**
  compilado via Nix e **não** rodado via `nix run`).
- `CBM_ALLOWED_ROOT=/home/caio/nix-config` restringe a indexação a este repo.
  `CBM_CACHE_DIR=~/.cache/codebase-memory-mcp` guarda o grafo — fora da working tree.

Tools:

| Tool | Para |
|---|---|
| `index_status` / `index_repository` | checar/reconstruir o grafo — uma vez por mudança significativa, não por query |
| `search_graph` | busca estruturada: `query` (BM25), `name_pattern` (regex), `semantic_query` (array de keywords). Substitui grep por símbolo |
| `search_code` | busca textual dentro do grafo, sem varrer o filesystem |
| `get_code_snippet` | corpo de uma função/classe por qualified name, em vez do arquivo inteiro |
| `trace_path` | travessia do call graph (quem chama o quê, inbound/outbound) |
| `get_architecture` | linguagens, packages, hotspots, clusters, entry points |
| `detect_changes` | mapeia `git diff` para símbolos afetados e risco — antes de editar |
| `query_graph` / `get_graph_schema` | consulta livre ao grafo / esquema disponível |
| `manage_adr`, `ingest_traces`, `list_projects`, `delete_project` | auxiliares |

`semantic_query` **não é uma tool** — é um parâmetro de `search_graph`, e precisa ser um **array**
de keywords.

**Escopo real:** o grafo cobre Python/CSS/TOML/Bash. **Não** cobre `.nix`, `.qml`, `.conf`,
`.rasi` nem Markdown — para esses, `Read`/`Grep` é o caminho, ou a tool `nix-ricing`
correspondente quando existir.

Se `index_status` disser que o projeto não está indexado, rode `index_repository` com
`repo_path=/home/caio/nix-config` antes de continuar.

## Delegando a subagentes

**Um subagente não herda o `CLAUDE.md`.** Ao delegar via `Agent`, o prompt tem que repetir
explicitamente:

> Regra de ouro: consulte os MCP servers (`nix-ricing`, `nixos`, `codebase-memory`) antes de ler,
> planejar ou escrever qualquer coisa; e roteie as skills disponíveis pelo nome/descrição antes de
> montar qualquer plano.

Mesma exigência para Plan Mode.
