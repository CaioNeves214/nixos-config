{ config, ... }:

{
  xdg.configFile."kitty/kitty.conf".source =
    config.lib.file.mkOutOfStoreSymlink /home/caio/nix-config/dotfiles/kitty/kitty.conf;
}
