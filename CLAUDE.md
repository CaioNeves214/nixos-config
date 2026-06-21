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
