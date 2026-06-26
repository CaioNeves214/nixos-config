{ config, ... }:

{
  xdg.configFile."waybar/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/waybar/config.jsonc;

  xdg.configFile."waybar/style.css".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/waybar/style.css;
}
