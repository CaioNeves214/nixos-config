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
# Apply system + home configuration (requires sudo)
# This is the ONLY switch command. home-manager runs as a NixOS module here, and
# the flake exposes only `nixosConfigurations` — there is no `homeConfigurations`
# output, so `home-manager switch --flake .#macbookpro2012` fails.
sudo nixos-rebuild switch --flake .#macbookpro2012

# Switch the visual profile (live, no rebuild) — see "Perfis visuais"
theme-profile            # show current + list available
theme-profile nous

# Fast validation without building or sudo
nix eval .#nixosConfigurations.macbookpro2012.config.system.build.toplevel.drvPath

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
    hyprland.nix                 # Points ~/.config/hypr/hyprland.conf at the ACTIVE PROFILE
    kitty.nix                    # Points ~/.config/kitty/kitty.conf at the active profile
    rofi.nix                     # Points ~/.config/rofi/{config,theme}.rasi at the active profile
    waybar.nix                   # Points ~/.config/waybar/style.css at the active profile
    quickshell.nix               # Points quickshell/{shell.qml,ui} at the active profile
    theme.nix                    # DESIGN SYSTEM: wallust wiring + update-theme / theme-profile / wallpaper-picker
    packages.nix                 # User packages + volume-popup wrapper (GTK3 typelibs)
    easyeffects.nix              # PipeWire EQ/bass-enhancer preset ("depth-boost") for CS4206 speakers
dotfiles/
  profiles/                      # VISUAL PROFILES — one self-contained look each (see "Perfis visuais")
    default/                     #   the original rice; palette derived from the wallpaper (wallust run)
      DESIGN.md                  #   ← READ FIRST when editing this profile (look, calibration, warts)
      hypr/hyprland.conf         #   Hyprland config (keybinds, animations, input); sources colors.conf
      kitty/kitty.conf           #   Kitty config; includes colors.conf (ABSOLUTE path)
      rofi/{config,theme}.rasi   #   Rofi launcher; theme.rasi imports colors.rasi (ABSOLUTE path)
      waybar/style.css           #   Waybar styling; @import colors.css (ABSOLUTE path)
      waybar/geometry.jsonc      #   Bar height/margins, included by the generated config.jsonc
      quickshell/shell.qml       #   Media widget: MPRIS drop-down under the waybar (layer-shell)
      quickshell/ui/             #   Local QML components (MediaButton.qml)
      gtk/popups.css             #   Overlay for the GTK popups (volume, wallpaper picker)
    nous/                        #   Nous Portal look: sharp corners, fixed palette, IBM Plex
      DESIGN.md                  #   ← the spec AND the implementation notes for this profile
      palette.toml               #   THE fixed palette — the only file to edit to recolor this profile
      ... same tree as default/
  sddm/theme/                    # Login screen: Main.qml + theme.conf + metadata.desktop (shared)
  waybar/scripts/volume-popup.py # GTK3 volume popup; reads tokens from rofi/colors.rasi (shared)
  scripts/wallpaper-picker.py    # GTK3 theme/wallpaper picker window (SUPER+W) (shared)
  scripts/palette-to-wallust.py  # palette.toml (semantic) -> wallust colorscheme JSON (19 keys)
  wallust/wallust.toml           # Design system config: palette extraction + template targets (shared)
  wallust/templates/             # colors-{hypr,kitty,rofi,waybar,quickshell} + waybar-config.jsonc (shared)
  wallpapers/                    # Wallpaper images (symlinked to ~/.config/wallpapers)
mcp_server/                      # Python nix-ricing MCP server (see docs/ and MCP section below)
docs/
  media-widget.md                # Quickshell media widget: full design + gotchas (per-profile QML)
  MCP_SETUP.md, mcp_server.md    # nix-ricing MCP server setup and reference
  MCP_REFACTOR.md, RICING_SERVER_SUMMARY.md
```

Everything under `dotfiles/profiles/<name>/` is **per-profile**; everything else in
`dotfiles/` is **shared** by all profiles.

## How dotfiles are managed

Dotfiles are linked into `~/.config/` via **`config.lib.file.mkOutOfStoreSymlink`** (an out-of-store symlink pointing back at the repo working tree, hardcoded to `/home/caio/nix-config`). This means **edits to files in `dotfiles/` take effect immediately** — no `home-manager switch` needed, just reload the app. A `switch` is only required when you change the Nix wiring itself (add/remove a linked file, edit a module).

For the per-profile files there is **one extra hop**: the Home Manager symlink points at
`~/.config/theme/active/<app>/<file>`, and `active` is itself a symlink to
`dotfiles/profiles/<name>/`. Live editing still works the same way — see below.

## Perfis visuais (theme profiles)

A **profile** is a complete, self-contained look: Hyprland decoration, waybar CSS + geometry,
kitty, rofi, and the Quickshell media widget. Switch with **`theme-profile <name>`** — live, no
rebuild; run it with no argument to see the current one and list the others.

> **Each profile documents its own look in `dotfiles/profiles/<name>/DESIGN.md`** — palette,
> fonts, radii, the constants that were calibrated on screen, and its known warts. **Read that
> file before editing a profile**, not this section. Kept out of here on purpose: it is only
> relevant when working on that specific profile.
>
> - `profiles/default/DESIGN.md` — the original rice: floating pills, wallpaper-derived palette.
> - `profiles/nous/DESIGN.md` — Nous Portal look: sharp corners, fixed palette, IBM Plex.

**The whole mechanism is one mutable symlink:**

```
~/.config/theme/active  ->  dotfiles/profiles/<name>/
```

Every Home Manager declaration points at a **constant** path under `active/`, never at a profile
directly. That is not a style choice — it is load-bearing:

> **A script must never re-point a path that Home Manager declares.** HM's
> `check-link-targets.sh` builds `homeFilePattern="$(readlink -e /nix/store)/*-home-manager-files/*"`;
> a target outside that pattern is treated as foreign, `cmp` sees different content, and because the
> target *is* a symlink the `backupFileExtension` branch is skipped — the result is `collision=1` and
> a **failed `nixos-rebuild switch`**. Keeping the declared target constant sidesteps this entirely.

**Four rules when adding to any profile:**

1. **Use absolute paths in color includes.** Profile files load from `~/.config/theme/active/…`, so a
   relative `include`/`@import` resolves into the *repo*, not into `~/.config/` where wallust writes.
   The one deliberate exception is rofi's `@theme "theme.rasi"`, which *should* stay relative so each
   profile picks up its own theme.
2. **The waybar layout is shared; only geometry is per-profile.** `wallust/templates/waybar-config.jsonc`
   is common to all profiles and pulls `active/waybar/geometry.jsonc` via waybar's `include`. Since
   waybar resolves duplicates with *"the first defined value takes precedence"* (`man 5 waybar`), the
   main template **must not** redeclare `height`/`margin-*` — it would win and the profile would be
   silently ignored. Anything else edited there repaints **every** profile.
3. **Quickshell does not hot-reload on a profile switch.** Its watch is on the *resolved inode*, and
   flipping `active` emits no inotify event, so `theme-profile` kills and respawns it. (Same reason
   `colors.json` *does* hot-reload: wallust performs a real write.)
4. **Changing bar geometry means re-measuring the media widget.** `shell.qml` anchors against the
   waybar's exclusive zone with `margins.top` and `barOffset` — both measured on screen, per-profile,
   never derived on paper. The values and the procedure live in each profile's `DESIGN.md`.

**Color: two ways to get a palette.** If a profile contains a `palette.toml`, it has a **fixed**
palette: `theme-profile` converts it with `dotfiles/scripts/palette-to-wallust.py` into
`~/.config/wallust/colorschemes/<name>.json` and applies it with `wallust cs -q -s <name>`, which
renders **the same 7 templates** as the wallpaper flow. Without a `palette.toml` (the `default`
profile) it falls back to `wallust run` on the current wallpaper. `update-theme` knows this too: on a
fixed-palette profile it changes the wallpaper image but **skips `wallust run`**, which would
otherwise destroy the palette. To recolor a fixed-palette profile, edit its `palette.toml` and run
`theme-profile <name>` — that file is the only place its colors exist.

## Design System (single source of color)

Colors are **not hardcoded per app** — they are derived from the current wallpaper by [`wallust`](https://codeberg.org/explosion-mental/wallust) and fanned out to every app. `dotfiles/wallust/wallust.toml` is the single source of truth.

**Flow:** `update-theme <img>` → sets wallpaper (hyprpaper) → `wallust run` extracts the palette and renders each `dotfiles/wallust/templates/colors-*` into a per-app include → reloads the apps live.

**Rendered includes and how each app consumes them** (all live in `~/.config/`, generated — never edit by hand):

| App     | Generated file          | Consumed via                                   |
|---------|-------------------------|------------------------------------------------|
| Hyprland| `hypr/colors.conf`      | `source = ~/.config/hypr/colors.conf`          |
| Kitty   | `kitty/colors.conf`     | `include /home/caio/.config/kitty/colors.conf` (absolute — see "Perfis visuais") |
| Waybar  | `waybar/colors.css`     | `@import url("file:///home/caio/.config/waybar/colors.css")` in `style.css` |
| Rofi    | `rofi/colors.rasi`      | `@import "/home/caio/.config/rofi/colors.rasi"` in `theme.rasi` |
| Waybar  | `waybar/config.jsonc`   | whole layout, generated (see below)             |
| Quickshell | `quickshell/colors.json` | `FileView` (`watchChanges: true`) in `shell.qml` |

**Apps that can't `@import` tokens get the palette differently:**
- **Waybar `config.jsonc`** — the calendar tooltip uses inline Pango markup (`<span color=…>`) which has no import mechanism, so the **entire config is a wallust template** (`wallust/templates/waybar-config.jsonc`). Edit *layout* there, not in `~/.config`. `waybar.nix` intentionally does **not** symlink `config.jsonc`.
- **GTK popups** (`volume-popup.py`) — read the generated `rofi/colors.rasi` at runtime via a small `load_colors()` regex and build their CSS from the tokens (fallback palette only if the file is missing). `wallpaper-picker.py` uses the same pattern; keep their fallbacks in sync.
- **SDDM greeter** (`dotfiles/sddm/theme/Main.qml`) — the greeter runs as the `sddm` user and cannot read `/home/caio`, so `update-theme` publishes its assets to **`/var/lib/sddm-theme/`** (see "Login screen" below).
- **Quickshell** (`dotfiles/profiles/<name>/quickshell/shell.qml`) — reads `~/.config/quickshell/colors.json` (template `colors-quickshell.json`) via `FileView` with `watchChanges: true`, so the media card re-themes live on every `update-theme`, with a fallback palette embedded in the QML for a fresh checkout. `quickshell.nix` symlinks `shell.qml` and `ui/` **individually, not the directory** — a directory symlink would make wallust write `colors.json` into the repo working tree (it used to, and the file ended up tracked in git).

**Bootstrap:** the generated files (`colors.*`, `waybar/config.jsonc`) are gitignored and do not exist on a fresh checkout — run `update-theme <wallpaper>` once after the first `nixos-rebuild switch` or Waybar/colors won't be present. The `~/.config/theme/active` symlink is created automatically by a `home.activation` hook in `theme.nix` (pointing at `default`) if it is missing, so nothing dangles on a fresh checkout.

**To change the whole system's look:** change the wallpaper and run `update-theme`, or tweak the extraction (`color_space`, `palette`, `check_contrast`) in `wallust.toml`. **To restyle one app while staying on-palette:** edit that app's dotfile to reference different color *tokens*, never literal hex.

**Two helper commands** (defined in `modules/home/theme.nix` as `writeShellScriptBin`, so they are on `PATH`):
- `update-theme [img|path]` — apply wallpaper + regenerate palette + reload apps. With no arg, re-applies the current wallpaper (`~/.cache/current-wallpaper`).
- `wallpaper-picker` — GTK3 popup to pick a wallpaper, bound to **SUPER+W** in `hyprland.conf`. Calls `update-theme` on selection.

**GTK3 Python popups** (`wallpaper-picker`, `volume-popup`) need `GI_TYPELIB_PATH` wired with the `.out` outputs of glib/pango plus `at-spi2-core` and `harfbuzz` — see the `giTypelibs`/`pickerTypelibs` lets in `packages.nix` and `theme.nix` before adding another PyGObject script.

## Media widget (Quickshell)

The now-playing control in the waybar's row is a separate **Quickshell layer-shell app**, not a
waybar module: `dotfiles/profiles/<name>/quickshell/shell.qml` (per-profile), symlinked live by
`modules/home/quickshell.nix` and started by `exec-once = quickshell`. It reads MPRIS and
Pipewire natively — no polling scripts.

> **Full documentation: [`docs/media-widget.md`](docs/media-widget.md)** — surface positioning
> and the anchor arithmetic, the audio visualizer, animation architecture, input masking, IPC
> control, and this host's constraints. Read it before touching the QML.
>
> Also load the **`quickshell` skill** (`.claude/skills/quickshell/`) for the exact 0.3.0 API
> and the known pitfalls.

Two things worth knowing without opening either: the widget's `margins.top` / `margins.left`
are **measured on screen and per-profile** (values in each profile's `DESIGN.md`), and it does
**not** hot-reload on a profile switch — `theme-profile` kills and respawns it, because its
watch is on the resolved inode and flipping the `active` symlink emits no inotify event.

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
