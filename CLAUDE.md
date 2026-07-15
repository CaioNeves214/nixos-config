# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🔒 REGRA DE OURO — INEGOCIÁVEL: MCP first, sempre

**Antes de abrir qualquer arquivo para ler, antes de planejar qualquer implementação, e antes de escrever qualquer arquivo, verifique se um MCP server (`nix-ricing`, `nixos` ou `codebase-memory`) pode fornecer essa informação — e use-o primeiro.** `Read`/`Grep`/`Write` direto só entram depois de esgotar as tools MCP relevantes, ou quando a tarefa não tem nenhuma tool MCP aplicável (ex.: debugar um arquivo local específico, scripts fora do escopo dos servers).

Isso vale para:
- Leitura de config (Hyprland, Waybar, Kitty, Hyprpaper, tema/wallust) → usar as tools `mcp__nix-ricing__*` correspondentes, nunca `Read` direto no dotfile.
- Escrita/edição de config → usar as tools de `set`/`update` do MCP quando existirem, antes de `Edit`/`Write` manual.
- Qualquer dúvida sobre pacotes nixpkgs, opções NixOS/home-manager/nix-darwin, flakes, canais, cache binário → usar `mcp__nixos__nix` / `mcp__nixos__nix_versions`, nunca confiar em conhecimento de treinamento nem em `nix search` manual.
- Navegação/entendimento de código (ex.: `mcp_server/`, scripts Python, achar onde uma função é chamada, mapear dependências) → usar `mcp__codebase-memory__*` (`search_graph`, `trace_path`, `get_code_snippet`, `search_code`, `get_architecture`) antes de `Read`/`Grep` varrendo arquivos manualmente — é ordens de magnitude mais barato em tokens.
- Planejamento (Plan Mode) → antes de esboçar qualquer plano de implementação, consultar os MCP servers relevantes para levantar o estado atual real, em vez de assumir a partir do código ou de memória.

**Essa regra se estende integralmente a subagentes.** Sempre que o usuário (ou o próprio fluxo) acionar o Plan Mode, ou qualquer subagente via `Agent`/`Task`, o prompt passado ao subagente deve incluir explicitamente esta regra de ouro: consultar e usar os MCP servers disponíveis (`nix-ricing`, `nixos`, `codebase-memory`) antes de ler, planejar ou escrever qualquer coisa. Um subagente não herda este arquivo automaticamente na sua instrução de tarefa — repita a regra no prompt sempre que delegar trabalho.

Ver detalhes das tools disponíveis na seção "MCP Server Integration" mais abaixo.

## What this repo is

NixOS + Home Manager configuration for a MacBook Pro 2012 running NixOS 25.05 with Hyprland (Wayland compositor). Managed as a Nix flake.

## Key commands

```bash
# Apply system configuration (requires sudo)
sudo nixos-rebuild switch --flake .#macbookpro2012

# Apply only Home Manager changes (faster, no sudo)
home-manager switch --flake .#macbookpro2012

# Check flake outputs / validate syntax
nix flake check

# Update all flake inputs (nixpkgs, home-manager)
nix flake update

# Search available packages
nix search nixpkgs <package-name>
```

## Repository structure

```
flake.nix                        # Entry point — defines inputs and nixosConfigurations
hosts/macbookpro2012/
  configuration.nix              # Host-level NixOS config (hardware, display, networking, XDG portals)
  hardware-configuration.nix     # Auto-generated; do not edit manually
home/caio.nix                    # Home Manager entry point (imports all home/ modules)
modules/
  system/                        # NixOS modules imported by configuration.nix
    audio.nix, bluetooth.nix, boot.nix, fan.nix, locale.nix
    networking.nix, packages.nix, users.nix, zsh.nix, udev.nix
    login.nix                    # SDDM (Qt6) + custom QML greeter theme
  home/                          # Home Manager modules imported by home/caio.nix
    dev.nix                      # Dev tools: nodejs_24, python311
    git.nix                      # Git identity
    hyprland.nix                 # Links dotfiles/hypr/hyprland.conf
    kitty.nix                    # Links dotfiles/kitty/kitty.conf
    rofi.nix                     # Links dotfiles/rofi/{config,theme}.rasi
    waybar.nix                   # Links dotfiles/waybar/style.css (config.jsonc is wallust-generated)
    quickshell.nix               # Links dotfiles/quickshell (media widget, layer-shell)
    theme.nix                    # DESIGN SYSTEM: wallust wiring + update-theme / wallpaper-picker
    packages.nix                 # User packages + volume-popup wrapper (GTK3 typelibs)
    easyeffects.nix              # PipeWire EQ/bass-enhancer preset ("depth-boost") for CS4206 speakers
dotfiles/
  sddm/theme/                    # Login screen: Main.qml + theme.conf + metadata.desktop
  hypr/hyprland.conf             # Hyprland config (keybinds, animations, input); sources colors.conf
  kitty/kitty.conf               # Kitty config; includes colors.conf
  rofi/{config,theme}.rasi       # Rofi launcher; theme.rasi imports colors.rasi
  waybar/style.css               # Waybar styling; @import "colors.css"
  waybar/scripts/volume-popup.py # GTK3 volume popup; reads tokens from rofi/colors.rasi
  scripts/wallpaper-picker.py    # GTK3 theme/wallpaper picker window (SUPER+W)
  quickshell/shell.qml           # Media widget: MPRIS drop-down under the waybar (layer-shell)
  wallust/wallust.toml           # Design system config: palette extraction + template targets
  wallust/templates/             # colors-{hypr,kitty,rofi,waybar,quickshell} + waybar-config.jsonc, rendered per wallpaper
  wallpapers/                    # Wallpaper images (symlinked to ~/.config/wallpapers)
mcp_server/                      # Python nix-ricing MCP server (see docs/ and MCP section below)
```

## How dotfiles are managed

Dotfiles under `dotfiles/` are linked into `~/.config/` via **`config.lib.file.mkOutOfStoreSymlink`** (an out-of-store symlink pointing back at the repo working tree, hardcoded to `/home/caio/nix-config`). This means **edits to files in `dotfiles/` take effect immediately** — no `home-manager switch` needed, just reload the app. A `switch` is only required when you change the Nix wiring itself (add/remove a linked file, edit a module).

## Design System (single source of color)

Colors are **not hardcoded per app** — they are derived from the current wallpaper by [`wallust`](https://codeberg.org/explosion-mental/wallust) and fanned out to every app. `dotfiles/wallust/wallust.toml` is the single source of truth.

**Flow:** `update-theme <img>` → sets wallpaper (hyprpaper) → `wallust run` extracts the palette and renders each `dotfiles/wallust/templates/colors-*` into a per-app include → reloads the apps live.

**Rendered includes and how each app consumes them** (all live in `~/.config/`, generated — never edit by hand):

| App     | Generated file          | Consumed via                                   |
|---------|-------------------------|------------------------------------------------|
| Hyprland| `hypr/colors.conf`      | `source = ~/.config/hypr/colors.conf`          |
| Kitty   | `kitty/colors.conf`     | `include colors.conf`                           |
| Waybar  | `waybar/colors.css`     | `@import "colors.css";` in `style.css`          |
| Rofi    | `rofi/colors.rasi`      | `@import "colors.rasi"` in `theme.rasi`         |
| Waybar  | `waybar/config.jsonc`   | whole layout, generated (see below)             |
| Quickshell | `quickshell/colors.json` | `FileView` (`watchChanges: true`) in `shell.qml` |

**Apps that can't `@import` tokens get the palette differently:**
- **Waybar `config.jsonc`** — the calendar tooltip uses inline Pango markup (`<span color=…>`) which has no import mechanism, so the **entire config is a wallust template** (`wallust/templates/waybar-config.jsonc`). Edit *layout* there, not in `~/.config`. `waybar.nix` intentionally does **not** symlink `config.jsonc`.
- **GTK popups** (`volume-popup.py`) — read the generated `rofi/colors.rasi` at runtime via a small `load_colors()` regex and build their CSS from the tokens (fallback palette only if the file is missing). `wallpaper-picker.py` uses the same pattern; keep their fallbacks in sync.
- **SDDM greeter** (`dotfiles/sddm/theme/Main.qml`) — the greeter runs as the `sddm` user and cannot read `/home/caio`, so `update-theme` publishes its assets to **`/var/lib/sddm-theme/`** (see "Login screen" below).
- **Quickshell** (`dotfiles/quickshell/shell.qml`) — reads `~/.config/quickshell/colors.json` (template `colors-quickshell.json`) via `FileView` with `watchChanges: true`, so the media card re-themes live on every `update-theme`, with a fallback palette embedded in the QML for a fresh checkout.

**Bootstrap:** the generated files (`colors.*`, `waybar/config.jsonc`) are gitignored and do not exist on a fresh checkout — run `update-theme <wallpaper>` once after the first `home-manager switch` or Waybar/colors won't be present.

**To change the whole system's look:** change the wallpaper and run `update-theme`, or tweak the extraction (`color_space`, `palette`, `check_contrast`) in `wallust.toml`. **To restyle one app while staying on-palette:** edit that app's dotfile to reference different color *tokens*, never literal hex.

**Two helper commands** (defined in `modules/home/theme.nix` as `writeShellScriptBin`, so they are on `PATH`):
- `update-theme [img|path]` — apply wallpaper + regenerate palette + reload apps. With no arg, re-applies the current wallpaper (`~/.cache/current-wallpaper`).
- `wallpaper-picker` — GTK3 popup to pick a wallpaper, bound to **SUPER+W** in `hyprland.conf`. Calls `update-theme` on selection.

**GTK3 Python popups** (`wallpaper-picker`, `volume-popup`) need `GI_TYPELIB_PATH` wired with the `.out` outputs of glib/pango plus `at-spi2-core` and `harfbuzz` — see the `giTypelibs`/`pickerTypelibs` lets in `packages.nix` and `theme.nix` before adding another PyGObject script.

## Media widget (Quickshell)

The now-playing control is **not** a waybar module — GTK/waybar drawers can only expand
horizontally inside the bar's own row, and the goal was a card that **drops down** below the bar
on hover with fluid animation and retracts on mouse-leave (inspired by adaptive eww music widgets
seen on r/unixporn). That needs its own compositor surface, so it's a separate
[Quickshell](https://quickshell.org) (QtQuick/QML) **layer-shell** app: `dotfiles/quickshell/shell.qml`,
symlinked live via `modules/home/quickshell.nix` to `~/.config/quickshell/` (Quickshell auto-discovers
`shell.qml` there — no `-c`/`-p` flag needed) and started by `exec-once = quickshell` in `hyprland.conf`.

- **Not embedded in waybar** — it's a `PanelWindow` anchored `top`+`left`, `exclusiveZone: 0` (doesn't
  push windows), rendered above windows and visually flush under the waybar (`margins.top` matches
  waybar's own `margin-top`). It only *looks* like part of the bar.
- **Trigger**: a small always-visible thumb (album art or a fallback glyph) sitting in the bar's row,
  where `group/mediaplayer` used to be — that module and its `custom/media-*` children were removed
  from `wallust/templates/waybar-config.jsonc` and `waybar/style.css`. `hyprland/window` (the focused
  window title) was also dropped from `modules-left` to free the space and, importantly, to make the
  bar's left-hand pill a **fixed width** (just the 5 workspace buttons) — `hyprland/window`'s width
  varied with the window title, which made any fixed pixel offset for the widget impossible to align.
  `margins.left` in `shell.qml` is a hand-tuned pixel offset to sit after `hyprland/workspaces`; if the
  number of workspaces or the bar layout changes, re-tune it visually.
- **The `PanelWindow`'s size is fixed, never animated** — `implicitWidth`/`implicitHeight` are constant
  (barHeight + cardHeight), sized for the fully-expanded state up front. Animating a wlr-layer-shell
  surface's size directly (what an earlier version did) requires the compositor to reconfigure the
  Wayland surface every frame; Hyprland doesn't do this smoothly, and it showed up as the card
  rendering half-clipped/stale-looking. The open/close animation instead happens **inside** the
  fixed surface: the card lives in a `clip: true` `Item` (`cardClip`) whose `height` animates
  (`Behavior on height`, `NumberAnimation`/`OutCubic`, ~280ms) — a plain QML property animation, not a
  surface resize.
- **Hover** — two `HoverHandler`s, one nested inside the thumb `Rectangle` and one inside `cardClip`,
  combined into `root.expanded` via a `Binding`. A `HoverHandler`'s hit-region follows its **parent
  Item's geometry**, not its `target` property — so each is declared *inside* the item it should
  track, rather than attached to the top-level `PanelWindow` (which would make the entire fixed-size
  320px-wide surface hoverable, including empty space beside the icon). No polling scripts: playback
  state, track metadata, and position/length come from Quickshell's built-in **MPRIS service**
  (`Quickshell.Services.Mpris`, `Mpris.players`), replacing the old `playerctl`+`jq` bash scripts
  (`waybar-media-play`/`waybar-media-info`, now deleted) that polled at `interval:1`. `playerctl` itself
  stays installed only as a general CLI convenience.
- **Colors** — wallust palette, not album-art-derived (unlike the eww reference), to stay consistent
  with the rest of the design system — see the table above.
- **`nix-ricing` doesn't cover Quickshell** — there's no `mcp__nix-ricing__quickshell_*` tool; edit
  `shell.qml` directly like any other QML/dotfile. Live-reloads on save (Quickshell watches its config).
- **Hardware**: Intel HD 4000 (2012 MacBook Pro) — same lesson as the SDDM greeter's pre-rendered blur:
  keep animations to opacity/height/position, avoid heavy shader effects.

## Login screen (SDDM + custom QML theme)

`modules/system/login.nix` builds `dotfiles/sddm/theme/` into a theme package (`sddm-theme-caio`) and points SDDM at it. Layout: circular avatar centered, real name below, password field below; background is the current wallpaper, blurred. On `loginSucceeded` the blur dissolves while the UI fades out — same duration, same easing (`animationDuration` in `theme.conf`).

Things that are easy to get wrong here:

- **The greeter runs as the `sddm` user**, so it cannot read `~/.config` or `~/.cache`. All its assets live in **`/var/lib/sddm-theme/`** (created by a `systemd.tmpfiles` rule, owned by `caio` so `update-theme` writes it without sudo, `0755` so sddm reads it): `wallpaper.jpg`, `wallpaper-blur.jpg` (both from ImageMagick), `avatar.png`, and `colors.conf` (wallust template `colors-sddm.conf`, copied in from `~/.cache/`). `Main.qml` falls back to a dark palette and an initial-letter circle if any of them is missing, so a fresh checkout still logs in.
- **The blur is pre-rendered, not a live QML effect** — an Intel HD 4000 does not want to gaussian-blur a full-screen image every frame. The animation cross-fades the blurred image out to reveal the sharp one.
- **SDDM must be the Qt6 package** (`pkgs.kdePackages.sddm`); the 25.05 default is still Qt5 and the theme uses `QtQuick.Effects` (`MultiEffect`, for the circular avatar mask).
- **`QML_XHR_ALLOW_FILE_READ=1`** is set on `display-manager.service`: Qt6 blocks `XMLHttpRequest` on `file://` by default, and that is how `Main.qml` reads `colors.conf`.
- **Fonts must be system fonts** (`fonts.packages`) — the greeter does not see Home Manager's.
- Debugging: **QML errors do not go to stderr**, they go to the journal (`journalctl -t sddm-greeter-qt6`). Test a change without rebooting with
  `sddm-greeter-qt6 --test-mode --theme dotfiles/sddm/theme` (`sddm.canPowerOff`/`canReboot`/`canSuspend` are always `false` in test mode, so the power row is hidden there).

**The user photo** goes at `dotfiles/sddm/avatar.png` (gitignored — personal, and kept out of the world-readable `/nix/store`); `update-theme` center-crops it into `/var/lib/sddm-theme/avatar.png`. Changing the photo needs only `update-theme`, not a rebuild.

## Architecture notes

- The flake targets a single host (`macbookpro2012`) at `x86_64-linux`.
- `home-manager` runs as a NixOS module (`home-manager.nixosModules.home-manager`), so `nixos-rebuild switch` rebuilds both system and home simultaneously.
- `nix-ld` is enabled with a broad set of dynamic libraries to support pre-built binaries (e.g., Electron apps, VS Code extensions).
- Fan control uses `mbpfan` tuned for MacBook Pro thermals (`modules/system/fan.nix`).
- Waybar refreshes instantly on AC plug/unplug via a `services.udev.extraRules` rule (`modules/system/udev.nix`) that sends `SIGUSR2` (waybar's default "reload" signal) on any `power_supply` subsystem `change` event. Purely event-driven — no polling service. Note: waybar's `"signal"` module option only applies to `custom/*` modules, not built-ins like `battery`, so a full-bar `SIGUSR2` reload is used instead of a targeted module refresh.
- `nixpkgs.config.allowUnfree = true` is set globally, so unfree packages (discord, etc.) can be added without per-package overrides.
- `nix-command` and `flakes` experimental features are enabled in `nix.settings`.
- The onboard audio codec is a Cirrus Logic CS4206, which needs `options snd-hda-intel model=mbp101` (`modules/system/audio.nix`, via `boot.extraModprobeConfig`) or the kernel's generic HDA autoparser produces thin/tinny speaker output. Even with that quirk the small 2012 speakers are physically bass-light, so `modules/home/easyeffects.nix` adds a PipeWire EQ + bass-enhancer preset (`depth-boost`, auto-loaded) to compensate in software; it requires `programs.dconf.enable = true` (set alongside the quirk in `audio.nix`) for the EasyEffects daemon to run.

## MCP Server Integration

**Always consult available MCP servers before reasoning independently.** This repository has access to specialized MCP servers (nixos, nix-ricing, codebase-memory) that expose tools for package queries, NixOS options, system configuration, and codebase structure.

**Token economy principle:** MCP tools retrieve only what's needed, avoiding redundant file reads and parsing. Always use them first.

**Before solving a problem yourself:**
1. Check which MCP servers are available in the current session
2. Review their tool capabilities
3. Use their tools first if they can help with the task

**Why:** MCP tools are optimized for real-time data (live package searches, current options, cache status) and eliminate token overhead from reasoning or manual lookups.

**When to reason independently:** Only if an MCP server has no relevant tools for the current task, or if its tools would clearly not help (e.g., debugging a local file).

### nix-ricing Server (modular, token-efficient)

Hyprland:
- `hyprland_read_config` → lists available sections (not the full config)
- `hyprland_get_section SECTION` → reads specific section only (general, input, gestures, etc)
- `hyprland_search_keybind MODIFIER KEY` → finds keybind by modifier+key (not full config)
- `hyprland_get_variable $VAR` → single variable value
- `hyprland_set_variable`, `hyprland_set_keybind` → write operations

Waybar:
- `waybar_read_config` → lists modules by position (left, center, right)
- `waybar_read_section SECTION config|style` → reads specific module or CSS selector
- `waybar_add_module` → add new module

Kitty:
- `kitty_read_config` → lists option categories (font, colors, window)
- `kitty_search_option OPTION` → finds specific option value
- `kitty_set_option` → write operation

Hyprpaper:
- `hyprpaper_read_config` → lists wallpapers configured
- `hyprpaper_set_wallpaper` → set wallpaper

Theme / Design System (wallust palette):
- `theme_read_palette` → current generated palette
- `theme_get_color NAME` → single token value (e.g. background, color1)
- `theme_list_wallpapers` → available wallpapers in the picker
- `theme_set_wallpaper` → switch wallpaper (drives the update-theme flow)

**Examples:**
- "Change SUPER+D binding" → `hyprland_search_keybind SUPER D`, then `hyprland_set_keybind`
- "Edit waybar clock module" → `waybar_read_section clock config`, then edit
- "Find font size" → `kitty_search_option font_size` (not full config)

### codebase-memory Server (structural code graph, token-efficient)

[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) — parses this repo's code (Python `mcp_server/`, shell/Python scripts under `dotfiles/`) into a tree-sitter-based structural graph, so navigation/search costs a query instead of reading whole files. It is **not packaged in nixpkgs**; it's run straight from its own flake via `nix run github:DeusData/codebase-memory-mcp --` (same pattern as the `nixos` server), registered in `.claude/mcp.json` as `codebase-memory`. No system rebuild needed to use it — `nix run` fetches/builds and caches the binary via the Nix store on first use.

**Scope:** `CBM_ALLOWED_ROOT=/home/caio/nix-config` restricts `index_repository` to this repo only. Graph/cache lives in `CBM_CACHE_DIR=~/.cache/codebase-memory-mcp` (not in the repo, not gitignored — it's outside the working tree entirely).

Key tools:
- `index_repository` / `index_status` — (re)build the graph; run once per significant change, not per query.
- `search_graph` — structured search by label/name/file/degree (replaces grepping for a symbol).
- `search_code` — grep-like text search within the indexed graph, no filesystem walk.
- `get_code_snippet` — fetch a function/class body by qualified name instead of reading the whole file.
- `trace_path` — call-graph traversal (who calls what, inbound/outbound).
- `detect_changes` — map `git diff` to affected symbols/risk before editing.
- `get_architecture` — languages, packages, hotspots overview of the repo.
- `semantic_query` — embedding-based search when you don't know the exact symbol name.

**When to use:** any question about "where is X defined", "what calls Y", "what changed and what does it affect" in this repo's code (mainly `mcp_server/` and the Python scripts in `dotfiles/`) — reach for these tools before `Read`/`Grep`, per the golden rule at the top of this file. Plain dotfile config values (Hyprland/Waybar/Kitty options) still go through `nix-ricing`, not this server.
