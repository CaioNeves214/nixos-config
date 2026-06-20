{ pkgs, ... }:

{
  home.username = "caio";

  home.homeDirectory = "/home/caio";

  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  imports = [

    ../modules/home/git.nix
    ../modules/home/packages.nix
    ../modules/home/dev.nix
    ../modules/home/hyprland.nix
    ../modules/home/waybar.nix
  ];
}
