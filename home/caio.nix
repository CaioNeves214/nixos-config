{ pkgs, ... }:

{
  home.username = "caio";

  home.homeDirectory = "/home/caio";

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # Cursor Bibata (padrão em rices Linux/Hyprland)
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  imports = [

    ../modules/home/git.nix
    ../modules/home/packages.nix
    ../modules/home/dev.nix
    ../modules/home/hyprland.nix
    ../modules/home/waybar.nix
    ../modules/home/quickshell.nix
    ../modules/home/kitty.nix
    ../modules/home/theme.nix
    ../modules/home/gtk.nix
    ../modules/home/rofi.nix
    ../modules/home/walker.nix
    ../modules/home/easyeffects.nix
  ];
}
