{ config, ... }:

{
  xdg.configFile."hypr/hyprland.conf".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/hypr/hyprland.conf;

#  xdg.configFile."hypr/hyprpaper.conf".source =
#    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/hypr/hyprpaper.conf;
}
