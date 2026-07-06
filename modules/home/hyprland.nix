{ config, ... }:

{
  # hyprpaper.conf é gerado/gerido pelo theme.nix (design system).
  xdg.configFile."hypr/hyprland.conf".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/hypr/hyprland.conf;
}
