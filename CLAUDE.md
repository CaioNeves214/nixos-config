# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
    networking.nix, packages.nix, users.nix, zsh.nix
  home/                          # Home Manager modules imported by home/caio.nix
    dev.nix                      # Dev tools: nodejs_24, python311
    git.nix                      # Git identity
    hyprland.nix                 # Links dotfiles/hypr/hyprland.conf
    kitty.nix                    # Links dotfiles/kitty/kitty.conf
    rofi.nix                     # Links dotfiles/rofi/{config,theme}.rasi
    waybar.nix                   # Links dotfiles/waybar/style.css (config.jsonc is wallust-generated)
    theme.nix                    # DESIGN SYSTEM: wallust wiring + update-theme / wallpaper-picker
    packages.nix                 # User packages + volume-popup wrapper (GTK3 typelibs)
dotfiles/
  hypr/hyprland.conf             # Hyprland config (keybinds, animations, input); sources colors.conf
  kitty/kitty.conf               # Kitty config; includes colors.conf
  rofi/{config,theme}.rasi       # Rofi launcher; theme.rasi imports colors.rasi
  waybar/style.css               # Waybar styling; @import "colors.css"
  waybar/scripts/volume-popup.py # GTK3 volume popup; reads tokens from rofi/colors.rasi
  scripts/wallpaper-picker.py    # GTK3 theme/wallpaper picker window (SUPER+W)
  wallust/wallust.toml           # Design system config: palette extraction + template targets
  wallust/templates/             # colors-{hypr,kitty,rofi,waybar} + waybar-config.jsonc, rendered per wallpaper
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

**Two apps can't `@import` tokens, so they get the palette differently:**
- **Waybar `config.jsonc`** — the calendar tooltip uses inline Pango markup (`<span color=…>`) which has no import mechanism, so the **entire config is a wallust template** (`wallust/templates/waybar-config.jsonc`). Edit *layout* there, not in `~/.config`. `waybar.nix` intentionally does **not** symlink `config.jsonc`.
- **GTK popups** (`volume-popup.py`) — read the generated `rofi/colors.rasi` at runtime via a small `load_colors()` regex and build their CSS from the tokens (fallback palette only if the file is missing). `wallpaper-picker.py` uses the same pattern; keep their fallbacks in sync.

**Bootstrap:** the generated files (`colors.*`, `waybar/config.jsonc`) are gitignored and do not exist on a fresh checkout — run `update-theme <wallpaper>` once after the first `home-manager switch` or Waybar/colors won't be present.

**To change the whole system's look:** change the wallpaper and run `update-theme`, or tweak the extraction (`color_space`, `palette`, `check_contrast`) in `wallust.toml`. **To restyle one app while staying on-palette:** edit that app's dotfile to reference different color *tokens*, never literal hex.

**Two helper commands** (defined in `modules/home/theme.nix` as `writeShellScriptBin`, so they are on `PATH`):
- `update-theme [img|path]` — apply wallpaper + regenerate palette + reload apps. With no arg, re-applies the current wallpaper (`~/.cache/current-wallpaper`).
- `wallpaper-picker` — GTK3 popup to pick a wallpaper, bound to **SUPER+W** in `hyprland.conf`. Calls `update-theme` on selection.

**GTK3 Python popups** (`wallpaper-picker`, `volume-popup`) need `GI_TYPELIB_PATH` wired with the `.out` outputs of glib/pango plus `at-spi2-core` and `harfbuzz` — see the `giTypelibs`/`pickerTypelibs` lets in `packages.nix` and `theme.nix` before adding another PyGObject script.

## Architecture notes

- The flake targets a single host (`macbookpro2012`) at `x86_64-linux`.
- `home-manager` runs as a NixOS module (`home-manager.nixosModules.home-manager`), so `nixos-rebuild switch` rebuilds both system and home simultaneously.
- `nix-ld` is enabled with a broad set of dynamic libraries to support pre-built binaries (e.g., Electron apps, VS Code extensions).
- Fan control uses `mbpfan` tuned for MacBook Pro thermals (`modules/system/fan.nix`).
- `nixpkgs.config.allowUnfree = true` is set globally, so unfree packages (discord, etc.) can be added without per-package overrides.
- `nix-command` and `flakes` experimental features are enabled in `nix.settings`.

## MCP Server Integration

**Always consult available MCP servers before reasoning independently.** This repository has access to specialized MCP servers (nixos, nix-ricing) that expose tools for package queries, NixOS options, and system configuration.

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
