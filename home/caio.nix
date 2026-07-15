{ pkgs, ... }:

{
  home.username = "caio";

  home.homeDirectory = "/home/caio";

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # Cursor padrão do Linux (Adwaita: preto com borda branca)
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
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
    ../modules/home/rofi.nix
    ../modules/home/easyeffects.nix
  ];
}
