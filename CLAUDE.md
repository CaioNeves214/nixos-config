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
home/caio.nix                    # Home Manager entry point for user caio
modules/
  system/                        # NixOS modules imported by configuration.nix
    audio.nix, bluetooth.nix, boot.nix, fan.nix, locale.nix
    networking.nix, packages.nix, users.nix, zsh.nix
  home/                          # Home Manager modules imported by home/caio.nix
    dev.nix                      # Dev tools: nodejs_24, python311
    git.nix                      # Git identity
    hyprland.nix                 # Links dotfiles/hypr/hyprland.conf via xdg.configFile
    packages.nix                 # User packages: brave, kitty, waybar, rofi, hyprpaper, thunar, mako, discord
    waybar.nix                   # Links dotfiles/waybar/{config.jsonc,style.css} via xdg.configFile
dotfiles/
  hypr/hyprland.conf             # Hyprland compositor config (keybinds, animations, input)
  waybar/config.jsonc            # Waybar bar layout
  waybar/style.css               # Waybar styling
```

## How dotfiles are managed

Dotfiles under `dotfiles/` are **symlinked into `~/.config/`** by the Home Manager modules using `xdg.configFile."<path>".source`. Edit the files in `dotfiles/` directly — they take effect after `home-manager switch`.

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

**Examples:**
- "Change SUPER+D binding" → `hyprland_search_keybind SUPER D`, then `hyprland_set_keybind`
- "Edit waybar clock module" → `waybar_read_section clock config`, then edit
- "Find font size" → `kitty_search_option font_size` (not full config)
